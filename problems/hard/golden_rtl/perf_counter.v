// =============================================================================
// Module: perf_counter
// Desc  : Perf counter 4ch 32b
// NXP ICLAD 2026 RTL Gen Library
// =============================================================================
`timescale 1ns/1ps

module perf_counter (
    input  wire pclk, presetn,
    input  wire        event_0,
    input  wire        event_1,
    input  wire        event_2,
    input  wire        event_3,
    input  wire psel, penable, pwrite,
    input  wire [11:0] paddr, input  wire [31:0] pwdata,
    output reg  [31:0] prdata, output wire pready, pslverr
);
    assign pready=1; assign pslverr=0;
    reg [31:0] cnt0;
    reg [31:0] cnt1;
    reg [31:0] cnt2;
    reg [31:0] cnt3;
    always @(posedge pclk or negedge presetn)
        if (!presetn) begin             cnt0<=0;
            cnt1<=0;
            cnt2<=0;
            cnt3<=0; end
        else begin
            if(event_0) cnt0<=cnt0+1;
            if(event_1) cnt1<=cnt1+1;
            if(event_2) cnt2<=cnt2+1;
            if(event_3) cnt3<=cnt3+1;
            if (psel&&penable&&pwrite&&paddr==0) begin             cnt0<=0;
            cnt1<=0;
            cnt2<=0;
            cnt3<=0; end
        end
    always @(*) case(paddr)
        0: prdata=cnt0;
        4: prdata=cnt1;
        8: prdata=cnt2;
        12: prdata=cnt3;
        default: prdata=32'hDEAD_BEEF;
    endcase
endmodule
