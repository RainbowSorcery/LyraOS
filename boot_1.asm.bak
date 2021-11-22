; 基址设置为7c00
org 0x7c00

BseOfLoader equ 0x1000
OffsetOfLoader equ 0x00

BaseOfStack equ 0x7c00
StartBootMessage: db "Hello lyra"

SectorNumOfFat1Start equ 1 ; 紧哎着引导扇区 引导扇区为0 FAT1 扇区为1
RootDirSectors equ 14 ; 根目录所占扇区数  根目录可容纳224个目录每个目录占32个字节 共7136个字节 每个扇区521字节 7136/512 = 14个扇区

SectorNumOfRootDirStart equ 19 ; 根目录起始扇区 引导扇区占一个扇区 FAT各占9个扇区 根目录扇区为19


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


; =========== 开始执行boot ==============
Label_Start:
	mov ax, cs
	mov ds, ax
	mov es, ax
	mov sp, BaseOfStack

	mov ax, 0600h
	; bh 高位背景 低位前景 颜色属性: https://www.ic.unicamp.br/~celio/mc404-2004/service_interrupts#attrib
	mov bx, 0f00h
	; 实模式下默认分辨率为25 * 80 18为 25 4f为 80
	mov cx, 0
	mov dx, 0184fh
	int 10h

	mov ax, 0200h
	mov bx, 0000h
	mov dx, 0000h
	int 10h

	mov ax, 1301h
	; bl 设置字体颜色
	mov bx, 000fh
	mov dx, 0000h
	mov cx, 10
	push ax
	mov ax, ds
	mov es, ax
	pop ax
	mov bp, StartBootMessage
	int 10h


	xor ah, ah
	xor dl, dl
	int 13h

; =================== 读取软盘 ====================
Func_ReadOneSector:
	; 保存栈帧
	push bp
	mov bp, sp

	sub esp, 2
	mov byte[bp - 2], cl
	push bx
	; 存储每磁道扇区数
	mov bl, [BPB_SectorsPerTrack]
	; 逻辑扇区 / 每磁道扇区数 余数存储道ah中 商保存道al中
	div bl
	; 磁道内起始扇区是从1开始计算 所以要 + 1
	inc ah
	mov cl, ah
	mov dh, al
	; 右移一位是柱面号
	shr al, 1
	mov ch, al
	; 与运算是磁头号
	add dh, 1
	pop bx
	mov dl, [BS_DrvNum]

Label_Go_On_Reading:
	mov ah, 2
	mov al, byte[bp - 2]
	int 13h
	jc Label_Go_On_Reading
	add esp, 2
	pop bp
	ret

;====================== 搜索 loader.bin ==========================
; 新建一个SectorNo 变量 并将值修改为SectorNumOfRootDirStart
mov word [SectorNo], SectorNumOfRootDirStart
Label_Search_In_Root_Dir_Begin:
	; a  < b cf = 1, zf = 0; a > b cf = 0 zf = 0; a = b zf = 1 cf = 0
	cmp word [RootDirSizeForLoop], 0
	; jz zf = 1 跳转 也就是循环了整个目录还是找不到文件 则继续跳转
	jz Label_No_LoaderBin
	dec word [RootDirSizeForLoop]
	; 初始化AX
	mov ax, 0x00
	; 初始化ES
	mov es, ax
	; 根目录数据所加载的地址位置 详情看实模式地址分配图
	mov bx, 0x8000
	mov ax, [SectorNo]
	; 读取一个扇区
	mov cl, 1
	call Func_ReadOneSector
	mov si, LoaderFileName
	mov di, 0x8000
	; 因为lodsb 会修改DF标志位寄存器 所以要复位
	cld
	; 每个扇区所容纳的目录项个数 一个目录项32个字节 一个扇区512字节 512/32 = 16
	mov dx, 10h

Lable_Search_For_LoaderBin:
	; dx = 0 表示已经到一个文件的末尾 直接扫描下一个文件即可
	cmp dx, 0
	jz Label_Goto_Next_Sector_In_Root_Dir
	dec dx
	; 存储文件名的长度
	mov cx, 11

Label_Cmp_FileName:
	cmp cx, 0
	; jz Lable_FileName_Found
	push ax
	pop ax
	dec cx
	; 读取一个字节数据放入ax中 SI + 1
	lodsb
	; 将文件名称与之前读取的缓冲区对比 若两者相等 跳转到Label_Go_On中进行下个字符的对比 若全部匹配 跳转到Lable_fileName_Found方法中
	cmp al, byte [es:di]
	jz Label_Go_On
	; 如果有字段不匹配 跳转至 Label_Different 中
	jmp Lable_Different

Label_Go_On:
	inc di
	jmp Label_Cmp_FileName

Lable_Different:
	; di 因为上面匹配字符串的时候已经修改过了 所以 需要复位 0ffe0h = 1111111111100000 文件名为11个字节 所以只要复位前十一位即可
	and di, 0x0ffe0
	; 一条目录项占32个字节 20h = 32 指向下一个目录项	
	add di, 20h
	mov si, LoaderFileName
	jmp Label_Search_In_Root_Dir_Begin

Label_Goto_Next_Sector_In_Root_Dir: 
	; 扇区 + 1 为读取下个扇区做准备
	add word [SectorNo], 1
	jmp Label_Search_In_Root_Dir_Begin
	
Label_No_LoaderBin: 
	mov ax, 1301h
	mov cx, 21
	mov dx, 0100h
	push ax
	mov ax, ds
	pop ax
	mov bp, Label_No_LoaderBin
	int 10h
	jmp $

Lable_FileName_Found: 

;=======        tmp variable

; 未扫描目录数
RootDirSizeForLoop      dw      RootDirSectors
SectorNo                dw      0
Odd                     db      0

;=======        display messages

NoLoaderMessage:        db      "ERROR:No LOADER Found"
LoaderFileName:         db      "LOADER  BIN",0

	; 510 - (当前指令地址 - 节首地址)
 	times 510 - ($ - $$) db 0
	dw 0xaa55
