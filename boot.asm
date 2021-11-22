org 0x7c00

BaseOfStack equ 0x7c00

jmp short Label_Start
nop
;------------- FAT12 data ---------------
BS_OEMName                  db 'LyraBoot'
BPB_BytesPerSector          dw 512
BPB_SectorsPerCluster       db 1
BPB_ResveredSectors         dw 1 ; The first sector is reserved
BPB_NumOfFATs               db 2 ; The number of FAT tables
BPB_RootDirectoryEntries    dw 224
BPB_TotalSectors            dw 2880
BPB_MediaDescriptor         db 0xF0
BPB_SectorsPerFAT           dw 9 ;每个FAT的扇区数 计算公式: 先将软盘大小所占字节数算出来 1.44 * 1024 * 1024 = 1509949.44 个字节 每个扇区区要512个字节 1509949.44需要2950个扇区来表示 2950个扇区在FAT中2950条数据每条数据12bit也就是1.5k 共需要2000字节来表示 512个字节为一个扇区 共需要9个扇区
BPB_SectorsPerTrack         dw 18
BPB_NumOfHeads              dw 2
BPB_HiddenSectors           dd 0
BPB_TotalSectors32          dd 0
BS_DrvNum                   db 0 ; Driver number of int 13H
BS_Reserved                 db 0
BS_BootSig                  db 029H
BS_VolID                    dd 0
BS_VolLabel                 db 'boot loader'
BS_FileSystem               db 'FAT12   '
;------------- End FAT12 data ---------------




Label_Start:        ; 跳转位置，跳过元数据, boot引导开始

    mov ax, cs              
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, BaseOfStack

;=======    clear screen

    mov ax, 0600h
    mov bx, 0700h
    mov cx, 0
    mov dx, 0184fh
    int 10h

;=======    set focus

    mov ax, 0200h
    mov bx, 0000h
    mov dx, 0000h
    int 10h

;=======    display on screen : Start Booting......

    mov ax, 1301h
    mov bx, 000fh
    mov dx, 0000h
    mov cx, 6
    push    ax
    mov ax, ds
    mov es, ax
    pop ax
    mov bp, StartBootMessage
    int 10h


StartBootMessage:   db  "123456"

times   510 - ($ - $$)  db  0
dw  0xaa55

