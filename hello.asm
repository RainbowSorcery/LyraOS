org 0x7c00

mov ax, cs
mov ds, ax
mov es, ax

call Disp

jmp $
Disp: 
	mov ax, BootMsg
	mov bp, ax
	mov cx, 16
	mov ax, 01301h
	mov bx, 000ch
	mov dl, 0
	int 10h
BootMsg: db "Hello Lyra OS!"
times 510 - ($-$$) db 0 ;510个字节后全部使用0来填充
dw 0xaa55
