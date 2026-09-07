// =============================================================================
// noc_aes_soc.v -- Golden stitched top-level
// NXP ICLAD 2026 Medium: 2x3 TileLink NoC AES Crypto SoC
// 2x3 mesh (x=0..1, y=0..2), 64-bit, 2 AES engines
// Router: bidirectional forwarding + inject port from NI + local AXI port to SRAM
// =============================================================================
`timescale 1ns/1ps
module noc_aes_soc (
    input  wire        clk, input  wire        por_n,
    input  wire [31:0] cpu_awaddr, input  wire cpu_awvalid, output wire cpu_awready,
    input  wire [63:0] cpu_wdata,  input  wire [7:0] cpu_wstrb,
    input  wire        cpu_wvalid, output wire cpu_wready,
    output wire [1:0]  cpu_bresp,  output wire cpu_bvalid,  input  wire cpu_bready,
    input  wire [31:0] cpu_araddr, input  wire cpu_arvalid, output wire cpu_arready,
    output wire [63:0] cpu_rdata,  output wire [1:0] cpu_rresp,
    output wire        cpu_rvalid, input  wire cpu_rready,
    input  wire [127:0] aes0_key_in,  input  wire aes0_key_valid,
    input  wire [127:0] aes0_data_in, input  wire aes0_start,
    output wire [127:0] aes0_data_out, output wire aes0_done, output wire aes0_busy,
    input  wire [127:0] aes1_key_in,  input  wire aes1_key_valid,
    input  wire [127:0] aes1_data_in, input  wire aes1_start,
    output wire [127:0] aes1_data_out, output wire aes1_done, output wire aes1_busy,
    output wire         cpu_irq, output wire [2:0] cpu_irq_id
);
    wire rst_n;
    reset_sync u_rst (.clk(clk), .por_n(por_n), .wdt_rst_n(1'b1), .sys_rst_n(rst_n));

    // ---- Boundary tie-off wires probed by testbench ----
    wire tie_00_p1_a_valid = 1'b0; // (0,0) South: no neighbour
    wire tie_02_p0_a_valid = 1'b0; // (0,2) North: no neighbour
    wire tie_10_p1_a_valid = 1'b0; // (1,0) South: no neighbour
    wire tie_12_p0_a_valid = 1'b0; // (1,2) North: no neighbour

    // ---- NI -> router inject port wires ----
    wire [2:0] ni00_a_opcode;
    wire [2:0] ni00_a_param;
    wire [2:0] ni00_a_size;
    wire [3:0] ni00_a_source;
    wire [31:0] ni00_a_addr;
    wire [7:0] ni00_a_mask;
    wire [63:0] ni00_a_data;
    wire ni00_a_valid;
    wire ni00_a_ready;
    wire [2:0] ni00_d_opcode;
    wire [1:0] ni00_d_param;
    wire [2:0] ni00_d_size;
    wire [3:0] ni00_d_source;
    wire [63:0] ni00_d_data;
    wire ni00_d_valid;
    wire ni00_d_ready;
    wire [2:0] ni01_a_opcode;
    wire [2:0] ni01_a_param;
    wire [2:0] ni01_a_size;
    wire [3:0] ni01_a_source;
    wire [31:0] ni01_a_addr;
    wire [7:0] ni01_a_mask;
    wire [63:0] ni01_a_data;
    wire ni01_a_valid;
    wire ni01_a_ready;
    wire [2:0] ni01_d_opcode;
    wire [1:0] ni01_d_param;
    wire [2:0] ni01_d_size;
    wire [3:0] ni01_d_source;
    wire [63:0] ni01_d_data;
    wire ni01_d_valid;
    wire ni01_d_ready;
    wire [2:0] ni02_a_opcode;
    wire [2:0] ni02_a_param;
    wire [2:0] ni02_a_size;
    wire [3:0] ni02_a_source;
    wire [31:0] ni02_a_addr;
    wire [7:0] ni02_a_mask;
    wire [63:0] ni02_a_data;
    wire ni02_a_valid;
    wire ni02_a_ready;
    wire [2:0] ni02_d_opcode;
    wire [1:0] ni02_d_param;
    wire [2:0] ni02_d_size;
    wire [3:0] ni02_d_source;
    wire [63:0] ni02_d_data;
    wire ni02_d_valid;
    wire ni02_d_ready;
    wire [2:0] ni10_a_opcode;
    wire [2:0] ni10_a_param;
    wire [2:0] ni10_a_size;
    wire [3:0] ni10_a_source;
    wire [31:0] ni10_a_addr;
    wire [7:0] ni10_a_mask;
    wire [63:0] ni10_a_data;
    wire ni10_a_valid;
    wire ni10_a_ready;
    wire [2:0] ni10_d_opcode;
    wire [1:0] ni10_d_param;
    wire [2:0] ni10_d_size;
    wire [3:0] ni10_d_source;
    wire [63:0] ni10_d_data;
    wire ni10_d_valid;
    wire ni10_d_ready;
    wire [2:0] ni11_a_opcode;
    wire [2:0] ni11_a_param;
    wire [2:0] ni11_a_size;
    wire [3:0] ni11_a_source;
    wire [31:0] ni11_a_addr;
    wire [7:0] ni11_a_mask;
    wire [63:0] ni11_a_data;
    wire ni11_a_valid;
    wire ni11_a_ready;
    wire [2:0] ni11_d_opcode;
    wire [1:0] ni11_d_param;
    wire [2:0] ni11_d_size;
    wire [3:0] ni11_d_source;
    wire [63:0] ni11_d_data;
    wire ni11_d_valid;
    wire ni11_d_ready;
    wire [2:0] ni12_a_opcode;
    wire [2:0] ni12_a_param;
    wire [2:0] ni12_a_size;
    wire [3:0] ni12_a_source;
    wire [31:0] ni12_a_addr;
    wire [7:0] ni12_a_mask;
    wire [63:0] ni12_a_data;
    wire ni12_a_valid;
    wire ni12_a_ready;
    wire [2:0] ni12_d_opcode;
    wire [1:0] ni12_d_param;
    wire [2:0] ni12_d_size;
    wire [3:0] ni12_d_source;
    wire [63:0] ni12_d_data;
    wire ni12_d_valid;
    wire ni12_d_ready;

    // ---- Router -> SRAM AXI wires ----
    wire [31:0] r00_awaddr;
    wire r00_awvalid;
    wire r00_awready;
    wire [63:0] r00_wdata;
    wire [7:0] r00_wstrb;
    wire r00_wvalid;
    wire r00_wready;
    wire [1:0] r00_bresp;
    wire r00_bvalid;
    wire r00_bready;
    wire [31:0] r00_araddr;
    wire r00_arvalid;
    wire r00_arready;
    wire [63:0] r00_rdata;
    wire [1:0] r00_rresp;
    wire r00_rvalid;
    wire r00_rready;
    wire [31:0] r01_awaddr;
    wire r01_awvalid;
    wire r01_awready;
    wire [63:0] r01_wdata;
    wire [7:0] r01_wstrb;
    wire r01_wvalid;
    wire r01_wready;
    wire [1:0] r01_bresp;
    wire r01_bvalid;
    wire r01_bready;
    wire [31:0] r01_araddr;
    wire r01_arvalid;
    wire r01_arready;
    wire [63:0] r01_rdata;
    wire [1:0] r01_rresp;
    wire r01_rvalid;
    wire r01_rready;
    wire [31:0] r02_awaddr;
    wire r02_awvalid;
    wire r02_awready;
    wire [63:0] r02_wdata;
    wire [7:0] r02_wstrb;
    wire r02_wvalid;
    wire r02_wready;
    wire [1:0] r02_bresp;
    wire r02_bvalid;
    wire r02_bready;
    wire [31:0] r02_araddr;
    wire r02_arvalid;
    wire r02_arready;
    wire [63:0] r02_rdata;
    wire [1:0] r02_rresp;
    wire r02_rvalid;
    wire r02_rready;
    wire [31:0] r10_awaddr;
    wire r10_awvalid;
    wire r10_awready;
    wire [63:0] r10_wdata;
    wire [7:0] r10_wstrb;
    wire r10_wvalid;
    wire r10_wready;
    wire [1:0] r10_bresp;
    wire r10_bvalid;
    wire r10_bready;
    wire [31:0] r10_araddr;
    wire r10_arvalid;
    wire r10_arready;
    wire [63:0] r10_rdata;
    wire [1:0] r10_rresp;
    wire r10_rvalid;
    wire r10_rready;
    wire [31:0] r11_awaddr;
    wire r11_awvalid;
    wire r11_awready;
    wire [63:0] r11_wdata;
    wire [7:0] r11_wstrb;
    wire r11_wvalid;
    wire r11_wready;
    wire [1:0] r11_bresp;
    wire r11_bvalid;
    wire r11_bready;
    wire [31:0] r11_araddr;
    wire r11_arvalid;
    wire r11_arready;
    wire [63:0] r11_rdata;
    wire [1:0] r11_rresp;
    wire r11_rvalid;
    wire r11_rready;
    wire [31:0] r12_awaddr;
    wire r12_awvalid;
    wire r12_awready;
    wire [63:0] r12_wdata;
    wire [7:0] r12_wstrb;
    wire r12_wvalid;
    wire r12_wready;
    wire [1:0] r12_bresp;
    wire r12_bvalid;
    wire r12_bready;
    wire [31:0] r12_araddr;
    wire r12_arvalid;
    wire r12_arready;
    wire [63:0] r12_rdata;
    wire [1:0] r12_rresp;
    wire r12_rvalid;
    wire r12_rready;

    // ---- E-W link wires (ew_yY_e: x=0->x=1, ew_yY_w: x=1->x=0) ----
    wire [2:0] ew_y0_e_a_opcode;
    wire [2:0] ew_y0_e_a_param;
    wire [2:0] ew_y0_e_a_size;
    wire [3:0] ew_y0_e_a_source;
    wire [31:0] ew_y0_e_a_addr;
    wire [7:0] ew_y0_e_a_mask;
    wire [63:0] ew_y0_e_a_data;
    wire ew_y0_e_a_valid;
    wire ew_y0_e_a_ready;
    wire [2:0] ew_y0_e_d_opcode;
    wire [63:0] ew_y0_e_d_data;
    wire ew_y0_e_d_valid;
    wire ew_y0_e_d_ready;
    wire [1:0] ew_y0_e_d_param;
    wire [2:0] ew_y0_e_d_size;
    wire [3:0] ew_y0_e_d_source;
    wire [2:0] ew_y0_w_a_opcode;
    wire [2:0] ew_y0_w_a_param;
    wire [2:0] ew_y0_w_a_size;
    wire [3:0] ew_y0_w_a_source;
    wire [31:0] ew_y0_w_a_addr;
    wire [7:0] ew_y0_w_a_mask;
    wire [63:0] ew_y0_w_a_data;
    wire ew_y0_w_a_valid;
    wire ew_y0_w_a_ready;
    wire [2:0] ew_y0_w_d_opcode;
    wire [63:0] ew_y0_w_d_data;
    wire ew_y0_w_d_valid;
    wire ew_y0_w_d_ready;
    wire [1:0] ew_y0_w_d_param;
    wire [2:0] ew_y0_w_d_size;
    wire [3:0] ew_y0_w_d_source;
    wire [2:0] ew_y1_e_a_opcode;
    wire [2:0] ew_y1_e_a_param;
    wire [2:0] ew_y1_e_a_size;
    wire [3:0] ew_y1_e_a_source;
    wire [31:0] ew_y1_e_a_addr;
    wire [7:0] ew_y1_e_a_mask;
    wire [63:0] ew_y1_e_a_data;
    wire ew_y1_e_a_valid;
    wire ew_y1_e_a_ready;
    wire [2:0] ew_y1_e_d_opcode;
    wire [63:0] ew_y1_e_d_data;
    wire ew_y1_e_d_valid;
    wire ew_y1_e_d_ready;
    wire [1:0] ew_y1_e_d_param;
    wire [2:0] ew_y1_e_d_size;
    wire [3:0] ew_y1_e_d_source;
    wire [2:0] ew_y1_w_a_opcode;
    wire [2:0] ew_y1_w_a_param;
    wire [2:0] ew_y1_w_a_size;
    wire [3:0] ew_y1_w_a_source;
    wire [31:0] ew_y1_w_a_addr;
    wire [7:0] ew_y1_w_a_mask;
    wire [63:0] ew_y1_w_a_data;
    wire ew_y1_w_a_valid;
    wire ew_y1_w_a_ready;
    wire [2:0] ew_y1_w_d_opcode;
    wire [63:0] ew_y1_w_d_data;
    wire ew_y1_w_d_valid;
    wire ew_y1_w_d_ready;
    wire [1:0] ew_y1_w_d_param;
    wire [2:0] ew_y1_w_d_size;
    wire [3:0] ew_y1_w_d_source;
    wire [2:0] ew_y2_e_a_opcode;
    wire [2:0] ew_y2_e_a_param;
    wire [2:0] ew_y2_e_a_size;
    wire [3:0] ew_y2_e_a_source;
    wire [31:0] ew_y2_e_a_addr;
    wire [7:0] ew_y2_e_a_mask;
    wire [63:0] ew_y2_e_a_data;
    wire ew_y2_e_a_valid;
    wire ew_y2_e_a_ready;
    wire [2:0] ew_y2_e_d_opcode;
    wire [63:0] ew_y2_e_d_data;
    wire ew_y2_e_d_valid;
    wire ew_y2_e_d_ready;
    wire [1:0] ew_y2_e_d_param;
    wire [2:0] ew_y2_e_d_size;
    wire [3:0] ew_y2_e_d_source;
    wire [2:0] ew_y2_w_a_opcode;
    wire [2:0] ew_y2_w_a_param;
    wire [2:0] ew_y2_w_a_size;
    wire [3:0] ew_y2_w_a_source;
    wire [31:0] ew_y2_w_a_addr;
    wire [7:0] ew_y2_w_a_mask;
    wire [63:0] ew_y2_w_a_data;
    wire ew_y2_w_a_valid;
    wire ew_y2_w_a_ready;
    wire [2:0] ew_y2_w_d_opcode;
    wire [63:0] ew_y2_w_d_data;
    wire ew_y2_w_d_valid;
    wire ew_y2_w_d_ready;
    wire [1:0] ew_y2_w_d_param;
    wire [2:0] ew_y2_w_d_size;
    wire [3:0] ew_y2_w_d_source;

    // ---- N-S link wires (ns_xX_yYZ: x col, direction from Y to Z) ----
    wire [2:0] ns_x0_y01_a_opcode;
    wire [2:0] ns_x0_y01_a_param;
    wire [2:0] ns_x0_y01_a_size;
    wire [3:0] ns_x0_y01_a_source;
    wire [31:0] ns_x0_y01_a_addr;
    wire [7:0] ns_x0_y01_a_mask;
    wire [63:0] ns_x0_y01_a_data;
    wire ns_x0_y01_a_valid;
    wire ns_x0_y01_a_ready;
    wire [2:0] ns_x0_y01_d_opcode;
    wire [63:0] ns_x0_y01_d_data;
    wire ns_x0_y01_d_valid;
    wire ns_x0_y01_d_ready;
    wire [1:0] ns_x0_y01_d_param;
    wire [2:0] ns_x0_y01_d_size;
    wire [3:0] ns_x0_y01_d_source;
    wire [2:0] ns_x0_y10_a_opcode;
    wire [2:0] ns_x0_y10_a_param;
    wire [2:0] ns_x0_y10_a_size;
    wire [3:0] ns_x0_y10_a_source;
    wire [31:0] ns_x0_y10_a_addr;
    wire [7:0] ns_x0_y10_a_mask;
    wire [63:0] ns_x0_y10_a_data;
    wire ns_x0_y10_a_valid;
    wire ns_x0_y10_a_ready;
    wire [2:0] ns_x0_y10_d_opcode;
    wire [63:0] ns_x0_y10_d_data;
    wire ns_x0_y10_d_valid;
    wire ns_x0_y10_d_ready;
    wire [1:0] ns_x0_y10_d_param;
    wire [2:0] ns_x0_y10_d_size;
    wire [3:0] ns_x0_y10_d_source;
    wire [2:0] ns_x0_y12_a_opcode;
    wire [2:0] ns_x0_y12_a_param;
    wire [2:0] ns_x0_y12_a_size;
    wire [3:0] ns_x0_y12_a_source;
    wire [31:0] ns_x0_y12_a_addr;
    wire [7:0] ns_x0_y12_a_mask;
    wire [63:0] ns_x0_y12_a_data;
    wire ns_x0_y12_a_valid;
    wire ns_x0_y12_a_ready;
    wire [2:0] ns_x0_y12_d_opcode;
    wire [63:0] ns_x0_y12_d_data;
    wire ns_x0_y12_d_valid;
    wire ns_x0_y12_d_ready;
    wire [1:0] ns_x0_y12_d_param;
    wire [2:0] ns_x0_y12_d_size;
    wire [3:0] ns_x0_y12_d_source;
    wire [2:0] ns_x0_y21_a_opcode;
    wire [2:0] ns_x0_y21_a_param;
    wire [2:0] ns_x0_y21_a_size;
    wire [3:0] ns_x0_y21_a_source;
    wire [31:0] ns_x0_y21_a_addr;
    wire [7:0] ns_x0_y21_a_mask;
    wire [63:0] ns_x0_y21_a_data;
    wire ns_x0_y21_a_valid;
    wire ns_x0_y21_a_ready;
    wire [2:0] ns_x0_y21_d_opcode;
    wire [63:0] ns_x0_y21_d_data;
    wire ns_x0_y21_d_valid;
    wire ns_x0_y21_d_ready;
    wire [1:0] ns_x0_y21_d_param;
    wire [2:0] ns_x0_y21_d_size;
    wire [3:0] ns_x0_y21_d_source;
    wire [2:0] ns_x1_y01_a_opcode;
    wire [2:0] ns_x1_y01_a_param;
    wire [2:0] ns_x1_y01_a_size;
    wire [3:0] ns_x1_y01_a_source;
    wire [31:0] ns_x1_y01_a_addr;
    wire [7:0] ns_x1_y01_a_mask;
    wire [63:0] ns_x1_y01_a_data;
    wire ns_x1_y01_a_valid;
    wire ns_x1_y01_a_ready;
    wire [2:0] ns_x1_y01_d_opcode;
    wire [63:0] ns_x1_y01_d_data;
    wire ns_x1_y01_d_valid;
    wire ns_x1_y01_d_ready;
    wire [1:0] ns_x1_y01_d_param;
    wire [2:0] ns_x1_y01_d_size;
    wire [3:0] ns_x1_y01_d_source;
    wire [2:0] ns_x1_y10_a_opcode;
    wire [2:0] ns_x1_y10_a_param;
    wire [2:0] ns_x1_y10_a_size;
    wire [3:0] ns_x1_y10_a_source;
    wire [31:0] ns_x1_y10_a_addr;
    wire [7:0] ns_x1_y10_a_mask;
    wire [63:0] ns_x1_y10_a_data;
    wire ns_x1_y10_a_valid;
    wire ns_x1_y10_a_ready;
    wire [2:0] ns_x1_y10_d_opcode;
    wire [63:0] ns_x1_y10_d_data;
    wire ns_x1_y10_d_valid;
    wire ns_x1_y10_d_ready;
    wire [1:0] ns_x1_y10_d_param;
    wire [2:0] ns_x1_y10_d_size;
    wire [3:0] ns_x1_y10_d_source;
    wire [2:0] ns_x1_y12_a_opcode;
    wire [2:0] ns_x1_y12_a_param;
    wire [2:0] ns_x1_y12_a_size;
    wire [3:0] ns_x1_y12_a_source;
    wire [31:0] ns_x1_y12_a_addr;
    wire [7:0] ns_x1_y12_a_mask;
    wire [63:0] ns_x1_y12_a_data;
    wire ns_x1_y12_a_valid;
    wire ns_x1_y12_a_ready;
    wire [2:0] ns_x1_y12_d_opcode;
    wire [63:0] ns_x1_y12_d_data;
    wire ns_x1_y12_d_valid;
    wire ns_x1_y12_d_ready;
    wire [1:0] ns_x1_y12_d_param;
    wire [2:0] ns_x1_y12_d_size;
    wire [3:0] ns_x1_y12_d_source;
    wire [2:0] ns_x1_y21_a_opcode;
    wire [2:0] ns_x1_y21_a_param;
    wire [2:0] ns_x1_y21_a_size;
    wire [3:0] ns_x1_y21_a_source;
    wire [31:0] ns_x1_y21_a_addr;
    wire [7:0] ns_x1_y21_a_mask;
    wire [63:0] ns_x1_y21_a_data;
    wire ns_x1_y21_a_valid;
    wire ns_x1_y21_a_ready;
    wire [2:0] ns_x1_y21_d_opcode;
    wire [63:0] ns_x1_y21_d_data;
    wire ns_x1_y21_d_valid;
    wire ns_x1_y21_d_ready;
    wire [1:0] ns_x1_y21_d_param;
    wire [2:0] ns_x1_y21_d_size;
    wire [3:0] ns_x1_y21_d_source;

    // ================================================================
    // Router instantiations
    // ================================================================
    router_00 u_router_00 (
        .clk(clk), .rst_n(rst_n),
        // p0 (North)
        .p0_a_opcode(ns_x0_y10_a_opcode),
        .p0_a_param(ns_x0_y10_a_param),
        .p0_a_size(ns_x0_y10_a_size),
        .p0_a_source(ns_x0_y10_a_source),
        .p0_a_addr(ns_x0_y10_a_addr),
        .p0_a_mask(ns_x0_y10_a_mask),
        .p0_a_data(ns_x0_y10_a_data),
        .p0_a_valid(ns_x0_y10_a_valid), .p0_a_ready(ns_x0_y10_a_ready),
        .p0_d_opcode(ns_x0_y10_d_opcode),
        .p0_d_param(ns_x0_y10_d_param),
        .p0_d_size(ns_x0_y10_d_size),
        .p0_d_source(ns_x0_y10_d_source),
        .p0_d_data(ns_x0_y10_d_data),
        .p0_d_valid(ns_x0_y10_d_valid),
        .p0_d_ready(ns_x0_y10_d_ready),
        .p0_ao_opcode(ns_x0_y01_a_opcode),
        .p0_ao_param(ns_x0_y01_a_param),
        .p0_ao_size(ns_x0_y01_a_size),
        .p0_ao_source(ns_x0_y01_a_source),
        .p0_ao_addr(ns_x0_y01_a_addr),
        .p0_ao_mask(ns_x0_y01_a_mask),
        .p0_ao_data(ns_x0_y01_a_data),
        .p0_ao_valid(ns_x0_y01_a_valid),
        .p0_ao_ready(ns_x0_y01_a_ready),
        .p0_di_opcode(ns_x0_y01_d_opcode),
        .p0_di_param(ns_x0_y01_d_param),
        .p0_di_size(ns_x0_y01_d_size),
        .p0_di_source(ns_x0_y01_d_source),
        .p0_di_data(ns_x0_y01_d_data),
        .p0_di_valid(ns_x0_y01_d_valid), .p0_di_ready(ns_x0_y01_d_ready),
        // p1 (South)
        .p1_a_opcode(3'b0),
        .p1_a_param(3'b0),
        .p1_a_size(3'b0),
        .p1_a_source(4'b0),
        .p1_a_addr(32'b0),
        .p1_a_mask(8'b0),
        .p1_a_data(64'b0),
        .p1_a_valid(1'b0), .p1_a_ready(/* nc */),
        .p1_d_opcode(/* nc */),
        .p1_d_param(/* nc */),
        .p1_d_size(/* nc */),
        .p1_d_source(/* nc */),
        .p1_d_data(/* nc */),
        .p1_d_valid(/* nc */),
        .p1_d_ready(1'b1),
        .p1_ao_opcode(/* nc */),
        .p1_ao_param(/* nc */),
        .p1_ao_size(/* nc */),
        .p1_ao_source(/* nc */),
        .p1_ao_addr(/* nc */),
        .p1_ao_mask(/* nc */),
        .p1_ao_data(/* nc */),
        .p1_ao_valid(/* nc */),
        .p1_ao_ready(1'b1),
        .p1_di_opcode(3'b0),
        .p1_di_param(3'b0),
        .p1_di_size(3'b0),
        .p1_di_source(4'b0),
        .p1_di_data(64'b0),
        .p1_di_valid(1'b0), .p1_di_ready(/* nc */),
        // p2 (East)
        .p2_a_opcode(ew_y0_w_a_opcode),
        .p2_a_param(ew_y0_w_a_param),
        .p2_a_size(ew_y0_w_a_size),
        .p2_a_source(ew_y0_w_a_source),
        .p2_a_addr(ew_y0_w_a_addr),
        .p2_a_mask(ew_y0_w_a_mask),
        .p2_a_data(ew_y0_w_a_data),
        .p2_a_valid(ew_y0_w_a_valid), .p2_a_ready(ew_y0_w_a_ready),
        .p2_d_opcode(ew_y0_w_d_opcode),
        .p2_d_param(ew_y0_w_d_param),
        .p2_d_size(ew_y0_w_d_size),
        .p2_d_source(ew_y0_w_d_source),
        .p2_d_data(ew_y0_w_d_data),
        .p2_d_valid(ew_y0_w_d_valid),
        .p2_d_ready(ew_y0_w_d_ready),
        .p2_ao_opcode(ew_y0_e_a_opcode),
        .p2_ao_param(ew_y0_e_a_param),
        .p2_ao_size(ew_y0_e_a_size),
        .p2_ao_source(ew_y0_e_a_source),
        .p2_ao_addr(ew_y0_e_a_addr),
        .p2_ao_mask(ew_y0_e_a_mask),
        .p2_ao_data(ew_y0_e_a_data),
        .p2_ao_valid(ew_y0_e_a_valid),
        .p2_ao_ready(ew_y0_e_a_ready),
        .p2_di_opcode(ew_y0_e_d_opcode),
        .p2_di_param(ew_y0_e_d_param),
        .p2_di_size(ew_y0_e_d_size),
        .p2_di_source(ew_y0_e_d_source),
        .p2_di_data(ew_y0_e_d_data),
        .p2_di_valid(ew_y0_e_d_valid), .p2_di_ready(ew_y0_e_d_ready),
        // p3 (West)
        .p3_a_opcode(3'b0),
        .p3_a_param(3'b0),
        .p3_a_size(3'b0),
        .p3_a_source(4'b0),
        .p3_a_addr(32'b0),
        .p3_a_mask(8'b0),
        .p3_a_data(64'b0),
        .p3_a_valid(1'b0), .p3_a_ready(/* nc */),
        .p3_d_opcode(/* nc */),
        .p3_d_param(/* nc */),
        .p3_d_size(/* nc */),
        .p3_d_source(/* nc */),
        .p3_d_data(/* nc */),
        .p3_d_valid(/* nc */),
        .p3_d_ready(1'b1),
        .p3_ao_opcode(/* nc */),
        .p3_ao_param(/* nc */),
        .p3_ao_size(/* nc */),
        .p3_ao_source(/* nc */),
        .p3_ao_addr(/* nc */),
        .p3_ao_mask(/* nc */),
        .p3_ao_data(/* nc */),
        .p3_ao_valid(/* nc */),
        .p3_ao_ready(1'b1),
        .p3_di_opcode(3'b0),
        .p3_di_param(3'b0),
        .p3_di_size(3'b0),
        .p3_di_source(4'b0),
        .p3_di_data(64'b0),
        .p3_di_valid(1'b0), .p3_di_ready(/* nc */),
        // inject from NI
        .inj_a_opcode(ni00_a_opcode),
        .inj_a_param(ni00_a_param),
        .inj_a_size(ni00_a_size),
        .inj_a_source(ni00_a_source),
        .inj_a_addr(ni00_a_addr),
        .inj_a_mask(ni00_a_mask),
        .inj_a_data(ni00_a_data),
        .inj_a_valid(ni00_a_valid), .inj_a_ready(ni00_a_ready),
        .inj_d_opcode(ni00_d_opcode),
        .inj_d_param(ni00_d_param),
        .inj_d_size(ni00_d_size),
        .inj_d_source(ni00_d_source),
        .inj_d_data(ni00_d_data),
        .inj_d_valid(ni00_d_valid), .inj_d_ready(ni00_d_ready),
        // local AXI to sram_00
        .axi_awaddr(r00_awaddr), .axi_awvalid(r00_awvalid), .axi_awready(r00_awready),
        .axi_wdata(r00_wdata), .axi_wstrb(r00_wstrb),
        .axi_wvalid(r00_wvalid), .axi_wready(r00_wready),
        .axi_bresp(r00_bresp), .axi_bvalid(r00_bvalid), .axi_bready(r00_bready),
        .axi_araddr(r00_araddr), .axi_arvalid(r00_arvalid), .axi_arready(r00_arready),
        .axi_rdata(r00_rdata), .axi_rresp(r00_rresp),
        .axi_rvalid(r00_rvalid), .axi_rready(r00_rready)
    );

    router_01 u_router_01 (
        .clk(clk), .rst_n(rst_n),
        // p0 (North)
        .p0_a_opcode(ns_x0_y21_a_opcode),
        .p0_a_param(ns_x0_y21_a_param),
        .p0_a_size(ns_x0_y21_a_size),
        .p0_a_source(ns_x0_y21_a_source),
        .p0_a_addr(ns_x0_y21_a_addr),
        .p0_a_mask(ns_x0_y21_a_mask),
        .p0_a_data(ns_x0_y21_a_data),
        .p0_a_valid(ns_x0_y21_a_valid), .p0_a_ready(ns_x0_y21_a_ready),
        .p0_d_opcode(ns_x0_y21_d_opcode),
        .p0_d_param(ns_x0_y21_d_param),
        .p0_d_size(ns_x0_y21_d_size),
        .p0_d_source(ns_x0_y21_d_source),
        .p0_d_data(ns_x0_y21_d_data),
        .p0_d_valid(ns_x0_y21_d_valid),
        .p0_d_ready(ns_x0_y21_d_ready),
        .p0_ao_opcode(ns_x0_y12_a_opcode),
        .p0_ao_param(ns_x0_y12_a_param),
        .p0_ao_size(ns_x0_y12_a_size),
        .p0_ao_source(ns_x0_y12_a_source),
        .p0_ao_addr(ns_x0_y12_a_addr),
        .p0_ao_mask(ns_x0_y12_a_mask),
        .p0_ao_data(ns_x0_y12_a_data),
        .p0_ao_valid(ns_x0_y12_a_valid),
        .p0_ao_ready(ns_x0_y12_a_ready),
        .p0_di_opcode(ns_x0_y12_d_opcode),
        .p0_di_param(ns_x0_y12_d_param),
        .p0_di_size(ns_x0_y12_d_size),
        .p0_di_source(ns_x0_y12_d_source),
        .p0_di_data(ns_x0_y12_d_data),
        .p0_di_valid(ns_x0_y12_d_valid), .p0_di_ready(ns_x0_y12_d_ready),
        // p1 (South)
        .p1_a_opcode(ns_x0_y01_a_opcode),
        .p1_a_param(ns_x0_y01_a_param),
        .p1_a_size(ns_x0_y01_a_size),
        .p1_a_source(ns_x0_y01_a_source),
        .p1_a_addr(ns_x0_y01_a_addr),
        .p1_a_mask(ns_x0_y01_a_mask),
        .p1_a_data(ns_x0_y01_a_data),
        .p1_a_valid(ns_x0_y01_a_valid), .p1_a_ready(ns_x0_y01_a_ready),
        .p1_d_opcode(ns_x0_y01_d_opcode),
        .p1_d_param(ns_x0_y01_d_param),
        .p1_d_size(ns_x0_y01_d_size),
        .p1_d_source(ns_x0_y01_d_source),
        .p1_d_data(ns_x0_y01_d_data),
        .p1_d_valid(ns_x0_y01_d_valid),
        .p1_d_ready(ns_x0_y01_d_ready),
        .p1_ao_opcode(ns_x0_y10_a_opcode),
        .p1_ao_param(ns_x0_y10_a_param),
        .p1_ao_size(ns_x0_y10_a_size),
        .p1_ao_source(ns_x0_y10_a_source),
        .p1_ao_addr(ns_x0_y10_a_addr),
        .p1_ao_mask(ns_x0_y10_a_mask),
        .p1_ao_data(ns_x0_y10_a_data),
        .p1_ao_valid(ns_x0_y10_a_valid),
        .p1_ao_ready(ns_x0_y10_a_ready),
        .p1_di_opcode(ns_x0_y10_d_opcode),
        .p1_di_param(ns_x0_y10_d_param),
        .p1_di_size(ns_x0_y10_d_size),
        .p1_di_source(ns_x0_y10_d_source),
        .p1_di_data(ns_x0_y10_d_data),
        .p1_di_valid(ns_x0_y10_d_valid), .p1_di_ready(ns_x0_y10_d_ready),
        // p2 (East)
        .p2_a_opcode(ew_y1_w_a_opcode),
        .p2_a_param(ew_y1_w_a_param),
        .p2_a_size(ew_y1_w_a_size),
        .p2_a_source(ew_y1_w_a_source),
        .p2_a_addr(ew_y1_w_a_addr),
        .p2_a_mask(ew_y1_w_a_mask),
        .p2_a_data(ew_y1_w_a_data),
        .p2_a_valid(ew_y1_w_a_valid), .p2_a_ready(ew_y1_w_a_ready),
        .p2_d_opcode(ew_y1_w_d_opcode),
        .p2_d_param(ew_y1_w_d_param),
        .p2_d_size(ew_y1_w_d_size),
        .p2_d_source(ew_y1_w_d_source),
        .p2_d_data(ew_y1_w_d_data),
        .p2_d_valid(ew_y1_w_d_valid),
        .p2_d_ready(ew_y1_w_d_ready),
        .p2_ao_opcode(ew_y1_e_a_opcode),
        .p2_ao_param(ew_y1_e_a_param),
        .p2_ao_size(ew_y1_e_a_size),
        .p2_ao_source(ew_y1_e_a_source),
        .p2_ao_addr(ew_y1_e_a_addr),
        .p2_ao_mask(ew_y1_e_a_mask),
        .p2_ao_data(ew_y1_e_a_data),
        .p2_ao_valid(ew_y1_e_a_valid),
        .p2_ao_ready(ew_y1_e_a_ready),
        .p2_di_opcode(ew_y1_e_d_opcode),
        .p2_di_param(ew_y1_e_d_param),
        .p2_di_size(ew_y1_e_d_size),
        .p2_di_source(ew_y1_e_d_source),
        .p2_di_data(ew_y1_e_d_data),
        .p2_di_valid(ew_y1_e_d_valid), .p2_di_ready(ew_y1_e_d_ready),
        // p3 (West)
        .p3_a_opcode(3'b0),
        .p3_a_param(3'b0),
        .p3_a_size(3'b0),
        .p3_a_source(4'b0),
        .p3_a_addr(32'b0),
        .p3_a_mask(8'b0),
        .p3_a_data(64'b0),
        .p3_a_valid(1'b0), .p3_a_ready(/* nc */),
        .p3_d_opcode(/* nc */),
        .p3_d_param(/* nc */),
        .p3_d_size(/* nc */),
        .p3_d_source(/* nc */),
        .p3_d_data(/* nc */),
        .p3_d_valid(/* nc */),
        .p3_d_ready(1'b1),
        .p3_ao_opcode(/* nc */),
        .p3_ao_param(/* nc */),
        .p3_ao_size(/* nc */),
        .p3_ao_source(/* nc */),
        .p3_ao_addr(/* nc */),
        .p3_ao_mask(/* nc */),
        .p3_ao_data(/* nc */),
        .p3_ao_valid(/* nc */),
        .p3_ao_ready(1'b1),
        .p3_di_opcode(3'b0),
        .p3_di_param(3'b0),
        .p3_di_size(3'b0),
        .p3_di_source(4'b0),
        .p3_di_data(64'b0),
        .p3_di_valid(1'b0), .p3_di_ready(/* nc */),
        // inject from NI
        .inj_a_opcode(ni01_a_opcode),
        .inj_a_param(ni01_a_param),
        .inj_a_size(ni01_a_size),
        .inj_a_source(ni01_a_source),
        .inj_a_addr(ni01_a_addr),
        .inj_a_mask(ni01_a_mask),
        .inj_a_data(ni01_a_data),
        .inj_a_valid(ni01_a_valid), .inj_a_ready(ni01_a_ready),
        .inj_d_opcode(ni01_d_opcode),
        .inj_d_param(ni01_d_param),
        .inj_d_size(ni01_d_size),
        .inj_d_source(ni01_d_source),
        .inj_d_data(ni01_d_data),
        .inj_d_valid(ni01_d_valid), .inj_d_ready(ni01_d_ready),
        // local AXI to sram_01
        .axi_awaddr(r01_awaddr), .axi_awvalid(r01_awvalid), .axi_awready(r01_awready),
        .axi_wdata(r01_wdata), .axi_wstrb(r01_wstrb),
        .axi_wvalid(r01_wvalid), .axi_wready(r01_wready),
        .axi_bresp(r01_bresp), .axi_bvalid(r01_bvalid), .axi_bready(r01_bready),
        .axi_araddr(r01_araddr), .axi_arvalid(r01_arvalid), .axi_arready(r01_arready),
        .axi_rdata(r01_rdata), .axi_rresp(r01_rresp),
        .axi_rvalid(r01_rvalid), .axi_rready(r01_rready)
    );

    router_02 u_router_02 (
        .clk(clk), .rst_n(rst_n),
        // p0 (North)
        .p0_a_opcode(3'b0),
        .p0_a_param(3'b0),
        .p0_a_size(3'b0),
        .p0_a_source(4'b0),
        .p0_a_addr(32'b0),
        .p0_a_mask(8'b0),
        .p0_a_data(64'b0),
        .p0_a_valid(1'b0), .p0_a_ready(/* nc */),
        .p0_d_opcode(/* nc */),
        .p0_d_param(/* nc */),
        .p0_d_size(/* nc */),
        .p0_d_source(/* nc */),
        .p0_d_data(/* nc */),
        .p0_d_valid(/* nc */),
        .p0_d_ready(1'b1),
        .p0_ao_opcode(/* nc */),
        .p0_ao_param(/* nc */),
        .p0_ao_size(/* nc */),
        .p0_ao_source(/* nc */),
        .p0_ao_addr(/* nc */),
        .p0_ao_mask(/* nc */),
        .p0_ao_data(/* nc */),
        .p0_ao_valid(/* nc */),
        .p0_ao_ready(1'b1),
        .p0_di_opcode(3'b0),
        .p0_di_param(3'b0),
        .p0_di_size(3'b0),
        .p0_di_source(4'b0),
        .p0_di_data(64'b0),
        .p0_di_valid(1'b0), .p0_di_ready(/* nc */),
        // p1 (South)
        .p1_a_opcode(ns_x0_y12_a_opcode),
        .p1_a_param(ns_x0_y12_a_param),
        .p1_a_size(ns_x0_y12_a_size),
        .p1_a_source(ns_x0_y12_a_source),
        .p1_a_addr(ns_x0_y12_a_addr),
        .p1_a_mask(ns_x0_y12_a_mask),
        .p1_a_data(ns_x0_y12_a_data),
        .p1_a_valid(ns_x0_y12_a_valid), .p1_a_ready(ns_x0_y12_a_ready),
        .p1_d_opcode(ns_x0_y12_d_opcode),
        .p1_d_param(ns_x0_y12_d_param),
        .p1_d_size(ns_x0_y12_d_size),
        .p1_d_source(ns_x0_y12_d_source),
        .p1_d_data(ns_x0_y12_d_data),
        .p1_d_valid(ns_x0_y12_d_valid),
        .p1_d_ready(ns_x0_y12_d_ready),
        .p1_ao_opcode(ns_x0_y21_a_opcode),
        .p1_ao_param(ns_x0_y21_a_param),
        .p1_ao_size(ns_x0_y21_a_size),
        .p1_ao_source(ns_x0_y21_a_source),
        .p1_ao_addr(ns_x0_y21_a_addr),
        .p1_ao_mask(ns_x0_y21_a_mask),
        .p1_ao_data(ns_x0_y21_a_data),
        .p1_ao_valid(ns_x0_y21_a_valid),
        .p1_ao_ready(ns_x0_y21_a_ready),
        .p1_di_opcode(ns_x0_y21_d_opcode),
        .p1_di_param(ns_x0_y21_d_param),
        .p1_di_size(ns_x0_y21_d_size),
        .p1_di_source(ns_x0_y21_d_source),
        .p1_di_data(ns_x0_y21_d_data),
        .p1_di_valid(ns_x0_y21_d_valid), .p1_di_ready(ns_x0_y21_d_ready),
        // p2 (East)
        .p2_a_opcode(ew_y2_w_a_opcode),
        .p2_a_param(ew_y2_w_a_param),
        .p2_a_size(ew_y2_w_a_size),
        .p2_a_source(ew_y2_w_a_source),
        .p2_a_addr(ew_y2_w_a_addr),
        .p2_a_mask(ew_y2_w_a_mask),
        .p2_a_data(ew_y2_w_a_data),
        .p2_a_valid(ew_y2_w_a_valid), .p2_a_ready(ew_y2_w_a_ready),
        .p2_d_opcode(ew_y2_w_d_opcode),
        .p2_d_param(ew_y2_w_d_param),
        .p2_d_size(ew_y2_w_d_size),
        .p2_d_source(ew_y2_w_d_source),
        .p2_d_data(ew_y2_w_d_data),
        .p2_d_valid(ew_y2_w_d_valid),
        .p2_d_ready(ew_y2_w_d_ready),
        .p2_ao_opcode(ew_y2_e_a_opcode),
        .p2_ao_param(ew_y2_e_a_param),
        .p2_ao_size(ew_y2_e_a_size),
        .p2_ao_source(ew_y2_e_a_source),
        .p2_ao_addr(ew_y2_e_a_addr),
        .p2_ao_mask(ew_y2_e_a_mask),
        .p2_ao_data(ew_y2_e_a_data),
        .p2_ao_valid(ew_y2_e_a_valid),
        .p2_ao_ready(ew_y2_e_a_ready),
        .p2_di_opcode(ew_y2_e_d_opcode),
        .p2_di_param(ew_y2_e_d_param),
        .p2_di_size(ew_y2_e_d_size),
        .p2_di_source(ew_y2_e_d_source),
        .p2_di_data(ew_y2_e_d_data),
        .p2_di_valid(ew_y2_e_d_valid), .p2_di_ready(ew_y2_e_d_ready),
        // p3 (West)
        .p3_a_opcode(3'b0),
        .p3_a_param(3'b0),
        .p3_a_size(3'b0),
        .p3_a_source(4'b0),
        .p3_a_addr(32'b0),
        .p3_a_mask(8'b0),
        .p3_a_data(64'b0),
        .p3_a_valid(1'b0), .p3_a_ready(/* nc */),
        .p3_d_opcode(/* nc */),
        .p3_d_param(/* nc */),
        .p3_d_size(/* nc */),
        .p3_d_source(/* nc */),
        .p3_d_data(/* nc */),
        .p3_d_valid(/* nc */),
        .p3_d_ready(1'b1),
        .p3_ao_opcode(/* nc */),
        .p3_ao_param(/* nc */),
        .p3_ao_size(/* nc */),
        .p3_ao_source(/* nc */),
        .p3_ao_addr(/* nc */),
        .p3_ao_mask(/* nc */),
        .p3_ao_data(/* nc */),
        .p3_ao_valid(/* nc */),
        .p3_ao_ready(1'b1),
        .p3_di_opcode(3'b0),
        .p3_di_param(3'b0),
        .p3_di_size(3'b0),
        .p3_di_source(4'b0),
        .p3_di_data(64'b0),
        .p3_di_valid(1'b0), .p3_di_ready(/* nc */),
        // inject from NI
        .inj_a_opcode(ni02_a_opcode),
        .inj_a_param(ni02_a_param),
        .inj_a_size(ni02_a_size),
        .inj_a_source(ni02_a_source),
        .inj_a_addr(ni02_a_addr),
        .inj_a_mask(ni02_a_mask),
        .inj_a_data(ni02_a_data),
        .inj_a_valid(ni02_a_valid), .inj_a_ready(ni02_a_ready),
        .inj_d_opcode(ni02_d_opcode),
        .inj_d_param(ni02_d_param),
        .inj_d_size(ni02_d_size),
        .inj_d_source(ni02_d_source),
        .inj_d_data(ni02_d_data),
        .inj_d_valid(ni02_d_valid), .inj_d_ready(ni02_d_ready),
        // local AXI to sram_02
        .axi_awaddr(r02_awaddr), .axi_awvalid(r02_awvalid), .axi_awready(r02_awready),
        .axi_wdata(r02_wdata), .axi_wstrb(r02_wstrb),
        .axi_wvalid(r02_wvalid), .axi_wready(r02_wready),
        .axi_bresp(r02_bresp), .axi_bvalid(r02_bvalid), .axi_bready(r02_bready),
        .axi_araddr(r02_araddr), .axi_arvalid(r02_arvalid), .axi_arready(r02_arready),
        .axi_rdata(r02_rdata), .axi_rresp(r02_rresp),
        .axi_rvalid(r02_rvalid), .axi_rready(r02_rready)
    );

    router_10 u_router_10 (
        .clk(clk), .rst_n(rst_n),
        // p0 (North)
        .p0_a_opcode(ns_x1_y10_a_opcode),
        .p0_a_param(ns_x1_y10_a_param),
        .p0_a_size(ns_x1_y10_a_size),
        .p0_a_source(ns_x1_y10_a_source),
        .p0_a_addr(ns_x1_y10_a_addr),
        .p0_a_mask(ns_x1_y10_a_mask),
        .p0_a_data(ns_x1_y10_a_data),
        .p0_a_valid(ns_x1_y10_a_valid), .p0_a_ready(ns_x1_y10_a_ready),
        .p0_d_opcode(ns_x1_y10_d_opcode),
        .p0_d_param(ns_x1_y10_d_param),
        .p0_d_size(ns_x1_y10_d_size),
        .p0_d_source(ns_x1_y10_d_source),
        .p0_d_data(ns_x1_y10_d_data),
        .p0_d_valid(ns_x1_y10_d_valid),
        .p0_d_ready(ns_x1_y10_d_ready),
        .p0_ao_opcode(ns_x1_y01_a_opcode),
        .p0_ao_param(ns_x1_y01_a_param),
        .p0_ao_size(ns_x1_y01_a_size),
        .p0_ao_source(ns_x1_y01_a_source),
        .p0_ao_addr(ns_x1_y01_a_addr),
        .p0_ao_mask(ns_x1_y01_a_mask),
        .p0_ao_data(ns_x1_y01_a_data),
        .p0_ao_valid(ns_x1_y01_a_valid),
        .p0_ao_ready(ns_x1_y01_a_ready),
        .p0_di_opcode(ns_x1_y01_d_opcode),
        .p0_di_param(ns_x1_y01_d_param),
        .p0_di_size(ns_x1_y01_d_size),
        .p0_di_source(ns_x1_y01_d_source),
        .p0_di_data(ns_x1_y01_d_data),
        .p0_di_valid(ns_x1_y01_d_valid), .p0_di_ready(ns_x1_y01_d_ready),
        // p1 (South)
        .p1_a_opcode(3'b0),
        .p1_a_param(3'b0),
        .p1_a_size(3'b0),
        .p1_a_source(4'b0),
        .p1_a_addr(32'b0),
        .p1_a_mask(8'b0),
        .p1_a_data(64'b0),
        .p1_a_valid(1'b0), .p1_a_ready(/* nc */),
        .p1_d_opcode(/* nc */),
        .p1_d_param(/* nc */),
        .p1_d_size(/* nc */),
        .p1_d_source(/* nc */),
        .p1_d_data(/* nc */),
        .p1_d_valid(/* nc */),
        .p1_d_ready(1'b1),
        .p1_ao_opcode(/* nc */),
        .p1_ao_param(/* nc */),
        .p1_ao_size(/* nc */),
        .p1_ao_source(/* nc */),
        .p1_ao_addr(/* nc */),
        .p1_ao_mask(/* nc */),
        .p1_ao_data(/* nc */),
        .p1_ao_valid(/* nc */),
        .p1_ao_ready(1'b1),
        .p1_di_opcode(3'b0),
        .p1_di_param(3'b0),
        .p1_di_size(3'b0),
        .p1_di_source(4'b0),
        .p1_di_data(64'b0),
        .p1_di_valid(1'b0), .p1_di_ready(/* nc */),
        // p2 (East)
        .p2_a_opcode(3'b0),
        .p2_a_param(3'b0),
        .p2_a_size(3'b0),
        .p2_a_source(4'b0),
        .p2_a_addr(32'b0),
        .p2_a_mask(8'b0),
        .p2_a_data(64'b0),
        .p2_a_valid(1'b0), .p2_a_ready(/* nc */),
        .p2_d_opcode(/* nc */),
        .p2_d_param(/* nc */),
        .p2_d_size(/* nc */),
        .p2_d_source(/* nc */),
        .p2_d_data(/* nc */),
        .p2_d_valid(/* nc */),
        .p2_d_ready(1'b1),
        .p2_ao_opcode(/* nc */),
        .p2_ao_param(/* nc */),
        .p2_ao_size(/* nc */),
        .p2_ao_source(/* nc */),
        .p2_ao_addr(/* nc */),
        .p2_ao_mask(/* nc */),
        .p2_ao_data(/* nc */),
        .p2_ao_valid(/* nc */),
        .p2_ao_ready(1'b1),
        .p2_di_opcode(3'b0),
        .p2_di_param(3'b0),
        .p2_di_size(3'b0),
        .p2_di_source(4'b0),
        .p2_di_data(64'b0),
        .p2_di_valid(1'b0), .p2_di_ready(/* nc */),
        // p3 (West)
        .p3_a_opcode(ew_y0_e_a_opcode),
        .p3_a_param(ew_y0_e_a_param),
        .p3_a_size(ew_y0_e_a_size),
        .p3_a_source(ew_y0_e_a_source),
        .p3_a_addr(ew_y0_e_a_addr),
        .p3_a_mask(ew_y0_e_a_mask),
        .p3_a_data(ew_y0_e_a_data),
        .p3_a_valid(ew_y0_e_a_valid), .p3_a_ready(ew_y0_e_a_ready),
        .p3_d_opcode(ew_y0_e_d_opcode),
        .p3_d_param(ew_y0_e_d_param),
        .p3_d_size(ew_y0_e_d_size),
        .p3_d_source(ew_y0_e_d_source),
        .p3_d_data(ew_y0_e_d_data),
        .p3_d_valid(ew_y0_e_d_valid),
        .p3_d_ready(ew_y0_e_d_ready),
        .p3_ao_opcode(ew_y0_w_a_opcode),
        .p3_ao_param(ew_y0_w_a_param),
        .p3_ao_size(ew_y0_w_a_size),
        .p3_ao_source(ew_y0_w_a_source),
        .p3_ao_addr(ew_y0_w_a_addr),
        .p3_ao_mask(ew_y0_w_a_mask),
        .p3_ao_data(ew_y0_w_a_data),
        .p3_ao_valid(ew_y0_w_a_valid),
        .p3_ao_ready(ew_y0_w_a_ready),
        .p3_di_opcode(ew_y0_w_d_opcode),
        .p3_di_param(ew_y0_w_d_param),
        .p3_di_size(ew_y0_w_d_size),
        .p3_di_source(ew_y0_w_d_source),
        .p3_di_data(ew_y0_w_d_data),
        .p3_di_valid(ew_y0_w_d_valid), .p3_di_ready(ew_y0_w_d_ready),
        // inject from NI
        .inj_a_opcode(ni10_a_opcode),
        .inj_a_param(ni10_a_param),
        .inj_a_size(ni10_a_size),
        .inj_a_source(ni10_a_source),
        .inj_a_addr(ni10_a_addr),
        .inj_a_mask(ni10_a_mask),
        .inj_a_data(ni10_a_data),
        .inj_a_valid(ni10_a_valid), .inj_a_ready(ni10_a_ready),
        .inj_d_opcode(ni10_d_opcode),
        .inj_d_param(ni10_d_param),
        .inj_d_size(ni10_d_size),
        .inj_d_source(ni10_d_source),
        .inj_d_data(ni10_d_data),
        .inj_d_valid(ni10_d_valid), .inj_d_ready(ni10_d_ready),
        // local AXI to sram_10
        .axi_awaddr(r10_awaddr), .axi_awvalid(r10_awvalid), .axi_awready(r10_awready),
        .axi_wdata(r10_wdata), .axi_wstrb(r10_wstrb),
        .axi_wvalid(r10_wvalid), .axi_wready(r10_wready),
        .axi_bresp(r10_bresp), .axi_bvalid(r10_bvalid), .axi_bready(r10_bready),
        .axi_araddr(r10_araddr), .axi_arvalid(r10_arvalid), .axi_arready(r10_arready),
        .axi_rdata(r10_rdata), .axi_rresp(r10_rresp),
        .axi_rvalid(r10_rvalid), .axi_rready(r10_rready)
    );

    router_11 u_router_11 (
        .clk(clk), .rst_n(rst_n),
        // p0 (North)
        .p0_a_opcode(ns_x1_y21_a_opcode),
        .p0_a_param(ns_x1_y21_a_param),
        .p0_a_size(ns_x1_y21_a_size),
        .p0_a_source(ns_x1_y21_a_source),
        .p0_a_addr(ns_x1_y21_a_addr),
        .p0_a_mask(ns_x1_y21_a_mask),
        .p0_a_data(ns_x1_y21_a_data),
        .p0_a_valid(ns_x1_y21_a_valid), .p0_a_ready(ns_x1_y21_a_ready),
        .p0_d_opcode(ns_x1_y21_d_opcode),
        .p0_d_param(ns_x1_y21_d_param),
        .p0_d_size(ns_x1_y21_d_size),
        .p0_d_source(ns_x1_y21_d_source),
        .p0_d_data(ns_x1_y21_d_data),
        .p0_d_valid(ns_x1_y21_d_valid),
        .p0_d_ready(ns_x1_y21_d_ready),
        .p0_ao_opcode(ns_x1_y12_a_opcode),
        .p0_ao_param(ns_x1_y12_a_param),
        .p0_ao_size(ns_x1_y12_a_size),
        .p0_ao_source(ns_x1_y12_a_source),
        .p0_ao_addr(ns_x1_y12_a_addr),
        .p0_ao_mask(ns_x1_y12_a_mask),
        .p0_ao_data(ns_x1_y12_a_data),
        .p0_ao_valid(ns_x1_y12_a_valid),
        .p0_ao_ready(ns_x1_y12_a_ready),
        .p0_di_opcode(ns_x1_y12_d_opcode),
        .p0_di_param(ns_x1_y12_d_param),
        .p0_di_size(ns_x1_y12_d_size),
        .p0_di_source(ns_x1_y12_d_source),
        .p0_di_data(ns_x1_y12_d_data),
        .p0_di_valid(ns_x1_y12_d_valid), .p0_di_ready(ns_x1_y12_d_ready),
        // p1 (South)
        .p1_a_opcode(ns_x1_y01_a_opcode),
        .p1_a_param(ns_x1_y01_a_param),
        .p1_a_size(ns_x1_y01_a_size),
        .p1_a_source(ns_x1_y01_a_source),
        .p1_a_addr(ns_x1_y01_a_addr),
        .p1_a_mask(ns_x1_y01_a_mask),
        .p1_a_data(ns_x1_y01_a_data),
        .p1_a_valid(ns_x1_y01_a_valid), .p1_a_ready(ns_x1_y01_a_ready),
        .p1_d_opcode(ns_x1_y01_d_opcode),
        .p1_d_param(ns_x1_y01_d_param),
        .p1_d_size(ns_x1_y01_d_size),
        .p1_d_source(ns_x1_y01_d_source),
        .p1_d_data(ns_x1_y01_d_data),
        .p1_d_valid(ns_x1_y01_d_valid),
        .p1_d_ready(ns_x1_y01_d_ready),
        .p1_ao_opcode(ns_x1_y10_a_opcode),
        .p1_ao_param(ns_x1_y10_a_param),
        .p1_ao_size(ns_x1_y10_a_size),
        .p1_ao_source(ns_x1_y10_a_source),
        .p1_ao_addr(ns_x1_y10_a_addr),
        .p1_ao_mask(ns_x1_y10_a_mask),
        .p1_ao_data(ns_x1_y10_a_data),
        .p1_ao_valid(ns_x1_y10_a_valid),
        .p1_ao_ready(ns_x1_y10_a_ready),
        .p1_di_opcode(ns_x1_y10_d_opcode),
        .p1_di_param(ns_x1_y10_d_param),
        .p1_di_size(ns_x1_y10_d_size),
        .p1_di_source(ns_x1_y10_d_source),
        .p1_di_data(ns_x1_y10_d_data),
        .p1_di_valid(ns_x1_y10_d_valid), .p1_di_ready(ns_x1_y10_d_ready),
        // p2 (East)
        .p2_a_opcode(3'b0),
        .p2_a_param(3'b0),
        .p2_a_size(3'b0),
        .p2_a_source(4'b0),
        .p2_a_addr(32'b0),
        .p2_a_mask(8'b0),
        .p2_a_data(64'b0),
        .p2_a_valid(1'b0), .p2_a_ready(/* nc */),
        .p2_d_opcode(/* nc */),
        .p2_d_param(/* nc */),
        .p2_d_size(/* nc */),
        .p2_d_source(/* nc */),
        .p2_d_data(/* nc */),
        .p2_d_valid(/* nc */),
        .p2_d_ready(1'b1),
        .p2_ao_opcode(/* nc */),
        .p2_ao_param(/* nc */),
        .p2_ao_size(/* nc */),
        .p2_ao_source(/* nc */),
        .p2_ao_addr(/* nc */),
        .p2_ao_mask(/* nc */),
        .p2_ao_data(/* nc */),
        .p2_ao_valid(/* nc */),
        .p2_ao_ready(1'b1),
        .p2_di_opcode(3'b0),
        .p2_di_param(3'b0),
        .p2_di_size(3'b0),
        .p2_di_source(4'b0),
        .p2_di_data(64'b0),
        .p2_di_valid(1'b0), .p2_di_ready(/* nc */),
        // p3 (West)
        .p3_a_opcode(ew_y1_e_a_opcode),
        .p3_a_param(ew_y1_e_a_param),
        .p3_a_size(ew_y1_e_a_size),
        .p3_a_source(ew_y1_e_a_source),
        .p3_a_addr(ew_y1_e_a_addr),
        .p3_a_mask(ew_y1_e_a_mask),
        .p3_a_data(ew_y1_e_a_data),
        .p3_a_valid(ew_y1_e_a_valid), .p3_a_ready(ew_y1_e_a_ready),
        .p3_d_opcode(ew_y1_e_d_opcode),
        .p3_d_param(ew_y1_e_d_param),
        .p3_d_size(ew_y1_e_d_size),
        .p3_d_source(ew_y1_e_d_source),
        .p3_d_data(ew_y1_e_d_data),
        .p3_d_valid(ew_y1_e_d_valid),
        .p3_d_ready(ew_y1_e_d_ready),
        .p3_ao_opcode(ew_y1_w_a_opcode),
        .p3_ao_param(ew_y1_w_a_param),
        .p3_ao_size(ew_y1_w_a_size),
        .p3_ao_source(ew_y1_w_a_source),
        .p3_ao_addr(ew_y1_w_a_addr),
        .p3_ao_mask(ew_y1_w_a_mask),
        .p3_ao_data(ew_y1_w_a_data),
        .p3_ao_valid(ew_y1_w_a_valid),
        .p3_ao_ready(ew_y1_w_a_ready),
        .p3_di_opcode(ew_y1_w_d_opcode),
        .p3_di_param(ew_y1_w_d_param),
        .p3_di_size(ew_y1_w_d_size),
        .p3_di_source(ew_y1_w_d_source),
        .p3_di_data(ew_y1_w_d_data),
        .p3_di_valid(ew_y1_w_d_valid), .p3_di_ready(ew_y1_w_d_ready),
        // inject from NI
        .inj_a_opcode(ni11_a_opcode),
        .inj_a_param(ni11_a_param),
        .inj_a_size(ni11_a_size),
        .inj_a_source(ni11_a_source),
        .inj_a_addr(ni11_a_addr),
        .inj_a_mask(ni11_a_mask),
        .inj_a_data(ni11_a_data),
        .inj_a_valid(ni11_a_valid), .inj_a_ready(ni11_a_ready),
        .inj_d_opcode(ni11_d_opcode),
        .inj_d_param(ni11_d_param),
        .inj_d_size(ni11_d_size),
        .inj_d_source(ni11_d_source),
        .inj_d_data(ni11_d_data),
        .inj_d_valid(ni11_d_valid), .inj_d_ready(ni11_d_ready),
        // local AXI to sram_11
        .axi_awaddr(r11_awaddr), .axi_awvalid(r11_awvalid), .axi_awready(r11_awready),
        .axi_wdata(r11_wdata), .axi_wstrb(r11_wstrb),
        .axi_wvalid(r11_wvalid), .axi_wready(r11_wready),
        .axi_bresp(r11_bresp), .axi_bvalid(r11_bvalid), .axi_bready(r11_bready),
        .axi_araddr(r11_araddr), .axi_arvalid(r11_arvalid), .axi_arready(r11_arready),
        .axi_rdata(r11_rdata), .axi_rresp(r11_rresp),
        .axi_rvalid(r11_rvalid), .axi_rready(r11_rready)
    );

    router_12 u_router_12 (
        .clk(clk), .rst_n(rst_n),
        // p0 (North)
        .p0_a_opcode(3'b0),
        .p0_a_param(3'b0),
        .p0_a_size(3'b0),
        .p0_a_source(4'b0),
        .p0_a_addr(32'b0),
        .p0_a_mask(8'b0),
        .p0_a_data(64'b0),
        .p0_a_valid(1'b0), .p0_a_ready(/* nc */),
        .p0_d_opcode(/* nc */),
        .p0_d_param(/* nc */),
        .p0_d_size(/* nc */),
        .p0_d_source(/* nc */),
        .p0_d_data(/* nc */),
        .p0_d_valid(/* nc */),
        .p0_d_ready(1'b1),
        .p0_ao_opcode(/* nc */),
        .p0_ao_param(/* nc */),
        .p0_ao_size(/* nc */),
        .p0_ao_source(/* nc */),
        .p0_ao_addr(/* nc */),
        .p0_ao_mask(/* nc */),
        .p0_ao_data(/* nc */),
        .p0_ao_valid(/* nc */),
        .p0_ao_ready(1'b1),
        .p0_di_opcode(3'b0),
        .p0_di_param(3'b0),
        .p0_di_size(3'b0),
        .p0_di_source(4'b0),
        .p0_di_data(64'b0),
        .p0_di_valid(1'b0), .p0_di_ready(/* nc */),
        // p1 (South)
        .p1_a_opcode(ns_x1_y12_a_opcode),
        .p1_a_param(ns_x1_y12_a_param),
        .p1_a_size(ns_x1_y12_a_size),
        .p1_a_source(ns_x1_y12_a_source),
        .p1_a_addr(ns_x1_y12_a_addr),
        .p1_a_mask(ns_x1_y12_a_mask),
        .p1_a_data(ns_x1_y12_a_data),
        .p1_a_valid(ns_x1_y12_a_valid), .p1_a_ready(ns_x1_y12_a_ready),
        .p1_d_opcode(ns_x1_y12_d_opcode),
        .p1_d_param(ns_x1_y12_d_param),
        .p1_d_size(ns_x1_y12_d_size),
        .p1_d_source(ns_x1_y12_d_source),
        .p1_d_data(ns_x1_y12_d_data),
        .p1_d_valid(ns_x1_y12_d_valid),
        .p1_d_ready(ns_x1_y12_d_ready),
        .p1_ao_opcode(ns_x1_y21_a_opcode),
        .p1_ao_param(ns_x1_y21_a_param),
        .p1_ao_size(ns_x1_y21_a_size),
        .p1_ao_source(ns_x1_y21_a_source),
        .p1_ao_addr(ns_x1_y21_a_addr),
        .p1_ao_mask(ns_x1_y21_a_mask),
        .p1_ao_data(ns_x1_y21_a_data),
        .p1_ao_valid(ns_x1_y21_a_valid),
        .p1_ao_ready(ns_x1_y21_a_ready),
        .p1_di_opcode(ns_x1_y21_d_opcode),
        .p1_di_param(ns_x1_y21_d_param),
        .p1_di_size(ns_x1_y21_d_size),
        .p1_di_source(ns_x1_y21_d_source),
        .p1_di_data(ns_x1_y21_d_data),
        .p1_di_valid(ns_x1_y21_d_valid), .p1_di_ready(ns_x1_y21_d_ready),
        // p2 (East)
        .p2_a_opcode(3'b0),
        .p2_a_param(3'b0),
        .p2_a_size(3'b0),
        .p2_a_source(4'b0),
        .p2_a_addr(32'b0),
        .p2_a_mask(8'b0),
        .p2_a_data(64'b0),
        .p2_a_valid(1'b0), .p2_a_ready(/* nc */),
        .p2_d_opcode(/* nc */),
        .p2_d_param(/* nc */),
        .p2_d_size(/* nc */),
        .p2_d_source(/* nc */),
        .p2_d_data(/* nc */),
        .p2_d_valid(/* nc */),
        .p2_d_ready(1'b1),
        .p2_ao_opcode(/* nc */),
        .p2_ao_param(/* nc */),
        .p2_ao_size(/* nc */),
        .p2_ao_source(/* nc */),
        .p2_ao_addr(/* nc */),
        .p2_ao_mask(/* nc */),
        .p2_ao_data(/* nc */),
        .p2_ao_valid(/* nc */),
        .p2_ao_ready(1'b1),
        .p2_di_opcode(3'b0),
        .p2_di_param(3'b0),
        .p2_di_size(3'b0),
        .p2_di_source(4'b0),
        .p2_di_data(64'b0),
        .p2_di_valid(1'b0), .p2_di_ready(/* nc */),
        // p3 (West)
        .p3_a_opcode(ew_y2_e_a_opcode),
        .p3_a_param(ew_y2_e_a_param),
        .p3_a_size(ew_y2_e_a_size),
        .p3_a_source(ew_y2_e_a_source),
        .p3_a_addr(ew_y2_e_a_addr),
        .p3_a_mask(ew_y2_e_a_mask),
        .p3_a_data(ew_y2_e_a_data),
        .p3_a_valid(ew_y2_e_a_valid), .p3_a_ready(ew_y2_e_a_ready),
        .p3_d_opcode(ew_y2_e_d_opcode),
        .p3_d_param(ew_y2_e_d_param),
        .p3_d_size(ew_y2_e_d_size),
        .p3_d_source(ew_y2_e_d_source),
        .p3_d_data(ew_y2_e_d_data),
        .p3_d_valid(ew_y2_e_d_valid),
        .p3_d_ready(ew_y2_e_d_ready),
        .p3_ao_opcode(ew_y2_w_a_opcode),
        .p3_ao_param(ew_y2_w_a_param),
        .p3_ao_size(ew_y2_w_a_size),
        .p3_ao_source(ew_y2_w_a_source),
        .p3_ao_addr(ew_y2_w_a_addr),
        .p3_ao_mask(ew_y2_w_a_mask),
        .p3_ao_data(ew_y2_w_a_data),
        .p3_ao_valid(ew_y2_w_a_valid),
        .p3_ao_ready(ew_y2_w_a_ready),
        .p3_di_opcode(ew_y2_w_d_opcode),
        .p3_di_param(ew_y2_w_d_param),
        .p3_di_size(ew_y2_w_d_size),
        .p3_di_source(ew_y2_w_d_source),
        .p3_di_data(ew_y2_w_d_data),
        .p3_di_valid(ew_y2_w_d_valid), .p3_di_ready(ew_y2_w_d_ready),
        // inject from NI
        .inj_a_opcode(ni12_a_opcode),
        .inj_a_param(ni12_a_param),
        .inj_a_size(ni12_a_size),
        .inj_a_source(ni12_a_source),
        .inj_a_addr(ni12_a_addr),
        .inj_a_mask(ni12_a_mask),
        .inj_a_data(ni12_a_data),
        .inj_a_valid(ni12_a_valid), .inj_a_ready(ni12_a_ready),
        .inj_d_opcode(ni12_d_opcode),
        .inj_d_param(ni12_d_param),
        .inj_d_size(ni12_d_size),
        .inj_d_source(ni12_d_source),
        .inj_d_data(ni12_d_data),
        .inj_d_valid(ni12_d_valid), .inj_d_ready(ni12_d_ready),
        // local AXI to sram_12
        .axi_awaddr(r12_awaddr), .axi_awvalid(r12_awvalid), .axi_awready(r12_awready),
        .axi_wdata(r12_wdata), .axi_wstrb(r12_wstrb),
        .axi_wvalid(r12_wvalid), .axi_wready(r12_wready),
        .axi_bresp(r12_bresp), .axi_bvalid(r12_bvalid), .axi_bready(r12_bready),
        .axi_araddr(r12_araddr), .axi_arvalid(r12_arvalid), .axi_arready(r12_arready),
        .axi_rdata(r12_rdata), .axi_rresp(r12_rresp),
        .axi_rvalid(r12_rvalid), .axi_rready(r12_rready)
    );

    // ================================================================
    // NI instantiations
    // ================================================================
    ni_00 u_ni_00 (
        .clk(clk), .rst_n(rst_n),
        .axi_awaddr(cpu_awaddr), .axi_awvalid(cpu_awvalid), .axi_awready(cpu_awready),
        .axi_wdata(cpu_wdata), .axi_wstrb(cpu_wstrb), .axi_wvalid(cpu_wvalid), .axi_wready(cpu_wready),
        .axi_bresp(cpu_bresp), .axi_bvalid(cpu_bvalid), .axi_bready(cpu_bready),
        .axi_araddr(cpu_araddr), .axi_arvalid(cpu_arvalid), .axi_arready(cpu_arready),
        .axi_rdata(cpu_rdata), .axi_rresp(cpu_rresp), .axi_rvalid(cpu_rvalid), .axi_rready(cpu_rready),
        .tl_a_opcode(ni00_a_opcode),
        .tl_a_param(ni00_a_param),
        .tl_a_size(ni00_a_size),
        .tl_a_source(ni00_a_source),
        .tl_a_addr(ni00_a_addr),
        .tl_a_mask(ni00_a_mask),
        .tl_a_data(ni00_a_data),
        .tl_a_valid(ni00_a_valid), .tl_a_ready(ni00_a_ready),
        .tl_d_opcode(ni00_d_opcode),
        .tl_d_param(ni00_d_param),
        .tl_d_size(ni00_d_size),
        .tl_d_source(ni00_d_source),
        .tl_d_data(ni00_d_data),
        .tl_d_valid(ni00_d_valid), .tl_d_ready(ni00_d_ready)
    );

    ni_01 u_ni_01 (
        .clk(clk), .rst_n(rst_n),
        .axi_awaddr(32'b0), .axi_awvalid(1'b0), .axi_awready(),
        .axi_wdata(64'b0), .axi_wstrb(8'b0), .axi_wvalid(1'b0), .axi_wready(),
        .axi_bresp(), .axi_bvalid(), .axi_bready(1'b0),
        .axi_araddr(32'b0), .axi_arvalid(1'b0), .axi_arready(),
        .axi_rdata(), .axi_rresp(), .axi_rvalid(), .axi_rready(1'b0),
        .tl_a_opcode(ni01_a_opcode),
        .tl_a_param(ni01_a_param),
        .tl_a_size(ni01_a_size),
        .tl_a_source(ni01_a_source),
        .tl_a_addr(ni01_a_addr),
        .tl_a_mask(ni01_a_mask),
        .tl_a_data(ni01_a_data),
        .tl_a_valid(ni01_a_valid), .tl_a_ready(ni01_a_ready),
        .tl_d_opcode(ni01_d_opcode),
        .tl_d_param(ni01_d_param),
        .tl_d_size(ni01_d_size),
        .tl_d_source(ni01_d_source),
        .tl_d_data(ni01_d_data),
        .tl_d_valid(ni01_d_valid), .tl_d_ready(ni01_d_ready)
    );

    ni_02 u_ni_02 (
        .clk(clk), .rst_n(rst_n),
        .axi_awaddr(32'b0), .axi_awvalid(1'b0), .axi_awready(),
        .axi_wdata(64'b0), .axi_wstrb(8'b0), .axi_wvalid(1'b0), .axi_wready(),
        .axi_bresp(), .axi_bvalid(), .axi_bready(1'b0),
        .axi_araddr(32'b0), .axi_arvalid(1'b0), .axi_arready(),
        .axi_rdata(), .axi_rresp(), .axi_rvalid(), .axi_rready(1'b0),
        .tl_a_opcode(ni02_a_opcode),
        .tl_a_param(ni02_a_param),
        .tl_a_size(ni02_a_size),
        .tl_a_source(ni02_a_source),
        .tl_a_addr(ni02_a_addr),
        .tl_a_mask(ni02_a_mask),
        .tl_a_data(ni02_a_data),
        .tl_a_valid(ni02_a_valid), .tl_a_ready(ni02_a_ready),
        .tl_d_opcode(ni02_d_opcode),
        .tl_d_param(ni02_d_param),
        .tl_d_size(ni02_d_size),
        .tl_d_source(ni02_d_source),
        .tl_d_data(ni02_d_data),
        .tl_d_valid(ni02_d_valid), .tl_d_ready(ni02_d_ready)
    );

    ni_10 u_ni_10 (
        .clk(clk), .rst_n(rst_n),
        .axi_awaddr(32'b0), .axi_awvalid(1'b0), .axi_awready(),
        .axi_wdata(64'b0), .axi_wstrb(8'b0), .axi_wvalid(1'b0), .axi_wready(),
        .axi_bresp(), .axi_bvalid(), .axi_bready(1'b0),
        .axi_araddr(32'b0), .axi_arvalid(1'b0), .axi_arready(),
        .axi_rdata(), .axi_rresp(), .axi_rvalid(), .axi_rready(1'b0),
        .tl_a_opcode(ni10_a_opcode),
        .tl_a_param(ni10_a_param),
        .tl_a_size(ni10_a_size),
        .tl_a_source(ni10_a_source),
        .tl_a_addr(ni10_a_addr),
        .tl_a_mask(ni10_a_mask),
        .tl_a_data(ni10_a_data),
        .tl_a_valid(ni10_a_valid), .tl_a_ready(ni10_a_ready),
        .tl_d_opcode(ni10_d_opcode),
        .tl_d_param(ni10_d_param),
        .tl_d_size(ni10_d_size),
        .tl_d_source(ni10_d_source),
        .tl_d_data(ni10_d_data),
        .tl_d_valid(ni10_d_valid), .tl_d_ready(ni10_d_ready)
    );

    ni_11 u_ni_11 (
        .clk(clk), .rst_n(rst_n),
        .axi_awaddr(32'b0), .axi_awvalid(1'b0), .axi_awready(),
        .axi_wdata(64'b0), .axi_wstrb(8'b0), .axi_wvalid(1'b0), .axi_wready(),
        .axi_bresp(), .axi_bvalid(), .axi_bready(1'b0),
        .axi_araddr(32'b0), .axi_arvalid(1'b0), .axi_arready(),
        .axi_rdata(), .axi_rresp(), .axi_rvalid(), .axi_rready(1'b0),
        .tl_a_opcode(ni11_a_opcode),
        .tl_a_param(ni11_a_param),
        .tl_a_size(ni11_a_size),
        .tl_a_source(ni11_a_source),
        .tl_a_addr(ni11_a_addr),
        .tl_a_mask(ni11_a_mask),
        .tl_a_data(ni11_a_data),
        .tl_a_valid(ni11_a_valid), .tl_a_ready(ni11_a_ready),
        .tl_d_opcode(ni11_d_opcode),
        .tl_d_param(ni11_d_param),
        .tl_d_size(ni11_d_size),
        .tl_d_source(ni11_d_source),
        .tl_d_data(ni11_d_data),
        .tl_d_valid(ni11_d_valid), .tl_d_ready(ni11_d_ready)
    );

    ni_12 u_ni_12 (
        .clk(clk), .rst_n(rst_n),
        .axi_awaddr(32'b0), .axi_awvalid(1'b0), .axi_awready(),
        .axi_wdata(64'b0), .axi_wstrb(8'b0), .axi_wvalid(1'b0), .axi_wready(),
        .axi_bresp(), .axi_bvalid(), .axi_bready(1'b0),
        .axi_araddr(32'b0), .axi_arvalid(1'b0), .axi_arready(),
        .axi_rdata(), .axi_rresp(), .axi_rvalid(), .axi_rready(1'b0),
        .tl_a_opcode(ni12_a_opcode),
        .tl_a_param(ni12_a_param),
        .tl_a_size(ni12_a_size),
        .tl_a_source(ni12_a_source),
        .tl_a_addr(ni12_a_addr),
        .tl_a_mask(ni12_a_mask),
        .tl_a_data(ni12_a_data),
        .tl_a_valid(ni12_a_valid), .tl_a_ready(ni12_a_ready),
        .tl_d_opcode(ni12_d_opcode),
        .tl_d_param(ni12_d_param),
        .tl_d_size(ni12_d_size),
        .tl_d_source(ni12_d_source),
        .tl_d_data(ni12_d_data),
        .tl_d_valid(ni12_d_valid), .tl_d_ready(ni12_d_ready)
    );

    // ================================================================
    // SRAM instantiations
    // ================================================================
    sram_00 u_sram_00 (
        .aclk(clk), .aresetn(rst_n),
        .awaddr(r00_awaddr), .awvalid(r00_awvalid), .awready(r00_awready),
        .wdata(r00_wdata), .wstrb(r00_wstrb), .wvalid(r00_wvalid), .wready(r00_wready),
        .bresp(r00_bresp), .bvalid(r00_bvalid), .bready(r00_bready),
        .araddr(r00_araddr), .arvalid(r00_arvalid), .arready(r00_arready),
        .rdata(r00_rdata), .rresp(r00_rresp), .rvalid(r00_rvalid), .rready(r00_rready)
    );

    sram_01 u_sram_01 (
        .aclk(clk), .aresetn(rst_n),
        .awaddr(r01_awaddr), .awvalid(r01_awvalid), .awready(r01_awready),
        .wdata(r01_wdata), .wstrb(r01_wstrb), .wvalid(r01_wvalid), .wready(r01_wready),
        .bresp(r01_bresp), .bvalid(r01_bvalid), .bready(r01_bready),
        .araddr(r01_araddr), .arvalid(r01_arvalid), .arready(r01_arready),
        .rdata(r01_rdata), .rresp(r01_rresp), .rvalid(r01_rvalid), .rready(r01_rready)
    );

    sram_02 u_sram_02 (
        .aclk(clk), .aresetn(rst_n),
        .awaddr(r02_awaddr), .awvalid(r02_awvalid), .awready(r02_awready),
        .wdata(r02_wdata), .wstrb(r02_wstrb), .wvalid(r02_wvalid), .wready(r02_wready),
        .bresp(r02_bresp), .bvalid(r02_bvalid), .bready(r02_bready),
        .araddr(r02_araddr), .arvalid(r02_arvalid), .arready(r02_arready),
        .rdata(r02_rdata), .rresp(r02_rresp), .rvalid(r02_rvalid), .rready(r02_rready)
    );

    sram_10 u_sram_10 (
        .aclk(clk), .aresetn(rst_n),
        .awaddr(r10_awaddr), .awvalid(r10_awvalid), .awready(r10_awready),
        .wdata(r10_wdata), .wstrb(r10_wstrb), .wvalid(r10_wvalid), .wready(r10_wready),
        .bresp(r10_bresp), .bvalid(r10_bvalid), .bready(r10_bready),
        .araddr(r10_araddr), .arvalid(r10_arvalid), .arready(r10_arready),
        .rdata(r10_rdata), .rresp(r10_rresp), .rvalid(r10_rvalid), .rready(r10_rready)
    );

    sram_11 u_sram_11 (
        .aclk(clk), .aresetn(rst_n),
        .awaddr(r11_awaddr), .awvalid(r11_awvalid), .awready(r11_awready),
        .wdata(r11_wdata), .wstrb(r11_wstrb), .wvalid(r11_wvalid), .wready(r11_wready),
        .bresp(r11_bresp), .bvalid(r11_bvalid), .bready(r11_bready),
        .araddr(r11_araddr), .arvalid(r11_arvalid), .arready(r11_arready),
        .rdata(r11_rdata), .rresp(r11_rresp), .rvalid(r11_rvalid), .rready(r11_rready)
    );

    sram_12 u_sram_12 (
        .aclk(clk), .aresetn(rst_n),
        .awaddr(r12_awaddr), .awvalid(r12_awvalid), .awready(r12_awready),
        .wdata(r12_wdata), .wstrb(r12_wstrb), .wvalid(r12_wvalid), .wready(r12_wready),
        .bresp(r12_bresp), .bvalid(r12_bvalid), .bready(r12_bready),
        .araddr(r12_araddr), .arvalid(r12_arvalid), .arready(r12_arready),
        .rdata(r12_rdata), .rresp(r12_rresp), .rvalid(r12_rvalid), .rready(r12_rready)
    );

    // ================================================================
    // AES engines + IRQ
    // ================================================================
    wire [1:0] irq_sources;
    aes0 u_aes0 (.clk(clk),.rst_n(rst_n),.key_in(aes0_key_in),.key_valid(aes0_key_valid),
        .data_in(aes0_data_in),.start(aes0_start),.encrypt(1'b1),
        .data_out(aes0_data_out),.done(aes0_done),.busy(aes0_busy));
    aes1 u_aes1 (.clk(clk),.rst_n(rst_n),.key_in(aes1_key_in),.key_valid(aes1_key_valid),
        .data_in(aes1_data_in),.start(aes1_start),.encrypt(1'b1),
        .data_out(aes1_data_out),.done(aes1_done),.busy(aes1_busy));
    assign irq_sources = {aes1_done, aes0_done};
    irq_aggregator u_irq_agg (.pclk(clk),.presetn(rst_n),.psel(1'b0),.penable(1'b0),.pwrite(1'b0),.paddr(12'b0),.pwdata(32'b0),.prdata(),.pready(),.pslverr(),
        .irq_src({6'b0, irq_sources}),.cpu_irq(cpu_irq),.cpu_irq_id(cpu_irq_id));
endmodule
