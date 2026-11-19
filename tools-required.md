# Tools & Dependencies Required

To build and test **PlanetZero OS** from source, you need an **x86_64 Linux** host environment with the following packages installed.

## Required Build Tools
* **`gnat` (GNU Ada Compiler):** Compiles the bare-metal Ada kernel, drivers, and `PZSH` shell units (`gcc` with Ada frontend).
* **`nasm` (Netwide Assembler):** Assembles the Stage 1 bootloader (`stage1.s`), Forth bootloader (`forth_boot.s`), kernel entry (`entry.s`), and ISR stubs (`isr.s`).
* **`binutils` (`ld` & `objcopy`):** Links the `elf_x86_64` object files using `kernel/kernel.ld` and strips the binary into a raw flat image (`kernel.bin`).
* **`xorriso`:** Generates the bootable `planet_zero.iso` image from the raw floppy/disk image (`os.img`).
* **`qemu-system-x86_64`:** Emulates the x86_64 hardware environment with serial stdio and an `e1000` network interface for testing.

## Quick Installation Commands

### Debian / Ubuntu / Kali / Linux Mint
```bash
sudo apt update
sudo apt install -y gnat nasm binutils xorriso qemu-system-x86
```

### Fedora / RHEL
```bash
sudo dnf install -y gcc-gnat nasm binutils xorriso qemu-system-x86
```

### Arch Linux
```bash
sudo pacman -S --needed gcc-ada nasm binutils xorriso qemu-full
```

## Building & Running
Once the tools are installed, run the build script from the repository root:
```bash
chmod +x build.sh
./build.sh
```
