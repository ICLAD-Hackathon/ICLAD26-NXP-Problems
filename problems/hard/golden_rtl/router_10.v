// Hard SoC TileLink-UL Router node=(1,0) data=64b addr=32b
// XY routing: addr[31:28]=dest_x addr[27:24]=dest_y
// Ports: p0=North p1=South p2=East p3=West (bidirectional mesh)
//        inj_a_* = NI inject input
//        axi_*   = direct AXI connection to local SRAM
module router_10 #(
    parameter NODE_X   = 1,
    parameter NODE_Y   = 0,
    parameter DATA_W   = 64,
    parameter ADDR_W   = 32,
    parameter MASK_W   = 8,
    parameter SIZE_W   = 3,
    parameter SOURCE_W = 4
)(
    input  wire clk, rst_n,
    // p0 North
    input  wire [2:0]          p0_a_opcode, p0_a_param,
    input  wire [SIZE_W-1:0]   p0_a_size,
    input  wire [SOURCE_W-1:0] p0_a_source,
    input  wire [ADDR_W-1:0]   p0_a_addr,
    input  wire [MASK_W-1:0]   p0_a_mask,
    input  wire [DATA_W-1:0]   p0_a_data,
    input  wire                p0_a_valid,
    output wire                p0_a_ready,
    output wire [DATA_W-1:0]   p0_ao_data,
    output wire [ADDR_W-1:0]   p0_ao_addr,
    output wire [MASK_W-1:0]   p0_ao_mask,
    output wire [2:0]          p0_ao_opcode, p0_ao_param,
    output wire [SIZE_W-1:0]   p0_ao_size,
    output wire [SOURCE_W-1:0] p0_ao_source,
    output wire                p0_ao_valid,
    output wire [2:0]          p0_d_opcode,
    output wire [1:0]          p0_d_param,
    output wire [SIZE_W-1:0]   p0_d_size,
    output wire [SOURCE_W-1:0] p0_d_source,
    output wire [DATA_W-1:0]   p0_d_data,
    output wire                p0_d_valid,
    input  wire                p0_d_ready,
    // p1 South
    input  wire [2:0]          p1_a_opcode, p1_a_param,
    input  wire [SIZE_W-1:0]   p1_a_size,
    input  wire [SOURCE_W-1:0] p1_a_source,
    input  wire [ADDR_W-1:0]   p1_a_addr,
    input  wire [MASK_W-1:0]   p1_a_mask,
    input  wire [DATA_W-1:0]   p1_a_data,
    input  wire                p1_a_valid,
    output wire                p1_a_ready,
    output wire [DATA_W-1:0]   p1_ao_data,
    output wire [ADDR_W-1:0]   p1_ao_addr,
    output wire [MASK_W-1:0]   p1_ao_mask,
    output wire [2:0]          p1_ao_opcode, p1_ao_param,
    output wire [SIZE_W-1:0]   p1_ao_size,
    output wire [SOURCE_W-1:0] p1_ao_source,
    output wire                p1_ao_valid,
    output wire [2:0]          p1_d_opcode,
    output wire [1:0]          p1_d_param,
    output wire [SIZE_W-1:0]   p1_d_size,
    output wire [SOURCE_W-1:0] p1_d_source,
    output wire [DATA_W-1:0]   p1_d_data,
    output wire                p1_d_valid,
    input  wire                p1_d_ready,
    // p2 East
    input  wire [2:0]          p2_a_opcode, p2_a_param,
    input  wire [SIZE_W-1:0]   p2_a_size,
    input  wire [SOURCE_W-1:0] p2_a_source,
    input  wire [ADDR_W-1:0]   p2_a_addr,
    input  wire [MASK_W-1:0]   p2_a_mask,
    input  wire [DATA_W-1:0]   p2_a_data,
    input  wire                p2_a_valid,
    output wire                p2_a_ready,
    output wire [DATA_W-1:0]   p2_ao_data,
    output wire [ADDR_W-1:0]   p2_ao_addr,
    output wire [MASK_W-1:0]   p2_ao_mask,
    output wire [2:0]          p2_ao_opcode, p2_ao_param,
    output wire [SIZE_W-1:0]   p2_ao_size,
    output wire [SOURCE_W-1:0] p2_ao_source,
    output wire                p2_ao_valid,
    output wire [2:0]          p2_d_opcode,
    output wire [1:0]          p2_d_param,
    output wire [SIZE_W-1:0]   p2_d_size,
    output wire [SOURCE_W-1:0] p2_d_source,
    output wire [DATA_W-1:0]   p2_d_data,
    output wire                p2_d_valid,
    input  wire                p2_d_ready,
    // p3 West
    input  wire [2:0]          p3_a_opcode, p3_a_param,
    input  wire [SIZE_W-1:0]   p3_a_size,
    input  wire [SOURCE_W-1:0] p3_a_source,
    input  wire [ADDR_W-1:0]   p3_a_addr,
    input  wire [MASK_W-1:0]   p3_a_mask,
    input  wire [DATA_W-1:0]   p3_a_data,
    input  wire                p3_a_valid,
    output wire                p3_a_ready,
    output wire [DATA_W-1:0]   p3_ao_data,
    output wire [ADDR_W-1:0]   p3_ao_addr,
    output wire [MASK_W-1:0]   p3_ao_mask,
    output wire [2:0]          p3_ao_opcode, p3_ao_param,
    output wire [SIZE_W-1:0]   p3_ao_size,
    output wire [SOURCE_W-1:0] p3_ao_source,
    output wire                p3_ao_valid,
    output wire [2:0]          p3_d_opcode,
    output wire [1:0]          p3_d_param,
    output wire [SIZE_W-1:0]   p3_d_size,
    output wire [SOURCE_W-1:0] p3_d_source,
    output wire [DATA_W-1:0]   p3_d_data,
    output wire                p3_d_valid,
    input  wire                p3_d_ready,
    // NI inject
    input  wire [2:0]          inj_a_opcode, inj_a_param,
    input  wire [SIZE_W-1:0]   inj_a_size,
    input  wire [SOURCE_W-1:0] inj_a_source,
    input  wire [ADDR_W-1:0]   inj_a_addr,
    input  wire [MASK_W-1:0]   inj_a_mask,
    input  wire [DATA_W-1:0]   inj_a_data,
    input  wire                inj_a_valid,
    output wire                inj_a_ready,
    // AXI to local SRAM
    output reg  [ADDR_W-1:0]   axi_awaddr,
    output reg                 axi_awvalid,
    input  wire                axi_awready,
    output reg  [DATA_W-1:0]   axi_wdata,
    output reg  [MASK_W-1:0]   axi_wstrb,
    output reg                 axi_wvalid,
    input  wire                axi_wready,
    input  wire [1:0]          axi_bresp,
    input  wire                axi_bvalid,
    output reg                 axi_bready,
    output reg  [ADDR_W-1:0]   axi_araddr,
    output reg                 axi_arvalid,
    input  wire                axi_arready,
    input  wire [DATA_W-1:0]   axi_rdata,
    input  wire [1:0]          axi_rresp,
    input  wire                axi_rvalid,
    output reg                 axi_rready,
    // D channel response out
    output wire [2:0]          d_opcode,
    output wire [1:0]          d_param,
    output wire [SIZE_W-1:0]   d_size,
    output wire [SOURCE_W-1:0] d_source,
    output wire [DATA_W-1:0]   d_data,
    output wire                d_valid,
    input  wire                d_ready
);
    // Source IDs
    localparam SRC_INJ=3'd0, SRC_P0=3'd1, SRC_P1=3'd2, SRC_P2=3'd3, SRC_P3=3'd4;
    // Forward directions
    localparam FWD_LOC=3'd0, FWD_N=3'd1, FWD_S=3'd2, FWD_E=3'd3, FWD_W=3'd4;
    // States
    localparam S_IDLE=2'd0, S_WAIT=2'd1;

    reg [1:0]          r_st;
    reg [2:0]          r_opcode, r_param;
    reg [SIZE_W-1:0]   r_size;
    reg [SOURCE_W-1:0] r_source;
    reg [ADDR_W-1:0]   r_addr;
    reg [MASK_W-1:0]   r_mask;
    reg [DATA_W-1:0]   r_wdata;
    reg [2:0]          r_origin;
    reg [2:0]          r_fwd;
    reg                r_local;
    reg                r_done;
    reg [DATA_W-1:0]   r_rdata;

    // Arbitration: p0>p1>p2>p3>inj
    wire any_p0 = p0_a_valid;
    wire any_p1 = !p0_a_valid && p1_a_valid;
    wire any_p2 = !p0_a_valid && !p1_a_valid && p2_a_valid;
    wire any_p3 = !p0_a_valid && !p1_a_valid && !p2_a_valid && p3_a_valid;
    wire any_inj= !p0_a_valid && !p1_a_valid && !p2_a_valid && !p3_a_valid && inj_a_valid;
    wire any_in = p0_a_valid | p1_a_valid | p2_a_valid | p3_a_valid | inj_a_valid;

    wire [2:0]          sel_opcode = any_p0?p0_a_opcode: any_p1?p1_a_opcode: any_p2?p2_a_opcode: any_p3?p3_a_opcode: inj_a_opcode;
    wire [2:0]          sel_param  = any_p0?p0_a_param:  any_p1?p1_a_param:  any_p2?p2_a_param:  any_p3?p3_a_param:  inj_a_param;
    wire [SIZE_W-1:0]   sel_size   = any_p0?p0_a_size:   any_p1?p1_a_size:   any_p2?p2_a_size:   any_p3?p3_a_size:   inj_a_size;
    wire [SOURCE_W-1:0] sel_source = any_p0?p0_a_source: any_p1?p1_a_source: any_p2?p2_a_source: any_p3?p3_a_source: inj_a_source;
    wire [ADDR_W-1:0]   sel_addr   = any_p0?p0_a_addr:   any_p1?p1_a_addr:   any_p2?p2_a_addr:   any_p3?p3_a_addr:   inj_a_addr;
    wire [MASK_W-1:0]   sel_mask   = any_p0?p0_a_mask:   any_p1?p1_a_mask:   any_p2?p2_a_mask:   any_p3?p3_a_mask:   inj_a_mask;
    wire [DATA_W-1:0]   sel_data   = any_p0?p0_a_data:   any_p1?p1_a_data:   any_p2?p2_a_data:   any_p3?p3_a_data:   inj_a_data;

    wire [3:0] sel_dx = sel_addr[ADDR_W-1:ADDR_W-4];
    wire [3:0] sel_dy = sel_addr[ADDR_W-5:ADDR_W-8];

    wire fwd_e   = any_in && (sel_dx > NODE_X[3:0]);
    wire fwd_w   = any_in && (sel_dx < NODE_X[3:0]);
    wire fwd_n   = any_in && (sel_dx == NODE_X[3:0]) && (sel_dy > NODE_Y[3:0]);
    wire fwd_s   = any_in && (sel_dx == NODE_X[3:0]) && (sel_dy < NODE_Y[3:0]);
    wire fwd_loc = any_in && (sel_dx == NODE_X[3:0]) && (sel_dy == NODE_Y[3:0]);

    wire do_accept = (r_st == S_IDLE) && any_in;

    // Input readies
    assign p0_a_ready  = any_p0  && do_accept;
    assign p1_a_ready  = any_p1  && do_accept;
    assign p2_a_ready  = any_p2  && do_accept;
    assign p3_a_ready  = any_p3  && do_accept;
    assign inj_a_ready = any_inj && do_accept;

    // Forwarding outputs - driven from latched register
    assign p0_ao_valid  = (r_st==S_IDLE) && r_done && (r_fwd==FWD_N);
    assign p0_ao_opcode = r_opcode; assign p0_ao_param=r_param;
    assign p0_ao_size   = r_size;   assign p0_ao_source=r_source;
    assign p0_ao_addr   = r_addr;   assign p0_ao_mask=r_mask;
    assign p0_ao_data   = r_wdata;

    assign p1_ao_valid  = (r_st==S_IDLE) && r_done && (r_fwd==FWD_S);
    assign p1_ao_opcode = r_opcode; assign p1_ao_param=r_param;
    assign p1_ao_size   = r_size;   assign p1_ao_source=r_source;
    assign p1_ao_addr   = r_addr;   assign p1_ao_mask=r_mask;
    assign p1_ao_data   = r_wdata;

    assign p2_ao_valid  = (r_st==S_IDLE) && r_done && (r_fwd==FWD_E);
    assign p2_ao_opcode = r_opcode; assign p2_ao_param=r_param;
    assign p2_ao_size   = r_size;   assign p2_ao_source=r_source;
    assign p2_ao_addr   = r_addr;   assign p2_ao_mask=r_mask;
    assign p2_ao_data   = r_wdata;

    assign p3_ao_valid  = (r_st==S_IDLE) && r_done && (r_fwd==FWD_W);
    assign p3_ao_opcode = r_opcode; assign p3_ao_param=r_param;
    assign p3_ao_size   = r_size;   assign p3_ao_source=r_source;
    assign p3_ao_addr   = r_addr;   assign p3_ao_mask=r_mask;
    assign p3_ao_data   = r_wdata;

    // D-channel response back to origin
    assign d_valid   = (r_st==S_IDLE) && r_done;
    assign d_opcode  = r_opcode[0] ? 3'd0 : 3'd1;
    assign d_param   = 2'd0;
    assign d_size    = r_size;
    assign d_source  = r_source;
    assign d_data    = r_rdata;

    // Broadcast D back to origin port
    assign p0_d_valid  = d_valid && (r_origin==SRC_P0);
    assign p0_d_opcode = d_opcode; assign p0_d_param=d_param; assign p0_d_size=d_size; assign p0_d_source=d_source; assign p0_d_data=d_data;
    assign p1_d_valid  = d_valid && (r_origin==SRC_P1);
    assign p1_d_opcode = d_opcode; assign p1_d_param=d_param; assign p1_d_size=d_size; assign p1_d_source=d_source; assign p1_d_data=d_data;
    assign p2_d_valid  = d_valid && (r_origin==SRC_P2);
    assign p2_d_opcode = d_opcode; assign p2_d_param=d_param; assign p2_d_size=d_size; assign p2_d_source=d_source; assign p2_d_data=d_data;
    assign p3_d_valid  = d_valid && (r_origin==SRC_P3);
    assign p3_d_opcode = d_opcode; assign p3_d_param=d_param; assign p3_d_size=d_size; assign p3_d_source=d_source; assign p3_d_data=d_data;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_st<=S_IDLE; r_done<=0; r_local<=0; r_fwd<=FWD_LOC;
            r_opcode<=0; r_param<=0; r_size<=0; r_source<=0;
            r_addr<=0; r_mask<=0; r_wdata<=0; r_origin<=0; r_rdata<=0;
            axi_awaddr<=0; axi_awvalid<=0; axi_wdata<=0; axi_wstrb<=0; axi_wvalid<=0;
            axi_bready<=0; axi_araddr<=0; axi_arvalid<=0; axi_rready<=0;
        end else begin
            case (r_st)
            S_IDLE: begin
                // clear r_done only when response consumed
                if (r_done && d_ready) r_done <= 0;
                if (!r_done && any_in) begin
                    r_opcode <= sel_opcode; r_param <= sel_param;
                    r_size   <= sel_size;   r_source <= sel_source;
                    r_addr   <= sel_addr;   r_mask   <= sel_mask;
                    r_wdata  <= sel_data;
                    r_origin <= any_p0?SRC_P0: any_p1?SRC_P1: any_p2?SRC_P2: any_p3?SRC_P3: SRC_INJ;
                    if (fwd_e) begin r_fwd<=FWD_E; r_local<=0; r_done<=1; end
                    else if (fwd_w) begin r_fwd<=FWD_W; r_local<=0; r_done<=1; end
                    else if (fwd_n) begin r_fwd<=FWD_N; r_local<=0; r_done<=1; end
                    else if (fwd_s) begin r_fwd<=FWD_S; r_local<=0; r_done<=1; end
                    else begin
                        r_fwd <= FWD_LOC; r_local <= 1;
                        r_st  <= S_WAIT;
                        if (sel_opcode==3'd0 || sel_opcode==3'd1) begin
                            axi_awaddr  <= sel_addr;
                            axi_awvalid <= 1;
                            axi_wdata   <= sel_data;
                            axi_wstrb   <= sel_mask;
                            axi_wvalid  <= 1;
                        end else begin
                            axi_araddr  <= sel_addr;
                            axi_arvalid <= 1;
                        end
                    end
                end
            end
            S_WAIT: begin
                if (axi_awvalid && axi_awready) axi_awvalid <= 0;
                if (axi_wvalid  && axi_wready)  axi_wvalid  <= 0;
                if (axi_arvalid && axi_arready) begin axi_arvalid<=0; axi_rready<=1; end
                if (!axi_awvalid && !axi_wvalid && r_local && r_opcode[2:1]==2'b00) begin
                    axi_bready <= 1;
                    if (axi_bvalid) begin axi_bready<=0; r_done<=1; r_st<=S_IDLE; end
                end
                if (axi_rvalid && axi_rready) begin
                    r_rdata  <= axi_rdata;
                    axi_rready <= 0;
                    r_done   <= 1;
                    r_st     <= S_IDLE;
                end
            end
            default: r_st <= S_IDLE;
            endcase
        end
    end
endmodule
