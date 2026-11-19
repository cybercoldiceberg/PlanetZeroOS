-- SPDX-License-Identifier: GPL-2.0-only
with System;
with Types; use Types;

package Syscall is
	Sys_Exit  : constant U64 := 0;
	Sys_Write : constant U64 := 1;
	Sys_Ticks : constant U64 := 2;
    Sys_In8   : constant U64 := 3;
    Sys_Out8  : constant U64 := 4;
    Sys_In32  : constant U64 := 5;
    Sys_Out32 : constant U64 := 6;
	procedure Handle
	 (Caller_CPL : U64; 
	  Num  : U64;
	   Arg1 : U64;
	   Arg2 : U64;
	   Arg3 : U64;
	   Ret  : out U64);

procedure Exit_Ring (Code : U64);
procedure Put_Char  (C : Character);
procedure Put_Str   (S : String);
procedure Put_Line  (S : String);
procedure Put_Hex8  (Val : U8);
procedure Put_Hex16 (Val : U16);
procedure Put_Hex32 (Val : U32);
procedure Put_Hex64 (Val : U64);
procedure Put_Dec2  (Val : U8); 
function Get_Ticks return U64;


function In8 (Port : U16) return U8;
procedure Out8 (Port : U16; Val : U8);
function In32 (Port : U16) return U32;
procedure Out32 (Port : U16; Val : U32);
end Syscall;
