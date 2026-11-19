; SPDX-License-Identifier: GPL-2.0-only
BITS 64 

section .text.boot 
global _start
global memcpy 
global memset 
global __gnat_last_chance_handler
extern kernel_main 
extern __bss_start
extern __bss_end 

_start: 
	cli
	cld 

	mov ax, 0x10 
	mov ds, ax
	mov es, ax 
	mov ss, ax

	mov rsp, 0x90000

	mov rdi, __bss_start
	mov rcx, __bss_end 
	sub rcx, rdi
	xor al, al 
	rep stosb 

	call kernel_main

__gnat_last_chance_handler: 
.hang: 
	cli 
	hlt
	jmp .hang 

memcpy: 
	mov rax, rdi 
	mov rcx, rdx 
	rep movsb 
	ret 

memset: 
	mov rax, rdi 
	mov rcx, rdx
	push rax 
	mov al, sil
	rep stosb 
	pop rax
	ret 
	
