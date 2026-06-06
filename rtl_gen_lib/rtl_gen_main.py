#!/usr/bin/env python3
"""
NXP ICLAD 2026 — RTL Generation Library Entry Point
=====================================================
Usage:
  python3 rtl_gen_main.py --spec my_ip.yaml --outdir ./generated/
  python3 rtl_gen_main.py --spec my_ip.yaml --list-variants
  python3 rtl_gen_main.py --demo

YAML file must contain 'ip_type' field.
Supported ip_type values:
  sync_fifo, async_fifo, sram_sp, sram_dp, reset_sync, cdc_sync,
  apb_uart, apb_gpio, apb_timer, apb_watchdog, irq_aggregator,
  ahb_to_apb_bridge, apb_fabric, axi_lite_crossbar, axi_lite_sram,
  dma_engine, perf_counter, tilelink_router, aes128
"""

import argparse
import sys
from pathlib import Path

# Import all generator modules
from gen_primitives import GENERATORS as PRIM_GENERATORS
from gen_apb_ips    import GENERATORS as APB_GENERATORS
from gen_axi_ips    import GENERATORS as AXI_GENERATORS
from gen_noc_ips    import GENERATORS as NOC_GENERATORS

ALL_GENERATORS = {}
ALL_GENERATORS.update(PRIM_GENERATORS)
ALL_GENERATORS.update(APB_GENERATORS)
ALL_GENERATORS.update(AXI_GENERATORS)
ALL_GENERATORS.update(NOC_GENERATORS)


def load_yaml(path):
    try:
        import yaml
        with open(path) as f:
            return yaml.safe_load(f)
    except ImportError:
        return _load_yaml_minimal(path)


def _load_yaml_minimal(path):
    """Minimal YAML loader — handles simple key:value and nested dicts."""
    import re
    lines = Path(path).read_text().splitlines()
    result, stack = {}, [(0, result)]
    for raw in lines:
        line = raw.rstrip()
        if not line or line.lstrip().startswith('#'):
            continue
        indent = len(line) - len(line.lstrip())
        line   = line.strip()
        if ':' not in line:
            continue
        key, _, val = line.partition(':')
        key = key.strip(); val = val.strip().strip('"').strip("'")
        while len(stack) > 1 and stack[-1][0] >= indent:
            stack.pop()
        parent = stack[-1][1]
        if val in ('', '{}'):
            d = {}; parent[key] = d; stack.append((indent, d))
        else:
            try:
                if re.match(r'^0x[0-9a-fA-F]+$', val):
                    parent[key] = int(val, 16)
                elif re.match(r'^\d+$', val):
                    parent[key] = int(val)
                elif val.lower() in ('true', 'yes'):
                    parent[key] = True
                elif val.lower() in ('false', 'no'):
                    parent[key] = False
                else:
                    parent[key] = val
            except Exception:
                parent[key] = val
    return result


def generate(spec_path, outdir="."):
    spec = load_yaml(spec_path)
    ip_type = spec.get("ip_type", "")
    if not ip_type:
        print(f"ERROR: YAML file must contain 'ip_type' field.", file=sys.stderr)
        return False
    if ip_type not in ALL_GENERATORS:
        print(f"ERROR: Unknown ip_type='{ip_type}'. Supported: {sorted(ALL_GENERATORS)}", file=sys.stderr)
        return False

    files = ALL_GENERATORS[ip_type](spec)
    out = Path(outdir)
    out.mkdir(parents=True, exist_ok=True)
    for fname, content in files.items():
        fpath = out / fname
        fpath.write_text(content)
        print(f"[GEN] {fpath}  ({len(content):,} chars)")
    return True


def list_variants(spec_path):
    spec = load_yaml(spec_path)
    ip_type = spec.get("ip_type", "")
    name = spec.get("name", "unnamed")
    print(f"\n=== Variants for ip_type={ip_type!r}, name={name!r} ===")
    if ip_type == "sync_fifo":
        depth = int(spec.get("depth", 16))
        width = int(spec.get("data_width", 32))
        print(f"  Base:        {name}.v  (depth={depth}, data_width={width}, fwft=false)")
        print(f"  FWFT:        {name}_fwft.v  (fwft=true)")
        print(f"  Double-deep: {name}_d{depth*2}.v  (depth={depth*2})")
        print(f"  Wide:        {name}_w64.v  (data_width=64)")
    elif ip_type == "async_fifo":
        print(f"  Base:        {name}.v  (dual-clock, Gray-code)")
        print(f"  ECC:         {name}_ecc.v  (with SEC-DED error correction)")
    elif ip_type == "sram_sp":
        print(f"  Base:        {name}.v  (single-port, byte-enable)")
        print(f"  No-BE:       {name}_nobe.v  (word write only)")
        print(f"  ECC:         {name}_ecc.v  (SEC-DED ECC)")
    elif ip_type == "apb_uart":
        print(f"  Base:        {name}.v  (FIFOs, parity, CTS/RTS)")
        print(f"  No-parity:   {name}_noparity.v  (parity_en always=0)")
        print(f"  Deep-FIFO:   {name}_fifo32.v  (fifo_depth=32)")
    elif ip_type == "axi_lite_crossbar":
        print(f"  Base:        {name}.v  (2M×3S, round-robin)")
        print(f"  3M×4S:       {name}_3m4s.v  (masters=3, slaves=4)")
        print(f"  Fixed-prio:  {name}_fp.v  (fixed-priority arbitration)")
    else:
        print(f"  Use --spec with modified parameters to generate variants.")
    print()


def print_demo():
    print(__doc__)
    print("Example YAML specs:\n")
    examples = [
        ("sync_fifo",  "ip_type: sync_fifo\nname: tx_fifo\ndepth: 16\ndata_width: 8\nfwft: false\nalmost_full_thresh: 14\nalmost_empty_thresh: 2"),
        ("apb_uart",   "ip_type: apb_uart\nname: debug_uart\nfifo_depth: 16\ndefault_baud: 115200\nclk_freq_hz: 50000000"),
        ("sram_sp",    "ip_type: sram_sp\nname: data_sram\ndepth: 2048\ndata_width: 32"),
        ("reset_sync", "ip_type: reset_sync\nname: sys_rst_sync\nstages: 3"),
    ]
    for ip_type, yaml_str in examples:
        print(f"--- {ip_type} ---")
        print(yaml_str)
        print()


def main():
    parser = argparse.ArgumentParser(
        description="NXP ICLAD 2026 RTL Generation Library",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__)
    parser.add_argument("--spec",    help="Path to YAML specification file")
    parser.add_argument("--outdir",  default=".", help="Output directory for generated Verilog")
    parser.add_argument("--list-variants", action="store_true", help="List possible variants from spec")
    parser.add_argument("--demo",    action="store_true", help="Show documentation and example YAMLs")
    args = parser.parse_args()

    if args.demo:
        print_demo()
        return

    if not args.spec:
        parser.print_help()
        sys.exit(1)

    if args.list_variants:
        list_variants(args.spec)
    else:
        ok = generate(args.spec, args.outdir)
        sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
