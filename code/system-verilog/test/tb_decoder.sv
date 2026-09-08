`timescale 1ns / 1ps

module tb_decoder;

    reg [23:0] A;
    reg [2:0]  FC;
    reg        AS_n, UDS_n, LDS_n, R_W, CLK, RESET_n;
    reg [7:0]  D;
    reg        DRAM_DTACK_n, ROM_DTACK_n, MFP_DTACK_n, FDC_DTACK_n;
    reg        OPL3_DTACK_n, VGA_DTACK_n, MIDI_DTACK_n, RTC_DTACK_n;
    reg        EXP_DTACK_n, INT_BERR_n;

    wire        DTACK_n, BERR_n;
    wire        RAM0_REQ_n, RAM1_REQ_n, VGA_MEM_n;
    wire        EXP_MEM2_n, EXP_MEM3_n, EXP_MEM5_n, EXP_MEM6_n;
    wire [15:0] IO_n;
    wire [7:0]  SYSREG_n;
    wire        ROM_CYCLE_n, ROM0_UDS_n, ROM0_LDS_n, ROM1_UDS_n, ROM1_LDS_n;
    wire        READ_n;
    wire [7:0]  DEBUG_Q;
    wire        OVERLAY_EN, OVERLAY_n;

    integer errors = 0;

    decoder dut (
        .A(A), .FC(FC), .AS_n(AS_n), .UDS_n(UDS_n), .LDS_n(LDS_n), .R_W(R_W),
        .CLK(CLK), .RESET_n(RESET_n), .D(D),
        .DRAM_DTACK_n(DRAM_DTACK_n), .ROM_DTACK_n(ROM_DTACK_n),
        .MFP_DTACK_n(MFP_DTACK_n), .FDC_DTACK_n(FDC_DTACK_n),
        .OPL3_DTACK_n(OPL3_DTACK_n), .VGA_DTACK_n(VGA_DTACK_n),
        .MIDI_DTACK_n(MIDI_DTACK_n), .RTC_DTACK_n(RTC_DTACK_n),
        .EXP_DTACK_n(EXP_DTACK_n), .INT_BERR_n(INT_BERR_n),
        .DTACK_n(DTACK_n), .BERR_n(BERR_n),
        .RAM0_REQ_n(RAM0_REQ_n), .RAM1_REQ_n(RAM1_REQ_n), .VGA_MEM_n(VGA_MEM_n),
        .EXP_MEM2_n(EXP_MEM2_n), .EXP_MEM3_n(EXP_MEM3_n),
        .EXP_MEM5_n(EXP_MEM5_n), .EXP_MEM6_n(EXP_MEM6_n),
        .IO_n(IO_n), .SYSREG_n(SYSREG_n), .ROM_CYCLE_n(ROM_CYCLE_n),
        .ROM0_UDS_n(ROM0_UDS_n), .ROM0_LDS_n(ROM0_LDS_n),
        .ROM1_UDS_n(ROM1_UDS_n), .ROM1_LDS_n(ROM1_LDS_n),
        .READ_n(READ_n), .DEBUG_Q(DEBUG_Q),
        .OVERLAY_EN(OVERLAY_EN), .OVERLAY_n(OVERLAY_n)
    );

    task check(input sig, input exp, input string name);
        begin
            if (sig !== exp) begin
                $display("FAIL %s got=%b want=%b", name, sig, exp);
                errors = errors + 1;
            end
        end
    endtask

    task check8(input [7:0] got, input [7:0] exp, input string name);
        begin
            if (got !== exp) begin
                $display("FAIL %s got=%h want=%h", name, got, exp);
                errors = errors + 1;
            end
        end
    endtask

    task check16(input [15:0] got, input [15:0] exp, input string name);
        begin
            if (got !== exp) begin
                $display("FAIL %s got=%h want=%h", name, got, exp);
                errors = errors + 1;
            end
        end
    endtask

    // Drive a normal (non-CPU-space) bus cycle and settle.
    task bus_cycle(input [23:0] addr, input [2:0] fc, input rw,
                   input uds, input lds);
        begin
            A    = addr;
            FC   = fc;
            R_W  = rw;
            UDS_n = uds;
            LDS_n = lds;
            AS_n = 1'b0;
            #300;
        end
    endtask

    task bus_idle;
        begin
            AS_n = 1'b1;
            UDS_n = 1'b1;
            LDS_n = 1'b1;
            R_W  = 1'b1;
            FC   = 3'b000;
            #300;
        end
    endtask

    task clk_pulse;
        begin
            CLK = 1'b1; #50;
            CLK = 1'b0; #50;
        end
    endtask

    initial begin
        A = 24'h000000; FC = 3'b000;
        AS_n = 1'b1; UDS_n = 1'b1; LDS_n = 1'b1; R_W = 1'b1;
        CLK = 1'b0; RESET_n = 1'b1; D = 8'h00;
        DRAM_DTACK_n = 1'b1; ROM_DTACK_n = 1'b1; MFP_DTACK_n = 1'b1;
        FDC_DTACK_n  = 1'b1; OPL3_DTACK_n = 1'b1; VGA_DTACK_n = 1'b1;
        MIDI_DTACK_n = 1'b1; RTC_DTACK_n  = 1'b1; EXP_DTACK_n = 1'b1;
        INT_BERR_n   = 1'b1;
        #200;

        // ---- Reset enables the boot overlay ----
        RESET_n = 1'b0; #200;
        check(OVERLAY_EN, 1'b1, "reset asserts overlay");
        check(OVERLAY_n, 1'b0, "reset asserts overlay_n");
        RESET_n = 1'b1; #200;

        // ---- Normal-cycle qualification: idle address is ignored ----
        A = 24'h300000; AS_n = 1'b1; #300;
        check(RAM1_REQ_n, 1'b1, "idle AS_n high keeps RAM1 inactive");

        // ---- CPU-space cycle suppresses normal decode ----
        A = 24'hE80003; FC = 3'b111; AS_n = 1'b0; R_W = 1'b0; LDS_n = 1'b0; UDS_n = 1'b1; #300;
        check(IO_n[4], 1'b1, "CPU-space suppresses IO4_n");
        check(SYSREG_n[1], 1'b1, "CPU-space suppresses SYSREG1_n");
        bus_idle;

        // ---- Boot alias: $000004 reads firmware while overlay enabled ----
        D = 8'h00;
        bus_cycle(24'h000004, 3'b001, 1'b1, 1'b0, 1'b0);
        check(ROM_CYCLE_n, 1'b0, "boot alias $000004 selects ROM_CYCLE_n");
        check(RAM0_REQ_n, 1'b1, "boot alias suppresses RAM0_REQ_n");
        check(ROM0_UDS_n, 1'b0, "boot alias upper-byte EEPROM enable");
        bus_idle;

        // ---- DRAM bank 0 above the alias still responds during boot ----
        bus_cycle(24'h100000, 3'b001, 1'b1, 1'b0, 1'b0);
        check(RAM0_REQ_n, 1'b0, "$100000 selects RAM0_REQ_n during boot");
        bus_idle;

        // ---- DRAM bank 1 request ----
        bus_cycle(24'h300000, 3'b001, 1'b1, 1'b0, 1'b0);
        check(RAM1_REQ_n, 1'b0, "$300000 selects RAM1_REQ_n");
        bus_idle;

        // ---- CL-GD5428 VGA host-memory window ----
        bus_cycle(24'h900000, 3'b001, 1'b1, 1'b0, 1'b0);
        check(VGA_MEM_n, 1'b0, "$900000 selects VGA_MEM_n");
        bus_idle;

        // ---- Expansion memory requests ----
        bus_cycle(24'h500000, 3'b001, 1'b1, 1'b0, 1'b0);
        check(EXP_MEM2_n, 1'b0, "$500000 selects EXP_MEM2_n");
        bus_cycle(24'h700000, 3'b001, 1'b1, 1'b0, 1'b0);
        check(EXP_MEM3_n, 1'b0, "$700000 selects EXP_MEM3_n");
        bus_cycle(24'hB00000, 3'b001, 1'b1, 1'b0, 1'b0);
        check(EXP_MEM5_n, 1'b0, "$B00000 selects EXP_MEM5_n");
        bus_cycle(24'hD00000, 3'b001, 1'b1, 1'b0, 1'b0);
        check(EXP_MEM6_n, 1'b0, "$D00000 selects EXP_MEM6_n");
        bus_idle;

        // ---- Top I/O slot decoders ----
        bus_cycle(24'hE00000, 3'b001, 1'b1, 1'b0, 1'b0);
        check(IO_n[0], 1'b0, "$E00000 selects IO0_n (MFP)");
        bus_cycle(24'hE20000, 3'b001, 1'b1, 1'b0, 1'b0);
        check(IO_n[1], 1'b0, "$E20000 selects IO1_n (floppy)");
        bus_cycle(24'hE40000, 3'b001, 1'b1, 1'b0, 1'b0);
        check(IO_n[2], 1'b0, "$E40000 selects IO2_n (OPL3)");
        bus_cycle(24'hE60000, 3'b001, 1'b1, 1'b0, 1'b0);
        check(IO_n[3], 1'b0, "$E60000 selects IO3_n (VGA I/O)");
        bus_cycle(24'hE80000, 3'b001, 1'b1, 1'b0, 1'b0);
        check(IO_n[4], 1'b0, "$E80000 selects IO4_n (system regs)");
        bus_cycle(24'hEA0000, 3'b001, 1'b1, 1'b0, 1'b0);
        check(IO_n[5], 1'b0, "$EA0000 selects IO5_n (MIDI)");
        bus_cycle(24'hF00000, 3'b001, 1'b1, 1'b0, 1'b0);
        check(IO_n[8], 1'b0, "$F00000 selects IO8_n (RTC)");
        bus_cycle(24'hFE0000, 3'b001, 1'b1, 1'b0, 1'b0);
        check(IO_n[15], 1'b0, "$FE0000 selects IO15_n (firmware)");
        bus_idle;

        // ---- System register decoder ----
        bus_cycle(24'hE80001, 3'b001, 1'b1, 1'b1, 1'b0);
        check(SYSREG_n[0], 1'b0, "$E80001 selects SYSREG0_n");
        bus_cycle(24'hE80003, 3'b001, 1'b1, 1'b1, 1'b0);
        check(SYSREG_n[1], 1'b0, "$E80003 selects SYSREG1_n");
        bus_idle;

        // ---- System register write qualification ----
        bus_cycle(24'hE80001, 3'b001, 1'b0, 1'b1, 1'b0);
        check(OVERLAY_EN, 1'b0, "SYSREG0 write disables overlay");
        check(DTACK_n, 1'b0, "system-register write asserts DTACK_n");
        bus_idle;

        // ---- Debug byte storage ----
        D = 8'hA5;
        bus_cycle(24'hE80003, 3'b001, 1'b0, 1'b1, 1'b0);
        check8(DEBUG_Q, 8'hA5, "debug register latches $A5");
        bus_idle;

        // ---- After overlay disable, low memory hits DRAM bank 0 ----
        bus_cycle(24'h000004, 3'b001, 1'b1, 1'b0, 1'b0);
        check(ROM_CYCLE_n, 1'b1, "overlay off -> $000004 not ROM");
        check(RAM0_REQ_n, 1'b0, "overlay off -> $000004 hits RAM0");
        bus_idle;

        // ---- Firmware permanent mapping and ROM bank/lane selection ----
        bus_cycle(24'hFE0000, 3'b001, 1'b1, 1'b0, 1'b1);
        check(ROM_CYCLE_n, 1'b0, "$FE0000 selects ROM_CYCLE_n");
        check(ROM0_UDS_n, 1'b0, "A16=0 UDS selects ROM0_UDS_n");
        check(ROM0_LDS_n, 1'b1, "A16=0 LDS high keeps ROM0_LDS_n inactive");
        bus_cycle(24'hFE0000, 3'b001, 1'b1, 1'b1, 1'b0);
        check(ROM0_LDS_n, 1'b0, "A16=0 LDS selects ROM0_LDS_n");
        bus_cycle(24'hFF0000, 3'b001, 1'b1, 1'b0, 1'b1);
        check(ROM1_UDS_n, 1'b0, "A16=1 UDS selects ROM1_UDS_n");
        bus_idle;

        // ---- READ_n follows R/W ----
        bus_cycle(24'hFE0000, 3'b001, 1'b1, 1'b0, 1'b1);
        check(READ_n, 1'b0, "read asserts READ_n");
        bus_cycle(24'hFE0000, 3'b001, 1'b0, 1'b0, 1'b1);
        check(READ_n, 1'b1, "write deasserts READ_n");
        bus_idle;

        // ---- DTACK combination tree ----
        check(DTACK_n, 1'b1, "no completion -> DTACK_n inactive");
        DRAM_DTACK_n = 1'b0; #300;
        check(DTACK_n, 1'b0, "DRAM_DTACK_n asserts DTACK_n");
        DRAM_DTACK_n = 1'b1;
        ROM_DTACK_n  = 1'b0; #300;
        check(DTACK_n, 1'b0, "ROM_DTACK_n asserts DTACK_n");
        ROM_DTACK_n = 1'b1;
        MFP_DTACK_n = 1'b0; #300;
        check(DTACK_n, 1'b0, "MFP_DTACK_n asserts DTACK_n");
        MFP_DTACK_n = 1'b1;
        EXP_DTACK_n = 1'b0; #300;
        check(DTACK_n, 1'b0, "EXP_DTACK_n asserts DTACK_n");
        EXP_DTACK_n = 1'b1; #300;
        check(DTACK_n, 1'b1, "all released -> DTACK_n inactive");

        // ---- Bus error sources ----
        INT_BERR_n = 1'b0; #300;
        check(BERR_n, 1'b0, "INT_BERR_n asserts BERR_n");
        INT_BERR_n = 1'b1; #300;
        check(BERR_n, 1'b1, "BERR_n inactive with no error");

        // ---- Bus timeout terminates an unanswered cycle ----
        bus_cycle(24'h500000, 3'b001, 1'b1, 1'b0, 1'b0);
        check(BERR_n, 1'b1, "BERR_n inactive before timeout");
        repeat (520) clk_pulse;
        check(BERR_n, 1'b0, "timeout asserts BERR_n");
        DRAM_DTACK_n = 1'b0; #300;
        check(DTACK_n, 1'b1, "timeout masks late DTACK_n");
        DRAM_DTACK_n = 1'b1;
        bus_idle;
        check(BERR_n, 1'b1, "AS_n release clears timeout BERR_n");
        check(DTACK_n, 1'b1, "AS_n release clears timeout DTACK_n mask");

        if (errors == 0) $display("PASS tb_decoder");
        else $fatal(1, "FAIL tb_decoder: %0d errors", errors);
    end

endmodule
