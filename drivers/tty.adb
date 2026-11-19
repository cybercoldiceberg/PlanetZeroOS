-- SPDX-License-Identifier: GPL-2.0-only
with System;
with System.Machine_Code; use System.Machine_Code;
with Ada.Unchecked_Conversion;
with IO;
with GDT;
with IDT;
package body TTY is 
	pragma Suppress (All_Checks); 

	type Ring_Buf is array (U8) of Character;
	type Key_Map  is array (U8  range 0 .. 16#39#) of Character;

	Buf 	       : Ring_Buf with Volatile;
	Head           : U8 with Volatile;
	Tail           : U8 with Volatile;
	Shift_Down     : Boolean with Volatile;
	Ctrl_Down      : Boolean with Volatile;
	Alt_Down       : Boolean with Volatile; 
	Caps_Lock      : Boolean with Volatile;
	Extended       : Boolean with Volatile; 
	Pending_Switch : U8 with Volatile;

	Line     : String(1 .. 80); 
	Line_Len : Natural;

	Unshifted : constant Key_Map :=
	     (ASCII.NUL, ASCII.NUL, '1','2','3','4','5','6','7','8',
	      '9','0','-','=', ASCII.BS, ASCII.HT,
	      'q','w','e','r','t','y','u','i','o','p','[',']',
	      ASCII.LF, ASCII.NUL,
	      'a','s','d','f','g','h','j','k','l',';',
	      Character'Val (39), '`', ASCII.NUL, Character'Val (92),
	      'z','x','c','v','b','n','m',',','.','/',
	      ASCII.NUL, '*', ASCII.NUL, ' ');
	
	   Shifted : constant Key_Map :=
	     (ASCII.NUL, ASCII.NUL, '!','@','#','$','%','^','&','*',
	      '(',')','_','+', ASCII.BS, ASCII.HT,
	      'Q','W','E','R','T','Y','U','I','O','P','{','}',
	      ASCII.LF, ASCII.NUL,
	      'A','S','D','F','G','H','J','K','L',':',
	      Character'Val (34), '~', ASCII.NUL, '|',
	      'Z','X','C','V','B','N','M','<','>','?',
	      ASCII.NUL, '*', ASCII.NUL, ' ');


	    procedure Push_Char (C : Character) is 
	    	Next : constant U8 := Head + 1;
	    begin 
	    	if Next /= Tail then
	    		Buf (Head) := C;
	    		Head := Next;
	    	end if;
	    end Push_Char; 

	    function Pop_Char (C : out Character) return Boolean is 
	    begin
	    	if Head = Tail then
	    		C := ASCII.NUL; 
	    		return False;
	    	end if;
	    	C    := Buf (Tail);
	    	Tail := Tail + 1; 
	    	return True;
	    end Pop_Char;

	    procedure Init is
	    	Dummy : U8;
	    begin
	      Head		     := 0;
	      Tail           := 0;
	      Shift_Down     := False;
	      Ctrl_Down      := False;
	      Alt_Down       := False;
	      Caps_Lock      := False;
	      Extended       := False;
	      Pending_Switch := 0;
	      

	      while (IO.Inb (16#64#) and 1) /= 0 loop
	      	Dummy := IO.Inb (16#60#); 
	      end loop;
	    end Init;

	    procedure Handle_Scancode (Sc : U8) is 
	    	C     : Character;
	    	Upper : Boolean;
	    begin

	      if Sc = 16#E0# then
	      	Extended := True;
	      	return;
	      end if;

	      if Extended then
	         Extended := False;
	         if Sc = 16#1D# then
	         	Ctrl_Down := True;
	         elsif Sc = 16#9D# then
	         	Ctrl_Down := False;
	         elsif Sc = 16#38# then
	         	Alt_Down := True;
	         elsif Sc = 16#B8# then
	         	Alt_Down := False;
	         end if;
	         return;
	       end if;

	      if Sc = 16#1D# then
	      	 Ctrl_Down := True;
	      	 return;
	      elsif Sc = 16#9D# then
	      	Ctrl_Down := False;
	        return;
	      elsif Sc = 16#38# then
	      	Alt_Down := True;
	        return;
	      elsif Sc = 16#B8# then
	      	 Alt_Down := False;
	         return;
	      end if;

	      if Sc = 16#2A# or else Sc = 16#36# then
	      	 Shift_Down  := True;
	      	 return;
	     elsif Sc = 16#AA# or else Sc = 16#B6# then
	     	Shift_Down := False;
	     	return;
	     elsif Sc = 16#3A# then
	     	Caps_Lock := not Caps_Lock;
	     	return;
	     end if;


	      if (Sc and 16#80#) /= 0 or else Sc > 16#39# then
	      	return;
	      end if; 

          if Ctrl_Down and then Shift_Down and then Alt_Down then

          	if Sc = 16#02# then
          		Pending_Switch := 1;
          	    return;
          	elsif Sc = 16#03# then
          		Pending_Switch := 2;
          		return;
          	elsif Sc = 16#04# then
          		Pending_Switch := 3;
          		return;
          	end if;
          end if;
	      C := Unshifted (Sc); 
	      if C = ASCII.NUL then 
	      	return;
	      end if;

	      if C >= 'a' and then C <= 'z' then
	      	Upper := Shift_Down xor Caps_Lock;
	      	if Upper then
	      		C := Shifted (Sc); 
	      	end if;
		elsif Shift_Down then
			C := Shifted (Sc);
		end if;

		Push_Char (C);
	end Handle_Scancode;

	procedure Next_Event
     (Kind    : out  Event_Kind; 
       Ch     : out  Character;
       Target : out  TTY_ID)
    is 
    	Got : Boolean;
    begin
      loop
      	if Pending_Switch >= 1 and then Pending_Switch <= 3 then
      	   Target         := TTY_ID (Pending_Switch);
      	   Pending_Switch := 0;
      	   Kind           := Evt_Switch;
      	   Ch             := ASCII.NUL;
      	   return;
      	 end if;

      	 if Pop_Char (Ch) then
      	 	Kind   := Evt_Char;
      	 	Target := IO.Current_TTY;
            return;
         end if;
      IO.Serial_Poll (Ch, Got);
      if Got then
      	Kind    := Evt_Char;
      	Target  := IO.Current_TTY;
      	return;
      end if;

      Asm ("sti; hlt", Volatile => True);
    end loop;
  end Next_Event;
end TTY;
      	
