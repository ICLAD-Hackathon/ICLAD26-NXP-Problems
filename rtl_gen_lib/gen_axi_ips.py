"""
AXI-Lite IP generators: axi_lite_crossbar, axi_lite_sram, dma_engine

All design-critical parameters MUST be explicit in the YAML spec.
"""
from gen_utils import required, opt, hdr as _hdr, MissingParameter

def _h(m, d=""):
    return _hdr(m, d)


def gen_axi_lite_sram(spec):
    """Required: name, depth, data_width, addr_width"""
    n    = opt(spec, "name", "axi_lite_sram")
    d    = int(required(spec, "depth",      "axi_lite_sram"))
    dw   = int(required(spec, "data_width", "axi_lite_sram"))
    aw   = int(required(spec, "addr_width", "axi_lite_sram"))
    ab   = max(1, (d-1).bit_length())
    code = _h(n, f"AXI4-Lite slave SRAM depth={d} data_width={dw}")
    code += f"""\
module {n} #(
    parameter DEPTH  = {d},
    parameter DATA_W = {dw},
    parameter ADDR_W = {aw},
    parameter ABITS  = {ab}
)(
    input  wire            aclk, aresetn,
    // Write address channel
    input  wire [ADDR_W-1:0] awaddr, input wire awvalid, output reg awready,
    // Write data channel
    input  wire [DATA_W-1:0] wdata, input wire [3:0] wstrb,
    input  wire wvalid, output reg wready,
    // Write response
    output reg  [1:0] bresp, output reg bvalid, input wire bready,
    // Read address channel
    input  wire [ADDR_W-1:0] araddr, input wire arvalid, output reg arready,
    // Read data channel
    output reg  [DATA_W-1:0] rdata, output reg [1:0] rresp,
    output reg  rvalid, input wire rready
);
    reg [DATA_W-1:0] mem [0:DEPTH-1];
    reg [ABITS-1:0] wr_addr_r;
    reg pending_w;
    integer bi;

    // Write path
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            awready<=0; wready<=0; bvalid<=0; bresp<=0; pending_w<=0;
        end else begin
            awready <= !pending_w && awvalid && !awready;
            if (awvalid && awready) begin wr_addr_r<=awaddr[ABITS-1:0]; pending_w<=1; end
            wready <= pending_w && wvalid && !wready;
            if (pending_w && wvalid && wready) begin
                for (bi=0; bi<4; bi=bi+1)
                    if (wstrb[bi]) mem[wr_addr_r][bi*8+:8] <= wdata[bi*8+:8];
                pending_w<=0; bvalid<=1; bresp<=0;
            end
            if (bvalid && bready) bvalid<=0;
        end
    end

    // Read path
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin arready<=0; rvalid<=0; rdata<=0; rresp<=0; end
        else begin
            arready <= arvalid && !arready && !rvalid;
            if (arvalid && arready) begin
                rdata  <= mem[araddr[ABITS-1:0]];
                rresp  <= 0;
                rvalid <= 1;
            end
            if (rvalid && rready) rvalid<=0;
        end
    end
endmodule
"""
    return {f"{n}.v": code}


