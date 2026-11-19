-- SPDX-License-Identifier: GPL-2.0-only
with IO;
with GDT;
with IDT;
with TTY;
with Shell;

procedure Kernel_Main is
   pragma Suppress (All_Checks);
begin
   IO.Init;
   IO.Put_Line ("[RING-0] Planet-Zero Ada Kernel Online (0xA000)");

   GDT.Init (Kernel_Stack_Top => 16#88000#);
   IO.Put_Line ("[RING-0] GDT + TSS loaded (Rings 0/1/2/3)");

   TTY.Init;
   IDT.Init;
   IO.Put_Line ("[RING-0] 64-bit IDT + PIC + PIT(100Hz) + IRQ1 active");

   Shell.Run;
end Kernel_Main;
