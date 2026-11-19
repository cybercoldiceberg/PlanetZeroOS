-- SPDX-License-Identifier: GPL-2.0-only
with System;
with Types; use Types;

package IDT is
	procedure Init;
	function Ticks return U64;


	procedure ISR_Dispatch (Frame_Addr : System.Address); 
	pragma Export (C, ISR_Dispatch, "isr_dispatch"); 
end IDT;
