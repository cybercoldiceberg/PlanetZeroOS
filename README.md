# PlanetZero OS

Welcome to **PlanetZero**, broskies! 

PlanetZero OS is an independent, bare-metal x86_64 operating system built from scratch with a focus on memory safety, clean architecture, and strict privilege separation.

> **Solo Development Notice:** I do not accept outside code contributions or pull requests on this project. I am an independent developer who enjoys the challenge of architecting, writing, and debugging every layer myself. Feel free to star the repo, follow the progress, and test builds—see [INFO.md](./INFO.md) for more details.

---

## Core Architecture
* **Kernel & Systems Logic:** Written in **Ada** for strong typing, compile-time safety checks, and bare-metal hardware control without C memory bugs.
* **Bootloader:** Custom **Assembly** (`forth_boot.s`) and **Forth** bootloader stage.
* **Privilege Rings:** Implements Ring-0 through Ring-3 separation.
* **Shell:** Custom **PZSH** (PlanetZero Shell) featuring native built-in commands like `repeat` and `testinet`.
* **Filesystem & Executables:** Custom directory layout (`/home/$USERNAME/system`) with support for ELF and custom `.PZE` executables.

## Current Status
**Early Alpha / Active Development** — Core boot handoff, VGA output, privilege ring initialization, and base shell parsing are actively being built and tested in QEMU.

## Building & Testing (QEMU)
### Prerequisites
* `gnat` / cross-compiler toolchain for bare-metal `x86_64` Ada
* `nasm` or `as` (GNU Assembler)
* `make`
* `qemu-system-x86_64`

### Quick Start
```bash
git clone https://github.com
cd PlanetZeroOS
make
qemu-system-x86_64 -drive format=raw,file=planetzero.img
```

## License
PlanetZero OS is licensed strictly under the **GNU General Public License v2.0 (GPL-2.0-only)**. See [LICENSE](./LICENSE) for the full text.
