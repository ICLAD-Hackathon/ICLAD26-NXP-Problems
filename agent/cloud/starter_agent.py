#!/usr/bin/env python3
"""
NXP ICLAD 2026 — Starter Agent Stub
=====================================
This starter agent demonstrates the required interface between the runner,
the model endpoint, and the RTL generation library.

Your agent MUST:
  1. Read the info.json provided by the runner
  2. Use the model endpoint for all LLM calls
  3. Write generated .v files to output_dir/
  4. NOT hardcode solutions (model must do the reasoning)

Interface:
  python3 your_agent.py <info_json_path> --model <model_name>

The info.json contains:
  {
    "run_id":         "<run_id>",
    "model":          "<model_name>",
    "model_endpoint": "http://127.0.0.1:<port>",
    "problem":        "easy",
    "architecture_doc": "<path to architecture.md>",
    "tb_skeleton":    "<path to tb_top_skeleton.v>",
    "rtl_gen_lib":    "<path to rtl_gen_lib/>",
    "output_dir":     "<where to write .v files>",
    "temp_dir":       "<scratch directory>",
    "usage_path":     "<token usage output path>"
  }

Starter agent strategy (replace with your own):
  Step 1: Read architecture_doc and tb_skeleton
  Step 2: Ask model to infer YAML specs for each IP block
  Step 3: Use rtl_gen_lib to generate Verilog from YAML
  Step 4: Ask model to write the top-level SoC stitching module
  Step 5: Write all files to output_dir
"""

import argparse
import json
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path


# ─────────────────────────────────────────────────────────────────────────────
# Model endpoint interface
# ─────────────────────────────────────────────────────────────────────────────

RETRYABLE_STATUS = {429, 500, 502, 503, 504}

def call_model(endpoint, prompt, model, max_tokens=8192, max_retries=5):
    """Send a prompt to the benchmark model endpoint and return text response."""
    url = endpoint.rstrip("/") + "/generate"
    body = json.dumps({
        "model":            model,
        "prompt":           prompt,
        "max_output_tokens": max_tokens,
    }).encode("utf-8")

    delay = 2
    for attempt in range(1, max_retries + 1):
        print(f"[MODEL] Attempt {attempt}/{max_retries}...", file=sys.stderr, flush=True)
        try:
            req = urllib.request.Request(
                url, data=body,
                headers={"Content-Type": "application/json"},
                method="POST"
            )
            with urllib.request.urlopen(req, timeout=300) as resp:
                payload = json.loads(resp.read().decode("utf-8"))
            text = payload.get("text", "")
            if text.strip():
                return text
            print("[WARN] Empty model response", file=sys.stderr)
            return ""
        except urllib.error.HTTPError as e:
            err_body = e.read().decode("utf-8", errors="replace")
            try:
                err_json = json.loads(err_body)
            except Exception:
                err_json = {}
            retryable = err_json.get("retryable", False) or e.code in RETRYABLE_STATUS
            if not retryable or attempt == max_retries:
                raise RuntimeError(f"Model error {e.code}: {err_body}")
            print(f"[WARN] Retryable error {e.code}, retrying in {delay}s", file=sys.stderr)
            time.sleep(delay); delay = min(delay * 2, 60)
        except urllib.error.URLError as e:
            if attempt == max_retries:
                raise RuntimeError(f"Cannot reach model endpoint: {e}")
            print(f"[WARN] Connection error, retrying in {delay}s", file=sys.stderr)
            time.sleep(delay); delay = min(delay * 2, 60)
    raise RuntimeError("Max retries exceeded")


# ─────────────────────────────────────────────────────────────────────────────
# Utility
# ─────────────────────────────────────────────────────────────────────────────

def extract_yaml_blocks(text):
    """Extract all YAML code blocks from model response."""
    blocks = re.findall(r'```(?:yaml|yml)?\s*\n(.*?)```', text, re.DOTALL | re.IGNORECASE)
    return blocks


def extract_verilog_blocks(text):
    """Extract all Verilog code blocks from model response."""
    blocks = re.findall(r'```(?:verilog|v|systemverilog|sv)?\s*\n(.*?)```', text, re.DOTALL | re.IGNORECASE)
    if not blocks:
        # Try to find module...endmodule patterns
        blocks = re.findall(r'(module\s+\w+.*?endmodule)', text, re.DOTALL)
    return blocks


