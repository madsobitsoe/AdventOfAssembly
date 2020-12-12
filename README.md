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

### Part2 tiny
Use handcrafted (i.e. copy/pasted) elf-64 header and binary output from nasm to
avoid overhead and useless cruft.
Makes the binary become 475 bytes instead of 5544 bytes (in the stripped version).


## Day 2
Day 2 was much harder than day one (in assembly, without libc).
The challenge: https://adventofcode.com/2020/day/2


I could reuse a few pieces of code from day1.
I decided to write proper procedures, to make it easier to reuse in the following days. 
The code now uses `call` and `ret` all over the place, so stack manipulation becomes a bit harder. 
Overall it makes the program much easier to read (and write and maintain!). 
the code in the `_start` label is almost human readable. Wonderful!

The biggest new challenges (as opposed to day 1): 
- The input data is 20k bytes. This needs to be read into memory, not just the stack.
- The input data needs to be parsed, so the pieces of it can be used.
A line in the input data is of the format:

`[0-9]-[0-9] [a-z]: [a-z]+\n`
or
`N-M C: P+`
where
- N and M are integers  
- C is a char  
- P+ is a password, i.e. one or more chars.  

For reading in the data, I:
- use open to get a file-descriptor (duh)
- use fstat to find the filesize
- use mmap to map the file in memory and get a pointer to it

Mapping memory also means unmapping memory when I'm done using it - (and in case of errors). 
The error-handling is not at the state where it should be, but in some cases it works.
The code has been designed towards and only been tested with the given data from the challenge. I didn't spend time making testdata that would cause errors.

When the data is read, I need to parse it.  
I parse it line by line.
I made a `readUntil` routine to detect the length of the various parts. 
The return value is used for actual "parsing".
Integers are converted using a routine based on the conversion from day 1 - but now storing results in memory and having an actual API.
Strings are not converted - the length and address of them is stored in the struct instead. No need for copying if I know where they begin and end.
While parsing a line, the result of parsing is written to a 12 byte struct in the .bss section.
After parsing a line, I validate it.
The validation routine uses the 12 byte-struct in the .bss section. Validation is by far the easiest part of day 2 - simple byte comparisons and incrementers.
If a password is valid, I increment a 2-byte area in the .bss-section. After going through the entire file, the

Using the .bss-section means I cannot use the tiny-header from day1 to create an as-small-as-possible executable. (Without writing more of the ELF-header by hand, which I can't do right now).

When the entire file has been read, parsed and validated,
the result, i.e. the number of valid passwords, is converted to an ascii-string and printed.
Lastly, the memory is unmapped and the program exits gracefully with 0.
