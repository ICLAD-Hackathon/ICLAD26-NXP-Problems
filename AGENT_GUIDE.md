# Agent Guide — NXP ICLAD 2026

This guide explains the complete interface for building a custom agent.

## Agent Contract

The runner invokes your agent as:

```bash
python3 your_agent.py <info_json_path> --model <model_name>
```

Your agent MUST:
1. Read `<info_json_path>` (JSON file created by the runner)
2. Send ALL model calls to the `model_endpoint` in that JSON
3. Write ALL generated `.v` files to `output_dir` in that JSON
4. Exit with code 0 on success, non-zero on failure

---

## `info.json` Structure

```json
{
  "run_id":           "my_agent_v1",
  "model":            "gemini-2.0-flash-exp",
  "model_endpoint":   "http://127.0.0.1:<port>",
  "problem":          "easy",
  "architecture_doc": "/abs/path/problems/easy/docs/architecture.md",
  "tb_skeleton":      "/abs/path/problems/easy/tb/tb_top_skeleton.v",
  "rtl_gen_lib":      "/abs/path/rtl_gen_lib/",
  "output_dir":       "/abs/path/result/my_agent_v1/easy/",
  "temp_dir":         "/abs/path/temp/my_agent_v1/easy/",
  "usage_path":       "/abs/path/usage/my_agent_v1/easy/easy_usage.json"
}
```

| Field | Description |
|-------|-------------|
| `run_id` | Unique identifier for this run |
| `model` | Default model name to use |
| `model_endpoint` | Local benchmark model service URL — ALL LLM calls go here |
| `problem` | `easy` (medium/hard in a future release) |
| `architecture_doc` | Path to architecture diagram + IP descriptions |
| `tb_skeleton` | Path to TB skeleton with exact port contract |
| `rtl_gen_lib` | Path to RTL generation library directory |
| `output_dir` | **Write all generated `.v` files here** |
| `temp_dir` | Scratch space for intermediate files |
| `usage_path` | Token usage written here by model service |

---

## Model Endpoint API

### POST `/generate`

```http
POST http://127.0.0.1:<port>/generate
Content-Type: application/json

{
  "model":            "gemini-2.0-flash-exp",
  "prompt":           "your prompt here",
  "max_output_tokens": 8192
}
```

**Response (success)**:
```json
{
  "text":        "model response text",
  "diagnostics": {}
}
```

**Response (error)**:
```json
{
  "error":           "error message",
  "retryable":       true,
  "provider":        "vertexai",
  "provider_status": 429
}
```

When `retryable=true` or status is `429/500/502/503/504`, implement exponential backoff.

### GET `/health`

Returns `200 OK` when the service is ready.

---

## RTL Generation Library

The library converts YAML specifications to iverilog-compatible Verilog.

### CLI Usage

```bash
# Generate one IP
python3 rtl_gen_lib/rtl_gen_main.py --spec my_spec.yaml --outdir ./output/

# List variants
python3 rtl_gen_lib/rtl_gen_main.py --spec my_spec.yaml --list-variants

# Show documentation and examples
python3 rtl_gen_lib/rtl_gen_main.py --demo
```

### YAML Format

Every spec must have `ip_type` and `name`:

```yaml
ip_type: apb_uart
name:    debug_uart
fifo_depth: 16
default_div: 26
```

### Supported `ip_type` Values

| ip_type | Key Parameters |
|---------|----------------|
| `sync_fifo` | depth, data_width, fwft, almost_full_thresh |
| `async_fifo` | depth, data_width |
| `sram_sp` | depth, data_width (single-port, byte-enable) |
| `sram_dp` | depth, data_width (dual-port 1W+1R) |
| `reset_sync` | stages |
| `cdc_sync` | data_width, kind (2ff\|pulse) |
| `apb_uart` | fifo_depth, default_div |
| `apb_gpio` | gpio_width, debounce_sync |
| `apb_timer` | width (counter bits) |
| `apb_watchdog` | (default loads configurable) |
| `irq_aggregator` | (8-source, fixed) |
| `ahb_to_apb_bridge` | (fixed interface) |
| `apb_fabric` | timeout_cyc |
| `axi_lite_crossbar` | masters, slaves, data_width, addr_width, slave_ranges |
| `axi_lite_sram` | depth, data_width, addr_width |
| `dma_engine` | burst_len, data_width, addr_width |
| `perf_counter` | channels, counter_width |
| `tilelink_router` | node_x, node_y, num_ports, data_width, addr_width |
| `tilelink_ni` | data_width, addr_width |
| `aes128` | (fixed: 128-bit key, 10-round iterative) |

### Variant Examples

From one YAML, different parameter values produce different IP variants:

```
sync_fifo  depth=16  → small TX buffer
sync_fifo  depth=64  → large RX buffer
sync_fifo  fwft=true → first-word-fall-through FIFO
axi_lite_crossbar masters=2 slaves=3 → 2M×3S
axi_lite_crossbar masters=3 slaves=4 → 3M×4S
```

---

## Calling the Library from Your Agent

```python
import subprocess, sys

def generate_ip(yaml_content, rtl_gen_lib_path, output_dir, temp_dir):
    """Generate Verilog from a YAML spec string."""
    import tempfile
    from pathlib import Path

    # Write YAML to temp file
    yaml_path = Path(temp_dir) / "spec.yaml"
    yaml_path.write_text(yaml_content)

    # Run the generator
    result = subprocess.run(
        [sys.executable, str(Path(rtl_gen_lib_path) / "rtl_gen_main.py"),
         "--spec", str(yaml_path),
         "--outdir", str(output_dir)],
        capture_output=True, text=True, timeout=30
    )
    if result.returncode != 0:
        print(f"Generation failed: {result.stderr}")
        return []

    # Parse output file names
    return [l.split("->")[1].strip().split()[0]
            for l in result.stdout.splitlines() if l.startswith("[GEN]")]
```

