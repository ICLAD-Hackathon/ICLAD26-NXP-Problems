// =============================================================================
// Module: reset_sync
// Desc  : Async-assert/sync-deassert reset synchronizer (3 stages)
// NXP ICLAD 2026 RTL Gen Library
// =============================================================================
`timescale 1ns/1ps

module reset_sync #(parameter STAGES=3)(
    input  wire clk, por_n, wdt_rst_n,
    output wire sys_rst_n
);
    wire async_rst_n = por_n & wdt_rst_n;
    reg [STAGES-1:0] chain;
    always @(posedge clk or negedge async_rst_n)
        if (!async_rst_n) chain <= 0;
        else              chain <= {chain[STAGES-2:0], 1'b1};
    assign sys_rst_n = chain[STAGES-1];
endmodule
