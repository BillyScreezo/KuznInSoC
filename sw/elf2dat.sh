filename=$(echo $(basename $1) | sed -e 's/\.[^.]*$//')
objcopy -I elf32-little -O binary -j .vectors -j .text $1 ${filename}_text.bin
hexdump -ve '"%08x\n"' ${filename}_text.bin > ../${filename}_text.dat


objcopy -I elf32-little -O binary -j .preinit_array -j .init_array -j .fini_array -j .sdata -j .sbss\
    -j .rodata -j .shbss -j .data -j .bss -j .stack -j .stab -j .stabstr $1 ${filename}_data.bin
hexdump -ve '"%08x\n"' ${filename}_data.bin > ../${filename}_data.dat


if [ $# -eq 2 ]
    then
        cp ../${filename}_text.dat ../${filename}_data.dat "$2"
fi

