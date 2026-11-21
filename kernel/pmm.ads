-- SPDX-License-Identifier: GPL-2.0-only
with Types; use Types;

package PMM is 
   Page_Size : constant := 4096;

   procedure Init;
   function Alloc_Page return U64;
   procedure Free_Page (Physc_Addr : U64); 
   function Free_Pages_Count return U64;
end PMM;
