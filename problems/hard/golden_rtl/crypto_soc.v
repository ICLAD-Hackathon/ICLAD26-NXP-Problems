// crypto_soc: Multi-Domain Crypto SoC top-level
// 4x3 TileLink NoC mesh, 4x AES-128, 2x DMA, AXI crossbar, APB cluster,
// dual IRQ aggregators, async mailbox, perf counter, SoC config registers
module crypto_soc (
    input  wire        clk,
    input  wire        por_n,
    input  wire        dsp_clk,
    // CPU AXI4-Lite master
    input  wire [31:0] cpu_awaddr,  input  wire cpu_awvalid, output wire cpu_awready,
    input  wire [31:0] cpu_wdata,   input  wire [3:0] cpu_wstrb,
    input  wire        cpu_wvalid,  output wire cpu_wready,
    output wire [1:0]  cpu_bresp,   output wire cpu_bvalid,  input  wire cpu_bready,
    input  wire [31:0] cpu_araddr,  input  wire cpu_arvalid, output wire cpu_arready,
    output wire [31:0] cpu_rdata,   output wire [1:0] cpu_rresp,
    output wire        cpu_rvalid,  input  wire cpu_rready,
    // GPIO pads
    inout  wire [15:0] gpio0_pad,
    inout  wire [7:0]  gpio1_pad,
    // UART
    input  wire        uart_rx,
    output wire        uart_tx,
    // IRQ outputs
    output wire        cpu_crypto_irq,
    output wire [2:0]  cpu_crypto_irq_id,
    output wire        cpu_periph_irq,
    output wire [2:0]  cpu_periph_irq_id,
    // DSP mailbox read
    output wire [31:0] mbox_dout,
    input  wire        mbox_rd_en,
    output wire        mbox_empty
);
    // -------------------------------------------------------------------
    // Reset synchronizer
    // -------------------------------------------------------------------
    wire sys_rst_n;
    reset_sync u_rst (.clk(clk), .por_n(por_n), .wdt_rst_n(1'b1), .sys_rst_n(sys_rst_n));

    // -------------------------------------------------------------------
    // AXI crossbar wires
    // -------------------------------------------------------------------
    wire [31:0] xb_s0_awaddr; wire xb_s0_awvalid, xb_s0_awready;
    wire [31:0] xb_s0_wdata;  wire [3:0] xb_s0_wstrb; wire xb_s0_wvalid, xb_s0_wready;
    wire [1:0]  xb_s0_bresp;  wire xb_s0_bvalid, xb_s0_bready;
    wire [31:0] xb_s0_araddr; wire xb_s0_arvalid, xb_s0_arready;
    wire [31:0] xb_s0_rdata;  wire [1:0] xb_s0_rresp; wire xb_s0_rvalid, xb_s0_rready;
    wire [63:0] ni00_rdata_64;
    wire [31:0] xb_s1_awaddr; wire xb_s1_awvalid, xb_s1_awready;
    wire [31:0] xb_s1_wdata;  wire [3:0] xb_s1_wstrb; wire xb_s1_wvalid, xb_s1_wready;
    wire [1:0]  xb_s1_bresp;  wire xb_s1_bvalid, xb_s1_bready;
    wire [31:0] xb_s1_araddr; wire xb_s1_arvalid, xb_s1_arready;
    wire [31:0] xb_s1_rdata;  wire [1:0] xb_s1_rresp; wire xb_s1_rvalid, xb_s1_rready;
    wire [31:0] xb_s2_awaddr; wire xb_s2_awvalid, xb_s2_awready;
    wire [31:0] xb_s2_wdata;  wire [3:0] xb_s2_wstrb; wire xb_s2_wvalid, xb_s2_wready;
    wire [1:0]  xb_s2_bresp;  wire xb_s2_bvalid, xb_s2_bready;
    wire [31:0] xb_s2_araddr; wire xb_s2_arvalid, xb_s2_arready;
    wire [31:0] xb_s2_rdata;  wire [1:0] xb_s2_rresp; wire xb_s2_rvalid, xb_s2_rready;
    // DMA config as M1 on crossbar (tied to 0: DMA cfg is accessed directly via dma ports)
    wire [31:0] dma_cfg_awaddr = 32'h0; wire dma_cfg_awvalid = 1'b0;
    wire [31:0] dma_cfg_wdata  = 32'h0; wire [3:0] dma_cfg_wstrb = 4'h0; wire dma_cfg_wvalid = 1'b0;
    wire        dma_cfg_bready = 1'b0;
    wire [31:0] dma_cfg_araddr = 32'h0; wire dma_cfg_arvalid = 1'b0;
    wire        dma_cfg_rready = 1'b0;

    assign xb_s0_rdata = ni00_rdata_64[31:0];
    axi_lite_xbar u_xbar (
        .aclk(clk), .aresetn(sys_rst_n),
        .m0_awaddr(cpu_awaddr), .m0_awvalid(cpu_awvalid), .m0_awready(cpu_awready),
        .m0_wdata(cpu_wdata), .m0_wstrb(cpu_wstrb), .m0_wvalid(cpu_wvalid), .m0_wready(cpu_wready),
        .m0_bresp(cpu_bresp), .m0_bvalid(cpu_bvalid), .m0_bready(cpu_bready),
        .m0_araddr(cpu_araddr), .m0_arvalid(cpu_arvalid), .m0_arready(cpu_arready),
        .m0_rdata(cpu_rdata), .m0_rresp(cpu_rresp), .m0_rvalid(cpu_rvalid), .m0_rready(cpu_rready),
        .m1_awaddr(dma_cfg_awaddr), .m1_awvalid(dma_cfg_awvalid), .m1_awready(),
        .m1_wdata(dma_cfg_wdata), .m1_wstrb(dma_cfg_wstrb), .m1_wvalid(dma_cfg_wvalid), .m1_wready(),
        .m1_bresp(), .m1_bvalid(), .m1_bready(dma_cfg_bready),
        .m1_araddr(dma_cfg_araddr), .m1_arvalid(dma_cfg_arvalid), .m1_arready(),
        .m1_rdata(), .m1_rresp(), .m1_rvalid(), .m1_rready(dma_cfg_rready),
        .s0_awaddr(xb_s0_awaddr), .s0_awvalid(xb_s0_awvalid), .s0_awready(xb_s0_awready),
        .s0_wdata(xb_s0_wdata), .s0_wstrb(xb_s0_wstrb), .s0_wvalid(xb_s0_wvalid), .s0_wready(xb_s0_wready),
        .s0_bresp(xb_s0_bresp), .s0_bvalid(xb_s0_bvalid), .s0_bready(xb_s0_bready),
        .s0_araddr(xb_s0_araddr), .s0_arvalid(xb_s0_arvalid), .s0_arready(xb_s0_arready),
        .s0_rdata(xb_s0_rdata), .s0_rresp(xb_s0_rresp), .s0_rvalid(xb_s0_rvalid), .s0_rready(xb_s0_rready),
        .s1_awaddr(xb_s1_awaddr), .s1_awvalid(xb_s1_awvalid), .s1_awready(xb_s1_awready),
        .s1_wdata(xb_s1_wdata), .s1_wstrb(xb_s1_wstrb), .s1_wvalid(xb_s1_wvalid), .s1_wready(xb_s1_wready),
        .s1_bresp(xb_s1_bresp), .s1_bvalid(xb_s1_bvalid), .s1_bready(xb_s1_bready),
        .s1_araddr(xb_s1_araddr), .s1_arvalid(xb_s1_arvalid), .s1_arready(xb_s1_arready),
        .s1_rdata(xb_s1_rdata), .s1_rresp(xb_s1_rresp), .s1_rvalid(xb_s1_rvalid), .s1_rready(xb_s1_rready),
        .s2_awaddr(xb_s2_awaddr), .s2_awvalid(xb_s2_awvalid), .s2_awready(xb_s2_awready),
        .s2_wdata(xb_s2_wdata), .s2_wstrb(xb_s2_wstrb), .s2_wvalid(xb_s2_wvalid), .s2_wready(xb_s2_wready),
        .s2_bresp(xb_s2_bresp), .s2_bvalid(xb_s2_bvalid), .s2_bready(xb_s2_bready),
        .s2_araddr(xb_s2_araddr), .s2_arvalid(xb_s2_arvalid), .s2_arready(xb_s2_arready),
        .s2_rdata(xb_s2_rdata), .s2_rresp(xb_s2_rresp), .s2_rvalid(xb_s2_rvalid), .s2_rready(xb_s2_rready)
    );
    // -------------------------------------------------------------------
    // APB cluster: AHB bridge -> APB fabric -> 5 slaves
    // -------------------------------------------------------------------
    // AXI-to-AHB shim: drive AHB from crossbar S1 AXI port
    // Use simple combinational bridge: awaddr->haddr, write->hwrite, etc.
    wire [31:0] apb_prdata_out;
    wire        apb_pready_out, apb_pslverr_out;
    wire        apb_psel_m, apb_penable_m, apb_pwrite_m;
    wire [31:0] apb_paddr_m, apb_pwdata_m;
    wire [2:0]  apb_pprot_m;
    // Direct AXI->APB (bypass AHB, drive bridge directly from S1)
    // Convert xb_s1 AXI writes/reads to APB via bridge
    ahb_to_apb_bridge u_bridge (
        .hclk(clk), .hresetn(sys_rst_n),
        .haddr(xb_s1_awvalid ? xb_s1_awaddr : xb_s1_araddr),
        .htrans(xb_s1_awvalid || xb_s1_arvalid ? 2'b10 : 2'b00),
        .hwrite(xb_s1_awvalid),
        .hsize(3'b010), .hburst(3'b000), .hprot(3'b001),
        .hwdata(xb_s1_wdata),
        .hsel(xb_s1_awvalid || xb_s1_arvalid),
        .hready_in(1'b1),
        .hrdata(xb_s1_rdata),
        .hready_out(xb_s1_awready),
        .hresp(xb_s1_bresp),
        .psel(apb_psel_m), .penable(apb_penable_m), .pwrite(apb_pwrite_m),
        .paddr(apb_paddr_m), .pwdata(apb_pwdata_m), .pprot(apb_pprot_m),
        .prdata(apb_prdata_out), .pready(apb_pready_out), .pslverr(apb_pslverr_out)
    );
    assign xb_s1_wready  = xb_s1_awready;
    assign xb_s1_bvalid  = xb_s1_awvalid && apb_pready_out;
    assign xb_s1_arready = ~xb_s1_awvalid;
    assign xb_s1_rvalid  = xb_s1_arvalid && apb_pready_out;
    assign xb_s1_rresp   = 2'b00;

    // APB fabric with 5 slaves
    wire apb_s0_psel, apb_s0_penable, apb_s0_pwrite; wire [11:0] apb_s0_paddr; wire [31:0] apb_s0_pwdata, apb_s0_prdata; wire apb_s0_pready, apb_s0_pslverr;
    wire apb_s1_psel, apb_s1_penable, apb_s1_pwrite; wire [11:0] apb_s1_paddr; wire [31:0] apb_s1_pwdata, apb_s1_prdata; wire apb_s1_pready, apb_s1_pslverr;
    wire apb_s2_psel, apb_s2_penable, apb_s2_pwrite; wire [11:0] apb_s2_paddr; wire [31:0] apb_s2_pwdata, apb_s2_prdata; wire apb_s2_pready, apb_s2_pslverr;
    wire apb_s3_psel, apb_s3_penable, apb_s3_pwrite; wire [11:0] apb_s3_paddr; wire [31:0] apb_s3_pwdata, apb_s3_prdata; wire apb_s3_pready, apb_s3_pslverr;
    wire apb_s4_psel, apb_s4_penable, apb_s4_pwrite; wire [11:0] apb_s4_paddr; wire [31:0] apb_s4_pwdata, apb_s4_prdata; wire apb_s4_pready, apb_s4_pslverr;
    apb_fabric u_apb_fab (
        .pclk(clk), .presetn(sys_rst_n),
        .m_psel(apb_psel_m), .m_penable(apb_penable_m), .m_pwrite(apb_pwrite_m),
        .m_paddr(apb_paddr_m), .m_pwdata(apb_pwdata_m), .m_pprot(apb_pprot_m),
        .m_prdata(apb_prdata_out), .m_pready(apb_pready_out), .m_pslverr(apb_pslverr_out),
        .s0_psel(apb_s0_psel), .s0_penable(apb_s0_penable), .s0_pwrite(apb_s0_pwrite), .s0_paddr(apb_s0_paddr), .s0_pwdata(apb_s0_pwdata), .s0_prdata(apb_s0_prdata), .s0_pready(apb_s0_pready), .s0_pslverr(apb_s0_pslverr),
        .s1_psel(apb_s1_psel), .s1_penable(apb_s1_penable), .s1_pwrite(apb_s1_pwrite), .s1_paddr(apb_s1_paddr), .s1_pwdata(apb_s1_pwdata), .s1_prdata(apb_s1_prdata), .s1_pready(apb_s1_pready), .s1_pslverr(apb_s1_pslverr),
        .s2_psel(apb_s2_psel), .s2_penable(apb_s2_penable), .s2_pwrite(apb_s2_pwrite), .s2_paddr(apb_s2_paddr), .s2_pwdata(apb_s2_pwdata), .s2_prdata(apb_s2_prdata), .s2_pready(apb_s2_pready), .s2_pslverr(apb_s2_pslverr),
        .s3_psel(apb_s3_psel), .s3_penable(apb_s3_penable), .s3_pwrite(apb_s3_pwrite), .s3_paddr(apb_s3_paddr), .s3_pwdata(apb_s3_pwdata), .s3_prdata(apb_s3_prdata), .s3_pready(apb_s3_pready), .s3_pslverr(apb_s3_pslverr),
        .s4_psel(apb_s4_psel), .s4_penable(apb_s4_penable), .s4_pwrite(apb_s4_pwrite), .s4_paddr(apb_s4_paddr), .s4_pwdata(apb_s4_pwdata), .s4_prdata(apb_s4_prdata), .s4_pready(apb_s4_pready), .s4_pslverr(apb_s4_pslverr)
    );

    // APB slaves: UART, GPIO0, GPIO1, Timer0, WDT
    wire uart_rx_irq;
    apb_uart u_uart (
        .pclk(clk), .presetn(sys_rst_n),
        .psel(apb_s0_psel), .penable(apb_s0_penable), .pwrite(apb_s0_pwrite),
        .paddr(apb_s0_paddr), .pwdata(apb_s0_pwdata), .prdata(apb_s0_prdata),
        .pready(apb_s0_pready), .pslverr(apb_s0_pslverr),
        .uart_rx(uart_rx), .uart_tx(uart_tx), .cts_n(1'b1), .rts_n(), .irq(uart_rx_irq)
    );
    wire gpio0_irq;
    apb_gpio0 u_gpio0 (
        .pclk(clk), .presetn(sys_rst_n),
        .psel(apb_s1_psel), .penable(apb_s1_penable), .pwrite(apb_s1_pwrite),
        .paddr(apb_s1_paddr), .pwdata(apb_s1_pwdata), .prdata(apb_s1_prdata),
        .pready(apb_s1_pready), .pslverr(apb_s1_pslverr),
        .gpio_in(gpio0_pad), .gpio_out(), .gpio_oe(), .alt_func(), .irq(gpio0_irq)
    );
    wire gpio1_irq;
    apb_gpio1 u_gpio1 (
        .pclk(clk), .presetn(sys_rst_n),
        .psel(apb_s2_psel), .penable(apb_s2_penable), .pwrite(apb_s2_pwrite),
        .paddr(apb_s2_paddr), .pwdata(apb_s2_pwdata), .prdata(apb_s2_prdata),
        .pready(apb_s2_pready), .pslverr(apb_s2_pslverr),
        .gpio_in(gpio1_pad), .gpio_out(), .gpio_oe(), .alt_func(), .irq(gpio1_irq)
    );
    wire timer0_irq;
    apb_timer0 u_timer0 (
        .pclk(clk), .presetn(sys_rst_n),
        .psel(apb_s3_psel), .penable(apb_s3_penable), .pwrite(apb_s3_pwrite),
        .paddr(apb_s3_paddr), .pwdata(apb_s3_pwdata), .prdata(apb_s3_prdata),
        .pready(apb_s3_pready), .pslverr(apb_s3_pslverr),
        .pwm0(), .pwm1(), .irq(timer0_irq)
    );
    wire wdt_irq;
    apb_watchdog u_wdt (
        .pclk(clk), .presetn(sys_rst_n),
        .psel(apb_s4_psel), .penable(apb_s4_penable), .pwrite(apb_s4_pwrite),
        .paddr(apb_s4_paddr), .pwdata(apb_s4_pwdata), .prdata(apb_s4_prdata),
        .pready(apb_s4_pready), .pslverr(apb_s4_pslverr),
        .wdt_irq(wdt_irq)
    );

    // -------------------------------------------------------------------
    // NoC mesh wire declarations
    // -------------------------------------------------------------------
    // NI inject wires per node (tl_a output from NI -> router inj)
    wire [2:0]  ni00_tl_a_opcode, ni00_tl_a_param;
    wire [2:0]  ni00_tl_a_size;
    wire [3:0]  ni00_tl_a_source;
    wire [31:0] ni00_tl_a_addr;
    wire [7:0]  ni00_tl_a_mask;
    wire [63:0] ni00_tl_a_data;
    wire        ni00_tl_a_valid, ni00_tl_a_ready;
    wire [2:0]  ni00_tl_d_opcode; wire [1:0] ni00_tl_d_param;
    wire [2:0]  ni00_tl_d_size; wire [3:0] ni00_tl_d_source;
    wire [63:0] ni00_tl_d_data; wire ni00_tl_d_valid, ni00_tl_d_ready;
    wire [2:0]  ni01_tl_a_opcode, ni01_tl_a_param;
    wire [2:0]  ni01_tl_a_size;
    wire [3:0]  ni01_tl_a_source;
    wire [31:0] ni01_tl_a_addr;
    wire [7:0]  ni01_tl_a_mask;
    wire [63:0] ni01_tl_a_data;
    wire        ni01_tl_a_valid, ni01_tl_a_ready;
    wire [2:0]  ni01_tl_d_opcode; wire [1:0] ni01_tl_d_param;
    wire [2:0]  ni01_tl_d_size; wire [3:0] ni01_tl_d_source;
    wire [63:0] ni01_tl_d_data; wire ni01_tl_d_valid, ni01_tl_d_ready;
    wire [2:0]  ni02_tl_a_opcode, ni02_tl_a_param;
    wire [2:0]  ni02_tl_a_size;
    wire [3:0]  ni02_tl_a_source;
    wire [31:0] ni02_tl_a_addr;
    wire [7:0]  ni02_tl_a_mask;
    wire [63:0] ni02_tl_a_data;
    wire        ni02_tl_a_valid, ni02_tl_a_ready;
    wire [2:0]  ni02_tl_d_opcode; wire [1:0] ni02_tl_d_param;
    wire [2:0]  ni02_tl_d_size; wire [3:0] ni02_tl_d_source;
    wire [63:0] ni02_tl_d_data; wire ni02_tl_d_valid, ni02_tl_d_ready;
    wire [2:0]  ni10_tl_a_opcode, ni10_tl_a_param;
    wire [2:0]  ni10_tl_a_size;
    wire [3:0]  ni10_tl_a_source;
    wire [31:0] ni10_tl_a_addr;
    wire [7:0]  ni10_tl_a_mask;
    wire [63:0] ni10_tl_a_data;
    wire        ni10_tl_a_valid, ni10_tl_a_ready;
    wire [2:0]  ni10_tl_d_opcode; wire [1:0] ni10_tl_d_param;
    wire [2:0]  ni10_tl_d_size; wire [3:0] ni10_tl_d_source;
    wire [63:0] ni10_tl_d_data; wire ni10_tl_d_valid, ni10_tl_d_ready;
    wire [2:0]  ni11_tl_a_opcode, ni11_tl_a_param;
    wire [2:0]  ni11_tl_a_size;
    wire [3:0]  ni11_tl_a_source;
    wire [31:0] ni11_tl_a_addr;
    wire [7:0]  ni11_tl_a_mask;
    wire [63:0] ni11_tl_a_data;
    wire        ni11_tl_a_valid, ni11_tl_a_ready;
    wire [2:0]  ni11_tl_d_opcode; wire [1:0] ni11_tl_d_param;
    wire [2:0]  ni11_tl_d_size; wire [3:0] ni11_tl_d_source;
    wire [63:0] ni11_tl_d_data; wire ni11_tl_d_valid, ni11_tl_d_ready;
    wire [2:0]  ni12_tl_a_opcode, ni12_tl_a_param;
    wire [2:0]  ni12_tl_a_size;
    wire [3:0]  ni12_tl_a_source;
    wire [31:0] ni12_tl_a_addr;
    wire [7:0]  ni12_tl_a_mask;
    wire [63:0] ni12_tl_a_data;
    wire        ni12_tl_a_valid, ni12_tl_a_ready;
    wire [2:0]  ni12_tl_d_opcode; wire [1:0] ni12_tl_d_param;
    wire [2:0]  ni12_tl_d_size; wire [3:0] ni12_tl_d_source;
    wire [63:0] ni12_tl_d_data; wire ni12_tl_d_valid, ni12_tl_d_ready;
    wire [2:0]  ni20_tl_a_opcode, ni20_tl_a_param;
    wire [2:0]  ni20_tl_a_size;
    wire [3:0]  ni20_tl_a_source;
    wire [31:0] ni20_tl_a_addr;
    wire [7:0]  ni20_tl_a_mask;
    wire [63:0] ni20_tl_a_data;
    wire        ni20_tl_a_valid, ni20_tl_a_ready;
    wire [2:0]  ni20_tl_d_opcode; wire [1:0] ni20_tl_d_param;
    wire [2:0]  ni20_tl_d_size; wire [3:0] ni20_tl_d_source;
    wire [63:0] ni20_tl_d_data; wire ni20_tl_d_valid, ni20_tl_d_ready;
    wire [2:0]  ni21_tl_a_opcode, ni21_tl_a_param;
    wire [2:0]  ni21_tl_a_size;
    wire [3:0]  ni21_tl_a_source;
    wire [31:0] ni21_tl_a_addr;
    wire [7:0]  ni21_tl_a_mask;
    wire [63:0] ni21_tl_a_data;
    wire        ni21_tl_a_valid, ni21_tl_a_ready;
    wire [2:0]  ni21_tl_d_opcode; wire [1:0] ni21_tl_d_param;
    wire [2:0]  ni21_tl_d_size; wire [3:0] ni21_tl_d_source;
    wire [63:0] ni21_tl_d_data; wire ni21_tl_d_valid, ni21_tl_d_ready;
    wire [2:0]  ni22_tl_a_opcode, ni22_tl_a_param;
    wire [2:0]  ni22_tl_a_size;
    wire [3:0]  ni22_tl_a_source;
    wire [31:0] ni22_tl_a_addr;
    wire [7:0]  ni22_tl_a_mask;
    wire [63:0] ni22_tl_a_data;
    wire        ni22_tl_a_valid, ni22_tl_a_ready;
    wire [2:0]  ni22_tl_d_opcode; wire [1:0] ni22_tl_d_param;
    wire [2:0]  ni22_tl_d_size; wire [3:0] ni22_tl_d_source;
    wire [63:0] ni22_tl_d_data; wire ni22_tl_d_valid, ni22_tl_d_ready;
    wire [2:0]  ni30_tl_a_opcode, ni30_tl_a_param;
    wire [2:0]  ni30_tl_a_size;
    wire [3:0]  ni30_tl_a_source;
    wire [31:0] ni30_tl_a_addr;
    wire [7:0]  ni30_tl_a_mask;
    wire [63:0] ni30_tl_a_data;
    wire        ni30_tl_a_valid, ni30_tl_a_ready;
    wire [2:0]  ni30_tl_d_opcode; wire [1:0] ni30_tl_d_param;
    wire [2:0]  ni30_tl_d_size; wire [3:0] ni30_tl_d_source;
    wire [63:0] ni30_tl_d_data; wire ni30_tl_d_valid, ni30_tl_d_ready;
    wire [2:0]  ni31_tl_a_opcode, ni31_tl_a_param;
    wire [2:0]  ni31_tl_a_size;
    wire [3:0]  ni31_tl_a_source;
    wire [31:0] ni31_tl_a_addr;
    wire [7:0]  ni31_tl_a_mask;
    wire [63:0] ni31_tl_a_data;
    wire        ni31_tl_a_valid, ni31_tl_a_ready;
    wire [2:0]  ni31_tl_d_opcode; wire [1:0] ni31_tl_d_param;
    wire [2:0]  ni31_tl_d_size; wire [3:0] ni31_tl_d_source;
    wire [63:0] ni31_tl_d_data; wire ni31_tl_d_valid, ni31_tl_d_ready;
    wire [2:0]  ni32_tl_a_opcode, ni32_tl_a_param;
    wire [2:0]  ni32_tl_a_size;
    wire [3:0]  ni32_tl_a_source;
    wire [31:0] ni32_tl_a_addr;
    wire [7:0]  ni32_tl_a_mask;
    wire [63:0] ni32_tl_a_data;
    wire        ni32_tl_a_valid, ni32_tl_a_ready;
    wire [2:0]  ni32_tl_d_opcode; wire [1:0] ni32_tl_d_param;
    wire [2:0]  ni32_tl_d_size; wire [3:0] ni32_tl_d_source;
    wire [63:0] ni32_tl_d_data; wire ni32_tl_d_valid, ni32_tl_d_ready;

    // E-W bidirectional link wires: one bus per row per E->W and W->E direction
    wire [2:0]  ew_y0_x0_1_e_opcode, ew_y0_x0_1_e_param;
    wire [2:0]  ew_y0_x0_1_e_size; wire [3:0] ew_y0_x0_1_e_source;
    wire [31:0] ew_y0_x0_1_e_addr; wire [7:0] ew_y0_x0_1_e_mask;
    wire [63:0] ew_y0_x0_1_e_data; wire ew_y0_x0_1_e_valid;
    wire [2:0]  ew_y0_x0_1_w_opcode, ew_y0_x0_1_w_param;
    wire [2:0]  ew_y0_x0_1_w_size; wire [3:0] ew_y0_x0_1_w_source;
    wire [31:0] ew_y0_x0_1_w_addr; wire [7:0] ew_y0_x0_1_w_mask;
    wire [63:0] ew_y0_x0_1_w_data; wire ew_y0_x0_1_w_valid;
    wire [2:0]  ew_y0_x1_2_e_opcode, ew_y0_x1_2_e_param;
    wire [2:0]  ew_y0_x1_2_e_size; wire [3:0] ew_y0_x1_2_e_source;
    wire [31:0] ew_y0_x1_2_e_addr; wire [7:0] ew_y0_x1_2_e_mask;
    wire [63:0] ew_y0_x1_2_e_data; wire ew_y0_x1_2_e_valid;
    wire [2:0]  ew_y0_x1_2_w_opcode, ew_y0_x1_2_w_param;
    wire [2:0]  ew_y0_x1_2_w_size; wire [3:0] ew_y0_x1_2_w_source;
    wire [31:0] ew_y0_x1_2_w_addr; wire [7:0] ew_y0_x1_2_w_mask;
    wire [63:0] ew_y0_x1_2_w_data; wire ew_y0_x1_2_w_valid;
    wire [2:0]  ew_y0_x2_3_e_opcode, ew_y0_x2_3_e_param;
    wire [2:0]  ew_y0_x2_3_e_size; wire [3:0] ew_y0_x2_3_e_source;
    wire [31:0] ew_y0_x2_3_e_addr; wire [7:0] ew_y0_x2_3_e_mask;
    wire [63:0] ew_y0_x2_3_e_data; wire ew_y0_x2_3_e_valid;
    wire [2:0]  ew_y0_x2_3_w_opcode, ew_y0_x2_3_w_param;
    wire [2:0]  ew_y0_x2_3_w_size; wire [3:0] ew_y0_x2_3_w_source;
    wire [31:0] ew_y0_x2_3_w_addr; wire [7:0] ew_y0_x2_3_w_mask;
    wire [63:0] ew_y0_x2_3_w_data; wire ew_y0_x2_3_w_valid;
    wire [2:0]  ew_y1_x0_1_e_opcode, ew_y1_x0_1_e_param;
    wire [2:0]  ew_y1_x0_1_e_size; wire [3:0] ew_y1_x0_1_e_source;
    wire [31:0] ew_y1_x0_1_e_addr; wire [7:0] ew_y1_x0_1_e_mask;
    wire [63:0] ew_y1_x0_1_e_data; wire ew_y1_x0_1_e_valid;
    wire [2:0]  ew_y1_x0_1_w_opcode, ew_y1_x0_1_w_param;
    wire [2:0]  ew_y1_x0_1_w_size; wire [3:0] ew_y1_x0_1_w_source;
    wire [31:0] ew_y1_x0_1_w_addr; wire [7:0] ew_y1_x0_1_w_mask;
    wire [63:0] ew_y1_x0_1_w_data; wire ew_y1_x0_1_w_valid;
    wire [2:0]  ew_y1_x1_2_e_opcode, ew_y1_x1_2_e_param;
    wire [2:0]  ew_y1_x1_2_e_size; wire [3:0] ew_y1_x1_2_e_source;
    wire [31:0] ew_y1_x1_2_e_addr; wire [7:0] ew_y1_x1_2_e_mask;
    wire [63:0] ew_y1_x1_2_e_data; wire ew_y1_x1_2_e_valid;
    wire [2:0]  ew_y1_x1_2_w_opcode, ew_y1_x1_2_w_param;
    wire [2:0]  ew_y1_x1_2_w_size; wire [3:0] ew_y1_x1_2_w_source;
    wire [31:0] ew_y1_x1_2_w_addr; wire [7:0] ew_y1_x1_2_w_mask;
    wire [63:0] ew_y1_x1_2_w_data; wire ew_y1_x1_2_w_valid;
    wire [2:0]  ew_y1_x2_3_e_opcode, ew_y1_x2_3_e_param;
    wire [2:0]  ew_y1_x2_3_e_size; wire [3:0] ew_y1_x2_3_e_source;
    wire [31:0] ew_y1_x2_3_e_addr; wire [7:0] ew_y1_x2_3_e_mask;
    wire [63:0] ew_y1_x2_3_e_data; wire ew_y1_x2_3_e_valid;
    wire [2:0]  ew_y1_x2_3_w_opcode, ew_y1_x2_3_w_param;
    wire [2:0]  ew_y1_x2_3_w_size; wire [3:0] ew_y1_x2_3_w_source;
    wire [31:0] ew_y1_x2_3_w_addr; wire [7:0] ew_y1_x2_3_w_mask;
    wire [63:0] ew_y1_x2_3_w_data; wire ew_y1_x2_3_w_valid;
    wire [2:0]  ew_y2_x0_1_e_opcode, ew_y2_x0_1_e_param;
    wire [2:0]  ew_y2_x0_1_e_size; wire [3:0] ew_y2_x0_1_e_source;
    wire [31:0] ew_y2_x0_1_e_addr; wire [7:0] ew_y2_x0_1_e_mask;
    wire [63:0] ew_y2_x0_1_e_data; wire ew_y2_x0_1_e_valid;
    wire [2:0]  ew_y2_x0_1_w_opcode, ew_y2_x0_1_w_param;
    wire [2:0]  ew_y2_x0_1_w_size; wire [3:0] ew_y2_x0_1_w_source;
    wire [31:0] ew_y2_x0_1_w_addr; wire [7:0] ew_y2_x0_1_w_mask;
    wire [63:0] ew_y2_x0_1_w_data; wire ew_y2_x0_1_w_valid;
    wire [2:0]  ew_y2_x1_2_e_opcode, ew_y2_x1_2_e_param;
    wire [2:0]  ew_y2_x1_2_e_size; wire [3:0] ew_y2_x1_2_e_source;
    wire [31:0] ew_y2_x1_2_e_addr; wire [7:0] ew_y2_x1_2_e_mask;
    wire [63:0] ew_y2_x1_2_e_data; wire ew_y2_x1_2_e_valid;
    wire [2:0]  ew_y2_x1_2_w_opcode, ew_y2_x1_2_w_param;
    wire [2:0]  ew_y2_x1_2_w_size; wire [3:0] ew_y2_x1_2_w_source;
    wire [31:0] ew_y2_x1_2_w_addr; wire [7:0] ew_y2_x1_2_w_mask;
    wire [63:0] ew_y2_x1_2_w_data; wire ew_y2_x1_2_w_valid;
    wire [2:0]  ew_y2_x2_3_e_opcode, ew_y2_x2_3_e_param;
    wire [2:0]  ew_y2_x2_3_e_size; wire [3:0] ew_y2_x2_3_e_source;
    wire [31:0] ew_y2_x2_3_e_addr; wire [7:0] ew_y2_x2_3_e_mask;
    wire [63:0] ew_y2_x2_3_e_data; wire ew_y2_x2_3_e_valid;
    wire [2:0]  ew_y2_x2_3_w_opcode, ew_y2_x2_3_w_param;
    wire [2:0]  ew_y2_x2_3_w_size; wire [3:0] ew_y2_x2_3_w_source;
    wire [31:0] ew_y2_x2_3_w_addr; wire [7:0] ew_y2_x2_3_w_mask;
    wire [63:0] ew_y2_x2_3_w_data; wire ew_y2_x2_3_w_valid;

    // N-S bidirectional link wires
    wire [2:0]  ns_x0_y0_1_n_opcode, ns_x0_y0_1_n_param;
    wire [2:0]  ns_x0_y0_1_n_size; wire [3:0] ns_x0_y0_1_n_source;
    wire [31:0] ns_x0_y0_1_n_addr; wire [7:0] ns_x0_y0_1_n_mask;
    wire [63:0] ns_x0_y0_1_n_data; wire ns_x0_y0_1_n_valid;
    wire [2:0]  ns_x0_y0_1_s_opcode, ns_x0_y0_1_s_param;
    wire [2:0]  ns_x0_y0_1_s_size; wire [3:0] ns_x0_y0_1_s_source;
    wire [31:0] ns_x0_y0_1_s_addr; wire [7:0] ns_x0_y0_1_s_mask;
    wire [63:0] ns_x0_y0_1_s_data; wire ns_x0_y0_1_s_valid;
    wire [2:0]  ns_x0_y1_2_n_opcode, ns_x0_y1_2_n_param;
    wire [2:0]  ns_x0_y1_2_n_size; wire [3:0] ns_x0_y1_2_n_source;
    wire [31:0] ns_x0_y1_2_n_addr; wire [7:0] ns_x0_y1_2_n_mask;
    wire [63:0] ns_x0_y1_2_n_data; wire ns_x0_y1_2_n_valid;
    wire [2:0]  ns_x0_y1_2_s_opcode, ns_x0_y1_2_s_param;
    wire [2:0]  ns_x0_y1_2_s_size; wire [3:0] ns_x0_y1_2_s_source;
    wire [31:0] ns_x0_y1_2_s_addr; wire [7:0] ns_x0_y1_2_s_mask;
    wire [63:0] ns_x0_y1_2_s_data; wire ns_x0_y1_2_s_valid;
    wire [2:0]  ns_x1_y0_1_n_opcode, ns_x1_y0_1_n_param;
    wire [2:0]  ns_x1_y0_1_n_size; wire [3:0] ns_x1_y0_1_n_source;
    wire [31:0] ns_x1_y0_1_n_addr; wire [7:0] ns_x1_y0_1_n_mask;
    wire [63:0] ns_x1_y0_1_n_data; wire ns_x1_y0_1_n_valid;
    wire [2:0]  ns_x1_y0_1_s_opcode, ns_x1_y0_1_s_param;
    wire [2:0]  ns_x1_y0_1_s_size; wire [3:0] ns_x1_y0_1_s_source;
    wire [31:0] ns_x1_y0_1_s_addr; wire [7:0] ns_x1_y0_1_s_mask;
    wire [63:0] ns_x1_y0_1_s_data; wire ns_x1_y0_1_s_valid;
    wire [2:0]  ns_x1_y1_2_n_opcode, ns_x1_y1_2_n_param;
    wire [2:0]  ns_x1_y1_2_n_size; wire [3:0] ns_x1_y1_2_n_source;
    wire [31:0] ns_x1_y1_2_n_addr; wire [7:0] ns_x1_y1_2_n_mask;
    wire [63:0] ns_x1_y1_2_n_data; wire ns_x1_y1_2_n_valid;
    wire [2:0]  ns_x1_y1_2_s_opcode, ns_x1_y1_2_s_param;
    wire [2:0]  ns_x1_y1_2_s_size; wire [3:0] ns_x1_y1_2_s_source;
    wire [31:0] ns_x1_y1_2_s_addr; wire [7:0] ns_x1_y1_2_s_mask;
    wire [63:0] ns_x1_y1_2_s_data; wire ns_x1_y1_2_s_valid;
    wire [2:0]  ns_x2_y0_1_n_opcode, ns_x2_y0_1_n_param;
    wire [2:0]  ns_x2_y0_1_n_size; wire [3:0] ns_x2_y0_1_n_source;
    wire [31:0] ns_x2_y0_1_n_addr; wire [7:0] ns_x2_y0_1_n_mask;
    wire [63:0] ns_x2_y0_1_n_data; wire ns_x2_y0_1_n_valid;
    wire [2:0]  ns_x2_y0_1_s_opcode, ns_x2_y0_1_s_param;
    wire [2:0]  ns_x2_y0_1_s_size; wire [3:0] ns_x2_y0_1_s_source;
    wire [31:0] ns_x2_y0_1_s_addr; wire [7:0] ns_x2_y0_1_s_mask;
    wire [63:0] ns_x2_y0_1_s_data; wire ns_x2_y0_1_s_valid;
    wire [2:0]  ns_x2_y1_2_n_opcode, ns_x2_y1_2_n_param;
    wire [2:0]  ns_x2_y1_2_n_size; wire [3:0] ns_x2_y1_2_n_source;
    wire [31:0] ns_x2_y1_2_n_addr; wire [7:0] ns_x2_y1_2_n_mask;
    wire [63:0] ns_x2_y1_2_n_data; wire ns_x2_y1_2_n_valid;
    wire [2:0]  ns_x2_y1_2_s_opcode, ns_x2_y1_2_s_param;
    wire [2:0]  ns_x2_y1_2_s_size; wire [3:0] ns_x2_y1_2_s_source;
    wire [31:0] ns_x2_y1_2_s_addr; wire [7:0] ns_x2_y1_2_s_mask;
    wire [63:0] ns_x2_y1_2_s_data; wire ns_x2_y1_2_s_valid;
    wire [2:0]  ns_x3_y0_1_n_opcode, ns_x3_y0_1_n_param;
    wire [2:0]  ns_x3_y0_1_n_size; wire [3:0] ns_x3_y0_1_n_source;
    wire [31:0] ns_x3_y0_1_n_addr; wire [7:0] ns_x3_y0_1_n_mask;
    wire [63:0] ns_x3_y0_1_n_data; wire ns_x3_y0_1_n_valid;
    wire [2:0]  ns_x3_y0_1_s_opcode, ns_x3_y0_1_s_param;
    wire [2:0]  ns_x3_y0_1_s_size; wire [3:0] ns_x3_y0_1_s_source;
    wire [31:0] ns_x3_y0_1_s_addr; wire [7:0] ns_x3_y0_1_s_mask;
    wire [63:0] ns_x3_y0_1_s_data; wire ns_x3_y0_1_s_valid;
    wire [2:0]  ns_x3_y1_2_n_opcode, ns_x3_y1_2_n_param;
    wire [2:0]  ns_x3_y1_2_n_size; wire [3:0] ns_x3_y1_2_n_source;
    wire [31:0] ns_x3_y1_2_n_addr; wire [7:0] ns_x3_y1_2_n_mask;
    wire [63:0] ns_x3_y1_2_n_data; wire ns_x3_y1_2_n_valid;
    wire [2:0]  ns_x3_y1_2_s_opcode, ns_x3_y1_2_s_param;
    wire [2:0]  ns_x3_y1_2_s_size; wire [3:0] ns_x3_y1_2_s_source;
    wire [31:0] ns_x3_y1_2_s_addr; wire [7:0] ns_x3_y1_2_s_mask;
    wire [63:0] ns_x3_y1_2_s_data; wire ns_x3_y1_2_s_valid;

    // Router AXI-to-SRAM wires
    wire [31:0] r00_awaddr; wire r00_awvalid, r00_awready;
    wire [63:0] r00_wdata; wire [7:0] r00_wstrb; wire r00_wvalid, r00_wready;
    wire [1:0]  r00_bresp; wire r00_bvalid, r00_bready;
    wire [31:0] r00_araddr; wire r00_arvalid, r00_arready;
    wire [63:0] r00_rdata; wire [1:0] r00_rresp; wire r00_rvalid, r00_rready;
    wire [2:0]  r00_d_opcode; wire [1:0] r00_d_param;
    wire [2:0]  r00_d_size; wire [3:0] r00_d_source;
    wire [63:0] r00_d_data; wire r00_d_valid;
    wire [31:0] r01_awaddr; wire r01_awvalid, r01_awready;
    wire [63:0] r01_wdata; wire [7:0] r01_wstrb; wire r01_wvalid, r01_wready;
    wire [1:0]  r01_bresp; wire r01_bvalid, r01_bready;
    wire [31:0] r01_araddr; wire r01_arvalid, r01_arready;
    wire [63:0] r01_rdata; wire [1:0] r01_rresp; wire r01_rvalid, r01_rready;
    wire [2:0]  r01_d_opcode; wire [1:0] r01_d_param;
    wire [2:0]  r01_d_size; wire [3:0] r01_d_source;
    wire [63:0] r01_d_data; wire r01_d_valid;
    wire [31:0] r02_awaddr; wire r02_awvalid, r02_awready;
    wire [63:0] r02_wdata; wire [7:0] r02_wstrb; wire r02_wvalid, r02_wready;
    wire [1:0]  r02_bresp; wire r02_bvalid, r02_bready;
    wire [31:0] r02_araddr; wire r02_arvalid, r02_arready;
    wire [63:0] r02_rdata; wire [1:0] r02_rresp; wire r02_rvalid, r02_rready;
    wire [2:0]  r02_d_opcode; wire [1:0] r02_d_param;
    wire [2:0]  r02_d_size; wire [3:0] r02_d_source;
    wire [63:0] r02_d_data; wire r02_d_valid;
    wire [31:0] r10_awaddr; wire r10_awvalid, r10_awready;
    wire [63:0] r10_wdata; wire [7:0] r10_wstrb; wire r10_wvalid, r10_wready;
    wire [1:0]  r10_bresp; wire r10_bvalid, r10_bready;
    wire [31:0] r10_araddr; wire r10_arvalid, r10_arready;
    wire [63:0] r10_rdata; wire [1:0] r10_rresp; wire r10_rvalid, r10_rready;
    wire [2:0]  r10_d_opcode; wire [1:0] r10_d_param;
    wire [2:0]  r10_d_size; wire [3:0] r10_d_source;
    wire [63:0] r10_d_data; wire r10_d_valid;
    wire [31:0] r11_awaddr; wire r11_awvalid, r11_awready;
    wire [63:0] r11_wdata; wire [7:0] r11_wstrb; wire r11_wvalid, r11_wready;
    wire [1:0]  r11_bresp; wire r11_bvalid, r11_bready;
    wire [31:0] r11_araddr; wire r11_arvalid, r11_arready;
    wire [63:0] r11_rdata; wire [1:0] r11_rresp; wire r11_rvalid, r11_rready;
    wire [2:0]  r11_d_opcode; wire [1:0] r11_d_param;
    wire [2:0]  r11_d_size; wire [3:0] r11_d_source;
    wire [63:0] r11_d_data; wire r11_d_valid;
    wire [31:0] r12_awaddr; wire r12_awvalid, r12_awready;
    wire [63:0] r12_wdata; wire [7:0] r12_wstrb; wire r12_wvalid, r12_wready;
    wire [1:0]  r12_bresp; wire r12_bvalid, r12_bready;
    wire [31:0] r12_araddr; wire r12_arvalid, r12_arready;
    wire [63:0] r12_rdata; wire [1:0] r12_rresp; wire r12_rvalid, r12_rready;
    wire [2:0]  r12_d_opcode; wire [1:0] r12_d_param;
    wire [2:0]  r12_d_size; wire [3:0] r12_d_source;
    wire [63:0] r12_d_data; wire r12_d_valid;
    wire [31:0] r20_awaddr; wire r20_awvalid, r20_awready;
    wire [63:0] r20_wdata; wire [7:0] r20_wstrb; wire r20_wvalid, r20_wready;
    wire [1:0]  r20_bresp; wire r20_bvalid, r20_bready;
    wire [31:0] r20_araddr; wire r20_arvalid, r20_arready;
    wire [63:0] r20_rdata; wire [1:0] r20_rresp; wire r20_rvalid, r20_rready;
    wire [2:0]  r20_d_opcode; wire [1:0] r20_d_param;
    wire [2:0]  r20_d_size; wire [3:0] r20_d_source;
    wire [63:0] r20_d_data; wire r20_d_valid;
    wire [31:0] r21_awaddr; wire r21_awvalid, r21_awready;
    wire [63:0] r21_wdata; wire [7:0] r21_wstrb; wire r21_wvalid, r21_wready;
    wire [1:0]  r21_bresp; wire r21_bvalid, r21_bready;
    wire [31:0] r21_araddr; wire r21_arvalid, r21_arready;
    wire [63:0] r21_rdata; wire [1:0] r21_rresp; wire r21_rvalid, r21_rready;
    wire [2:0]  r21_d_opcode; wire [1:0] r21_d_param;
    wire [2:0]  r21_d_size; wire [3:0] r21_d_source;
    wire [63:0] r21_d_data; wire r21_d_valid;
    wire [31:0] r22_awaddr; wire r22_awvalid, r22_awready;
    wire [63:0] r22_wdata; wire [7:0] r22_wstrb; wire r22_wvalid, r22_wready;
    wire [1:0]  r22_bresp; wire r22_bvalid, r22_bready;
    wire [31:0] r22_araddr; wire r22_arvalid, r22_arready;
    wire [63:0] r22_rdata; wire [1:0] r22_rresp; wire r22_rvalid, r22_rready;
    wire [2:0]  r22_d_opcode; wire [1:0] r22_d_param;
    wire [2:0]  r22_d_size; wire [3:0] r22_d_source;
    wire [63:0] r22_d_data; wire r22_d_valid;
    wire [31:0] r30_awaddr; wire r30_awvalid, r30_awready;
    wire [63:0] r30_wdata; wire [7:0] r30_wstrb; wire r30_wvalid, r30_wready;
    wire [1:0]  r30_bresp; wire r30_bvalid, r30_bready;
    wire [31:0] r30_araddr; wire r30_arvalid, r30_arready;
    wire [63:0] r30_rdata; wire [1:0] r30_rresp; wire r30_rvalid, r30_rready;
    wire [2:0]  r30_d_opcode; wire [1:0] r30_d_param;
    wire [2:0]  r30_d_size; wire [3:0] r30_d_source;
    wire [63:0] r30_d_data; wire r30_d_valid;
    wire [31:0] r31_awaddr; wire r31_awvalid, r31_awready;
    wire [63:0] r31_wdata; wire [7:0] r31_wstrb; wire r31_wvalid, r31_wready;
    wire [1:0]  r31_bresp; wire r31_bvalid, r31_bready;
    wire [31:0] r31_araddr; wire r31_arvalid, r31_arready;
    wire [63:0] r31_rdata; wire [1:0] r31_rresp; wire r31_rvalid, r31_rready;
    wire [2:0]  r31_d_opcode; wire [1:0] r31_d_param;
    wire [2:0]  r31_d_size; wire [3:0] r31_d_source;
    wire [63:0] r31_d_data; wire r31_d_valid;
    wire [31:0] r32_awaddr; wire r32_awvalid, r32_awready;
    wire [63:0] r32_wdata; wire [7:0] r32_wstrb; wire r32_wvalid, r32_wready;
    wire [1:0]  r32_bresp; wire r32_bvalid, r32_bready;
    wire [31:0] r32_araddr; wire r32_arvalid, r32_arready;
    wire [63:0] r32_rdata; wire [1:0] r32_rresp; wire r32_rvalid, r32_rready;
    wire [2:0]  r32_d_opcode; wire [1:0] r32_d_param;
    wire [2:0]  r32_d_size; wire [3:0] r32_d_source;
    wire [63:0] r32_d_data; wire r32_d_valid;

    // Boundary tie-offs: West boundary of col 0, East boundary of col 3,
    // North boundary of row 2, South boundary of row 0
    wire tie_lo = 1'b0;
    wire [63:0] tie64 = 64'h0;
    wire [31:0] tie32 = 32'h0;
    wire [7:0]  tie8  = 8'h0;
    wire [3:0]  tie4  = 4'h0;
    wire [2:0]  tie3  = 3'h0;
    // -------------------------------------------------------------------
    // 12 NoC nodes: router + NI + SRAM instantiations
    // -------------------------------------------------------------------
    // --- Node (0,0) ---
    ni_00 u_ni_00 (
        .clk(clk), .rst_n(sys_rst_n),
        .axi_awaddr(xb_s0_awaddr), .axi_awvalid(xb_s0_awvalid), .axi_awready(xb_s0_awready),
        .axi_wdata({32'h0,xb_s0_wdata}), .axi_wstrb({4'h0,xb_s0_wstrb}), .axi_wvalid(xb_s0_wvalid), .axi_wready(xb_s0_wready),
        .axi_bresp(xb_s0_bresp), .axi_bvalid(xb_s0_bvalid), .axi_bready(xb_s0_bready),
        .axi_araddr(xb_s0_araddr), .axi_arvalid(xb_s0_arvalid), .axi_arready(xb_s0_arready),
        .axi_rdata(ni00_rdata_64), .axi_rresp(xb_s0_rresp), .axi_rvalid(xb_s0_rvalid), .axi_rready(xb_s0_rready),
        .tl_a_opcode(ni00_tl_a_opcode), .tl_a_param(ni00_tl_a_param),
        .tl_a_size(ni00_tl_a_size), .tl_a_source(ni00_tl_a_source),
        .tl_a_addr(ni00_tl_a_addr), .tl_a_mask(ni00_tl_a_mask),
        .tl_a_data(ni00_tl_a_data), .tl_a_valid(ni00_tl_a_valid), .tl_a_ready(ni00_tl_a_ready),
        .tl_d_opcode(r00_d_opcode), .tl_d_param(r00_d_param),
        .tl_d_size(r00_d_size), .tl_d_source(r00_d_source),
        .tl_d_data(r00_d_data), .tl_d_valid(r00_d_valid), .tl_d_ready(r00_d_ready)
    );
    router_00 u_router_00 (
        .clk(clk), .rst_n(sys_rst_n),
        .p0_a_opcode(ns_x0_y0_1_s_opcode), .p0_a_param(ns_x0_y0_1_s_param),
        .p0_a_size(ns_x0_y0_1_s_size), .p0_a_source(ns_x0_y0_1_s_source),
        .p0_a_addr(ns_x0_y0_1_s_addr), .p0_a_mask(ns_x0_y0_1_s_mask),
        .p0_a_data(ns_x0_y0_1_s_data), .p0_a_valid(ns_x0_y0_1_s_valid), .p0_a_ready(),
        .p0_ao_opcode(ns_x0_y0_1_n_opcode), .p0_ao_param(ns_x0_y0_1_n_param),
        .p0_ao_size(ns_x0_y0_1_n_size), .p0_ao_source(ns_x0_y0_1_n_source),
        .p0_ao_addr(ns_x0_y0_1_n_addr), .p0_ao_mask(ns_x0_y0_1_n_mask),
        .p0_ao_data(ns_x0_y0_1_n_data), .p0_ao_valid(ns_x0_y0_1_n_valid),
        .p0_d_opcode(), .p0_d_param(), .p0_d_size(), .p0_d_source(), .p0_d_data(), .p0_d_valid(), .p0_d_ready(1'b1),
        .p1_a_opcode(3'h0), .p1_a_param(3'h0),
        .p1_a_size(3'h0), .p1_a_source(4'h0),
        .p1_a_addr(32'h0), .p1_a_mask(8'h0),
        .p1_a_data(64'h0), .p1_a_valid(1'b0), .p1_a_ready(),
        .p1_ao_opcode(), .p1_ao_param(),
        .p1_ao_size(), .p1_ao_source(),
        .p1_ao_addr(), .p1_ao_mask(),
        .p1_ao_data(), .p1_ao_valid(),
        .p1_d_opcode(), .p1_d_param(), .p1_d_size(), .p1_d_source(), .p1_d_data(), .p1_d_valid(), .p1_d_ready(1'b1),
        .p2_a_opcode(ew_y0_x0_1_w_opcode), .p2_a_param(ew_y0_x0_1_w_param),
        .p2_a_size(ew_y0_x0_1_w_size), .p2_a_source(ew_y0_x0_1_w_source),
        .p2_a_addr(ew_y0_x0_1_w_addr), .p2_a_mask(ew_y0_x0_1_w_mask),
        .p2_a_data(ew_y0_x0_1_w_data), .p2_a_valid(ew_y0_x0_1_w_valid), .p2_a_ready(),
        .p2_ao_opcode(ew_y0_x0_1_e_opcode), .p2_ao_param(ew_y0_x0_1_e_param),
        .p2_ao_size(ew_y0_x0_1_e_size), .p2_ao_source(ew_y0_x0_1_e_source),
        .p2_ao_addr(ew_y0_x0_1_e_addr), .p2_ao_mask(ew_y0_x0_1_e_mask),
        .p2_ao_data(ew_y0_x0_1_e_data), .p2_ao_valid(ew_y0_x0_1_e_valid),
        .p2_d_opcode(), .p2_d_param(), .p2_d_size(), .p2_d_source(), .p2_d_data(), .p2_d_valid(), .p2_d_ready(1'b1),
        .p3_a_opcode(3'h0), .p3_a_param(3'h0),
        .p3_a_size(3'h0), .p3_a_source(4'h0),
        .p3_a_addr(32'h0), .p3_a_mask(8'h0),
        .p3_a_data(64'h0), .p3_a_valid(1'b0), .p3_a_ready(),
        .p3_ao_opcode(), .p3_ao_param(),
        .p3_ao_size(), .p3_ao_source(),
        .p3_ao_addr(), .p3_ao_mask(),
        .p3_ao_data(), .p3_ao_valid(),
        .p3_d_opcode(), .p3_d_param(), .p3_d_size(), .p3_d_source(), .p3_d_data(), .p3_d_valid(), .p3_d_ready(1'b1),
        .inj_a_opcode(ni00_tl_a_opcode), .inj_a_param(ni00_tl_a_param),
        .inj_a_size(ni00_tl_a_size), .inj_a_source(ni00_tl_a_source),
        .inj_a_addr(ni00_tl_a_addr), .inj_a_mask(ni00_tl_a_mask),
        .inj_a_data(ni00_tl_a_data), .inj_a_valid(ni00_tl_a_valid), .inj_a_ready(ni00_tl_a_ready),
        .axi_awaddr(r00_awaddr), .axi_awvalid(r00_awvalid), .axi_awready(r00_awready),
        .axi_wdata(r00_wdata), .axi_wstrb(r00_wstrb), .axi_wvalid(r00_wvalid), .axi_wready(r00_wready),
        .axi_bresp(r00_bresp), .axi_bvalid(r00_bvalid), .axi_bready(r00_bready),
        .axi_araddr(r00_araddr), .axi_arvalid(r00_arvalid), .axi_arready(r00_arready),
        .axi_rdata(r00_rdata), .axi_rresp(r00_rresp), .axi_rvalid(r00_rvalid), .axi_rready(r00_rready),
        .d_opcode(r00_d_opcode), .d_param(r00_d_param), .d_size(r00_d_size), .d_source(r00_d_source),
        .d_data(r00_d_data), .d_valid(r00_d_valid), .d_ready(1'b1)
    );
    sram_00 u_sram_00 (
        .aclk(clk), .aresetn(sys_rst_n),
        .awaddr(r00_awaddr), .awvalid(r00_awvalid), .awready(r00_awready),
        .wdata(r00_wdata), .wstrb(r00_wstrb), .wvalid(r00_wvalid), .wready(r00_wready),
        .bresp(r00_bresp), .bvalid(r00_bvalid), .bready(r00_bready),
        .araddr(r00_araddr), .arvalid(r00_arvalid), .arready(r00_arready),
        .rdata(r00_rdata), .rresp(r00_rresp), .rvalid(r00_rvalid), .rready(r00_rready)
    );

    // --- Node (0,1) ---
    ni_01 u_ni_01 (
        .clk(clk), .rst_n(sys_rst_n),
        .axi_awaddr(32'h0), .axi_awvalid(1'b0), .axi_awready(),
        .axi_wdata(64'h0), .axi_wstrb(8'h0), .axi_wvalid(1'b0), .axi_wready(),
        .axi_bresp(), .axi_bvalid(), .axi_bready(1'b0),
        .axi_araddr(32'h0), .axi_arvalid(1'b0), .axi_arready(),
        .axi_rdata(), .axi_rresp(), .axi_rvalid(), .axi_rready(1'b0),
        .tl_a_opcode(ni01_tl_a_opcode), .tl_a_param(ni01_tl_a_param),
        .tl_a_size(ni01_tl_a_size), .tl_a_source(ni01_tl_a_source),
        .tl_a_addr(ni01_tl_a_addr), .tl_a_mask(ni01_tl_a_mask),
        .tl_a_data(ni01_tl_a_data), .tl_a_valid(ni01_tl_a_valid), .tl_a_ready(ni01_tl_a_ready),
        .tl_d_opcode(r01_d_opcode), .tl_d_param(r01_d_param),
        .tl_d_size(r01_d_size), .tl_d_source(r01_d_source),
        .tl_d_data(r01_d_data), .tl_d_valid(r01_d_valid), .tl_d_ready(r01_d_ready)
    );
    router_01 u_router_01 (
        .clk(clk), .rst_n(sys_rst_n),
        .p0_a_opcode(ns_x0_y1_2_s_opcode), .p0_a_param(ns_x0_y1_2_s_param),
        .p0_a_size(ns_x0_y1_2_s_size), .p0_a_source(ns_x0_y1_2_s_source),
        .p0_a_addr(ns_x0_y1_2_s_addr), .p0_a_mask(ns_x0_y1_2_s_mask),
        .p0_a_data(ns_x0_y1_2_s_data), .p0_a_valid(ns_x0_y1_2_s_valid), .p0_a_ready(),
        .p0_ao_opcode(ns_x0_y1_2_n_opcode), .p0_ao_param(ns_x0_y1_2_n_param),
        .p0_ao_size(ns_x0_y1_2_n_size), .p0_ao_source(ns_x0_y1_2_n_source),
        .p0_ao_addr(ns_x0_y1_2_n_addr), .p0_ao_mask(ns_x0_y1_2_n_mask),
        .p0_ao_data(ns_x0_y1_2_n_data), .p0_ao_valid(ns_x0_y1_2_n_valid),
        .p0_d_opcode(), .p0_d_param(), .p0_d_size(), .p0_d_source(), .p0_d_data(), .p0_d_valid(), .p0_d_ready(1'b1),
        .p1_a_opcode(ns_x0_y0_1_n_opcode), .p1_a_param(ns_x0_y0_1_n_param),
        .p1_a_size(ns_x0_y0_1_n_size), .p1_a_source(ns_x0_y0_1_n_source),
        .p1_a_addr(ns_x0_y0_1_n_addr), .p1_a_mask(ns_x0_y0_1_n_mask),
        .p1_a_data(ns_x0_y0_1_n_data), .p1_a_valid(ns_x0_y0_1_n_valid), .p1_a_ready(),
        .p1_ao_opcode(ns_x0_y0_1_s_opcode), .p1_ao_param(ns_x0_y0_1_s_param),
        .p1_ao_size(ns_x0_y0_1_s_size), .p1_ao_source(ns_x0_y0_1_s_source),
        .p1_ao_addr(ns_x0_y0_1_s_addr), .p1_ao_mask(ns_x0_y0_1_s_mask),
        .p1_ao_data(ns_x0_y0_1_s_data), .p1_ao_valid(ns_x0_y0_1_s_valid),
        .p1_d_opcode(), .p1_d_param(), .p1_d_size(), .p1_d_source(), .p1_d_data(), .p1_d_valid(), .p1_d_ready(1'b1),
        .p2_a_opcode(ew_y1_x0_1_w_opcode), .p2_a_param(ew_y1_x0_1_w_param),
        .p2_a_size(ew_y1_x0_1_w_size), .p2_a_source(ew_y1_x0_1_w_source),
        .p2_a_addr(ew_y1_x0_1_w_addr), .p2_a_mask(ew_y1_x0_1_w_mask),
        .p2_a_data(ew_y1_x0_1_w_data), .p2_a_valid(ew_y1_x0_1_w_valid), .p2_a_ready(),
        .p2_ao_opcode(ew_y1_x0_1_e_opcode), .p2_ao_param(ew_y1_x0_1_e_param),
        .p2_ao_size(ew_y1_x0_1_e_size), .p2_ao_source(ew_y1_x0_1_e_source),
        .p2_ao_addr(ew_y1_x0_1_e_addr), .p2_ao_mask(ew_y1_x0_1_e_mask),
        .p2_ao_data(ew_y1_x0_1_e_data), .p2_ao_valid(ew_y1_x0_1_e_valid),
        .p2_d_opcode(), .p2_d_param(), .p2_d_size(), .p2_d_source(), .p2_d_data(), .p2_d_valid(), .p2_d_ready(1'b1),
        .p3_a_opcode(3'h0), .p3_a_param(3'h0),
        .p3_a_size(3'h0), .p3_a_source(4'h0),
        .p3_a_addr(32'h0), .p3_a_mask(8'h0),
        .p3_a_data(64'h0), .p3_a_valid(1'b0), .p3_a_ready(),
        .p3_ao_opcode(), .p3_ao_param(),
        .p3_ao_size(), .p3_ao_source(),
        .p3_ao_addr(), .p3_ao_mask(),
        .p3_ao_data(), .p3_ao_valid(),
        .p3_d_opcode(), .p3_d_param(), .p3_d_size(), .p3_d_source(), .p3_d_data(), .p3_d_valid(), .p3_d_ready(1'b1),
        .inj_a_opcode(ni01_tl_a_opcode), .inj_a_param(ni01_tl_a_param),
        .inj_a_size(ni01_tl_a_size), .inj_a_source(ni01_tl_a_source),
        .inj_a_addr(ni01_tl_a_addr), .inj_a_mask(ni01_tl_a_mask),
        .inj_a_data(ni01_tl_a_data), .inj_a_valid(ni01_tl_a_valid), .inj_a_ready(ni01_tl_a_ready),
        .axi_awaddr(r01_awaddr), .axi_awvalid(r01_awvalid), .axi_awready(r01_awready),
        .axi_wdata(r01_wdata), .axi_wstrb(r01_wstrb), .axi_wvalid(r01_wvalid), .axi_wready(r01_wready),
        .axi_bresp(r01_bresp), .axi_bvalid(r01_bvalid), .axi_bready(r01_bready),
        .axi_araddr(r01_araddr), .axi_arvalid(r01_arvalid), .axi_arready(r01_arready),
        .axi_rdata(r01_rdata), .axi_rresp(r01_rresp), .axi_rvalid(r01_rvalid), .axi_rready(r01_rready),
        .d_opcode(r01_d_opcode), .d_param(r01_d_param), .d_size(r01_d_size), .d_source(r01_d_source),
        .d_data(r01_d_data), .d_valid(r01_d_valid), .d_ready(1'b1)
    );
    sram_01 u_sram_01 (
        .aclk(clk), .aresetn(sys_rst_n),
        .awaddr(r01_awaddr), .awvalid(r01_awvalid), .awready(r01_awready),
        .wdata(r01_wdata), .wstrb(r01_wstrb), .wvalid(r01_wvalid), .wready(r01_wready),
        .bresp(r01_bresp), .bvalid(r01_bvalid), .bready(r01_bready),
        .araddr(r01_araddr), .arvalid(r01_arvalid), .arready(r01_arready),
        .rdata(r01_rdata), .rresp(r01_rresp), .rvalid(r01_rvalid), .rready(r01_rready)
    );

    // --- Node (0,2) ---
    ni_02 u_ni_02 (
        .clk(clk), .rst_n(sys_rst_n),
        .axi_awaddr(32'h0), .axi_awvalid(1'b0), .axi_awready(),
        .axi_wdata(64'h0), .axi_wstrb(8'h0), .axi_wvalid(1'b0), .axi_wready(),
        .axi_bresp(), .axi_bvalid(), .axi_bready(1'b0),
        .axi_araddr(32'h0), .axi_arvalid(1'b0), .axi_arready(),
        .axi_rdata(), .axi_rresp(), .axi_rvalid(), .axi_rready(1'b0),
        .tl_a_opcode(ni02_tl_a_opcode), .tl_a_param(ni02_tl_a_param),
        .tl_a_size(ni02_tl_a_size), .tl_a_source(ni02_tl_a_source),
        .tl_a_addr(ni02_tl_a_addr), .tl_a_mask(ni02_tl_a_mask),
        .tl_a_data(ni02_tl_a_data), .tl_a_valid(ni02_tl_a_valid), .tl_a_ready(ni02_tl_a_ready),
        .tl_d_opcode(r02_d_opcode), .tl_d_param(r02_d_param),
        .tl_d_size(r02_d_size), .tl_d_source(r02_d_source),
        .tl_d_data(r02_d_data), .tl_d_valid(r02_d_valid), .tl_d_ready(r02_d_ready)
    );
    router_02 u_router_02 (
        .clk(clk), .rst_n(sys_rst_n),
        .p0_a_opcode(3'h0), .p0_a_param(3'h0),
        .p0_a_size(3'h0), .p0_a_source(4'h0),
        .p0_a_addr(tie3), .p0_a_mask(tie3),
        .p0_a_data(tie3), .p0_a_valid(1'b0), .p0_a_ready(),
        .p0_ao_opcode(), .p0_ao_param(),
        .p0_ao_size(), .p0_ao_source(),
        .p0_ao_addr(), .p0_ao_mask(),
        .p0_ao_data(), .p0_ao_valid(),
        .p0_d_opcode(), .p0_d_param(), .p0_d_size(), .p0_d_source(), .p0_d_data(), .p0_d_valid(), .p0_d_ready(1'b1),
        .p1_a_opcode(ns_x0_y1_2_n_opcode), .p1_a_param(ns_x0_y1_2_n_param),
        .p1_a_size(ns_x0_y1_2_n_size), .p1_a_source(ns_x0_y1_2_n_source),
        .p1_a_addr(ns_x0_y1_2_n_addr), .p1_a_mask(ns_x0_y1_2_n_mask),
        .p1_a_data(ns_x0_y1_2_n_data), .p1_a_valid(ns_x0_y1_2_n_valid), .p1_a_ready(),
        .p1_ao_opcode(ns_x0_y1_2_s_opcode), .p1_ao_param(ns_x0_y1_2_s_param),
        .p1_ao_size(ns_x0_y1_2_s_size), .p1_ao_source(ns_x0_y1_2_s_source),
        .p1_ao_addr(ns_x0_y1_2_s_addr), .p1_ao_mask(ns_x0_y1_2_s_mask),
        .p1_ao_data(ns_x0_y1_2_s_data), .p1_ao_valid(ns_x0_y1_2_s_valid),
        .p1_d_opcode(), .p1_d_param(), .p1_d_size(), .p1_d_source(), .p1_d_data(), .p1_d_valid(), .p1_d_ready(1'b1),
        .p2_a_opcode(ew_y2_x0_1_w_opcode), .p2_a_param(ew_y2_x0_1_w_param),
        .p2_a_size(ew_y2_x0_1_w_size), .p2_a_source(ew_y2_x0_1_w_source),
        .p2_a_addr(ew_y2_x0_1_w_addr), .p2_a_mask(ew_y2_x0_1_w_mask),
        .p2_a_data(ew_y2_x0_1_w_data), .p2_a_valid(ew_y2_x0_1_w_valid), .p2_a_ready(),
        .p2_ao_opcode(ew_y2_x0_1_e_opcode), .p2_ao_param(ew_y2_x0_1_e_param),
        .p2_ao_size(ew_y2_x0_1_e_size), .p2_ao_source(ew_y2_x0_1_e_source),
        .p2_ao_addr(ew_y2_x0_1_e_addr), .p2_ao_mask(ew_y2_x0_1_e_mask),
        .p2_ao_data(ew_y2_x0_1_e_data), .p2_ao_valid(ew_y2_x0_1_e_valid),
        .p2_d_opcode(), .p2_d_param(), .p2_d_size(), .p2_d_source(), .p2_d_data(), .p2_d_valid(), .p2_d_ready(1'b1),
        .p3_a_opcode(3'h0), .p3_a_param(3'h0),
        .p3_a_size(3'h0), .p3_a_source(4'h0),
        .p3_a_addr(32'h0), .p3_a_mask(8'h0),
        .p3_a_data(64'h0), .p3_a_valid(1'b0), .p3_a_ready(),
        .p3_ao_opcode(), .p3_ao_param(),
        .p3_ao_size(), .p3_ao_source(),
        .p3_ao_addr(), .p3_ao_mask(),
        .p3_ao_data(), .p3_ao_valid(),
        .p3_d_opcode(), .p3_d_param(), .p3_d_size(), .p3_d_source(), .p3_d_data(), .p3_d_valid(), .p3_d_ready(1'b1),
        .inj_a_opcode(ni02_tl_a_opcode), .inj_a_param(ni02_tl_a_param),
        .inj_a_size(ni02_tl_a_size), .inj_a_source(ni02_tl_a_source),
        .inj_a_addr(ni02_tl_a_addr), .inj_a_mask(ni02_tl_a_mask),
        .inj_a_data(ni02_tl_a_data), .inj_a_valid(ni02_tl_a_valid), .inj_a_ready(ni02_tl_a_ready),
        .axi_awaddr(r02_awaddr), .axi_awvalid(r02_awvalid), .axi_awready(r02_awready),
        .axi_wdata(r02_wdata), .axi_wstrb(r02_wstrb), .axi_wvalid(r02_wvalid), .axi_wready(r02_wready),
        .axi_bresp(r02_bresp), .axi_bvalid(r02_bvalid), .axi_bready(r02_bready),
        .axi_araddr(r02_araddr), .axi_arvalid(r02_arvalid), .axi_arready(r02_arready),
        .axi_rdata(r02_rdata), .axi_rresp(r02_rresp), .axi_rvalid(r02_rvalid), .axi_rready(r02_rready),
        .d_opcode(r02_d_opcode), .d_param(r02_d_param), .d_size(r02_d_size), .d_source(r02_d_source),
        .d_data(r02_d_data), .d_valid(r02_d_valid), .d_ready(1'b1)
    );
    sram_02 u_sram_02 (
        .aclk(clk), .aresetn(sys_rst_n),
        .awaddr(r02_awaddr), .awvalid(r02_awvalid), .awready(r02_awready),
        .wdata(r02_wdata), .wstrb(r02_wstrb), .wvalid(r02_wvalid), .wready(r02_wready),
        .bresp(r02_bresp), .bvalid(r02_bvalid), .bready(r02_bready),
        .araddr(r02_araddr), .arvalid(r02_arvalid), .arready(r02_arready),
        .rdata(r02_rdata), .rresp(r02_rresp), .rvalid(r02_rvalid), .rready(r02_rready)
    );

    // --- Node (1,0) ---
    ni_10 u_ni_10 (
        .clk(clk), .rst_n(sys_rst_n),
        .axi_awaddr(32'h0), .axi_awvalid(1'b0), .axi_awready(),
        .axi_wdata(64'h0), .axi_wstrb(8'h0), .axi_wvalid(1'b0), .axi_wready(),
        .axi_bresp(), .axi_bvalid(), .axi_bready(1'b0),
        .axi_araddr(32'h0), .axi_arvalid(1'b0), .axi_arready(),
        .axi_rdata(), .axi_rresp(), .axi_rvalid(), .axi_rready(1'b0),
        .tl_a_opcode(ni10_tl_a_opcode), .tl_a_param(ni10_tl_a_param),
        .tl_a_size(ni10_tl_a_size), .tl_a_source(ni10_tl_a_source),
        .tl_a_addr(ni10_tl_a_addr), .tl_a_mask(ni10_tl_a_mask),
        .tl_a_data(ni10_tl_a_data), .tl_a_valid(ni10_tl_a_valid), .tl_a_ready(ni10_tl_a_ready),
        .tl_d_opcode(r10_d_opcode), .tl_d_param(r10_d_param),
        .tl_d_size(r10_d_size), .tl_d_source(r10_d_source),
        .tl_d_data(r10_d_data), .tl_d_valid(r10_d_valid), .tl_d_ready(r10_d_ready)
    );
    router_10 u_router_10 (
        .clk(clk), .rst_n(sys_rst_n),
        .p0_a_opcode(ns_x1_y0_1_s_opcode), .p0_a_param(ns_x1_y0_1_s_param),
        .p0_a_size(ns_x1_y0_1_s_size), .p0_a_source(ns_x1_y0_1_s_source),
        .p0_a_addr(ns_x1_y0_1_s_addr), .p0_a_mask(ns_x1_y0_1_s_mask),
        .p0_a_data(ns_x1_y0_1_s_data), .p0_a_valid(ns_x1_y0_1_s_valid), .p0_a_ready(),
        .p0_ao_opcode(ns_x1_y0_1_n_opcode), .p0_ao_param(ns_x1_y0_1_n_param),
        .p0_ao_size(ns_x1_y0_1_n_size), .p0_ao_source(ns_x1_y0_1_n_source),
        .p0_ao_addr(ns_x1_y0_1_n_addr), .p0_ao_mask(ns_x1_y0_1_n_mask),
        .p0_ao_data(ns_x1_y0_1_n_data), .p0_ao_valid(ns_x1_y0_1_n_valid),
        .p0_d_opcode(), .p0_d_param(), .p0_d_size(), .p0_d_source(), .p0_d_data(), .p0_d_valid(), .p0_d_ready(1'b1),
        .p1_a_opcode(3'h0), .p1_a_param(3'h0),
        .p1_a_size(3'h0), .p1_a_source(4'h0),
        .p1_a_addr(32'h0), .p1_a_mask(8'h0),
        .p1_a_data(64'h0), .p1_a_valid(1'b0), .p1_a_ready(),
        .p1_ao_opcode(), .p1_ao_param(),
        .p1_ao_size(), .p1_ao_source(),
        .p1_ao_addr(), .p1_ao_mask(),
        .p1_ao_data(), .p1_ao_valid(),
        .p1_d_opcode(), .p1_d_param(), .p1_d_size(), .p1_d_source(), .p1_d_data(), .p1_d_valid(), .p1_d_ready(1'b1),
        .p2_a_opcode(ew_y0_x1_2_w_opcode), .p2_a_param(ew_y0_x1_2_w_param),
        .p2_a_size(ew_y0_x1_2_w_size), .p2_a_source(ew_y0_x1_2_w_source),
        .p2_a_addr(ew_y0_x1_2_w_addr), .p2_a_mask(ew_y0_x1_2_w_mask),
        .p2_a_data(ew_y0_x1_2_w_data), .p2_a_valid(ew_y0_x1_2_w_valid), .p2_a_ready(),
        .p2_ao_opcode(ew_y0_x1_2_e_opcode), .p2_ao_param(ew_y0_x1_2_e_param),
        .p2_ao_size(ew_y0_x1_2_e_size), .p2_ao_source(ew_y0_x1_2_e_source),
        .p2_ao_addr(ew_y0_x1_2_e_addr), .p2_ao_mask(ew_y0_x1_2_e_mask),
        .p2_ao_data(ew_y0_x1_2_e_data), .p2_ao_valid(ew_y0_x1_2_e_valid),
        .p2_d_opcode(), .p2_d_param(), .p2_d_size(), .p2_d_source(), .p2_d_data(), .p2_d_valid(), .p2_d_ready(1'b1),
        .p3_a_opcode(ew_y0_x0_1_e_opcode), .p3_a_param(ew_y0_x0_1_e_param),
        .p3_a_size(ew_y0_x0_1_e_size), .p3_a_source(ew_y0_x0_1_e_source),
        .p3_a_addr(ew_y0_x0_1_e_addr), .p3_a_mask(ew_y0_x0_1_e_mask),
        .p3_a_data(ew_y0_x0_1_e_data), .p3_a_valid(ew_y0_x0_1_e_valid), .p3_a_ready(),
        .p3_ao_opcode(ew_y0_x0_1_w_opcode), .p3_ao_param(ew_y0_x0_1_w_param),
        .p3_ao_size(ew_y0_x0_1_w_size), .p3_ao_source(ew_y0_x0_1_w_source),
        .p3_ao_addr(ew_y0_x0_1_w_addr), .p3_ao_mask(ew_y0_x0_1_w_mask),
        .p3_ao_data(ew_y0_x0_1_w_data), .p3_ao_valid(ew_y0_x0_1_w_valid),
        .p3_d_opcode(), .p3_d_param(), .p3_d_size(), .p3_d_source(), .p3_d_data(), .p3_d_valid(), .p3_d_ready(1'b1),
        .inj_a_opcode(ni10_tl_a_opcode), .inj_a_param(ni10_tl_a_param),
        .inj_a_size(ni10_tl_a_size), .inj_a_source(ni10_tl_a_source),
        .inj_a_addr(ni10_tl_a_addr), .inj_a_mask(ni10_tl_a_mask),
        .inj_a_data(ni10_tl_a_data), .inj_a_valid(ni10_tl_a_valid), .inj_a_ready(ni10_tl_a_ready),
        .axi_awaddr(r10_awaddr), .axi_awvalid(r10_awvalid), .axi_awready(r10_awready),
        .axi_wdata(r10_wdata), .axi_wstrb(r10_wstrb), .axi_wvalid(r10_wvalid), .axi_wready(r10_wready),
        .axi_bresp(r10_bresp), .axi_bvalid(r10_bvalid), .axi_bready(r10_bready),
        .axi_araddr(r10_araddr), .axi_arvalid(r10_arvalid), .axi_arready(r10_arready),
        .axi_rdata(r10_rdata), .axi_rresp(r10_rresp), .axi_rvalid(r10_rvalid), .axi_rready(r10_rready),
        .d_opcode(r10_d_opcode), .d_param(r10_d_param), .d_size(r10_d_size), .d_source(r10_d_source),
        .d_data(r10_d_data), .d_valid(r10_d_valid), .d_ready(1'b1)
    );
    sram_10 u_sram_10 (
        .aclk(clk), .aresetn(sys_rst_n),
        .awaddr(r10_awaddr), .awvalid(r10_awvalid), .awready(r10_awready),
        .wdata(r10_wdata), .wstrb(r10_wstrb), .wvalid(r10_wvalid), .wready(r10_wready),
        .bresp(r10_bresp), .bvalid(r10_bvalid), .bready(r10_bready),
        .araddr(r10_araddr), .arvalid(r10_arvalid), .arready(r10_arready),
        .rdata(r10_rdata), .rresp(r10_rresp), .rvalid(r10_rvalid), .rready(r10_rready)
    );

    // --- Node (1,1) ---
    ni_11 u_ni_11 (
        .clk(clk), .rst_n(sys_rst_n),
        .axi_awaddr(32'h0), .axi_awvalid(1'b0), .axi_awready(),
        .axi_wdata(64'h0), .axi_wstrb(8'h0), .axi_wvalid(1'b0), .axi_wready(),
        .axi_bresp(), .axi_bvalid(), .axi_bready(1'b0),
        .axi_araddr(32'h0), .axi_arvalid(1'b0), .axi_arready(),
        .axi_rdata(), .axi_rresp(), .axi_rvalid(), .axi_rready(1'b0),
        .tl_a_opcode(ni11_tl_a_opcode), .tl_a_param(ni11_tl_a_param),
        .tl_a_size(ni11_tl_a_size), .tl_a_source(ni11_tl_a_source),
        .tl_a_addr(ni11_tl_a_addr), .tl_a_mask(ni11_tl_a_mask),
        .tl_a_data(ni11_tl_a_data), .tl_a_valid(ni11_tl_a_valid), .tl_a_ready(ni11_tl_a_ready),
        .tl_d_opcode(r11_d_opcode), .tl_d_param(r11_d_param),
        .tl_d_size(r11_d_size), .tl_d_source(r11_d_source),
        .tl_d_data(r11_d_data), .tl_d_valid(r11_d_valid), .tl_d_ready(r11_d_ready)
    );
    router_11 u_router_11 (
        .clk(clk), .rst_n(sys_rst_n),
        .p0_a_opcode(ns_x1_y1_2_s_opcode), .p0_a_param(ns_x1_y1_2_s_param),
        .p0_a_size(ns_x1_y1_2_s_size), .p0_a_source(ns_x1_y1_2_s_source),
        .p0_a_addr(ns_x1_y1_2_s_addr), .p0_a_mask(ns_x1_y1_2_s_mask),
        .p0_a_data(ns_x1_y1_2_s_data), .p0_a_valid(ns_x1_y1_2_s_valid), .p0_a_ready(),
        .p0_ao_opcode(ns_x1_y1_2_n_opcode), .p0_ao_param(ns_x1_y1_2_n_param),
        .p0_ao_size(ns_x1_y1_2_n_size), .p0_ao_source(ns_x1_y1_2_n_source),
        .p0_ao_addr(ns_x1_y1_2_n_addr), .p0_ao_mask(ns_x1_y1_2_n_mask),
        .p0_ao_data(ns_x1_y1_2_n_data), .p0_ao_valid(ns_x1_y1_2_n_valid),
        .p0_d_opcode(), .p0_d_param(), .p0_d_size(), .p0_d_source(), .p0_d_data(), .p0_d_valid(), .p0_d_ready(1'b1),
        .p1_a_opcode(ns_x1_y0_1_n_opcode), .p1_a_param(ns_x1_y0_1_n_param),
        .p1_a_size(ns_x1_y0_1_n_size), .p1_a_source(ns_x1_y0_1_n_source),
        .p1_a_addr(ns_x1_y0_1_n_addr), .p1_a_mask(ns_x1_y0_1_n_mask),
        .p1_a_data(ns_x1_y0_1_n_data), .p1_a_valid(ns_x1_y0_1_n_valid), .p1_a_ready(),
        .p1_ao_opcode(ns_x1_y0_1_s_opcode), .p1_ao_param(ns_x1_y0_1_s_param),
        .p1_ao_size(ns_x1_y0_1_s_size), .p1_ao_source(ns_x1_y0_1_s_source),
        .p1_ao_addr(ns_x1_y0_1_s_addr), .p1_ao_mask(ns_x1_y0_1_s_mask),
        .p1_ao_data(ns_x1_y0_1_s_data), .p1_ao_valid(ns_x1_y0_1_s_valid),
        .p1_d_opcode(), .p1_d_param(), .p1_d_size(), .p1_d_source(), .p1_d_data(), .p1_d_valid(), .p1_d_ready(1'b1),
        .p2_a_opcode(ew_y1_x1_2_w_opcode), .p2_a_param(ew_y1_x1_2_w_param),
        .p2_a_size(ew_y1_x1_2_w_size), .p2_a_source(ew_y1_x1_2_w_source),
        .p2_a_addr(ew_y1_x1_2_w_addr), .p2_a_mask(ew_y1_x1_2_w_mask),
        .p2_a_data(ew_y1_x1_2_w_data), .p2_a_valid(ew_y1_x1_2_w_valid), .p2_a_ready(),
        .p2_ao_opcode(ew_y1_x1_2_e_opcode), .p2_ao_param(ew_y1_x1_2_e_param),
        .p2_ao_size(ew_y1_x1_2_e_size), .p2_ao_source(ew_y1_x1_2_e_source),
        .p2_ao_addr(ew_y1_x1_2_e_addr), .p2_ao_mask(ew_y1_x1_2_e_mask),
        .p2_ao_data(ew_y1_x1_2_e_data), .p2_ao_valid(ew_y1_x1_2_e_valid),
        .p2_d_opcode(), .p2_d_param(), .p2_d_size(), .p2_d_source(), .p2_d_data(), .p2_d_valid(), .p2_d_ready(1'b1),
        .p3_a_opcode(ew_y1_x0_1_e_opcode), .p3_a_param(ew_y1_x0_1_e_param),
        .p3_a_size(ew_y1_x0_1_e_size), .p3_a_source(ew_y1_x0_1_e_source),
        .p3_a_addr(ew_y1_x0_1_e_addr), .p3_a_mask(ew_y1_x0_1_e_mask),
        .p3_a_data(ew_y1_x0_1_e_data), .p3_a_valid(ew_y1_x0_1_e_valid), .p3_a_ready(),
        .p3_ao_opcode(ew_y1_x0_1_w_opcode), .p3_ao_param(ew_y1_x0_1_w_param),
        .p3_ao_size(ew_y1_x0_1_w_size), .p3_ao_source(ew_y1_x0_1_w_source),
        .p3_ao_addr(ew_y1_x0_1_w_addr), .p3_ao_mask(ew_y1_x0_1_w_mask),
        .p3_ao_data(ew_y1_x0_1_w_data), .p3_ao_valid(ew_y1_x0_1_w_valid),
        .p3_d_opcode(), .p3_d_param(), .p3_d_size(), .p3_d_source(), .p3_d_data(), .p3_d_valid(), .p3_d_ready(1'b1),
        .inj_a_opcode(ni11_tl_a_opcode), .inj_a_param(ni11_tl_a_param),
        .inj_a_size(ni11_tl_a_size), .inj_a_source(ni11_tl_a_source),
        .inj_a_addr(ni11_tl_a_addr), .inj_a_mask(ni11_tl_a_mask),
        .inj_a_data(ni11_tl_a_data), .inj_a_valid(ni11_tl_a_valid), .inj_a_ready(ni11_tl_a_ready),
        .axi_awaddr(r11_awaddr), .axi_awvalid(r11_awvalid), .axi_awready(r11_awready),
        .axi_wdata(r11_wdata), .axi_wstrb(r11_wstrb), .axi_wvalid(r11_wvalid), .axi_wready(r11_wready),
        .axi_bresp(r11_bresp), .axi_bvalid(r11_bvalid), .axi_bready(r11_bready),
        .axi_araddr(r11_araddr), .axi_arvalid(r11_arvalid), .axi_arready(r11_arready),
        .axi_rdata(r11_rdata), .axi_rresp(r11_rresp), .axi_rvalid(r11_rvalid), .axi_rready(r11_rready),
        .d_opcode(r11_d_opcode), .d_param(r11_d_param), .d_size(r11_d_size), .d_source(r11_d_source),
        .d_data(r11_d_data), .d_valid(r11_d_valid), .d_ready(1'b1)
    );
    sram_11 u_sram_11 (
        .aclk(clk), .aresetn(sys_rst_n),
        .awaddr(r11_awaddr), .awvalid(r11_awvalid), .awready(r11_awready),
        .wdata(r11_wdata), .wstrb(r11_wstrb), .wvalid(r11_wvalid), .wready(r11_wready),
        .bresp(r11_bresp), .bvalid(r11_bvalid), .bready(r11_bready),
        .araddr(r11_araddr), .arvalid(r11_arvalid), .arready(r11_arready),
        .rdata(r11_rdata), .rresp(r11_rresp), .rvalid(r11_rvalid), .rready(r11_rready)
    );

    // --- Node (1,2) ---
    ni_12 u_ni_12 (
        .clk(clk), .rst_n(sys_rst_n),
        .axi_awaddr(32'h0), .axi_awvalid(1'b0), .axi_awready(),
        .axi_wdata(64'h0), .axi_wstrb(8'h0), .axi_wvalid(1'b0), .axi_wready(),
        .axi_bresp(), .axi_bvalid(), .axi_bready(1'b0),
        .axi_araddr(32'h0), .axi_arvalid(1'b0), .axi_arready(),
        .axi_rdata(), .axi_rresp(), .axi_rvalid(), .axi_rready(1'b0),
        .tl_a_opcode(ni12_tl_a_opcode), .tl_a_param(ni12_tl_a_param),
        .tl_a_size(ni12_tl_a_size), .tl_a_source(ni12_tl_a_source),
        .tl_a_addr(ni12_tl_a_addr), .tl_a_mask(ni12_tl_a_mask),
        .tl_a_data(ni12_tl_a_data), .tl_a_valid(ni12_tl_a_valid), .tl_a_ready(ni12_tl_a_ready),
        .tl_d_opcode(r12_d_opcode), .tl_d_param(r12_d_param),
        .tl_d_size(r12_d_size), .tl_d_source(r12_d_source),
        .tl_d_data(r12_d_data), .tl_d_valid(r12_d_valid), .tl_d_ready(r12_d_ready)
    );
    router_12 u_router_12 (
        .clk(clk), .rst_n(sys_rst_n),
        .p0_a_opcode(3'h0), .p0_a_param(3'h0),
        .p0_a_size(3'h0), .p0_a_source(4'h0),
        .p0_a_addr(tie3), .p0_a_mask(tie3),
        .p0_a_data(tie3), .p0_a_valid(1'b0), .p0_a_ready(),
        .p0_ao_opcode(), .p0_ao_param(),
        .p0_ao_size(), .p0_ao_source(),
        .p0_ao_addr(), .p0_ao_mask(),
        .p0_ao_data(), .p0_ao_valid(),
        .p0_d_opcode(), .p0_d_param(), .p0_d_size(), .p0_d_source(), .p0_d_data(), .p0_d_valid(), .p0_d_ready(1'b1),
        .p1_a_opcode(ns_x1_y1_2_n_opcode), .p1_a_param(ns_x1_y1_2_n_param),
        .p1_a_size(ns_x1_y1_2_n_size), .p1_a_source(ns_x1_y1_2_n_source),
        .p1_a_addr(ns_x1_y1_2_n_addr), .p1_a_mask(ns_x1_y1_2_n_mask),
        .p1_a_data(ns_x1_y1_2_n_data), .p1_a_valid(ns_x1_y1_2_n_valid), .p1_a_ready(),
        .p1_ao_opcode(ns_x1_y1_2_s_opcode), .p1_ao_param(ns_x1_y1_2_s_param),
        .p1_ao_size(ns_x1_y1_2_s_size), .p1_ao_source(ns_x1_y1_2_s_source),
        .p1_ao_addr(ns_x1_y1_2_s_addr), .p1_ao_mask(ns_x1_y1_2_s_mask),
        .p1_ao_data(ns_x1_y1_2_s_data), .p1_ao_valid(ns_x1_y1_2_s_valid),
        .p1_d_opcode(), .p1_d_param(), .p1_d_size(), .p1_d_source(), .p1_d_data(), .p1_d_valid(), .p1_d_ready(1'b1),
        .p2_a_opcode(ew_y2_x1_2_w_opcode), .p2_a_param(ew_y2_x1_2_w_param),
        .p2_a_size(ew_y2_x1_2_w_size), .p2_a_source(ew_y2_x1_2_w_source),
        .p2_a_addr(ew_y2_x1_2_w_addr), .p2_a_mask(ew_y2_x1_2_w_mask),
        .p2_a_data(ew_y2_x1_2_w_data), .p2_a_valid(ew_y2_x1_2_w_valid), .p2_a_ready(),
        .p2_ao_opcode(ew_y2_x1_2_e_opcode), .p2_ao_param(ew_y2_x1_2_e_param),
        .p2_ao_size(ew_y2_x1_2_e_size), .p2_ao_source(ew_y2_x1_2_e_source),
        .p2_ao_addr(ew_y2_x1_2_e_addr), .p2_ao_mask(ew_y2_x1_2_e_mask),
        .p2_ao_data(ew_y2_x1_2_e_data), .p2_ao_valid(ew_y2_x1_2_e_valid),
        .p2_d_opcode(), .p2_d_param(), .p2_d_size(), .p2_d_source(), .p2_d_data(), .p2_d_valid(), .p2_d_ready(1'b1),
        .p3_a_opcode(ew_y2_x0_1_e_opcode), .p3_a_param(ew_y2_x0_1_e_param),
        .p3_a_size(ew_y2_x0_1_e_size), .p3_a_source(ew_y2_x0_1_e_source),
        .p3_a_addr(ew_y2_x0_1_e_addr), .p3_a_mask(ew_y2_x0_1_e_mask),
        .p3_a_data(ew_y2_x0_1_e_data), .p3_a_valid(ew_y2_x0_1_e_valid), .p3_a_ready(),
        .p3_ao_opcode(ew_y2_x0_1_w_opcode), .p3_ao_param(ew_y2_x0_1_w_param),
        .p3_ao_size(ew_y2_x0_1_w_size), .p3_ao_source(ew_y2_x0_1_w_source),
        .p3_ao_addr(ew_y2_x0_1_w_addr), .p3_ao_mask(ew_y2_x0_1_w_mask),
        .p3_ao_data(ew_y2_x0_1_w_data), .p3_ao_valid(ew_y2_x0_1_w_valid),
        .p3_d_opcode(), .p3_d_param(), .p3_d_size(), .p3_d_source(), .p3_d_data(), .p3_d_valid(), .p3_d_ready(1'b1),
        .inj_a_opcode(ni12_tl_a_opcode), .inj_a_param(ni12_tl_a_param),
        .inj_a_size(ni12_tl_a_size), .inj_a_source(ni12_tl_a_source),
        .inj_a_addr(ni12_tl_a_addr), .inj_a_mask(ni12_tl_a_mask),
        .inj_a_data(ni12_tl_a_data), .inj_a_valid(ni12_tl_a_valid), .inj_a_ready(ni12_tl_a_ready),
        .axi_awaddr(r12_awaddr), .axi_awvalid(r12_awvalid), .axi_awready(r12_awready),
        .axi_wdata(r12_wdata), .axi_wstrb(r12_wstrb), .axi_wvalid(r12_wvalid), .axi_wready(r12_wready),
        .axi_bresp(r12_bresp), .axi_bvalid(r12_bvalid), .axi_bready(r12_bready),
        .axi_araddr(r12_araddr), .axi_arvalid(r12_arvalid), .axi_arready(r12_arready),
        .axi_rdata(r12_rdata), .axi_rresp(r12_rresp), .axi_rvalid(r12_rvalid), .axi_rready(r12_rready),
        .d_opcode(r12_d_opcode), .d_param(r12_d_param), .d_size(r12_d_size), .d_source(r12_d_source),
        .d_data(r12_d_data), .d_valid(r12_d_valid), .d_ready(1'b1)
    );
    sram_12 u_sram_12 (
        .aclk(clk), .aresetn(sys_rst_n),
        .awaddr(r12_awaddr), .awvalid(r12_awvalid), .awready(r12_awready),
        .wdata(r12_wdata), .wstrb(r12_wstrb), .wvalid(r12_wvalid), .wready(r12_wready),
        .bresp(r12_bresp), .bvalid(r12_bvalid), .bready(r12_bready),
        .araddr(r12_araddr), .arvalid(r12_arvalid), .arready(r12_arready),
        .rdata(r12_rdata), .rresp(r12_rresp), .rvalid(r12_rvalid), .rready(r12_rready)
    );

    // --- Node (2,0) ---
    ni_20 u_ni_20 (
        .clk(clk), .rst_n(sys_rst_n),
        .axi_awaddr(32'h0), .axi_awvalid(1'b0), .axi_awready(),
        .axi_wdata(64'h0), .axi_wstrb(8'h0), .axi_wvalid(1'b0), .axi_wready(),
        .axi_bresp(), .axi_bvalid(), .axi_bready(1'b0),
        .axi_araddr(32'h0), .axi_arvalid(1'b0), .axi_arready(),
        .axi_rdata(), .axi_rresp(), .axi_rvalid(), .axi_rready(1'b0),
        .tl_a_opcode(ni20_tl_a_opcode), .tl_a_param(ni20_tl_a_param),
        .tl_a_size(ni20_tl_a_size), .tl_a_source(ni20_tl_a_source),
        .tl_a_addr(ni20_tl_a_addr), .tl_a_mask(ni20_tl_a_mask),
        .tl_a_data(ni20_tl_a_data), .tl_a_valid(ni20_tl_a_valid), .tl_a_ready(ni20_tl_a_ready),
        .tl_d_opcode(r20_d_opcode), .tl_d_param(r20_d_param),
        .tl_d_size(r20_d_size), .tl_d_source(r20_d_source),
        .tl_d_data(r20_d_data), .tl_d_valid(r20_d_valid), .tl_d_ready(r20_d_ready)
    );
    router_20 u_router_20 (
        .clk(clk), .rst_n(sys_rst_n),
        .p0_a_opcode(ns_x2_y0_1_s_opcode), .p0_a_param(ns_x2_y0_1_s_param),
        .p0_a_size(ns_x2_y0_1_s_size), .p0_a_source(ns_x2_y0_1_s_source),
        .p0_a_addr(ns_x2_y0_1_s_addr), .p0_a_mask(ns_x2_y0_1_s_mask),
        .p0_a_data(ns_x2_y0_1_s_data), .p0_a_valid(ns_x2_y0_1_s_valid), .p0_a_ready(),
        .p0_ao_opcode(ns_x2_y0_1_n_opcode), .p0_ao_param(ns_x2_y0_1_n_param),
        .p0_ao_size(ns_x2_y0_1_n_size), .p0_ao_source(ns_x2_y0_1_n_source),
        .p0_ao_addr(ns_x2_y0_1_n_addr), .p0_ao_mask(ns_x2_y0_1_n_mask),
        .p0_ao_data(ns_x2_y0_1_n_data), .p0_ao_valid(ns_x2_y0_1_n_valid),
        .p0_d_opcode(), .p0_d_param(), .p0_d_size(), .p0_d_source(), .p0_d_data(), .p0_d_valid(), .p0_d_ready(1'b1),
        .p1_a_opcode(3'h0), .p1_a_param(3'h0),
        .p1_a_size(3'h0), .p1_a_source(4'h0),
        .p1_a_addr(32'h0), .p1_a_mask(8'h0),
        .p1_a_data(64'h0), .p1_a_valid(1'b0), .p1_a_ready(),
        .p1_ao_opcode(), .p1_ao_param(),
        .p1_ao_size(), .p1_ao_source(),
        .p1_ao_addr(), .p1_ao_mask(),
        .p1_ao_data(), .p1_ao_valid(),
        .p1_d_opcode(), .p1_d_param(), .p1_d_size(), .p1_d_source(), .p1_d_data(), .p1_d_valid(), .p1_d_ready(1'b1),
        .p2_a_opcode(ew_y0_x2_3_w_opcode), .p2_a_param(ew_y0_x2_3_w_param),
        .p2_a_size(ew_y0_x2_3_w_size), .p2_a_source(ew_y0_x2_3_w_source),
        .p2_a_addr(ew_y0_x2_3_w_addr), .p2_a_mask(ew_y0_x2_3_w_mask),
        .p2_a_data(ew_y0_x2_3_w_data), .p2_a_valid(ew_y0_x2_3_w_valid), .p2_a_ready(),
        .p2_ao_opcode(ew_y0_x2_3_e_opcode), .p2_ao_param(ew_y0_x2_3_e_param),
        .p2_ao_size(ew_y0_x2_3_e_size), .p2_ao_source(ew_y0_x2_3_e_source),
        .p2_ao_addr(ew_y0_x2_3_e_addr), .p2_ao_mask(ew_y0_x2_3_e_mask),
        .p2_ao_data(ew_y0_x2_3_e_data), .p2_ao_valid(ew_y0_x2_3_e_valid),
        .p2_d_opcode(), .p2_d_param(), .p2_d_size(), .p2_d_source(), .p2_d_data(), .p2_d_valid(), .p2_d_ready(1'b1),
        .p3_a_opcode(ew_y0_x1_2_e_opcode), .p3_a_param(ew_y0_x1_2_e_param),
        .p3_a_size(ew_y0_x1_2_e_size), .p3_a_source(ew_y0_x1_2_e_source),
        .p3_a_addr(ew_y0_x1_2_e_addr), .p3_a_mask(ew_y0_x1_2_e_mask),
        .p3_a_data(ew_y0_x1_2_e_data), .p3_a_valid(ew_y0_x1_2_e_valid), .p3_a_ready(),
        .p3_ao_opcode(ew_y0_x1_2_w_opcode), .p3_ao_param(ew_y0_x1_2_w_param),
        .p3_ao_size(ew_y0_x1_2_w_size), .p3_ao_source(ew_y0_x1_2_w_source),
        .p3_ao_addr(ew_y0_x1_2_w_addr), .p3_ao_mask(ew_y0_x1_2_w_mask),
        .p3_ao_data(ew_y0_x1_2_w_data), .p3_ao_valid(ew_y0_x1_2_w_valid),
        .p3_d_opcode(), .p3_d_param(), .p3_d_size(), .p3_d_source(), .p3_d_data(), .p3_d_valid(), .p3_d_ready(1'b1),
        .inj_a_opcode(ni20_tl_a_opcode), .inj_a_param(ni20_tl_a_param),
        .inj_a_size(ni20_tl_a_size), .inj_a_source(ni20_tl_a_source),
        .inj_a_addr(ni20_tl_a_addr), .inj_a_mask(ni20_tl_a_mask),
        .inj_a_data(ni20_tl_a_data), .inj_a_valid(ni20_tl_a_valid), .inj_a_ready(ni20_tl_a_ready),
        .axi_awaddr(r20_awaddr), .axi_awvalid(r20_awvalid), .axi_awready(r20_awready),
        .axi_wdata(r20_wdata), .axi_wstrb(r20_wstrb), .axi_wvalid(r20_wvalid), .axi_wready(r20_wready),
        .axi_bresp(r20_bresp), .axi_bvalid(r20_bvalid), .axi_bready(r20_bready),
        .axi_araddr(r20_araddr), .axi_arvalid(r20_arvalid), .axi_arready(r20_arready),
        .axi_rdata(r20_rdata), .axi_rresp(r20_rresp), .axi_rvalid(r20_rvalid), .axi_rready(r20_rready),
        .d_opcode(r20_d_opcode), .d_param(r20_d_param), .d_size(r20_d_size), .d_source(r20_d_source),
        .d_data(r20_d_data), .d_valid(r20_d_valid), .d_ready(1'b1)
    );
    sram_20 u_sram_20 (
        .aclk(clk), .aresetn(sys_rst_n),
        .awaddr(r20_awaddr), .awvalid(r20_awvalid), .awready(r20_awready),
        .wdata(r20_wdata), .wstrb(r20_wstrb), .wvalid(r20_wvalid), .wready(r20_wready),
        .bresp(r20_bresp), .bvalid(r20_bvalid), .bready(r20_bready),
        .araddr(r20_araddr), .arvalid(r20_arvalid), .arready(r20_arready),
        .rdata(r20_rdata), .rresp(r20_rresp), .rvalid(r20_rvalid), .rready(r20_rready)
    );

    // --- Node (2,1) ---
    ni_21 u_ni_21 (
        .clk(clk), .rst_n(sys_rst_n),
        .axi_awaddr(32'h0), .axi_awvalid(1'b0), .axi_awready(),
        .axi_wdata(64'h0), .axi_wstrb(8'h0), .axi_wvalid(1'b0), .axi_wready(),
        .axi_bresp(), .axi_bvalid(), .axi_bready(1'b0),
        .axi_araddr(32'h0), .axi_arvalid(1'b0), .axi_arready(),
        .axi_rdata(), .axi_rresp(), .axi_rvalid(), .axi_rready(1'b0),
        .tl_a_opcode(ni21_tl_a_opcode), .tl_a_param(ni21_tl_a_param),
        .tl_a_size(ni21_tl_a_size), .tl_a_source(ni21_tl_a_source),
        .tl_a_addr(ni21_tl_a_addr), .tl_a_mask(ni21_tl_a_mask),
        .tl_a_data(ni21_tl_a_data), .tl_a_valid(ni21_tl_a_valid), .tl_a_ready(ni21_tl_a_ready),
        .tl_d_opcode(r21_d_opcode), .tl_d_param(r21_d_param),
        .tl_d_size(r21_d_size), .tl_d_source(r21_d_source),
        .tl_d_data(r21_d_data), .tl_d_valid(r21_d_valid), .tl_d_ready(r21_d_ready)
    );
    router_21 u_router_21 (
        .clk(clk), .rst_n(sys_rst_n),
        .p0_a_opcode(ns_x2_y1_2_s_opcode), .p0_a_param(ns_x2_y1_2_s_param),
        .p0_a_size(ns_x2_y1_2_s_size), .p0_a_source(ns_x2_y1_2_s_source),
        .p0_a_addr(ns_x2_y1_2_s_addr), .p0_a_mask(ns_x2_y1_2_s_mask),
        .p0_a_data(ns_x2_y1_2_s_data), .p0_a_valid(ns_x2_y1_2_s_valid), .p0_a_ready(),
        .p0_ao_opcode(ns_x2_y1_2_n_opcode), .p0_ao_param(ns_x2_y1_2_n_param),
        .p0_ao_size(ns_x2_y1_2_n_size), .p0_ao_source(ns_x2_y1_2_n_source),
        .p0_ao_addr(ns_x2_y1_2_n_addr), .p0_ao_mask(ns_x2_y1_2_n_mask),
        .p0_ao_data(ns_x2_y1_2_n_data), .p0_ao_valid(ns_x2_y1_2_n_valid),
        .p0_d_opcode(), .p0_d_param(), .p0_d_size(), .p0_d_source(), .p0_d_data(), .p0_d_valid(), .p0_d_ready(1'b1),
        .p1_a_opcode(ns_x2_y0_1_n_opcode), .p1_a_param(ns_x2_y0_1_n_param),
        .p1_a_size(ns_x2_y0_1_n_size), .p1_a_source(ns_x2_y0_1_n_source),
        .p1_a_addr(ns_x2_y0_1_n_addr), .p1_a_mask(ns_x2_y0_1_n_mask),
        .p1_a_data(ns_x2_y0_1_n_data), .p1_a_valid(ns_x2_y0_1_n_valid), .p1_a_ready(),
        .p1_ao_opcode(ns_x2_y0_1_s_opcode), .p1_ao_param(ns_x2_y0_1_s_param),
        .p1_ao_size(ns_x2_y0_1_s_size), .p1_ao_source(ns_x2_y0_1_s_source),
        .p1_ao_addr(ns_x2_y0_1_s_addr), .p1_ao_mask(ns_x2_y0_1_s_mask),
        .p1_ao_data(ns_x2_y0_1_s_data), .p1_ao_valid(ns_x2_y0_1_s_valid),
        .p1_d_opcode(), .p1_d_param(), .p1_d_size(), .p1_d_source(), .p1_d_data(), .p1_d_valid(), .p1_d_ready(1'b1),
        .p2_a_opcode(ew_y1_x2_3_w_opcode), .p2_a_param(ew_y1_x2_3_w_param),
        .p2_a_size(ew_y1_x2_3_w_size), .p2_a_source(ew_y1_x2_3_w_source),
        .p2_a_addr(ew_y1_x2_3_w_addr), .p2_a_mask(ew_y1_x2_3_w_mask),
        .p2_a_data(ew_y1_x2_3_w_data), .p2_a_valid(ew_y1_x2_3_w_valid), .p2_a_ready(),
        .p2_ao_opcode(ew_y1_x2_3_e_opcode), .p2_ao_param(ew_y1_x2_3_e_param),
        .p2_ao_size(ew_y1_x2_3_e_size), .p2_ao_source(ew_y1_x2_3_e_source),
        .p2_ao_addr(ew_y1_x2_3_e_addr), .p2_ao_mask(ew_y1_x2_3_e_mask),
        .p2_ao_data(ew_y1_x2_3_e_data), .p2_ao_valid(ew_y1_x2_3_e_valid),
        .p2_d_opcode(), .p2_d_param(), .p2_d_size(), .p2_d_source(), .p2_d_data(), .p2_d_valid(), .p2_d_ready(1'b1),
        .p3_a_opcode(ew_y1_x1_2_e_opcode), .p3_a_param(ew_y1_x1_2_e_param),
        .p3_a_size(ew_y1_x1_2_e_size), .p3_a_source(ew_y1_x1_2_e_source),
        .p3_a_addr(ew_y1_x1_2_e_addr), .p3_a_mask(ew_y1_x1_2_e_mask),
        .p3_a_data(ew_y1_x1_2_e_data), .p3_a_valid(ew_y1_x1_2_e_valid), .p3_a_ready(),
        .p3_ao_opcode(ew_y1_x1_2_w_opcode), .p3_ao_param(ew_y1_x1_2_w_param),
        .p3_ao_size(ew_y1_x1_2_w_size), .p3_ao_source(ew_y1_x1_2_w_source),
        .p3_ao_addr(ew_y1_x1_2_w_addr), .p3_ao_mask(ew_y1_x1_2_w_mask),
        .p3_ao_data(ew_y1_x1_2_w_data), .p3_ao_valid(ew_y1_x1_2_w_valid),
        .p3_d_opcode(), .p3_d_param(), .p3_d_size(), .p3_d_source(), .p3_d_data(), .p3_d_valid(), .p3_d_ready(1'b1),
        .inj_a_opcode(ni21_tl_a_opcode), .inj_a_param(ni21_tl_a_param),
        .inj_a_size(ni21_tl_a_size), .inj_a_source(ni21_tl_a_source),
        .inj_a_addr(ni21_tl_a_addr), .inj_a_mask(ni21_tl_a_mask),
        .inj_a_data(ni21_tl_a_data), .inj_a_valid(ni21_tl_a_valid), .inj_a_ready(ni21_tl_a_ready),
        .axi_awaddr(r21_awaddr), .axi_awvalid(r21_awvalid), .axi_awready(r21_awready),
        .axi_wdata(r21_wdata), .axi_wstrb(r21_wstrb), .axi_wvalid(r21_wvalid), .axi_wready(r21_wready),
        .axi_bresp(r21_bresp), .axi_bvalid(r21_bvalid), .axi_bready(r21_bready),
        .axi_araddr(r21_araddr), .axi_arvalid(r21_arvalid), .axi_arready(r21_arready),
        .axi_rdata(r21_rdata), .axi_rresp(r21_rresp), .axi_rvalid(r21_rvalid), .axi_rready(r21_rready),
        .d_opcode(r21_d_opcode), .d_param(r21_d_param), .d_size(r21_d_size), .d_source(r21_d_source),
        .d_data(r21_d_data), .d_valid(r21_d_valid), .d_ready(1'b1)
    );
    sram_21 u_sram_21 (
        .aclk(clk), .aresetn(sys_rst_n),
        .awaddr(r21_awaddr), .awvalid(r21_awvalid), .awready(r21_awready),
        .wdata(r21_wdata), .wstrb(r21_wstrb), .wvalid(r21_wvalid), .wready(r21_wready),
        .bresp(r21_bresp), .bvalid(r21_bvalid), .bready(r21_bready),
        .araddr(r21_araddr), .arvalid(r21_arvalid), .arready(r21_arready),
        .rdata(r21_rdata), .rresp(r21_rresp), .rvalid(r21_rvalid), .rready(r21_rready)
    );

    // --- Node (2,2) ---
    ni_22 u_ni_22 (
        .clk(clk), .rst_n(sys_rst_n),
        .axi_awaddr(32'h0), .axi_awvalid(1'b0), .axi_awready(),
        .axi_wdata(64'h0), .axi_wstrb(8'h0), .axi_wvalid(1'b0), .axi_wready(),
        .axi_bresp(), .axi_bvalid(), .axi_bready(1'b0),
        .axi_araddr(32'h0), .axi_arvalid(1'b0), .axi_arready(),
        .axi_rdata(), .axi_rresp(), .axi_rvalid(), .axi_rready(1'b0),
        .tl_a_opcode(ni22_tl_a_opcode), .tl_a_param(ni22_tl_a_param),
        .tl_a_size(ni22_tl_a_size), .tl_a_source(ni22_tl_a_source),
        .tl_a_addr(ni22_tl_a_addr), .tl_a_mask(ni22_tl_a_mask),
        .tl_a_data(ni22_tl_a_data), .tl_a_valid(ni22_tl_a_valid), .tl_a_ready(ni22_tl_a_ready),
        .tl_d_opcode(r22_d_opcode), .tl_d_param(r22_d_param),
        .tl_d_size(r22_d_size), .tl_d_source(r22_d_source),
        .tl_d_data(r22_d_data), .tl_d_valid(r22_d_valid), .tl_d_ready(r22_d_ready)
    );
    router_22 u_router_22 (
        .clk(clk), .rst_n(sys_rst_n),
        .p0_a_opcode(3'h0), .p0_a_param(3'h0),
        .p0_a_size(3'h0), .p0_a_source(4'h0),
        .p0_a_addr(tie3), .p0_a_mask(tie3),
        .p0_a_data(tie3), .p0_a_valid(1'b0), .p0_a_ready(),
        .p0_ao_opcode(), .p0_ao_param(),
        .p0_ao_size(), .p0_ao_source(),
        .p0_ao_addr(), .p0_ao_mask(),
        .p0_ao_data(), .p0_ao_valid(),
        .p0_d_opcode(), .p0_d_param(), .p0_d_size(), .p0_d_source(), .p0_d_data(), .p0_d_valid(), .p0_d_ready(1'b1),
        .p1_a_opcode(ns_x2_y1_2_n_opcode), .p1_a_param(ns_x2_y1_2_n_param),
        .p1_a_size(ns_x2_y1_2_n_size), .p1_a_source(ns_x2_y1_2_n_source),
        .p1_a_addr(ns_x2_y1_2_n_addr), .p1_a_mask(ns_x2_y1_2_n_mask),
        .p1_a_data(ns_x2_y1_2_n_data), .p1_a_valid(ns_x2_y1_2_n_valid), .p1_a_ready(),
        .p1_ao_opcode(ns_x2_y1_2_s_opcode), .p1_ao_param(ns_x2_y1_2_s_param),
        .p1_ao_size(ns_x2_y1_2_s_size), .p1_ao_source(ns_x2_y1_2_s_source),
        .p1_ao_addr(ns_x2_y1_2_s_addr), .p1_ao_mask(ns_x2_y1_2_s_mask),
        .p1_ao_data(ns_x2_y1_2_s_data), .p1_ao_valid(ns_x2_y1_2_s_valid),
        .p1_d_opcode(), .p1_d_param(), .p1_d_size(), .p1_d_source(), .p1_d_data(), .p1_d_valid(), .p1_d_ready(1'b1),
        .p2_a_opcode(ew_y2_x2_3_w_opcode), .p2_a_param(ew_y2_x2_3_w_param),
        .p2_a_size(ew_y2_x2_3_w_size), .p2_a_source(ew_y2_x2_3_w_source),
        .p2_a_addr(ew_y2_x2_3_w_addr), .p2_a_mask(ew_y2_x2_3_w_mask),
        .p2_a_data(ew_y2_x2_3_w_data), .p2_a_valid(ew_y2_x2_3_w_valid), .p2_a_ready(),
        .p2_ao_opcode(ew_y2_x2_3_e_opcode), .p2_ao_param(ew_y2_x2_3_e_param),
        .p2_ao_size(ew_y2_x2_3_e_size), .p2_ao_source(ew_y2_x2_3_e_source),
        .p2_ao_addr(ew_y2_x2_3_e_addr), .p2_ao_mask(ew_y2_x2_3_e_mask),
        .p2_ao_data(ew_y2_x2_3_e_data), .p2_ao_valid(ew_y2_x2_3_e_valid),
        .p2_d_opcode(), .p2_d_param(), .p2_d_size(), .p2_d_source(), .p2_d_data(), .p2_d_valid(), .p2_d_ready(1'b1),
        .p3_a_opcode(ew_y2_x1_2_e_opcode), .p3_a_param(ew_y2_x1_2_e_param),
        .p3_a_size(ew_y2_x1_2_e_size), .p3_a_source(ew_y2_x1_2_e_source),
        .p3_a_addr(ew_y2_x1_2_e_addr), .p3_a_mask(ew_y2_x1_2_e_mask),
        .p3_a_data(ew_y2_x1_2_e_data), .p3_a_valid(ew_y2_x1_2_e_valid), .p3_a_ready(),
        .p3_ao_opcode(ew_y2_x1_2_w_opcode), .p3_ao_param(ew_y2_x1_2_w_param),
        .p3_ao_size(ew_y2_x1_2_w_size), .p3_ao_source(ew_y2_x1_2_w_source),
        .p3_ao_addr(ew_y2_x1_2_w_addr), .p3_ao_mask(ew_y2_x1_2_w_mask),
        .p3_ao_data(ew_y2_x1_2_w_data), .p3_ao_valid(ew_y2_x1_2_w_valid),
        .p3_d_opcode(), .p3_d_param(), .p3_d_size(), .p3_d_source(), .p3_d_data(), .p3_d_valid(), .p3_d_ready(1'b1),
        .inj_a_opcode(ni22_tl_a_opcode), .inj_a_param(ni22_tl_a_param),
        .inj_a_size(ni22_tl_a_size), .inj_a_source(ni22_tl_a_source),
        .inj_a_addr(ni22_tl_a_addr), .inj_a_mask(ni22_tl_a_mask),
        .inj_a_data(ni22_tl_a_data), .inj_a_valid(ni22_tl_a_valid), .inj_a_ready(ni22_tl_a_ready),
        .axi_awaddr(r22_awaddr), .axi_awvalid(r22_awvalid), .axi_awready(r22_awready),
        .axi_wdata(r22_wdata), .axi_wstrb(r22_wstrb), .axi_wvalid(r22_wvalid), .axi_wready(r22_wready),
        .axi_bresp(r22_bresp), .axi_bvalid(r22_bvalid), .axi_bready(r22_bready),
        .axi_araddr(r22_araddr), .axi_arvalid(r22_arvalid), .axi_arready(r22_arready),
        .axi_rdata(r22_rdata), .axi_rresp(r22_rresp), .axi_rvalid(r22_rvalid), .axi_rready(r22_rready),
        .d_opcode(r22_d_opcode), .d_param(r22_d_param), .d_size(r22_d_size), .d_source(r22_d_source),
        .d_data(r22_d_data), .d_valid(r22_d_valid), .d_ready(1'b1)
    );
    sram_22 u_sram_22 (
        .aclk(clk), .aresetn(sys_rst_n),
        .awaddr(r22_awaddr), .awvalid(r22_awvalid), .awready(r22_awready),
        .wdata(r22_wdata), .wstrb(r22_wstrb), .wvalid(r22_wvalid), .wready(r22_wready),
        .bresp(r22_bresp), .bvalid(r22_bvalid), .bready(r22_bready),
        .araddr(r22_araddr), .arvalid(r22_arvalid), .arready(r22_arready),
        .rdata(r22_rdata), .rresp(r22_rresp), .rvalid(r22_rvalid), .rready(r22_rready)
    );

    // --- Node (3,0) ---
    ni_30 u_ni_30 (
        .clk(clk), .rst_n(sys_rst_n),
        .axi_awaddr(32'h0), .axi_awvalid(1'b0), .axi_awready(),
        .axi_wdata(64'h0), .axi_wstrb(8'h0), .axi_wvalid(1'b0), .axi_wready(),
        .axi_bresp(), .axi_bvalid(), .axi_bready(1'b0),
        .axi_araddr(32'h0), .axi_arvalid(1'b0), .axi_arready(),
        .axi_rdata(), .axi_rresp(), .axi_rvalid(), .axi_rready(1'b0),
        .tl_a_opcode(ni30_tl_a_opcode), .tl_a_param(ni30_tl_a_param),
        .tl_a_size(ni30_tl_a_size), .tl_a_source(ni30_tl_a_source),
        .tl_a_addr(ni30_tl_a_addr), .tl_a_mask(ni30_tl_a_mask),
        .tl_a_data(ni30_tl_a_data), .tl_a_valid(ni30_tl_a_valid), .tl_a_ready(ni30_tl_a_ready),
        .tl_d_opcode(r30_d_opcode), .tl_d_param(r30_d_param),
        .tl_d_size(r30_d_size), .tl_d_source(r30_d_source),
        .tl_d_data(r30_d_data), .tl_d_valid(r30_d_valid), .tl_d_ready(r30_d_ready)
    );
    router_30 u_router_30 (
        .clk(clk), .rst_n(sys_rst_n),
        .p0_a_opcode(ns_x3_y0_1_s_opcode), .p0_a_param(ns_x3_y0_1_s_param),
        .p0_a_size(ns_x3_y0_1_s_size), .p0_a_source(ns_x3_y0_1_s_source),
        .p0_a_addr(ns_x3_y0_1_s_addr), .p0_a_mask(ns_x3_y0_1_s_mask),
        .p0_a_data(ns_x3_y0_1_s_data), .p0_a_valid(ns_x3_y0_1_s_valid), .p0_a_ready(),
        .p0_ao_opcode(ns_x3_y0_1_n_opcode), .p0_ao_param(ns_x3_y0_1_n_param),
        .p0_ao_size(ns_x3_y0_1_n_size), .p0_ao_source(ns_x3_y0_1_n_source),
        .p0_ao_addr(ns_x3_y0_1_n_addr), .p0_ao_mask(ns_x3_y0_1_n_mask),
        .p0_ao_data(ns_x3_y0_1_n_data), .p0_ao_valid(ns_x3_y0_1_n_valid),
        .p0_d_opcode(), .p0_d_param(), .p0_d_size(), .p0_d_source(), .p0_d_data(), .p0_d_valid(), .p0_d_ready(1'b1),
        .p1_a_opcode(3'h0), .p1_a_param(3'h0),
        .p1_a_size(3'h0), .p1_a_source(4'h0),
        .p1_a_addr(32'h0), .p1_a_mask(8'h0),
        .p1_a_data(64'h0), .p1_a_valid(1'b0), .p1_a_ready(),
        .p1_ao_opcode(), .p1_ao_param(),
        .p1_ao_size(), .p1_ao_source(),
        .p1_ao_addr(), .p1_ao_mask(),
        .p1_ao_data(), .p1_ao_valid(),
        .p1_d_opcode(), .p1_d_param(), .p1_d_size(), .p1_d_source(), .p1_d_data(), .p1_d_valid(), .p1_d_ready(1'b1),
        .p2_a_opcode(3'h0), .p2_a_param(3'h0),
        .p2_a_size(3'h0), .p2_a_source(4'h0),
        .p2_a_addr(32'h0), .p2_a_mask(8'h0),
        .p2_a_data(64'h0), .p2_a_valid(1'b0), .p2_a_ready(),
        .p2_ao_opcode(), .p2_ao_param(),
        .p2_ao_size(), .p2_ao_source(),
        .p2_ao_addr(), .p2_ao_mask(),
        .p2_ao_data(), .p2_ao_valid(),
        .p2_d_opcode(), .p2_d_param(), .p2_d_size(), .p2_d_source(), .p2_d_data(), .p2_d_valid(), .p2_d_ready(1'b1),
        .p3_a_opcode(ew_y0_x2_3_e_opcode), .p3_a_param(ew_y0_x2_3_e_param),
        .p3_a_size(ew_y0_x2_3_e_size), .p3_a_source(ew_y0_x2_3_e_source),
        .p3_a_addr(ew_y0_x2_3_e_addr), .p3_a_mask(ew_y0_x2_3_e_mask),
        .p3_a_data(ew_y0_x2_3_e_data), .p3_a_valid(ew_y0_x2_3_e_valid), .p3_a_ready(),
        .p3_ao_opcode(ew_y0_x2_3_w_opcode), .p3_ao_param(ew_y0_x2_3_w_param),
        .p3_ao_size(ew_y0_x2_3_w_size), .p3_ao_source(ew_y0_x2_3_w_source),
        .p3_ao_addr(ew_y0_x2_3_w_addr), .p3_ao_mask(ew_y0_x2_3_w_mask),
        .p3_ao_data(ew_y0_x2_3_w_data), .p3_ao_valid(ew_y0_x2_3_w_valid),
        .p3_d_opcode(), .p3_d_param(), .p3_d_size(), .p3_d_source(), .p3_d_data(), .p3_d_valid(), .p3_d_ready(1'b1),
        .inj_a_opcode(ni30_tl_a_opcode), .inj_a_param(ni30_tl_a_param),
        .inj_a_size(ni30_tl_a_size), .inj_a_source(ni30_tl_a_source),
        .inj_a_addr(ni30_tl_a_addr), .inj_a_mask(ni30_tl_a_mask),
        .inj_a_data(ni30_tl_a_data), .inj_a_valid(ni30_tl_a_valid), .inj_a_ready(ni30_tl_a_ready),
        .axi_awaddr(r30_awaddr), .axi_awvalid(r30_awvalid), .axi_awready(r30_awready),
        .axi_wdata(r30_wdata), .axi_wstrb(r30_wstrb), .axi_wvalid(r30_wvalid), .axi_wready(r30_wready),
        .axi_bresp(r30_bresp), .axi_bvalid(r30_bvalid), .axi_bready(r30_bready),
        .axi_araddr(r30_araddr), .axi_arvalid(r30_arvalid), .axi_arready(r30_arready),
        .axi_rdata(r30_rdata), .axi_rresp(r30_rresp), .axi_rvalid(r30_rvalid), .axi_rready(r30_rready),
        .d_opcode(r30_d_opcode), .d_param(r30_d_param), .d_size(r30_d_size), .d_source(r30_d_source),
        .d_data(r30_d_data), .d_valid(r30_d_valid), .d_ready(1'b1)
    );
    sram_30 u_sram_30 (
        .aclk(clk), .aresetn(sys_rst_n),
        .awaddr(r30_awaddr), .awvalid(r30_awvalid), .awready(r30_awready),
        .wdata(r30_wdata), .wstrb(r30_wstrb), .wvalid(r30_wvalid), .wready(r30_wready),
        .bresp(r30_bresp), .bvalid(r30_bvalid), .bready(r30_bready),
        .araddr(r30_araddr), .arvalid(r30_arvalid), .arready(r30_arready),
        .rdata(r30_rdata), .rresp(r30_rresp), .rvalid(r30_rvalid), .rready(r30_rready)
    );

    // --- Node (3,1) ---
    ni_31 u_ni_31 (
        .clk(clk), .rst_n(sys_rst_n),
        .axi_awaddr(32'h0), .axi_awvalid(1'b0), .axi_awready(),
        .axi_wdata(64'h0), .axi_wstrb(8'h0), .axi_wvalid(1'b0), .axi_wready(),
        .axi_bresp(), .axi_bvalid(), .axi_bready(1'b0),
        .axi_araddr(32'h0), .axi_arvalid(1'b0), .axi_arready(),
        .axi_rdata(), .axi_rresp(), .axi_rvalid(), .axi_rready(1'b0),
        .tl_a_opcode(ni31_tl_a_opcode), .tl_a_param(ni31_tl_a_param),
        .tl_a_size(ni31_tl_a_size), .tl_a_source(ni31_tl_a_source),
        .tl_a_addr(ni31_tl_a_addr), .tl_a_mask(ni31_tl_a_mask),
        .tl_a_data(ni31_tl_a_data), .tl_a_valid(ni31_tl_a_valid), .tl_a_ready(ni31_tl_a_ready),
        .tl_d_opcode(r31_d_opcode), .tl_d_param(r31_d_param),
        .tl_d_size(r31_d_size), .tl_d_source(r31_d_source),
        .tl_d_data(r31_d_data), .tl_d_valid(r31_d_valid), .tl_d_ready(r31_d_ready)
    );
    router_31 u_router_31 (
        .clk(clk), .rst_n(sys_rst_n),
        .p0_a_opcode(ns_x3_y1_2_s_opcode), .p0_a_param(ns_x3_y1_2_s_param),
        .p0_a_size(ns_x3_y1_2_s_size), .p0_a_source(ns_x3_y1_2_s_source),
        .p0_a_addr(ns_x3_y1_2_s_addr), .p0_a_mask(ns_x3_y1_2_s_mask),
        .p0_a_data(ns_x3_y1_2_s_data), .p0_a_valid(ns_x3_y1_2_s_valid), .p0_a_ready(),
        .p0_ao_opcode(ns_x3_y1_2_n_opcode), .p0_ao_param(ns_x3_y1_2_n_param),
        .p0_ao_size(ns_x3_y1_2_n_size), .p0_ao_source(ns_x3_y1_2_n_source),
        .p0_ao_addr(ns_x3_y1_2_n_addr), .p0_ao_mask(ns_x3_y1_2_n_mask),
        .p0_ao_data(ns_x3_y1_2_n_data), .p0_ao_valid(ns_x3_y1_2_n_valid),
        .p0_d_opcode(), .p0_d_param(), .p0_d_size(), .p0_d_source(), .p0_d_data(), .p0_d_valid(), .p0_d_ready(1'b1),
        .p1_a_opcode(ns_x3_y0_1_n_opcode), .p1_a_param(ns_x3_y0_1_n_param),
        .p1_a_size(ns_x3_y0_1_n_size), .p1_a_source(ns_x3_y0_1_n_source),
        .p1_a_addr(ns_x3_y0_1_n_addr), .p1_a_mask(ns_x3_y0_1_n_mask),
        .p1_a_data(ns_x3_y0_1_n_data), .p1_a_valid(ns_x3_y0_1_n_valid), .p1_a_ready(),
        .p1_ao_opcode(ns_x3_y0_1_s_opcode), .p1_ao_param(ns_x3_y0_1_s_param),
        .p1_ao_size(ns_x3_y0_1_s_size), .p1_ao_source(ns_x3_y0_1_s_source),
        .p1_ao_addr(ns_x3_y0_1_s_addr), .p1_ao_mask(ns_x3_y0_1_s_mask),
        .p1_ao_data(ns_x3_y0_1_s_data), .p1_ao_valid(ns_x3_y0_1_s_valid),
        .p1_d_opcode(), .p1_d_param(), .p1_d_size(), .p1_d_source(), .p1_d_data(), .p1_d_valid(), .p1_d_ready(1'b1),
        .p2_a_opcode(3'h0), .p2_a_param(3'h0),
        .p2_a_size(3'h0), .p2_a_source(4'h0),
        .p2_a_addr(32'h0), .p2_a_mask(8'h0),
        .p2_a_data(64'h0), .p2_a_valid(1'b0), .p2_a_ready(),
        .p2_ao_opcode(), .p2_ao_param(),
        .p2_ao_size(), .p2_ao_source(),
        .p2_ao_addr(), .p2_ao_mask(),
        .p2_ao_data(), .p2_ao_valid(),
        .p2_d_opcode(), .p2_d_param(), .p2_d_size(), .p2_d_source(), .p2_d_data(), .p2_d_valid(), .p2_d_ready(1'b1),
        .p3_a_opcode(ew_y1_x2_3_e_opcode), .p3_a_param(ew_y1_x2_3_e_param),
        .p3_a_size(ew_y1_x2_3_e_size), .p3_a_source(ew_y1_x2_3_e_source),
        .p3_a_addr(ew_y1_x2_3_e_addr), .p3_a_mask(ew_y1_x2_3_e_mask),
        .p3_a_data(ew_y1_x2_3_e_data), .p3_a_valid(ew_y1_x2_3_e_valid), .p3_a_ready(),
        .p3_ao_opcode(ew_y1_x2_3_w_opcode), .p3_ao_param(ew_y1_x2_3_w_param),
        .p3_ao_size(ew_y1_x2_3_w_size), .p3_ao_source(ew_y1_x2_3_w_source),
        .p3_ao_addr(ew_y1_x2_3_w_addr), .p3_ao_mask(ew_y1_x2_3_w_mask),
        .p3_ao_data(ew_y1_x2_3_w_data), .p3_ao_valid(ew_y1_x2_3_w_valid),
        .p3_d_opcode(), .p3_d_param(), .p3_d_size(), .p3_d_source(), .p3_d_data(), .p3_d_valid(), .p3_d_ready(1'b1),
        .inj_a_opcode(ni31_tl_a_opcode), .inj_a_param(ni31_tl_a_param),
        .inj_a_size(ni31_tl_a_size), .inj_a_source(ni31_tl_a_source),
        .inj_a_addr(ni31_tl_a_addr), .inj_a_mask(ni31_tl_a_mask),
        .inj_a_data(ni31_tl_a_data), .inj_a_valid(ni31_tl_a_valid), .inj_a_ready(ni31_tl_a_ready),
        .axi_awaddr(r31_awaddr), .axi_awvalid(r31_awvalid), .axi_awready(r31_awready),
        .axi_wdata(r31_wdata), .axi_wstrb(r31_wstrb), .axi_wvalid(r31_wvalid), .axi_wready(r31_wready),
        .axi_bresp(r31_bresp), .axi_bvalid(r31_bvalid), .axi_bready(r31_bready),
        .axi_araddr(r31_araddr), .axi_arvalid(r31_arvalid), .axi_arready(r31_arready),
        .axi_rdata(r31_rdata), .axi_rresp(r31_rresp), .axi_rvalid(r31_rvalid), .axi_rready(r31_rready),
        .d_opcode(r31_d_opcode), .d_param(r31_d_param), .d_size(r31_d_size), .d_source(r31_d_source),
        .d_data(r31_d_data), .d_valid(r31_d_valid), .d_ready(1'b1)
    );
    sram_31 u_sram_31 (
        .aclk(clk), .aresetn(sys_rst_n),
        .awaddr(r31_awaddr), .awvalid(r31_awvalid), .awready(r31_awready),
        .wdata(r31_wdata), .wstrb(r31_wstrb), .wvalid(r31_wvalid), .wready(r31_wready),
        .bresp(r31_bresp), .bvalid(r31_bvalid), .bready(r31_bready),
        .araddr(r31_araddr), .arvalid(r31_arvalid), .arready(r31_arready),
        .rdata(r31_rdata), .rresp(r31_rresp), .rvalid(r31_rvalid), .rready(r31_rready)
    );

    // --- Node (3,2) ---
    ni_32 u_ni_32 (
        .clk(clk), .rst_n(sys_rst_n),
        .axi_awaddr(32'h0), .axi_awvalid(1'b0), .axi_awready(),
        .axi_wdata(64'h0), .axi_wstrb(8'h0), .axi_wvalid(1'b0), .axi_wready(),
        .axi_bresp(), .axi_bvalid(), .axi_bready(1'b0),
        .axi_araddr(32'h0), .axi_arvalid(1'b0), .axi_arready(),
        .axi_rdata(), .axi_rresp(), .axi_rvalid(), .axi_rready(1'b0),
        .tl_a_opcode(ni32_tl_a_opcode), .tl_a_param(ni32_tl_a_param),
        .tl_a_size(ni32_tl_a_size), .tl_a_source(ni32_tl_a_source),
        .tl_a_addr(ni32_tl_a_addr), .tl_a_mask(ni32_tl_a_mask),
        .tl_a_data(ni32_tl_a_data), .tl_a_valid(ni32_tl_a_valid), .tl_a_ready(ni32_tl_a_ready),
        .tl_d_opcode(r32_d_opcode), .tl_d_param(r32_d_param),
        .tl_d_size(r32_d_size), .tl_d_source(r32_d_source),
        .tl_d_data(r32_d_data), .tl_d_valid(r32_d_valid), .tl_d_ready(r32_d_ready)
    );
    router_32 u_router_32 (
        .clk(clk), .rst_n(sys_rst_n),
        .p0_a_opcode(3'h0), .p0_a_param(3'h0),
        .p0_a_size(3'h0), .p0_a_source(4'h0),
        .p0_a_addr(tie3), .p0_a_mask(tie3),
        .p0_a_data(tie3), .p0_a_valid(1'b0), .p0_a_ready(),
        .p0_ao_opcode(), .p0_ao_param(),
        .p0_ao_size(), .p0_ao_source(),
        .p0_ao_addr(), .p0_ao_mask(),
        .p0_ao_data(), .p0_ao_valid(),
        .p0_d_opcode(), .p0_d_param(), .p0_d_size(), .p0_d_source(), .p0_d_data(), .p0_d_valid(), .p0_d_ready(1'b1),
        .p1_a_opcode(ns_x3_y1_2_n_opcode), .p1_a_param(ns_x3_y1_2_n_param),
        .p1_a_size(ns_x3_y1_2_n_size), .p1_a_source(ns_x3_y1_2_n_source),
        .p1_a_addr(ns_x3_y1_2_n_addr), .p1_a_mask(ns_x3_y1_2_n_mask),
        .p1_a_data(ns_x3_y1_2_n_data), .p1_a_valid(ns_x3_y1_2_n_valid), .p1_a_ready(),
        .p1_ao_opcode(ns_x3_y1_2_s_opcode), .p1_ao_param(ns_x3_y1_2_s_param),
        .p1_ao_size(ns_x3_y1_2_s_size), .p1_ao_source(ns_x3_y1_2_s_source),
        .p1_ao_addr(ns_x3_y1_2_s_addr), .p1_ao_mask(ns_x3_y1_2_s_mask),
        .p1_ao_data(ns_x3_y1_2_s_data), .p1_ao_valid(ns_x3_y1_2_s_valid),
        .p1_d_opcode(), .p1_d_param(), .p1_d_size(), .p1_d_source(), .p1_d_data(), .p1_d_valid(), .p1_d_ready(1'b1),
        .p2_a_opcode(3'h0), .p2_a_param(3'h0),
        .p2_a_size(3'h0), .p2_a_source(4'h0),
        .p2_a_addr(32'h0), .p2_a_mask(8'h0),
        .p2_a_data(64'h0), .p2_a_valid(1'b0), .p2_a_ready(),
        .p2_ao_opcode(), .p2_ao_param(),
        .p2_ao_size(), .p2_ao_source(),
        .p2_ao_addr(), .p2_ao_mask(),
        .p2_ao_data(), .p2_ao_valid(),
        .p2_d_opcode(), .p2_d_param(), .p2_d_size(), .p2_d_source(), .p2_d_data(), .p2_d_valid(), .p2_d_ready(1'b1),
        .p3_a_opcode(ew_y2_x2_3_e_opcode), .p3_a_param(ew_y2_x2_3_e_param),
        .p3_a_size(ew_y2_x2_3_e_size), .p3_a_source(ew_y2_x2_3_e_source),
        .p3_a_addr(ew_y2_x2_3_e_addr), .p3_a_mask(ew_y2_x2_3_e_mask),
        .p3_a_data(ew_y2_x2_3_e_data), .p3_a_valid(ew_y2_x2_3_e_valid), .p3_a_ready(),
        .p3_ao_opcode(ew_y2_x2_3_w_opcode), .p3_ao_param(ew_y2_x2_3_w_param),
        .p3_ao_size(ew_y2_x2_3_w_size), .p3_ao_source(ew_y2_x2_3_w_source),
        .p3_ao_addr(ew_y2_x2_3_w_addr), .p3_ao_mask(ew_y2_x2_3_w_mask),
        .p3_ao_data(ew_y2_x2_3_w_data), .p3_ao_valid(ew_y2_x2_3_w_valid),
        .p3_d_opcode(), .p3_d_param(), .p3_d_size(), .p3_d_source(), .p3_d_data(), .p3_d_valid(), .p3_d_ready(1'b1),
        .inj_a_opcode(ni32_tl_a_opcode), .inj_a_param(ni32_tl_a_param),
        .inj_a_size(ni32_tl_a_size), .inj_a_source(ni32_tl_a_source),
        .inj_a_addr(ni32_tl_a_addr), .inj_a_mask(ni32_tl_a_mask),
        .inj_a_data(ni32_tl_a_data), .inj_a_valid(ni32_tl_a_valid), .inj_a_ready(ni32_tl_a_ready),
        .axi_awaddr(r32_awaddr), .axi_awvalid(r32_awvalid), .axi_awready(r32_awready),
        .axi_wdata(r32_wdata), .axi_wstrb(r32_wstrb), .axi_wvalid(r32_wvalid), .axi_wready(r32_wready),
        .axi_bresp(r32_bresp), .axi_bvalid(r32_bvalid), .axi_bready(r32_bready),
        .axi_araddr(r32_araddr), .axi_arvalid(r32_arvalid), .axi_arready(r32_arready),
        .axi_rdata(r32_rdata), .axi_rresp(r32_rresp), .axi_rvalid(r32_rvalid), .axi_rready(r32_rready),
        .d_opcode(r32_d_opcode), .d_param(r32_d_param), .d_size(r32_d_size), .d_source(r32_d_source),
        .d_data(r32_d_data), .d_valid(r32_d_valid), .d_ready(1'b1)
    );
    sram_32 u_sram_32 (
        .aclk(clk), .aresetn(sys_rst_n),
        .awaddr(r32_awaddr), .awvalid(r32_awvalid), .awready(r32_awready),
        .wdata(r32_wdata), .wstrb(r32_wstrb), .wvalid(r32_wvalid), .wready(r32_wready),
        .bresp(r32_bresp), .bvalid(r32_bvalid), .bready(r32_bready),
        .araddr(r32_araddr), .arvalid(r32_arvalid), .arready(r32_arready),
        .rdata(r32_rdata), .rresp(r32_rresp), .rvalid(r32_rvalid), .rready(r32_rready)
    );

    // -------------------------------------------------------------------
    // AES-128 engines
    // -------------------------------------------------------------------
    wire [127:0] aes0_data_out; wire aes0_done, aes0_busy;
    aes0 u_aes0 (
        .clk(clk), .rst_n(sys_rst_n),
        .key_in(128'h0), .key_valid(1'b0),
        .data_in(128'h0), .start(1'b0), .encrypt(1'b1),
        .data_out(aes0_data_out), .done(aes0_done), .busy(aes0_busy)
    );
    wire [127:0] aes1_data_out; wire aes1_done, aes1_busy;
    aes1 u_aes1 (
        .clk(clk), .rst_n(sys_rst_n),
        .key_in(128'h0), .key_valid(1'b0),
        .data_in(128'h0), .start(1'b0), .encrypt(1'b1),
        .data_out(aes1_data_out), .done(aes1_done), .busy(aes1_busy)
    );
    wire [127:0] aes2_data_out; wire aes2_done, aes2_busy;
    aes2 u_aes2 (
        .clk(clk), .rst_n(sys_rst_n),
        .key_in(128'h0), .key_valid(1'b0),
        .data_in(128'h0), .start(1'b0), .encrypt(1'b1),
        .data_out(aes2_data_out), .done(aes2_done), .busy(aes2_busy)
    );
    wire [127:0] aes3_data_out; wire aes3_done, aes3_busy;
    aes3 u_aes3 (
        .clk(clk), .rst_n(sys_rst_n),
        .key_in(128'h0), .key_valid(1'b0),
        .data_in(128'h0), .start(1'b0), .encrypt(1'b1),
        .data_out(aes3_data_out), .done(aes3_done), .busy(aes3_busy)
    );

    // -------------------------------------------------------------------
    // DMA engines
    // -------------------------------------------------------------------
    wire dma0_irq_w, dma1_irq_w;
    dma0 u_dma0 (
        .aclk(clk), .aresetn(sys_rst_n),
        .cfg_awaddr(12'h0), .cfg_awvalid(1'b0), .cfg_awready(),
        .cfg_wdata(32'h0), .cfg_wstrb(4'h0), .cfg_wvalid(1'b0), .cfg_wready(),
        .cfg_bresp(), .cfg_bvalid(), .cfg_bready(1'b1),
        .cfg_araddr(12'h0), .cfg_arvalid(1'b0), .cfg_arready(),
        .cfg_rdata(), .cfg_rresp(), .cfg_rvalid(), .cfg_rready(1'b1),
        .m_awaddr(), .m_awvalid(), .m_awready(1'b0),
        .m_wdata(), .m_wstrb(), .m_wvalid(), .m_wready(1'b0),
        .m_bresp(2'b0), .m_bvalid(1'b0), .m_bready(),
        .m_araddr(), .m_arvalid(), .m_arready(1'b0),
        .m_rdata(32'h0), .m_rresp(2'b0), .m_rvalid(1'b0), .m_rready(),
        .dma_irq(dma0_irq_w)
    );
    dma1 u_dma1 (
        .aclk(clk), .aresetn(sys_rst_n),
        .cfg_awaddr(12'h0), .cfg_awvalid(1'b0), .cfg_awready(),
        .cfg_wdata(32'h0), .cfg_wstrb(4'h0), .cfg_wvalid(1'b0), .cfg_wready(),
        .cfg_bresp(), .cfg_bvalid(), .cfg_bready(1'b1),
        .cfg_araddr(12'h0), .cfg_arvalid(1'b0), .cfg_arready(),
        .cfg_rdata(), .cfg_rresp(), .cfg_rvalid(), .cfg_rready(1'b1),
        .m_awaddr(), .m_awvalid(), .m_awready(1'b0),
        .m_wdata(), .m_wstrb(), .m_wvalid(), .m_wready(1'b0),
        .m_bresp(2'b0), .m_bvalid(1'b0), .m_bready(),
        .m_araddr(), .m_arvalid(), .m_arready(1'b0),
        .m_rdata(32'h0), .m_rresp(2'b0), .m_rvalid(1'b0), .m_rready(),
        .dma_irq(dma1_irq_w)
    );

    // -------------------------------------------------------------------
    // IRQ aggregators
    // -------------------------------------------------------------------
    wire [7:0] irq_crypto_src;
    wire [7:0] irq_periph_src;
    assign irq_crypto_src = {2'b0, dma1_irq_w, dma0_irq_w, aes3_done, aes2_done, aes1_done, aes0_done};
    assign irq_periph_src = {3'b0, wdt_irq, timer0_irq, gpio1_irq, gpio0_irq, uart_rx_irq};
    irq_crypto u_irq_crypto (
        .pclk(clk), .presetn(sys_rst_n),
        .psel(1'b0), .penable(1'b0), .pwrite(1'b0),
        .paddr(12'h0), .pwdata(32'h0), .prdata(), .pready(), .pslverr(),
        .irq_src(irq_crypto_src),
        .cpu_irq(cpu_crypto_irq), .cpu_irq_id(cpu_crypto_irq_id)
    );
    irq_periph u_irq_periph (
        .pclk(clk), .presetn(sys_rst_n),
        .psel(1'b0), .penable(1'b0), .pwrite(1'b0),
        .paddr(12'h0), .pwdata(32'h0), .prdata(), .pready(), .pslverr(),
        .irq_src(irq_periph_src),
        .cpu_irq(cpu_periph_irq), .cpu_irq_id(cpu_periph_irq_id)
    );

    // -------------------------------------------------------------------
    // SoC config registers and async mailbox
    // -------------------------------------------------------------------
    wire mbox_wr_en;
    wire [31:0] mbox_wr_data;
    wire mbox_full;
    wire [3:0] mbox_level_w;
    reg  [31:0] cfg_regs [0:15];
    integer ci;
    initial for(ci=0;ci<16;ci=ci+1) cfg_regs[ci]=32'h0;
    // SoC config reg write (from xb_s2)
    assign xb_s2_awready = 1'b1;
    assign xb_s2_wready  = 1'b1;
    assign xb_s2_bvalid  = xb_s2_wvalid;
    assign xb_s2_bresp   = 2'b00;
    assign xb_s2_arready = 1'b1;
    assign xb_s2_rresp   = 2'b00;
    reg [31:0] cfg_rdata_r; reg cfg_rvalid_r;
    assign xb_s2_rdata  = cfg_rdata_r;
    assign xb_s2_rvalid = cfg_rvalid_r;
    assign mbox_wr_en   = xb_s2_awvalid && xb_s2_wvalid && (xb_s2_awaddr[7:2]==6'h0);
    assign mbox_wr_data = xb_s2_wdata;
    always @(posedge clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            for(ci=0;ci<16;ci=ci+1) cfg_regs[ci]<=32'h0;
            cfg_rdata_r<=0; cfg_rvalid_r<=0;
        end else begin
            if (xb_s2_awvalid && xb_s2_wvalid)
                cfg_regs[xb_s2_awaddr[5:2]] <= xb_s2_wdata;
            cfg_rvalid_r <= xb_s2_arvalid;
            case (xb_s2_araddr[5:2])
                4'h0: cfg_rdata_r <= mbox_wr_data;
                4'h1: cfg_rdata_r <= {26'h0, mbox_full, mbox_empty, mbox_level_w};
                4'h2: cfg_rdata_r <= u_perf.cnt0; // PERF_CNT0 at 0x08
                4'h3: cfg_rdata_r <= u_perf.cnt1; // PERF_CNT1 at 0x0C
                4'h4: cfg_rdata_r <= u_perf.cnt2; // PERF_CNT2 at 0x10
                4'h5: cfg_rdata_r <= u_perf.cnt3; // PERF_CNT3 at 0x14
                default: cfg_rdata_r <= 32'h0;
            endcase
        end
    end
    async_fifo_mbox u_mbox (
        .wr_clk(clk), .wr_rst_n(sys_rst_n), .wr_en(mbox_wr_en),
        .din(mbox_wr_data), .full(mbox_full),
        .rd_clk(dsp_clk), .rd_rst_n(sys_rst_n), .rd_en(mbox_rd_en),
        .dout(mbox_dout), .empty(mbox_empty)
    );
    assign mbox_level_w = 4'h0;

    // -------------------------------------------------------------------
    // Performance counter
    // -------------------------------------------------------------------
    wire perf_event0 = ni00_tl_a_valid;
    wire perf_event1 = dma0_irq_w;
    wire perf_event2 = dma1_irq_w;
    wire perf_event3 = aes0_done | aes1_done | aes2_done | aes3_done;
    // Wire perf counter APB port: cfg write to 0xF001_0018 (PERF_CTRL)
    // bit[0]=enable (not used in this impl), bit[1]=clear (pwrite to paddr=0)
    wire perf_psel    = xb_s2_awvalid && xb_s2_wvalid && (xb_s2_awaddr[7:2]==6'h6);
    wire perf_pwrite  = perf_psel;
    wire perf_penable = perf_psel;
    wire [11:0] perf_paddr = 12'h0; // write to addr 0 clears all counters
    wire [31:0] perf_pwdata = xb_s2_wdata;
    wire [31:0] perf_prdata;
    perf_counter u_perf (
        .pclk(clk), .presetn(sys_rst_n),
        .event_0(perf_event0), .event_1(perf_event1),
        .event_2(perf_event2), .event_3(perf_event3),
        .psel(perf_psel), .penable(perf_penable), .pwrite(perf_pwrite),
        .paddr(perf_paddr), .pwdata(perf_pwdata), .prdata(perf_prdata),
        .pready(), .pslverr()
    );

endmodule
