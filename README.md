# 68EC000 Computer

A 10 MHz, 16-bit computer built around the Motorola MC68EC000FN10.

## At a glance

| Area             | Specification                                                                                |
| ---------------- | -------------------------------------------------------------------------------------------- |
| CPU              | Motorola MC68EC000FN10 at 10 MHz                                                             |
| CPU bus          | 24-bit address bus, 16-bit data bus, 16 MiB address space                                    |
| Main memory      | 4 MiB FPM DRAM in two 2 MiB banks, using eight TMS44400DJ-70 parts                           |
| Firmware         | 128 KiB, 16-bit-wide, read-only EEPROM storage in four AT28C256-15PU parts                   |
| Video            | Cirrus Logic CL-GD5428 VGA controller with 2 MiB VRAM and DE-15 output                       |
| Floppy           | Intel 82077AA-1 controller and two Mitsumi D359M3D 3.5-inch 1.44 MB drives                   |
| Sound            | Yamaha YMF262 OPL3, two YAC512 DACs, stereo amplifier, volume control, and 3.5 mm output     |
| Serial and input | MC68901 MFP with RS-232 on a DE-9 DTE connector and a bidirectional PS/2 keyboard port       |
| MIDI             | MC6850 ACIA at 31.25 kbit/s with isolated MIDI IN, MIDI OUT, and hardware THRU               |
| Timekeeping      | DS1285 RTC with battery-backed clock, calendar, alarms, interrupts, and 50 bytes of CMOS RAM |
| Parallel I/O     | MC68230 PI/T with a bit-banged 5 V I2C bus, a 34-pin user I/O header, and a 24-bit timer     |
| Debugging        | Write-only byte register driving a two-digit hexadecimal seven-segment display               |
| Expansion        | Two front-loading 3U Eurocard slots with DIN 41612 connectors                                |

## Documentation

Open the [documentation index](docs/static/index.html) in a browser for the complete design set. It covers the address decoder, clock and reset circuits, DRAM controller, firmware ROM, interrupts, peripherals, video, audio, parallel I/O, and expansion interface. [docs/README.md](docs/README.md) explains the document set, formatting commands, and license terms.

## Repository layout

| Path                               | Contents                                                      |
| ---------------------------------- | ------------------------------------------------------------- |
| [code/](code/)                     | Source code and project-specific build and test instructions. |
| [docs/](docs/)                     | Design documentation and reference material.                  |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Contribution guidelines and interface-change rules.           |

## Working with the repository

Each project manages its own tools and dependencies. Read its README before
running its commands.

```sh
make list                 # List available projects
make test                 # Run tests across projects
make check                # Run all project checks
make check PROJECT=docs   # Check one project
make clean                # Remove generated output
```

The root Makefile discovers project Makefiles one or two directory levels below
the repository root. New projects join these commands by providing `test`,
`check`, and `clean` targets. Build commands and other project-specific tasks
stay in each project's Makefile.

Run `make help` for the available root commands. See [CONTRIBUTING.md](CONTRIBUTING.md)
for the project conventions and [docs/README.md](docs/README.md) for documentation
setup.

Code uses [GPL v3.0](code/LICENSE); project-authored documentation uses
[CC BY-NC-SA 4.0](docs/LICENSE). Manufacturer datasheets retain their own terms.
