`timescale 1ns / 1ps
`default_nettype none

module sn74f86 #(
    // max propagation delay times in ns, other input low
    parameter real TPLH_L = 5.5,
    parameter real TPHL_L = 5.5,

    // max propagation delay times in ns, other input high
    parameter real TPLH_H = 7.0,
    parameter real TPHL_H = 6.5
) (
    input  wire A,
    input  wire B,
    output wire Y
);

    assign Y = A ^ B;

    specify
        specparam tplh_l = TPLH_L;
        specparam tphl_l = TPHL_L;
        specparam tplh_h = TPLH_H;
        specparam tphl_h = TPHL_H;

        if (!B) (A => Y) = (tplh_l, tphl_l);
        if ( B) (A => Y) = (tplh_h, tphl_h);
        if (!A) (B => Y) = (tplh_l, tphl_l);
        if ( A) (B => Y) = (tplh_h, tphl_h);
    endspecify

endmodule

`default_nettype wire
