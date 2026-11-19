; SPDX-License-Identifier: GPL-2.0-only
BITS 16
ORG 0x7C00

start: 
	cli 
	cld
	xor ax, ax
	mov ds, ax
	mov es, ax
	mov ss, ax 
	mov sp, 0x7C00 
	mov [boot_drive], dl 

	mov ah, 0x08
	mov dl, [boot_drive]     
    xor di, di 
	mov es, di    
	int 0x13
	jc .geom_done
	and cx, 0x003F 
	jz .geom_done 
	mov [spt], cx
	movzx dx, dh
	inc dx
	mov [heads], dx
.geom_done: 

	mov ax, 1
	mov cx, 8 
	mov bx, 0x0800 
	mov es, bx
	call read_sectors

	mov ax, 9
	mov cx, 64
	mov bx, 0x0A00
	mov es, bx
	call read_sectors

	xor ax, ax
	mov es, ax

    in al, 0x92
    and al, 0xFE
    or al, 2
    out 0x92, al

    mov di, 0x1000
    mov cx, 0x3000 / 4
    xor eax, eax
    rep stosd

    mov dword [0x1000], 0x2003
    mov dword [0x2000], 0x3003
    mov dword [0x3000], 0x0083

    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    mov eax, 0x1000
    mov cr3, eax
    mov ecx, 0xC0000080
    rdmsr 
    or eax, 1 << 8 
    wrmsr 

    lgdt [gdt64.ptr] 
    mov eax, cr0
    or eax, (1 << 31) | (1 << 0)
    mov cr0, eax
    jmp gdt64.code:0x8000

read_sectors: 
.next: 
	push ax
	push cx
	xor dx, dx 
	div word [spt]
	inc dl 
	mov cl, dl
	xor dx, dx 
	div word [heads]
	mov ch, al
	mov dh, dl
	mov dl, [boot_drive] 
	mov ax, 0x0201 
	xor bx, bx
	int 0x13
	jc disk_error
	mov ax, es
	add ax, 0x20
	mov es, ax
	pop cx
	pop ax
	inc ax
	loop .next
	ret
disk_error: 
	mov si, err_msg 
.loop: 
	lodsb 
	or al, al 
	jz .halt
	mov ah, 0xE 
	int 0x10 
	jmp .loop
.halt: 
	hlt 
	jmp .halt 

boot_drive: db 0 
spt:        dw 18
heads:      dw 2
err_msg:    db "Disk read failed!", 0 

align 8
gdt64: 
	dq 0 
.code: equ $ - gdt64
	dq (1<<43) | (1<<44) | (1<<47) | (1<<53) 
.data: equ $ - gdt64
	dq (1<<41) | (1<<44) | (1<<47) 
.ptr: 
	dw $ - gdt64 - 1 
	dq gdt64 
	times 510 - ($ - $$) db 0 
dw 0xAA55 
	
