// =============================================================================
// Module: apb_timer
// Desc  : APB3 dual-channel timer 32-bit, prescaler, PWM, periodic
// NXP ICLAD 2026 RTL Gen Library
// =============================================================================
`timescale 1ns/1ps

module apb_timer #(parameter CHANNELS=2, parameter WIDTH=32)(
    input  wire        pclk, presetn,
    input  wire        psel, penable, pwrite,
    input  wire [11:0] paddr, input wire [31:0] pwdata,
    output reg  [31:0] prdata, output wire pready, pslverr,
    output wire        pwm0, pwm1, irq
);
    assign pready=1; assign pslverr=0;
    reg [WIDTH-1:0] ld0,v0,c0; reg [7:0] p0; reg en0,per0,ie0,pe0,iq0; reg [7:0] pc0;
    reg [WIDTH-1:0] ld1,v1,c1; reg [7:0] p1; reg en1,per1,ie1,pe1,iq1; reg [7:0] pc1;
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            ld0<=32'hFFFFFFFF; v0<=0; c0<=0; p0<=0; en0<=0; per0<=0; ie0<=0; pe0<=0; iq0<=0; pc0<=0;
            ld1<=32'hFFFFFFFF; v1<=0; c1<=0; p1<=0; en1<=0; per1<=0; ie1<=0; pe1<=0; iq1<=0; pc1<=0;
        end else begin
            if (psel&&penable&&pwrite) case(paddr)
                12'h000: ld0<=pwdata;
                12'h008: begin en0<=pwdata[0]; per0<=pwdata[1]; ie0<=pwdata[2]; pe0<=pwdata[3];
                               p0<=pwdata[11:4]; if(pwdata[0]&&!en0) v0<=ld0; end
                12'h00C: c0<=pwdata;
                12'h010: if(pwdata[0]) iq0<=0;
                12'h020: ld1<=pwdata;
                12'h028: begin en1<=pwdata[0]; per1<=pwdata[1]; ie1<=pwdata[2]; pe1<=pwdata[3];
                               p1<=pwdata[11:4]; if(pwdata[0]&&!en1) v1<=ld1; end
                12'h02C: c1<=pwdata;
                12'h030: if(pwdata[0]) iq1<=0;
                default:;
            endcase
            if (en0) begin
                if (pc0==p0) begin pc0<=0;
                    if (v0==0) begin if(ie0) iq0<=1; if(per0) v0<=ld0; else en0<=0; end
                    else v0<=v0-1;
                end else pc0<=pc0+1;
            end
            if (en1) begin
                if (pc1==p1) begin pc1<=0;
                    if (v1==0) begin if(ie1) iq1<=1; if(per1) v1<=ld1; else en1<=0; end
                    else v1<=v1-1;
                end else pc1<=pc1+1;
            end
        end
    end
    assign pwm0=pe0?(v0>c0):1'b0; assign pwm1=pe1?(v1>c1):1'b0; assign irq=iq0|iq1;
    always @(*) case(paddr)
        12'h000: prdata=ld0; 12'h004: prdata=v0;
        12'h008: prdata={20'h0,p0,pe0,ie0,per0,en0}; 12'h00C: prdata=c0; 12'h010: prdata={31'h0,iq0};
        12'h020: prdata=ld1; 12'h024: prdata=v1;
        12'h028: prdata={20'h0,p1,pe1,ie1,per1,en1}; 12'h02C: prdata=c1; 12'h030: prdata={31'h0,iq1};
        default: prdata=32'hDEAD_BEEF;
    endcase
endmodule
