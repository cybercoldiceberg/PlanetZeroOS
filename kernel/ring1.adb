-- SPDX-License-Identifier: GPL-2.0-only
with System;
with System.Machine_Code; use System.Machine_Code;
with GDT;
with Syscall;

package body Ring1 is
   pragma Suppress (All_Checks);

   Cur_Mode : Mode_Kind with Volatile;

   function Ring_Call_PL
     (Entry_RIP : System.Address;
      Stack_Top : U64;
      Code_Sel  : U64;
      Data_Sel  : U64) return U64
   with
      Import,
      Convention    => C,
      External_Name => "ring_call_pl";

   function Read_CS return U16 is
      Val : U16;
   begin
      Asm ("movw %%cs, %0",
           Outputs  => U16'Asm_Output ("=r", Val),
           Volatile => True);
      return Val;
   end Read_CS;

   function PCI_Read32 (Bus, Dev, Func, Reg : U32) return U32 is
      Addr : constant U32 :=
        16#8000_0000#
        or ((Bus  and 16#FF#) * 2**16)
        or ((Dev  and 16#1F#) * 2**11)
        or ((Func and 16#07#) * 2**8)
        or (Reg   and 16#FC#);
   begin
      Syscall.Out32 (16#CF8#, Addr);
      return Syscall.In32 (16#CFC#);
   end PCI_Read32;

   procedure Print_Class_Tag (Class, Subclass : U8) is
   begin
      if Class = 16#01# then
         if Subclass = 16#01# then
            Syscall.Put_Str ("[IDE Storage]");
         elsif Subclass = 16#06# then
            Syscall.Put_Str ("[AHCI/SATA]");
         else
            Syscall.Put_Str ("[Storage]");
         end if;
      elsif Class = 16#02# then
         if Subclass = 16#00# then
            Syscall.Put_Str ("[Ethernet NIC]");
         else
            Syscall.Put_Str ("[Network]");
         end if;
      elsif Class = 16#03# then
         Syscall.Put_Str ("[VGA/Display]");
      elsif Class = 16#06# then
         if Subclass = 16#00# then
            Syscall.Put_Str ("[Host Bridge]");
         elsif Subclass = 16#01# then
            Syscall.Put_Str ("[ISA Bridge]");
         else
            Syscall.Put_Str ("[Bridge]");
         end if;
      elsif Class = 16#0C# and then Subclass = 16#03# then
         Syscall.Put_Str ("[USB]");
      else
         Syscall.Put_Str ("[Device]");
      end if;
   end Print_Class_Tag;

   procedure Run_PCI_Scan is
      ID, Class_Word, BAR0, Hdr_Word : U32;
      Vendor, Device                 : U16;
      Class, Subclass, Hdr           : U8;
      Max_Func                       : U32;
   begin
      Syscall.Put_Line ("[RING-1 PCI] Scanning Bus 0 (0xCF8/0xCFC):");
      for Dev in U32 range 0 .. 31 loop
         ID     := PCI_Read32 (0, Dev, 0, 0);
         Vendor := U16 (ID and 16#FFFF#);
         if Vendor /= 16#FFFF# then
            Hdr_Word := PCI_Read32 (0, Dev, 0, 16#0C#);
            Hdr      := U8 ((Hdr_Word / 2**16) and 16#FF#);
            if (Hdr and 16#80#) /= 0 then
               Max_Func := 7;
            else
               Max_Func := 0;
            end if;

            for Func in U32 range 0 .. Max_Func loop
               ID     := PCI_Read32 (0, Dev, Func, 0);
               Vendor := U16 (ID and 16#FFFF#);
               if Vendor /= 16#FFFF# then
                  Device     := U16 (ID / 2**16);
                  Class_Word := PCI_Read32 (0, Dev, Func, 16#08#);
                  Class      := U8 ((Class_Word / 2**24) and 16#FF#);
                  Subclass   := U8 ((Class_Word / 2**16) and 16#FF#);
                  Hdr_Word   := PCI_Read32 (0, Dev, Func, 16#0C#);
                  Hdr        := U8 ((Hdr_Word / 2**16) and 16#FF#);

                  Syscall.Put_Str ("  00:");
                  Syscall.Put_Hex8 (U8 (Dev));
                  Syscall.Put_Char ('.');
                  Syscall.Put_Hex8 (U8 (Func));
                  Syscall.Put_Str ("  ");
                  Syscall.Put_Hex16 (Vendor);
                  Syscall.Put_Char (':');
                  Syscall.Put_Hex16 (Device);
                  Syscall.Put_Str ("  ");
                  Syscall.Put_Hex8 (Class);
                  Syscall.Put_Char (':');
                  Syscall.Put_Hex8 (Subclass);
                  Syscall.Put_Str (" ");
                  Print_Class_Tag (Class, Subclass);

                  if (Hdr and 16#7F#) = 0 then
                     BAR0 := PCI_Read32 (0, Dev, Func, 16#10#);
                     if BAR0 /= 0 then
                        Syscall.Put_Str (" BAR0=");
                        Syscall.Put_Hex32 (BAR0);
                     end if;
                  end if;
                  Syscall.Put_Char (ASCII.LF);
               end if;
            end loop;
         end if;
      end loop;
   end Run_PCI_Scan;

   function Read_CMOS (Reg : U8) return U8 is
   begin
      Syscall.Out8 (16#70#, Reg and 16#7F#);
      return Syscall.In8 (16#71#);
   end Read_CMOS;

   function From_BCD (Val : U8) return U8 is
   begin
      return ((Val / 16) * 10) + (Val and 16#0F#);
   end From_BCD;

   procedure Run_RTC is
      Sec, Min, Hour, Day, Month, Year, RegB : U8;
      Spins                                  : Natural := 0;
      Is_PM                                  : Boolean;
   begin
      while (Read_CMOS (16#0A#) and 16#80#) /= 0 loop
         Spins := Spins + 1;
         exit when Spins > 100_000;
      end loop;

      Sec   := Read_CMOS (16#00#);
      Min   := Read_CMOS (16#02#);
      Hour  := Read_CMOS (16#04#);
      Day   := Read_CMOS (16#07#);
      Month := Read_CMOS (16#08#);
      Year  := Read_CMOS (16#09#);
      RegB  := Read_CMOS (16#0B#);

      Is_PM := (Hour and 16#80#) /= 0;
      Hour  := Hour and 16#7F#;

      if (RegB and 16#04#) = 0 then
         Sec   := From_BCD (Sec);
         Min   := From_BCD (Min);
         Hour  := From_BCD (Hour);
         Day   := From_BCD (Day);
         Month := From_BCD (Month);
         Year  := From_BCD (Year);
      end if;

      if (RegB and 16#02#) = 0 then
         if Is_PM and then Hour < 12 then
            Hour := Hour + 12;
         elsif (not Is_PM) and then Hour = 12 then
            Hour := 0;
         end if;
      end if;

      Syscall.Put_Str ("[RING-1 RTC] 20");
      Syscall.Put_Dec2 (Year);
      Syscall.Put_Char ('-');
      Syscall.Put_Dec2 (Month);
      Syscall.Put_Char ('-');
      Syscall.Put_Dec2 (Day);
      Syscall.Put_Char (' ');
      Syscall.Put_Dec2 (Hour);
      Syscall.Put_Char (':');
      Syscall.Put_Dec2 (Min);
      Syscall.Put_Char (':');
      Syscall.Put_Dec2 (Sec);
      Syscall.Put_Line (" UTC");
   end Run_RTC;

   procedure Ring1_Entry is
      CS_Val : constant U16 := Read_CS;
   begin
      case Cur_Mode is
         when Mode_Info =>
            Syscall.Put_Line ("[RING-1] Ada Driver Tier Active!");
            Syscall.Put_Str  ("[RING-1] CS = ");
            Syscall.Put_Hex64 (U64 (CS_Val));
            Syscall.Put_Str  ("  CPL = ");
            Syscall.Put_Hex64 (U64 (CS_Val and 3));
            Syscall.Put_Char (ASCII.LF);
            Syscall.Put_Str  ("[RING-1] Ticks via INT 0x80 = ");
            Syscall.Put_Hex64 (Syscall.Get_Ticks);
            Syscall.Put_Char (ASCII.LF);

         when Mode_PCI =>
            Run_PCI_Scan;

         when Mode_RTC =>
            Run_RTC;

         when Mode_Fault =>
            Syscall.Put_Line ("[RING-1] Trying privileged 'cli' (expect #GP)...");
            Asm ("cli", Volatile => True);
      end case;

      Syscall.Exit_Ring (0);
   end Ring1_Entry;

   function Launch (Mode : Mode_Kind) return U64 is
   begin
      Cur_Mode := Mode;
      return Ring_Call_PL
        (Entry_RIP => Ring1_Entry'Address,
         Stack_Top => 16#80000#,
         Code_Sel  => U64 (GDT.Ring1_Code_Sel),
         Data_Sel  => U64 (GDT.Ring1_Data_Sel));
   end Launch;
end Ring1;
