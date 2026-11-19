-- SPDX-License-Identifier: GPL-2.0-only
with System.Machine_Code; use System.Machine_Code;
with Ada.Unchecked_Conversion; 
with IO;
with TTY;
with Syscall;
package body IDT is
	pragma Suppress (All_Checks);

	type IDT_Entry is record 
		Offset_Low  : U16;
		Selector    : U16;
		IST         : U8;
		Type_Attr   : U8;
		Offset_Mid  : U16;
		Offset_High : U32;
		Reserved    : U32;
	end record with Size => 128;

		for IDT_Entry use record
			Offset_Low  at 0  range 0 .. 15; 
			Selector    at 2  range 0 .. 15;
			IST         at 4  range 0 .. 7;
			Type_Attr   at 5  range 0 .. 7;
			Offset_Mid  at 6  range 0 .. 15;
			Offset_High at 8  range 0 .. 31;
			Reserved    at 12 range 0 .. 31;
		end record;

		type IDTR is record 
			Limit : U16;
			Base  : U64;
		end record with Size => 80;

		for IDTR use record 
			Limit at 0 range 0 .. 15;
			Base  at 2 range 0 .. 63;
		end record; 

		type Interrupt_Frame is record 

		R15			  : U64;
		R14			  : U64;
		R13           : U64;
		R12           : U64;
		R11           : U64;
		R10           : U64;
		R9            : U64;
		R8            : U64;
		RBP           : U64;
		RDI           : U64;
		RSI           : U64;
		RDX           : U64;
		RCX           : U64;
		RBX           : U64;
		RAX           : U64;
		Vector        : U64;
		Error_Code    : U64;
		RIP           : U64;
		CS            : U64;
		RFLAGS        : U64;
		RSP           : U64;
		SS            : U64;
	end record with Size => 22 * 64;

	for Interrupt_Frame use record 
		R15		   at 0   range 0 .. 63;
		R14        at 8   range 0 .. 63;
		R13        at 16  range 0 .. 63;
		R12        at 24  range 0 .. 63;
		R11        at 32  range 0 .. 63;
		R10        at 40  range 0 .. 63;
		R9         at 48  range 0 .. 63;
		R8         at 56  range 0 .. 63;
		RBP        at 64  range 0 .. 63;
		RDI        at 72  range 0 .. 63;
		RSI        at 80  range 0 .. 63;
		RDX        at 88  range 0 .. 63;
		RCX        at 96  range 0 .. 63;
		RBX        at 104 range 0 .. 63;
		RAX        at 112 range 0 .. 63;
		Vector     at 120 range 0 .. 63;
		Error_Code at 128 range 0 .. 63;
		RIP        at 136 range 0 .. 63;
		CS         at 144 range 0 .. 63;
		RFLAGS     at 152 range 0 .. 63;
		RSP        at 160 range 0 .. 63;
		SS         at 168 range 0 .. 63;
	end record;

	type IDT_Array is array (0 .. 255) of IDT_Entry with Size => 256 * 128;
	type Stub_Array is array (0 .. 47) of U64;

	IDT_Table  : IDT_Array with Volatile, Alignment => 16;
	IDT_Ptr    : IDTR with Volatile; 
	Tick_Count : U64 with Volatile; 

	ISR_Stubs : Stub_Array with
		Import,
		Convention	  => C,
		External_Name => "isr_stub_table"; 

	Stub_128 : U64 with
		Import,
		Convention    => C,
		External_Name => "isr_stub_128";

    procedure Ring_Return (Exit_Code : U64) with
    	Import,
    	Convention    => C,
    	External_Name => "ring_return_to_caller";
    	
	
	function Addr_To_U64 is new Ada.Unchecked_Conversion
		(System.Address, U64); 

	procedure IO_Wait is
	begin
	  IO.Outb (16#80#, 0); 
	end IO_Wait;

	procedure Set_Gate (Vec : Natural; Handler : U64; Attr : U8) is 
	begin
		IDT_Table (Vec).Offset_Low 	:= U16 (Handler and 16#FFFF#); 
		IDT_Table (Vec).Selector    := 16#08#;
		IDT_Table (Vec).IST         := 0;
		IDT_Table (Vec).Type_Attr   := Attr;
		IDT_Table (Vec).Offset_Mid  := U16 ((Handler / 2**16) and 16#FFFF#); 
		IDT_Table (Vec).Offset_High := U32 (Handler / 2**32);
		IDT_Table (Vec).Reserved    := 0;
	end Set_Gate;

	procedure Remap_PIC is 
	begin
		IO.Outb (16#20#, 16#11#); IO_Wait;
		IO.Outb (16#A0#, 16#11#); IO_Wait;
		IO.Outb (16#21#, 16#20#); IO_Wait;
		IO.Outb (16#A1#, 16#28#); IO_Wait;
		IO.Outb (16#21#, 16#04#); IO_Wait;
		IO.Outb (16#A1#, 16#02#); IO_Wait;
		IO.Outb (16#21#, 16#01#); IO_Wait;
		IO.Outb (16#A1#, 16#01#); IO_Wait;

		IO.Outb (16#21#, 16#FC#); 
		IO.Outb (16#A1#, 16#FF#); 
	end Remap_PIC;

	procedure Init_PIT is
	begin
		IO.Outb (16#43#, 16#36#); 
		IO.Outb (16#40#, 16#9B#); 
		IO.Outb (16#40#, 16#2E#); 
	end Init_PIT;

	procedure Init is 
	begin
		Tick_Count := 0;
		for I in 0 .. 47 loop
			Set_Gate (I, ISR_Stubs (I), 16#8E#);
		end loop;

        Set_Gate (128, Addr_To_U64 (Stub_128'Address), 16#EE#);
		
		Remap_PIC;
		Init_PIT;

		IDT_Ptr.Limit := 256 * 16 -1;
		IDT_Ptr.Base  := Addr_To_U64 (IDT_Table'Address);

		Asm ("lidt (%0)" & ASCII.LF & "sti", 
			Inputs   => System.Address'Asm_Input ("r", IDT_Ptr'Address),
			Clobber  => "memory",
			Volatile =>  True); 
		end Init;

		function Ticks return U64 is
		begin 
			return Tick_Count;
		end Ticks;

		procedure ISR_Dispatch (Frame_Addr : System.Address) is 
		  Frame : Interrupt_Frame with
		  	Volatile,
		  	Import,
		  	Address => Frame_Addr;
		  CR2 : U64;
		  Sc  : U8;
		  Res : U64;
		begin
		   if Frame.Vector < 32 then
		   	IO.Put_Line (""); 
		   	IO.Put_Str ("[EXCEPTION] Vec=");
		   	IO.Put_Hex64 (Frame.Vector);
		   	IO.Put_Str   (" Err=");
		   	IO.Put_Hex64 (Frame.Error_Code);
		   	IO.Put_Char  (ASCII.LF); 
		   	IO.Put_Str  ("             RIP=");
		   	IO.Put_Hex64 (Frame.RIP); 
		   	IO.Put_Str (" RSP=");
		   	IO.Put_Hex64 (Frame.RSP);
		   	IO.Put_Char  (ASCII.LF); 
		   	if Frame.Vector = 14 then
		   		Asm ("movq %%cr2, %0", 
		   			Outputs  => U64'Asm_Output ("=r", CR2),
		   			Volatile => True);
		   		IO.Put_Str ("            CR2=");
		   		IO.Put_Hex64 (CR2);
		   		IO.Put_Char  (ASCII.LF); 
		   	end if;

            if (Frame.CS and 3) /= 0 then
              IO.Put_Line ("[RING-0] Lower ring faulted; returning to PZSH.");
              Ring_Return (16#DEAD#);
            end if;
		   	
		   	loop
		   		Asm ("cli; hlt", Volatile => True);
		   	end loop;
		 end if;

		 if Frame.Vector = 32 then
		 	Tick_Count := Tick_Count + 1;
		 elsif Frame.Vector = 33 then
		 	Sc := IO.Inb (16#60#);
		 	TTY.Handle_Scancode (Sc);
		 elsif Frame.Vector = 128 then
		 	Syscall.Handle
		 	 (Caller_CPL => Frame.CS and 3, 
		      Num  => Frame.RAX,
		       Arg1 => Frame.RDI,
		       Arg2 => Frame.RSI,
		       Arg3 => Frame.RDX,
		       Ret  => Res);
		    Frame.RAX := Res;
		 end if;

		 if Frame.Vector >= 32 and then Frame.Vector <= 47 then
          if Frame.Vector >= 40 then
		 	IO.Outb (16#A0#, 16#20#);
		 end if;
		 IO.Outb (16#20#, 16#20#);
	  end if;
	end ISR_Dispatch;
end IDT;
