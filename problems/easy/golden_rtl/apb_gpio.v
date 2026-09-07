// =============================================================================
// Module: apb_gpio
// Desc  : APB3 GPIO 32-pin, 3-stage debounce, per-pin edge/level IRQ
// NXP ICLAD 2026 RTL Gen Library
// =============================================================================
`timescale 1ns/1ps

module apb_gpio #(parameter GPIO_WIDTH=32, parameter DBS=3)(
    input  wire               pclk, presetn,
    input  wire               psel, penable, pwrite,
    input  wire [11:0]        paddr, input  wire [31:0] pwdata,
    output reg  [31:0]        prdata, output wire pready, pslverr,
    input  wire [GPIO_WIDTH-1:0] gpio_in,
    output wire [GPIO_WIDTH-1:0] gpio_out, gpio_oe,
    output wire [2*GPIO_WIDTH-1:0] alt_func,
    output wire               irq
);
    assign pready=1; assign pslverr=0;
    reg [GPIO_WIDTH-1:0] r_out,r_dir,r_ien,r_iedge,r_ipol,r_istat;
    reg [31:0] r_alt_lo,r_alt_hi;
    reg [GPIO_WIDTH-1:0] sync[0:DBS-1];
    integer si;
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin for(si=0;si<DBS;si=si+1) sync[si]<=0; end
        else begin sync[0]<=gpio_in; for(si=1;si<DBS;si=si+1) sync[si]<=sync[si-1]; end
    end
    wire [GPIO_WIDTH-1:0] gs=sync[DBS-1];
    reg [GPIO_WIDTH-1:0] gprev;
    always @(posedge pclk or negedge presetn)
        if (!presetn) gprev<=0; else gprev<=gs;
    wire [GPIO_WIDTH-1:0] rise=gs&~gprev, fall=~gs&gprev;
    wire [GPIO_WIDTH-1:0] ev=(r_ipol&rise)|(~r_ipol&fall);
    wire [GPIO_WIDTH-1:0] lv=r_ipol?gs:~gs;
    wire [GPIO_WIDTH-1:0] raw=r_ien&(r_iedge?ev:lv);
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin r_out<=0; r_dir<=0; r_alt_lo<=0; r_alt_hi<=0;
            r_ien<=0; r_iedge<=0; r_ipol<=0; r_istat<=0;
        end else begin
            r_istat<=r_istat|raw;
            if (psel&&penable&&pwrite) case(paddr)
                12'h004: r_out   <=pwdata[GPIO_WIDTH-1:0];
                12'h008: r_dir   <=pwdata[GPIO_WIDTH-1:0];
                12'h00C: r_alt_lo<=pwdata;
                12'h010: r_alt_hi<=pwdata;
                12'h014: r_ien   <=pwdata[GPIO_WIDTH-1:0];
                12'h018: r_iedge <=pwdata[GPIO_WIDTH-1:0];
                12'h01C: r_ipol  <=pwdata[GPIO_WIDTH-1:0];
                12'h020: r_istat <=r_istat&~pwdata[GPIO_WIDTH-1:0];
                default: ;
            endcase
        end
    end
    always @(*) case(paddr)
        12'h000: prdata={{32-GPIO_WIDTH{1'b0}},gs};
        12'h004: prdata={{32-GPIO_WIDTH{1'b0}},r_out};
        12'h008: prdata={{32-GPIO_WIDTH{1'b0}},r_dir};
        12'h00C: prdata=r_alt_lo;
        12'h010: prdata=r_alt_hi;
        12'h014: prdata={{32-GPIO_WIDTH{1'b0}},r_ien};
        12'h018: prdata={{32-GPIO_WIDTH{1'b0}},r_iedge};
        12'h01C: prdata={{32-GPIO_WIDTH{1'b0}},r_ipol};
        12'h020: prdata={{32-GPIO_WIDTH{1'b0}},r_istat};
        default: prdata=32'hDEAD_BEEF;
    endcase
    assign gpio_out=r_out; assign gpio_oe=r_dir;
    assign alt_func={r_alt_hi[2*GPIO_WIDTH/2-1:0],r_alt_lo[2*GPIO_WIDTH/2-1:0]};
    assign irq=|r_istat;
endmodule