def save_yaml_and_generate(yaml_content, rtl_gen_lib_path, output_dir, temp_dir):
    """
    Write YAML to temp file, call rtl_gen_main.py to generate Verilog.
    Returns list of generated file paths.
    """
    import subprocess, tempfile, os

    # Write YAML to temp file
    yaml_path = Path(temp_dir) / "spec_temp.yaml"
    yaml_path.write_text(yaml_content, encoding="utf-8")

    # Call the RTL generation library
    gen_script = Path(rtl_gen_lib_path) / "rtl_gen_main.py"
    if not gen_script.is_file():
        print(f"[WARN] RTL gen library not found at {gen_script}", file=sys.stderr)
        return []

    cmd = [sys.executable, str(gen_script), "--spec", str(yaml_path), "--outdir", str(output_dir)]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    if result.returncode != 0:
        print(f"[WARN] RTL generation failed: {result.stderr}", file=sys.stderr)
        return []

    # Collect generated files
    generated = [l.split("->")[1].strip().split()[0] for l in result.stdout.splitlines()
                 if l.startswith("[GEN]")]
    print(f"[RTL_GEN] Generated: {generated}", file=sys.stderr)
    return generated


# ─────────────────────────────────────────────────────────────────────────────
# Agent steps
# ─────────────────────────────────────────────────────────────────────────────

def step1_read_inputs(info):
    """Read architecture doc and TB skeleton."""
    arch_path = Path(info["architecture_doc"])
    tb_path   = Path(info["tb_skeleton"])

    arch_doc = arch_path.read_text(encoding="utf-8") if arch_path.is_file() else ""
    tb_skel  = tb_path.read_text(encoding="utf-8")   if tb_path.is_file()  else ""

    print(f"[STEP1] Read architecture doc ({len(arch_doc):,} chars)", file=sys.stderr)
    print(f"[STEP1] Read TB skeleton ({len(tb_skel):,} chars)", file=sys.stderr)
    return arch_doc, tb_skel


def step2_infer_yaml_specs(info, arch_doc, tb_skel):
    """
    Ask the model to infer YAML specifications for each IP block
    from the architecture diagram and IP descriptions.
    """
    prompt = f"""\
You are an expert hardware design engineer participating in the NXP ICLAD 2026 contest.

Your task: Design and implement a "{info['problem'].upper()}" level SoC in Verilog.

## Architecture Documentation
{arch_doc[:8000]}

## Testbench Port Contract
The top-level module MUST match this exact interface:
{tb_skel[:3000]}

## Your Task (Step 1 of 2)
Read the architecture documentation above carefully.
For each IP block described, write a YAML specification that captures:
- ip_type (must be one of: sync_fifo, async_fifo, sram_sp, sram_dp, reset_sync, cdc_sync,
  apb_uart, apb_gpio, apb_timer, apb_watchdog, irq_aggregator, ahb_to_apb_bridge, apb_fabric,
  axi_lite_crossbar, axi_lite_sram, dma_engine, perf_counter, tilelink_router, tilelink_ni, aes128)
- name (Verilog module name)
- All relevant parameters (widths, depths, timeouts, etc.)

Output EACH IP as a separate ```yaml ... ``` code block.
DO NOT output Verilog yet — only YAML specifications.
"""
    print("[STEP2] Asking model to infer YAML specs...", file=sys.stderr)
    response = call_model(info["model_endpoint"], prompt, info["model"], max_tokens=4096)
    yaml_blocks = extract_yaml_blocks(response)
    print(f"[STEP2] Got {len(yaml_blocks)} YAML block(s)", file=sys.stderr)
    return yaml_blocks, response


def step3_generate_ip_rtl(info, yaml_blocks):
    """Generate Verilog for each IP using the RTL generation library."""
    output_dir = Path(info["output_dir"])
    temp_dir   = Path(info["temp_dir"])
    output_dir.mkdir(parents=True, exist_ok=True)
    temp_dir.mkdir(parents=True, exist_ok=True)

    generated_files = []
    for i, yaml_str in enumerate(yaml_blocks):
        print(f"[STEP3] Generating IP {i+1}/{len(yaml_blocks)}...", file=sys.stderr)
        files = save_yaml_and_generate(yaml_str, info["rtl_gen_lib"], output_dir, temp_dir)
        generated_files.extend(files)

    print(f"[STEP3] Total generated files: {len(generated_files)}", file=sys.stderr)
    return generated_files


