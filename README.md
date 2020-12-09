# Advent of assembly
Doing advent of code in pure x86-64 assembly without libc.

It's gonna be a long and lonely christmas, without you (libc).

## Day 1
Kindof terrible solution.
### Part 1
- Read filename from command-line argument
- Read file onto stack
- convert file from ascii to ints line by line
- loop O(n^2) to add numbers and find a + b = 2020
- Multiply a and b
- Convert result to ascii with div/mod algorithm
- print result
### Part 2
- Read filename from command-line argument
- Read file onto stack
- convert file from ascii to ints line by line
- loop O(n^3) to add numbers and find a + b + c = 2020
- Multiply a and b and c
- Convert result to ascii with div/mod algorithm
- print result
- exit

## Day 2
Not a solution yet
### Part 1
- Read filename from command-line argument
- mmap hardcoded amount of bytes in data.txt-file
- TODO do SOMETHING SOMETHING to get result
- TODO Convert result to ascii with div/mod algorithm
- TODO print result
- unmap memory
- exit

### Part 2
- Read filename from command-line argument
- mmap hardcoded amount of bytes in data.txt-file
- TODO do SOMETHING SOMETHING to get result
- TODO Convert result to ascii with div/mod algorithm
- TODO print result
- unmap memory
- exit
