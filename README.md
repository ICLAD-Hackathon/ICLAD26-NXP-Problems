# NXP ICLAD 2026 -- SoC Design Benchmark

## Overview

Design and implement industrial-complexity SoC hardware in synthesizable Verilog.
Three difficulty levels -- Easy, Medium, Hard -- each requiring participants to:

1. **Read** `architecture.html` -- the only reference document provided (See `problems/easy/docs/architecture.html`)
2. **Infer** YAML specifications for each IP block from the visual diagrams
3. **Generate** parameterized Verilog using the provided RTL generation library
4. **Stitch** all IPs into a top-level SoC module
5. **Verify** the design compiles and simulates with `iverilog`

No YAML is given. No pre-written RTL. No text descriptions. The agent must read the visual
diagrams, reason about the architecture, and drive the full RTL generation toolchain.

---

## Repository Structure

```
nxp-soc-problems/
+-- README.md                       <- This file
+-- AGENT_GUIDE.md                  <- Interface specification for building agents
+-- DEPENDENCIES.md                 <- System tools and setup verification
|
+-- problems/
|   +-- easy/
|   |   +-- docs/
|   |   |   +-- architecture.html  <- Visual diagrams + minimal spec [GIVEN -- only reference]
|   |   +-- tb/
|   |   |   +-- tb_top_skeleton.v  <- TB shell with exact port contract [GIVEN]
|   |   +-- specs/                 <- Golden YAML specs   [HIDDEN from participants]
|   |   +-- golden_rtl/            <- Golden Verilog RTL  [HIDDEN from participants]
|   |   +-- golden_tb/             <- Golden testbench    [HIDDEN from participants]
|   +-- medium/
|   |   +-- docs/
|   |   |   +-- architecture.html  <- Visual diagrams + minimal spec [GIVEN -- only reference]
|   |   +-- tb/
|   |       +-- tb_top_skeleton.v  <- TB shell with exact port contract [GIVEN]
|   +-- hard/
|       +-- docs/
|       |   +-- architecture.html  <- Visual diagrams + minimal spec [GIVEN -- only reference]
|       +-- tb/
|           +-- tb_top_skeleton.v  <- TB shell with exact port contract [GIVEN]
|
+-- rtl_gen_lib/                    <- RTL generation library [GIVEN]
|   +-- rtl_gen_main.py             <- Entry point: --spec <yaml> --outdir <dir>
|   +-- gen_primitives.py           <- FIFO, SRAM, CDC, reset generators
|   +-- gen_apb_ips.py              <- UART, GPIO, Timer, WDT, IRQ, Bridge, Fabric
|   +-- gen_axi_ips.py              <- AXI crossbar, SRAM, DMA engine
|   +-- gen_noc_ips.py              <- TileLink router, NI, AES-128
|
+-- agent/
|   +-- starter_agent.py           <- Minimal starter stub [GIVEN -- extend this]
|   +-- vertexai_express_agent.py  <- Production agent with heartbeat + diagnostics [GIVEN]
|
+-- runner/
|   +-- run_benchmark.py           <- Benchmark runner
|
+-- evaluator/
|   +-- evaluate.py                <- Compilation + simulation + scoring
|
+-- factors/                       <- Score outputs (created at runtime)
```

---

## Problem Descriptions

### [EASY] Secure Peripheral Subsystem

**Top module**: `secure_periph_soc`

An AHB-Lite CPU master connects to 4 peripheral slaves through an APB fabric
with privilege-level access control. An interrupt aggregator delivers vectored
interrupts to the CPU.

**IP Blocks**: reset_sync, ahb_to_apb_bridge, apb_fabric (5-slave), apb_uart,
apb_gpio, apb_timer, apb_watchdog, irq_aggregator

**Test Categories**: basic_rw, uart_tx, gpio_irq, timer, watchdog, privilege, irq_aggregator, reset_sync

**Architecture**: See `problems/easy/docs/architecture.html` (open in any browser)

---

### [MEDIUM] 2x3 TileLink NoC AES Crypto SoC

**Top module**: `noc_aes_soc`

A 2x3 mesh NoC built from TileLink-UL routers. Each of the 6 nodes contains a router,
a network interface (NI), and a local SRAM. AES-128 encryption engines are attached
at nodes (1,0) and (1,1). The CPU enters the mesh at node (0,0) via an AXI4-Lite
master port. An IRQ aggregator collects AES done signals and delivers vectored
interrupts to the CPU.

**IP Blocks**: reset_sync, tilelink_router (x6), tilelink_ni (x6), axi_lite_sram (x6),
aes128 (x2), irq_aggregator

**Architecture**: See `problems/medium/docs/architecture.html` (open in any browser)

---

### [HARD] Multi-Domain Crypto SoC

**Top module**: `crypto_soc`

