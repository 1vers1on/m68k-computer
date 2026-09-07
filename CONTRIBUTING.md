# Contributing

This monorepo holds the hardware, firmware, software, documentation, and supporting tools for the 68EC000 computer. Contributions should leave the design easier to build, inspect, test, or use.

## Before you start

Read the [project README](README.md) and the README in the area you plan to change. Follow local instructions when they exist.

Keep a change focused. Split unrelated fixes, refactors, formatting, and design changes into separate submissions.

## Working in the repository

| Area                  | Contribution expectations                                                                                                                                                    |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Hardware              | Keep schematics, PCB layouts, BOMs, manufacturing files, and electrical notes consistent. Record part substitutions, constraints, and measurements that affect the design.   |
| Firmware and software | Follow the local build and test instructions. Add or update tests when behavior changes, and document changes to public interfaces, register access, file formats, or tools. |
| Documentation         | State facts plainly, preserve established signal and address notation, and cite sources for electrical limits, timing values, and part specifications.                       |
| Tools and automation  | Keep inputs, outputs, supported environments, and failure modes clear. Do not hide generated output or side effects.                                                         |

Do not edit third-party material unless the repository includes it under terms that allow the change. Keep manufacturer datasheets and other reference material separate from project-authored work.

## Hardware and interface changes

Treat memory maps, register layouts, connector pinouts, bus timing, power limits, and mechanical dimensions as interfaces. Describe compatibility effects when changing one of them.

The revision 1.0 memory map is frozen. An address-range, I/O-slot, or register-address change needs a new memory-map revision and coordinated updates to the affected hardware, firmware, software, and documentation.

For a hardware change, include the evidence needed to review it: relevant calculations, datasheet references, layout constraints, or measurements. Mark planned values and measured values clearly.

## Generated content and AI assistance

AI-generated code and documentation are welcome when a contributor reviews them before submission. The person submitting the change is responsible for its correctness, licensing, security, and fit with the project.

Review generated code as you would any other contribution. Build it, run the relevant tests, inspect error paths, and verify behavior against the hardware or interface documentation. Review generated documentation against primary sources and remove claims that cannot be checked.

AI-generated schematics, PCBs, hardware, and images are NOT ALLOWED!!!!

## Check your change

Run the formatter, build, tests, design-rule checks, and other validation that apply to the files you changed. Each project area may define its own commands.

For the current static documentation, run:

```sh
cd docs
npm install
npm run format
npm run format:check
```

Then open the changed pages in a browser. Check links, tables, code-formatted addresses, internal anchors, and cited datasheets.

## Submission notes

Explain what changed, why it changed, and which areas of the system it affects. List the checks you ran and their results. Name the source for each new hardware claim. Call out compatibility risks, required migration steps, and work that remains unverified.

Project-authored documentation uses the [CC BY-NC-SA 4.0 license](docs/LICENSE). Do not add material that you cannot contribute under the applicable project terms. Third-party files retain their own terms.
