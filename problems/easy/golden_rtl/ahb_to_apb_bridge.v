// =============================================================================
// Module: ahb_to_apb_bridge
// Desc  : AHB-Lite to APB3 bridge: SETUP+ENABLE, 2-cycle ERROR response
// NXP ICLAD 2026 RTL Gen Library
// =============================================================================
`timescale 1ns/1ps

module ahb_to_apb_bridge (
    input  wire        hclk, hresetn,
    input  wire [31:0] haddr,
    input  wire [1:0]  htrans,
    input  wire        hwrite,
    input  wire [2:0]  hsize, hburst, hprot,
    input  wire [31:0] hwdata,
    input  wire        hsel, hready_in,
    output reg  [31:0] hrdata,
    output reg         hready_out,
    output reg  [1:0]  hresp,
    output reg         psel, penable, pwrite,
    output reg  [31:0] paddr, pwdata,
    output reg  [2:0]  pprot,
    input  wire [31:0] prdata,
    input  wire        pready, pslverr
);
    localparam ST_IDLE=2'd0, ST_SETUP=2'd1, ST_ENABLE=2'd2, ST_ERR2=2'd3;
    reg [1:0] state;
    reg [31:0] r_haddr; reg r_hwrite; reg [2:0] r_hprot;
    wire valid = hsel && hready_in && (htrans==2'b10 || htrans==2'b11);
    always @(posedge hclk or negedge hresetn) begin
        if (!hresetn) begin
            state<=ST_IDLE; psel<=0; penable<=0; pwrite<=0;
            paddr<=0; pwdata<=0; pprot<=0;
            hrdata<=0; hready_out<=1; hresp<=0;
            r_haddr<=0; r_hwrite<=0; r_hprot<=0;
        end else case (state)
            ST_IDLE: begin
                hready_out<=1; hresp<=0; psel<=0; penable<=0;
                if (valid) begin
                    r_haddr<=haddr; r_hwrite<=hwrite; r_hprot<=hprot;
                    hready_out<=0; state<=ST_SETUP;
                end
            end
            ST_SETUP: begin
                psel<=1; penable<=0; pwrite<=r_hwrite;
                paddr<=r_haddr; pprot<=r_hprot; pwdata<=hwdata;
                state<=ST_ENABLE;
            end
            ST_ENABLE: begin
                if (!penable) penable<=1;
                else if (pready) begin
                    psel<=0; penable<=0; hrdata<=prdata;
                    if (pslverr) begin hresp<=2'b01; hready_out<=0; state<=ST_ERR2; end
                    else begin hresp<=0; hready_out<=1; state<=ST_IDLE; end
                end
            end
            ST_ERR2: begin hresp<=2'b01; hready_out<=1; state<=ST_IDLE; end
            default: state<=ST_IDLE;
        endcase
    end
endmodule
