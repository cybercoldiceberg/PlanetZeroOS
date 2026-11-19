/* SPDX-License-Identifier: GPL-2.0-only */
ENTRY(_start) 

SECTIONS { 
	. = 0xA000; 

	.text : ALIGN(16) { 
		KEEP(*(.text_boot)) 
		*(.text*) 
	}

	.rodata : ALIGN(16) { 
		*(.rodata*) 
		*(.data.rel.ro*) 
	} 

	.data : ALIGN(16) { 
		*(.data*) 
	} 

	.bss : ALIGN(16) { 
		__bss_start = .; 
		*(COMMON) 
		*(.bss*) 
		__bss_end = .; 
    } 

    /DISCARD/ : { 
    	*(.eh_frame*) 
    	*(.note*) 
    	*(.comment) 
    } 
} 
