"""
Primitive IP generators: sync_fifo, async_fifo, sram_sp, sram_dp,
                         reset_sync, cdc_sync, perf_counter

All design-critical parameters are REQUIRED in the YAML spec.
Use gen_utils.required() — no silent defaults for key values.
"""
from gen_utils import required, opt, hdr, MissingParameter


def gen_sync_fifo(spec):
    """
    Required YAML fields: name, depth, data_width
    Optional: fwft (default False), almost_full_thresh, almost_empty_thresh
    """
    n  = opt(spec, "name", "sync_fifo")
    d  = int(required(spec, "depth",      "sync_fifo"))
    w  = int(required(spec, "data_width", "sync_fifo"))
    fw = bool(opt(spec, "fwft", False))
    af = int(opt(spec, "almost_full_thresh",  d - 2))
    ae = int(opt(spec, "almost_empty_thresh", 2))
    ab = max(1, (d-1).bit_length())
    cb = ab + 1
    rd = (f"    assign dout = mem[rd_ptr[{ab-1}:0]];\n" if fw else
          f"    reg [DATA_W-1:0] dout_r;\n"
          f"    always @(posedge clk) if (rd_en && !empty) dout_r <= mem[rd_ptr[{ab-1}:0]];\n"
          f"    assign dout = dout_r;\n")
    code = hdr(n, f"Sync FIFO depth={d} width={w}" + (" FWFT" if fw else ""))
    code += f"""\
module {n} #(
    parameter DEPTH  = {d}, parameter DATA_W = {w},
    parameter AF_THR = {af}, parameter AE_THR = {ae}
)(
    input  wire clk, rst_n, wr_en, rd_en,
    input  wire [DATA_W-1:0] din,
    output wire [DATA_W-1:0] dout,
    output wire full, empty, almost_full, almost_empty,
    output wire [{cb-1}:0] count
);
    localparam ABITS = {ab};
    reg [DATA_W-1:0] mem [0:DEPTH-1];
    reg [{cb-1}:0] wr_ptr, rd_ptr;
    assign count        = wr_ptr - rd_ptr;
    assign full         = (count == DEPTH[{cb-1}:0]);
    assign empty        = (count == 0);
    assign almost_full  = (count >= AF_THR[{cb-1}:0]);
    assign almost_empty = (count <= AE_THR[{cb-1}:0]);
    always @(posedge clk or negedge rst_n)
        if (!rst_n) wr_ptr <= 0;
        else if (wr_en && !full) begin mem[wr_ptr[ABITS-1:0]] <= din; wr_ptr <= wr_ptr+1; end
    always @(posedge clk or negedge rst_n)
        if (!rst_n) rd_ptr <= 0;
        else if (rd_en && !empty) rd_ptr <= rd_ptr+1;
{rd}endmodule
"""
    return {f"{n}.v": code}


def gen_async_fifo(spec):
    """Required: name, depth, data_width"""
    n  = opt(spec, "name", "async_fifo")
    d  = int(required(spec, "depth",      "async_fifo"))
    w  = int(required(spec, "data_width", "async_fifo"))
    ab = max(1, (d-1).bit_length())
    pb = ab + 1
    code = hdr(n, f"Async dual-clock FIFO depth={d} width={w} Gray-code ptrs")
    code += f"""\
module {n} #(parameter DEPTH={d}, parameter DATA_W={w})(
    input  wire wr_clk, wr_rst_n, wr_en,
    input  wire [DATA_W-1:0] din,
    output wire full,
    input  wire rd_clk, rd_rst_n, rd_en,
    output wire [DATA_W-1:0] dout,
    output wire empty
);
    localparam ABITS={ab}; localparam PBITS={pb};
    reg [DATA_W-1:0] mem [0:DEPTH-1];
    reg [PBITS-1:0] wr_bin,wr_gray,rd_bin,rd_gray;
    reg [PBITS-1:0] rdg1,rdg2,wrg1,wrg2;
    function [PBITS-1:0] b2g; input [PBITS-1:0] b; b2g=b^(b>>1); endfunction
    always @(posedge wr_clk or negedge wr_rst_n)
        if (!wr_rst_n) begin wr_bin<=0; wr_gray<=0; end
        else if (wr_en && !full) begin
            mem[wr_bin[ABITS-1:0]] <= din;
            wr_bin  <= wr_bin+1; wr_gray <= b2g(wr_bin+1); end
    always @(posedge wr_clk or negedge wr_rst_n)
        if (!wr_rst_n) begin rdg1<=0; rdg2<=0; end
        else begin rdg1<=rd_gray; rdg2<=rdg1; end
    assign full = (wr_gray == {{~rdg2[PBITS-1:PBITS-2], rdg2[PBITS-3:0]}});
    always @(posedge rd_clk or negedge rd_rst_n)
        if (!rd_rst_n) begin rd_bin<=0; rd_gray<=0; end
        else if (rd_en && !empty) begin rd_bin<=rd_bin+1; rd_gray<=b2g(rd_bin+1); end
    always @(posedge rd_clk or negedge rd_rst_n)
        if (!rd_rst_n) begin wrg1<=0; wrg2<=0; end
        else begin wrg1<=wr_gray; wrg2<=wrg1; end
    assign empty = (rd_gray==wrg2);
    assign dout  = mem[rd_bin[ABITS-1:0]];
endmodule
"""
    return {f"{n}.v": code}


