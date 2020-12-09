# Use nasm and ld
nasm -f elf64 -o day2part1.o day2part1.asm && ld day2part1.o -o day2part1
# nasm -f bin -o tinyday2part1 tinyday2part1.asm
# chmod +x tinyday2part1
# Run with ./day2part1 data.txt - using the dataset from the advent of code challenge
