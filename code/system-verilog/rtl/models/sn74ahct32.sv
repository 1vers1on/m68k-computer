`timescale 1ns / 1ps
`default_nettype none

module sn74ahct32 #(
    // max propagation delay times in ns
    parameter real TPLH = 10.0,
    parameter real TPHL = 10.0
) (
    input  wire A,
    input  wire B,
    output wire Y
);

    assign Y = A | B;

    specify
        specparam tplh = TPLH;
        specparam tphl = TPHL;

        (A => Y) = (tplh, tphl);
        (B => Y) = (tplh, tphl);
    endspecify

endmodule

`default_nettype wire
