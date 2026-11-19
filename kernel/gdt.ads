-- SPDX-License-Identifier: GPL-2.0-only
with Types; use Types;

package GDT is 
	Kernel_Code_Sel : constant U16 := 16#08#; 
	Kernel_Data_Sel : constant U16 := 16#10#; 
	Ring1_Code_Sel  : constant U16 := 16#19#;
	Ring1_Data_Sel  : constant U16 := 16#21#; 
	Ring2_Code_Sel  : constant U16 := 16#2A#; 
	Ring2_Data_Sel  : constant U16 := 16#32#; 
	Ring3_Data_Sel  : constant U16 := 16#3B#; 
	Ring3_Code_Sel  : constant U16 := 16#43#; 
	TSS_Sel         : constant U16 := 16#48#; 

	procedure Init (Kernel_Stack_Top : U64); 
	procedure Set_Ring1_Stack (Stack_Top : U64); 
	procedure Set_Ring2_Stack (Stack_Top : U64); 
	function Current_CS return U16;
	function Current_TR return U16;
end GDT;
