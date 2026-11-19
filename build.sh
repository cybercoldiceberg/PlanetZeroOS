#!/usr/bin/env bash
set -e

ADAFLAGS="-O2 -gnatp -fno-pie -fno-stack-protector -fno-asynchronous-unwind-tables -mno-red-zone -mno-sse -mno-mmx -Ikernel -Idrivers -Ishell"

echo "=== [1/5] Assembling Bootloaders ==="
nasm -f bin boot/stage1.s -o stage1.bin
nasm -f bin boot/forth_boot.s -o stage2.bin

echo "=== [2/5] Assembling Kernel Entry & ISR Stubs ==="
nasm -f elf64 boot/entry.s -o entry.o
nasm -f elf64 kernel/isr.s -o isr.o

echo "=== [3/5] Compiling Ada Units ==="
gcc -c $ADAFLAGS kernel/types.ads       -o types.o
gcc -c $ADAFLAGS drivers/io.adb         -o io.o
gcc -c $ADAFLAGS kernel/gdt.adb         -o gdt.o
gcc -c $ADAFLAGS kernel/syscall.adb     -o syscall.o
gcc -c $ADAFLAGS kernel/idt.adb         -o idt.o
gcc -c $ADAFLAGS drivers/tty.adb        -o tty.o
gcc -c $ADAFLAGS kernel/ring1.adb       -o ring1.o
gcc -c $ADAFLAGS shell/shell.adb        -o shell.o
gcc -c $ADAFLAGS kernel/kernel_main.adb -o kernel_main.o

echo "=== [4/5] Linking & Creating kernel.bin ==="
ld -m elf_x86_64 -T kernel/kernel.ld -nostdlib --no-pie --no-warn-rwx-segments \
   entry.o isr.o types.o io.o gdt.o syscall.o idt.o tty.o ring1.o \
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
