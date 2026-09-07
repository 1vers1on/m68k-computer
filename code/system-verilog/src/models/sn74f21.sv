`timescale 1ns / 1ps
`default_nettype none

module sn74f21 #(
    // max propagation delay times in ns
    parameter real TPLH = 4.7,
    parameter real TPHL = 5.1
) (
    input  wire A,
    input  wire B,
    input  wire C,
    input  wire D,
    output wire Y
);

    assign Y = A & B & C & D;

    specify
        specparam tplh = TPLH;
        specparam tphl = TPHL;

        (A => Y) = (tplh, tphl);
        (B => Y) = (tplh, tphl);
        (C => Y) = (tplh, tphl);
        (D => Y) = (tplh, tphl);
    endspecify

endmodule

`default_nettype wire
