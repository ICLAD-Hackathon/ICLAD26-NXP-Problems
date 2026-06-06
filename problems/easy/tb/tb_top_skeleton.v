// =============================================================================
// NXP ICLAD 2026 — EASY Problem: Secure Peripheral Subsystem
// Testbench Skeleton (provided to participants)
//
// INSTRUCTIONS:
//   1. Study the architecture diagram in docs/architecture.md
//   2. Read the IP descriptions in docs/ip_descriptions.md
//   3. Use the RTL generation library to produce each IP Verilog file
//   4. Implement soc_top.v that instantiates and connects all IPs
//   5. Your design must compile and simulate with:
//        iverilog -g2005 -o sim your_rtl/*.v this_tb.v
//        vvp sim
//   6. The evaluator will replace this skeleton with the hidden golden TB
//      and score your design against all test categories.
//
// PORT CONTRACT (DO NOT MODIFY this module's interface):
//   Your top-level module MUST be named:  secure_periph_soc
//   with exactly the port list shown in the DUT instantiation below.
// =============================================================================
`timescale 1ns/1ps

module tb_top;

    // ── DUT connections ───────────────────────────────────────────────────
    reg         clk;
    reg         por_n;

    // AHB-Lite CPU master port
    reg  [31:0] cpu_haddr;
    reg  [1:0]  cpu_htrans;
    reg         cpu_hwrite;
    reg  [2:0]  cpu_hsize;
    reg  [2:0]  cpu_hburst;
    reg  [2:0]  cpu_hprot;
    reg  [31:0] cpu_hwdata;
    wire [31:0] cpu_hrdata;
    wire        cpu_hready;
    wire [1:0]  cpu_hresp;     // 00=OKAY  01=ERROR

    // GPIO
    reg  [31:0] gpio_in;
    wire [31:0] gpio_out;
    wire [31:0] gpio_oe;       // output enable, 1=output

    // UART
    output wire uart_tx;
    input  wire uart_rx;
    input  wire uart_cts_n;    // clear-to-send (active low)
    output wire uart_rts_n;    // request-to-send (active low)

    // PWM (from timer output compare)
    wire        pwm0;
    wire        pwm1;

    // Interrupt to CPU
    wire        cpu_irq;
    wire [2:0]  cpu_irq_id;    // vector ID of highest-priority pending IRQ

    // Watchdog reset output
    wire        wdt_rst_req;   // pulses when WDT stage-2 expires

    // ── DUT instantiation ─────────────────────────────────────────────────
    // Implement this module in your RTL files.
    secure_periph_soc dut (
        .clk         (clk),
        .por_n       (por_n),
        .cpu_haddr   (cpu_haddr),
        .cpu_htrans  (cpu_htrans),
        .cpu_hwrite  (cpu_hwrite),
        .cpu_hsize   (cpu_hsize),
        .cpu_hburst  (cpu_hburst),
        .cpu_hprot   (cpu_hprot),
        .cpu_hwdata  (cpu_hwdata),
        .cpu_hrdata  (cpu_hrdata),
        .cpu_hready  (cpu_hready),
        .cpu_hresp   (cpu_hresp),
        .gpio_in     (gpio_in),
        .gpio_out    (gpio_out),
        .gpio_oe     (gpio_oe),
        .uart_tx     (uart_tx),
        .uart_rx     (uart_rx),
        .uart_cts_n  (uart_cts_n),
        .uart_rts_n  (uart_rts_n),
        .pwm0        (pwm0),
        .pwm1        (pwm1),
        .cpu_irq     (cpu_irq),
        .cpu_irq_id  (cpu_irq_id),
        .wdt_rst_req (wdt_rst_req)
    );

    // ── Clock ─────────────────────────────────────────────────────────────
    initial clk = 0;
    always  #5 clk = ~clk;   // 100 MHz

    // ── Reset ─────────────────────────────────────────────────────────────
    initial begin
        por_n      = 0;
        cpu_htrans = 2'b00;  // IDLE
        cpu_hwrite = 0;
        cpu_haddr  = 0;
        cpu_hwdata = 0;
        cpu_hprot  = 3'b001; // privileged data access
        cpu_hsize  = 3'b010; // word
        cpu_hburst = 3'b000; // SINGLE
        gpio_in    = 0;
        uart_rx    = 1;      // UART idle = high
        uart_cts_n = 0;      // CTS asserted

        repeat(20) @(posedge clk);
        por_n = 1;
        repeat(5)  @(posedge clk);

        // ── YOUR SANITY CHECKS HERE ────────────────────────────────────────
        // Write a basic AHB transfer to verify your bus fabric works:
        //   ahb_write(32'h0000_1004, 32'hDEADC0DE, 3'b001);  // GPIO DATA_OUT
        //   ahb_read (32'h0000_1004, 3'b001, rd, rs);
        //   if (rd === 32'hDEADC0DE) $display("GPIO write-readback PASS");
        //   else $display("GPIO write-readback FAIL: got %h", rd);

        $display("Skeleton TB: basic sanity only — add your own checks here.");
        $finish;
    end

    // ── AHB master helper tasks ───────────────────────────────────────────
    // Address map:
    //   UART     : 0x0000_0000 – 0x0000_0FFF
    //   GPIO     : 0x0000_1000 – 0x0000_1FFF
    //   TIMER    : 0x0000_2000 – 0x0000_2FFF
    //   WATCHDOG : 0x0000_3000 – 0x0000_3FFF  (privileged access only)
    //   IRQ_AGG  : 0x0000_4000 – 0x0000_4FFF

    task ahb_write;
        input [31:0] addr, data;
        input [2:0]  prot;
        // Drive on negedge; poll hready with #1 for NBA visibility
        @(negedge clk);
        cpu_haddr=addr; cpu_htrans=2'b10; cpu_hwrite=1;
        cpu_hprot=prot; cpu_hwdata=data;
        cpu_hsize=3'b010; cpu_hburst=0;
        @(posedge clk); #1;
        while (!cpu_hready) begin @(posedge clk); #1; end
        @(negedge clk); cpu_htrans=2'b00; cpu_hwrite=0;
        @(posedge clk); #1;
    endtask

    task ahb_read;
        input  [31:0] addr;
        input  [2:0]  prot;
        output [31:0] rdata;
        output [1:0]  resp;
        @(negedge clk);
        cpu_haddr=addr; cpu_htrans=2'b10; cpu_hwrite=0;
        cpu_hprot=prot; cpu_hsize=3'b010; cpu_hburst=0;
        @(posedge clk); #1;
        while (!cpu_hready) begin @(posedge clk); #1; end
        rdata = cpu_hrdata; resp = cpu_hresp;
        @(negedge clk); cpu_htrans=2'b00;
        @(posedge clk); #1;
    endtask

    // ── Timeout guard ────────────────────────────────────────────────────
    initial begin
        #5_000_000;
        $display("[TIMEOUT] 5ms simulation limit reached");
        $finish;
    end

endmodule
