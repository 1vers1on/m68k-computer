# 68EC000 Computer documentation

This directory holds the project’s static design documentation. Open [static/index.html](static/index.html) in a browser to start at the document index.

The pages cover the memory map, bus and address decode, clock and reset, power control, interrupts, system control, debug display, DRAM, firmware ROM, MFP, floppy controller, VGA, OPL3, MIDI, RTC, and expansion slots. Each is revision 1.0 and records the pre-layout design where applicable.

`static/defaults.css` provides the shared page styling. `package.json` supplies Prettier commands for the HTML files:

```sh
npm run format
npm run format:check
```

## Run the website with Docker

Build the image from this directory, then start the container:

```sh
docker build -t m68k-computer-docs .
docker run --rm -p 8080:80 m68k-computer-docs
```

Open <http://localhost:8080> to view the documentation. The container serves the files in `static/` through nginx. Stop it with `Ctrl-C`.

To run it in the background, add `-d` and give the container a name:

```sh
docker run -d --name m68k-computer-docs -p 8080:80 m68k-computer-docs
docker stop m68k-computer-docs
docker rm m68k-computer-docs
```

Change `8080` in the `-p 8080:80` argument if that port is already in use. To make the site available to other computers on your network, open `http://<host-address>:8080` and allow that port through the host firewall.

## License

The project-authored documentation is licensed under [CC BY-NC-SA 4.0](LICENSE). The files in `static/datasheets/` are exempt from that documentation license: they are manufacturer-provided datasheets and remain subject to their respective rights holders’ terms.

Return to the [repository README](../README.md) for the project overview.
