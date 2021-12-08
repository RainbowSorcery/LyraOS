; 基址设置为7c00
org 0x7c00

; loader起始地址
BaseOfLoader equ 0x1000
OffsetOfLoader equ 0x00

BaseOfStack equ 0x7c00

; 数据分区起始扇区 到数据分区 需要跳过一个MBR 两个FAT 更目录分区 共19个扇区 因为FAT中 前两个FAT项是保留的 并没有在根目录区中存储数据 所以要 - 2 共17个扇区
SectorBalance equ 17

SectorNumOfFat1Start equ 1 ; 紧哎着引导扇区 引导扇区为0 FAT1 扇区为1
RootDirSectors equ 14 ; 根目录所占扇区数  根目录可容纳224个目录每个目录占32个字节 共7136个字节 每个扇区521字节 7136/512 = 14个扇区

SectorNumOfRootDirStart equ 19 ; 根目录起始扇区 引导扇区占一个扇区 FAT各占9个扇区 根目录扇区为19

; 数据区位置: 引导区占一个扇区 FAT各占9个扇区 数据区14个 因为前两个FAT表项系统保留 然后在减去两个系统保留簇可以找到文件数据区

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
	; ax存储待读磁盘起始扇区
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
	jz Lable_FileName_Found
	dec cx
	; 读取一个字节数据放入ax中 SI + 1
	lodsb
	mov bp, si
	; 将文件名称与之前读取的缓冲区对比 若两者相等 跳转到Label_Go_On中进行下个字符的对比 若全部匹配 跳转到Lable_fileName_Found方法中
	cmp al, byte [es:di]
	jz Label_Go_On
	; 如果有字段不匹配 跳转至 Label_Different 中
	jmp Lable_Different

Label_Go_On:
	; di - 1 匹配下一个字符
	inc di
	jmp Label_Cmp_FileName

Lable_Different:
	; di 因为上面匹配字符串的时候已经修改过了 所以 需要复位 0ffe0h = 1111111111100000 文件名为11个字节 所以只要复位前十一位即可
	and di, 0x0ffe0
	; 一条目录项占32个字节 20h = 32 指向下一个目录项	
	add di, 20h
	mov si, LoaderFileName
	; 一直找不到文件的原因: 找不到文件直接跳转到Begin中 然后重新初始化 di 一直循环就一直找不到
	jmp Lable_Search_For_LoaderBin

Label_Goto_Next_Sector_In_Root_Dir: 
	; 扇区 + 1 为读取下个扇区做准备
	add word [SectorNo], 1
	jmp Label_Search_In_Root_Dir_Begin

Lable_FileName_Found:
	mov ax, RootDirSectors
	; and 打成add 复位di指向行第一个
	and di, 0ffe0h
	; 1a为文件首簇偏移 偏移 + 段地址找到文件首簇
	add di, 01ah
	; cx保存文件首簇
	mov cx, word [es:di]
	push cx
	; 根目录所占扇区 + 一个mbr + 2个FAT + FAT数据项偏移 - 2 因为前两个FAT数据项系统保留 并没有存储数据
	add cx, ax
	add cx, SectorBalance
	; 设置loader加载地址以及偏移
	mov ax, BaseOfLoader
	mov es, ax
	mov bx, OffsetOfLoader
	mov ax, cx

Label_Go_on_loading_File:
	; 每读取一个扇区 打印输出一次
	push ax
	push bx
	mov ah, 0eh
	mov al, '*'
	mov bl, 0fh
	int 10h
	pop bx
	pop ax

	; 读取的扇区不对 导致死循环
	mov cl, 1
	
	call Func_ReadOneSector
	pop ax
	; 获取下个FAT项
	call Func_GetFATEntity
	; 如果下一个FAT项为0xfff表示到文件末尾了
	cmp ax, 0xfff
	; 跳转至loader内存地址
	jz Lable_File_Loaded
	push ax
	; 和之前一样根目录所占扇区 + 一个mbr + 2个FAT + FAT数据项偏移 - 2 计算文件簇的扇区
	mov dx, RootDirSectors
	add ax, dx
	add ax, SectorBalance
	add bx, [BPB_BytesPerSector]
	; 继续读取下一个扇区
	jmp Label_Go_on_loading_File

