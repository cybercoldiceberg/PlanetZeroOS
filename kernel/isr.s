; SPDX-License-Identifier: GPL-2.0-only
BITS 64

section .text
extern isr_dispatch
global isr_stub_table
global isr_stub_128
global ring_return_to_caller
global ring_call_pl
section .text
isr_stub_128:
	push qword 0 
	push qword 128
	jmp isr_common



%macro ISR_NOERR 1 
isr_stub_%1: 
	push qword 0 
	push qword %1 
	jmp isr_common 
%endmacro 

%macro ISR_ERR 1 
isr_stub_%1: 
	push qword %1 
	jmp isr_common 
%endmacro

ISR_NOERR 0 
ISR_NOERR 1
ISR_NOERR 2 
ISR_NOERR 3 
ISR_NOERR 4 
ISR_NOERR 5 
ISR_NOERR 6 
ISR_NOERR 7
ISR_ERR   8 
ISR_NOERR 9
ISR_ERR   10
ISR_ERR   11
ISR_ERR   12
ISR_ERR   13
ISR_ERR   14
ISR_NOERR 15
ISR_NOERR 16
ISR_ERR   17
ISR_NOERR 18
ISR_NOERR 19
ISR_NOERR 20
ISR_ERR   21
ISR_NOERR 22
ISR_NOERR 23
ISR_NOERR 24
ISR_NOERR 25
ISR_NOERR 26
ISR_NOERR 27 
ISR_NOERR 28 
ISR_ERR   29
ISR_ERR   30
ISR_NOERR 31

ISR_NOERR 32
ISR_NOERR 33
ISR_NOERR 34
ISR_NOERR 35
ISR_NOERR 36
ISR_NOERR 37
ISR_NOERR 38
ISR_NOERR 39
ISR_NOERR 40
ISR_NOERR 41
ISR_NOERR 42
ISR_NOERR 43
ISR_NOERR 44
ISR_NOERR 45
ISR_NOERR 46
ISR_NOERR 47

isr_common: 
	push rax
	push rbx
	push rcx 
	push rdx 
	push rsi
	push rdi
	push rbp
	push r8
	push r9
	push r10
	push r11
	push r12
	push r13
	push r14
	push r15

	mov rdi, rsp
	cld 
	call isr_dispatch 

	pop r15
	pop r14
	pop r13
	pop r12
	pop r11
	pop r10
	pop r9
	pop r8
	pop rbp
	pop rdi
	pop rsi
	pop rdx
    pop rcx
    pop rbx
    pop rax
    add rsp, 16
    iretq

section .rodata
align 8
isr_stub_table:
	dq isr_stub_0, isr_stub_1, isr_stub_2, isr_stub_3
	dq isr_stub_4, isr_stub_5, isr_stub_6, isr_stub_7
	dq isr_stub_8, isr_stub_9, isr_stub_10, isr_stub_11
	dq isr_stub_12, isr_stub_13, isr_stub_14, isr_stub_15
	dq isr_stub_16, isr_stub_17, isr_stub_18, isr_stub_19
	dq isr_stub_20, isr_stub_21, isr_stub_22, isr_stub_23
	dq isr_stub_24, isr_stub_25, isr_stub_26, isr_stub_27
	dq isr_stub_28, isr_stub_29, isr_stub_30, isr_stub_31
	dq isr_stub_32, isr_stub_33, isr_stub_34, isr_stub_35
	dq isr_stub_36, isr_stub_37, isr_stub_38, isr_stub_39
	dq isr_stub_40, isr_stub_41, isr_stub_42, isr_stub_43
	dq isr_stub_44, isr_stub_45, isr_stub_46, isr_stub_47
	
section .text

ring_call_pl:
	push rbx
	push rbp
	push r12
	push r13
	push r14
	push r15

	mov [rel ring0_saved_rsp], rsp
	mov byte [rel ring_active], 1

	and rsi, -16
	sub rsi, 8

	mov ds, cx
	mov es, cx

	push rcx
	push rsi
	push qword 0x202
	push rdx
	push rdi
	iretq

ring_return_to_caller:
	cli
	cmp byte [rel ring_active], 0
	je .halt_forever
	mov byte [rel ring_active], 0

	mov ax, 0x10
	mov ds, ax
	mov es, ax
	mov ss, ax

	mov rax, rdi
	mov rsp, [rel ring0_saved_rsp]

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    sti
    ret

.halt_forever:
	hlt
	jmp .halt_forever

section .bss
align 8 
ring0_saved_rsp: resq 1 
ring_active:     resb 1
