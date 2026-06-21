"""
LangChain ReAct Agent backed by LM Studio (OpenAI-compatible endpoint).

A simplified example designed for small language models like Gemma 4.
The agent acts as a basic RTL / hardware engineering expert and has
access to file-system / shell tools. Its task is to:
  1. Write a simple Verilog RTL module (a 4-bit up-counter)
  2. Write a self-checking testbench for it
  3. Compile both with iverilog
  4. Run the simulation with vvp
  5. Report pass/fail based on simulation output

Usage:
    python rtl_agent_updated.py

Requirements (already in .lmstudio venv):
    langchain-core, langchain-openai, langgraph
"""

import warnings
import subprocess
from pathlib import Path

from langchain_openai import ChatOpenAI
from langchain_core.tools import tool
from langgraph.prebuilt import create_react_agent


# ---------------------------------------------------------------------------
# Tool definitions  (Cline-style: write_to_file, read_file, list_files, execute_command)
# ---------------------------------------------------------------------------

@tool
def write_to_file(path: str, content: str) -> str:
    """Write content to a file at the given path. Creates parent directories if needed."""
    try:
        file_path = Path(path)
        file_path.parent.mkdir(parents=True, exist_ok=True)
        file_path.write_text(content, encoding="utf-8")
        return f"Successfully wrote {len(content)} characters to '{path}'."
    except Exception as exc:
        return f"Error writing to '{path}': {exc}"


@tool
def read_file(path: str) -> str:
    """Read and return the full text contents of a file."""
    try:
        return Path(path).read_text(encoding="utf-8")
    except Exception as exc:
        return f"Error reading '{path}': {exc}"


@tool
def list_files(directory: str = ".") -> str:
    """List files and sub-directories inside the given directory path."""
    try:
        entries = sorted(Path(directory).iterdir(), key=lambda p: (p.is_file(), p.name))
        lines = [f"{'DIR ' if e.is_dir() else 'FILE'} {e.name}" for e in entries]
        return "\n".join(lines) if lines else "(empty directory)"
    except Exception as exc:
        return f"Error listing '{directory}': {exc}"


@tool
def execute_command(command: str) -> str:
    """Execute a shell command and return its stdout, stderr and exit code."""
    try:
        result = subprocess.run(
            command,
            shell=True,
            capture_output=True,
            text=True,
            timeout=30,
        )
        output = ""
        if result.stdout:
            output += f"STDOUT:\n{result.stdout}"
        if result.stderr:
            output += f"STDERR:\n{result.stderr}"
        output += f"EXIT CODE: {result.returncode}"
        return output or "(no output)"
    except subprocess.TimeoutExpired:
        return "Error: command timed out after 30 seconds."
    except Exception as exc:
        return f"Error executing command: {exc}"


@tool
def compile_verilog(rtl_file: str, tb_file: str, output: str = "counter_sim") -> str:
    """Compile a Verilog RTL module and testbench with iverilog.

    Args:
        rtl_file: Path to the RTL module source file (.v).
        tb_file:  Path to the testbench source file (.v).
        output:   Name for the compiled simulation binary (default: counter_sim).

    Returns a summary of the compilation result including any errors or warnings.
    """
    cmd = f"iverilog -g2005-sv -o {output} {rtl_file} {tb_file}"
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            capture_output=True,
            text=True,
            timeout=60,
        )
        lines = []
        lines.append(f"Command: {cmd}")
        if result.stdout:
            lines.append(f"STDOUT:\n{result.stdout.rstrip()}")
        if result.stderr:
            lines.append(f"STDERR:\n{result.stderr.rstrip()}")
        lines.append(f"EXIT CODE: {result.returncode}")
        if result.returncode == 0:
            lines.append(f"Compilation SUCCESS - binary '{output}' created.")
        else:
            lines.append("Compilation FAILED - check errors above.")
        return "\n".join(lines)
    except subprocess.TimeoutExpired:
        return f"Error: iverilog timed out after 60 seconds."
    except FileNotFoundError:
        return "Error: iverilog not found. Please ensure it is installed and on PATH."
    except Exception as exc:
        return f"Error running iverilog: {exc}"


@tool
def run_simulation(sim_binary: str = "counter_sim") -> str:
    """Run a compiled Verilog simulation binary with vvp and return its output.

    Args:
        sim_binary: Path/name of the compiled simulation binary (default: counter_sim).

    Returns the full simulation stdout/stderr so the agent can parse pass/fail.
    """
    cmd = f"vvp {sim_binary}"
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            capture_output=True,
            text=True,
            timeout=60,
        )
        lines = []
        lines.append(f"Command: {cmd}")
        if result.stdout:
            lines.append(f"STDOUT:\n{result.stdout.rstrip()}")
        if result.stderr:
            lines.append(f"STDERR:\n{result.stderr.rstrip()}")
        lines.append(f"EXIT CODE: {result.returncode}")
        if result.returncode == 0:
            lines.append("Simulation finished successfully.")
        else:
            lines.append("Simulation exited with non-zero code - check output above.")
        return "\n".join(lines)
    except subprocess.TimeoutExpired:
        return f"Error: vvp timed out after 60 seconds."
    except FileNotFoundError:
        return "Error: vvp not found. Please ensure iverilog/vvp is installed and on PATH."
    except Exception as exc:
        return f"Error running vvp: {exc}"


