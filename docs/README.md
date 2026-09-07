# 68EC000 Computer documentation

This directory holds the project’s static design documentation. Open [static/index.html](static/index.html) in a browser to start at the document index.

The pages cover the memory map, bus and address decode, clock and reset, power control, interrupts, system control, debug display, DRAM, firmware ROM, MFP, floppy controller, VGA, OPL3, MIDI, RTC, and expansion slots. Each is revision 1.0 and records the pre-layout design where applicable.

`static/defaults.css` provides the shared page styling. `package.json` supplies Prettier commands for the HTML files:

```sh
npm run format
npm run format:check
```

## License

The project-authored documentation is licensed under [CC BY-NC-SA 4.0](LICENSE). The files in `static/datasheets/` are exempt from that documentation license: they are manufacturer-provided datasheets and remain subject to their respective rights holders’ terms.

Return to the [repository README](../README.md) for the project overview.
