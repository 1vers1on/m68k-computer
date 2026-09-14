`timescale 1ns / 1ps
`default_nettype none

module sn74hct245_tb;

    logic OE_n;
    logic DIR;
    logic drive_a_en;
    logic drive_a;
    logic drive_b_en;
    logic drive_b;
    tri   A;
    tri   B;
    integer failures;

    assign A = drive_a_en ? drive_a : 1'bz;
    assign B = drive_b_en ? drive_b : 1'bz;

    sn74hct245 dut (
        .OE_n(OE_n),
        .DIR(DIR),
        .A(A),
        .B(B)
    );

    task automatic check;
        input logic expected_a;
        input logic expected_b;
        begin
            #1;

            if (A !== expected_a || B !== expected_b) begin
                $display("FAIL A=%b B=%b expected=%b/%b", A, B, expected_a, expected_b);
                failures = failures + 1;
            end
        end
    endtask

    initial begin
        failures = 0;
        OE_n = 1'b1;
        DIR = 1'b1;
        drive_a_en = 1'b0;
        drive_a = 1'b0;
        drive_b_en = 1'b0;
        drive_b = 1'b0;
`ifndef VERILATOR
        check(1'bz, 1'bz);
`endif

        drive_a_en = 1'b1;
        drive_a = 1'b1;
        OE_n = 1'b0;
        check(1'b1, 1'b1);

        drive_a = 1'b0;
        check(1'b0, 1'b0);

        OE_n = 1'b1;
`ifndef VERILATOR
        check(1'b0, 1'bz);
`endif

        drive_a_en = 1'b0;
        drive_b_en = 1'b1;
        drive_b = 1'b1;
        DIR = 1'b0;
        OE_n = 1'b0;
        check(1'b1, 1'b1);

        drive_b = 1'b0;
        check(1'b0, 1'b0);

        OE_n = 1'b1;
`ifndef VERILATOR
        check(1'bz, 1'b0);
`endif

        if (failures != 0) $fatal(1, "%0d checks failed", failures);

        $display("PASS sn74hct245_tb");
        $finish;
    end

endmodule

`default_nettype wire
