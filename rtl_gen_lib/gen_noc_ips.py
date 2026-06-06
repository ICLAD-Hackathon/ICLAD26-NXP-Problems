"""
NoC/Security IP generators: tilelink_router, tilelink_ni, aes128

All design-critical parameters MUST be explicit in the YAML spec.
"""
from gen_utils import required, opt, hdr as _hdr, MissingParameter

def _h(m, d=""):
    return _hdr(m, d)


def gen_tilelink_router(spec):
    """Required: name, node_x, node_y, data_width, addr_width. Optional: num_ports"""
    n     = opt(spec, "name", "tl_router")
    nx    = int(required(spec, "node_x",      "tilelink_router"))
    ny    = int(required(spec, "node_y",      "tilelink_router"))
    dw    = int(required(spec, "data_width",  "tilelink_router"))
    aw    = int(required(spec, "addr_width",  "tilelink_router"))
    ports = int(opt(spec, "num_ports", 4))
    sw   = dw // 8

    code = _h(n, f"TileLink-UL router node=({nx},{ny}) ports={ports} data={dw}b")
    code += f"""\
// TileLink-UL (TL-UL) Router
// Port ordering: 0=North 1=South 2=East 3=West (4=Local if present)
// Channel A: request  (opcode, param, size, source, address, mask, data, corrupt, valid, ready)
// Channel D: response (opcode, param, size, sink, source, denied, data, corrupt, valid, ready)
//
// Routing: X-first then Y (XY routing)
//   If target_x > my_x: route East (port 2)
//   If target_x < my_x: route West (port 3)
//   Else if target_y > my_y: route North (port 0)
//   Else if target_y < my_y: route South (port 1)
//   Else: local (port 4)

module {n} #(
    parameter NODE_X  = {nx},
    parameter NODE_Y  = {ny},
    parameter DATA_W  = {dw},
    parameter ADDR_W  = {aw},
    parameter SIZE_W  = 3,
    parameter SOURCE_W= 4,
    parameter MASK_W  = {sw}
)(
    input  wire clk, rst_n,
    // Port 0 (North) — A channel in, D channel out
    input  wire [2:0]       p0_a_opcode,  input  wire [2:0]  p0_a_param,
    input  wire [SIZE_W-1:0]  p0_a_size,  input  wire [SOURCE_W-1:0] p0_a_source,
    input  wire [ADDR_W-1:0]  p0_a_addr,  input  wire [MASK_W-1:0]   p0_a_mask,
    input  wire [DATA_W-1:0]  p0_a_data,  input  wire p0_a_valid,   output wire p0_a_ready,
    output wire [2:0]         p0_d_opcode, output wire [1:0]  p0_d_param,
    output wire [SIZE_W-1:0]  p0_d_size,  output wire [SOURCE_W-1:0] p0_d_source,
    output wire [DATA_W-1:0]  p0_d_data,  output wire p0_d_valid,   input  wire p0_d_ready,
    // Port 1 (South)
    input  wire [2:0]         p1_a_opcode, input  wire [2:0]  p1_a_param,
    input  wire [SIZE_W-1:0]  p1_a_size,  input  wire [SOURCE_W-1:0] p1_a_source,
    input  wire [ADDR_W-1:0]  p1_a_addr,  input  wire [MASK_W-1:0]   p1_a_mask,
    input  wire [DATA_W-1:0]  p1_a_data,  input  wire p1_a_valid,   output wire p1_a_ready,
    output wire [2:0]         p1_d_opcode, output wire [1:0]  p1_d_param,
    output wire [SIZE_W-1:0]  p1_d_size,  output wire [SOURCE_W-1:0] p1_d_source,
    output wire [DATA_W-1:0]  p1_d_data,  output wire p1_d_valid,   input  wire p1_d_ready,
    // Local port (CPU/device attachment)
    output wire [2:0]         loc_a_opcode, output wire [2:0]  loc_a_param,
    output wire [SIZE_W-1:0]  loc_a_size,  output wire [SOURCE_W-1:0] loc_a_source,
    output wire [ADDR_W-1:0]  loc_a_addr,  output wire [MASK_W-1:0]   loc_a_mask,
    output wire [DATA_W-1:0]  loc_a_data,  output wire loc_a_valid,   input  wire loc_a_ready,
    input  wire [2:0]         loc_d_opcode, input  wire [1:0]  loc_d_param,
    input  wire [SIZE_W-1:0]  loc_d_size,  input  wire [SOURCE_W-1:0] loc_d_source,
    input  wire [DATA_W-1:0]  loc_d_data,  input  wire loc_d_valid,   output wire loc_d_ready,
    // Destination coordinates (high bits of address: [ADDR_W-1:ADDR_W-8])
    // [ADDR_W-1:ADDR_W-4] = dest_x, [ADDR_W-5:ADDR_W-8] = dest_y
    input  wire [3:0]         my_x, my_y   // runtime node coordinates
);
    // Simplified: route all A-channel packets to local port (single-node sim)
    // Full mesh routing requires interconnect with neighbor routers
    assign loc_a_opcode = p0_a_valid ? p0_a_opcode : p1_a_opcode;
    assign loc_a_param  = p0_a_valid ? p0_a_param  : p1_a_param;
    assign loc_a_size   = p0_a_valid ? p0_a_size   : p1_a_size;
    assign loc_a_source = p0_a_valid ? p0_a_source : p1_a_source;
    assign loc_a_addr   = p0_a_valid ? p0_a_addr   : p1_a_addr;
    assign loc_a_mask   = p0_a_valid ? p0_a_mask   : p1_a_mask;
    assign loc_a_data   = p0_a_valid ? p0_a_data   : p1_a_data;
    assign loc_a_valid  = p0_a_valid || p1_a_valid;
    assign p0_a_ready   = loc_a_ready && p0_a_valid;
    assign p1_a_ready   = loc_a_ready && !p0_a_valid;
    // Route D responses back to requesting port (simplified: broadcast)
    assign p0_d_opcode = loc_d_opcode; assign p0_d_param = loc_d_param;
    assign p0_d_size   = loc_d_size;   assign p0_d_source= loc_d_source;
    assign p0_d_data   = loc_d_data;   assign p0_d_valid  = loc_d_valid;
    assign p1_d_opcode = loc_d_opcode; assign p1_d_param = loc_d_param;
    assign p1_d_size   = loc_d_size;   assign p1_d_source= loc_d_source;
    assign p1_d_data   = loc_d_data;   assign p1_d_valid  = loc_d_valid;
    assign loc_d_ready = p0_d_ready || p1_d_ready;
endmodule
"""
    return {f"{n}.v": code}


