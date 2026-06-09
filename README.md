# NXP ICLAD 2026 — SoC Design Benchmark

## Overview

Design and implement industrial-complexity SoC hardware in synthesizable Verilog.
Three difficulty levels — Easy, Medium, Hard — each requiring participants to:

1. **Read** `architecture.html` — the only reference document provided (See `problems/easy/docs/architecture.html`)
2. **Infer** YAML specifications for each IP block from the visual diagrams
3. **Generate** parameterized Verilog using the provided RTL generation library
4. **Stitch** all IPs into a top-level SoC module
5. **Verify** the design compiles and simulates with `iverilog`

No YAML is given. No pre-written RTL. No text descriptions. The agent must read the visual diagrams, reason about the architecture, and drive the full RTL generation toolchain.

### Scoring

Scores are computed on two dimensions:

| Dimension | Description |
|-----------|-------------|
| **Correctness** | `passed_tests / total_tests × 100%` — based on iverilog simulation against the hidden golden testbench |
| **Efficiency** | Token cost metric — total tokens consumed across all model calls (logged via `usage_path`) |

A lower token cost with the same correctness score ranks higher. Both dimensions are reported in `easy_score.json`.

---

## Repository Structure

```
nxp-soc-problems/
├── README.md                       ← This file
├── AGENT_GUIDE.md                  ← Interface specification for building agents
├── DEPENDENCIES.md                 ← System tools and setup verification
│
├── problems/
│   └── easy/
│       ├── docs/
│       │   └── architecture.html  ← Visual diagrams + minimal spec [GIVEN — only reference]
│       ├── tb/
│       │   └── tb_top_skeleton.v  ← TB shell with exact port contract [GIVEN]
│       ├── specs/                 ← Golden YAML specs   [HIDDEN from participants]
│       ├── golden_rtl/            ← Golden Verilog RTL  [HIDDEN from participants]
│       └── golden_tb/             ← Golden testbench    [HIDDEN from participants]
│
├── rtl_gen_lib/                    ← RTL generation library [GIVEN]
│   ├── rtl_gen_main.py             ← Entry point: --spec <yaml> --outdir <dir>
│   ├── gen_primitives.py           ← FIFO, SRAM, CDC, reset generators
│   ├── gen_apb_ips.py              ← UART, GPIO, Timer, WDT, IRQ, Bridge, Fabric
│   ├── gen_axi_ips.py              ← AXI crossbar, SRAM, DMA engine
│   └── gen_noc_ips.py              ← TileLink router, NI, AES-128
│
├── agent/
│   ├── starter_agent.py           ← Minimal starter stub [GIVEN — extend this]
│   └── vertexai_express_agent.py  ← Production agent with heartbeat + diagnostics [GIVEN]
│
├── runner/
│   └── run_benchmark.py           ← Benchmark runner
│
├── evaluator/
│   └── evaluate.py                ← Compilation + simulation + scoring
│
└── factors/                       ← Score outputs (created at runtime)
```

---

## Problem Descriptions

### 🟢 EASY: Secure Peripheral Subsystem (~$8–12 to solve)

**Top module**: `secure_periph_soc`

An AHB-Lite CPU master connects to 4 peripheral slaves through an APB fabric
with privilege-level access control. An interrupt aggregator delivers vectored
interrupts to the CPU.

**IP Blocks**: reset_sync, ahb_to_apb_bridge, apb_fabric (5-slave), apb_uart,
apb_gpio, apb_timer, apb_watchdog, irq_aggregator

**Test Categories**: basic_rw, uart_tx, gpio_irq, timer, watchdog, privilege, irq_aggregator, reset_sync

**Architecture**: See `problems/easy/docs/architecture.html` (open in any browser)

> **Note**: Medium and Hard difficulty levels are coming in a future release.

---

## Quickstart

### 1. Setup

```bash
git clone <repo>
cd nxp-soc-problems

# Python 3.8+ required (no extra packages needed for basic use)
# Optional: pip install pyyaml  (for cleaner YAML parsing)

# Verify iverilog is available
iverilog -v
```

### 2. Explore the RTL Generation Library

```bash
cd rtl_gen_lib

# Show all supported IP types and example YAML
python3 rtl_gen_main.py --demo

# Generate a single IP from YAML
cat > /tmp/my_uart.yaml << 'EOF'
ip_type: apb_uart
name: my_uart
fifo_depth: 16
default_div: 26
EOF
python3 rtl_gen_main.py --spec /tmp/my_uart.yaml --outdir /tmp/gen/

# List variants possible from one YAML
python3 rtl_gen_main.py --spec /tmp/my_uart.yaml --list-variants
```

