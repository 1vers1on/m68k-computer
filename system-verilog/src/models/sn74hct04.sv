`timescale 1ns / 1ps
`default_nettype none

module sn74hct04 #(
    // max propagation delay times in ns
    parameter real TPLH = 20.0,
    parameter real TPHL = 20.0
) (
    input  wire A,
    output wire Y
);

    assign Y = ~A;

    specify
        specparam tplh = TPLH;
        specparam tphl = TPHL;

        (A => Y) = (tplh, tphl);
    endspecify

endmodule

`default_nettype wire