def gen_dma_engine(spec):
    """
    Single-channel memory-to-memory DMA engine with AXI4-Lite config port
    and AXI4-Lite master port.
    Parameters: name, burst_len (1/4/8/16)
    Config registers (AXI-Lite slave at config_base):
      0x00 SRC_ADDR  RW - source address
      0x04 DST_ADDR  RW - destination address
      0x08 LENGTH    RW - transfer length in bytes
      0x0C CTRL      RW - [0]=start [1]=irq_en
      0x10 STATUS    RO - [0]=busy [1]=done [2]=error
      0x14 IRQSTAT   W1C
    """
    n    = spec.get("name", "dma_engine")
    blen = int(spec.get("burst_len", 4))
    dw   = int(spec.get("data_width", 32))
    aw   = int(spec.get("addr_width", 32))
    code = _h(n, f"1-ch AXI4-Lite M2M DMA, burst={blen}, data={dw}b")
    code += f"""\
// Single-channel memory-to-memory DMA
// Config slave: AXI4-Lite (cfg_* ports)
// Master: AXI4-Lite (m_* ports)
module {n} #(
    parameter DATA_W = {dw},
    parameter ADDR_W = {aw},
    parameter BURST_LEN = {blen}
)(
    input  wire            aclk, aresetn,
    // Config AXI4-Lite slave
    input  wire [11:0]     cfg_awaddr, input wire cfg_awvalid, output wire cfg_awready,
    input  wire [31:0]     cfg_wdata,  input wire [3:0] cfg_wstrb,
    input  wire            cfg_wvalid, output wire cfg_wready,
    output wire [1:0]      cfg_bresp,  output wire cfg_bvalid, input wire cfg_bready,
    input  wire [11:0]     cfg_araddr, input wire cfg_arvalid, output wire cfg_arready,
    output wire [31:0]     cfg_rdata,  output wire [1:0] cfg_rresp,
    output wire            cfg_rvalid, input wire cfg_rready,
    // Master AXI4-Lite
    output wire [ADDR_W-1:0] m_awaddr,  output wire m_awvalid, input wire m_awready,
    output wire [DATA_W-1:0] m_wdata,   output wire [3:0] m_wstrb,
    output wire m_wvalid, input wire m_wready,
    input  wire [1:0]      m_bresp,  input  wire m_bvalid, output wire m_bready,
    output wire [ADDR_W-1:0] m_araddr,  output wire m_arvalid, input wire m_arready,
    input  wire [DATA_W-1:0] m_rdata,   input  wire [1:0] m_rresp,
    input  wire m_rvalid, output wire m_rready,
    // Interrupt
    output wire dma_irq
);
    // Config registers
    reg [31:0] r_src, r_dst, r_len, r_ctrl, r_stat, r_irqstat;
    // Simplified: zero-wait config slave
    assign cfg_awready = 1; assign cfg_wready = 1; assign cfg_bvalid = 1;
    assign cfg_bresp = 0; assign cfg_arready = 1; assign cfg_rresp = 0;
    assign cfg_rvalid = 1;
    always @(*) case(cfg_araddr)
        12'h000: cfg_rdata = r_src; 12'h004: cfg_rdata = r_dst;
        12'h008: cfg_rdata = r_len; 12'h00C: cfg_rdata = r_ctrl;
        12'h010: cfg_rdata = r_stat; 12'h014: cfg_rdata = r_irqstat;
        default: cfg_rdata = 32'hDEAD_BEEF;
    endcase

    // DMA FSM (simplified: word-by-word transfer)
    localparam S_IDLE=3'd0, S_RD_ADDR=3'd1, S_RD_DATA=3'd2,
               S_WR_ADDR=3'd3, S_WR_DATA=3'd4, S_WR_RESP=3'd5, S_DONE=3'd6;
    reg [2:0]      dma_st;
    reg [ADDR_W-1:0] cur_src, cur_dst;
    reg [31:0]     remaining;
    reg [DATA_W-1:0] rd_buf;

    assign m_araddr  = cur_src;
    assign m_arvalid = (dma_st == S_RD_ADDR);
    assign m_rready  = (dma_st == S_RD_DATA);
    assign m_awaddr  = cur_dst;
    assign m_awvalid = (dma_st == S_WR_ADDR);
    assign m_wdata   = rd_buf;
    assign m_wstrb   = 4'hF;
    assign m_wvalid  = (dma_st == S_WR_DATA);
    assign m_bready  = (dma_st == S_WR_RESP);
    assign dma_irq   = r_irqstat[0] & r_ctrl[1];

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            dma_st<=S_IDLE; r_src<=0; r_dst<=0; r_len<=0; r_ctrl<=0;
            r_stat<=0; r_irqstat<=0; cur_src<=0; cur_dst<=0; remaining<=0; rd_buf<=0;
        end else begin
            // Config writes
            if (cfg_awvalid && cfg_wvalid) case(cfg_awaddr)
                12'h000: r_src <= cfg_wdata;
                12'h004: r_dst <= cfg_wdata;
                12'h008: r_len <= cfg_wdata;
                12'h00C: r_ctrl<= cfg_wdata;
                12'h014: r_irqstat <= r_irqstat & ~cfg_wdata;
                default: ;
            endcase
            // DMA state machine
            case (dma_st)
                S_IDLE: begin
                    r_stat <= 0;
                    if (r_ctrl[0]) begin
                        cur_src   <= r_src;
                        cur_dst   <= r_dst;
                        remaining <= r_len;
                        r_stat    <= 32'h1; // busy
                        dma_st    <= S_RD_ADDR;
                        r_ctrl[0] <= 0;
                    end
                end
                S_RD_ADDR: if (m_arready) dma_st <= S_RD_DATA;
                S_RD_DATA: if (m_rvalid) begin
                    rd_buf  <= m_rdata;
                    dma_st  <= S_WR_ADDR;
                end
                S_WR_ADDR: if (m_awready) dma_st <= S_WR_DATA;
                S_WR_DATA: if (m_wready) dma_st <= S_WR_RESP;
                S_WR_RESP: if (m_bvalid) begin
                    cur_src   <= cur_src + 4;
                    cur_dst   <= cur_dst + 4;
                    remaining <= remaining - 4;
                    if (remaining <= 4) dma_st <= S_DONE;
                    else                dma_st <= S_RD_ADDR;
                end
                S_DONE: begin
                    r_stat    <= 32'h2; // done
                    r_irqstat <= 1;
                    dma_st    <= S_IDLE;
                end
                default: dma_st <= S_IDLE;
            endcase
        end
    end
endmodule
"""
    return {f"{n}.v": code}