A multi-clock-domain SoC combining a TileLink NoC crypto subsystem, an AXI4-Lite
crossbar, an APB peripheral subsystem, a DMA engine, dual IRQ aggregators (crypto
and peripheral), GPIO, UART, and a DSP-domain mailbox. The CPU master port is
AXI4-Lite (32-bit data). A separate `dsp_clk` drives the DSP/mailbox domain.

**IP Blocks**: reset_sync, tilelink_router, tilelink_ni, axi_lite_sram, axi_lite_crossbar,
aes128, dma_engine, apb_fabric, apb_gpio (x2), apb_uart, irq_aggregator (x2),
perf_counter, mailbox

**Architecture**: See `problems/hard/docs/architecture.html` (open in any browser)

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

### 3. Run the Starter Agent

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

# Run with Vertex AI Express Mode agent (recommended -- production-grade)
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

# Run against the medium problem
python3 runner/run_benchmark.py \
    --problem medium \
    --agent path/to/my_agent.py \
    --model <model_name> \
    --model-endpoint http://... \
    --run-id my_agent_medium_v1

# Run against the hard problem
python3 runner/run_benchmark.py \
    --problem hard \
    --agent path/to/my_agent.py \
    --model <model_name> \
    --model-endpoint http://... \
    --run-id my_agent_hard_v1
```

### 4. Evaluate Against Golden TB

```bash
# Easy
python3 evaluator/evaluate.py \
    --problem easy \
    --rtl_dir result/my_agent_v1/easy/ \
    --run_id  my_agent_v1

# Medium
python3 evaluator/evaluate.py \
    --problem medium \
    --rtl_dir result/my_agent_medium_v1/medium/ \
    --run_id  my_agent_medium_v1

# Hard
python3 evaluator/evaluate.py \
    --problem hard \
    --rtl_dir result/my_agent_hard_v1/hard/ \
    --run_id  my_agent_hard_v1
```

Output is written to `factors/<run_id>/<problem>/<problem>_score.json`
(e.g., `factors/my_agent_v1/easy/easy_score.json`).

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

Functionality is the primary scoring criterion. Tokens are used only as a tie-breaker.

### Score Formula

```
Score = category_weight_factor x (number of passing tests in that category)
```

Scores are summed across all categories within a problem level.

### Weight Factors

| Problem Level | Weight Factor |
|---------------|---------------|
| Easy          | 1             |
| Medium        | 1.5           |
| Hard          | 2             |

### Bonuses

| Condition | Bonus Points |
|-----------|-------------|
| All tests pass within a single category | +100 per category |
| All tests pass across all three problem levels | +300 (one-time) |

### Tie-Breaker (equal overall score)

When two or more participants have the same total score, the tie is broken as follows:

1. Per-category rank is determined by token count -- fewer tokens is a better rank.
2. The participant with a higher rank across more categories wins.

Example: In a two-team tie, if Team A wins Easy and Medium, and Team B wins Hard,
Team A is declared the winner.

### Score Output

```json
{
  "compilation":   { "success": true },
  "test_results":  { "passed": 20, "total": 22, "score": 90.9 },
  "token_cost":    { "total_tokens": 12400, "model_calls": 2 },
  "categories":    { "reset_sync": {}, "uart_tx": {}, "..." : {} }
}
```

| Field | Description |
|-------|-------------|
| `compilation.success` | iverilog compiled without errors |
| `test_results.passed` | Number of test assertions passed |
| `test_results.total`  | Total test assertions |
| `test_results.score`  | passed / total x 100% |
| `token_cost.total_tokens` | Total tokens consumed across all model calls |
| `categories` | Per-category pass/fail breakdown |

The golden testbench uses numbered test IDs (`T101`, `T201`, etc.) grouped by category.
Each `[PASS] T<id>` or `[FAIL] T<id>` line is parsed by the evaluator.

---

## Key Rules

1. **Your top module name MUST match the contract** exactly as shown in `tb_top_skeleton.v`
2. **All ports MUST match exactly** -- same names, same widths, same directions
3. **Verilog 2001 only** -- `iverilog -g2005` compatibility required
4. **No external IP libraries** -- all logic must be in your `.v` files
5. **RTL generation library is provided** -- your agent may call it to generate IP blocks
6. **Golden testbench is hidden** -- participants receive only `tb_top_skeleton.v`
7. **Internal signal and instance names MUST match** the names specified in
   `architecture.html` exactly -- the golden testbench probes internal hierarchy paths
   by name; deviating from the specified names will cause test failures even if the
   logic is functionally correct
8. **RTL generation library coverage** -- `rtl_gen_lib` covers the standard IP types
   listed in `AGENT_GUIDE.md`; for Medium and Hard problems some blocks may require
   custom or templated Verilog beyond what the library generates -- participants are
   free to write or template additional RTL to supplement the generated IPs

---

## Files Provided to Participants

| File | Description |
|------|-------------|
| `problems/<level>/docs/architecture.html` | Primary reference -- visual diagrams + minimal spec (open in browser) |
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