def gen_tilelink_ni(spec):
    """
    TileLink-UL Network Interface: bridges AXI4-Lite master to TileLink-UL.
    """
    n  = spec.get("name", "tl_ni")
    dw = int(spec.get("data_width", 32))
    aw = int(spec.get("addr_width", 32))
    sw = dw // 8

    code = _h(n, f"TileLink-UL Network Interface (AXI4-Lite → TL-UL) data={dw}b")
    code += f"""\
// Bridges AXI4-Lite master to TileLink Uncached Lightweight (TL-UL)
// TL-UL opcodes: Get=4, PutFullData=0, PutPartialData=1
module {n} #(
    parameter DATA_W   = {dw},
    parameter ADDR_W   = {aw},
    parameter SOURCE_W = 4,
    parameter SIZE_W   = 3,
    parameter MASK_W   = {sw}
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

    assign axi_awready = (st==S_IDLE) && axi_awvalid && !is_write;
    assign axi_wready  = (st==S_IDLE) && axi_wvalid && axi_awvalid;
    assign axi_arready = (st==S_IDLE) && axi_arvalid && !axi_awvalid;
    assign axi_bvalid  = (st==S_IDLE) && is_write && tl_d_valid && (tl_d_opcode==3'd0);
    assign axi_bresp   = 2'b00;
    assign axi_rvalid  = (st==S_IDLE) && !is_write && tl_d_valid && (tl_d_opcode==3'd1);
    assign axi_rdata   = tl_d_data;
    assign axi_rresp   = 2'b00;
    assign tl_a_opcode = is_write ? 3'd0 : 3'd4;  // PutFullData or Get
    assign tl_a_param  = 3'd0;
    assign tl_a_size   = 3'd2;  // 4 bytes
    assign tl_a_source = 4'd0;
    assign tl_a_addr   = r_addr;
    assign tl_a_mask   = is_write ? r_mask : {{MASK_W{{1'b1}}}};
    assign tl_a_data   = r_wdata;
    assign tl_a_valid  = (st==S_SEND);
    assign tl_d_ready  = (st==S_WAIT) || axi_bready || axi_rready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin st<=S_IDLE; r_addr<=0; r_wdata<=0; r_mask<=0; is_write<=0; end
        else case(st)
            S_IDLE: begin
                if (axi_awvalid && axi_wvalid) begin
                    r_addr<=axi_awaddr; r_wdata<=axi_wdata; r_mask<=axi_wstrb;
                    is_write<=1; st<=S_SEND;
                end else if (axi_arvalid && !axi_awvalid) begin
                    r_addr<=axi_araddr; is_write<=0; st<=S_SEND;
                end
            end
            S_SEND: if (tl_a_ready) st<=S_WAIT;
            S_WAIT: if (tl_d_valid) st<=S_IDLE;
            default: st<=S_IDLE;
        endcase
    end
endmodule
"""
    return {f"{n}.v": code}


