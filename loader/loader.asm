org 0x10000

mov ax, cs
mov ds, ax
mov ax, 0x00
mov ss, ax
mov sp, 0x7c00


; =============== 输出 ===================
mov ax, 1301h
mov bx, 000fh
mov dx, 0200h
mov cx, 17
push ax
mov ax, es
mov es, ax
pop ax
mov bp, StartLoaderMessage
int 10h

jmp $

StartLoaderMessage db "Hello Lyra Loader"
