# Dependencies

## System Tools

| Tool | Version | Purpose |
|---|---:|---|
| Python | 3.8 or newer | Runner, agent, and evaluator scripts |
| iverilog | 10.0 or newer | Compiling and simulating generated Verilog RTL |
| vvp | bundled with iverilog | Running compiled simulation |

Verify iverilog:

```bash
iverilog -V
```

Expected output (example):

```text
Icarus Verilog version 10.3 (stable)
```

Verify Python:

```bash
python3 --version
```

Expected output (example):

```text
Python 3.10.12
```

## Python Packages

The benchmark runner, agents, and evaluator use only Python standard library modules:

```
argparse    json    re    subprocess    sys
threading   time    urllib.request    urllib.error
pathlib     contextlib
```

**No `pip install` is required** for the provided scripts.

Optional — install `pyyaml` for cleaner YAML handling in your own agent:

```bash
pip install pyyaml
```

## Vertex AI Express Mode

The benchmark model service uses Vertex AI Express Mode. Set the API key in the shell that runs the benchmark:

```bash
export EXPRESS_MODE_KEY="your_actual_api_key_here"
```

The runner passes the key to the local model service, which proxies all model calls. Your agent never handles API keys directly — it calls the local endpoint at `http://127.0.0.1:<port>/generate` as specified in `info.json`.

## Quick Verify

Run this after setup to confirm everything works:

```bash
# 1. Check iverilog
iverilog -V

# 2. Verify RTL generation library
python3 rtl_gen_lib/rtl_gen_main.py --demo
