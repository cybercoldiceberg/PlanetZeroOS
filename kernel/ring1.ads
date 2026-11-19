-- SPDX-License-Identifier: GPL-2.0-only
with Types; use Types;

package Ring1 is
    type Mode_Kind is (Mode_Info, Mode_PCI, Mode_RTC, Mode_Fault);
    
	function Launch (Mode : Mode_Kind) return U64;
end Ring1;
