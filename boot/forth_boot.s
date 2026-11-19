; SPDX-License-Identifier: GPL-2.0-only
BITS 64
ORG 0x8000

forth_entry: 
	cli 
	cld 
	xor ax, ax
	mov ss, ax
	mov ds, ax
	mov es, ax 
	mov rsp, 0x7000
	mov r15, 0x6000

	call vga_clear
	mov rsi, banner
	call vga_print_str

repl_loop: 
	mov rsi, prompt 
	call vga_print_str
	call read_line

	mov rsi, line_buf
.next_token: 
	call skip_spaces
	cmp byte [rsi], 0 
	je .line_done

	call parse_token
	call exec_token
	jc repl_loop
	jmp .next_token


.line_done: 
	mov rsi, ok_msg
	call vga_print_str
	jmp repl_loop

skip_spaces: 
	cmp byte [rsi], ' ' 
	jne .done 
	inc rsi 
	jmp skip_spaces
.done: 
	ret 

parse_token: 
	mov rdi, rsi
	xor rcx, rcx
.scan: 
	mov al, [rsi]
	cmp al, 0 
	je .done 
	cmp al, ' ' 
	je .done 
	inc rsi
	inc rcx
	jmp .scan
.done: 
	ret

exec_token: 
	push rsi
	mov rbx, dict_head
.search: 
	test rbx, rbx
	jz .try_number
	movzx rax, byte [rbx + 8] 
	cmp rax, rcx
	jne .next_entry

	push rdi
	push rcx 
	lea rsi, [rbx + 9] 
	repe cmpsb 
	pop rcx
	pop rdi 
	je .found
.next_entry: 
	mov rbx, [rbx] 
	jmp .search 
.found: 
	movzx rax, byte [rbx + 8]
	lea rax, [rbx + 9 + rax]
	call [rax]
	pop rsi
	clc
	ret
.try_number: 

	xor rax, rax
	xor rdx, rdx
.hex_loop: 
	cmp rdx, rcx
	je .push_num 
	movzx r8, byte [rdi + rdx] 
	cmp r8, '0'
	jb .unknown
	cmp r8, '9'
	jbe .digit
	cmp r8, 'A'
	jb .unknown 
	cmp r8, 'F'
	ja .unknown
	sub r8, 'A' - 10 
	jmp .accum 
.digit: 
	sub r8, '0'
.accum: 
	shl rax, 4
	or rax, r8
	inc rdx 
	jmp .hex_loop

.push_num: 
	sub r15, 8 
	mov [r15], rax
	pop rsi
	clc
	ret 

.unknown:
	mov rsi, err_word 
	call vga_print_str
	pop rsi
	stc
	ret

w_add: 
	mov rax, [r15]
	add r15, 8
	add [r15], rax
	ret

w_sub: 
	mov rax, [r15]
	add r15, 8
	sub [r15], rax
	ret

w_dup: 
	mov rax, [r15]
	sub r15, 8 
	mov [r15], rax
	ret 

w_drop: 
	add r15, 8
	ret

w_swap: 
	mov rax, [r15] 
	mov rdx, [r15 + 8]
	mov [r15], rdx
	mov [r15 + 8], rax
	ret

w_fetch: 
	mov rax, [r15]
	mov rax, [rax]
	mov [r15], rax
	ret

w_store: 
	mov rdi, [r15]
	mov rax, [r15 + 8]
	mov [rdi], rax
	add r15, 16
	ret

w_dot: 
	mov rax, [r15]
	add r15, 8
	call print_hex64
	mov al, ' ' 
	call vga_putchar 
	ret

w_words: 
	mov rbx, dict_head
.loop:
	test rbx, rbx
	jz .done
	movzx rcx, byte [rbx + 8] 
	lea rsi, [rbx + 9] 
.print_name: 
	lodsb 
	call vga_putchar
	loop .print_name
	mov al, ' ' 
	call vga_putchar
	mov rbx, [rbx]
	jmp .loop
.done:
	mov al, 10
	call vga_putchar
	ret

w_cls: 
    call vga_clear
    ret

w_boot: 
	mov rsi, boot_msg
	call vga_print_str
	call 0xA000
	
.hang:
	hlt 
	jmp .hang 

%define LAST_WORD 0 
%macro DEFWORD 2 
	align 8
%%link: 
	dq LAST_WORD
	%define LAST_WORD %%link
	%strlen %%len %1 
	db %%len
	db %1
	dq %2 
%endmacro

DEFWORD "+",     w_add
DEFWORD "-",     w_sub
DEFWORD "DUP",   w_dup 
DEFWORD "DROP",  w_drop
DEFWORD "SWAP",  w_swap
DEFWORD "@",     w_fetch
DEFWORD "!",     w_store
DEFWORD ".",     w_dot
DEFWORD "WORDS", w_words
DEFWORD "CLS",   w_cls
DEFWORD "BOOT",  w_boot
dict_head equ LAST_WORD