### 3. Run the Starter Agent (EASY problem)

```bash
# Prepare info.json only (no agent invoked)
python3 runner/run_benchmark.py --problem easy --prepare-only --run-id test_v1

# Run with starter agent + your model endpoint
python3 runner/run_benchmark.py \
    --problem easy \
    --agent agent/starter_agent.py \
    --model <your_model_name> \
    --model-endpoint http://your_endpoint:port \
    --run-id starter_v1

# Run with Vertex AI Express Mode agent (recommended — production-grade)
python3 runner/run_benchmark.py \
    --problem easy \
    --agent agent/vertexai_express_agent.py \
    --model gemini-2.0-flash-exp \
    --model-endpoint http://your_endpoint:port \
    --run-id vertexai_v1

# Run your custom agent
python3 runner/run_benchmark.py \
    --problem easy \
    --agent path/to/my_agent.py \
    --model <model_name> \
    --model-endpoint http://... \
    --run-id my_agent_v1
```

### 4. Evaluate Against Golden TB

```bash
python3 evaluator/evaluate.py \
    --problem easy \
    --rtl_dir result/my_agent_v1/easy/ \
    --run_id  my_agent_v1
```

Output is written to `factors/my_agent_v1/easy/easy_score.json`.

### 5. Verify the Easy golden RTL (reference)

```bash
cd problems/easy
iverilog -g2005 -o sim_easy \
    golden_rtl/reset_sync.v \
    golden_rtl/apb_uart.v \
    golden_rtl/apb_gpio.v \
    golden_rtl/apb_timer.v \
    golden_rtl/apb_watchdog.v \
    golden_rtl/ahb_to_apb_bridge.v \
    golden_rtl/irq_aggregator.v \
    golden_rtl/secure_periph_soc.v \
    golden_tb/tb_secure_periph_soc.v
vvp sim_easy
# Expected: 22/22 ALL TESTS PASSED
```

---

## Scoring

```json
{
  "compilation":   { "success": true },
  "test_results":  { "passed": 20, "total": 22, "score": 90.9 },
  "token_cost":    { "total_tokens": 12400, "model_calls": 2 },
  "categories":    { "reset_sync": {...}, "uart_tx": {...}, ... }
}
```

| Field | Description |
|-------|-------------|
| `compilation.success` | iverilog compiled without errors |
| `test_results.passed` | Number of test assertions passed |
| `test_results.total`  | Total test assertions |
| `test_results.score`  | `passed / total × 100%` (primary ranking metric) |
| `token_cost.total_tokens` | Total tokens consumed across all model calls (efficiency metric) |
| `categories` | Per-category pass/fail breakdown |

The golden testbench uses numbered test IDs (`T101`, `T201`, etc.) grouped by category.
Each `[PASS] T<id>` or `[FAIL] T<id>` line is parsed by the evaluator.
Agents with equal correctness scores are ranked by lower token cost.

---

## Key Rules

1. **Your top module name MUST match the contract** exactly as shown in `tb_top_skeleton.v`
2. **All ports MUST match exactly** — same names, same widths, same directions
3. **Verilog 2001 only** — `iverilog -g2005` compatibility required
4. **No external IP libraries** — all logic must be in your `.v` files
5. **RTL generation library is provided** — your agent may call it to generate IP blocks
6. **Golden testbench is hidden** — participants receive only `tb_top_skeleton.v`

---

## Files Provided to Participants

| File | Description |
|------|-------------|
| `problems/<level>/docs/architecture.html` | **Primary reference** — visual diagrams + minimal spec (open in browser) |
| `problems/<level>/tb/tb_top_skeleton.v` | TB skeleton with exact port contract |
| `rtl_gen_lib/` | Complete RTL generation library |
| `agent/starter_agent.py` | Minimal starter agent demonstrating the interface |
| `agent/vertexai_express_agent.py` | Production Vertex AI Express Mode agent (heartbeat, retry, diagnostics) |
| `runner/run_benchmark.py` | Benchmark runner |
| `evaluator/evaluate.py` | Evaluator (uses hidden golden TB) |

## Files Hidden from Participants

| File | Description |
|------|-------------|
| `problems/<level>/specs/` | Golden YAML specifications |
| `problems/<level>/golden_rtl/` | Golden Verilog RTL |
| `problems/<level>/golden_tb/` | Golden assertion testbench |
