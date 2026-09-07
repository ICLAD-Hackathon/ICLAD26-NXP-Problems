// =============================================================================
// Module: async_fifo_mbox
// Desc  : Async dual-clock FIFO depth=16 width=32 Gray-code ptrs
// NXP ICLAD 2026 RTL Gen Library
// =============================================================================
`timescale 1ns/1ps

module async_fifo_mbox #(parameter DEPTH=16, parameter DATA_W=32)(
    input  wire wr_clk, wr_rst_n, wr_en,
    input  wire [DATA_W-1:0] din,
    output wire full,
    input  wire rd_clk, rd_rst_n, rd_en,
    output wire [DATA_W-1:0] dout,
    output wire empty
);
    localparam ABITS=4; localparam PBITS=5;
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
    assign full = (wr_gray == {~rdg2[PBITS-1:PBITS-2], rdg2[PBITS-3:0]});
    always @(posedge rd_clk or negedge rd_rst_n)
        if (!rd_rst_n) begin rd_bin<=0; rd_gray<=0; end
        else if (rd_en && !empty) begin rd_bin<=rd_bin+1; rd_gray<=b2g(rd_bin+1); end
    always @(posedge rd_clk or negedge rd_rst_n)
        if (!rd_rst_n) begin wrg1<=0; wrg2<=0; end
        else begin wrg1<=wr_gray; wrg2<=wrg1; end
    assign empty = (rd_gray==wrg2);
    assign dout  = mem[rd_bin[ABITS-1:0]];
endmodule
