#!/usr/bin/env python3
"""
NXP ICLAD 2026 — Design Evaluator
===================================
Compiles and simulates participant-submitted RTL against the hidden golden TB.
Parses simulation output and produces a structured score JSON.

Usage:
  python3 evaluate.py --problem easy --rtl_dir ./my_rtl/ --run_id my_agent_v1

The evaluator:
  1. Collects all .v files from rtl_dir
  2. Compiles with: iverilog -g2005 <rtl_files> <golden_tb>
  3. Simulates with: vvp sim_binary
  4. Parses [PASS]/[FAIL] lines from stdout
  5. Writes factors/<run_id>/<problem>_score.json
"""

import argparse
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path


PROBLEMS = {
    "easy": {
        "top_module": "secure_periph_soc",
        "golden_tb":  "problems/easy/golden_tb/tb_secure_periph_soc.v",
        "timeout_s":  120,
        "categories": {
            "basic_rw":       list(range(101, 105)),
            "uart_tx":        list(range(201, 204)),
            "gpio_irq":       list(range(301, 304)),
            "timer":          list(range(401, 404)),
            "watchdog":       list(range(501, 503)),
            "privilege":      list(range(601, 604)),
            "irq_aggregator": list(range(701, 703)),
            "reset_sync":     list(range(801, 803)),
        },
    },
    # medium and hard problems coming in a future release
}

REPO_ROOT = Path(__file__).resolve().parents[1]


def find_rtl_files(rtl_dir):
    """Collect all .v files from the submitted RTL directory."""
    rtl_path = Path(rtl_dir)
    if not rtl_path.is_dir():
        raise FileNotFoundError(f"RTL directory not found: {rtl_dir}")
    files = sorted(rtl_path.glob("**/*.v"))
    if not files:
        raise FileNotFoundError(f"No .v files found in {rtl_dir}")
    return [str(f) for f in files]


def compile_design(rtl_files, golden_tb, out_bin, problem):
    """Compile RTL + golden TB with iverilog."""
    tb_path = REPO_ROOT / golden_tb
    if not tb_path.is_file():
        return False, f"Golden TB not found: {tb_path}", ""

    cmd = ["iverilog", "-g2005", "-o", str(out_bin)] + rtl_files + [str(tb_path)]
    t0 = time.time()
    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=60
        )
        elapsed = time.time() - t0
        stderr = result.stderr.strip()
        if result.returncode != 0:
            return False, stderr, f"Compilation failed in {elapsed:.1f}s"
        return True, stderr, f"Compilation OK in {elapsed:.1f}s"
    except subprocess.TimeoutExpired:
        return False, "Compilation timed out", ""
    except FileNotFoundError:
        return False, "iverilog not found on PATH", ""


def simulate_design(sim_bin, timeout_s, workdir):
    """Run simulation and capture output."""
    cmd = ["vvp", str(sim_bin)]
    t0 = time.time()
    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True,
            timeout=timeout_s, cwd=str(workdir)
        )
        elapsed = time.time() - t0
        stdout = result.stdout
        stderr = result.stderr
        return True, stdout, stderr, elapsed
    except subprocess.TimeoutExpired:
        return False, "", f"Simulation timeout after {timeout_s}s", timeout_s
    except FileNotFoundError:
        return False, "", "vvp not found on PATH", 0.0


def parse_results(stdout, categories):
    """
    Parse [PASS] T<id> and [FAIL] T<id> lines from simulation output.
    Returns: pass_count, fail_count, per_category scores, full test map
    """
    pass_ids = set()
    fail_ids = set()

    for line in stdout.splitlines():
        m = re.match(r'\[(PASS|FAIL)\]\s+T(\d+)', line)
        if m:
            status, tid = m.group(1), int(m.group(2))
            if status == "PASS":
                pass_ids.add(tid)
            else:
                fail_ids.add(tid)

    # Overall
    total = len(pass_ids) + len(fail_ids)
    passed = len(pass_ids)
    failed = len(fail_ids)

    # Per-category
    cat_scores = {}
    for cat, tids in categories.items():
        cat_pass = sum(1 for t in tids if t in pass_ids)
        cat_total = len(tids)
        cat_scores[cat] = {
            "passed": cat_pass,
            "total":  cat_total,
            "score":  round(100.0 * cat_pass / cat_total, 1) if cat_total else 0.0,
        }

    overall_pct = round(100.0 * passed / total, 1) if total else 0.0

    return {
        "passed": passed,
        "failed": failed,
        "total":  total,
        "score_pct": overall_pct,
        "categories": cat_scores,
        "pass_ids": sorted(pass_ids),
        "fail_ids": sorted(fail_ids),
    }


def parse_summary_line(stdout):
    """Extract SCORE: X/Y from simulation output."""
    m = re.search(r'SCORE:\s*(\d+)/(\d+)', stdout)
    if m:
        return int(m.group(1)), int(m.group(2))
    return None, None


