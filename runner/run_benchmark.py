#!/usr/bin/env python3
"""
NXP ICLAD 2026 — Benchmark Runner
====================================
Orchestrates the full benchmark: creates info.json, starts the model service,
invokes the participant's agent, then calls the evaluator.

Usage:
  python3 run_benchmark.py --problem easy --agent agent/starter_agent.py
  python3 run_benchmark.py --problem easy --agent my_agent.py --run-id my_v1
  python3 run_benchmark.py --problem easy --prepare-only

Available problems: easy  (medium and hard coming in a future release)
"""

import argparse
import contextlib
import json
import os
import socket
import subprocess
import sys
import time
import urllib.request
from pathlib import Path


REPO_ROOT   = Path(__file__).resolve().parents[1]
DEFAULT_AGENT = "agent/starter_agent.py"
DEFAULT_MODEL = "gemini-2.0-flash-exp"

PROBLEMS = ["easy"]  # medium and hard coming in a future release

PROBLEM_CONFIG = {
    "easy": {
        "top_module":       "secure_periph_soc",
        "architecture_doc": "problems/easy/docs/architecture.md",
        "tb_skeleton":      "problems/easy/tb/tb_top_skeleton.v",
        "golden_tb":        "problems/easy/golden_tb/tb_secure_periph_soc.v",
    },
}


def find_free_port():
    with contextlib.closing(socket.socket(socket.AF_INET, socket.SOCK_STREAM)) as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def wait_for_service(url, process, timeout=20):
    deadline = time.monotonic() + timeout
    last_error = None
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError(f"Model service exited with code {process.returncode}")
        try:
            with urllib.request.urlopen(url + "/health", timeout=1) as r:
                if r.status == 200:
                    return
        except Exception as e:
            last_error = e
            time.sleep(0.2)
    raise RuntimeError(f"Model service not ready after {timeout}s: {last_error}")


def write_info_json(problem, run_id, model_name, model_endpoint=""):
    """Create the info.json file consumed by the agent."""
    cfg = PROBLEM_CONFIG[problem]

    out_dir   = REPO_ROOT / "result"   / run_id / problem
    task_dir  = REPO_ROOT / "task"     / run_id / problem
    temp_dir  = REPO_ROOT / "temp"     / run_id / problem
    usage_dir = REPO_ROOT / "usage"    / run_id / problem

    for d in [out_dir, task_dir, temp_dir, usage_dir]:
        d.mkdir(parents=True, exist_ok=True)

    info = {
        "run_id":           run_id,
        "model":            model_name,
        "model_endpoint":   model_endpoint,
        "problem":          problem,
        "architecture_doc": str(REPO_ROOT / cfg["architecture_doc"]),
        "tb_skeleton":      str(REPO_ROOT / cfg["tb_skeleton"]),
        "rtl_gen_lib":      str(REPO_ROOT / "rtl_gen_lib"),
        "output_dir":       str(out_dir),
        "temp_dir":         str(temp_dir),
        "usage_path":       str(usage_dir / f"{problem}_usage.json"),
    }

    info_path = task_dir / f"{problem}_info.json"
    info_path.write_text(json.dumps(info, indent=2) + "\n", encoding="utf-8")
    return info_path, out_dir


@contextlib.contextmanager
def model_service(run_id, problem, model_name):
    """Start the benchmark model service and yield its endpoint URL."""
    model_svc = REPO_ROOT / "scripts" / "model_service.py"
    if not model_svc.is_file():
        # No local model service — expect external endpoint
        yield ""
        return

    port = find_free_port()
    endpoint = f"http://127.0.0.1:{port}"
    cmd = [
        sys.executable, str(model_svc),
        "--port", str(port),
        "--model", model_name,
        "--run-id", run_id,
        "--problem", problem,
    ]
    proc = subprocess.Popen(cmd, env=os.environ.copy())
    try:
        wait_for_service(endpoint, proc)
        print(f"[RUNNER] Model service ready at {endpoint}")
        yield endpoint
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill(); proc.wait()


def run_agent(agent_path, info_path, model_name):
    cmd = [sys.executable, str(agent_path), str(info_path), "--model", model_name]
    print(f"[RUNNER] Invoking agent: {' '.join(cmd)}")
    subprocess.run(cmd, check=True)


def run_evaluator(problem, output_dir, run_id):
    eval_script = REPO_ROOT / "evaluator" / "evaluate.py"
    cmd = [
        sys.executable, str(eval_script),
        "--problem", problem,
        "--rtl_dir", str(output_dir),
        "--run_id",  run_id,
    ]
    print(f"[RUNNER] Evaluating with: {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=False, text=True)
    return result.returncode == 0


def update_endpoint(info_path, endpoint):
    with open(info_path) as f:
        info = json.load(f)
    info["model_endpoint"] = endpoint
    info_path.write_text(json.dumps(info, indent=2) + "\n", encoding="utf-8")


def run_problem(problem, args):
    print(f"\n{'='*60}")
    print(f"[RUNNER] Problem: {problem.upper()}")
    print(f"[RUNNER] Run ID : {args.run_id}")
    print(f"{'='*60}")

    # Create info.json
    info_path, output_dir = write_info_json(problem, args.run_id, args.model)
    print(f"[RUNNER] Info JSON: {info_path}")
    print(f"[RUNNER] Output dir: {output_dir}")

    if args.prepare_only:
        print(f"[RUNNER] --prepare-only: stopping here.")
        return True

    agent_path = Path(args.agent)
    if not agent_path.is_absolute():
        agent_path = REPO_ROOT / agent_path
    if not agent_path.is_file():
        print(f"[RUNNER] ERROR: Agent not found: {agent_path}")
        return False

    if args.model_endpoint:
        # Use existing external endpoint
        update_endpoint(info_path, args.model_endpoint)
        run_agent(agent_path, info_path, args.model)
    else:
        with model_service(args.run_id, problem, args.model) as endpoint:
            if endpoint:
                update_endpoint(info_path, endpoint)
            run_agent(agent_path, info_path, args.model)

    if not args.skip_eval:
        ok = run_evaluator(problem, output_dir, args.run_id)
        return ok
    return True


def main():
    parser = argparse.ArgumentParser(
        description="NXP ICLAD 2026 Benchmark Runner",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    parser.add_argument("--problem",  default="easy",
                        help="Problem to run: easy  (medium/hard coming later)")
    parser.add_argument("--agent",    default=DEFAULT_AGENT,
                        help="Path to agent script (relative to repo root)")
    parser.add_argument("--model",    default=DEFAULT_MODEL)
    parser.add_argument("--run-id",   default="starter-agent",
                        help="Identifier for this run (affects output paths)")
    parser.add_argument("--model-endpoint", default="",
                        help="Use an existing model endpoint instead of starting one")
    parser.add_argument("--prepare-only", action="store_true",
                        help="Write info.json only — do not invoke agent or evaluator")
    parser.add_argument("--skip-eval", action="store_true",
                        help="Run agent but skip evaluation step")
    args = parser.parse_args()

    problems = PROBLEMS if args.problem == "all" else [args.problem]
    if args.problem not in PROBLEMS and args.problem != "all":
        parser.error(f"Unknown problem '{args.problem}'. Choose: {PROBLEMS + ['all']}")

    success = True
    for prob in problems:
        ok = run_problem(prob, args)
        if not ok:
            success = False

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
