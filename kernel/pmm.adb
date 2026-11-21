-- SPDX-License-Identifier: GPL-2.0-only
package body PMM is 
   pragma Suppress (All_Checks); 

   Total_Memory : constant := 64 * 1024 * 1024; 
   Total_Pages  : constant := Total_Memory / Page_Size;
   Bitmap_Size  : constant := Total_Pages / 8;

   Bitmap     : array (0 .. Bitmap_Size - 1) of U8 with Volatile;  
   Free_Count : U64;

   Masks : constant array (0 .. 7) of U8 :=
     (16#01#, 16#02#, 16#04#, 16#08#, 16#10#, 16#20#, 16#40#, 16#80#);

   procedure Set_Bit (Bit_Idx : U64) is  
      Byte_Idx : constant U64 := Bit_Idx / 8;
      Bit_Off  : constant Natural := Natural (Bit_Idx mod 8);
   begin 
    Bitmap (Integer (Byte_Idx)) := Bitmap (Integer (Byte_Idx)) or Masks (Bit_Off);
   end Set_Bit;

   procedure Clear_Bit (Bit_Idx : U64) is 
      Byte_Idx : constant U64 := Bit_Idx / 8;
      Bit_Off  : constant Natural := Natural (Bit_Idx mod 8);
   begin 
     Bitmap (Integer (Byte_Idx)) := Bitmap (Integer (Byte_Idx)) and not Masks (Bit_Off);
   end Clear_Bit;

   function Test_Bit (Bit_Idx : U64) return Boolean is 
      Byte_Idx : constant U64 := Bit_Idx / 8; 
      Bit_off  : constant Natural := Natural (Bit_Idx mod 8);
   begin 
     return (Bitmap (Integer (Byte_Idx)) and Masks (Bit_Off)) /= 0; 
   end Test_Bit;

   procedure Init is 
   begin 
     for I in Bitmap'Range loop 
       Bitmap (I) := 16#FF#; 
     end loop;
     Free_Count := 0; 
     for Page in 512 .. Total_Pages - 1 loop
        Clear_Bit (U64 (Page));
        Free_Count := Free_Count + 1;
     end loop;
end Init;

function Alloc_Page return U64 is 
begin
  for Page in U64'(0) .. U64 (Total_Pages - 1) loop
    if not Test_Bit (Page) then 
       Set_Bit (Page); 
       if Free_Count > 0 then
          Free_Count := Free_Count - 1;
       end if;
       return Page * Page_Size;
    end if;
  end loop;
  return 16#FFFF_FFFF_FFFF_FFFF#;
end Alloc_Page;

procedure Free_Page (Physc_Addr : U64) is 
  Page : constant U64 := Physc_Addr / Page_Size; 
begin 
  if Test_Bit (Page) then 
     Clear_Bit (Page);
     Free_Count := Free_Count + 1;
  end if;
end Free_Page;

function Free_Pages_Count return U64 is 
begin 
  return Free_Count; 
 end Free_Pages_Count;
end PMM;
