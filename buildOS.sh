#!/bin/bash
IMAGE=output/boot.img

echo "Compiling boot.nasm...."
nasm boot/boot_2.asm -o output/boot.bin

echo "Compiling loader.asm...."
nasm loader/loader.asm -o output/loader.bin

echo "Dumping Boot sector...."
dd if=output/boot.bin of=$IMAGE bs=512 count=1 conv=notrunc

# echo "Installing loader..."
# ./cp.sh
