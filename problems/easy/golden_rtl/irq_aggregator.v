// =============================================================================
// Module: irq_aggregator
// Desc  : 8-source IRQ aggregator, priority encoder, edge/level, polarity, soft-IRQ
// NXP ICLAD 2026 RTL Gen Library
// =============================================================================
`timescale 1ns/1ps

module irq_aggregator (
    input  wire       pclk, presetn,
    input  wire       psel, penable, pwrite,
    input  wire [11:0] paddr, input wire [31:0] pwdata,
    output reg  [31:0] prdata, output wire pready, pslverr,
    input  wire [7:0]  irq_src,
    output wire        cpu_irq,
    output wire [2:0]  cpu_irq_id
);
    assign pready=1; assign pslverr=0;
    reg [7:0] r_en, r_edge, r_pol, r_pend, r_soft;
    wire [7:0] irq_in = (irq_src ^ ~r_pol) | r_soft;
    reg  [7:0] irq_prev;
    always @(posedge pclk or negedge presetn)
        if (!presetn) irq_prev<=0; else irq_prev<=irq_in;
    wire [7:0] edge_ev=irq_in&~irq_prev;
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin r_en<=8'hFF; r_edge<=0; r_pol<=8'hFF; r_pend<=0; r_soft<=0; end
        else begin
            r_pend <= r_pend | (r_edge&edge_ev&r_en) | (~r_edge&irq_in&r_en);
            if (psel&&penable&&pwrite) case(paddr)
                12'h008: r_en  <=pwdata[7:0];
                12'h00C: r_edge<=pwdata[7:0];
                12'h010: r_pol <=pwdata[7:0];
                12'h014: r_pend<=r_pend&~pwdata[7:0];
                12'h01C: r_soft<=pwdata[7:0];
                default:;
            endcase
        end
    end
    reg [2:0] vid;
    always @(*)
        if      (r_pend[7]) vid=7; else if (r_pend[6]) vid=6;
        else if (r_pend[5]) vid=5; else if (r_pend[4]) vid=4;
        else if (r_pend[3]) vid=3; else if (r_pend[2]) vid=2;
        else if (r_pend[1]) vid=1; else vid=0;
    assign cpu_irq=|r_pend; assign cpu_irq_id=vid;
    always @(*) case(paddr)
        12'h000: prdata={24'h0,irq_in}; 12'h004: prdata={24'h0,r_pend};
        12'h008: prdata={24'h0,r_en};   12'h00C: prdata={24'h0,r_edge};
        12'h010: prdata={24'h0,r_pol};  12'h014: prdata=32'h0;
        12'h018: prdata={29'h0,vid};    12'h01C: prdata={24'h0,r_soft};
        default: prdata=32'hDEAD_BEEF;
    endcase
endmodule