---

## Output Requirements

1. **All `.v` files MUST go to `output_dir`**
2. **Top module name MUST match** exactly as in `tb_top_skeleton.v`
3. **All port names, widths, directions MUST match** the skeleton
4. **Only Verilog 2001 syntax** — compatible with `iverilog -g2005`
5. **No `$clog2` in non-synthesis context** — compute bit widths in Python instead
6. Files may be flat (all in `output_dir`) or in subdirectories; the evaluator
   recursively collects all `.v` files

---

## Evaluation

The evaluator compiles your RTL against the **hidden golden testbench** and runs simulation:

```bash
# What the evaluator does internally:
iverilog -g2005 -o sim your_rtl/*.v hidden_golden_tb.v
vvp sim
# Parse [PASS] T<id> / [FAIL] T<id> lines
```

Each test has a numeric ID (e.g., T101, T201). Tests are grouped by category.
Score = `passed / total × 100%`.

---

## Strategy Tips

### For Easy

- Focus on getting the AHB-to-APB bridge timing right (SETUP then ENABLE phase)
- The APB fabric must correctly decode 4KB address windows
- Watchdog requires the 2-step unlock sequence (magic key = 0xABCD1234)
- IRQ aggregator polarity: `irq_in = irq_src XOR ~polarity`

> **Note**: Strategy tips for Medium and Hard problems will be added in a future release.

---

## Running Your Agent

```bash
# Prepare benchmark case
python3 runner/run_benchmark.py --problem easy --prepare-only --run-id my_v1

# Run with external model endpoint
python3 runner/run_benchmark.py \
    --problem easy \
    --agent my_agent.py \
    --model gemini-2.0-flash-exp \
    --model-endpoint http://localhost:8080 \
    --run-id my_v1

# Evaluate results
python3 evaluator/evaluate.py --problem easy --rtl_dir result/my_v1/easy/ --run_id my_v1

# View score
cat factors/my_v1/easy/easy_score.json

---

## Vertex AI Express Mode Agent

A production-grade agent is provided in `agent/vertexai_express_agent.py`, adapted
from the ICLAD 2026 ASU reference implementation and upgraded for the NXP RTL task.

### Key differences from `starter_agent.py`

| Feature | `starter_agent.py` | `vertexai_express_agent.py` |
|---------|-------------------|----------------------------|
| Heartbeat | None | Background thread logs elapsed time every 15s |
| Retry logic | Basic backoff | `retryable` flag-aware + HTTP 429/5xx classification |
| Per-call diagnostics | None | Writes JSON diagnostics per model call to `temp_dir/` |
| YAML temp files | Single `spec_temp.yaml` | Indexed `spec_00.yaml … spec_N.yaml` (no overwrites) |
| Prompt content | Same minimal prompts | Same minimal prompts — extend `step2`/`step4` to improve |

### Usage

```bash
python3 agent/vertexai_express_agent.py <info_json> \
    --model gemini-2.0-flash-exp \
    --max-retries 5
```

### Agent Pipeline

```
Step 1  Read architecture.html (or .md) + tb_top_skeleton.v
        → Prefers HTML: richer embedded SVG diagrams give the model more visual context

Step 2  Model call → YAML inference prompt
        → Returns 8 ```yaml``` blocks, one per IP block
        → Saves raw response to temp_dir/yaml_response.txt
        → Saves diagnostics to temp_dir/yaml_inference_diagnostics.json

Step 3  rtl_gen_lib → generate Verilog from each YAML
        → Calls rtl_gen_main.py --spec spec_NN.yaml --outdir output_dir/
        → Collects generated file list from [GEN] lines

Step 4  Model call → SoC top-level prompt
        → Passes list of already-generated IPs so model only writes the stitching module
        → Returns ```verilog // FILE: secure_periph_soc.v ... ``` block
        → Saves response to temp_dir/soc_response.txt
        → Saves diagnostics to temp_dir/soc_top_diagnostics.json

Step 5  Extract and save Verilog files to output_dir/
        → Parses // FILE: <name>.v markers for accurate filenames
        → Falls back to module name extraction
```

### Prompt Design

Both `step2` (YAML inference) and `step4` (SoC top) pass the architecture doc and TB skeleton to the model with minimal guidance. Improving prompt quality — adding constraints, chain-of-thought instructions, or few-shot examples — is left to participants as part of the challenge.

### Heartbeat Example

During long model calls, the heartbeat thread writes to `stderr`:

```
[INFO] Model request attempt 1/5 using gemini-2.0-flash-exp
[INFO] Waiting for model response (15s elapsed)
[INFO] Waiting for model response (30s elapsed)
[INFO] Waiting for model response (45s elapsed)
```

### Diagnostics Files

After each model call, a JSON diagnostics file is saved:

```
temp_dir/
  yaml_inference_diagnostics.json   ← token usage, latency for YAML call
  soc_top_diagnostics.json          ← token usage, latency for SoC call
  yaml_response.txt                 ← raw model response (YAML blocks)
  soc_response.txt                  ← raw model response (Verilog blocks)
  spec_00.yaml … spec_07.yaml       ← extracted YAML specs
```

### Error Handling

| Error | Behaviour |
|-------|-----------|
| HTTP 429, 500–504 | Retry with exponential backoff (2s → 4s → 8s … max 60s) |
| `retryable: true` in payload | Retry regardless of status code |
| Empty model response | Log warning, return empty string (caller handles gracefully) |
| RTL gen failure | Log warning, skip that IP (SoC prompt still runs with partial list) |
| No Verilog extracted | Exit code 1 with `[ERROR]` message |