# ---------------------------------------------------------------------------
# LLM setup  -- LM Studio OpenAI-compatible endpoint
# ---------------------------------------------------------------------------

LM_STUDIO_BASE_URL = "http://localhost:1234/v1"
LM_STUDIO_MODEL    = "google/gemma-4-e2b"   # model loaded in LM Studio

llm = ChatOpenAI(
    base_url=LM_STUDIO_BASE_URL,
    api_key="lm-studio",        # LM Studio accepts any non-empty string
    model=LM_STUDIO_MODEL,
    temperature=0,
)

# ---------------------------------------------------------------------------
# Build the ReAct agent
# ---------------------------------------------------------------------------

tools = [write_to_file, read_file, list_files, execute_command, compile_verilog, run_simulation]
agent = create_react_agent(llm, tools)

# ---------------------------------------------------------------------------
# Define and run the agent task
# ---------------------------------------------------------------------------
# NOTE: This task is intentionally simple (a 4-bit counter) so that small
# language models like Gemma 4 can reliably complete all steps.
# The Verilog code is straightforward sequential logic, and the testbench
# only checks 16 values (0 through 15).
# ---------------------------------------------------------------------------

TASK = (
    "You are an RTL / hardware engineering expert. "
    "Your task is to create a simple 4-bit up-counter in Verilog, "
    "write a self-checking testbench for it, compile it with iverilog, "
    "and run the simulation with vvp. Follow these steps in order:\n\n"

    "Step 1: Write a Verilog RTL module to a file named 'simple_counter.v' "
    "using the write_to_file tool. "
    "The module should be named 'simple_counter' with three ports: "
    "a clock input, an active-low reset input, and a 4-bit count output. "
    "On every positive clock edge, the counter increments by one. "
    "When reset is asserted low, the counter resets to zero.\n\n"

    "Step 2: Write a self-checking testbench to a file named 'tb_simple_counter.v' "
    "using the write_to_file tool. "
    "The testbench module should be named 'tb_simple_counter' with no ports. "
    "It should instantiate the simple_counter module, generate a clock with period 10 time units, "
    "assert and then de-assert reset, and then check the count output for 16 consecutive clock cycles. "
    "The expected values should be 0, 1, 2, 3, and so on up to 15. "
    "Write each check explicitly — do not use a loop. "
    "If any check fails, print a FAIL message and call $finish. "
    "If all 16 checks pass, print 'ALL TESTS PASSED' and call $finish.\n\n"

    "Step 3: Compile both Verilog files using the compile_verilog tool. "
    "Set rtl_file to 'simple_counter.v', tb_file to 'tb_simple_counter.v', and output to 'counter_sim'.\n\n"

    "Step 4: Run the compiled simulation using the run_simulation tool with sim_binary set to 'counter_sim'.\n\n"

    "Step 5: Read the simulation output from step 4. "
    "If the output contains 'ALL TESTS PASSED', print 'SUCCESS: All tests passed!'. "
    "Otherwise, print 'FAILURE: See simulation output for details.'"
)

print("=" * 60)
print("LangChain ReAct Agent  --  RTL Simple Counter Task")
print(f"Model : {LM_STUDIO_MODEL}")
print(f"Server: {LM_STUDIO_BASE_URL}")
print("=" * 60)
print(f"Task: {TASK}\n")

# Stream agent steps so reasoning and tool calls are visible
for step in agent.stream(
    {"messages": [{"role": "user", "content": TASK}]},
    stream_mode="updates",
):
    for node_name, node_output in step.items():
        messages = node_output.get("messages", [])
        for msg in messages:
            msg_type = getattr(msg, "type", type(msg).__name__)

            if hasattr(msg, "tool_calls") and msg.tool_calls:
                for tc in msg.tool_calls:
                    print(f"[{node_name}] TOOL CALL  -> {tc['name']}  args={tc['args']}")

            elif msg_type == "tool":
                preview = str(msg.content)[:300]
                print(f"[{node_name}] TOOL RESULT-> {preview}")

            elif hasattr(msg, "content") and msg.content:
                preview = str(msg.content)[:600]
                print(f"[{node_name}] AI         -> {preview}")

print("\n" + "=" * 60)
print("Agent run complete.")

# Check if the output files were created
rtl_path = Path("simple_counter.v")
tb_path = Path("tb_simple_counter.v")
sim_path = Path("counter_sim")

if rtl_path.exists():
    print(f"\nGenerated {rtl_path.name}:")
    print("-" * 40)
    print(rtl_path.read_text())
else:
    print(f"\n{rtl_path.name} was NOT created by the agent.")

if tb_path.exists():
    print(f"\nGenerated {tb_path.name}:")
    print("-" * 40)
    print(tb_path.read_text())
else:
    print(f"{tb_path.name} was NOT created by the agent.")

if sim_path.exists():
    print(f"\nSimulation binary {sim_path.name} exists.")
else:
    print(f"\nSimulation binary {sim_path.name} was NOT created.")