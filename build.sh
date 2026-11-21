#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -e

ADAFLAGS="-O2 -gnatp -fno-pie -fno-stack-protector -fno-asynchronous-unwind-tables -mno-red-zone -mno-sse -mno-mmx"

echo "=== [1/5] Assembling Bootloaders ==="
nasm -f bin stage1.s -o stage1.bin
nasm -f bin forth_boot.s -o stage2.bin

echo "=== [2/5] Assembling Kernel Entry & ISR Stubs ==="
nasm -f elf64 entry.s -o entry.o
nasm -f elf64 isr.s -o isr.o

echo "=== [3/5] Compiling Ada Kernel Units ==="
gcc -c $ADAFLAGS types.ads       -o types.o
gcc -c $ADAFLAGS io.adb          -o io.o
gcc -c $ADAFLAGS gdt.adb         -o gdt.o
gcc -c $ADAFLAGS syscall.adb     -o syscall.o
gcc -c $ADAFLAGS idt.adb         -o idt.o
gcc -c $ADAFLAGS tty.adb         -o tty.o
gcc -c $ADAFLAGS ring1.adb       -o ring1.o
gcc -c $ADAFLAGS pmm.adb         -o pmm.o         
gcc -c $ADAFLAGS shell.adb       -o shell.o
gcc -c $ADAFLAGS kernel_main.adb -o kernel_main.o

echo "=== [4/5] Linking & Creating kernel.bin ==="
ld -m elf_x86_64 -T kernel.ld -nostdlib --no-pie --no-warn-rwx-segments \
   entry.o isr.o types.o io.o gdt.o syscall.o idt.o tty.o ring1.o pmm.o \
   shell.o kernel_main.o -o kernel.elf
objcopy -O binary kernel.elf kernel.bin

KSIZE=$(stat -c%s kernel.bin)
echo "kernel.bin size: $KSIZE / 32768 bytes"
if [ "$KSIZE" -gt 32768 ]; then
    echo "ERROR: kernel.bin exceeds Stage 1's 64-sector (32 KB) load limit!"
    exit 1
fi

echo "=== [5/5] Building Disk Image & Bootable ISO ==="
dd if=/dev/zero of=os.img bs=512 count=2880 status=none
dd if=stage1.bin of=os.img bs=512 seek=0 conv=notrunc status=none
dd if=stage2.bin of=os.img bs=512 seek=1 conv=notrunc status=none
dd if=kernel.bin of=os.img bs=512 seek=9 conv=notrunc status=none

mkdir -p iso_root
cp os.img iso_root/
xorriso -as mkisofs -b os.img -c boot.cat -o planet_zero.iso iso_root/ 2>/dev/null

echo "=== Launching Planet-Zero in QEMU ==="
qemu-system-x86_64 -cdrom planet_zero.iso -serial stdio -nic model=e1000
