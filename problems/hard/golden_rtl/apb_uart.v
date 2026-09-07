// =============================================================================
// Module: apb_uart
// Desc  : APB3 full-duplex UART, FIFO=16, default_div=26
// NXP ICLAD 2026 RTL Gen Library
// =============================================================================
`timescale 1ns/1ps

module apb_uart #(parameter FIFO_DEPTH=16, parameter DEFAULT_DIV=26)(
    input  wire        pclk, presetn,
    input  wire        psel, penable, pwrite,
    input  wire [11:0] paddr, input wire [31:0] pwdata,
    output reg  [31:0] prdata, output wire pready, pslverr,
    output reg         uart_tx, input wire uart_rx,
    input  wire        cts_n, output wire rts_n, output wire irq
);
    assign pready=1; assign pslverr=0;
    localparam ABITS=4; localparam CBITS=5;
    reg [15:0] baud_div; reg tx_en,rx_en,par_en,par_odd,stop2;
    reg [7:0]  irq_en, irq_stat;
    reg [7:0] tx_mem[0:FIFO_DEPTH-1]; reg [CBITS-1:0] tx_wp,tx_rp;
    wire tx_full=((tx_wp-tx_rp)==FIFO_DEPTH[CBITS-1:0]); wire tx_empty=(tx_wp==tx_rp);
    reg [7:0] rx_mem[0:FIFO_DEPTH-1]; reg [CBITS-1:0] rx_wp,rx_rp;
    wire rx_full=((rx_wp-rx_rp)==FIFO_DEPTH[CBITS-1:0]); wire rx_empty=(rx_wp==rx_rp);
    reg [15:0] bcnt; reg btick;
    always @(posedge pclk or negedge presetn)
        if (!presetn) begin bcnt<=0; btick<=0; end
        else if (bcnt==baud_div) begin bcnt<=0; btick<=1; end
        else begin bcnt<=bcnt+1; btick<=0; end
    reg [2:0] tx_st; reg [7:0] tx_sr; reg [3:0] tx_sub; reg [2:0] tx_bc;
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            tx_st<=0; tx_sr<=8'hFF; tx_sub<=0; tx_bc<=0;
            tx_wp<=0; tx_rp<=0; uart_tx<=1;
        end else begin
            if (psel&&penable&&pwrite&&paddr==12'h000&&!tx_full) begin
                tx_mem[tx_wp[ABITS-1:0]]<=pwdata[7:0]; tx_wp<=tx_wp+1; end
            if (btick&&tx_en) begin
                tx_sub<=tx_sub+1;
                if (tx_sub==4'hF) case(tx_st)
                    0: begin uart_tx<=1; if(!tx_empty&&!cts_n) begin
                           tx_sr<=tx_mem[tx_rp[ABITS-1:0]]; tx_rp<=tx_rp+1;
                           uart_tx<=0; tx_st<=1; end end
                    1: begin uart_tx<=tx_sr[0]; tx_sr<={1'b1,tx_sr[7:1]}; tx_bc<=1; tx_st<=2; end
                    2: begin if(tx_bc==7) begin uart_tx<=tx_sr[0];
                                 tx_st<=par_en?3:4; end
                             else begin uart_tx<=tx_sr[0]; tx_sr<={1'b1,tx_sr[7:1]};
                                  tx_bc<=tx_bc+1; end end
                    3: begin uart_tx<=^tx_sr^par_odd; tx_st<=4; end
                    4: begin uart_tx<=1; tx_st<=stop2?5:0; end
                    5: begin uart_tx<=1; tx_st<=0; end
                    default: tx_st<=0;
                endcase
            end
        end
    end
    assign rts_n=rx_full;
    reg [2:0] rx_sync; wire rx_in=rx_sync[2];
    reg [2:0] rx_st; reg [7:0] rx_sr; reg [3:0] rx_sub; reg [2:0] rx_bc;
    reg frame_err,par_err,overrun;
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            rx_sync<=3'b111; rx_st<=0; rx_sr<=0; rx_sub<=0; rx_bc<=0;
            rx_wp<=0; rx_rp<=0; frame_err<=0; par_err<=0; overrun<=0;
        end else begin
            rx_sync<={rx_sync[1:0],uart_rx};
            if (psel&&penable&&!pwrite&&paddr==12'h004&&!rx_empty) rx_rp<=rx_rp+1;
            if (btick&&rx_en) begin
                rx_sub<=rx_sub+1;
                case(rx_st)
                    0: if(!rx_in) begin rx_st<=1; rx_sub<=0; end
                    1: if(rx_sub==7) begin if(!rx_in) begin rx_st<=2; rx_bc<=0; rx_sub<=0; end
                                          else rx_st<=0; end
                    2: if(rx_sub==15) begin rx_sr<={rx_in,rx_sr[7:1]}; rx_sub<=0;
                           rx_bc<=rx_bc+1; if(rx_bc==7) rx_st<=par_en?3:4; end
                    3: if(rx_sub==15) begin par_err<=(^rx_sr^par_odd)!=rx_in;
                           rx_st<=4; rx_sub<=0; end
                    4: if(rx_sub==15) begin frame_err<=!rx_in;
                           if(rx_in) begin if(!rx_full) begin
                               rx_mem[rx_wp[ABITS-1:0]]<=rx_sr; rx_wp<=rx_wp+1;
                           end else overrun<=1; end rx_st<=0; end
                    default: rx_st<=0;
                endcase
            end
        end
    end
    wire [7:0] status={cts_n,overrun,par_err,frame_err,rx_empty,rx_full,tx_empty,tx_full};
    always @(posedge pclk or negedge presetn)
        if (!presetn) begin irq_en<=0; irq_stat<=0; baud_div<=DEFAULT_DIV[15:0];
            tx_en<=1; rx_en<=1; par_en<=0; par_odd<=0; stop2<=0;
        end else begin
            irq_stat<=irq_stat|(status&irq_en);
            if (psel&&penable&&pwrite) case(paddr)
                12'h00C: begin tx_en<=pwdata[0]; rx_en<=pwdata[1]; par_en<=pwdata[2];
                                par_odd<=pwdata[3]; stop2<=pwdata[4]; baud_div<=pwdata[23:8]; end
                12'h010: irq_en<=pwdata[7:0];
                12'h014: irq_stat<=irq_stat&~pwdata[7:0];
                default: ;
            endcase
        end
    assign irq=|(irq_stat&irq_en);
    always @(*) case(paddr)
        12'h000: prdata=32'h0;
        12'h004: prdata=rx_empty?32'h0:{24'h0,rx_mem[rx_rp[ABITS-1:0]]};
        12'h008: prdata={24'h0,status};
        12'h00C: prdata={8'h0,baud_div,3'h0,stop2,par_odd,par_en,rx_en,tx_en};
        12'h010: prdata={24'h0,irq_en};
        12'h014: prdata={24'h0,irq_stat};
        default: prdata=32'hDEAD_BEEF;
    endcase
endmodule
