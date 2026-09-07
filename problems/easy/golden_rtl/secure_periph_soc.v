// =============================================================================
// secure_periph_soc.v -- Top-level SoC stitching module
// NXP ICLAD 2026 Easy: Secure Peripheral Subsystem
//
// Hierarchy:
//   CPU (AHB-Lite master)
//     -> ahb_to_apb_bridge
//       -> apb_fabric (5 slaves)
//            S0: apb_uart      0x0000_0000
//            S1: apb_gpio      0x0000_1000
//            S2: apb_timer     0x0000_2000
//            S3: apb_watchdog  0x0000_3000  (privileged only)
//            S4: irq_aggregator 0x0000_4000
//   reset_sync: por_n + wdt_rst_req -> sys_rst_n
//   irq sources: uart_irq, gpio_irq, timer_irq, wdt_irq -> irq_aggregator
// =============================================================================
`timescale 1ns/1ps

module secure_periph_soc (
    input  wire        clk,
    input  wire        por_n,

    // AHB-Lite CPU master port
    input  wire [31:0] cpu_haddr,
    input  wire [1:0]  cpu_htrans,
    input  wire        cpu_hwrite,
    input  wire [2:0]  cpu_hsize,
    input  wire [2:0]  cpu_hburst,
    input  wire [2:0]  cpu_hprot,
    input  wire [31:0] cpu_hwdata,
    output wire [31:0] cpu_hrdata,
    output wire        cpu_hready,
    output wire [1:0]  cpu_hresp,

    // GPIO
    input  wire [31:0] gpio_in,
    output wire [31:0] gpio_out,
    output wire [31:0] gpio_oe,

    // UART
    output wire        uart_tx,
    input  wire        uart_rx,
    input  wire        uart_cts_n,
    output wire        uart_rts_n,

    // PWM
    output wire        pwm0,
    output wire        pwm1,

    // Interrupt to CPU
    output wire        cpu_irq,
    output wire [2:0]  cpu_irq_id,

    // Watchdog reset output
    output wire        wdt_rst_req
);

    // -------------------------------------------------------------------------
    // Reset synchronizer
    // -------------------------------------------------------------------------
    wire sys_rst_n;
    wire wdt_rst_n = ~wdt_rst_req;

    reset_sync u_reset_sync (
        .clk      (clk),
        .por_n    (por_n),
        .wdt_rst_n(wdt_rst_n),
        .sys_rst_n(sys_rst_n)
    );

    // -------------------------------------------------------------------------
    // AHB-to-APB bridge
    // -------------------------------------------------------------------------
    wire        br_psel, br_penable, br_pwrite;
    wire [31:0] br_paddr, br_pwdata;
    wire [2:0]  br_pprot;
    wire [31:0] br_prdata;
    wire        br_pready, br_pslverr;
    wire        br_hready_out;
    wire [31:0] br_hrdata;
    wire [1:0]  br_hresp;

    ahb_to_apb_bridge u_bridge (
        .hclk      (clk),
        .hresetn   (sys_rst_n),
        .haddr     (cpu_haddr),
        .htrans    (cpu_htrans),
        .hwrite    (cpu_hwrite),
        .hsize     (cpu_hsize),
        .hburst    (cpu_hburst),
        .hprot     (cpu_hprot),
        .hwdata    (cpu_hwdata),
        .hsel      (1'b1),
        .hready_in (1'b1),
        .hrdata    (br_hrdata),
        .hready_out(br_hready_out),
        .hresp     (br_hresp),
        .psel      (br_psel),
        .penable   (br_penable),
        .pwrite    (br_pwrite),
        .paddr     (br_paddr),
        .pwdata    (br_pwdata),
        .pprot     (br_pprot),
        .prdata    (br_prdata),
        .pready    (br_pready),
        .pslverr   (br_pslverr)
    );

    assign cpu_hrdata = br_hrdata;
    assign cpu_hready = br_hready_out;
    assign cpu_hresp  = br_hresp;

    // -------------------------------------------------------------------------
    // APB fabric (5 slaves)
    // -------------------------------------------------------------------------
    // Slave 0: UART
    wire        s0_psel, s0_penable, s0_pwrite;
    wire [11:0] s0_paddr;
    wire [31:0] s0_pwdata, s0_prdata;
    wire        s0_pready, s0_pslverr;
    // Slave 1: GPIO
    wire        s1_psel, s1_penable, s1_pwrite;
    wire [11:0] s1_paddr;
    wire [31:0] s1_pwdata, s1_prdata;
    wire        s1_pready, s1_pslverr;
    // Slave 2: Timer
    wire        s2_psel, s2_penable, s2_pwrite;
    wire [11:0] s2_paddr;
    wire [31:0] s2_pwdata, s2_prdata;
    wire        s2_pready, s2_pslverr;
    // Slave 3: Watchdog
    wire        s3_psel, s3_penable, s3_pwrite;
    wire [11:0] s3_paddr;
    wire [31:0] s3_pwdata, s3_prdata;
    wire        s3_pready, s3_pslverr;
    // Slave 4: IRQ aggregator
    wire        s4_psel, s4_penable, s4_pwrite;
    wire [11:0] s4_paddr;
    wire [31:0] s4_pwdata, s4_prdata;
    wire        s4_pready, s4_pslverr;

    apb_fabric u_fabric (
        .pclk     (clk),
        .presetn  (sys_rst_n),
        .m_psel   (br_psel),
        .m_penable(br_penable),
        .m_pwrite (br_pwrite),
        .m_paddr  (br_paddr),
        .m_pwdata (br_pwdata),
        .m_pprot  (br_pprot),
        .m_prdata (br_prdata),
        .m_pready (br_pready),
        .m_pslverr(br_pslverr),
        // S0
        .s0_psel  (s0_psel),   .s0_penable(s0_penable), .s0_pwrite(s0_pwrite),
        .s0_paddr (s0_paddr),  .s0_pwdata (s0_pwdata),
        .s0_prdata(s0_prdata), .s0_pready (s0_pready),  .s0_pslverr(s0_pslverr),
        // S1
        .s1_psel  (s1_psel),   .s1_penable(s1_penable), .s1_pwrite(s1_pwrite),
        .s1_paddr (s1_paddr),  .s1_pwdata (s1_pwdata),
        .s1_prdata(s1_prdata), .s1_pready (s1_pready),  .s1_pslverr(s1_pslverr),
        // S2
        .s2_psel  (s2_psel),   .s2_penable(s2_penable), .s2_pwrite(s2_pwrite),
        .s2_paddr (s2_paddr),  .s2_pwdata (s2_pwdata),
        .s2_prdata(s2_prdata), .s2_pready (s2_pready),  .s2_pslverr(s2_pslverr),
        // S3
        .s3_psel  (s3_psel),   .s3_penable(s3_penable), .s3_pwrite(s3_pwrite),
        .s3_paddr (s3_paddr),  .s3_pwdata (s3_pwdata),
        .s3_prdata(s3_prdata), .s3_pready (s3_pready),  .s3_pslverr(s3_pslverr),
        // S4
        .s4_psel  (s4_psel),   .s4_penable(s4_penable), .s4_pwrite(s4_pwrite),
        .s4_paddr (s4_paddr),  .s4_pwdata (s4_pwdata),
        .s4_prdata(s4_prdata), .s4_pready (s4_pready),  .s4_pslverr(s4_pslverr)
    );

    // -------------------------------------------------------------------------
    // APB UART (Slave 0)
    // -------------------------------------------------------------------------
    wire uart_irq;
    apb_uart u_uart (
        .pclk    (clk),
        .presetn (sys_rst_n),
        .psel    (s0_psel),
        .penable (s0_penable),
        .pwrite  (s0_pwrite),
        .paddr   (s0_paddr),
        .pwdata  (s0_pwdata),
        .prdata  (s0_prdata),
        .pready  (s0_pready),
        .pslverr (s0_pslverr),
        .uart_tx (uart_tx),
        .uart_rx (uart_rx),
        .cts_n   (uart_cts_n),
        .rts_n   (uart_rts_n),
        .irq     (uart_irq)
    );

    // -------------------------------------------------------------------------
    // APB GPIO (Slave 1)
    // -------------------------------------------------------------------------
    wire gpio_irq;
    wire [63:0] gpio_alt_func;
    apb_gpio u_gpio (
        .pclk    (clk),
        .presetn (sys_rst_n),
        .psel    (s1_psel),
        .penable (s1_penable),
        .pwrite  (s1_pwrite),
        .paddr   (s1_paddr),
        .pwdata  (s1_pwdata),
        .prdata  (s1_prdata),
        .pready  (s1_pready),
        .pslverr (s1_pslverr),
        .gpio_in (gpio_in),
        .gpio_out(gpio_out),
        .gpio_oe (gpio_oe),
        .alt_func(gpio_alt_func),
        .irq     (gpio_irq)
    );

    // -------------------------------------------------------------------------
    // APB Timer (Slave 2)
    // -------------------------------------------------------------------------
    wire timer_irq;
    apb_timer u_timer (
        .pclk    (clk),
        .presetn (sys_rst_n),
        .psel    (s2_psel),
        .penable (s2_penable),
        .pwrite  (s2_pwrite),
        .paddr   (s2_paddr),
        .pwdata  (s2_pwdata),
        .prdata  (s2_prdata),
        .pready  (s2_pready),
        .pslverr (s2_pslverr),
        .pwm0    (pwm0),
        .pwm1    (pwm1),
        .irq     (timer_irq)
    );

    // -------------------------------------------------------------------------
    // APB Watchdog (Slave 3)
    // -------------------------------------------------------------------------
    wire wdt_irq;
    apb_watchdog u_watchdog (
        .pclk      (clk),
        .presetn   (sys_rst_n),
        .psel      (s3_psel),
        .penable   (s3_penable),
        .pwrite    (s3_pwrite),
        .paddr     (s3_paddr),
        .pwdata    (s3_pwdata),
        .prdata    (s3_prdata),
        .pready    (s3_pready),
        .pslverr   (s3_pslverr),
        .wdt_irq   (wdt_irq),
        .wdt_rst_req(wdt_rst_req)
    );

    // -------------------------------------------------------------------------
    // IRQ aggregator (Slave 4)
    // IRQ source mapping:
    //   [0] = uart_irq
    //   [1] = gpio_irq
    //   [2] = timer_irq
    //   [3] = wdt_irq
    //   [7:4] = unused (tied 0)
    // -------------------------------------------------------------------------
    irq_aggregator u_irq_agg (
        .pclk      (clk),
        .presetn   (sys_rst_n),
        .psel      (s4_psel),
        .penable   (s4_penable),
        .pwrite    (s4_pwrite),
        .paddr     (s4_paddr),
        .pwdata    (s4_pwdata),
        .prdata    (s4_prdata),
        .pready    (s4_pready),
        .pslverr   (s4_pslverr),
        .irq_src   ({4'b0000, wdt_irq, timer_irq, gpio_irq, uart_irq}),
        .cpu_irq   (cpu_irq),
        .cpu_irq_id(cpu_irq_id)
    );

endmodule
