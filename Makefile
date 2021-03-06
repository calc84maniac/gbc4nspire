NSPIRE_HARDWARE ?= NON_CAS

GCC = nspire-gcc
LD = nspire-ld
GCCFLAGS = -Os -Wall -W -fpie -fno-merge-constants -D $(NSPIRE_HARDWARE)
OBJCOPY := "$(shell which arm-elf-objcopy 2>/dev/null)"
ifeq (${OBJCOPY},"")
	OBJCOPY := arm-none-eabi-objcopy
endif
OBJS = gbc4nspire.o utils.o
vpath %.tns  ../../res/$(NSPIRE_HARDWARE)

all: gbc4nspire.tns

gbc4nspire.o: gbc4nspire.S cpu.S memory.S defines.inc
	$(GCC) $(GCCFLAGS) -c $<
	
utils.o: utils.c defines.h
	$(GCC) $(GCCFLAGS) -c $<
	
gbc4nspire.tns: $(OBJS)
	$(LD) $^ -o $(@:.tns=.elf)
	$(OBJCOPY) -O binary $(@:.tns=.elf) $(@:.tns=.bin)
	MakeTNS $(@:.tns=.bin)
	rm -f $(@:.tns=.bin)
	mkdir -p ../../res/$(NSPIRE_HARDWARE)
	mv $@ ../../res/$(NSPIRE_HARDWARE) 

.PHONY: clean

clean:
	rm -f *.o *.elf