print_hex64: 
	mov rcx, 16
.loop:
	rol rax, 4 
	mov rdx, rax
	and rdx, 0x0F 
	mov dl, [hex_chars + rdx] 
	push rax 
	push rcx
	mov al, dl
	call vga_putchar 
	pop rcx
	pop rax
	loop .loop
	ret

vga_clear: 
	mov rdi, 0xB8000 
	mov rcx, 80 * 25 
	mov ax, 0x0A20
	rep stosw 
	mov qword [cursor_pos], 0
	ret

vga_scroll: 
	push rax
	push rcx
	push rsi
	push rdi
	mov rdi, 0xB8000
	mov rsi, 0xB8000 + 160
	mov rcx, 80 * 24
	rep movsw
	mov ax, 0x0A20
	mov rcx, 80
	rep stosw
	mov qword [cursor_pos], 80 * 24
	pop rdi 
	pop rsi 
	pop rcx
	pop rax 
	ret

vga_putchar: 
	push rax
	push rbx
	push rcx
	push rdx
	cmp al, 10
	je .newline 
    mov rbx, [cursor_pos] 
    cmp rbx, 80 * 25 
    jb .write_char
    call vga_scroll
    mov rbx, [cursor_pos] 

.write_char: 
	mov [0xB8000 + rbx * 2], al 
	mov byte [0xB8000 + rbx * 2 + 1], 0x0A
	inc qword [cursor_pos] 
	jmp .done 
.newline: 
	mov rax, [cursor_pos] 
	xor rdx, rdx
	mov rcx, 80
	div rcx
	inc rax
	mul rcx 
	cmp rax, 80 * 25
	jb .set_cursor
	call vga_scroll
	jmp .done
.set_cursor: 
	mov [cursor_pos], rax
.done: 
	pop rdx
	pop rcx
	pop rbx
	pop rax
	ret

vga_print_str: 
	lodsb 
	or al, al
	jz .done
	call vga_putchar
	jmp vga_print_str

.done: 
	ret

read_line: 
	xor rbx, rbx

.wait_key: 
	in al, 0x64
	test al, 1
	jz .wait_key
	in al, 0x60
	cmp al, 0x2A
	je .shift_on
	cmp al, 0x36
	je .shift_on 
	cmp al, 0xAA
	je .shift_off
	cmp al, 0xB6
	je .shift_off

	test al, 0x80
	jnz .wait_key
	cmp al, 0x1C
	je .enter
	cmp al, 0x0E 
	je .backspace 
	cmp al, 0x39
	ja .wait_key

	movzx rdx, al
	cmp byte [shift_down], 0 
	jne .shifted
	mov al, [scancode_ascii + rdx]
	jmp .got_char
.shifted:
	mov al, [scancode_ascii_shift + rdx] 
.got_char: 
		or al, al 
		jz .wait_key
		cmp rbx, 79

		jae .wait_key
		mov [line_buf + rbx], al 
		inc rbx
		call vga_putchar
		jmp .wait_key
.shift_on: 
	mov byte [shift_down], 1
	jmp .wait_key
.shift_off: 
	mov byte [shift_down], 0
	jmp .wait_key
.backspace:
	test rbx, rbx
	jz .wait_key
	dec rbx
	dec qword [cursor_pos]
	mov rcx, [cursor_pos] 
	mov word [0xB8000 + rcx * 2], 0x0A20 
	jmp .wait_key
.enter:
	mov byte [line_buf + rbx], 0
	mov al, 10
	call vga_putchar
	ret

	cursor_pos: dq 0 
	shift_down: db 0 
	hex_chars: db "0123456789ABCDEF"
	banner:    db "[FORTH STAGE-2] Planet-Zero Forth Bootloader", 10, "Type WORDS to inspect dictionary or BOOT for Ada Ring-0", 10, 0 
	prompt:    db "BOOT> ", 0
	ok_msg:    db " ok", 10, 0 
	err_word:  db " ?", 10, 0 
	boot_msg:  db "Jumping to Ada Ring-0 Kernel (0xA000)...", 10, 0
	line_buf:  times 80 db 0 

		scancode_ascii: 
	    db 0, 0, '1','2','3','4','5','6','7','8','9','0','-','=', 0, 0
	    db 'Q','W','E','R','T','Y','U','I','O','P','[',']', 0, 0
	    db 'A','S','D','F','G','H','J','K','L',';', 39, 96, 0, 92
	    db 'Z','X','C','V','B','N','M',',','.','/', 0,'*', 0,' '

	    scancode_ascii_shift: 
	    	db 0, 0, '!','@','#','$','%','^','&','*','(',')','_','+', 0, 0
	    	db 'Q','W','E','R','T','Y','U','I','O','P','{','}', 0, 0
	    	db 'A','S','D','F','G','H','J','K','L',':','"', '~', 0, '|'
	    	db 'Z','X','C','V','B','N','M','<','>','?', 0,'*', 0,' '
times 4096 - ($ - $$) db 0 
