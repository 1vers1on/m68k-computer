`timescale 1ns / 1ps
`default_nettype none

module tb_dram_controller;
    logic CPU_CLK_DIV2 = 0;
    logic CPU_CLK_10 = 0;
    always #25 CPU_CLK_DIV2 = ~CPU_CLK_DIV2;
    always @(posedge CPU_CLK_DIV2) CPU_CLK_10 <= ~CPU_CLK_10;

    logic [31:0] random_state = 32'h68000400;
    logic RESET_n = 1;
    logic [23:0] A = 0;
    logic AS_n = 1, UDS_n = 1, LDS_n = 1, R_W = 1;
    logic RAM0_REQ_n = 1, RAM1_REQ_n = 1;
    logic [15:0] cpu_data = 0;
    logic cpu_drive = 0;
    tri [15:0] D;
    tri [15:0] DRAM_D;
    assign D = cpu_drive ? cpu_data : 16'hzzzz;
    wire [9:0] DRAM_A;
    wire RAS0_n, RAS1_n, CAS_U_n, CAS_L_n, W_n, OE_n;
    wire DRAM_ADDR_COL, DRAM_DTACK_n, DRAM_INIT_DONE, ROM_CLK, INT_CLK;

    dram_controller dut (.*);

    // Both banks share the isolated DRAM_D bus, addresses, CAS, W, and OE. DQ[0] is DQ1,
    // connected to the highest CPU bit of each nibble per dram.html.
    wire [31:0] violations [0:7];
    wire [31:0] warnings [0:7];
    wire [31:0] refreshes [0:7];
    wire [9:0] refresh_row [0:7];
    wire [7:0] ready;
    for (genvar b = 0; b < 2; b = b + 1) begin : bank
        for (genvar n = 0; n < 4; n = n + 1) begin : nibble
            tms4x400 #(.SPEED(70), .TIMING_CHECKS(1), .CHECK_ACCESS_MAX(0),
                .REFRESH_CHECKS(1), .DECAY_ENABLE(1), .POWERUP_CHECKS(1)) ram (
                .A(DRAM_A), .RAS_N(b == 0 ? RAS0_n : RAS1_n),
                .CAS_N(n < 2 ? CAS_U_n : CAS_L_n), .W_N(W_n), .OE_N(OE_n),
                .DQ({DRAM_D[12-4*n], DRAM_D[13-4*n], DRAM_D[14-4*n], DRAM_D[15-4*n]}));
            assign violations[4*b+n] = ram.n_viol;
            assign warnings[4*b+n] = ram.n_warn;
            assign refreshes[4*b+n] = ram.n_ref;
            assign refresh_row[4*b+n] = ram.cbr_cnt;
            assign ready[4*b+n] = ram.pwr_ready;
        end
    end

    task automatic check(input bit condition, input string message);
        if (!condition) $fatal(1, "%s at %0t", message, $time);
    endtask

    // A watchdog makes missing initialization/DTACK an unambiguous failure.
    initial begin
        #20000000;
        $fatal(1, "testbench watchdog expired");
    end

    // Count accepted operations independently of data-path readback. Sample
    // grants before the edge, and check credit arithmetic after clock-to-Q.
    int cpu_starts = 0, refresh_grants = 0, ticks = 0, cbr_cycles = 0;
    int credit_expected;
    always @(posedge dut.DRAM_CLK_C) begin
        if (RESET_n && $time > 100) begin
            credit_expected = dut.CREDIT_Q;
            if (dut.REFRESH_TICK) ticks++;
            if (dut.REFRESH_SERVICE) begin
                refresh_grants++;
                check(dut.CREDIT_Q != 0, "no refresh-credit underflow");
                check(!dut.CPU_START, "CPU and refresh cannot start together");
            end
            if (dut.CPU_START) begin
                cpu_starts++;
                check(dut.CREDIT_Q == 0, "pending refresh has priority");
            end
            case ({dut.REFRESH_TICK, dut.REFRESH_SERVICE})
                2'b10: credit_expected++;
                2'b01: credit_expected--;
                default: ;
            endcase
            #15;
            if (RESET_n)
                check(dut.CREDIT_Q === credit_expected[3:0], "refresh-credit accounting");
        end
    end

    // Verify addresses at the actual strobe pins, not from controller state.
    // Both RAS lines may fall together only for all-device CBR refresh.
    always @(negedge RAS0_n) begin
        if (RESET_n && $time > 100) begin
            if (!CAS_U_n && !CAS_L_n) begin
                cbr_cycles++;
                #1;
                check(!RAS1_n && W_n && OE_n, "all-bank CBR controls");
                check(DRAM_DTACK_n && !DRAM_ADDR_COL, "refresh neither ACKs nor selects column");
            end else begin
                check(DRAM_A === A[10:1], "bank 0 row-address mapping");
                check(RAS1_n, "bank 0 CPU access excludes bank 1");
            end
        end
    end
    always @(negedge RAS1_n) begin
        if (RESET_n && $time > 100 && (CAS_U_n || CAS_L_n)) begin
            check(DRAM_A === A[10:1], "bank 1 row-address mapping");
            check(RAS0_n, "bank 1 CPU access excludes bank 0");
        end
    end
    always @(negedge CAS_U_n or negedge CAS_L_n) begin
        if (RESET_n && $time > 100 && (!RAS0_n || !RAS1_n))
            check(DRAM_A === A[20:11], "column-address mapping");
    end

    // CPU data must already be stable before ACK; the DRAM model also checks
    // all its runtime timing requirements. Unselected read lanes must float.
    realtime data_changed = 0;
    always @(D) data_changed = $realtime;
    always @(negedge CAS_U_n or negedge CAS_L_n) begin
        #25;
        if (RESET_n && dut.CPU_BUSY && dut.DRAM_CPU_REQ && !dut.CPU_REQUEST_ENDED) begin
            check((dut.TX_BANK1 ? RAS1_n : RAS0_n) === 1'b0, "selected bank active at CAS");
            check((dut.TX_BANK1 ? RAS0_n : RAS1_n) === 1'b1, "other bank inactive at CAS");
            check({CAS_U_n,CAS_L_n} === {~dut.TX_UPPER,~dut.TX_LOWER}, "captured byte-lane CAS");
            check(W_n === !dut.TX_WRITE, "captured read/write direction at CAS");
            check(OE_n === dut.TX_WRITE, "DRAM drives only reads");
        end
    end
    always @(negedge DRAM_DTACK_n) begin
        if (RESET_n && R_W)
            check($realtime - data_changed >= 5.0, "read data setup before acknowledgement");
    end

    task automatic begin_cycle(input logic [23:0] address,
        input bit write_cycle, input logic [1:0] lanes, input logic [15:0] data);
        // Vary CPU/controller phase with a deterministic offset. Writes have
        // address/direction/data setup before their first byte strobe.
        @(negedge CPU_CLK_DIV2); #(3 + random_state[3:0]);
        A = address; R_W = !write_cycle; AS_n = 0;
        RAM0_REQ_n = address[21]; RAM1_REQ_n = !address[21];
        cpu_data = data; cpu_drive = write_cycle;
        #75;
        UDS_n = !lanes[1]; LDS_n = !lanes[0];
    endtask

    task automatic await_ack(output logic [15:0] result);
        begin : poll
            for (int k = 0; k < 200; k++) begin
                #10;
                if (DRAM_DTACK_n === 1'b0) begin
                    result = D;
                    check(DRAM_INIT_DONE === 1'b1, "no ACK before initialization");
                    // ACK follows data capture; the physical row may be closed.
                    if (R_W) begin
                        if (UDS_n) check(D[15:8] === 8'hzz, "unselected upper byte floats");
                        if (LDS_n) check(D[7:0] === 8'hzz, "unselected lower byte floats");
                    end
                    // Completion-tree delay, asynchronous DTACK recognition,
                    // then the CPU's following data-sampling cycle.
                    #230;
                    check(D === result, "data retained through delayed CPU sampling");
                    disable poll;
                end
            end
            $fatal(1, "no DRAM acknowledgement for %h", A);
        end
    endtask

    // release_kind tests AS-only and byte-strobe-only release independently.
    task automatic end_cycle(input int release_kind = 0, input int recovery = 600);
        if (release_kind != 2) AS_n = 1;
        if (release_kind != 1) begin UDS_n = 1; LDS_n = 1; end
        #30;
        check(DRAM_DTACK_n === 1'b1, "DTACK releases within 30 ns locally");
        AS_n = 1; UDS_n = 1; LDS_n = 1;
        RAM0_REQ_n = 1; RAM1_REQ_n = 1;
        cpu_drive = 0;
        #60;
        check(D === 16'hzzzz, "DRAM releases data bus after request end");
        #(recovery);
    endtask

    task automatic transfer(input logic [23:0] address,
        input bit write_cycle, input logic [1:0] lanes,
        input logic [15:0] data, output logic [15:0] result);
        begin_cycle(address, write_cycle, lanes, data);
        await_ack(result);
        #30;
        end_cycle();
    endtask

    task automatic reset_controller;
        RESET_n = 0;
        #100;
        check({RAS0_n,RAS1_n,CAS_U_n,CAS_L_n,W_n,OE_n,DRAM_DTACK_n} === 7'h7f,
            "reset leaves external controls inactive");
        check(!DRAM_INIT_DONE && !DRAM_ADDR_COL && dut.CREDIT_Q == 0,
            "reset clears initialization, mux, and credits");
        AS_n = 1; UDS_n = 1; LDS_n = 1;
        RAM0_REQ_n = 1; RAM1_REQ_n = 1; cpu_drive = 0;
        #200; RESET_n = 1;
    endtask

    logic [15:0] result;
    logic [23:0] addresses [0:23];
    logic [15:0] expected [0:1][0:23];
    logic [1:0] lanes;
    logic [15:0] value;
    int index, selected_bank, mark_cpu, mark_cbr, mark_ticks, mark_grants;
    int sweep_start;
    realtime reset_released, sweep_time;

    // Fixed-seed PRNG keeps failures reproducible across simulator versions.
    task automatic next_random;
        random_state = random_state ^ (random_state << 13);
        random_state = random_state ^ (random_state >> 17);
        random_state = random_state ^ (random_state << 5);
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile(".build/dram_controller.vcd");
            $dumpvars(1, tb_dram_controller);
            $dumpvars(1, dut);
        end
        $display("Checking startup and request qualification");
        #1; reset_controller(); reset_released = $realtime;
        begin_cycle(24'h1000, 0, 2'b11, 0);
        #2000;
        check(DRAM_DTACK_n && RAS0_n && RAS1_n, "CPU waits during startup");
        end_cycle();
        wait (DRAM_INIT_DONE === 1'b1);
        check($realtime - reset_released >= 200000, "startup pause is at least 200 us");
        #500;
        check(ready === 8'hff, "all eight memories initialized");
        for (int i = 0; i < 8; i++) check(refreshes[i] == 8, "eight startup CBR cycles per chip");
        mark_cpu = cpu_starts;
        begin_cycle(24'h1000, 0, 2'b00, 0);
        #1000;
        check(cpu_starts == mark_cpu && DRAM_DTACK_n, "bank select alone does not start memory");
        end_cycle();
        AS_n = 0; UDS_n = 0; LDS_n = 0;
        // Neither bank selected: represents an unrelated peripheral access.
        #1000;
        check(cpu_starts == mark_cpu && DRAM_DTACK_n, "non-DRAM cycle is ignored");
        RAM0_REQ_n = 0; RAM1_REQ_n = 0;
        #1000;
        check(cpu_starts == mark_cpu && DRAM_DTACK_n, "dual-bank request is rejected");
        end_cycle();

        $display("Checking bank, nibble, byte-lane, and all address-bit wiring");
        addresses[0] = 0;
        for (int i = 1; i <= 20; i++) addresses[i] = 24'b1 << i;
        addresses[21] = 24'h1ffffe;
        addresses[22] = 24'h012346;
        addresses[23] = 24'h155554;
        for (int b = 0; b < 2; b++) begin
            for (int i = 0; i < 24; i++) begin
                next_random(); expected[b][i] = random_state[15:0];
                transfer(addresses[i] | (b << 21), 1, 2'b11, expected[b][i], result);
            end
        end
        for (int b = 0; b < 2; b++) begin
            for (int i = 0; i < 24; i++) begin
                transfer(addresses[i] | (b << 21), 0, 2'b11, 0, result);
                check(result === expected[b][i], "independent address/bank readback");
            end
        end
        // Writes change only the selected byte; reads must leave the other
        // lane high-Z, even though the banks share CAS and data wires.
        for (int k = 0; k < 128; k++) begin
            next_random(); index = random_state[7:0] % 24;
            selected_bank = random_state[8];
            lanes = (k % 3) + 1;
            value = random_state[31:16];
            transfer(addresses[index] | (selected_bank << 21), 1, lanes, value, result);
            if (lanes[1]) expected[selected_bank][index][15:8] = value[15:8];
            if (lanes[0]) expected[selected_bank][index][7:0] = value[7:0];
            transfer(addresses[index] | (selected_bank << 21), 0, lanes, 0, result);
            if (lanes[1]) check(result[15:8] === expected[selected_bank][index][15:8], "upper-byte read");
            if (lanes[0]) check(result[7:0] === expected[selected_bank][index][7:0], "lower-byte read");
            transfer(addresses[index] | (selected_bank << 21), 0, 2'b11, 0, result);
            check(result === expected[selected_bank][index], "byte write preserves other lane");
        end

        $display("Checking acknowledgement release, re-arm, and held requests");
        for (int kind = 1; kind <= 2; kind++) begin
            begin_cycle(addresses[22], 0, 2'b11, 0);
            await_ack(result);
            #20; end_cycle(kind, 20);
            // Check a new transaction after each independent release path.
            begin_cycle(addresses[22] | 24'h200000, 0, 2'b11, 0);
            await_ack(result);
            check(result === expected[1][22], "fresh request after short bus gap");
            #20; end_cycle();
        end
        // Exactly 105 ns from both strobes high to the next strobes low.
        // Sweep release across a complete 50 ns controller clock period.
        for (int offset = 0; offset < 50; offset++) begin
            begin_cycle(addresses[22], 0, 2'b11, 0);
            await_ack(result);
            #(20 + offset);
            end_cycle(0, 0); // 90 ns elapsed, including output-release check
            A = addresses[22] | 24'h200000;
            AS_n = 0; RAM0_REQ_n = 1; RAM1_REQ_n = 0;
            #15; UDS_n = 0; LDS_n = 0;
            await_ack(result);
            check(result === expected[1][22], "new transaction after minimum 105 ns strobe gap");
            #20; end_cycle();
        end

        // Abort a read before ACK, as an external bus-error path would do.
        mark_cpu = cpu_starts;
        begin_cycle(addresses[22], 0, 2'b11, 0);
        @(negedge RAS0_n); #30;
        check(DRAM_DTACK_n, "early abort precedes acknowledgement");
        end_cycle();
        check(cpu_starts == mark_cpu + 1 && DRAM_DTACK_n,
            "aborted request retires without stale acknowledgement");

        begin_cycle(addresses[22], 0, 2'b11, 0);
        await_ack(result);
        mark_cpu = cpu_starts; mark_cbr = cbr_cycles;
        mark_ticks = ticks; mark_grants = refresh_grants;
        // Fault injection: hold the CPU cycle despite ACK, for the documented
        // motherboard timeout interval. Physical RAS/CAS must still close.
        #51200;
        check(D === result && result === expected[0][22],
            "read data retained through DMA READY stall and timeout interval");
        check(DRAM_D === 16'hzzzz, "DRAM bus floats while read registers hold CPU data");
        check(cpu_starts == mark_cpu, "held request is executed once");
        check(cbr_cycles == mark_cbr, "refresh does not preempt held CPU ownership");
        check({RAS0_n,RAS1_n,CAS_U_n,CAS_L_n} === 4'hf, "strobe widths bounded during CPU stall");
        check(dut.CREDIT_Q >= 4 && dut.CREDIT_Q <= 5, "timeout backlog bounded to five credits");
        check(ticks - mark_ticks == dut.CREDIT_Q, "all blocked refresh events retained");
        end_cycle();
        begin_cycle(addresses[22] | 24'h200000, 0, 2'b11, 0);
        await_ack(result);
        check(result === expected[1][22], "request survives refresh backlog");
        check(refresh_grants - mark_grants >= ticks - mark_ticks,
            "backlog drains before new CPU service");
        #20; end_cycle();

        $display("Checking CPU arrival during CBR and reset during a read");
        @(negedge CAS_U_n);
        check(RAS0_n && RAS1_n, "periodic refresh starts CAS before RAS");
        begin_cycle(addresses[22], 0, 2'b11, 0);
        await_ack(result);
        check(result === expected[0][22], "CPU request arriving during refresh is retained");
        #20;
        // The memory's minimum pulse widths have elapsed at this point;
        // reset still interrupts an active read and an asserted ACK.
        mark_cbr = cbr_cycles;
        reset_controller(); reset_released = $realtime;
        wait (DRAM_INIT_DONE === 1'b1); #500;
        check($realtime - reset_released >= 200000, "reset restarts full startup delay");
        check(cbr_cycles - mark_cbr == 8, "reset repeats eight CBR initialization cycles");

        $display("Checking a complete 1024-row CBR sweep and retained data");
        sweep_start = cbr_cycles; sweep_time = $realtime;
        wait (cbr_cycles >= sweep_start + 1024);
        #500;
        check($realtime - sweep_time < 16000000, "all rows refreshed within 16 ms");
        // The DRAM chip's internal row counters must advance together, even
        // though normal accesses have selected different banks and lanes.
        for (int i = 1; i < 8; i++)
            check(refresh_row[i] === refresh_row[0], "all eight CBR counters agree");
        for (int b = 0; b < 2; b++) begin
            for (int i = 0; i < 24; i++) begin
                transfer(addresses[i] | (b << 21), 0, 2'b11, 0, result);
                check(result === expected[b][i], "data retained after full refresh sweep");
            end
        end
        for (int i = 0; i < 8; i++) begin
            check(violations[i] == 0, $sformatf("chip %0d has timing failures", i));
            check(warnings[i] == 0, $sformatf("chip %0d has warnings", i));
        end
        $display("PASS dram_controller: %0d CPU transfers, %0d CBR cycles, all eight DRAM timing checks clean",
            cpu_starts, cbr_cycles);
        $finish;
    end
endmodule

`default_nettype wire
