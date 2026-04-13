# Makefile
AS      = riscv64-unknown-elf-as
LD      = riscv64-unknown-elf-ld
OBJCOPY = riscv64-unknown-elf-objcopy

FLAGS   = -march=rv32i -mabi=ilp32

all: main.bin

main.o: main.s
	$(AS) $(FLAGS) -o main.o main.s

main.elf: main.o
	$(LD) -m elf32lriscv -Ttext=0x0000 -o main.elf main.o

main.bin: main.elf
	$(OBJCOPY) -O binary main.elf main.bin

clean:
	rm -f *.o *.elf *.bin
