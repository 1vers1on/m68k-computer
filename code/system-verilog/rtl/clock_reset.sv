`timescale 1ns / 1ps
`default_nettype none

module clock_reset (
    input  wire MASTER_CLK_40,
    input  wire RESET_RAW_n,
    inout  wire CPU_RESET_n,
    inout  wire CPU_HALT_n,
    output wire CPU_CLK_DIV2,
    output wire CPU_CLK_10,
    output wire RESET_n,
    output wire PIT_CLK,
    output wire TIMEOUT_CLK,
    output wire PERIPH_RESET_n
);

    wire CPU_CLK_DIV2_n;
    wire CPU_CLK_10_n;
    wire RESET_STAGE_H;
    wire IO_CLK_ROOT;

    sn74f74 U_CPU_CLK_STAGE1 (
        .PRE_n(1'b1), .CLR_n(1'b1),
        .CLK(MASTER_CLK_40),
        .D(CPU_CLK_DIV2_n),
        .Q(CPU_CLK_DIV2), .Q_n(CPU_CLK_DIV2_n)
    );
    sn74f74 U_CPU_CLK_STAGE2 (
        .PRE_n(1'b1), .CLR_n(1'b1),
        .CLK(CPU_CLK_DIV2),
        .D(CPU_CLK_10_n),
        .Q(CPU_CLK_10), .Q_n(CPU_CLK_10_n)
    );

    // U_IO_CLK_BUF: CD74ACT244E. One input from CPU_CLK_10, re-buffered as
    // IO_CLK_ROOT, then a separate channel for each I/O clock.
    cd74act244 U_IO_CLK_ROOT (.OE_n(1'b0), .A(CPU_CLK_10), .Y(IO_CLK_ROOT));
    cd74act244 U_IO_CLK_PIT (.OE_n(1'b0), .A(IO_CLK_ROOT), .Y(PIT_CLK));
    cd74act244 U_IO_CLK_TIMEOUT (.OE_n(1'b0), .A(IO_CLK_ROOT), .Y(TIMEOUT_CLK));

    // U_RESET_COND: two SN74LS14 Schmitt stages preserve active-low polarity
    // while conditioning the slow RESET_RAW_n edge.
    sn74ls14 U_RESET_COND_1 (.A(RESET_RAW_n), .Y(RESET_STAGE_H));
    sn74ls14 U_RESET_COND_2 (.A(RESET_STAGE_H), .Y(RESET_n));

    // U_RESET_DRV: SN74LS07N non-inverting open-collector channels. Channels 1
    // and 2 drive the processor pins from RESET_n; channel 3 re-buffers
    // CPU_RESET_n into PERIPH_RESET_n so a processor RESET instruction is
    // distributed without reasserting RESET_n.
    sn74ls07 U_RESET_DRV_CPU_RESET (.A(RESET_n), .Y(CPU_RESET_n));
    sn74ls07 U_RESET_DRV_CPU_HALT  (.A(RESET_n), .Y(CPU_HALT_n));
    sn74ls07 U_RESET_DRV_PERIPH    (.A(CPU_RESET_n), .Y(PERIPH_RESET_n));

    // Open-collector pull-ups (R_CPU_RESET, R_CPU_HALT, R_PERIPH_RESET).
    pullup (CPU_RESET_n);
    pullup (CPU_HALT_n);
    pullup (PERIPH_RESET_n);

endmodule

`default_nettype wire
