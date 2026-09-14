`timescale 1ns / 1ps
`default_nettype none

module cd74act373_tb;

    logic OE_n;
    logic LE;
    logic D;
    wire  Q;
    integer failures;

    cd74act373 dut (
        .OE_n(OE_n),
        .LE(LE),
        .D(D),
        .Q(Q)
    );

    task automatic check;
        input logic expected;
        begin
            #1;

            if (Q !== expected) begin
                $display("FAIL OE_n=%b LE=%b D=%b Q=%b expected=%b", OE_n, LE, D, Q, expected);
                failures = failures + 1;
            end
        end
    endtask

    initial begin
        failures = 0;
        OE_n = 1'b1;
        LE = 1'b0;
        D = 1'b0;
`ifndef VERILATOR
        check(1'bz);
`endif

        OE_n = 1'b0;
        LE = 1'b1;
        D = 1'b0;
        check(1'b0);

        D = 1'b1;
        check(1'b1);

        LE = 1'b0;
        D = 1'b0;
        check(1'b1);

        OE_n = 1'b1;
`ifndef VERILATOR
        check(1'bz);
`endif

        LE = 1'b1;
        check(1'b0);

        OE_n = 1'b0;
        check(1'b0);

        if (failures != 0) $fatal(1, "%0d checks failed", failures);

        $display("PASS cd74act373_tb");
        $finish;
    end

endmodule

`default_nettype wire
