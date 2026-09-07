// =============================================================================
// Module: apb_watchdog
// Desc  : APB3 two-stage watchdog: stage1=IRQ, stage2=reset, window mode, unlock key
// NXP ICLAD 2026 RTL Gen Library
// =============================================================================
`timescale 1ns/1ps

module apb_watchdog #(
    parameter DEFAULT_LOAD1 = 32'h0001_0000,
    parameter DEFAULT_LOAD2 = 32'h0000_8000
)(
    input  wire        pclk, presetn,
    input  wire        psel, penable, pwrite,
    input  wire [11:0] paddr, input wire [31:0] pwdata,
    output reg  [31:0] prdata, output wire pready, pslverr,
    output wire        wdt_irq, wdt_rst_req
);
    assign pready=1; assign pslverr=0;
    reg [31:0] ld1,ld2,ctr; reg stage,en,wen,ren,ien;
    reg [3:0]  uck; wire unlocked=(uck!=0);
    reg iq1,iqw,rstpulse,inwin;
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) uck<=0;
        else begin
            if (psel&&penable&&pwrite&&paddr==12'h014)
                uck <= (pwdata==32'hABCD_1234) ? 4'd15 : 4'd0;
            else if (uck!=0) uck<=uck-1;
        end
    end
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin ld1<=DEFAULT_LOAD1; ld2<=DEFAULT_LOAD2; ctr<=DEFAULT_LOAD1;
            stage<=0; en<=0; wen<=0; ren<=1; ien<=1; iq1<=0; iqw<=0; rstpulse<=0; inwin<=0;
        end else begin
            rstpulse<=0;
            inwin <= (ctr <= (stage==0 ? ld1>>1 : ld2>>1));
            if (psel&&penable&&pwrite) case(paddr)
                12'h000: if(unlocked) ld1<=pwdata;
                12'h004: if(unlocked) ld2<=pwdata;
                12'h00C: if(unlocked) begin en<=pwdata[0]; wen<=pwdata[1]; ren<=pwdata[2]; ien<=pwdata[3];
                             if(pwdata[0]&&!en) begin ctr<=ld1; stage<=0; end end
                12'h018: if(pwdata==32'hFEED_C0DE && en) begin
                             if(wen&&!inwin) iqw<=1;
                             else begin ctr<=ld1; stage<=0; end end
                12'h01C: begin if(pwdata[0]) iq1<=0; if(pwdata[1]) iqw<=0; end
                default:;
            endcase
            if (en) begin
                if (ctr==0) begin
                    if (stage==0) begin iq1<=1; ctr<=ld2; stage<=1; end
                    else begin if(ren) rstpulse<=1; ctr<=ld2; end
                end else ctr<=ctr-1;
            end
        end
    end
    assign wdt_irq=iq1&ien; assign wdt_rst_req=rstpulse;
    always @(*) case(paddr)
        12'h000: prdata=ld1; 12'h004: prdata=ld2; 12'h008: prdata=ctr;
        12'h00C: prdata={28'h0,ien,ren,wen,en};
        12'h010: prdata={29'h0,unlocked,inwin,iq1};
        12'h014: prdata=32'h0; 12'h018: prdata=32'h0;
        12'h01C: prdata={30'h0,iqw,iq1};
        default: prdata=32'hDEAD_BEEF;
    endcase
endmodule
