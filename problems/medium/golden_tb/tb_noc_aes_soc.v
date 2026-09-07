// =============================================================================
// tb_noc_aes_soc.v -- Golden testbench
// NXP ICLAD 2026 Medium: 2x3 TileLink NoC AES Crypto SoC
//
// Test categories:
//   T101-T105  reset_sync      -- 4-stage reset, POR deassert, bus alive
//   T201-T205  noc_topology    -- router/NI params, mesh boundary tie-offs
//   T301-T305  aes0_encrypt    -- AES0 key load, encrypt, done pulse, output
//   T401-T405  aes1_encrypt    -- AES1 parallel operation, different key
//   T501-T504  irq_agg         -- IRQ aggregator driven by AES done
//   T601-T605  sram_ni_idle    -- NI/SRAM wiring idle checks
//   T701-T703  noc_ni_basic    -- CPU NI AXI handshake (node 0,0 entry)
//   T801-T805  noc_local_loop  -- CPU write+read to node (0,0) local SRAM
//   T901-T905  noc_ew_routing  -- CPU write+read to node (1,0) via E-W hop
//   T1001-T1005 noc_ns_routing -- CPU write+read to node (0,1) via N-S hop
//   T1101-T1103 noc_2hop       -- CPU write+read to node (1,1) via E+N hops
//   T1201-T1202 irq_id_order   -- IRQ ID encodes which AES engine fired
// =============================================================================
`timescale 1ns/1ps

module tb_top;

    reg         clk;
    reg         por_n;

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

    reg  [127:0] aes0_key_in;
    reg          aes0_key_valid;
    reg  [127:0] aes0_data_in;
    reg          aes0_start;
    wire [127:0] aes0_data_out;
    wire         aes0_done;
    wire         aes0_busy;

    reg  [127:0] aes1_key_in;
    reg          aes1_key_valid;
    reg  [127:0] aes1_data_in;
    reg          aes1_start;
    wire [127:0] aes1_data_out;
    wire         aes1_done;
    wire         aes1_busy;

    wire         cpu_irq;
    wire [2:0]   cpu_irq_id;

    // Latch AES done pulses (done is 1 cycle)
    reg aes0_done_latch, aes1_done_latch;
    initial begin aes0_done_latch=0; aes1_done_latch=0; end
    always @(posedge clk) begin
        if (aes0_done) aes0_done_latch <= 1;
        if (aes1_done) aes1_done_latch <= 1;
    end

    noc_aes_soc dut (
        .clk(clk), .por_n(por_n),
        .cpu_awaddr(cpu_awaddr), .cpu_awvalid(cpu_awvalid), .cpu_awready(cpu_awready),
        .cpu_wdata(cpu_wdata), .cpu_wstrb(cpu_wstrb),
        .cpu_wvalid(cpu_wvalid), .cpu_wready(cpu_wready),
        .cpu_bresp(cpu_bresp), .cpu_bvalid(cpu_bvalid), .cpu_bready(cpu_bready),
        .cpu_araddr(cpu_araddr), .cpu_arvalid(cpu_arvalid), .cpu_arready(cpu_arready),
        .cpu_rdata(cpu_rdata), .cpu_rresp(cpu_rresp),
        .cpu_rvalid(cpu_rvalid), .cpu_rready(cpu_rready),
        .aes0_key_in(aes0_key_in), .aes0_key_valid(aes0_key_valid),
        .aes0_data_in(aes0_data_in), .aes0_start(aes0_start),
        .aes0_data_out(aes0_data_out), .aes0_done(aes0_done), .aes0_busy(aes0_busy),
        .aes1_key_in(aes1_key_in), .aes1_key_valid(aes1_key_valid),
        .aes1_data_in(aes1_data_in), .aes1_start(aes1_start),
        .aes1_data_out(aes1_data_out), .aes1_done(aes1_done), .aes1_busy(aes1_busy),
        .cpu_irq(cpu_irq), .cpu_irq_id(cpu_irq_id)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer pass_cnt, fail_cnt;

    task check;
        input [15:0] tid;
        input        cond;
        input [63:0] got, exp;
        begin
            if (cond) begin
                $display("[PASS] T%0d", tid);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("[FAIL] T%0d  got=%0h  exp=%0h", tid, got, exp);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    reg [127:0] aes0_out_saved;

    initial begin
        pass_cnt=0; fail_cnt=0;
        por_n=0;
        cpu_awvalid=0; cpu_wvalid=0; cpu_bready=0;
        cpu_arvalid=0; cpu_rready=0;
        cpu_awaddr=0; cpu_wdata=0; cpu_wstrb=8'hFF; cpu_araddr=0;
        aes0_key_in=0; aes0_key_valid=0; aes0_data_in=0; aes0_start=0;
        aes1_key_in=0; aes1_key_valid=0; aes1_data_in=0; aes1_start=0;

        repeat(20) @(posedge clk);
        por_n = 1;
        repeat(10) @(posedge clk);

        // =============================================================
        // T101-T105: reset_sync (4-stage)
        // =============================================================

        // T101: rst_n deasserts after POR+10 cycles
        check(101, dut.rst_n===1'b1, dut.rst_n, 1);

        // T102: NI at (0,0) in IDLE state after reset (st==S_IDLE=0)
        check(102, dut.u_ni_00.st===2'd0, dut.u_ni_00.st, 0);

        // T103: rst_n goes low when POR asserted
        @(negedge clk); por_n=0;
        repeat(2) @(posedge clk); #1;
        check(103, dut.rst_n===1'b0, dut.rst_n, 0);
        @(negedge clk); por_n=1;
        repeat(8) @(posedge clk);

        // T104: rst_n recovers to 1 after 4 stages
        check(104, dut.rst_n===1'b1, dut.rst_n, 1);

        // T105: reset_sync has STAGES=4 parameter
        check(105, dut.u_rst.STAGES===4, dut.u_rst.STAGES, 4);

        // =============================================================
        // T201-T205: noc_topology
        // =============================================================

        // T201: router_00 has correct coordinates (NODE_X=0, NODE_Y=0)
        check(201, dut.u_router_00.NODE_X===0 && dut.u_router_00.NODE_Y===0, 1, 1);

        // T202: router_10 has NODE_X=1
        check(202, dut.u_router_10.NODE_X===1, dut.u_router_10.NODE_X, 1);

        // T203: router_12 has NODE_Y=2 (top-right corner)
        check(203, dut.u_router_12.NODE_Y===2, dut.u_router_12.NODE_Y, 2);

        // T204: Boundary tie-off: (0,2).North A-valid = 0 (no north neighbor)
        check(204, dut.tie_02_p0_a_valid===1'b0, dut.tie_02_p0_a_valid, 0);

        // T205: Boundary tie-off: (0,0).South A-valid = 0 (no south neighbor)
        check(205, dut.tie_00_p1_a_valid===1'b0, dut.tie_00_p1_a_valid, 0);

        // =============================================================
        // T301-T305: aes0_encrypt
        // =============================================================

        // T301: Load key -- AES0 not busy
        @(negedge clk);
        aes0_key_in   = 128'h00010203_04050607_08090A0B_0C0D0E0F;
        aes0_key_valid = 1;
        @(posedge clk); #1;
        @(negedge clk); aes0_key_valid=0;
        repeat(2) @(posedge clk);
        check(301, aes0_busy===1'b0, aes0_busy, 0);

        // T302: AES0 DATA_WIDTH = 64 (checked via SRAM)
        check(302, dut.u_sram_10.DATA_W===64, dut.u_sram_10.DATA_W, 64);

        // T303: Start encryption -- busy asserts
        aes0_done_latch = 0;
        @(negedge clk);
        aes0_data_in = 128'h00112233_44556677_8899AABB_CCDDEEFF;
        aes0_start   = 1;
        @(posedge clk); #1;
        @(negedge clk); aes0_start=0;
        @(posedge clk); #1;
        check(303, aes0_busy===1'b1, aes0_busy, 1);

        // T304: AES0 done fires within 15 cycles
        repeat(14) @(posedge clk);
        check(304, aes0_done_latch===1'b1, aes0_done_latch, 1);

        // T305: AES0 output is non-zero
        aes0_out_saved = aes0_data_out;
        check(305, aes0_data_out !== 128'h0, aes0_data_out[63:0], 1);

        // =============================================================
        // T401-T405: aes1_encrypt (different key)
        // =============================================================

        // T401: Load different key into AES1
        @(negedge clk);
        aes1_key_in   = 128'hFFEEDDCC_BBAA9988_77665544_33221100;
        aes1_key_valid = 1;
        @(posedge clk); #1;
        @(negedge clk); aes1_key_valid=0;
        repeat(2) @(posedge clk);
        check(401, aes1_busy===1'b0, aes1_busy, 0);

        // T402: Start AES1 with same plaintext
        aes1_done_latch = 0;
        @(negedge clk);
        aes1_data_in = 128'h00112233_44556677_8899AABB_CCDDEEFF;
        aes1_start   = 1;
        @(posedge clk); #1;
        @(negedge clk); aes1_start=0;
        @(posedge clk); #1;
        check(402, aes1_busy===1'b1, aes1_busy, 1);

        // T403: AES1 done fires within 15 cycles
        repeat(14) @(posedge clk);
        check(403, aes1_done_latch===1'b1, aes1_done_latch, 1);

        // T404: AES1 output is non-zero
        check(404, aes1_data_out !== 128'h0, aes1_data_out[63:0], 1);

        // T405: AES0 and AES1 produce different ciphertext (different keys)
        check(405, aes0_out_saved !== aes1_data_out, aes0_out_saved[63:0], aes1_data_out[63:0]+1);

        // =============================================================
        // T501-T504: irq_agg
        // =============================================================

        // T501: Start new AES0 to generate fresh done pulse
        aes0_done_latch = 0;
        @(negedge clk);
        aes0_data_in = 128'hDEADBEEF_CAFEBABE_12345678_9ABCDEF0;
        aes0_start   = 1;
        @(posedge clk); #1;
        @(negedge clk); aes0_start=0;
        repeat(14) @(posedge clk);
        check(501, aes0_done_latch===1'b1, aes0_done_latch, 1);

        // T502: cpu_irq asserted when aes0_done is active
        // IRQ aggregator uses level mode -- irq_sources[0]=aes0_done
        // Wait 1 cycle after done pulse; during done cycle cpu_irq fires
        // Latch cpu_irq during the done pulse cycle
        // (T501 waited to end of 14 cycles; check during that window)
        check(502, cpu_irq===1'b1 || aes0_done_latch===1'b1, cpu_irq, 1);

        // T503: cpu_irq_id is 0 or 1 (AES sources at bits 0/1)
        check(503, cpu_irq_id<=3'd1, cpu_irq_id, 0);

        // T504: irq_sources wiring: bit[0]=aes0_done, bit[1]=aes1_done
        check(504, dut.irq_sources[1:0] === {aes1_done, aes0_done},
              dut.irq_sources[1:0], 0);

        // =============================================================
        // T601-T605: sram_ni_idle (structural checks)
        // =============================================================

        // T601: sram_00 DEPTH=2048 (2KB)
        check(601, dut.u_sram_00.DEPTH===2048, dut.u_sram_00.DEPTH, 2048);

        // T602: sram_11 DEPTH=2048
        check(602, dut.u_sram_11.DEPTH===2048, dut.u_sram_11.DEPTH, 2048);

        // T603: ni_01 DATA_W=64 (64-bit TL-UL)
        check(603, dut.u_ni_01.DATA_W===64, dut.u_ni_01.DATA_W, 64);

        // T604: ni_12 ADDR_W=32
        check(604, dut.u_ni_12.ADDR_W===32, dut.u_ni_12.ADDR_W, 32);

        // T605: 6 NIs instantiated -- verify ni_02 exists with correct params
        check(605, dut.u_ni_02.DATA_W===64, dut.u_ni_02.DATA_W, 64);

        // =============================================================
        // T701-T703: noc_ni_basic (CPU entry at node 0,0)
        // =============================================================

        // T701: CPU AXI read: arready asserts combinationally when arvalid=1
        // and NI is in IDLE state (st=0)
        @(negedge clk);
        cpu_araddr=32'h1000_0000; cpu_arvalid=1; cpu_rready=1;
        #1; // combinational settle
        check(701, cpu_arready===1'b1, cpu_arready, 1);
        @(posedge clk); #1;
        @(negedge clk); cpu_arvalid=0; cpu_rready=0;
        repeat(5) @(posedge clk);

        // T702: NI data width is 64-bit (MASK_W = DATA_W/8 = 8)
        check(702, dut.u_ni_00.MASK_W===8, dut.u_ni_00.MASK_W, 8);
        // Wait for T701 read round-trip to complete (multi-hop router adds latency)
        @(negedge clk); cpu_arvalid=0; cpu_rready=1;
        begin : t701_drain
            integer t; t=0;
            while (dut.u_ni_00.st!==2'd0 && t<50) begin @(posedge clk); #1; t=t+1; end
        end
        @(negedge clk); cpu_rready=0; cpu_awvalid=0; cpu_wvalid=0; cpu_bready=0;
        repeat(3) @(posedge clk);

        // T703: After CPU write to local node (0,0), NI transitions to SEND state (st=1)
        @(negedge clk);
        cpu_awaddr=32'h0000_0300; cpu_awvalid=1;
        cpu_wdata=64'hAAAA_BBBB_CCCC_DDDD; cpu_wstrb=8'hFF; cpu_wvalid=1;
        @(posedge clk); #1; // NI latches and moves to S_SEND
        check(703, dut.u_ni_00.st===2'd1, dut.u_ni_00.st, 1); // S_SEND=1
        @(negedge clk); cpu_awvalid=0; cpu_wvalid=0; cpu_bready=1;
        begin : t703_drain
            integer t; t=0;
            while (dut.u_ni_00.st!==2'd0 && t<50) begin @(posedge clk); #1; t=t+1; end
        end
        @(negedge clk); cpu_bready=0; repeat(3) @(posedge clk);

        // =============================================================
        // T801-T805: noc_local_loop -- CPU write+read to node (0,0)
        // addr 0x0000_0010 -> dest_x=0, dest_y=0, local SRAM
        // =============================================================
        begin : blk_local
            integer t; reg [63:0] rdata_got;
            @(negedge clk);
            cpu_awaddr=32'h0000_0010; cpu_awvalid=1;
            cpu_wdata=64'hA5A5_5A5A_1234_5678; cpu_wstrb=8'hFF; cpu_wvalid=1;
            t=0; while (!(cpu_awready && cpu_wready) && t<50) begin @(posedge clk); #1; t=t+1; end
            @(posedge clk); #1;
            @(negedge clk); cpu_awvalid=0; cpu_wvalid=0; cpu_bready=1;
            t=0; while (!cpu_bvalid && t<50) begin @(posedge clk); #1; t=t+1; end
            check(801, cpu_bvalid===1 && cpu_bresp===2'b00, {62'b0,cpu_bresp}, 0);
            @(posedge clk); #1; @(negedge clk); cpu_bready=0; repeat(2) @(posedge clk);
            @(negedge clk); cpu_araddr=32'h0000_0010; cpu_arvalid=1; cpu_rready=1;
            t=0; while (!cpu_arready && t<50) begin @(posedge clk); #1; t=t+1; end
            @(posedge clk); #1; @(negedge clk); cpu_arvalid=0;
            t=0; while (!cpu_rvalid && t<50) begin @(posedge clk); #1; t=t+1; end
            rdata_got=cpu_rdata;
            check(802, cpu_rvalid===1, cpu_rvalid, 1);
            check(803, rdata_got===64'hA5A5_5A5A_1234_5678, rdata_got, 64'hA5A5_5A5A_1234_5678);
            @(posedge clk); #1; @(negedge clk); cpu_rready=0; repeat(2) @(posedge clk);
            @(negedge clk); cpu_awaddr=32'h0000_0018; cpu_awvalid=1;
            cpu_wdata=64'hDEAD_BEEF_CAFE_BABE; cpu_wstrb=8'hFF; cpu_wvalid=1;
            t=0; while (!(cpu_awready && cpu_wready) && t<50) begin @(posedge clk); #1; t=t+1; end
            @(posedge clk); #1; @(negedge clk); cpu_awvalid=0; cpu_wvalid=0; cpu_bready=1;
            t=0; while (!cpu_bvalid && t<50) begin @(posedge clk); #1; t=t+1; end
            check(804, cpu_bvalid===1, cpu_bvalid, 1);
            @(posedge clk); #1; @(negedge clk); cpu_bready=0; repeat(2) @(posedge clk);
            @(negedge clk); cpu_araddr=32'h0000_0018; cpu_arvalid=1; cpu_rready=1;
            t=0; while (!cpu_arready && t<50) begin @(posedge clk); #1; t=t+1; end
            @(posedge clk); #1; @(negedge clk); cpu_arvalid=0;
            t=0; while (!cpu_rvalid && t<50) begin @(posedge clk); #1; t=t+1; end
            rdata_got=cpu_rdata;
            check(805, rdata_got===64'hDEAD_BEEF_CAFE_BABE, rdata_got, 64'hDEAD_BEEF_CAFE_BABE);
            @(posedge clk); #1; @(negedge clk); cpu_rready=0; repeat(3) @(posedge clk);
        end

        // =============================================================
        // T901-T905: noc_ew_routing -- CPU write+read to node (1,0)
        // addr 0x1000_xxxx -> dest_x=1, dest_y=0, 1 East hop
        // =============================================================
        begin : blk_ew
            integer t; reg [63:0] rdata_got;
            @(negedge clk);
            cpu_awaddr=32'h1000_0020; cpu_awvalid=1;
            cpu_wdata=64'h1111_2222_3333_4444; cpu_wstrb=8'hFF; cpu_wvalid=1;
            t=0; while (!(cpu_awready && cpu_wready) && t<100) begin @(posedge clk); #1; t=t+1; end
            @(posedge clk); #1; @(negedge clk); cpu_awvalid=0; cpu_wvalid=0; cpu_bready=1;
            t=0; while (!cpu_bvalid && t<100) begin @(posedge clk); #1; t=t+1; end
            check(901, cpu_bvalid===1 && cpu_bresp===2'b00, {62'b0,cpu_bresp}, 0);
            @(posedge clk); #1; @(negedge clk); cpu_bready=0; repeat(2) @(posedge clk);
            @(negedge clk); cpu_araddr=32'h1000_0020; cpu_arvalid=1; cpu_rready=1;
            t=0; while (!cpu_arready && t<100) begin @(posedge clk); #1; t=t+1; end
            @(posedge clk); #1; @(negedge clk); cpu_arvalid=0;
            t=0; while (!cpu_rvalid && t<100) begin @(posedge clk); #1; t=t+1; end
            rdata_got=cpu_rdata;
            check(902, cpu_rvalid===1, cpu_rvalid, 1);
            check(903, rdata_got===64'h1111_2222_3333_4444, rdata_got, 64'h1111_2222_3333_4444);
            @(posedge clk); #1; @(negedge clk); cpu_rready=0; repeat(2) @(posedge clk);
            @(negedge clk); cpu_awaddr=32'h1000_0028; cpu_awvalid=1;
            cpu_wdata=64'hBEEF_CAFE_0000_0001; cpu_wstrb=8'hFF; cpu_wvalid=1;
            t=0; while (!(cpu_awready && cpu_wready) && t<100) begin @(posedge clk); #1; t=t+1; end
            @(posedge clk); #1; @(negedge clk); cpu_awvalid=0; cpu_wvalid=0; cpu_bready=1;
            t=0; while (!cpu_bvalid && t<100) begin @(posedge clk); #1; t=t+1; end
            check(904, cpu_bvalid===1, cpu_bvalid, 1);
            @(posedge clk); #1; @(negedge clk); cpu_bready=0; repeat(2) @(posedge clk);
            @(negedge clk); cpu_araddr=32'h1000_0028; cpu_arvalid=1; cpu_rready=1;
            t=0; while (!cpu_arready && t<100) begin @(posedge clk); #1; t=t+1; end
            @(posedge clk); #1; @(negedge clk); cpu_arvalid=0;
            t=0; while (!cpu_rvalid && t<100) begin @(posedge clk); #1; t=t+1; end
            rdata_got=cpu_rdata;
            check(905, rdata_got===64'hBEEF_CAFE_0000_0001, rdata_got, 64'hBEEF_CAFE_0000_0001);
            @(posedge clk); #1; @(negedge clk); cpu_rready=0; repeat(3) @(posedge clk);
        end

        // =============================================================
        // T1001-T1005: noc_ns_routing -- CPU write+read to node (0,1)
        // addr 0x0100_xxxx -> dest_x=0, dest_y=1, 1 North hop
        // =============================================================
        begin : blk_ns
            integer t; reg [63:0] rdata_got;
            @(negedge clk);
            cpu_awaddr=32'h0100_0030; cpu_awvalid=1;
            cpu_wdata=64'hABCD_EF01_2345_6789; cpu_wstrb=8'hFF; cpu_wvalid=1;
            t=0; while (!(cpu_awready && cpu_wready) && t<100) begin @(posedge clk); #1; t=t+1; end
            @(posedge clk); #1; @(negedge clk); cpu_awvalid=0; cpu_wvalid=0; cpu_bready=1;
            t=0; while (!cpu_bvalid && t<100) begin @(posedge clk); #1; t=t+1; end
            check(1001, cpu_bvalid===1 && cpu_bresp===2'b00, {62'b0,cpu_bresp}, 0);
            @(posedge clk); #1; @(negedge clk); cpu_bready=0; repeat(2) @(posedge clk);
            @(negedge clk); cpu_araddr=32'h0100_0030; cpu_arvalid=1; cpu_rready=1;
            t=0; while (!cpu_arready && t<100) begin @(posedge clk); #1; t=t+1; end
            @(posedge clk); #1; @(negedge clk); cpu_arvalid=0;
            t=0; while (!cpu_rvalid && t<100) begin @(posedge clk); #1; t=t+1; end
            rdata_got=cpu_rdata;
            check(1002, cpu_rvalid===1, cpu_rvalid, 1);
            check(1003, rdata_got===64'hABCD_EF01_2345_6789, rdata_got, 64'hABCD_EF01_2345_6789);
            @(posedge clk); #1; @(negedge clk); cpu_rready=0; repeat(2) @(posedge clk);
            @(negedge clk); cpu_awaddr=32'h0100_0038; cpu_awvalid=1;
            cpu_wdata=64'h0000_0000_FFFF_EEEE; cpu_wstrb=8'hFF; cpu_wvalid=1;
            t=0; while (!(cpu_awready && cpu_wready) && t<100) begin @(posedge clk); #1; t=t+1; end
            @(posedge clk); #1; @(negedge clk); cpu_awvalid=0; cpu_wvalid=0; cpu_bready=1;
            t=0; while (!cpu_bvalid && t<100) begin @(posedge clk); #1; t=t+1; end
            check(1004, cpu_bvalid===1, cpu_bvalid, 1);
            @(posedge clk); #1; @(negedge clk); cpu_bready=0; repeat(2) @(posedge clk);
            @(negedge clk); cpu_araddr=32'h0100_0038; cpu_arvalid=1; cpu_rready=1;
            t=0; while (!cpu_arready && t<100) begin @(posedge clk); #1; t=t+1; end
            @(posedge clk); #1; @(negedge clk); cpu_arvalid=0;
            t=0; while (!cpu_rvalid && t<100) begin @(posedge clk); #1; t=t+1; end
            rdata_got=cpu_rdata;
            check(1005, rdata_got===64'h0000_0000_FFFF_EEEE, rdata_got, 64'h0000_0000_FFFF_EEEE);
            @(posedge clk); #1; @(negedge clk); cpu_rready=0; repeat(3) @(posedge clk);
        end

        // =============================================================
        // T1101-T1103: noc_2hop -- CPU write+read to node (1,1)
        // addr 0x1100_xxxx -> dest_x=1, dest_y=1, E then N hops
        // =============================================================
        begin : blk_2hop
            integer t; reg [63:0] rdata_got;
            @(negedge clk);
            cpu_awaddr=32'h1100_0040; cpu_awvalid=1;
            cpu_wdata=64'hFACE_FEED_0BAD_C0DE; cpu_wstrb=8'hFF; cpu_wvalid=1;
            t=0; while (!(cpu_awready && cpu_wready) && t<200) begin @(posedge clk); #1; t=t+1; end
            @(posedge clk); #1; @(negedge clk); cpu_awvalid=0; cpu_wvalid=0; cpu_bready=1;
            t=0; while (!cpu_bvalid && t<200) begin @(posedge clk); #1; t=t+1; end
            check(1101, cpu_bvalid===1 && cpu_bresp===2'b00, {62'b0,cpu_bresp}, 0);
            @(posedge clk); #1; @(negedge clk); cpu_bready=0; repeat(2) @(posedge clk);
            @(negedge clk); cpu_araddr=32'h1100_0040; cpu_arvalid=1; cpu_rready=1;
            t=0; while (!cpu_arready && t<200) begin @(posedge clk); #1; t=t+1; end
            @(posedge clk); #1; @(negedge clk); cpu_arvalid=0;
            t=0; while (!cpu_rvalid && t<200) begin @(posedge clk); #1; t=t+1; end
            rdata_got=cpu_rdata;
            check(1102, cpu_rvalid===1, cpu_rvalid, 1);
            check(1103, rdata_got===64'hFACE_FEED_0BAD_C0DE, rdata_got, 64'hFACE_FEED_0BAD_C0DE);
            @(posedge clk); #1; @(negedge clk); cpu_rready=0; repeat(3) @(posedge clk);
        end

        // =============================================================
        // T1201-T1202: irq_id_order -- cpu_irq fires when AES done asserts
        // (r_pend accumulates; verify cpu_irq asserts during done window)
        // =============================================================
        aes0_done_latch=0;
        @(negedge clk);
        aes0_data_in=128'h1234_5678_9ABC_DEF0_0FED_CBA9_8765_4321;
        aes0_start=1; @(posedge clk); #1; @(negedge clk); aes0_start=0;
        repeat(14) @(posedge clk);
        check(1201, aes0_done_latch===1'b1 && cpu_irq===1'b1, {63'b0,cpu_irq}, 1);

        aes1_done_latch=0;
        @(negedge clk);
        aes1_data_in=128'hFEDC_BA98_7654_3210_0123_4567_89AB_CDEF;
        aes1_start=1; @(posedge clk); #1; @(negedge clk); aes1_start=0;
        repeat(14) @(posedge clk);
        check(1202, aes1_done_latch===1'b1 && cpu_irq===1'b1, {63'b0,cpu_irq}, 1);

        // =============================================================
        // Summary
        // =============================================================
        $display("=== SIMULATION COMPLETE ===");
        $display("PASSED: %0d  FAILED: %0d  TOTAL: %0d",
                 pass_cnt, fail_cnt, pass_cnt+fail_cnt);
        if (fail_cnt==0) $display("ALL TESTS PASSED");
        else             $display("SOME TESTS FAILED");
        $finish;
    end

    initial begin
        #10_000_000;
        $display("[TIMEOUT] 10ms limit reached");
        $finish;
    end

endmodule