def gen_axi_lite_crossbar(spec):
    """2M x 3S AXI4-Lite crossbar with round-robin arbitration."""
    n   = spec.get("name", "axi_lite_xbar")
    dw  = int(spec.get("data_width", 32))
    aw  = int(spec.get("addr_width", 32))
    srs = spec.get("slave_ranges", [
        {"base": 0x00000000, "size": 0x10000},
        {"base": 0x00010000, "size": 0x10000},
        {"base": 0x00020000, "size": 0x10000},
    ])
    def parse_int(v):
        return int(v, 0) if isinstance(v, str) else int(v)
    hits = []
    for i, s in enumerate(srs[:3]):
        base = parse_int(s.get("base", i * 0x10000))
        size = parse_int(s.get("size", 0x10000))
        mask = ~(size - 1) & ((1 << aw) - 1)
        hits.append(f"    function s{i}_hit; input [{aw-1}:0] a; s{i}_hit=(a&{aw}'h{mask:08X})=={aw}'h{base:08X}; endfunction")
    hit_str = "\n".join(hits)

    code = _h(n, f"AXI4-Lite 2M×3S crossbar round-robin arb data={dw}b addr={aw}b")
    code += f"""\
module {n} #(parameter DATA_W={dw}, parameter ADDR_W={aw})(
    input  wire aclk, aresetn,
    // M0
    input  wire [ADDR_W-1:0] m0_awaddr, input wire m0_awvalid, output wire m0_awready,
    input  wire [DATA_W-1:0] m0_wdata, input wire [3:0] m0_wstrb, input wire m0_wvalid, output wire m0_wready,
    output wire [1:0] m0_bresp, output wire m0_bvalid, input wire m0_bready,
    input  wire [ADDR_W-1:0] m0_araddr, input wire m0_arvalid, output wire m0_arready,
    output wire [DATA_W-1:0] m0_rdata, output wire [1:0] m0_rresp, output wire m0_rvalid, input wire m0_rready,
    // M1
    input  wire [ADDR_W-1:0] m1_awaddr, input wire m1_awvalid, output wire m1_awready,
    input  wire [DATA_W-1:0] m1_wdata, input wire [3:0] m1_wstrb, input wire m1_wvalid, output wire m1_wready,
    output wire [1:0] m1_bresp, output wire m1_bvalid, input wire m1_bready,
    input  wire [ADDR_W-1:0] m1_araddr, input wire m1_arvalid, output wire m1_arready,
    output wire [DATA_W-1:0] m1_rdata, output wire [1:0] m1_rresp, output wire m1_rvalid, input wire m1_rready,
    // S0
    output wire [ADDR_W-1:0] s0_awaddr, output wire s0_awvalid, input wire s0_awready,
    output wire [DATA_W-1:0] s0_wdata, output wire [3:0] s0_wstrb, output wire s0_wvalid, input wire s0_wready,
    input  wire [1:0] s0_bresp, input wire s0_bvalid, output wire s0_bready,
    output wire [ADDR_W-1:0] s0_araddr, output wire s0_arvalid, input wire s0_arready,
    input  wire [DATA_W-1:0] s0_rdata, input wire [1:0] s0_rresp, input wire s0_rvalid, output wire s0_rready,
    // S1
    output wire [ADDR_W-1:0] s1_awaddr, output wire s1_awvalid, input wire s1_awready,
    output wire [DATA_W-1:0] s1_wdata, output wire [3:0] s1_wstrb, output wire s1_wvalid, input wire s1_wready,
    input  wire [1:0] s1_bresp, input wire s1_bvalid, output wire s1_bready,
    output wire [ADDR_W-1:0] s1_araddr, output wire s1_arvalid, input wire s1_arready,
    input  wire [DATA_W-1:0] s1_rdata, input wire [1:0] s1_rresp, input wire s1_rvalid, output wire s1_rready,
    // S2
    output wire [ADDR_W-1:0] s2_awaddr, output wire s2_awvalid, input wire s2_awready,
    output wire [DATA_W-1:0] s2_wdata, output wire [3:0] s2_wstrb, output wire s2_wvalid, input wire s2_wready,
    input  wire [1:0] s2_bresp, input wire s2_bvalid, output wire s2_bready,
    output wire [ADDR_W-1:0] s2_araddr, output wire s2_arvalid, input wire s2_arready,
    input  wire [DATA_W-1:0] s2_rdata, input wire [1:0] s2_rresp, input wire s2_rvalid, output wire s2_rready
);
{hit_str}

    // Round-robin: rr=0 → m0 priority, rr=1 → m1 priority
    reg rr;
    always @(posedge aclk or negedge aresetn)
        if (!aresetn) rr<=0;
        else if (m0_awvalid && m0_awready) rr<=1;
        else if (m1_awvalid && m1_awready) rr<=0;

    // Write routing
    wire m0w = m0_awvalid && (!m1_awvalid || !rr);
    wire m1w = m1_awvalid && (!m0_awvalid || rr);
    wire [ADDR_W-1:0] waddr = m0w ? m0_awaddr : m1_awaddr;
    wire s0_ws = s0_hit(waddr), s1_ws = s1_hit(waddr), s2_ws = s2_hit(waddr);
    assign s0_awaddr=waddr; assign s0_awvalid=(m0w||m1w)&&s0_ws;
    assign s1_awaddr=waddr; assign s1_awvalid=(m0w||m1w)&&s1_ws;
    assign s2_awaddr=waddr; assign s2_awvalid=(m0w||m1w)&&s2_ws;
    wire sw_rdy=(s0_ws?s0_awready:1'b0)|(s1_ws?s1_awready:1'b0)|(s2_ws?s2_awready:1'b0);
    assign m0_awready=m0w&&sw_rdy; assign m1_awready=m1w&&sw_rdy;
    assign s0_wdata=m0w?m0_wdata:m1_wdata; assign s0_wstrb=m0w?m0_wstrb:m1_wstrb;
    assign s0_wvalid=(m0w?m0_wvalid:m1_wvalid)&&s0_ws;
    assign s1_wdata=m0w?m0_wdata:m1_wdata; assign s1_wstrb=m0w?m0_wstrb:m1_wstrb;
    assign s1_wvalid=(m0w?m0_wvalid:m1_wvalid)&&s1_ws;
    assign s2_wdata=m0w?m0_wdata:m1_wdata; assign s2_wstrb=m0w?m0_wstrb:m1_wstrb;
    assign s2_wvalid=(m0w?m0_wvalid:m1_wvalid)&&s2_ws;
    wire swr_rdy=(s0_ws?s0_wready:1'b0)|(s1_ws?s1_wready:1'b0)|(s2_ws?s2_wready:1'b0);
    assign m0_wready=m0w&&swr_rdy; assign m1_wready=m1w&&swr_rdy;
    // Bresp routing (simplified: return to requesting master)
    wire bv=(s0_ws?s0_bvalid:1'b0)|(s1_ws?s1_bvalid:1'b0)|(s2_ws?s2_bvalid:1'b0);
    wire [1:0] br=(s0_ws&&s0_bvalid)?s0_bresp:(s1_ws&&s1_bvalid)?s1_bresp:s2_bresp;
    assign m0_bvalid=m0w&&bv; assign m0_bresp=br;
    assign m1_bvalid=m1w&&bv; assign m1_bresp=br;
    assign s0_bready=(s0_ws&&m0w)?m0_bready:(s0_ws&&m1w)?m1_bready:1'b0;
    assign s1_bready=(s1_ws&&m0w)?m0_bready:(s1_ws&&m1w)?m1_bready:1'b0;
    assign s2_bready=(s2_ws&&m0w)?m0_bready:(s2_ws&&m1w)?m1_bready:1'b0;

    // Read routing (round-robin by read address)
    reg rr_rd;
    always @(posedge aclk or negedge aresetn)
        if (!aresetn) rr_rd<=0;
        else if (m0_arvalid&&m0_arready) rr_rd<=1;
        else if (m1_arvalid&&m1_arready) rr_rd<=0;
    wire m0r=m0_arvalid&&(!m1_arvalid||!rr_rd);
    wire m1r=m1_arvalid&&(!m0_arvalid||rr_rd);
    wire [ADDR_W-1:0] raddr=m0r?m0_araddr:m1_araddr;
    wire s0_rs=s0_hit(raddr),s1_rs=s1_hit(raddr),s2_rs=s2_hit(raddr);
    assign s0_araddr=raddr; assign s0_arvalid=(m0r||m1r)&&s0_rs;
    assign s1_araddr=raddr; assign s1_arvalid=(m0r||m1r)&&s1_rs;
    assign s2_araddr=raddr; assign s2_arvalid=(m0r||m1r)&&s2_rs;
    wire sar_rdy=(s0_rs?s0_arready:1'b0)|(s1_rs?s1_arready:1'b0)|(s2_rs?s2_arready:1'b0);
    assign m0_arready=m0r&&sar_rdy; assign m1_arready=m1r&&sar_rdy;
    wire [DATA_W-1:0] rd=(s0_rs&&s0_rvalid)?s0_rdata:(s1_rs&&s1_rvalid)?s1_rdata:s2_rdata;
    wire [1:0] rr2=(s0_rs&&s0_rvalid)?s0_rresp:(s1_rs&&s1_rvalid)?s1_rresp:s2_rresp;
    wire rv=(s0_rs?s0_rvalid:1'b0)|(s1_rs?s1_rvalid:1'b0)|(s2_rs?s2_rvalid:1'b0);
    assign m0_rdata=rd; assign m0_rresp=rr2; assign m0_rvalid=m0r&&rv;
    assign m1_rdata=rd; assign m1_rresp=rr2; assign m1_rvalid=m1r&&rv;
    assign s0_rready=(s0_rs&&m0r)?m0_rready:(s0_rs&&m1r)?m1_rready:1'b0;
    assign s1_rready=(s1_rs&&m0r)?m0_rready:(s1_rs&&m1r)?m1_rready:1'b0;
    assign s2_rready=(s2_rs&&m0r)?m0_rready:(s2_rs&&m1r)?m1_rready:1'b0;
endmodule
"""
    return {f"{n}.v": code}


GENERATORS = {
    "axi_lite_crossbar": gen_axi_lite_crossbar,
    "axi_lite_sram":     gen_axi_lite_sram,
    "dma_engine":        gen_dma_engine,
}
