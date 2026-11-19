-- SPDX-License-Identifier: GPL-2.0-only
with Types; use Types;

package TTY is
   type Event_Kind is (Evt_Char, Evt_Switch);

   procedure Init;
   procedure Handle_Scancode (Sc : U8);

   procedure Next_Event
     (Kind   : out Event_Kind; 
      Ch     : out Character; 
      Target : out TTY_ID);
end TTY;
