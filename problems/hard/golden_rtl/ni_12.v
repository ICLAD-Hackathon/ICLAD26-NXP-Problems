// =============================================================================
// Module: ni_12
// Desc  : TileLink-UL Network Interface (AXI4-Lite → TL-UL) data=64b
// NXP ICLAD 2026 RTL Gen Library
// =============================================================================
`timescale 1ns/1ps

// Bridges AXI4-Lite master to TileLink Uncached Lightweight (TL-UL)
// TL-UL opcodes: Get=4, PutFullData=0, PutPartialData=1
module ni_12 #(
    parameter DATA_W   = 64,
    parameter ADDR_W   = 32,
    parameter SOURCE_W = 4,
    parameter SIZE_W   = 3,
    parameter MASK_W   = 8
)(
    input  wire clk, rst_n,
    // AXI4-Lite master (upstream)
    input  wire [ADDR_W-1:0] axi_awaddr, input wire axi_awvalid, output wire axi_awready,
    input  wire [DATA_W-1:0] axi_wdata,  input wire [MASK_W-1:0] axi_wstrb,
    input  wire axi_wvalid, output wire axi_wready,
    output wire [1:0] axi_bresp, output wire axi_bvalid, input wire axi_bready,
    input  wire [ADDR_W-1:0] axi_araddr, input wire axi_arvalid, output wire axi_arready,
    output wire [DATA_W-1:0] axi_rdata,  output wire [1:0] axi_rresp,
    output wire axi_rvalid, input wire axi_rready,
    // TL-UL channel A (output to NoC)
    output wire [2:0]           tl_a_opcode,
    output wire [2:0]           tl_a_param,
    output wire [SIZE_W-1:0]    tl_a_size,
    output wire [SOURCE_W-1:0]  tl_a_source,
    output wire [ADDR_W-1:0]    tl_a_addr,
    output wire [MASK_W-1:0]    tl_a_mask,
    output wire [DATA_W-1:0]    tl_a_data,
    output wire                 tl_a_valid,
    input  wire                 tl_a_ready,
    // TL-UL channel D (input from NoC)
    input  wire [2:0]           tl_d_opcode,
    input  wire [1:0]           tl_d_param,
    input  wire [SIZE_W-1:0]    tl_d_size,
    input  wire [SOURCE_W-1:0]  tl_d_source,
    input  wire [DATA_W-1:0]    tl_d_data,
    input  wire                 tl_d_valid,
    output wire                 tl_d_ready
);
    // State machine: IDLE → SEND_A → WAIT_D
    localparam S_IDLE=2'd0, S_SEND=2'd1, S_WAIT=2'd2;
    reg [1:0] st;
    reg [ADDR_W-1:0] r_addr; reg [DATA_W-1:0] r_wdata;
    reg [MASK_W-1:0] r_mask; reg is_write;
    reg [DATA_W-1:0] r_rdata; reg [1:0] r_resp;
    reg r_done; reg [DATA_W-1:0] r_rdata_lat;

    assign axi_awready = (st==S_IDLE) && axi_awvalid && !is_write;
    assign axi_wready  = (st==S_IDLE) && axi_wvalid && axi_awvalid;
    assign axi_arready = (st==S_IDLE) && axi_arvalid && !axi_awvalid;
    assign axi_bvalid  = (st==S_IDLE) && r_done && is_write;
    assign axi_bresp   = 2'b00;
    assign axi_rvalid  = (st==S_IDLE) && r_done && !is_write;
    assign axi_rdata   = r_rdata_lat;
    assign axi_rresp   = 2'b00;
    assign tl_a_opcode = is_write ? 3'd0 : 3'd4;  // PutFullData or Get
    assign tl_a_param  = 3'd0;
    assign tl_a_size   = 3'd2;  // 4 bytes
    assign tl_a_source = 4'd0;
    assign tl_a_addr   = r_addr;
    assign tl_a_mask   = is_write ? r_mask : {MASK_W{1'b1}};
    assign tl_a_data   = r_wdata;
    assign tl_a_valid  = (st==S_SEND);
    assign tl_d_ready  = (st==S_WAIT);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin st<=S_IDLE; r_addr<=0; r_wdata<=0; r_mask<=0; is_write<=0; end
        else case(st)
            S_IDLE: begin
                r_done <= 0;
                if (axi_awvalid && axi_wvalid) begin
                    r_addr<=axi_awaddr; r_wdata<=axi_wdata; r_mask<=axi_wstrb;
                    is_write<=1; st<=S_SEND;
                end else if (axi_arvalid && !axi_awvalid) begin
                    r_addr<=axi_araddr; is_write<=0; st<=S_SEND;
                end
            end
            S_SEND: if (tl_a_ready) st<=S_WAIT;
            S_WAIT: if (tl_d_valid) begin r_done<=1; r_rdata_lat<=tl_d_data; st<=S_IDLE; end
            default: st<=S_IDLE;
        endcase
    end
endmodule
