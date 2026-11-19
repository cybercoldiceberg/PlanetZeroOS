-- SPDX-License-Identifier: GPL-2.0-only
with Types; use Types;

package IO is
	procedure Init;
	function Current_TTY return TTY_ID;
	procedure Switch_TTY (T : TTY_ID);

	procedure Clear;
	procedure Clear_On (T : TTY_ID);
	procedure Backspace;

	procedure Put_Char (C : Character);
	procedure Put_Str (S : String);
	procedure Put_Line (S : String);

	procedure Put_Char_On (T : TTY_ID; C : Character);
	procedure Put_Str_On  (T : TTY_ID; S : String); 
	procedure Put_Line_On (T : TTY_ID; S : String); 

	procedure Put_Hex64 (Val : U64);
	procedure Serial_Poll (C : out Character; Got : out Boolean);

	procedure Outb (Port : U16; Val : U8);
	function Inb (Port : U16) return U8;
    procedure Outl (Port : U16; Val : U32);
    function Inl (Port : U16) return U32;
end IO;
