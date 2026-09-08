# SystemVerilog

Simulation models for the address decoder and the 74-series and memory devices that support it.

## Layout

| Path | Contents |
| --- | --- |
| `rtl/` | Design sources. `rtl/models/` holds reusable device models. |
| `test/` | Testbenches, mirroring the layout beneath `rtl/` where appropriate. |
| `.build/` | Generated simulator executables and logs; safe to delete with `make clean`. |

## Requirements

The test runner requires [Icarus Verilog](https://steveicarus.github.io/iverilog/) with SystemVerilog support (`iverilog` and `vvp` on `PATH`). 

## Commands

```sh
# From this directory
make test
make test NAME=decoder
make list
make clean
```

`make test` always recompiles and runs the selected testbenches, so test results cannot be mistaken for previous build output.

The code is licensed under the [GNU GPL v3.0](../LICENSE).
