`timescale 1ns / 1ps
`default_nettype none

module sn74f10 #(
    // max propagation delay times in ns
    parameter real TPLH = 5.0,
    parameter real TPHL = 4.3
) (
    input  wire A,
    input  wire B,
    input  wire C,
    output wire Y
);

    assign Y = ~(A & B & C);

    specify
        specparam tplh = TPLH;
        specparam tphl = TPHL;

        (A => Y) = (tplh, tphl);
        (B => Y) = (tplh, tphl);
        (C => Y) = (tplh, tphl);
    endspecify

endmodule

`default_nettype wire
