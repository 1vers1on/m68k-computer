`timescale 1ns / 1ps
`default_nettype none

module sn74ls07 #(
    // max propagation delay times in ns
    parameter real TPLH = 10.0,
    parameter real TPHL = 30.0
) (
    input  wire A,
    output wire Y
);

    bufif0 u_buf (Y, 1'b0, A);

    specify
        specparam tplh = TPLH;
        specparam tphl = TPHL;

        (A => Y) = (tplh, tphl);
    endspecify

endmodule

`default_nettype wire