def gen_sram_sp(spec):
    """Required: name, depth, data_width"""
    n    = opt(spec, "name", "sram_sp")
    d    = int(required(spec, "depth",      "sram_sp"))
    w    = int(required(spec, "data_width", "sram_sp"))
    ab   = max(1, (d-1).bit_length())
    bew  = w // 8
    code = hdr(n, f"Single-port SRAM depth={d} width={w} byte-enable")
    code += f"""\
module {n} #(parameter DEPTH={d}, parameter DATA_W={w}, parameter ABITS={ab})(
    input  wire clk, ce, we,
    input  wire [{bew-1}:0] be,
    input  wire [ABITS-1:0]  addr,
    input  wire [DATA_W-1:0] din,
    output reg  [DATA_W-1:0] dout
);
    reg [DATA_W-1:0] mem [0:DEPTH-1];
    integer bi;
    always @(posedge clk) if (ce) begin
        if (we) for (bi=0; bi<{bew}; bi=bi+1)
            if (be[bi]) mem[addr][bi*8+:8] <= din[bi*8+:8];
        dout <= mem[addr];
    end
endmodule
"""
    return {f"{n}.v": code}


def gen_sram_dp(spec):
    """Required: name, depth, data_width"""
    n    = opt(spec, "name", "sram_dp")
    d    = int(required(spec, "depth",      "sram_dp"))
    w    = int(required(spec, "data_width", "sram_dp"))
    ab   = max(1, (d-1).bit_length())
    code = hdr(n, f"Simple-dual-port SRAM (1W+1R) depth={d} width={w}")
    code += f"""\
module {n} #(parameter DEPTH={d}, parameter DATA_W={w}, parameter ABITS={ab})(
    input  wire wr_clk, wr_en,
    input  wire [3:0] wr_be,
    input  wire [ABITS-1:0]  wr_addr,
    input  wire [DATA_W-1:0] wr_din,
    input  wire rd_clk, rd_en,
    input  wire [ABITS-1:0]  rd_addr,
    output reg  [DATA_W-1:0] rd_dout
);
    reg [DATA_W-1:0] mem [0:DEPTH-1];
    integer bi;
    always @(posedge wr_clk)
        if (wr_en) for (bi=0; bi<4; bi=bi+1)
            if (wr_be[bi]) mem[wr_addr][bi*8+:8] <= wr_din[bi*8+:8];
    always @(posedge rd_clk) if (rd_en) rd_dout <= mem[rd_addr];
endmodule
"""
    return {f"{n}.v": code}