def step4_generate_soc_top(info, arch_doc, tb_skel, generated_files):
    """Ask model to write the SoC top-level stitching module."""
    # List what was generated so model knows what IPs are available
    gen_summary = "\n".join(f"  - {Path(f).name}" for f in generated_files)

    prompt = f"""\
You are completing the RTL implementation of the "{info['problem'].upper()}" SoC.

## Architecture Documentation
{arch_doc[:6000]}

## Already Generated IP Modules
{gen_summary if gen_summary else "  (none generated yet — write all IPs from scratch)"}

## Testbench Port Contract (TOP MODULE INTERFACE)
The top-level module MUST be named exactly as shown and have EXACTLY these ports:
{tb_skel[:4000]}

## Your Task
Write the complete, synthesizable Verilog implementation.

Requirements:
1. The top module MUST have EXACTLY the ports shown in the TB skeleton above
2. Instantiate and connect all IP modules
3. Use only synthesizable Verilog 2001 constructs (compatible with iverilog -g2005)
4. Include proper wire declarations for all internal connections
5. Reset synchronizer must feed sys_rst_n to all registers
6. APB/AXI address map must match the architecture documentation

Output ALL Verilog files, each in a separate ```verilog ... ``` code block.
Include the module name as a comment at the top of each block.
Start each block with: // FILE: <module_name>.v
"""
    print("[STEP4] Asking model to generate SoC top and any missing IPs...", file=sys.stderr)
    response = call_model(info["model_endpoint"], prompt, info["model"], max_tokens=16384)
    return response


def step5_save_verilog(info, model_response):
    """Extract and save Verilog modules from model response."""
    output_dir = Path(info["output_dir"])
    output_dir.mkdir(parents=True, exist_ok=True)

    # Try to find file markers like "// FILE: foo.v"
    saved = []
    chunks = re.split(r'```(?:verilog|v|sv)?\s*\n', model_response, flags=re.IGNORECASE)
    for chunk in chunks[1:]:
        end = chunk.find('```')
        if end < 0:
            code = chunk.strip()
        else:
            code = chunk[:end].strip()
        if not code or 'module' not in code:
            continue

        # Determine filename
        fname_match = re.search(r'//\s*FILE:\s*(\S+\.v)', code)
        if fname_match:
            fname = fname_match.group(1)
        else:
            mod_match = re.search(r'module\s+(\w+)', code)
            fname = (mod_match.group(1) + ".v") if mod_match else f"module_{len(saved)}.v"

        fpath = output_dir / fname
        fpath.write_text(code + "\n", encoding="utf-8")
        print(f"[STEP5] Saved: {fpath}", file=sys.stderr)
        saved.append(str(fpath))

    print(f"[STEP5] Total Verilog files saved: {len(saved)}", file=sys.stderr)
    return saved


# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="NXP ICLAD 2026 Starter Agent")
    parser.add_argument("info_json", help="Path to info.json from the runner")
    parser.add_argument("--model",   default="gemini-2.0-flash-exp")
    args = parser.parse_args()

    # Load info.json
    with open(args.info_json, encoding="utf-8") as f:
        info = json.load(f)

    # Override model if specified
    if args.model:
        info["model"] = args.model

    print(f"[INFO] Starting agent: problem={info['problem']}, model={info['model']}",
          file=sys.stderr, flush=True)
    print(f"[INFO] Model endpoint: {info['model_endpoint']}", file=sys.stderr)
    print(f"[INFO] Output dir: {info['output_dir']}", file=sys.stderr)

    # === Agent Pipeline ===
    # Step 1: Read architecture documentation
    arch_doc, tb_skel = step1_read_inputs(info)

    # Step 2: Ask model to infer YAML specs from architecture docs
    yaml_blocks, yaml_response = step2_infer_yaml_specs(info, arch_doc, tb_skel)

    # Step 3: Generate Verilog from YAML using the RTL gen library
    if yaml_blocks:
        generated = step3_generate_ip_rtl(info, yaml_blocks)
    else:
        print("[WARN] No YAML specs extracted — skipping library generation", file=sys.stderr)
        generated = []

    # Save YAML response for debugging
    temp_dir = Path(info["temp_dir"])
    temp_dir.mkdir(parents=True, exist_ok=True)
    (temp_dir / "yaml_response.txt").write_text(yaml_response, encoding="utf-8")

    # Step 4: Ask model to write SoC top-level + any missing IPs
    soc_response = step4_generate_soc_top(info, arch_doc, tb_skel, generated)
    (temp_dir / "soc_response.txt").write_text(soc_response, encoding="utf-8")

    # Step 5: Save all Verilog files
    saved = step5_save_verilog(info, soc_response)

    print(f"[DONE] Agent complete. {len(saved)} Verilog file(s) written to {info['output_dir']}",
          file=sys.stderr, flush=True)

    if not saved:
        print("[ERROR] No Verilog files were generated!", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
