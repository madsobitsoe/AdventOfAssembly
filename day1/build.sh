# Use nasm and ld
nasm -f elf64 day1part1.asm && ld day1part1.o -o day1part1
nasm -f elf64 day1part2.asm && ld day1part2.o -o day1part2
nasm -f bin -o tinyday1part2 tinyday1part2.asm
chmod +x tinyday1part2
# Run with ./day1part data.txt - using the dataset from the advent of code challenge
