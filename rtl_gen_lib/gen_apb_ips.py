"""
APB IP generators: apb_uart, apb_gpio, apb_timer, apb_watchdog,
                   irq_aggregator, ahb_to_apb_bridge, apb_fabric

All design-critical parameters MUST be explicit in the YAML spec.
"""
from gen_utils import required, opt, hdr, MissingParameter


def gen_ahb_to_apb_bridge(spec):
    """Required: name (only — interface is fixed by AHB-APB spec)"""
    n = opt(spec, "name", "ahb_to_apb_bridge")
    code = hdr(n, "AHB-Lite to APB3 bridge: SETUP+ENABLE, 2-cycle ERROR response")
    code += f"""\
module {n} (
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
"""
    return {f"{n}.v": code}


def gen_apb_fabric(spec):
    """Required: name, timeout_cyc"""
    n   = opt(spec, "name", "apb_fabric5")
    tmo = int(required(spec, "timeout_cyc", "apb_fabric"))
    code = hdr(n, f"APB3 5-slave fabric, priv-filter S3, {tmo}-cycle timeout")
    code += f"""\
module {n} #(parameter TIMEOUT_CYC={tmo})(
    input  wire        pclk, presetn,
    input  wire        m_psel, m_penable, m_pwrite,
    input  wire [31:0] m_paddr, m_pwdata,
    input  wire [2:0]  m_pprot,
    output reg  [31:0] m_prdata,
    output wire        m_pready, m_pslverr,
    output wire s0_psel,s0_penable,s0_pwrite, output wire [11:0] s0_paddr,
    output wire [31:0] s0_pwdata, input wire [31:0] s0_prdata,
    input  wire s0_pready, s0_pslverr,
    output wire s1_psel,s1_penable,s1_pwrite, output wire [11:0] s1_paddr,
    output wire [31:0] s1_pwdata, input wire [31:0] s1_prdata,
    input  wire s1_pready, s1_pslverr,
    output wire s2_psel,s2_penable,s2_pwrite, output wire [11:0] s2_paddr,
    output wire [31:0] s2_pwdata, input wire [31:0] s2_prdata,
    input  wire s2_pready, s2_pslverr,
    output wire s3_psel,s3_penable,s3_pwrite, output wire [11:0] s3_paddr,
    output wire [31:0] s3_pwdata, input wire [31:0] s3_prdata,
    input  wire s3_pready, s3_pslverr,
    output wire s4_psel,s4_penable,s4_pwrite, output wire [11:0] s4_paddr,
    output wire [31:0] s4_pwdata, input wire [31:0] s4_prdata,
    input  wire s4_pready, s4_pslverr
);
    wire dec0=m_psel&&(m_paddr[31:12]==20'h00000);
    wire dec1=m_psel&&(m_paddr[31:12]==20'h00001);
    wire dec2=m_psel&&(m_paddr[31:12]==20'h00002);
    wire dec3=m_psel&&(m_paddr[31:12]==20'h00003);
    wire dec4=m_psel&&(m_paddr[31:12]==20'h00004);
    wire priv=m_pprot[0];
    wire priv_err=dec3&&!priv;
    wire miss=m_psel&&!(dec0||dec1||dec2||dec3||dec4);
    reg [4:0] tcnt; reg terr;
    always @(posedge pclk or negedge presetn)
        if (!presetn) begin tcnt<=0; terr<=0; end
        else if (!m_psel||m_pready) begin tcnt<=0; terr<=0; end
        else if (tcnt==TIMEOUT_CYC-1) terr<=1;
        else tcnt<=tcnt+1;
    wire s0_ok=dec0, s1_ok=dec1, s2_ok=dec2, s3_ok=dec3&&priv, s4_ok=dec4;
    assign s0_psel=s0_ok; assign s1_psel=s1_ok; assign s2_psel=s2_ok;
    assign s3_psel=s3_ok; assign s4_psel=s4_ok;
    assign s0_penable=m_penable; assign s1_penable=m_penable;
    assign s2_penable=m_penable; assign s3_penable=m_penable; assign s4_penable=m_penable;
    assign s0_pwrite=m_pwrite; assign s1_pwrite=m_pwrite; assign s2_pwrite=m_pwrite;
    assign s3_pwrite=m_pwrite; assign s4_pwrite=m_pwrite;
    assign s0_paddr=m_paddr[11:0]; assign s1_paddr=m_paddr[11:0];
    assign s2_paddr=m_paddr[11:0]; assign s3_paddr=m_paddr[11:0]; assign s4_paddr=m_paddr[11:0];
    assign s0_pwdata=m_pwdata; assign s1_pwdata=m_pwdata; assign s2_pwdata=m_pwdata;
    assign s3_pwdata=m_pwdata; assign s4_pwdata=m_pwdata;
    always @(*)
        if      (s0_ok) m_prdata=s0_prdata;
        else if (s1_ok) m_prdata=s1_prdata;
        else if (s2_ok) m_prdata=s2_prdata;
        else if (s3_ok) m_prdata=s3_prdata;
        else if (s4_ok) m_prdata=s4_prdata;
        else            m_prdata=32'hDEAD_BEEF;
    wire err_cond=miss|priv_err|terr;
    wire slv_rdy=(s0_ok?s0_pready:1'b1)&(s1_ok?s1_pready:1'b1)&
                 (s2_ok?s2_pready:1'b1)&(s3_ok?s3_pready:1'b1)&(s4_ok?s4_pready:1'b1);
    assign m_pready  = err_cond ? 1'b1 : slv_rdy;
    assign m_pslverr = miss|priv_err|terr|
                       (s0_ok&s0_pslverr)|(s1_ok&s1_pslverr)|(s2_ok&s2_pslverr)|
                       (s3_ok&s3_pslverr)|(s4_ok&s4_pslverr);
endmodule
"""
    return {f"{n}.v": code}