def gen_reset_sync(spec):
    """Required: name, stages"""
    n  = opt(spec, "name", "reset_sync")
    s  = int(required(spec, "stages", "reset_sync"))
    code = hdr(n, f"Async-assert/sync-deassert reset synchronizer ({s} stages)")
    code += f"""\
module {n} #(parameter STAGES={s})(
    input  wire clk, por_n, wdt_rst_n,
    output wire sys_rst_n
);
    wire async_rst_n = por_n & wdt_rst_n;
    reg [STAGES-1:0] chain;
    always @(posedge clk or negedge async_rst_n)
        if (!async_rst_n) chain <= 0;
        else              chain <= {{chain[STAGES-2:0], 1'b1}};
    assign sys_rst_n = chain[STAGES-1];
endmodule
"""
    return {f"{n}.v": code}


def gen_cdc_sync(spec):
    """Required: name, data_width. Optional: kind (2ff|pulse, default 2ff)"""
    n    = opt(spec, "name", "cdc_sync")
    w    = int(required(spec, "data_width", "cdc_sync"))
    kind = opt(spec, "kind", "2ff")
    wp   = f"[{w-1}:0] " if w > 1 else ""
    if kind == "pulse":
        code = hdr(n, "Pulse synchronizer toggle+3FF")
        code += f"""\
module {n} (
    input  wire src_clk, src_rst_n, src_pulse,
    input  wire dst_clk, dst_rst_n,
    output wire dst_pulse
);
    reg tgl;
    always @(posedge src_clk or negedge src_rst_n)
        if (!src_rst_n) tgl<=0; else if (src_pulse) tgl<=~tgl;
    reg s1,s2,s3;
    always @(posedge dst_clk or negedge dst_rst_n)
        if (!dst_rst_n) {{s1,s2,s3}}<=0;
        else begin s1<=tgl; s2<=s1; s3<=s2; end
    assign dst_pulse = s2^s3;
endmodule
"""
    else:
        code = hdr(n, f"2-FF CDC synchronizer {w}-bit")
        code += f"""\
module {n} #(parameter DATA_W={w})(
    input  wire dst_clk, dst_rst_n,
    input  wire {wp}src_data,
    output wire {wp}dst_data
);
    reg {wp}ff1, ff2;
    always @(posedge dst_clk or negedge dst_rst_n)
        if (!dst_rst_n) begin ff1<=0; ff2<=0; end
        else begin ff1<=src_data; ff2<=ff1; end
    assign dst_data = ff2;
endmodule
"""
    return {f"{n}.v": code}


def gen_perf_counter(spec):
    """Required: name, channels, counter_width"""
    n  = opt(spec, "name", "perf_counter")
    ch = int(required(spec, "channels",      "perf_counter"))
    w  = int(required(spec, "counter_width", "perf_counter"))
    ports  = "\n".join(f"    input  wire        event_{i}," for i in range(ch))
    regs   = "\n".join(f"    reg [{w-1}:0] cnt{i};" for i in range(ch))
    clr    = "\n".join(f"            cnt{i}<=0;" for i in range(ch))
    inc    = "\n".join(f"            if(event_{i}) cnt{i}<=cnt{i}+1;" for i in range(ch))
    cases  = "\n".join(f"        {i*4}: prdata=cnt{i};" for i in range(ch))
    code = hdr(n, f"Perf counter {ch}ch {w}b")
    code += f"""\
module {n} (
    input  wire pclk, presetn,
{ports}
    input  wire psel, penable, pwrite,
    input  wire [11:0] paddr, input  wire [31:0] pwdata,
    output reg  [31:0] prdata, output wire pready, pslverr
);
    assign pready=1; assign pslverr=0;
{regs}
    always @(posedge pclk or negedge presetn)
        if (!presetn) begin {clr} end
        else begin
{inc}
            if (psel&&penable&&pwrite&&paddr==0) begin {clr} end
        end
    always @(*) case(paddr)
{cases}
        default: prdata=32'hDEAD_BEEF;
    endcase
endmodule
"""
    return {f"{n}.v": code}


GENERATORS = {
    "sync_fifo":    gen_sync_fifo,
    "async_fifo":   gen_async_fifo,
    "sram_sp":      gen_sram_sp,
    "sram_dp":      gen_sram_dp,
    "reset_sync":   gen_reset_sync,
    "cdc_sync":     gen_cdc_sync,
    "perf_counter": gen_perf_counter,
}