def evaluate(problem, rtl_dir, run_id, output_dir=None):
    """Full evaluation pipeline."""
    if problem not in PROBLEMS:
        print(f"ERROR: Unknown problem '{problem}'. Choose from: {list(PROBLEMS)}")
        return None

    cfg = PROBLEMS[problem]
    print(f"\n{'='*60}")
    print(f"NXP ICLAD 2026 Evaluator — problem={problem}, run_id={run_id}")
    print(f"{'='*60}")

    # Output directory
    out_dir = Path(output_dir or (REPO_ROOT / "factors" / run_id / problem))
    out_dir.mkdir(parents=True, exist_ok=True)

    result = {
        "run_id":  run_id,
        "problem": problem,
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "compilation": {"success": False, "warnings": 0, "errors": "", "notes": ""},
        "simulation":  {"success": False, "elapsed_s": 0.0, "stdout": "", "stderr": ""},
        "test_results": None,
        "score": 0.0,
    }

    # Step 1: Find RTL files
    try:
        rtl_files = find_rtl_files(rtl_dir)
        print(f"Found {len(rtl_files)} RTL file(s) in {rtl_dir}")
    except FileNotFoundError as e:
        result["compilation"]["errors"] = str(e)
        _write_result(result, out_dir, problem)
        return result

    # Step 2: Compile
    sim_bin = out_dir / f"sim_{problem}_{run_id}"
    print(f"Compiling...")
    ok, stderr, note = compile_design(rtl_files, cfg["golden_tb"], sim_bin, problem)
    warnings = len([l for l in stderr.splitlines() if "warning" in l.lower()])
    result["compilation"] = {
        "success":  ok,
        "warnings": warnings,
        "errors":   stderr if not ok else "",
        "notes":    note,
    }
    if not ok:
        print(f"COMPILATION FAILED:\n{stderr}")
        _write_result(result, out_dir, problem)
        return result
    print(f"  {note}  ({warnings} warnings)")

    # Step 3: Simulate
    print(f"Simulating (timeout={cfg['timeout_s']}s)...")
    workdir = out_dir
    ok_sim, stdout, stderr_sim, elapsed = simulate_design(sim_bin, cfg["timeout_s"], workdir)
    result["simulation"] = {
        "success":   ok_sim,
        "elapsed_s": round(elapsed, 2),
        "stdout":    stdout,
        "stderr":    stderr_sim,
    }
    if not ok_sim:
        print(f"SIMULATION FAILED: {stderr_sim}")
        _write_result(result, out_dir, problem)
        return result
    print(f"  Simulation completed in {elapsed:.1f}s")

    # Step 4: Parse results
    test_results = parse_results(stdout, cfg["categories"])
    result["test_results"] = test_results
    result["score"] = test_results["score_pct"]

    # Print summary
    print(f"\n{'─'*50}")
    print(f"RESULTS: {test_results['passed']}/{test_results['total']} tests passed")
    print(f"SCORE  : {result['score']:.1f}%")
    print(f"{'─'*50}")
    print("Category breakdown:")
    for cat, cs in test_results["categories"].items():
        bar = "█" * cs["passed"] + "░" * (cs["total"] - cs["passed"])
        print(f"  {cat:20s}  [{bar}]  {cs['passed']}/{cs['total']}  ({cs['score']:.0f}%)")
    if test_results["fail_ids"]:
        print(f"Failed test IDs: {test_results['fail_ids']}")
    print(f"{'─'*50}")

    _write_result(result, out_dir, problem)
    print(f"\nScore JSON written to: {out_dir}/{problem}_score.json")
    return result


def _write_result(result, out_dir, problem):
    out_path = out_dir / f"{problem}_score.json"
    # Don't include full stdout in the JSON (can be large)
    result_slim = dict(result)
    if result_slim.get("simulation", {}).get("stdout"):
        result_slim["simulation"]["stdout"] = "[see simulation log]"
    out_path.write_text(json.dumps(result_slim, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(
        description="NXP ICLAD 2026 Design Evaluator",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    parser.add_argument("--problem", required=True, choices=list(PROBLEMS),
                        help="Problem difficulty level")
    parser.add_argument("--rtl_dir", required=True,
                        help="Directory containing participant's .v files")
    parser.add_argument("--run_id",  default="default",
                        help="Run identifier for output naming")
    parser.add_argument("--output_dir", default=None,
                        help="Output directory for score JSON (default: factors/<run_id>/<problem>)")
    args = parser.parse_args()

    result = evaluate(args.problem, args.rtl_dir, args.run_id, args.output_dir)
    if result is None or result["score"] == 0.0:
        sys.exit(1)


if __name__ == "__main__":
    main()
