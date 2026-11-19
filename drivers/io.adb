-- SPDX-License-Identifier: GPL-2.0-only
with System; 
with System.Machine_Code; use System.Machine_Code;

package body IO is 
	pragma Suppress (All_Checks); 

	type VGA_Cell is record 
		Char : Character;
		Attr : U8;
	end record with Size => 16;

	for VGA_Cell use record 
		Char at 0 range 0 .. 7; 
		Attr at 1 range 0 .. 7; 
	end record; 

    type VGA_Screen is array (0 .. 80 * 25 - 1) of
VGA_Cell 
	with Component_Size => 16; 


	type Console_State is record
		Buf  : VGA_Screen;
		Row  : Natural;
		Col  : Natural;
		Attr : U8;
	end record;
    
  VGA : VGA_Screen with 
  	Volatile, 
  	Import,
  	Address => System'To_Address (16#B8000#); 

  Consoles   : array (TTY_ID) of Console_State;
  Active_TTY : TTY_ID;

  COM1       : constant U16 := 16#3F8#; 
  Hex_Digits : constant String := "0123456789ABCDEF"; 

  procedure Outb (Port : U16; Val : U8) is 
  begin 
  	Asm ("outb %0, %1", 
  		Inputs 	=> (U8'Asm_Input ("a", Val),
  					U16'Asm_Input ("Nd", Port)), 
  		Volatile => True); 
  	end Outb; 

  	function Inb (Port : U16) return U8 is 
  		Val : U8;
  	begin 
  		Asm ("inb %1, %0",  
  		Outputs => U8'Asm_Output ("=a", Val), 
  		Inputs => U16'Asm_Input ("Nd", Port), 
  		Volatile => True); 
  	return Val;
  end Inb;

  procedure Outl (Port : U16; Val : U32) is
  begin
  	Asm ("outl %0, %1", 
  		 Inputs  => (U32'Asm_Input ("a", Val),
  		 			 U16'Asm_Input ("Nd", Port)),
  		 Volatile => True);
    end Outl;

    function Inl (Port : U16) return U32 is
       Val : U32;
    begin
       Asm ("inl %1, %0", 
            Outputs  => U32'Asm_Output ("=a", Val),
            Inputs   => U16'Asm_Input  ("Nd", Port),
            Volatile => True);
       return Val;
end Inl;
  
  procedure Update_Cursor is
  	Pos : constant U16 :=
  		U16 (Consoles (Active_TTY).Row * 80 + Consoles (Active_TTY).Col);
   begin 
   	  Outb (16#3D4#, 16#0F#);
   	  Outb (16#3D5#, U8 (Pos and 16#FF#));
   	  Outb (16#3D4#, 16#0E#);
   	  Outb (16#3D5#, U8 (Pos / 256));
   end Update_Cursor;
  procedure Serial_Put (C : Character) is 
  	Spin : Natural := 0; 
  begin 
  	while (Inb (COM1 + 5) and 16#20#) = 0 loop 
  		Spin := Spin + 1; 
  		exit when Spin > 100_000;
  	end loop;
  	Outb (COM1, U8 (Character'Pos (C))); 
  end Serial_Put; 
  procedure Serial_Poll (C : out Character; Got : out Boolean) is
  begin
  	if (Inb (COM1 + 5) and 16#01#) /= 0 then 
  		C := Character'Val (Natural (Inb (COM1)));
  		Got := True;
  	else
  	  C := ASCII.NUL;
  	  Got := False;
  	end if;
  end Serial_Poll;
  
  procedure Scroll_On (T : TTY_ID) is
  	Attr : constant U8 := Consoles (T).Attr;
  begin
  	for R in 0 .. 23 loop
  		for C in 0 .. 79 loop
  			Consoles (T).Buf (R * 80 + C) :=
  				Consoles (T).Buf ((R + 1) * 80 + C);
  			end loop;
  		end loop;
  		for C in 0 .. 79 loop
  			Consoles (T).Buf (24 * 80 + C) := (Char => ' ', Attr => Attr);
  		end loop;
  		Consoles (T).Row := 24; 
  		Consoles (T).Col := 0;

  		if T = Active_TTY then
  			for I in VGA'Range loop
  				VGA (I) := Consoles (T).Buf (I);
  			end loop;
  		end if;
  	end Scroll_On;

  procedure Clear_On (T : TTY_ID) is
  	Attr : constant U8 := Consoles (T).Attr;
  begin
  	   for I in VGA'Range loop
  	   	 Consoles (T).Buf (I) := (Char => ' ', Attr => Attr);
  	   end loop;
  	   Consoles (T).Row := 0;
  	   Consoles (T).Col := 0;

  	   if T = Active_TTY then
  	   	 for I in VGA'Range loop
  	   	 	VGA (I) := Consoles (T).Buf (I);
  	   	 end loop;
  	     Update_Cursor;
  	  end if;
end Clear_On;
  procedure Clear is
  begin 
  	Clear_On (Active_TTY);
  end Clear;

  function Current_TTY return TTY_ID is 
  begin
  	return Active_TTY;
  end Current_TTY;

  procedure Switch_TTY (T : TTY_ID) is
  begin
  	if T = Active_TTY then
  		return;
  	end if;
  	Active_TTY := T;
  	for I in VGA'Range loop
  		VGA (I) := Consoles (T).Buf (I);
  	end loop;
  	Update_Cursor;
  end Switch_TTY;
  
	procedure Backspace is 

	T : constant TTY_ID := Active_TTY;
	Idx  : Natural;
	Cell : VGA_Cell;
begin
	if Consoles (T).Col > 0 then
	   Consoles (T).Col := Consoles (T).Col - 1;
	   Idx  := Consoles (T).Row * 80 + Consoles (T).Col;
	   Cell := (Char => ' ', Attr => Consoles (T).Attr);
	   Consoles (T).Buf (Idx) := Cell;
	   VGA (Idx) := Cell;
	   Serial_Put (ASCII.BS);
	   Serial_Put (' ');
	   Serial_Put (ASCII.BS);
	   Update_Cursor;
	 end if;
end Backspace; 
	
  procedure Init is 
  begin 
  	Outb (COM1 + 1, 16#00#);
  	Outb (COM1 + 3, 16#80#); 
  	Outb (COM1 + 0, 16#01#); 
  	Outb (COM1 + 1, 16#00#); 
  	Outb (COM1 + 3, 16#03#); 
  	Outb (COM1 + 2, 16#C7#); 
  	Outb (COM1 + 4, 16#0B#); 
  	Consoles (1).Attr := 16#0A#; 
  	Consoles (2).Attr := 16#0B#;
  	Consoles (3).Attr := 16#0E#;

    Active_TTY := 1;
    Clear_On (1);
    Clear_On (2);
    Clear_On (3);
end Init; 

procedure Put_Char_On (T : TTY_ID; C : Character) is
	Idx  : Natural;
	Cell : VGA_Cell;
begin
	if C = ASCII.LF then
		if T = Active_TTY then
			Serial_Put (ASCII.CR);
			Serial_Put (ASCII.LF);
		end if;
		Consoles (T).Col := 0;
		Consoles (T).Row := Consoles (T).Row + 1;
		if Consoles (T).Row >= 25 then
			Scroll_On (T);
		end if;
		if T = Active_TTY then
			Update_Cursor;
		end if;
		return; 
	end if;

	if T = Active_TTY then
		Serial_Put (C);
	end if;

	Idx  := Consoles (T).Row * 80 + Consoles (T).Col;
	Cell := (Char => C, Attr => Consoles (T).Attr);
	Consoles (T).Buf (Idx) := Cell;
	if T = Active_TTY then
		VGA (Idx) := Cell;
	end if;

    Consoles (T).Col := Consoles (T).Col + 1;
    if Consoles (T).Col >= 80 then
       Consoles (T).Col := 0;
       Consoles (T).Row := Consoles (T).Row + 1;
    if Consoles (T).Row >= 25 then
    	Scroll_On (T);
    end if;
 end if;
 if T = Active_TTY then
 	Update_Cursor;
 end if;
end Put_Char_On;
	 
  procedure Put_Char (C : Character) is 
  begin 
  	Put_Char_On (Active_TTY, C);
  end Put_Char;

  procedure Put_Str_On (T : TTY_ID; S : String) is 
  begin
  	for I in S'Range loop
  		Put_Char_On (T, S (I));
  	end loop;
end Put_Str_On;

procedure Put_Line_On (T : TTY_ID; S : String) is
	begin 
		Put_Str_On (T, S);
		Put_Char_On (T, ASCII.LF);
	end Put_Line_On;

  procedure Put_Str (S : String) is 
  	begin 
  	  Put_Str_On (Active_TTY, S);
    end Put_Str;

  	procedure Put_Line (S : String) is 
  	begin 
  		Put_Str (S);
  		Put_Char (ASCII.LF); 
  	end Put_Line; 

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
end IO;
   	
