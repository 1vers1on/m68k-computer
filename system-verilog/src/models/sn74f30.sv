`timescale 1ns / 1ps
`default_nettype none

module sn74f30 #(
    // max propagation delay times in ns
    parameter real TPLH = 5.0,
    parameter real TPHL = 4.5
) (
    input  wire A,
    input  wire B,
    input  wire C,
    input  wire D,
    input  wire E,
    input  wire F,
    input  wire G,
    input  wire H,
    output wire Y
);

    assign Y = ~(A & B & C & D & E & F & G & H);

    specify
        specparam tplh = TPLH;
        specparam tphl = TPHL;

        (A => Y) = (tplh, tphl);
        (B => Y) = (tplh, tphl);
        (C => Y) = (tplh, tphl);
        (D => Y) = (tplh, tphl);
        (E => Y) = (tplh, tphl);
        (F => Y) = (tplh, tphl);
        (G => Y) = (tplh, tphl);
        (H => Y) = (tplh, tphl);
    endspecify

endmodule

`default_nettype wire
