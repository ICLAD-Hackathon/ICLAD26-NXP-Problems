// =============================================================================
// tb_top_skeleton.v -- Participant testbench skeleton
// NXP ICLAD 2026 Medium: 2x3 TileLink NoC AES Crypto SoC
//
// Instructions:
//   1. Read architecture.html to understand the design
//   2. Infer specs for each IP block (data_width, addr_width, num_ports,
//      stages, depth, etc.) from the diagrams
//   3. Generate each sub-IP using rtl_gen_lib/rtl_gen_main.py with your specs
//   4. Write noc_aes_soc.v to stitch all IPs together
//   5. Place all .v files in your_rtl/ and run:
//        python3 evaluator/evaluate.py --problem medium \
//          --rtl_dir your_rtl/ --run_id my_agent
//
// Top-level module name: noc_aes_soc
// =============================================================================
`timescale 1ns/1ps

module tb_top;

    // Clock and reset
    reg         clk;
    reg         por_n;

    // CPU AXI4-Lite master port (64-bit data, 32-bit address)
    reg  [31:0] cpu_awaddr;
    reg         cpu_awvalid;
    wire        cpu_awready;
    reg  [63:0] cpu_wdata;
    reg  [7:0]  cpu_wstrb;
    reg         cpu_wvalid;
    wire        cpu_wready;
    wire [1:0]  cpu_bresp;
    wire        cpu_bvalid;
    reg         cpu_bready;
    reg  [31:0] cpu_araddr;
    reg         cpu_arvalid;
    wire        cpu_arready;
    wire [63:0] cpu_rdata;
    wire [1:0]  cpu_rresp;
    wire        cpu_rvalid;
    reg         cpu_rready;

    // AES0 direct interface (node 1,0)
    reg  [127:0] aes0_key_in;
    reg          aes0_key_valid;
    reg  [127:0] aes0_data_in;
    reg          aes0_start;
    wire [127:0] aes0_data_out;
    wire         aes0_done;
    wire         aes0_busy;

    // AES1 direct interface (node 1,1)
    reg  [127:0] aes1_key_in;
    reg          aes1_key_valid;
    reg  [127:0] aes1_data_in;
    reg          aes1_start;
    wire [127:0] aes1_data_out;
    wire         aes1_done;
    wire         aes1_busy;

    // CPU IRQ output from IRQ aggregator
    wire         cpu_irq;
    wire [2:0]   cpu_irq_id;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // (Replace with your generated noc_aes_soc module)
    // -------------------------------------------------------------------------
    noc_aes_soc dut (
        .clk(clk),
        .por_n(por_n),
        .cpu_awaddr(cpu_awaddr),   .cpu_awvalid(cpu_awvalid), .cpu_awready(cpu_awready),
        .cpu_wdata(cpu_wdata),     .cpu_wstrb(cpu_wstrb),
        .cpu_wvalid(cpu_wvalid),   .cpu_wready(cpu_wready),
        .cpu_bresp(cpu_bresp),     .cpu_bvalid(cpu_bvalid),   .cpu_bready(cpu_bready),
        .cpu_araddr(cpu_araddr),   .cpu_arvalid(cpu_arvalid), .cpu_arready(cpu_arready),
        .cpu_rdata(cpu_rdata),     .cpu_rresp(cpu_rresp),
        .cpu_rvalid(cpu_rvalid),   .cpu_rready(cpu_rready),
        .aes0_key_in(aes0_key_in), .aes0_key_valid(aes0_key_valid),
        .aes0_data_in(aes0_data_in), .aes0_start(aes0_start),
        .aes0_data_out(aes0_data_out), .aes0_done(aes0_done), .aes0_busy(aes0_busy),
        .aes1_key_in(aes1_key_in), .aes1_key_valid(aes1_key_valid),
        .aes1_data_in(aes1_data_in), .aes1_start(aes1_start),
        .aes1_data_out(aes1_data_out), .aes1_done(aes1_done), .aes1_busy(aes1_busy),
        .cpu_irq(cpu_irq),
        .cpu_irq_id(cpu_irq_id)
    );

    // Clock: 100 MHz
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        por_n      = 0;
        cpu_awvalid = 0; cpu_wvalid = 0; cpu_bready = 0;
        cpu_arvalid = 0; cpu_rready = 0;
        cpu_awaddr = 0; cpu_wdata = 0; cpu_wstrb = 8'hFF; cpu_araddr = 0;
        aes0_key_in = 0; aes0_key_valid = 0;
        aes0_data_in = 0; aes0_start = 0;
        aes1_key_in = 0; aes1_key_valid = 0;
        aes1_data_in = 0; aes1_start = 0;

        // Release reset after 20 cycles
        repeat(20) @(posedge clk);
        por_n = 1;
        repeat(10) @(posedge clk);

        // TODO: add your test stimulus here
        $display("Skeleton: simulation started");
        repeat(100) @(posedge clk);
        $display("Skeleton: simulation done");
        $finish;
    end

    // Timeout guard
    initial begin
        #10_000_000;
        $display("[TIMEOUT]");
        $finish;
    end

endmodule
