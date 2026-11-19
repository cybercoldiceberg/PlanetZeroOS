-- SPDX-License-Identifier: GPL-2.0-only
with Types; use Types;
with System.Machine_Code; use System.Machine_Code;
with IO;
with TTY; use type TTY.Event_Kind;
with GDT;
with IDT;
with Ring1;
package body Shell is 
	pragma Suppress (All_Checks);
	type Session_State is record 
	Line : String (1 .. 80);
	Len  : Natural;
end record;

Sessions : array (TTY_ID) of Session_State;

	function Match
		(T          : TTY_ID;
		First, Last : Natural;
		Word        : String) return Boolean  
    is
    begin 
       if First > Last or else (Last - First + 1) /= Word'Length then
       	  return False;
       end if;
       for I in 0 .. Word'Length - 1 loop
       	 if Sessions (T).Line (First + I) /= Word (Word'First + I) then
       	 	return False;
       	 end if;
       end loop;
       return True;
    end Match;

    procedure Next_Token
      (T     : TTY_ID;
      Pos   : in out Natural;
       First : out Natural;
       Last  : out Natural;
       Found : out Boolean)
    is 
      Len : constant Natural := Sessions (T).Len;
    begin 
    	while Pos <= Len and then Sessions (T).Line (Pos) = ' ' loop
    	   Pos := Pos + 1;
    	end loop;
    	if Pos > Len then
    		First := 1;
    		Last  := 0;
    		Found := False;
    		return;
    	end if;
    	First := Pos;
    	while Pos <= Len and then Sessions (T).Line (Pos) /= ' ' loop
    	   Pos := Pos + 1;
    	end loop;
    	Last  := Pos - 1;
    	Found := True;
    end Next_Token;
  
    procedure Print_Prompt (T : TTY_ID) is
    begin
       case T is
       	  when 1 => IO.Put_Str_On (1, "PZSH[1]> ");
       	  when 2 => IO.Put_Str_On (2, "PZSH[2]> ");
       	  when 3 => IO.Put_Str_On (3, "PZSH[3]> ");
       end case;
    end Print_Prompt;
    
    procedure Print_Help is
    begin 
    	IO.Put_Line ("PZSH Commands: ");
    	IO.Put_Line ("  help         - show this message");
    	IO.Put_Line ("  clr          - clear active TTY");
    	IO.Put_Line ("  repeat <x>   - print text");
    	IO.Put_Line ("  get_ticks    - show PIT timer ticks");
    	IO.Put_Line ("  rings        - inspect GDT/ISS rings");
    	IO.Put_Line ("  ring1 [fault] - run Ada in Ring 1 Ada Drivers (CPL=1)");
    	IO.Put_Line ("  tty <1-3>    - switch TTY (or Ctrl+Shift+Alt+1..3)");
    	IO.Put_Line ("  hlt          - halt CPU"); 
    end Print_Help;

    procedure Execute_Line (Cur : TTY_ID; Next_TTY : out TTY_ID) is
       Pos, F, L : Natural := 1;
       A1, A2    : Natural;
       Found     : Boolean;
       Len       : constant Natural := Sessions (Cur).Len;
    begin
       Next_TTY := Cur;
       Next_Token (Cur, Pos, F, L, Found);
       if not Found then
       	   return;
       end if;

       if Match (Cur, F, L, "help") then
       	Print_Help;
       elsif Match (Cur, F, L, "clr") then
       	  IO.Clear;
       elsif Match (Cur, F, L, "repeat") then
       	while Pos <= Len and then Sessions (Cur).Line (Pos) = ' ' loop
       		Pos := Pos + 1;
       	end loop;
        for I in Pos .. Len loop
        	IO.Put_Char (Sessions (Cur).Line (I));

        end loop;
        IO.Put_Char (ASCII.LF);
        elsif Match (Cur, F, L, "get_ticks") then
          IO.Put_Str   ("Ticks: ");
          IO.Put_Hex64 (IDT.Ticks);
          IO.Put_Char (ASCII.LF);
       elsif Match (Cur, F, L, "rings") then
       	  IO.Put_Str ("CS=");
       	  IO.Put_Hex64 (U64 (GDT.Current_CS));
       	  IO.Put_Str (" TR=");
       	  IO.Put_Hex64 (U64 (GDT.Current_TR));
       	  IO.Put_Char (ASCII.LF);
       	  IO.Put_Line ("Rings: 0(0x08/10) 1(0x18/20) 2(0x28/30) 3(0x38/40)");
       elsif Match (Cur, F, L, "ring1") then
       	      Next_Token (Cur, Pos, A1, A2, Found);
       	      declare
       	      	 Code : U64;
       	      begin 
       	         if Found and then Match (Cur, A1, A2, "pci") then
       	            Code := Ring1.Launch (Ring1.Mode_PCI);
       	         elsif Found and then Match (Cur, A1, A2, "rtc") then
       	         	Code := Ring1.Launch (Ring1.Mode_RTC);
       	      	 if Found and then Match (Cur, A1, A2, "fault") then
       	      	 	Code := Ring1.Launch (Ring1.Mode_Fault);
       	      	 else
       	      	    Code := Ring1.Launch (Ring1.Mode_Info);
       	      	 end if;
       	      	 IO.Put_Str ("[RING-0] Ring-1 exited with code ");
       	      	 IO.Put_Hex64 (Code);
       	      	 IO.Put_Char (ASCII.LF);
       	    end if;
       	end;
       elsif Match (Cur, F, L, "tty") then
       	  Next_Token (Cur, Pos, A1, A2, Found);
       	  if Found and then A1 = A2 then
       	     if Sessions (Cur).Line (A1) = '1' then
       	     	Next_TTY := 1;
       	     elsif Sessions (Cur).Line (A1) = '2' then
       	     	Next_TTY := 2;
       	     elsif Sessions (Cur).Line (A1) = '3' then
       	     	Next_TTY := 3;
       	     else
       	     	IO.Put_Line ("Usage: tty <1|2|3>");
       	     end if;
       	   else 
       	     IO.Put_Line ("Usage: tty <1|2|3>");
       	   end if;

       	   elsif Match (Cur, F, L, "hlt") then
       	   	IO.Put_Line ("System halted.");
       	   	loop
       	   		Asm ("cli; hlt", Volatile => True);
       	   	end loop;
       	  else IO.Put_Str ("PZSH: unknown command: ");
       	  for I in F .. L loop
       	  	IO.Put_Char (Sessions (Cur).Line (I));
       	  end loop;
       	  IO.Put_Char (ASCII.LF);
       	end if;
     end Execute_Line;

     procedure Run is
     	Cur, Next_TTY : TTY_ID := 1;
     	Kind          : TTY.Event_Kind;
     	Ch            : Character;
     	Target        : TTY_ID;
     begin
     	for T in TTY_ID loop
     		Sessions (T).Len := 0;
        end loop; 
         IO.Put_Line_On (1, "PZSH [TTY 1/3] - Ctrl+Shift+Alt+1..3 or 'tty <1-3>'");
      Print_Prompt (1);

      IO.Put_Line_On (2, "[TTY 2/3] PlanetZero System Console (Cyan)");
      IO.Put_Line_On (2, "Ready for Ring-1 diagnostics & commands.");
      Print_Prompt (2);

      IO.Put_Line_On (3, "[TTY 3/3] PlanetZero Sandbox Console (Yellow)");
      IO.Put_Line_On (3, "Ready for ring-2 pending progress...");
      Print_Prompt (3);

      loop
         TTY.Next_Event (Kind, Ch, Target);
         if Kind = TTY.Evt_Switch then
            IO.Switch_TTY (Target);
            Cur := Target;
         else
            if Ch = ASCII.LF or else Ch = ASCII.CR then
               IO.Put_Char (ASCII.LF);
               Execute_Line (Cur, Next_TTY);
               Sessions (Cur).Len := 0;
               Print_Prompt (Cur);
               if Next_TTY /= Cur then
                  IO.Switch_TTY (Next_TTY);
                  Cur := Next_TTY;
               end if;
            elsif Ch = ASCII.BS or else Ch = ASCII.DEL then
               if Sessions (Cur).Len > 0 then
                  Sessions (Cur).Len := Sessions (Cur).Len - 1;
                  IO.Backspace;
               end if;
            elsif Ch >= ' ' and then Ch <= '~' then
               if Sessions (Cur).Len < 80 then
                  Sessions (Cur).Len := Sessions (Cur).Len + 1;
                  Sessions (Cur).Line (Sessions (Cur).Len) := Ch;
                  IO.Put_Char (Ch);
               end if;
            end if;
         end if;
      end loop;
   end Run;
end Shell;
       
       