def gen_apb_uart(spec):
    """Required: name, fifo_depth, default_div"""
    n    = opt(spec, "name", "apb_uart")
    fd   = int(required(spec, "fifo_depth",   "apb_uart"))
    div  = int(required(spec, "default_div",  "apb_uart"))
    ab   = max(1, (fd-1).bit_length())
    cb   = ab + 1
    code = hdr(n, f"APB3 full-duplex UART, FIFO={fd}, default_div={div}")
    code += f"""\
module {n} #(parameter FIFO_DEPTH={fd}, parameter DEFAULT_DIV={div})(
    input  wire        pclk, presetn,
    input  wire        psel, penable, pwrite,
    input  wire [11:0] paddr, input wire [31:0] pwdata,
    output reg  [31:0] prdata, output wire pready, pslverr,
    output reg         uart_tx, input wire uart_rx,
    input  wire        cts_n, output wire rts_n, output wire irq
);
    assign pready=1; assign pslverr=0;
    localparam ABITS={ab}; localparam CBITS={cb};
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
                    1: begin uart_tx<=tx_sr[0]; tx_sr<={{1'b1,tx_sr[7:1]}}; tx_bc<=1; tx_st<=2; end
                    2: begin if(tx_bc==7) begin uart_tx<=tx_sr[0];
                                 tx_st<=par_en?3:4; end
                             else begin uart_tx<=tx_sr[0]; tx_sr<={{1'b1,tx_sr[7:1]}};
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
            rx_sync<={{rx_sync[1:0],uart_rx}};
            if (psel&&penable&&!pwrite&&paddr==12'h004&&!rx_empty) rx_rp<=rx_rp+1;
            if (btick&&rx_en) begin
                rx_sub<=rx_sub+1;
                case(rx_st)
                    0: if(!rx_in) begin rx_st<=1; rx_sub<=0; end
                    1: if(rx_sub==7) begin if(!rx_in) begin rx_st<=2; rx_bc<=0; rx_sub<=0; end
                                          else rx_st<=0; end
                    2: if(rx_sub==15) begin rx_sr<={{rx_in,rx_sr[7:1]}}; rx_sub<=0;
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
    wire [7:0] status={{cts_n,overrun,par_err,frame_err,rx_empty,rx_full,tx_empty,tx_full}};
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
        12'h004: prdata=rx_empty?32'h0:{{24'h0,rx_mem[rx_rp[ABITS-1:0]]}};
        12'h008: prdata={{24'h0,status}};
        12'h00C: prdata={{8'h0,baud_div,3'h0,stop2,par_odd,par_en,rx_en,tx_en}};
        12'h010: prdata={{24'h0,irq_en}};
        12'h014: prdata={{24'h0,irq_stat}};
        default: prdata=32'hDEAD_BEEF;
    endcase
endmodule
"""
    return {f"{n}.v": code}


