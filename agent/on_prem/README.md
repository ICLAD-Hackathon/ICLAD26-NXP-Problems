# On-Prem Agent — LM Studio on Snapdragon Laptop

This directory contains everything needed to run a LangChain ReAct agent **locally** on a Snapdragon-powered laptop using [LM Studio](https://lmstudio.ai/) as the model inference server.

Unlike the cloud-based agents (`starter_agent.py`, `vertexai_express_agent.py`) that call a remote Vertex AI endpoint, this on-prem setup runs entirely on your machine — no internet required after the model is downloaded, no API keys, no usage costs.

## What's in this folder

| File | Description |
|------|-------------|
| `rtl_agent_updated.py` | LangChain ReAct agent that writes Verilog RTL, compiles with iverilog, and runs simulation |
| `requirements_on_prem.txt` | Python dependencies (langchain-core, langchain-openai, langgraph, etc.) |

The agent acts as an RTL / hardware engineering expert. Given a natural-language task description, it:

1. Writes a Verilog RTL module to disk
2. Writes a self-checking testbench to disk
3. Compiles both with `iverilog`
4. Runs the simulation with `vvp`
5. Reports pass/fail based on simulation output

The default task is a simple 4-bit up-counter — intentionally simple so that small language models (like Gemma 4, Phi-3, Llama 3.2) can complete it reliably.

---

## Prerequisites

### Hardware

- **Snapdragon X Elite / X Plus laptop** (e.g., Surface Laptop 7, Lenovo Yoga Slim 7x, Dell XPS 13 Snapdragon)
- **At least 16 GB RAM** (8 GB minimum, but larger models may be slow)
- **At least 10 GB free disk space** for model storage

### Software

| Tool | Minimum Version | Purpose |
|------|----------------|---------|
| Python | 3.12 | Running the agent script |
| LM Studio | 0.4.16 (ARM64) | Local model inference server |
| iverilog | 11.0 | Compiling Verilog RTL |
| vvp | (bundled with iverilog) | Running Verilog simulation |

---

## Step 1: Install System Dependencies

### 1.1 Python

```bash
python3 --version
# Should show Python 3.12 or newer
```

If Python is not installed, download it from [python.org](https://www.python.org/downloads/) (ARM64 installer).

### 1.2 Icarus Verilog (iverilog)

On Linux (Debian/Ubuntu on Snapdragon):

```bash
sudo apt update
sudo apt install iverilog
```

Verify the installation:

```bash
iverilog -V
# Expected: Icarus Verilog version 10.0 or newer
```

---

## Step 2: Install and Configure LM Studio

### 2.1 Download LM Studio

1. Go to [lmstudio.ai](https://lmstudio.ai/) and download the **ARM64** version for your OS (Windows on ARM or Linux ARM64).
2. Install and launch LM Studio.

### 2.2 Download a Model

Choose a model that fits within your laptop's RAM. Recommended models for Snapdragon laptops:

| Model | Size | RAM Needed | Notes |
|-------|------|-----------|-------|
| `google/gemma-4-e2b` | ~3 GB | 8 GB+ | Default in the agent script |
| `microsoft/Phi-3-mini-4k-instruct` | ~2.5 GB | 8 GB+ | Very fast, good for simple tasks |
| `llama-3.2-3b-instruct` | ~2 GB | 8 GB+ | Small, efficient |
| `llama-3.2-1b-instruct` | ~1 GB | 8 GB+ | Fastest option, lower quality |

In LM Studio:

1. Click the **Search** icon (magnifying glass) in the top bar
2. Search for your chosen model (e.g., `google/gemma-4-e2b`)
3. Select the model and click **Download**
4. Wait for the download to complete

### 2.3 Load the Model and Start the Server

1. In LM Studio, go to the **Chat** tab
2. Select your downloaded model from the dropdown at the top
3. Click the **Start Server** button (or go to the **Server** tab and click **Start**)
4. The server starts on `http://localhost:1234` by default

### 2.4 Verify the Server is Running

Open a terminal and run:

```bash
curl http://localhost:1234/v1/models
```

You should see a JSON response listing the loaded model. Alternatively:

```bash
curl http://localhost:1234/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "google/gemma-4-e2b",
    "messages": [{"role": "user", "content": "Say hello"}],
    "max_tokens": 50
  }'
```

Replace `google/gemma-4-e2b` with the actual model name shown in LM Studio.

---

## Step 3: Set Up the Python Environment

### 3.1 Create a Virtual Environment

```bash
cd ICLAD26-NXP-Problems/agent/on_prem
python3 -m venv .venv
source .venv/bin/activate      # Linux
# OR
.venv\Scripts\activate          # Windows
```

### 3.2 Install Dependencies

```bash
pip install -r requirements_on_prem.txt
```

This installs:

- `langchain-core` — LangChain base abstractions
- `langchain-openai` — OpenAI-compatible chat model wrapper
- `langgraph` — LangGraph runtime for the ReAct agent
- `openai` — OpenAI Python SDK (used under the hood by langchain-openai)

---

## Step 4: Configure the Agent

Open `rtl_agent.py` and check the LM Studio configuration (lines 171–178):

```python
LM_STUDIO_BASE_URL = "http://localhost:1234/v1"
LM_STUDIO_MODEL    = "google/gemma-4-e2b"   # model loaded in LM Studio

llm = ChatOpenAI(
    base_url=LM_STUDIO_BASE_URL,
    api_key="lm-studio",        # LM Studio accepts any non-empty string
    model=LM_STUDIO_MODEL,
    temperature=0,
)
```

- **`LM_STUDIO_BASE_URL`** — Should match the server address shown in LM Studio (default `http://localhost:1234/v1`)
- **`LM_STUDIO_MODEL`** — Must match the model name exactly as shown in LM Studio. To find the exact name, check the LM Studio Server tab or run `curl http://localhost:1234/v1/models`
- **`temperature=0`** — Deterministic output. Increase to 0.1–0.3 for more creative responses if needed

---

## Step 5: Run the Agent

Make sure LM Studio is running with the model loaded and the server active.

```bash
cd ICLAD26-NXP-Problems/agent/on_prem
source .venv/bin/activate      # if not already activated
python rtl_agent.py
```

### What you'll see

The agent streams its reasoning and tool calls to the console:

```
============================================================
LangChain ReAct Agent  --  RTL Simple Counter Task
Model : google/gemma-4-e2b
Server: http://localhost:1234/v1
============================================================
Task: ...

[agent] TOOL CALL  -> write_to_file  args={'path': 'simple_counter.v', 'content': '...'}
[agent] TOOL RESULT-> Successfully wrote 123 characters to 'simple_counter.v'.
[agent] TOOL CALL  -> write_to_file  args={'path': 'tb_simple_counter.v', 'content': '...'}
[agent] TOOL RESULT-> Successfully wrote 456 characters to 'tb_simple_counter.v'.
[agent] TOOL CALL  -> compile_verilog  args={'rtl_file': 'simple_counter.v', 'tb_file': 'tb_simple_counter.v', 'output': 'counter_sim'}
[agent] TOOL RESULT-> Compilation SUCCESS - binary 'counter_sim' created.
[agent] TOOL CALL  -> run_simulation  args={'sim_binary': 'counter_sim'}
[agent] TOOL RESULT-> STDOUT: ALL TESTS PASSED
[agent] AI         -> SUCCESS: All tests passed!
```

After the run completes, the script prints the generated Verilog files and confirms whether the simulation binary was created.

### Output files

After a successful run, the following files are created in the current directory:

| File | Description |
|------|-------------|
| `simple_counter.v` | Generated Verilog RTL module |
| `tb_simple_counter.v` | Generated self-checking testbench |
| `counter_sim` | Compiled simulation binary |

---

## How the Agent Works

### Architecture

The agent uses **LangGraph's prebuilt ReAct agent** (`create_react_agent`), which implements the ReAct (Reasoning + Acting) pattern:

1. The LLM receives the task prompt
2. It reasons about what step to take next
3. It calls a tool (e.g., `write_to_file`)
4. The tool result is fed back to the LLM
5. The LLM reasons again and calls the next tool
6. This loop continues until the task is complete

### Tools Available to the Agent

| Tool | Description |
|------|-------------|
| `write_to_file` | Write content to a file (creates directories as needed) |
| `read_file` | Read the full contents of a file |
| `list_files` | List files and directories |
| `execute_command` | Run any shell command |
| `compile_verilog` | Compile Verilog files with `iverilog` |
| `run_simulation` | Run a compiled simulation with `vvp` |

### Task Prompt

The task is defined in the `TASK` variable (lines 197–228). It describes the goal in natural language — the agent must infer the exact Verilog code, testbench structure, and simulation commands from the description alone. No code snippets are provided in the prompt.

---

## Customization

### Changing the Model

1. Load a different model in LM Studio
2. Update `LM_STUDIO_MODEL` in `rtl_agent.py` to match the new model name
3. Restart the LM Studio server if needed

### Changing the Task

Edit the `TASK` variable (lines 197–228) to describe a different RTL design. For example, you could ask the agent to create:

- An 8-bit shift register
- A simple finite state machine
- A clock divider
- A UART transmitter

Keep the task simple for small models — avoid complex multi-cycle operations or intricate state machines.

### Adding New Tools

To give the agent additional capabilities, define a new `@tool` function and add it to the `tools` list (line 185). For example, a tool to check if iverilog is installed:

```python
@tool
def check_iverilog() -> str:
    """Check if iverilog is installed and return its version."""
    try:
        result = subprocess.run(["iverilog", "-V"], capture_output=True, text=True, timeout=10)
        return result.stdout.splitlines()[0] if result.stdout else "iverilog not found"
    except FileNotFoundError:
        return "iverilog not found"
```

---

## Troubleshooting

### LM Studio server won't start

- Ensure you downloaded the **ARM64** version of LM Studio, not the x64 version
- Check that no other process is using port 1234: `lsof -i :1234` (Linux) or `netstat -ano | findstr :1234` (Windows)
- Try a different port in LM Studio settings (e.g., 8080) and update `LM_STUDIO_BASE_URL` accordingly

### Model runs out of memory

- Use a smaller model (e.g., Phi-3-mini-4k or Llama 3.2 1B)
- In LM Studio, go to Settings → Hardware and reduce the **GPU Offload** or use **CPU only**
- Close other applications to free up RAM

### Agent calls a tool but gets no useful response

- The model may be too small or not instruction-tuned. Try a larger model or one with better instruction-following (e.g., Phi-3-mini-4k-instruct)
- Increase `temperature` from 0 to 0.1–0.3 for slightly more variation
- Simplify the task prompt — be more explicit about what you want

### iverilog or vvp not found

```bash
# Linux
sudo apt install iverilog

# Verify
which iverilog
which vvp
```

### Agent keeps repeating the same tool call

- This is a common issue with small models. The model may not understand that the tool already returned a result
- Try reducing `max_tokens` in the `ChatOpenAI` constructor to force shorter responses
- Add a note in the task prompt: "After a tool returns a result, move to the next step. Do not call the same tool again."

### LM Studio returns gibberish

- Ensure the model is fully downloaded and not corrupted
- Try a different quantization (e.g., Q4_K_M instead of Q8_0) in LM Studio's model settings
- Check that `temperature` is set to 0 for deterministic output

---

## Comparison: On-Prem vs Cloud Agents

| Aspect | On-Prem (this folder) | Cloud (starter_agent.py / vertexai_express_agent.py) |
|--------|----------------------|------------------------------------------------------|
| Model location | Local (LM Studio) | Remote (Vertex AI) |
| Internet required | Only for initial model download | Yes, for every API call |
| API key required | No | Yes (EXPRESS_MODE_KEY) |
| Cost | Free (electricity only) | Per-token billing |
| Latency | Depends on model size and hardware | Typically faster on cloud GPUs |
| Privacy | 100% local — no data leaves your machine | Data sent to cloud endpoint |
| Model flexibility | Any model LM Studio supports | Limited to Vertex AI models |
| Benchmark integration | Standalone (not part of `run_benchmark.py`) | Full integration with runner + evaluator |