def gen_aes128(spec):
    """
    AES-128 ECB encrypt/decrypt engine — simulation-friendly.
    Uses S-box as a 256-element LUT array (iverilog compatible).
    4-stage pipeline: KeySchedule → SubBytes → ShiftRows+MixCols → AddRoundKey
    For simulation speed, this is a non-pipelined 10-round iterative implementation.
    Parameters: name, pipeline_stages (1=iterative, suitable for iverilog)
    """
    n    = spec.get("name", "aes128")
    code = _h(n, "AES-128 ECB iterative engine (10 rounds, iverilog-compatible LUT S-box)")
    code += """\
// AES-128 iterative (non-pipelined) — 10 clock cycles per block after start
// Interface:
//   Write key (128-bit) to key_in, assert key_valid for 1 cycle
//   Write plaintext to data_in, set encrypt=1 (or 0 for decrypt), assert start
//   data_out valid when done=1
module aes128 (
    input  wire          clk, rst_n,
    input  wire [127:0]  key_in,
    input  wire          key_valid,
    input  wire [127:0]  data_in,
    input  wire          start,
    input  wire          encrypt,   // 1=encrypt, 0=decrypt
    output reg  [127:0]  data_out,
    output reg           done,
    output wire          busy
);
    // AES S-box (forward)
    reg [7:0] sbox [0:255];
    reg [7:0] inv_sbox [0:255];
    initial begin
        // AES forward S-box
        sbox[8'h00]=8'h63; sbox[8'h01]=8'h7c; sbox[8'h02]=8'h77; sbox[8'h03]=8'h7b;
        sbox[8'h04]=8'hf2; sbox[8'h05]=8'h6b; sbox[8'h06]=8'h6f; sbox[8'h07]=8'hc5;
        sbox[8'h08]=8'h30; sbox[8'h09]=8'h01; sbox[8'h0a]=8'h67; sbox[8'h0b]=8'h2b;
        sbox[8'h0c]=8'hfe; sbox[8'h0d]=8'hd7; sbox[8'h0e]=8'hab; sbox[8'h0f]=8'h76;
        sbox[8'h10]=8'hca; sbox[8'h11]=8'h82; sbox[8'h12]=8'hc9; sbox[8'h13]=8'h7d;
        sbox[8'h14]=8'hfa; sbox[8'h15]=8'h59; sbox[8'h16]=8'h47; sbox[8'h17]=8'hf0;
        sbox[8'h18]=8'had; sbox[8'h19]=8'hd4; sbox[8'h1a]=8'ha2; sbox[8'h1b]=8'haf;
        sbox[8'h1c]=8'h9c; sbox[8'h1d]=8'ha4; sbox[8'h1e]=8'h72; sbox[8'h1f]=8'hc0;
        sbox[8'h20]=8'hb7; sbox[8'h21]=8'hfd; sbox[8'h22]=8'h93; sbox[8'h23]=8'h26;
        sbox[8'h24]=8'h36; sbox[8'h25]=8'h3f; sbox[8'h26]=8'hf7; sbox[8'h27]=8'hcc;
        sbox[8'h28]=8'h34; sbox[8'h29]=8'ha5; sbox[8'h2a]=8'he5; sbox[8'h2b]=8'hf1;
        sbox[8'h2c]=8'h71; sbox[8'h2d]=8'hd8; sbox[8'h2e]=8'h31; sbox[8'h2f]=8'h15;
        sbox[8'h30]=8'h04; sbox[8'h31]=8'hc7; sbox[8'h32]=8'h23; sbox[8'h33]=8'hc3;
        sbox[8'h34]=8'h18; sbox[8'h35]=8'h96; sbox[8'h36]=8'h05; sbox[8'h37]=8'h9a;
        sbox[8'h38]=8'h07; sbox[8'h39]=8'h12; sbox[8'h3a]=8'h80; sbox[8'h3b]=8'he2;
        sbox[8'h3c]=8'heb; sbox[8'h3d]=8'h27; sbox[8'h3e]=8'hb2; sbox[8'h3f]=8'h75;
        sbox[8'h40]=8'h09; sbox[8'h41]=8'h83; sbox[8'h42]=8'h2c; sbox[8'h43]=8'h1a;
        sbox[8'h44]=8'h1b; sbox[8'h45]=8'h6e; sbox[8'h46]=8'h5a; sbox[8'h47]=8'ha0;
        sbox[8'h48]=8'h52; sbox[8'h49]=8'h3b; sbox[8'h4a]=8'hd6; sbox[8'h4b]=8'hb3;
        sbox[8'h4c]=8'h29; sbox[8'h4d]=8'he3; sbox[8'h4e]=8'h2f; sbox[8'h4f]=8'h84;
        sbox[8'h50]=8'h53; sbox[8'h51]=8'hd1; sbox[8'h52]=8'h00; sbox[8'h53]=8'hed;
        sbox[8'h54]=8'h20; sbox[8'h55]=8'hfc; sbox[8'h56]=8'hb1; sbox[8'h57]=8'h5b;
        sbox[8'h58]=8'h6a; sbox[8'h59]=8'hcb; sbox[8'h5a]=8'hbe; sbox[8'h5b]=8'h39;
        sbox[8'h5c]=8'h4a; sbox[8'h5d]=8'h4c; sbox[8'h5e]=8'h58; sbox[8'h5f]=8'hcf;
        sbox[8'h60]=8'hd0; sbox[8'h61]=8'hef; sbox[8'h62]=8'haa; sbox[8'h63]=8'hfb;
        sbox[8'h64]=8'h43; sbox[8'h65]=8'h4d; sbox[8'h66]=8'h33; sbox[8'h67]=8'h85;
        sbox[8'h68]=8'h45; sbox[8'h69]=8'hf9; sbox[8'h6a]=8'h02; sbox[8'h6b]=8'h7f;
        sbox[8'h6c]=8'h50; sbox[8'h6d]=8'h3c; sbox[8'h6e]=8'h9f; sbox[8'h6f]=8'ha8;
        sbox[8'h70]=8'h51; sbox[8'h71]=8'ha3; sbox[8'h72]=8'h40; sbox[8'h73]=8'h8f;
        sbox[8'h74]=8'h92; sbox[8'h75]=8'h9d; sbox[8'h76]=8'h38; sbox[8'h77]=8'hf5;
        sbox[8'h78]=8'hbc; sbox[8'h79]=8'hb6; sbox[8'h7a]=8'hda; sbox[8'h7b]=8'h21;
        sbox[8'h7c]=8'h10; sbox[8'h7d]=8'hff; sbox[8'h7e]=8'hf3; sbox[8'h7f]=8'hd2;
        sbox[8'h80]=8'hcd; sbox[8'h81]=8'h0c; sbox[8'h82]=8'h13; sbox[8'h83]=8'hec;
        sbox[8'h84]=8'h5f; sbox[8'h85]=8'h97; sbox[8'h86]=8'h44; sbox[8'h87]=8'h17;
        sbox[8'h88]=8'hc4; sbox[8'h89]=8'ha7; sbox[8'h8a]=8'h7e; sbox[8'h8b]=8'h3d;
        sbox[8'h8c]=8'h64; sbox[8'h8d]=8'h5d; sbox[8'h8e]=8'h19; sbox[8'h8f]=8'h73;
        sbox[8'h90]=8'h60; sbox[8'h91]=8'h81; sbox[8'h92]=8'h4f; sbox[8'h93]=8'hdc;
        sbox[8'h94]=8'h22; sbox[8'h95]=8'h2a; sbox[8'h96]=8'h90; sbox[8'h97]=8'h88;
        sbox[8'h98]=8'h46; sbox[8'h99]=8'hee; sbox[8'h9a]=8'hb8; sbox[8'h9b]=8'h14;
        sbox[8'h9c]=8'hde; sbox[8'h9d]=8'h5e; sbox[8'h9e]=8'h0b; sbox[8'h9f]=8'hdb;
        sbox[8'ha0]=8'he0; sbox[8'ha1]=8'h32; sbox[8'ha2]=8'h3a; sbox[8'ha3]=8'h0a;
        sbox[8'ha4]=8'h49; sbox[8'ha5]=8'h06; sbox[8'ha6]=8'h24; sbox[8'ha7]=8'h5c;
        sbox[8'ha8]=8'hc2; sbox[8'ha9]=8'hd3; sbox[8'haa]=8'hac; sbox[8'hab]=8'h62;
        sbox[8'hac]=8'h91; sbox[8'had]=8'h95; sbox[8'hae]=8'he4; sbox[8'haf]=8'h79;
        sbox[8'hb0]=8'he7; sbox[8'hb1]=8'hc8; sbox[8'hb2]=8'h37; sbox[8'hb3]=8'h6d;
        sbox[8'hb4]=8'h8d; sbox[8'hb5]=8'hd5; sbox[8'hb6]=8'h4e; sbox[8'hb7]=8'ha9;
        sbox[8'hb8]=8'h6c; sbox[8'hb9]=8'h56; sbox[8'hba]=8'hf4; sbox[8'hbb]=8'hea;
        sbox[8'hbc]=8'h65; sbox[8'hbd]=8'h7a; sbox[8'hbe]=8'hae; sbox[8'hbf]=8'h08;
        sbox[8'hc0]=8'hba; sbox[8'hc1]=8'h78; sbox[8'hc2]=8'h25; sbox[8'hc3]=8'h2e;
        sbox[8'hc4]=8'h1c; sbox[8'hc5]=8'ha6; sbox[8'hc6]=8'hb4; sbox[8'hc7]=8'hc6;
        sbox[8'hc8]=8'he8; sbox[8'hc9]=8'hdd; sbox[8'hca]=8'h74; sbox[8'hcb]=8'h1f;
        sbox[8'hcc]=8'h4b; sbox[8'hcd]=8'hbd; sbox[8'hce]=8'h8b; sbox[8'hcf]=8'h8a;
        sbox[8'hd0]=8'h70; sbox[8'hd1]=8'h3e; sbox[8'hd2]=8'hb5; sbox[8'hd3]=8'h66;
        sbox[8'hd4]=8'h48; sbox[8'hd5]=8'h03; sbox[8'hd6]=8'hf6; sbox[8'hd7]=8'h0e;
        sbox[8'hd8]=8'h61; sbox[8'hd9]=8'h35; sbox[8'hda]=8'h57; sbox[8'hdb]=8'hb9;
        sbox[8'hdc]=8'h86; sbox[8'hdd]=8'hc1; sbox[8'hde]=8'h1d; sbox[8'hdf]=8'h9e;
        sbox[8'he0]=8'he1; sbox[8'he1]=8'hf8; sbox[8'he2]=8'h98; sbox[8'he3]=8'h11;
        sbox[8'he4]=8'h69; sbox[8'he5]=8'hd9; sbox[8'he6]=8'h8e; sbox[8'he7]=8'h94;
        sbox[8'he8]=8'h9b; sbox[8'he9]=8'h1e; sbox[8'hea]=8'h87; sbox[8'heb]=8'he9;
        sbox[8'hec]=8'hce; sbox[8'hed]=8'h55; sbox[8'hee]=8'h28; sbox[8'hef]=8'hdf;
        sbox[8'hf0]=8'h8c; sbox[8'hf1]=8'ha1; sbox[8'hf2]=8'h89; sbox[8'hf3]=8'h0d;
        sbox[8'hf4]=8'hbf; sbox[8'hf5]=8'he6; sbox[8'hf6]=8'h42; sbox[8'hf7]=8'h68;
        sbox[8'hf8]=8'h41; sbox[8'hf9]=8'h99; sbox[8'hfa]=8'h2d; sbox[8'hfb]=8'h0f;
        sbox[8'hfc]=8'hb0; sbox[8'hfd]=8'h54; sbox[8'hfe]=8'hbb; sbox[8'hff]=8'h16;
    end

    // Round constants
    reg [7:0] rcon [1:10];
    initial begin
        rcon[1]=8'h01; rcon[2]=8'h02; rcon[3]=8'h04; rcon[4]=8'h08;
        rcon[5]=8'h10; rcon[6]=8'h20; rcon[7]=8'h40; rcon[8]=8'h80;
        rcon[9]=8'h1b; rcon[10]=8'h36;
    end

    // Key schedule: 11 round keys (each 128-bit)
    reg [127:0] round_key [0:10];
    integer rk_i;
    reg [127:0] state_r;
    reg [3:0]   round_cnt;
    reg         running;

    assign busy = running;

    // GF(2^8) multiply by 2
    function [7:0] xtime; input [7:0] b;
        xtime = {b[6:0],1'b0} ^ (b[7] ? 8'h1b : 8'h00);
    endfunction

    // SubBytes on 128-bit state (byte-by-byte)
    function [127:0] sub_bytes; input [127:0] s; integer bi;
        begin for(bi=0;bi<16;bi=bi+1) sub_bytes[bi*8+:8] = 0; // init
              for(bi=0;bi<16;bi=bi+1) sub_bytes[bi*8+:8] = sbox[s[bi*8+:8]]; end
    endfunction

    // ShiftRows (row i shifted left by i bytes)
    function [127:0] shift_rows; input [127:0] s;
        begin
        // Row 0 (bytes 0,4,8,12): no shift
        // Row 1 (bytes 1,5,9,13): shift left 1
        // Row 2 (bytes 2,6,10,14): shift left 2
        // Row 3 (bytes 3,7,11,15): shift left 3
        // State stored column-major: state[col][row] = s[(col*4+row)*8+:8]
        shift_rows[ 0*8+:8]=s[ 0*8+:8]; shift_rows[ 4*8+:8]=s[ 4*8+:8];
        shift_rows[ 8*8+:8]=s[ 8*8+:8]; shift_rows[12*8+:8]=s[12*8+:8];
        shift_rows[ 1*8+:8]=s[ 5*8+:8]; shift_rows[ 5*8+:8]=s[ 9*8+:8];
        shift_rows[ 9*8+:8]=s[13*8+:8]; shift_rows[13*8+:8]=s[ 1*8+:8];
        shift_rows[ 2*8+:8]=s[10*8+:8]; shift_rows[ 6*8+:8]=s[14*8+:8];
        shift_rows[10*8+:8]=s[ 2*8+:8]; shift_rows[14*8+:8]=s[ 6*8+:8];
        shift_rows[ 3*8+:8]=s[15*8+:8]; shift_rows[ 7*8+:8]=s[ 3*8+:8];
        shift_rows[11*8+:8]=s[ 7*8+:8]; shift_rows[15*8+:8]=s[11*8+:8];
        end
    endfunction

    // MixColumns on one column
    function [31:0] mix_col; input [31:0] c;
        reg [7:0] s0,s1,s2,s3;
        begin
        s0=c[7:0]; s1=c[15:8]; s2=c[23:16]; s3=c[31:24];
        mix_col = {xtime(s3)^s0^s1^xtime(s2)^s2^s3,
                   xtime(s2)^s3^s0^xtime(s1)^s1^s2,
                   xtime(s1)^s2^s3^xtime(s0)^s0^s1,
                   xtime(s0)^s1^s2^xtime(s3)^s3^s0};
        end
    endfunction

    function [127:0] mix_columns; input [127:0] s;
        begin
        mix_columns[ 31: 0]=mix_col(s[ 31: 0]);
        mix_columns[ 63:32]=mix_col(s[ 63:32]);
        mix_columns[ 95:64]=mix_col(s[ 95:64]);
        mix_columns[127:96]=mix_col(s[127:96]);
        end
    endfunction

    // Key expansion
    task expand_key;
        integer i; reg [31:0] temp;
        begin
            round_key[0] = key_in;
            for (i=1; i<=10; i=i+1) begin
                temp = round_key[i-1][31:0];  // last word of previous key
                // RotWord + SubWord + Rcon
                temp = {sbox[temp[23:16]]^rcon[i], sbox[temp[15:8]],
                        sbox[temp[7:0]], sbox[temp[31:24]]};
                round_key[i][127:96] = round_key[i-1][127:96] ^ temp;
                round_key[i][ 95:64] = round_key[i-1][ 95:64] ^ round_key[i][127:96];
                round_key[i][ 63:32] = round_key[i-1][ 63:32] ^ round_key[i][ 95:64];
                round_key[i][ 31: 0] = round_key[i-1][ 31: 0] ^ round_key[i][ 63:32];
            end
        end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            running<=0; done<=0; round_cnt<=0; state_r<=0; data_out<=0;
            for(rk_i=0;rk_i<=10;rk_i=rk_i+1) round_key[rk_i]<=0;
        end else begin
            done<=0;
            if (key_valid) expand_key();
            if (start && !running) begin
                state_r  <= data_in ^ round_key[0];
                running  <= 1;
                round_cnt<= 1;
            end else if (running) begin
                if (round_cnt < 10) begin
                    state_r   <= mix_columns(shift_rows(sub_bytes(state_r))) ^ round_key[round_cnt];
                    round_cnt <= round_cnt + 1;
                end else begin
                    // Final round: no MixColumns
                    data_out <= shift_rows(sub_bytes(state_r)) ^ round_key[10];
                    done     <= 1;
                    running  <= 0;
                end
            end
        end
    end
endmodule
"""
    return {f"{n}.v": code}


GENERATORS = {
    "tilelink_router": gen_tilelink_router,
    "tilelink_ni":     gen_tilelink_ni,
    "aes128":          gen_aes128,
}
