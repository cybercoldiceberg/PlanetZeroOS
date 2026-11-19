-- SPDX-License-Identifier: GPL-2.0-only
package Types is 
	pragma Pure;

	type U8  is mod 2**8  with Size => 8;
	type U16 is mod 2**16 with Size => 16;
	type U32 is mod 2**32 with Size => 32;
	type U64 is mod 2**64 with Size => 64; 

	type TTY_ID is range 1 .. 3;
end Types;
