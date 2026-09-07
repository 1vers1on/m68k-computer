# 68EC000 Computer

Design documentation for a 10 MHz, 16-bit computer built around the Motorola MC68EC000FN10.

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
| Debugging        | Write-only byte register driving a two-digit hexadecimal seven-segment display               |
| Expansion        | Two front-loading 3U Eurocard slots with DIN 41612 connectors                                |

## Expansion bus

Each slot accepts a 100 mm × 160 mm, 1.6 mm-thick 3U Eurocard through a 96-contact Type C DIN 41612 connector. Each receives a fixed 2 MiB memory window and 128 KiB I/O window, plus up to +5 V at 1.0 A and +12 V at 0.4 A. Cards must be inserted or removed with power off. The bus has no DMA, arbitration, or bus mastering.

## Documentation

Open the [documentation index](docs/static/index.html) in a browser for the complete design set. It covers the address decoder, clock and reset circuits, DRAM controller, firmware ROM, interrupts, peripherals, video, audio, and expansion interface. [docs/README.md](docs/README.md) explains the document set, formatting commands, and license terms.
