# SystemVerilog

Simulation models for the DRAM controller, DMA bus glue, and their 74-series and memory devices.

## Layout

| Path      | Contents                                                                                |
| --------- | --------------------------------------------------------------------------------------- |
| `rtl/`    | Design sources. `rtl/models/` holds reusable device models.                             |
| `test/`   | Testbenches, mirroring the layout beneath `rtl/` where appropriate.                     |
| `.build/` | Generated simulator executables, logs, and waveforms; safe to delete with `make clean`. |

## Requirements

Use the project's Linux-only Icarus Verilog fork, with `iverilog` and `vvp` on
`PATH`. The models depend on support added in that fork; stock Windows builds
are not a substitute.

## Commands

```sh
# From this directory
make test
make test NAME=dram_controller
make check
make list
make clean
```

`make test` recompiles and runs the selected testbenches on every invocation.
A test passes only if compilation and simulation succeed, the log contains a
line starting with `PASS`, and no line starts with `FAIL`, `FATAL`, or `ERROR`.
Leading whitespace is allowed. Each test's output is saved in `.build/<name>.log` and printed on failure.
Unknown test names are rejected; `NAME` accepts only names shown by `make list`.

Use `make -j4 test` to run up to four simulations at once. Override `IVERILOG`,
`VVP`, or `IVERILOG_FLAGS` on the command line if needed. Keep `-g2012 -gspecify`
in the compiler flags to enable SystemVerilog and modeled propagation delays.

`make test-runner` checks the runner's failure handling with Python 3. It uses
temporary fixtures and does not require Icarus Verilog. `make check` runs both
the simulations and these runner tests.

From the repository root, use `make check PROJECT=code/system-verilog` to check
this project, or `make test PROJECT=code/system-verilog NAME=dram_controller` to run one
simulation.

The code is licensed under the [GNU GPL v3.0](../LICENSE).

## DRAM controller

`rtl/dram_controller.sv` implements the discrete controller described in
[`dram.html`](../../../docs/static/dram.html). It instantiates the existing FAST
logic, ACT mux/buffer, HCT timer, F194 transaction-register, and F191
refresh-counter models. It is a structural simulation model; the scalar gate
and flip-flop instances represent individual IC channels.

Connect the controller as follows:

| Port                                    | Connection                                                                                  |
| --------------------------------------- | ------------------------------------------------------------------------------------------- |
| `A[23:0]`                               | CPU byte address; the mux uses `A[20:1]`. `A[0]` is unused.                                 |
| `RAM0_REQ_n`, `RAM1_REQ_n`              | Qualified bank requests from the motherboard decode; exactly one must be low for a transfer. |
| `AS_n`, `UDS_n`, `LDS_n`, `R_W`         | CPU bus strobes and transfer direction.                                                     |
| `CPU_CLK_DIV2`, `CPU_CLK_10`, `RESET_n` | Motherboard 20 MHz clock, related 10 MHz clock, and active-low reset.                       |
| `DRAM_A[9:0]`                           | Shared multiplexed address inputs on all eight DRAMs.                                       |
| `D[15:0]`                              | Motherboard data bus shared by the CPU, DMA, and peripherals. |
| `DRAM_D[15:0]`                         | Isolated data bus shared by both DRAM banks. |
| `RAS0_n`, `RAS1_n`                      | Four DRAM RAS inputs per bank.                                                              |
| `CAS_U_n`, `CAS_L_n`                    | Upper/lower byte CAS inputs in both banks.                                                  |
| `W_n`, `OE_n`                           | Shared write and output-enable inputs on all eight DRAMs.                                   |
| `DRAM_DTACK_n`                          | The decoder's DRAM completion input, not a wired-OR bus.                                    |
| `DRAM_ADDR_COL`, `DRAM_INIT_DONE`       | Address-mux selection and initialization status.                                            |
| `ROM_CLK`, `INT_CLK`                    | Buffered 10 MHz clocks for the ROM and interrupt circuits.                                  |

Connect DRAM DQ pins to `DRAM_D`, preserving the documented nibble order.
Two HCT574 registers capture reads at phase 4 and drive the selected motherboard
byte lanes until raw request release. Two ACT244 buffers carry writes from `D`
to `DRAM_D`. ACK arms at phase 5 and registers at phase 6, when the physical
DRAM strobes close. Read data remains available during a DMA READY stall.
`test/tb_dram_controller.sv` shows the full two-bank, eight-chip wiring using
`tms4x400` at speed grade 70, including the document's DQ1-to-highest-nibble-bit
mapping. It generates qualified bank requests directly; the motherboard
decoder, CPU instruction execution, and global DTACK tree are outside this test.

```sh
make test NAME=dram_controller

# Optional waveform, after compiling the test above:
vvp .build/dram_controller.out +vcd
# Output: .build/dram_controller.vcd
```

The self-checking test runs the actual startup and refresh intervals. It checks
all address bits, independent banks, deterministic randomized word/byte writes,
unselected read lanes at high impedance, request qualification, AS-only and
byte-strobe-only ACK release, and aborted reads. It sweeps a 105 ns inter-cycle
strobe gap across the controller clock period, delays CPU sampling by 230 ns
after local ACK, holds a read for 51.2 us to check data retention and
refresh-credit accumulation, resets during an active read,
and verifies retained data after a complete 1,024-row CBR sweep. All eight DRAM
models have timing, power-up, refresh, and decay checking enabled. Any unexpected
DRAM timing violation or warning fails the test; a watchdog catches hangs.

The minimum-gap regression exposed two problems in the original documented
logic: stale `ACK_ARM` could acknowledge a new cycle, and a request-clear pulse
could finish before phase 9 observed it. The controller uses the spare third
`U_DRAM_MODE` flip-flop as `CPU_REQUEST_ENDED` and qualifies `ACK_D` with
`REQ_SYNC2` and the complementary request-end output. The matching equations
and acknowledgement gate assignments are updated in `dram.html`.

The read-retention changes have not been simulated. Run the updated testbench
with the project's fork. Simulation does not establish board timing closure:
clock skew, analog loading, metastability, and setup/hold need separate checks.
The read registers use the SN74HCT574 full-temperature timing requirements and
150 pF clock-to-output and enable limits. The count-7 equation uses equivalent
F08/F04 gates because the repository has no F20 model; gate allocation is not a
package-exact netlist.

## DMA bus glue

`rtl/dma_bus_glue.sv` describes the arbitration bridge, expansion data enables,
and CPU register DTACK qualifier in `dma.html` and `expansion.html`.
`CPU_BR_n` stays low while either the DMAC requests the bus or `OWN_n` is low.
Only the expansion lower-byte transceiver enables during a channel's DMA
transfer, and its direction inverts the memory R/W direction.

Feed `DMAC_DTACK_RAW_n` from the CPU-side HCT125 isolation output and connect
`DMAC_DTACK_n` to completion group 3. `DMAC_CS_n` must include the documented
CPU-ownership and byte-strobe qualification. Two clocked arm stages prevent a
late source release from acknowledging the next CPU access; raw strobes force
completion inactive on release. This module has not been simulated.
