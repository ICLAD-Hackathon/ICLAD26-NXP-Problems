// =============================================================================
// Module: axi_lite_xbar
// Desc  : AXI4-Lite 2M×3S crossbar round-robin arb data=32b addr=32b
// NXP ICLAD 2026 RTL Gen Library
// =============================================================================
`timescale 1ns/1ps

module axi_lite_xbar #(parameter DATA_W=32, parameter ADDR_W=32)(
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
    function s0_hit; input [31:0] a; s0_hit=((a&32'hFFFF0000)!=32'hF0000000) && ((a&32'hFFFF0000)!=32'hF0010000); endfunction
    function s1_hit; input [31:0] a; s1_hit=(a&32'hFFFF0000)==32'hF0000000; endfunction
    function s2_hit; input [31:0] a; s2_hit=(a&32'hFFFF0000)==32'hF0010000; endfunction

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