def gen_apb_gpio(spec):
    """Required: name, gpio_width, debounce_sync"""
    n   = opt(spec, "name", "apb_gpio")
    w   = int(required(spec, "gpio_width",    "apb_gpio"))
    dbs = int(required(spec, "debounce_sync", "apb_gpio"))
    code = hdr(n, f"APB3 GPIO {w}-pin, {dbs}-stage debounce, per-pin edge/level IRQ")
    code += f"""\
module {n} #(parameter GPIO_WIDTH={w}, parameter DBS={dbs})(
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
        12'h000: prdata={{{{32-GPIO_WIDTH{{1'b0}}}},gs}};
        12'h004: prdata={{{{32-GPIO_WIDTH{{1'b0}}}},r_out}};
        12'h008: prdata={{{{32-GPIO_WIDTH{{1'b0}}}},r_dir}};
        12'h00C: prdata=r_alt_lo;
        12'h010: prdata=r_alt_hi;
        12'h014: prdata={{{{32-GPIO_WIDTH{{1'b0}}}},r_ien}};
        12'h018: prdata={{{{32-GPIO_WIDTH{{1'b0}}}},r_iedge}};
        12'h01C: prdata={{{{32-GPIO_WIDTH{{1'b0}}}},r_ipol}};
        12'h020: prdata={{{{32-GPIO_WIDTH{{1'b0}}}},r_istat}};
        default: prdata=32'hDEAD_BEEF;
    endcase
    assign gpio_out=r_out; assign gpio_oe=r_dir;
    assign alt_func={{r_alt_hi[2*GPIO_WIDTH/2-1:0],r_alt_lo[2*GPIO_WIDTH/2-1:0]}};
    assign irq=|r_istat;
endmodule
"""
    return {f"{n}.v": code}


def gen_apb_timer(spec):
    """Required: name, channels, width"""
    n  = opt(spec, "name", "apb_timer")
    ch = int(required(spec, "channels", "apb_timer"))
    w  = int(required(spec, "width",    "apb_timer"))
    hex_ones = "F" * (w // 4)
    rst_val  = f"{w}'h{hex_ones}"
    code = hdr(n, f"APB3 dual-channel timer {w}-bit, prescaler, PWM, periodic")
    code += f"""\
module {n} #(parameter CHANNELS={ch}, parameter WIDTH={w})(
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
            ld0<={rst_val}; v0<=0; c0<=0; p0<=0; en0<=0; per0<=0; ie0<=0; pe0<=0; iq0<=0; pc0<=0;
            ld1<={rst_val}; v1<=0; c1<=0; p1<=0; en1<=0; per1<=0; ie1<=0; pe1<=0; iq1<=0; pc1<=0;
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
        12'h008: prdata={{20'h0,p0,pe0,ie0,per0,en0}}; 12'h00C: prdata=c0; 12'h010: prdata={{31'h0,iq0}};
        12'h020: prdata=ld1; 12'h024: prdata=v1;
        12'h028: prdata={{20'h0,p1,pe1,ie1,per1,en1}}; 12'h02C: prdata=c1; 12'h030: prdata={{31'h0,iq1}};
        default: prdata=32'hDEAD_BEEF;
    endcase
endmodule
"""
    return {f"{n}.v": code}


def gen_apb_watchdog(spec):
    """Required: name (interface and behavior fixed by spec)"""
    n = opt(spec, "name", "apb_watchdog")
    code = hdr(n, "APB3 two-stage watchdog: stage1=IRQ, stage2=reset, window mode, unlock key")
    code += f"""\
module {n} #(
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
        12'h00C: prdata={{28'h0,ien,ren,wen,en}};
        12'h010: prdata={{29'h0,unlocked,inwin,iq1}};
        12'h014: prdata=32'h0; 12'h018: prdata=32'h0;
        12'h01C: prdata={{30'h0,iqw,iq1}};
        default: prdata=32'hDEAD_BEEF;
    endcase
endmodule
"""
    return {f"{n}.v": code}


def gen_irq_aggregator(spec):
    """Required: name (interface fixed by spec)"""
    n = opt(spec, "name", "irq_aggregator")
    code = hdr(n, "8-source IRQ aggregator, priority encoder, edge/level, polarity, soft-IRQ")
    code += f"""\
module {n} (
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
        12'h000: prdata={{24'h0,irq_in}}; 12'h004: prdata={{24'h0,r_pend}};
        12'h008: prdata={{24'h0,r_en}};   12'h00C: prdata={{24'h0,r_edge}};
        12'h010: prdata={{24'h0,r_pol}};  12'h014: prdata=32'h0;
        12'h018: prdata={{29'h0,vid}};    12'h01C: prdata={{24'h0,r_soft}};
        default: prdata=32'hDEAD_BEEF;
    endcase
endmodule
"""
    return {f"{n}.v": code}


GENERATORS = {
    "ahb_to_apb_bridge": gen_ahb_to_apb_bridge,
    "apb_fabric":        gen_apb_fabric,
    "apb_uart":          gen_apb_uart,
    "apb_gpio":          gen_apb_gpio,
    "apb_timer":         gen_apb_timer,
    "apb_watchdog":      gen_apb_watchdog,
    "irq_aggregator":    gen_irq_aggregator,
}
