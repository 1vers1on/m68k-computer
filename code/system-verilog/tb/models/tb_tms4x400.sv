`timescale 1ns / 1ps

module tb_tms4x400;

    reg  [9:0] A;
    reg        RAS_N, CAS_N, W_N, OE_N;
    wire [3:0] DQ;

    reg  [3:0] dq_drive;
    reg        dq_en;

    assign DQ = dq_en ? dq_drive : 4'bz;

    tms4x400 dut(
        .A(A), .RAS_N(RAS_N), .CAS_N(CAS_N), .W_N(W_N), .OE_N(OE_N), .DQ(DQ)
    );

    integer errors = 0;
    integer i;
    logic [3:0] rd;

    task check(input [3:0] got, exp, input string name);
        if (got !== exp) begin
            $display("FAIL %s got=%h want=%h", name, got, exp);
            errors = errors + 1;
        end
    endtask

    task ras_only_refresh(input [9:0] row);
        begin
            A = row;
            #10 RAS_N = 0;
            #80 RAS_N = 1;
            #50;
        end
    endtask

    task cbr_refresh;
        begin
            CAS_N = 0;
            #10 RAS_N = 0;
            #20 CAS_N = 1;
            #50 RAS_N = 1;
            #50;
        end
    endtask

    task early_write(input [9:0] row, input [9:0] col, input [3:0] data);
        begin
            A = row;
            #10 RAS_N = 0;
            #20 A = col;
            #10 W_N = 0; dq_en = 1; dq_drive = data;
            #10 CAS_N = 0;
            #15 W_N = 1;
            #5  dq_en = 0;
            #25 CAS_N = 1;
            #15 RAS_N = 1;
            #50;
        end
    endtask

    task read_cycle(input [9:0] row, input [9:0] col, output [3:0] data);
        begin
            A = row;
            #10 RAS_N = 0;
            #20 A = col;
            #20 CAS_N = 0;
            #5  OE_N = 0;
            #25 data = DQ;
            #5  OE_N = 1;
            #10 CAS_N = 1;
            #15 RAS_N = 1;
            #50;
        end
    endtask

    initial begin
        A = 10'd0;
        RAS_N = 1'b1;
        CAS_N = 1'b1;
        W_N   = 1'b1;
        OE_N  = 1'b1;
        dq_en = 1'b0;
        dq_drive = 4'b0;

        #200000;

        for (i = 0; i < 8; i = i + 1)
            ras_only_refresh(i[9:0]);

        early_write(10'd0, 10'd0, 4'hA);
        early_write(10'd0, 10'd1, 4'h5);
        early_write(10'd1, 10'd0, 4'h3);
        early_write(10'd0, 10'd2, 4'hF);

        check(dut.peek(10'd0, 10'd0), 4'hA, "peek 0,0");
        check(dut.peek(10'd0, 10'd1), 4'h5, "peek 0,1");
        check(dut.peek(10'd1, 10'd0), 4'h3, "peek 1,0");
        check(dut.peek(10'd0, 10'd2), 4'hF, "peek 0,2");

        read_cycle(10'd0, 10'd0, rd);
        check(rd, 4'hA, "read 0,0");
        read_cycle(10'd0, 10'd1, rd);
        check(rd, 4'h5, "read 0,1");
        read_cycle(10'd1, 10'd0, rd);
        check(rd, 4'h3, "read 1,0");
        read_cycle(10'd0, 10'd2, rd);
        check(rd, 4'hF, "read 0,2");

        cbr_refresh;

        check(dut.peek(10'd0, 10'd0), 4'hA, "peek after cbr 0,0");
        check(dut.peek(10'd0, 10'd2), 4'hF, "peek after cbr 0,2");

        #100;

        if (dut.n_viol != 0) begin
            $display("FAIL %0d timing violations", dut.n_viol);
            errors = errors + 1;
        end

        if (errors == 0) begin
            $display("PASS tb_tms4x400");
        end else begin
            $fatal(1, "FAIL tb_tms4x400: %0d errors", errors);
        end

        $finish;
    end

endmodule
