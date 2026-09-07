// ===========================================================================
// Module: router_11
// Desc  : TileLink-UL mesh router node=(1,1) with forwarding + local AXI
// NXP ICLAD 2026 RTL Gen Library
// ===========================================================================
`timescale 1ns/1ps

// TileLink-UL 5-port mesh router with full forwarding
// p0=North p1=South p2=East p3=West
// Each mesh port: A-in (receive from neighbor) + A-out (forward to neighbor)
//                 D-out (respond to neighbor) + D-in (receive response from neighbor)
// inj port: injection from NI (AXI->TL NI injects here)
// local AXI port: direct AXI connection to SRAM
// addr[31:28]=dest_x  addr[27:24]=dest_y
module router_11 #(
    parameter NODE_X   = 1,
    parameter NODE_Y   = 1,
    parameter DATA_W   = 64,
    parameter ADDR_W   = 32,
    parameter SIZE_W   = 3,
    parameter SOURCE_W = 4,
    parameter MASK_W   = 8
)(
    input  wire clk, rst_n,
    // --- Port 0 (North): A-in from north, A-out forward north, D bidirectional ---
    input  wire [2:0]          p0_a_opcode, p0_a_param,
    input  wire [SIZE_W-1:0]   p0_a_size,
    input  wire [SOURCE_W-1:0] p0_a_source,
    input  wire [ADDR_W-1:0]   p0_a_addr,
    input  wire [MASK_W-1:0]   p0_a_mask,
    input  wire [DATA_W-1:0]   p0_a_data,
    input  wire                p0_a_valid,
    output wire                p0_a_ready,
    output wire [2:0]          p0_d_opcode,
    output wire [1:0]          p0_d_param,
    output wire [SIZE_W-1:0]   p0_d_size,
    output wire [SOURCE_W-1:0] p0_d_source,
    output wire [DATA_W-1:0]   p0_d_data,
    output wire                p0_d_valid,
    input  wire                p0_d_ready,
    // Forwarding output and response-in for North
    output wire [2:0]          p0_ao_opcode, p0_ao_param,
    output wire [SIZE_W-1:0]   p0_ao_size,
    output wire [SOURCE_W-1:0] p0_ao_source,
    output wire [ADDR_W-1:0]   p0_ao_addr,
    output wire [MASK_W-1:0]   p0_ao_mask,
    output wire [DATA_W-1:0]   p0_ao_data,
    output wire                p0_ao_valid,
    input  wire                p0_ao_ready,
    input  wire [2:0]          p0_di_opcode,
    input  wire [1:0]          p0_di_param,
    input  wire [SIZE_W-1:0]   p0_di_size,
    input  wire [SOURCE_W-1:0] p0_di_source,
    input  wire [DATA_W-1:0]   p0_di_data,
    input  wire                p0_di_valid,
    output wire                p0_di_ready,
    // --- Port 1 (South): A-in from south, A-out forward south, D bidirectional ---
    input  wire [2:0]          p1_a_opcode, p1_a_param,
    input  wire [SIZE_W-1:0]   p1_a_size,
    input  wire [SOURCE_W-1:0] p1_a_source,
    input  wire [ADDR_W-1:0]   p1_a_addr,
    input  wire [MASK_W-1:0]   p1_a_mask,
    input  wire [DATA_W-1:0]   p1_a_data,
    input  wire                p1_a_valid,
    output wire                p1_a_ready,
    output wire [2:0]          p1_d_opcode,
    output wire [1:0]          p1_d_param,
    output wire [SIZE_W-1:0]   p1_d_size,
    output wire [SOURCE_W-1:0] p1_d_source,
    output wire [DATA_W-1:0]   p1_d_data,
    output wire                p1_d_valid,
    input  wire                p1_d_ready,
    // Forwarding output and response-in for South
    output wire [2:0]          p1_ao_opcode, p1_ao_param,
    output wire [SIZE_W-1:0]   p1_ao_size,
    output wire [SOURCE_W-1:0] p1_ao_source,
    output wire [ADDR_W-1:0]   p1_ao_addr,
    output wire [MASK_W-1:0]   p1_ao_mask,
    output wire [DATA_W-1:0]   p1_ao_data,
    output wire                p1_ao_valid,
    input  wire                p1_ao_ready,
    input  wire [2:0]          p1_di_opcode,
    input  wire [1:0]          p1_di_param,
    input  wire [SIZE_W-1:0]   p1_di_size,
    input  wire [SOURCE_W-1:0] p1_di_source,
    input  wire [DATA_W-1:0]   p1_di_data,
    input  wire                p1_di_valid,
    output wire                p1_di_ready,
    // --- Port 2 (East): A-in from east, A-out forward east, D bidirectional ---
    input  wire [2:0]          p2_a_opcode, p2_a_param,
    input  wire [SIZE_W-1:0]   p2_a_size,
    input  wire [SOURCE_W-1:0] p2_a_source,
    input  wire [ADDR_W-1:0]   p2_a_addr,
    input  wire [MASK_W-1:0]   p2_a_mask,
    input  wire [DATA_W-1:0]   p2_a_data,
    input  wire                p2_a_valid,
    output wire                p2_a_ready,
    output wire [2:0]          p2_d_opcode,
    output wire [1:0]          p2_d_param,
    output wire [SIZE_W-1:0]   p2_d_size,
    output wire [SOURCE_W-1:0] p2_d_source,
    output wire [DATA_W-1:0]   p2_d_data,
    output wire                p2_d_valid,
    input  wire                p2_d_ready,
    // Forwarding output and response-in for East
    output wire [2:0]          p2_ao_opcode, p2_ao_param,
    output wire [SIZE_W-1:0]   p2_ao_size,
    output wire [SOURCE_W-1:0] p2_ao_source,
    output wire [ADDR_W-1:0]   p2_ao_addr,
    output wire [MASK_W-1:0]   p2_ao_mask,
    output wire [DATA_W-1:0]   p2_ao_data,
    output wire                p2_ao_valid,
    input  wire                p2_ao_ready,
    input  wire [2:0]          p2_di_opcode,
    input  wire [1:0]          p2_di_param,
    input  wire [SIZE_W-1:0]   p2_di_size,
    input  wire [SOURCE_W-1:0] p2_di_source,
    input  wire [DATA_W-1:0]   p2_di_data,
    input  wire                p2_di_valid,
    output wire                p2_di_ready,
    // --- Port 3 (West): A-in from west, A-out forward west, D bidirectional ---
    input  wire [2:0]          p3_a_opcode, p3_a_param,
    input  wire [SIZE_W-1:0]   p3_a_size,
    input  wire [SOURCE_W-1:0] p3_a_source,
    input  wire [ADDR_W-1:0]   p3_a_addr,
    input  wire [MASK_W-1:0]   p3_a_mask,
    input  wire [DATA_W-1:0]   p3_a_data,
    input  wire                p3_a_valid,
    output wire                p3_a_ready,
    output wire [2:0]          p3_d_opcode,
    output wire [1:0]          p3_d_param,
    output wire [SIZE_W-1:0]   p3_d_size,
    output wire [SOURCE_W-1:0] p3_d_source,
    output wire [DATA_W-1:0]   p3_d_data,
    output wire                p3_d_valid,
    input  wire                p3_d_ready,
    // Forwarding output and response-in for West
    output wire [2:0]          p3_ao_opcode, p3_ao_param,
    output wire [SIZE_W-1:0]   p3_ao_size,
    output wire [SOURCE_W-1:0] p3_ao_source,
    output wire [ADDR_W-1:0]   p3_ao_addr,
    output wire [MASK_W-1:0]   p3_ao_mask,
    output wire [DATA_W-1:0]   p3_ao_data,
    output wire                p3_ao_valid,
    input  wire                p3_ao_ready,
    input  wire [2:0]          p3_di_opcode,
    input  wire [1:0]          p3_di_param,
    input  wire [SIZE_W-1:0]   p3_di_size,
    input  wire [SOURCE_W-1:0] p3_di_source,
    input  wire [DATA_W-1:0]   p3_di_data,
    input  wire                p3_di_valid,
    output wire                p3_di_ready,
    // --- Inject port (from NI) ---
    input  wire [2:0]          inj_a_opcode, inj_a_param,
    input  wire [SIZE_W-1:0]   inj_a_size,
    input  wire [SOURCE_W-1:0] inj_a_source,
    input  wire [ADDR_W-1:0]   inj_a_addr,
    input  wire [MASK_W-1:0]   inj_a_mask,
    input  wire [DATA_W-1:0]   inj_a_data,
    input  wire                inj_a_valid,
    output wire                inj_a_ready,
    output wire [2:0]          inj_d_opcode,
    output wire [1:0]          inj_d_param,
    output wire [SIZE_W-1:0]   inj_d_size,
    output wire [SOURCE_W-1:0] inj_d_source,
    output wire [DATA_W-1:0]   inj_d_data,
    output wire                inj_d_valid,
    input  wire                inj_d_ready,
    // --- Local AXI port (direct to SRAM) ---
    output wire [ADDR_W-1:0]   axi_awaddr,
    output wire                axi_awvalid,
    input  wire                axi_awready,
    output wire [DATA_W-1:0]   axi_wdata,
    output wire [MASK_W-1:0]   axi_wstrb,
    output wire                axi_wvalid,
    input  wire                axi_wready,
    input  wire [1:0]          axi_bresp,
    input  wire                axi_bvalid,
    output wire                axi_bready,
    output wire [ADDR_W-1:0]   axi_araddr,
    output wire                axi_arvalid,
    input  wire                axi_arready,
    input  wire [DATA_W-1:0]   axi_rdata,
    input  wire [1:0]          axi_rresp,
    input  wire                axi_rvalid,
    output wire                axi_rready
);
    // Source encoding: 0=inj, 1=p0, 2=p1, 3=p2, 4=p3
    localparam SRC_INJ=3'd0, SRC_P0=3'd1, SRC_P1=3'd2, SRC_P2=3'd3, SRC_P3=3'd4;
    // Forward direction: 0=North, 1=South, 2=East, 3=West
    localparam FWD_N=2'd0, FWD_S=2'd1, FWD_E=2'd2, FWD_W=2'd3;

    // Registered request state
    reg         pend;
    reg [2:0]   r_origin;
    reg         r_local;
    reg [1:0]   r_fwd;
    reg [2:0]   r_opcode, r_param;
    reg [SIZE_W-1:0]   r_size;
    reg [SOURCE_W-1:0] r_source;
    reg [ADDR_W-1:0]   r_addr;
    reg [MASK_W-1:0]   r_mask;
    reg [DATA_W-1:0]   r_data;
    reg         r_is_write;
    reg         r_aw_done, r_w_done;

    // Arbitration: inj > p0 > p1 > p2 > p3
    wire sel_inj = !pend && inj_a_valid;
    wire sel_p0  = !pend && !inj_a_valid && p0_a_valid;
    wire sel_p1  = !pend && !inj_a_valid && !p0_a_valid && p1_a_valid;
    wire sel_p2  = !pend && !inj_a_valid && !p0_a_valid && !p1_a_valid && p2_a_valid;
    wire sel_p3  = !pend && !inj_a_valid && !p0_a_valid && !p1_a_valid && !p2_a_valid && p3_a_valid;
    wire any_sel = sel_inj | sel_p0 | sel_p1 | sel_p2 | sel_p3;

    // Mux selected incoming packet
    wire [2:0]                s_opcode = sel_inj?inj_a_opcode: sel_p0?p0_a_opcode: sel_p1?p1_a_opcode: sel_p2?p2_a_opcode: p3_a_opcode;
    wire [2:0]                s_param = sel_inj?inj_a_param: sel_p0?p0_a_param: sel_p1?p1_a_param: sel_p2?p2_a_param: p3_a_param;
    wire [SIZE_W-1:0]         s_size = sel_inj?inj_a_size: sel_p0?p0_a_size: sel_p1?p1_a_size: sel_p2?p2_a_size: p3_a_size;
    wire [SOURCE_W-1:0]       s_source = sel_inj?inj_a_source: sel_p0?p0_a_source: sel_p1?p1_a_source: sel_p2?p2_a_source: p3_a_source;
    wire [ADDR_W-1:0]         s_addr = sel_inj?inj_a_addr: sel_p0?p0_a_addr: sel_p1?p1_a_addr: sel_p2?p2_a_addr: p3_a_addr;
    wire [MASK_W-1:0]         s_mask = sel_inj?inj_a_mask: sel_p0?p0_a_mask: sel_p1?p1_a_mask: sel_p2?p2_a_mask: p3_a_mask;
    wire [DATA_W-1:0]         s_data = sel_inj?inj_a_data: sel_p0?p0_a_data: sel_p1?p1_a_data: sel_p2?p2_a_data: p3_a_data;

    // XY routing on selected packet
    wire [3:0] s_dest_x = s_addr[ADDR_W-1:ADDR_W-4];
    wire [3:0] s_dest_y = s_addr[ADDR_W-5:ADDR_W-8];
    wire s_go_east  = any_sel && (s_dest_x > NODE_X[3:0]);
    wire s_go_west  = any_sel && (s_dest_x < NODE_X[3:0]);
    wire s_go_north = any_sel && (s_dest_x == NODE_X[3:0]) && (s_dest_y > NODE_Y[3:0]);
    wire s_go_south = any_sel && (s_dest_x == NODE_X[3:0]) && (s_dest_y < NODE_Y[3:0]);
    wire s_go_local = any_sel && (s_dest_x == NODE_X[3:0]) && (s_dest_y == NODE_Y[3:0]);

    // Accept incoming request (one-cycle pulse)
    assign inj_a_ready = sel_inj;
    assign p0_a_ready  = sel_p0;
    assign p1_a_ready  = sel_p1;
    assign p2_a_ready  = sel_p2;
    assign p3_a_ready  = sel_p3;

    // D-channel: collect response
    wire d_local_wr = pend && r_local &&  r_is_write && axi_bvalid;
    wire d_local_rd = pend && r_local && !r_is_write && axi_rvalid;
    wire d_fwd_n    = pend && !r_local && (r_fwd==FWD_N) && p0_di_valid;
    wire d_fwd_s    = pend && !r_local && (r_fwd==FWD_S) && p1_di_valid;
    wire d_fwd_e    = pend && !r_local && (r_fwd==FWD_E) && p2_di_valid;
    wire d_fwd_w    = pend && !r_local && (r_fwd==FWD_W) && p3_di_valid;
    wire d_any      = d_local_wr | d_local_rd | d_fwd_n | d_fwd_s | d_fwd_e | d_fwd_w;
    wire [DATA_W-1:0] d_rdata = d_local_rd ? axi_rdata :
                               d_fwd_n   ? p0_di_data :
                               d_fwd_s   ? p1_di_data :
                               d_fwd_e   ? p2_di_data :
                               d_fwd_w   ? p3_di_data : {DATA_W{1'b0}};
    wire [2:0] d_opcode_r = r_is_write ? 3'd0 : 3'd1; // AccessAck / AccessAckData

    // Route D back to origin
    assign inj_d_opcode = d_opcode_r; assign inj_d_param  = 2'd0;
    assign inj_d_size   = r_size;     assign inj_d_source = r_source;
    assign inj_d_data   = d_rdata;    assign inj_d_valid  = d_any && (r_origin==SRC_INJ);
    assign p0_d_opcode = d_opcode_r; assign p0_d_param  = 2'd0;
    assign p0_d_size   = r_size;     assign p0_d_source = r_source;
    assign p0_d_data   = d_rdata;    assign p0_d_valid  = d_any && (r_origin==SRC_P0);
    assign p1_d_opcode = d_opcode_r; assign p1_d_param  = 2'd0;
    assign p1_d_size   = r_size;     assign p1_d_source = r_source;
    assign p1_d_data   = d_rdata;    assign p1_d_valid  = d_any && (r_origin==SRC_P1);
    assign p2_d_opcode = d_opcode_r; assign p2_d_param  = 2'd0;
    assign p2_d_size   = r_size;     assign p2_d_source = r_source;
    assign p2_d_data   = d_rdata;    assign p2_d_valid  = d_any && (r_origin==SRC_P2);
    assign p3_d_opcode = d_opcode_r; assign p3_d_param  = 2'd0;
    assign p3_d_size   = r_size;     assign p3_d_source = r_source;
    assign p3_d_data   = d_rdata;    assign p3_d_valid  = d_any && (r_origin==SRC_P3);

    // D-in readys (consume D from forwarded neighbor)
    assign p0_di_ready = pend && !r_local && (r_fwd==FWD_N);
    assign p1_di_ready = pend && !r_local && (r_fwd==FWD_S);
    assign p2_di_ready = pend && !r_local && (r_fwd==FWD_E);
    assign p3_di_ready = pend && !r_local && (r_fwd==FWD_W);

    // Forwarding outputs (held valid until D received)
    wire fwd_active = pend && !r_local;
    assign p0_ao_opcode=r_opcode; assign p0_ao_param=r_param; assign p0_ao_size=r_size;
    assign p0_ao_source=r_source; assign p0_ao_addr=r_addr; assign p0_ao_mask=r_mask;
    assign p0_ao_data=r_data; assign p0_ao_valid=fwd_active && (r_fwd==FWD_N);
    assign p1_ao_opcode=r_opcode; assign p1_ao_param=r_param; assign p1_ao_size=r_size;
    assign p1_ao_source=r_source; assign p1_ao_addr=r_addr; assign p1_ao_mask=r_mask;
    assign p1_ao_data=r_data; assign p1_ao_valid=fwd_active && (r_fwd==FWD_S);
    assign p2_ao_opcode=r_opcode; assign p2_ao_param=r_param; assign p2_ao_size=r_size;
    assign p2_ao_source=r_source; assign p2_ao_addr=r_addr; assign p2_ao_mask=r_mask;
    assign p2_ao_data=r_data; assign p2_ao_valid=fwd_active && (r_fwd==FWD_E);
    assign p3_ao_opcode=r_opcode; assign p3_ao_param=r_param; assign p3_ao_size=r_size;
    assign p3_ao_source=r_source; assign p3_ao_addr=r_addr; assign p3_ao_mask=r_mask;
    assign p3_ao_data=r_data; assign p3_ao_valid=fwd_active && (r_fwd==FWD_W);

    // Local AXI port (to SRAM)
    assign axi_awaddr  = r_addr;
    assign axi_awvalid = pend && r_local &&  r_is_write && !r_aw_done;
    assign axi_wdata   = r_data;
    assign axi_wstrb   = r_mask;
    assign axi_wvalid  = pend && r_local &&  r_is_write && !r_w_done;
    assign axi_araddr  = r_addr;
    assign axi_arvalid = pend && r_local && !r_is_write;
    assign axi_bready  = 1'b1;
    assign axi_rready  = 1'b1;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pend<=0; r_origin<=0; r_local<=0; r_fwd<=0;
            r_opcode<=0; r_param<=0; r_size<=0; r_source<=0;
            r_addr<=0; r_mask<=0; r_data<=0; r_is_write<=0;
            r_aw_done<=0; r_w_done<=0;
        end else if (!pend && any_sel) begin
            pend      <= 1;
            r_opcode  <= s_opcode; r_param  <= s_param;
            r_size    <= s_size;   r_source <= s_source;
            r_addr    <= s_addr;   r_mask   <= s_mask;
            r_data    <= s_data;
            r_is_write<= (s_opcode == 3'd0);
            r_origin  <= sel_inj ? SRC_INJ :
                         sel_p0  ? SRC_P0  :
                         sel_p1  ? SRC_P1  :
                         sel_p2  ? SRC_P2  : SRC_P3;
            r_local   <= s_go_local;
            r_fwd     <= s_go_east  ? FWD_E :
                         s_go_west  ? FWD_W :
                         s_go_north ? FWD_N : FWD_S;
            r_aw_done <= 0; r_w_done <= 0;
        end else if (pend) begin
            if (r_local) begin
                if (axi_awvalid && axi_awready) r_aw_done <= 1;
                if (axi_wvalid  && axi_wready)  r_w_done  <= 1;
            end
            if (d_any) pend <= 0;
        end
    end
endmodule
