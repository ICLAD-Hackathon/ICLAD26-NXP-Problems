#!/usr/bin/env python3
"""
NXP ICLAD 2026 — Vertex AI Express Mode Agent
==============================================
Drop-in replacement for starter_agent.py with production-grade infrastructure:
  - Background heartbeat (progress logging during long model calls)
  - Exponential-backoff retry with retryable-flag awareness
  - Per-call JSON diagnostics saved to temp_dir/

The agent interface and 5-step pipeline are identical to starter_agent.py.
Participants should extend the prompt logic in step2 / step4.

Usage:
  python3 agent/vertexai_express_agent.py <info_json> --model gemini-2.0-flash-exp
"""

import argparse
import json
import re
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
from contextlib import contextmanager
from pathlib import Path


# ─── Constants ───────────────────────────────────────────────────────────────

RETRYABLE_HTTP_STATUS = {429, 500, 502, 503, 504}


# ─── Heartbeat ────────────────────────────────────────────────────────────────

@contextmanager
def heartbeat(message, interval_seconds=15):
    """Log elapsed time every interval_seconds while a block runs."""
    stop_event = threading.Event()

    def run():
        start = time.monotonic()
        while not stop_event.wait(interval_seconds):
            elapsed = int(time.monotonic() - start)
            print(f"[INFO] {message} ({elapsed}s elapsed)", file=sys.stderr, flush=True)

    thread = threading.Thread(target=run, daemon=True)
    thread.start()
    try:
        yield
    finally:
        stop_event.set()
        thread.join(timeout=1)


# ─── Model endpoint ───────────────────────────────────────────────────────────

def parse_error_payload(error_text):
    try:
        payload = json.loads(error_text)
    except json.JSONDecodeError:
        return {"error": error_text}
    return payload if isinstance(payload, dict) else {"error": error_text}


def should_retry(status_code, payload):
    if payload.get("retryable") is True:
        return True
    return status_code in RETRYABLE_HTTP_STATUS