Lable_File_Loaded:
	; 跳转至 boot内存
	jmp BaseOfLoader:OffsetOfLoader

; ================= 获取FAT 实体对象 ==========
; 因为每12bit保存一个FAT项 拼接FAT簇时 只要将地址为偶数8个bit和地址为奇数的四个bit拼接 然后甚于四个bit和下一个地址为偶数的拼接 依次
Func_GetFATEntity: 
	; 保存现场
	push es
	push bx
	push ax
	; 初始化ES
	mov ax, 00
	mov es, ax
	pop ax
	; 初始化 Odd
	mov byte [Odd], 0
	; ax * 3 / 2 也就是 * 1.5 根据是否有余数来判断fat项在偶数地址还是在奇数地址 根据地址的不同 进行不同的处理 余数为FAT项如FAT[0] FAT[1]中的0和1 商为FAT项偏移 相当于 + 1.5 找到下个目标簇的偏移 之后根据奇偶位进行计算下一簇
	mov bx, 3
	; 无符号乘法 相乘的两个数 要么是8位 要么是16位 ax * bx 存储到ax中
	; ax = ax * 3 相当于FAT表项 * 3 
	mul bx
	; ax / bx 商ax 余数 dx 然后 / 2
	; 忘了设置寄存器 / 2  
	mov bx, 2
	div bx
	; 判断是否有余数 若有余数读0.5个字节 若无余数读1个字节
	cmp dx, 0
	jz Label_Even
	mov byte [Odd], 1
	
Label_Even:
	xor dx, dx
	mov bx, [BPB_BytesPerSector]
	; 在将fat项 / 512 计算出要读取的fat扇区的分区 余数为在fat项中的便宜
	div bx
	push dx
	; 放入内存地址
	mov bx, 8000h
	; 将fat扇区的分区 + 1个boot分区计算出要读取的扇区
	add ax, SectorNumOfFat1Start
	; 因为1.5个字节存储两个扇区文件 可能跨扇区存储 所以要读取两个扇区
	mov cl, 2
	call Func_ReadOneSector

	pop dx
	; bx + dx fat项偏移 + 读取的扇区地址
	add bx, dx
	; 获取fat项簇
	mov ax, [es:bx]
	cmp byte[Odd], 1
	; 如果是奇数地址 右移四位取低12bit
	jnz Label_Event_2
	; 之后为了解决错位的问题 右移四位 
	shr ax, 4

Label_Event_2:
	; 如果是偶数地址 取高12bit
	and ax, 0fffh
	pop bx
	pop es
	ret


; ================== 文件未找到 ================	
; 似乎是输出语句编写错误导致一直跳转不过来
Label_No_LoaderBin: 
	mov ax, 1301h
	mov bx, 008ch
	mov cx, 21
	mov dx, 0100h
	push ax
	mov ax, ds
	mov es, ax
	pop ax
	mov bp, NoLoaderMessage
	int 10h
	jmp $

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
	and dh, 1
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
; 是按ASCILL码表输出数字

;=======        tmp variable

; 未扫描目录数
RootDirSizeForLoop      dw      RootDirSectors
SectorNo                dw      0
Odd                     db      0
RowNumber dw  2

;=======        display messages

NoLoaderMessage:        db      "ERROR:No LOADER Found"
LoaderFileName:         db      "LOADER  BIN",0
StartBootMessage: db "Hello lyra"

	; 510 - (当前指令地址 - 节首地址)
 	times 510 - ($ - $$) db 0
	dw 0xaa55
