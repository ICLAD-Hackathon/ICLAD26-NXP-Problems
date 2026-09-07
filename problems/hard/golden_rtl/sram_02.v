// =============================================================================
// Module: sram_02
// Desc  : AXI4-Lite slave SRAM depth=256 data_width=64
// NXP ICLAD 2026 RTL Gen Library
// =============================================================================
`timescale 1ns/1ps

module sram_02 #(
    parameter DEPTH  = 256,
    parameter DATA_W = 64,
    parameter ADDR_W = 32,
    parameter ABITS  = 8
)(
    input  wire            aclk, aresetn,
    // Write address channel
    input  wire [ADDR_W-1:0] awaddr, input wire awvalid, output reg awready,
    // Write data channel
    input  wire [DATA_W-1:0] wdata, input wire [7:0] wstrb,
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
                for (bi=0; bi<8; bi=bi+1)
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
