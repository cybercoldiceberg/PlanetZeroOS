-- SPDX-License-Identifier: GPL-2.0-only
with System.Machine_Code; use System.Machine_Code;
with Ada.Unchecked_Conversion;
with IO;
with IDT;

package body Syscall is  
	pragma Suppress (All_Checks);

	Hex_Digits : constant String := "0123456789ABCDEF";

	function U64_To_Addr is new Ada.Unchecked_Conversion
		(U64, System.Address);

	procedure Ring_Return (Exit_Code : U64) with
	   Import,
	   Convention    =>   C,
	   External_Name =>   "ring_return_to_caller";

	procedure Handle
	(Caller_CPL   : U64; 
	  Num	: U64;
	   Arg1 : U64;
	   Arg2 : U64;
	   Arg3 : U64;
	   Ret  : out U64)
	is 
		pragma Unreferenced (Arg3);
		Count : Natural;
	begin
		Ret := 0;
		if Num = Sys_Exit then
			Ring_Return (Arg1);
		elsif Num = Sys_Write then
		   if Arg2 > 4096 then
		   	  Count := 4096;
		   else
		     Count := Natural (Arg2);
		   end if;
		   for I in 0 .. Count - 1 loop
		   	 declare 
		   	 	Ch : Character with
		   	 		Volatile,
		   	 		Import,
		   	 		Address => U64_To_Addr (Arg1 + U64 (I));
		   	 begin
		   	 	IO.Put_Char (Ch);
		   	 end;
		  end loop;
		  Ret := U64 (Count);
	elsif Num = Sys_Ticks then
      Ret := IDT.Ticks;
      elsif Num >= Sys_In8 and then Num <= Sys_Out32 then

         if Caller_CPL > 1 then
            Ret := 16#FFFF_FFFF_FFFF_FFFF#;
            return;
    end if;

    if Num = Sys_In8 then
       Ret := U64 (IO.Inb (U16 (Arg1 and 16#FFFF#)));
    elsif Num = Sys_Out8 then
       IO.Outb (U16 (Arg1 and 16#FFFF#), U8 (Arg2 and 16#FF#));
    elsif Num = Sys_In32 then
       Ret := U64 (IO.Inl (U16 (Arg1 and 16#FFFF#)));
    elsif Num = Sys_Out32 then
       IO.Outl (U16 (Arg1 and 16#FFFF#), U32 (Arg2 and 16#FFFF_FFFF#));
      end if;
   end if;
end Handle;

procedure Exit_Ring (Code : U64) is
   Ret : U64;
begin
	Asm ("int $0x80", 
		Outputs => U64'Asm_Output ("=a", Ret),
		Inputs  => (U64'Asm_Input ("0", Sys_Exit),
					U64'Asm_Input ("D", Code)),
		Clobber  =>  "memory",
		Volatile =>  True);
	end Exit_Ring;

	procedure Sys_Write_Raw (Buf : System.Address; Len : U64) is
	  Ret : U64;
	begin
	   Asm ("int $0x80", 
	   		Outputs  => U64'Asm_Output ("=a", Ret),
	   		Inputs   => (U64'Asm_Input ("0", Sys_Write), 
						 System.Address'Asm_Input ("D", Buf),
						 U64'Asm_Input  ("S", Len)),
	   		Clobber  => "memory", 
	   		Volatile => True);
	   end Sys_Write_Raw;

	   procedure Put_Char (C : Character) is
	      Buf : Character := C with Volatile;
	   begin
	   	  Sys_Write_Raw (Buf'Address, 1);
	   end Put_Char;

	   procedure Put_Str (S : String) is
	   begin
	      if S'Length > 0 then
	         Sys_Write_Raw (S (S'First)'Address, U64 (S'Length));
	      end if;
	   end Put_Str;

	   procedure Put_Line (S : String) is
	   begin
	   	  Put_Str (S);
	   	  Put_Char (ASCII.LF);
	   end Put_Line;

       procedure Put_Hex8 (Val : U8) is
       	  Hi : constant Natural := Natural (Val / 16);
       	  Lo : constant Natural := Natural (Val mod 16);
       begin
          Put_Char (Hex_Digits (Hex_Digits'First + Hi));
          Put_Char (Hex_Digits (Hex_Digits'First + Lo));
       end Put_Hex8;

       procedure Put_Hex16 (Val : U16) is
          V : U16 := Val;
       begin
          for I in 1 .. 4 loop
            Put_Char (Hex_Digits (Hex_Digits'First + Natural (V / 16#1000#)));
            V := V * 16;
          end loop;
       end Put_Hex16;

       procedure Put_Hex32 (Val : U32) is
          V : U32 := Val;
       begin 
          for I in 1 .. 8 loop
            Put_Char
              (Hex_Digits (Hex_Digits'First + Natural (V / 16#1000_0000#)));
            V := V * 16;
          end loop;
       end Put_Hex32;
       
	   procedure Put_Hex64 (Val : U64) is
	   	  V      : U64 := Val;
	   	  Nibble : Natural;
	   begin
		  Put_Str ("0x");
	      for I in 1 .. 16 loop
	         Nibble := Natural (V / 16#1000_0000_0000_0000#);
	         Put_Char (Hex_Digits (Hex_Digits'First + Nibble));
	         V := V * 16;
	      end loop;
	  end Put_Hex64;

      procedure Put_Dec2 (Val : U8) is
      	    D1 : constant Natural := Natural ((Val / 10) mod 10);
      	    D2 : constant Natural := Natural (Val mod 10);
        begin
           Put_Char (Character'Val (Character'Pos ('0') + D1));
           Put_Char (Character'Val (Character'Pos ('0') + D2));
        end Put_Dec2;
        
	  
	  function Get_Ticks return U64 is
	  	Ret : U64;
	  begin 
	  	Asm ("int $0x80", 
	  		Outputs  => U64'Asm_Output ("=a", Ret),
	  		Inputs   => (U64'Asm_Input   ("0", Sys_Ticks)),
	  		Clobber  => "memory",
	  		Volatile => True);
	  	return Ret;
	  end Get_Ticks;

	  function In8 (Port : U16) return U8 is
	     Ret : U64;
	  begin
	     Asm ("int $0x80", 
	          Outputs  => U64'Asm_Output ("=a", Ret),
	          Inputs   => (U64'Asm_Input ("0", Sys_In8),
	                       U64'Asm_Input ("D", U64 (Port))),
	          Clobber  => "memory",
	          Volatile => True);
	    return U8 (Ret and 16#FF#);
	 end In8;

    procedure Out8 (Port : U16; Val : U8) is 
       Ret : U64;
    begin
       Asm ("int $0x80", 
            Outputs  => U64'Asm_Output ("=a", Ret), 
            Inputs   => (U64'Asm_Input ("0", Sys_Out8),
                         U64'Asm_Input ("D", U64 (Port)),
                         U64'Asm_Input ("S", U64 (Val))),
            Clobber  => "memory",
            Volatile => True);
    end Out8;

    function In32 (Port : U16) return U32 is
       Ret : U64;
    begin
       Asm ("int $0x80", 
            Outputs  => U64'Asm_Output ("=a", Ret),
            Inputs   => (U64'Asm_Input ("0", Sys_In32),
                         U64'Asm_Input ("D", U64 (Port))),
            Clobber  => "memory",
            Volatile => True);
       return U32 (Ret and 16#FFFF_FFFF#);
    end In32;

    procedure Out32 (Port : U16; Val : U32) is
       Ret : U64;
    begin
       Asm ("int $0x80", 
             Outputs  => U64'Asm_Output ("=a", Ret),
             Inputs   => (U64'Asm_Input ("0", Sys_Out32), 
                          U64'Asm_Input ("D", U64 (Port)),
                          U64'Asm_Input ("S", U64 (Val))),
             Clobber  => "memory",
             Volatile => True);
   end Out32;
end Syscall;
