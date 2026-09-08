# Code

Source code for the 68EC000 computer. Keep each project in its own directory,
with a README describing its purpose, dependencies, build commands, and tests.
Projects can use the language and tools they need.

The root commands discover Makefiles directly beneath this directory. Provide
these targets to include a project:

| Target  | Purpose                                                |
| ------- | ------------------------------------------------------ |
| `test`  | Run the project's automated tests.                     |
| `check` | Run tests and other validation required for changes.   |
| `clean` | Remove generated output while preserving source files. |

Keep toolchain settings, test selection, and build rules in the project.
A Makefile can call another build system; it does not need to implement the
build itself. Put shared code in a separate directory when projects need it.

Code in this directory is licensed under the [GNU GPL v3.0](LICENSE) unless
stated otherwise.
