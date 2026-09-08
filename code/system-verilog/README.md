# SystemVerilog

Simulation models for the address decoder, DRAM controller, and their 74-series and memory devices.

## Layout

| Path      | Contents                                                                                |
| --------- | --------------------------------------------------------------------------------------- |
| `rtl/`    | Design sources. `rtl/models/` holds reusable device models.                             |
| `test/`   | Testbenches, mirroring the layout beneath `rtl/` where appropriate.                     |
| `.build/` | Generated simulator executables, logs, and waveforms; safe to delete with `make clean`. |

## Requirements

The test runner requires [Icarus Verilog](https://steveicarus.github.io/iverilog/) with SystemVerilog support (`iverilog` and `vvp` on `PATH`).

## Commands

```sh
# From this directory
make test
make test NAME=decoder
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
this project, or `make test PROJECT=code/system-verilog NAME=decoder` to run one
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
| `RAM0_REQ_n`, `RAM1_REQ_n`              | Already-qualified bank requests from `decoder`; exactly one must be low for a CPU transfer. |
| `AS_n`, `UDS_n`, `LDS_n`, `R_W`         | CPU bus strobes and transfer direction.                                                     |
| `CPU_CLK_DIV2`, `CPU_CLK_10`, `RESET_n` | Motherboard 20 MHz clock, related 10 MHz clock, and active-low reset.                       |
| `DRAM_A[9:0]`                           | Shared multiplexed address inputs on all eight DRAMs.                                       |
| `RAS0_n`, `RAS1_n`                      | Four DRAM RAS inputs per bank.                                                              |
| `CAS_U_n`, `CAS_L_n`                    | Upper/lower byte CAS inputs in both banks.                                                  |
| `W_n`, `OE_n`                           | Shared write and output-enable inputs on all eight DRAMs.                                   |
| `DRAM_DTACK_n`                          | The decoder's DRAM completion input, not a wired-OR bus.                                    |
| `DRAM_ADDR_COL`, `DRAM_INIT_DONE`       | Address-mux selection and initialization status.                                            |
| `ROM_CLK`, `INT_CLK`                    | Buffered 10 MHz clocks for the ROM and interrupt circuits.                                  |

The CPU data bus connects directly to the DRAM DQ pins outside this module.
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
strobe gap across the controller clock period, holds a CPU request for 51.2 us
to check refresh-credit accumulation and priority, resets during an active read,
and verifies retained data after a complete 1,024-row CBR sweep. All eight DRAM
models have timing, power-up, refresh, and decay checking enabled. Any unexpected
DRAM timing violation or warning fails the test; a watchdog catches hangs.

The minimum-gap regression exposed two problems in the original documented
logic: stale `ACK_ARM` could acknowledge a new cycle, and a request-clear pulse
could finish before phase 9 observed it. The controller uses the spare third
`U_DRAM_MODE` flip-flop as `CPU_REQUEST_ENDED` and qualifies `ACK_D` with
`REQ_SYNC2` and the complementary request-end output. The matching equations
and acknowledgement gate assignments are updated in `dram.html`.

Simulation does not establish board timing closure. Icarus applies modeled
propagation delays with `-gspecify`, but reports unsupported `specify` timing
checks and limited multibit path-delay support. The DRAM's procedural timing
checks and the testbench assertions still run. Clock skew, analog loading,
metastability, and setup/hold closure need separate verification. The model uses
the document's 9.6 ns ACT244 and 8 ns F194 propagation values, with other device
model defaults. The count-7 equation uses equivalent F08/F04 gates because the
repository has no F20 model; gate allocation is not a package-exact netlist.
