// =============================================================================
// Module: dma1
// Desc  : 1-ch AXI4-Lite M2M DMA, burst=4, data=32b
// NXP ICLAD 2026 RTL Gen Library
// =============================================================================
`timescale 1ns/1ps

// Single-channel memory-to-memory DMA
// Config slave: AXI4-Lite (cfg_* ports)
// Master: AXI4-Lite (m_* ports)
module dma1 #(
    parameter DATA_W = 32,
    parameter ADDR_W = 32,
    parameter BURST_LEN = 4
)(
    input  wire            aclk, aresetn,
    // Config AXI4-Lite slave
    input  wire [11:0]     cfg_awaddr, input wire cfg_awvalid, output wire cfg_awready,
    input  wire [31:0]     cfg_wdata,  input wire [3:0] cfg_wstrb,
    input  wire            cfg_wvalid, output wire cfg_wready,
    output wire [1:0]      cfg_bresp,  output wire cfg_bvalid, input wire cfg_bready,
    input  wire [11:0]     cfg_araddr, input wire cfg_arvalid, output wire cfg_arready,
    output reg  [31:0]     cfg_rdata,  output wire [1:0] cfg_rresp,
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
