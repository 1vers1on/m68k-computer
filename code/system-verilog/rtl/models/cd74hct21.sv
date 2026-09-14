`timescale 1ns / 1ps
`default_nettype none

module cd74hct21 #(
    // max propagation delay times in ns
    parameter real TPLH = 41.0,
    parameter real TPHL = 41.0
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
