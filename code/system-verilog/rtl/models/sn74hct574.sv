`timescale 1ns / 1ps
`default_nettype none

module sn74hct574 #(
    // max propagation delay times in ns
    parameter real TPLH = 36.0,
    parameter real TPHL = 36.0,
    parameter real TPZH = 30.0,
    parameter real TPZL = 30.0,
    parameter real TPHZ = 30.0,
    parameter real TPLZ = 30.0,

    // timing requirements in ns
    parameter real TSU  = 20.0,
    parameter real TH   =  5.0,
    parameter real TW   = 16.0
) (
    input  wire OE_n,
    input  wire CLK,
    input  wire D,
    output wire Q
);

    logic q_int;
    reg   notifier;

    always @(posedge CLK) q_int <= D;
    always @(notifier)    q_int <= 1'bx;

    bufif0 u_buf (Q, q_int, OE_n);

    specify
        specparam tplh = TPLH;
        specparam tphl = TPHL;
        specparam tpzh = TPZH;
        specparam tpzl = TPZL;
        specparam tphz = TPHZ;
        specparam tplz = TPLZ;
        specparam tsu  = TSU;
        specparam th   = TH;
        specparam tw   = TW;

        (posedge CLK => (Q +: D)) = (tplh, tphl);

        (OE_n => Q) = (tplh, tphl, tplz, tpzh, tphz, tpzl);

        $setuphold(posedge CLK, D, tsu, th, notifier);
        $width(posedge CLK, tw, 0, notifier);
        $width(negedge CLK, tw, 0, notifier);
    endspecify

endmodule

`default_nettype wire