def write_diagnostics(path, diagnostics, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    data = dict(diagnostics or {})
    data["text_chars"] = len(text or "")
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def call_model(endpoint, prompt, model, max_tokens=8192, max_retries=5, diagnostics_path=None):
    """POST to the benchmark model endpoint with heartbeat + exponential-backoff retry."""
    url = endpoint.rstrip("/") + "/generate"
    body = json.dumps({
        "model":            model,
        "prompt":           prompt,
        "max_output_tokens": max_tokens,
    }).encode("utf-8")

    delay = 2
    for attempt in range(1, max_retries + 1):
        print(
            f"[INFO] Model request attempt {attempt}/{max_retries} using {model}",
            file=sys.stderr, flush=True,
        )
        try:
            req = urllib.request.Request(
                url, data=body,
                headers={"Content-Type": "application/json"},
                method="POST",
            )
            with heartbeat("Waiting for model response"):
                with urllib.request.urlopen(req, timeout=300) as resp:
                    payload = json.loads(resp.read().decode("utf-8"))

            text = payload.get("text") or ""
            diagnostics = payload.get("diagnostics") or {}
            if diagnostics_path:
                write_diagnostics(diagnostics_path, diagnostics, text)
            if not text.strip():
                print(f"[WARN] Model returned empty text. Diagnostics: {diagnostics}",
                      file=sys.stderr, flush=True)
            return text

        except urllib.error.HTTPError as exc:
            err_payload = parse_error_payload(exc.read().decode("utf-8", errors="replace"))
            if not should_retry(exc.code, err_payload):
                raise RuntimeError(f"Model non-retryable error {exc.code}: {err_payload}")
            if attempt == max_retries:
                raise RuntimeError(f"Model retry limit reached after {exc.code}: {err_payload}")
            print(f"[WARN] Retryable error {exc.code}. Retry in {delay}s ({attempt}/{max_retries})",
                  file=sys.stderr, flush=True)
            time.sleep(delay)
            delay = min(delay * 2, 60)

        except urllib.error.URLError as exc:
            if attempt == max_retries:
                raise RuntimeError(f"Model endpoint unreachable: {exc}")
            print(f"[WARN] Connection error. Retry in {delay}s ({attempt}/{max_retries}) {exc}",
                  file=sys.stderr, flush=True)
            time.sleep(delay)
            delay = min(delay * 2, 60)

    raise RuntimeError("Maximum retries exceeded.")


# ─── Utilities ────────────────────────────────────────────────────────────────

def read_text(path_value, label, max_chars=None):
    path = Path(path_value)
    if not path.is_file():
        print(f"[WARN] {label} not found: {path}", file=sys.stderr)
        return path, ""
    content = path.read_text(encoding="utf-8", errors="replace")
    if max_chars and len(content) > max_chars:
        print(f"[INFO] {label} truncated to {max_chars:,}/{len(content):,} chars", file=sys.stderr)
        content = content[:max_chars]
    else:
        print(f"[INFO] Read {label}: {path} ({len(content):,} chars)", file=sys.stderr)
    return path, content


def extract_yaml_blocks(text):
    return re.findall(r'```(?:yaml|yml)?\s*\n(.*?)```', text, re.DOTALL | re.IGNORECASE)


def extract_verilog_blocks(text):
    results = []
    chunks = re.split(r'```(?:verilog|v|sv|systemverilog)?\s*\n', text, flags=re.IGNORECASE)
    for chunk in chunks[1:]:
        end = chunk.find('```')
        code = (chunk[:end] if end >= 0 else chunk).strip()
        if not code or 'module' not in code:
            continue
        fname_match = re.search(r'//\s*FILE:\s*(\S+\.v)', code)
        if fname_match:
            fname = fname_match.group(1)
        else:
            mod_match = re.search(r'module\s+(\w+)', code)
            fname = (mod_match.group(1) + ".v") if mod_match else f"module_{len(results)}.v"
        results.append((fname, code))
    return results


def rtl_gen_from_yaml(yaml_str, rtl_gen_lib, output_dir, temp_dir, idx=0):
    """Call rtl_gen_main.py --spec <yaml> --outdir <dir>. Returns generated file list."""
    temp_dir = Path(temp_dir)
    temp_dir.mkdir(parents=True, exist_ok=True)
    yaml_path = temp_dir / f"spec_{idx:02d}.yaml"
    yaml_path.write_text(yaml_str, encoding="utf-8")

    gen_script = Path(rtl_gen_lib) / "rtl_gen_main.py"
    if not gen_script.is_file():
        print(f"[WARN] rtl_gen_main.py not found: {gen_script}", file=sys.stderr)
        return []

    result = subprocess.run(
        [sys.executable, str(gen_script), "--spec", str(yaml_path), "--outdir", str(output_dir)],
        capture_output=True, text=True, timeout=30,
    )
    if result.returncode != 0:
        print(f"[WARN] RTL gen failed for spec_{idx:02d}:\n{result.stderr[:400]}", file=sys.stderr)
        return []

    generated = [
        line.split("->")[1].strip().split()[0]
        for line in result.stdout.splitlines()
        if line.startswith("[GEN]")
    ]
    print(f"[RTL_GEN] spec_{idx:02d} → {generated}", file=sys.stderr)
    return generated


# ─── Agent steps ──────────────────────────────────────────────────────────────

def step1_read_inputs(info):
    """Read architecture doc and TB skeleton."""
    arch_path = Path(info["architecture_doc"])
    _, arch_doc = read_text(arch_path, "architecture doc", max_chars=20000)
    _, tb_skel  = read_text(info["tb_skeleton"], "TB skeleton", max_chars=5000)
    return arch_doc, tb_skel


def step2_infer_yaml_specs(info, arch_doc, tb_skel):
    """Ask model to infer YAML specs for each IP block. Extend the prompt as needed."""
    temp_dir = Path(info["temp_dir"])
    temp_dir.mkdir(parents=True, exist_ok=True)

    prompt = f"""\
You are an expert hardware design engineer participating in the NXP ICLAD 2026 contest.

## Architecture Documentation
{arch_doc}

## Testbench Port Contract
{tb_skel}

## Task
Read the architecture documentation above carefully.
For each IP block described, write a YAML specification in a ```yaml ... ``` code block.
Each block must include ip_type, name, and all relevant parameters.
Output ONLY the YAML blocks — no Verilog yet.
"""
    print(f"[STEP2] Sending YAML inference prompt ({len(prompt):,} chars)...", file=sys.stderr)
    response = call_model(
        info["model_endpoint"], prompt, info["model"],
        max_tokens=4096, max_retries=5,
        diagnostics_path=temp_dir / "yaml_inference_diagnostics.json",
    )
    (temp_dir / "yaml_response.txt").write_text(response, encoding="utf-8")

    yaml_blocks = extract_yaml_blocks(response)
    print(f"[STEP2] Extracted {len(yaml_blocks)} YAML block(s)", file=sys.stderr)
    return yaml_blocks


def step3_generate_ip_rtl(info, yaml_blocks):
    """Generate Verilog from each YAML block using rtl_gen_lib."""
    output_dir = Path(info["output_dir"])
    output_dir.mkdir(parents=True, exist_ok=True)

    generated = []
    for i, yaml_str in enumerate(yaml_blocks):
        print(f"[STEP3] Generating IP {i+1}/{len(yaml_blocks)}...", file=sys.stderr)
        files = rtl_gen_from_yaml(yaml_str, info["rtl_gen_lib"], output_dir, info["temp_dir"], idx=i)
        generated.extend(files)

    print(f"[STEP3] Total generated: {len(generated)} file(s)", file=sys.stderr)
    return generated


def step4_generate_soc_top(info, arch_doc, tb_skel, generated_files):
    """Ask model to write the SoC top-level stitching module. Extend the prompt as needed."""
    temp_dir = Path(info["temp_dir"])
    gen_summary = "\n".join(f"  - {Path(f).name}" for f in generated_files)

    prompt = f"""\
You are completing the RTL implementation of the NXP ICLAD 2026 {info['problem'].upper()} SoC.

## Architecture Documentation
{arch_doc[:6000]}

## Already Generated IP Modules
{gen_summary if gen_summary else "  (none generated yet — write all IPs from scratch)"}

## Testbench Port Contract (TOP MODULE MUST MATCH EXACTLY)
{tb_skel}

## Task
Write the complete synthesizable Verilog for the top-level SoC module.
The top module name and ports MUST match the testbench skeleton exactly.
Use only Verilog 2001 constructs (iverilog -g2005 compatible).
Output each file in a ```verilog ... ``` block with // FILE: <name>.v as the first comment.
"""
    print(f"[STEP4] Sending SoC top prompt ({len(prompt):,} chars)...", file=sys.stderr)
    response = call_model(
        info["model_endpoint"], prompt, info["model"],
        max_tokens=16384, max_retries=5,
        diagnostics_path=temp_dir / "soc_top_diagnostics.json",
    )
    (temp_dir / "soc_response.txt").write_text(response, encoding="utf-8")
    return response


def step5_save_verilog(info, soc_response):
    """Extract and write Verilog modules to output_dir."""
    output_dir = Path(info["output_dir"])
    output_dir.mkdir(parents=True, exist_ok=True)

    saved = []
    for fname, code in extract_verilog_blocks(soc_response):
        fpath = output_dir / fname
        fpath.write_text(code + "\n", encoding="utf-8")
        print(f"[STEP5] Saved: {fpath}", file=sys.stderr)
        saved.append(str(fpath))

    print(f"[STEP5] Total Verilog files saved: {len(saved)}", file=sys.stderr)
    return saved


# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="NXP ICLAD 2026 — Vertex AI Express Mode agent"
    )
    parser.add_argument("info_json", help="Path to info.json produced by runner/run_benchmark.py")
    parser.add_argument("--model", default="gemini-2.0-flash-exp")
    parser.add_argument("--max-retries", type=int, default=5)
    args = parser.parse_args()

    with Path(args.info_json).open(encoding="utf-8") as f:
        info = json.load(f)

    if args.model:
        info["model"] = args.model

    if not info.get("model_endpoint"):
        raise RuntimeError(
            "model_endpoint missing from info.json. "
            "Run via runner/run_benchmark.py."
        )

    print(f"[INFO] Problem:    {info['problem']}", file=sys.stderr, flush=True)
    print(f"[INFO] Model:      {info['model']}", file=sys.stderr, flush=True)
    print(f"[INFO] Endpoint:   {info['model_endpoint']}", file=sys.stderr, flush=True)
    print(f"[INFO] Output dir: {info['output_dir']}", file=sys.stderr, flush=True)

    Path(info["output_dir"]).mkdir(parents=True, exist_ok=True)
    Path(info["temp_dir"]).mkdir(parents=True, exist_ok=True)

    arch_doc, tb_skel = step1_read_inputs(info)
    yaml_blocks       = step2_infer_yaml_specs(info, arch_doc, tb_skel)
    generated         = step3_generate_ip_rtl(info, yaml_blocks) if yaml_blocks else []
    if not yaml_blocks:
        print("[WARN] No YAML blocks extracted — skipping library generation", file=sys.stderr)
    soc_response      = step4_generate_soc_top(info, arch_doc, tb_skel, generated)
    saved             = step5_save_verilog(info, soc_response)

    print(f"[DONE] {len(saved)} Verilog file(s) written to {info['output_dir']}",
          file=sys.stderr, flush=True)

    if not saved:
        print("[ERROR] No Verilog files generated!", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
