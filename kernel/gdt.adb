-- SPDX-License-Identifier: GPL-2.0-only
with System;
with System.Machine_Code; use System.Machine_Code;
with Ada.Unchecked_Conversion; 

package body GDT is 
	pragma Suppress (All_Checks); 

	type GDTR is record 
		Limit : U16;
		Base  : U64; 
	end record with Size => 80;

	for GDTR use record 
		Limit at 0 range 0 .. 15;
		Base  at 2 range 0 .. 63;
	end record;

	type TSS_Record is record 
		Reserved1   : U32;
		RSP0        : U64;
		RSP1        : U64;
		RSP2        : U64; 
		Reserved2   : U64;
		IST1        : U64; 
		IST2        : U64;
		IST3        : U64;
		IST4        : U64;
		IST5        : U64;
		IST6        : U64;
		IST7        : U64; 
		Reserved3   : U64;
		Reserved4   : U16;
		IOPB_Offset : U16;
	end record with Size => 104 * 8;

	for TSS_Record use record 
		Reserved1   at 0   range 0 .. 31;
		RSP0        at 4   range 0 .. 63;
		RSP1        at 12  range 0 .. 63;
		RSP2        at 20  range 0 .. 63;
		Reserved2   at 28  range 0 .. 63;
		IST1        at 36  range 0 .. 63;
		IST2        at 44  range 0 .. 63;
		IST3        at 52  range 0 .. 63;
		IST4        at 60  range 0 .. 63;
		IST5        at 68  range 0 .. 63;
		IST6        at 76  range 0 .. 63;
		IST7        at 84  range 0 .. 63;
		Reserved3   at 92  range 0 .. 63;
		Reserved4   at 100 range 0 .. 15;
		IOPB_Offset at 102 range 0 .. 15;
	end record;

	type GDT_Array is array (0 .. 10) of U64 with Size => 11 * 64;

	GDT_Table : GDT_Array with Volatile, Alignment => 8; 
	TSS_Data  : TSS_Record with Volatile, Alignment => 16;
	GDT_Ptr   : GDTR with Volatile; 

	function Addr_To_U64 is new Ada.Unchecked_Conversion
		(System.Address, U64); 

	procedure Init (Kernel_Stack_Top : U64) is
		TSS_Addr  : constant U64 := Addr_To_U64 (TSS_Data'Address);
		TSS_Limit : constant U64 := 103; 
	begin 
		TSS_Data.RSP0		 := Kernel_Stack_Top;
		TSS_Data.IOPB_Offset := 104;

		GDT_Table (0) := 0;
		GDT_Table (1) := 16#00AF_9A00_0000_FFFF#;
		GDT_Table (2) := 16#00CF_9200_0000_FFFF#; 
		GDT_Table (3) := 16#00AF_BA00_0000_FFFF#; 
		GDT_Table (4) := 16#00CF_B200_0000_FFFF#; 
		GDT_Table (5) := 16#00AF_DA00_0000_FFFF#;
		GDT_Table (6) := 16#00CF_D200_0000_FFFF#; 
		GDT_Table (7) := 16#00CF_F200_0000_FFFF#; 
		GDT_Table (8) := 16#00AF_FA00_0000_FFFF#;

		GDT_Table (9) := 
			(TSS_Limit and 16#FFFF#) 
			or ((TSS_Addr and 16#FFFF#) * 2**16) 
			or (((TSS_Addr / 2**16) and 16#FF#) * 2**32) 
			or (U64'(16#89#) * 2**40) 
			or (((TSS_Addr / 2**24) and 16#FF#) * 2**56); 
		GDT_Table (10) := TSS_Addr / 2**32; 

		GDT_Ptr.Limit := 11 * 8 - 1;
		GDT_Ptr.Base  := Addr_To_U64 (GDT_Table'Address); 

		Asm ("lgdt (%0)" & ASCII.LF & 
			"movw $0x10, %%ax" & ASCII.LF & 
			"movw %%ax, %%ds" & ASCII.LF & 
			"movw %%ax, %%es" & ASCII.LF & 
			"movw %%ax, %%ss" & ASCII.LF & 
			"xorw %%ax, %%ax" & ASCII.LF & 
			"movw %%ax, %%fs" & ASCII.LF & 
			"movw %%ax, %%gs" & ASCII.LF & 
			"pushq $0x08" & ASCII.LF & 
			"leaq 1f(%%rip), %%rax" & ASCII.LF & 
			"pushq %%rax" & ASCII.LF &
			"lretq" & ASCII.LF & 
			"1:" & ASCII.LF & 
			"movw $0x48, %%ax" & ASCII.LF & 
			"ltr %%ax",
			Inputs 	 => System.Address'Asm_Input ("r", GDT_Ptr'Address), 
			Clobber  => "rax,memory",
			Volatile => True); 
		end Init;

		procedure Set_Ring1_Stack (Stack_Top : U64) is 
		begin
			TSS_Data.RSP1 := Stack_Top;
		end Set_Ring1_Stack; 

		procedure Set_Ring2_Stack (Stack_Top : U64) is 
		begin 
			TSS_Data.RSP2 := Stack_Top;
		end Set_Ring2_Stack;

		function Current_CS return U16 is 
			Val : U16; 
		begin 
			Asm ("movw %%cs, %0",
				Outputs => U16'Asm_Output ("=r", Val),
				Volatile => True); 
			return Val;
		end Current_CS; 

		function Current_TR return U16 is 
			Val : U16;
		begin 
			Asm ("str %0", 
				Outputs => U16'Asm_Output ("=r", Val),
				Volatile => True);
			return Val;
		end Current_TR;
	end GDT;
	
