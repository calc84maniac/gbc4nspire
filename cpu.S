.macro NEXT cycles
	ldrb r0,[gb_pc],#1
	subs gb_cycles,gb_cycles,#\cycles
	ldrgt pc,[sp,r0,lsl #2]
	b cpu_done
.endm

.macro WASTE cycles
	sub gb_cycles,gb_cycles,#\cycles
.endm

.macro READHL
	mov r0,gb_hl,lsr #16
	READMEM
.endm

.macro READMEM
	bl read_mem
.endm

.macro READMEM_16
	bl read_mem_16
.endm

.macro WRITEHL
	mov r0,gb_hl,lsr #16
	WRITEMEM
.endm

.macro WRITEMEM
	bl write_mem
.endm

.macro WRITEMEM_16
	bl write_mem_16
.endm

.macro OP_INC8 reg, byte
	.if \byte < 3
		mov \reg,\reg,ror #8 + \byte*8
	.endif
	
	and gb_f,gb_f,#flags_c
	
	.if \byte == 4
		adds \reg,\reg,#1 << 24
	.else
		add \reg,\reg,#1 << 24
		tst \reg,#0xFF << 24
	.endif
	orreq gb_f,gb_f,#flags_z
	
	tst \reg,#0x0F << 24
	orreq gb_f,gb_f,#flags_h
	
	.if \byte < 3
		mov \reg,\reg,ror #24 - \byte*8
	.endif
.endm

.macro OP_DEC8 reg, byte
	.if \byte < 3
		mov \reg,\reg,ror #8 + \byte*8
	.endif
	
	orr gb_f,gb_f,#flags_n | flags_h | flags_z
	
	tst \reg,#0x0F << 24
	bicne gb_f,gb_f,#flags_h
	
	.if \byte == 4
		subs \reg,\reg,#1 << 24
	.else
		sub \reg,\reg,#1 << 24
		tst \reg,#0xFF << 24
	.endif
	bicne gb_f,gb_f,#flags_z
	
	.if \byte < 3
		mov \reg,\reg,ror #24 - \byte*8
	.endif
.endm

.macro OP_INC16 reg, word
	.if \word > 0
		add \reg,\reg,#1 << 16
	.else
		mov \reg,\reg,ror #16
		add \reg,\reg,#1 << 16
		mov \reg,\reg,ror #16
	.endif
.endm

.macro OP_DEC16 reg, word
	.if \word > 0
		sub \reg,\reg,#1 << 16
	.else
		mov \reg,\reg,ror #16
		sub \reg,\reg,#1 << 16
		mov \reg,\reg,ror #16
	.endif
.endm

.macro OP_LD8IMM reg, byte
	ldrb r0,[gb_pc],#1
	.if \byte == 4
		mov \reg,r0,lsl #24
	.else
		bic \reg,\reg,#0xFF << (\byte*8)
		orr \reg,\reg,r0,lsl #\byte*8
	.endif
.endm
	
.macro OP_ADD8 reg, byte
	.if \byte == 4
		mov gb_f,#0
		movs gb_a,gb_a,lsl #1
		orreq gb_f,gb_f,#flags_z
		orrcs gb_f,gb_f,#flags_c
		tst gb_a,#1 << 28
		orrne gb_f,gb_f,#flags_h
	.else
		.if \byte > 0
			mov r0,\reg,lsr #\byte*8
			OP_ADD8 r0, 0
		.else
			mov gb_f,#0
			mov r1,gb_a,lsl #4
			adds gb_a,gb_a,\reg,lsl #24
			orreq gb_f,gb_f,#flags_z
			orrcs gb_f,gb_f,#flags_c
			cmn r1,\reg,lsl #28
			orrcs gb_f,gb_f,#flags_h
		.endif
	.endif
.endm

.macro OP_SUB8 reg, byte
	.if \byte == 4
		mov gb_a,#0
		mov gb_f,#flags_n | flags_z
	.else
		.if \byte > 0
			mov r0,\reg,lsr #\byte*8
			OP_SUB8 r0, 0
		.else
			mov gb_f,#flags_n
			mov r1,gb_a,lsl #4
			subs gb_a,gb_a,\reg,lsl #24
			orreq gb_f,gb_f,#flags_z
			orrcc gb_f,gb_f,#flags_c
			cmp r1,\reg,lsl #28
			orrcc gb_f,gb_f,#flags_h
		.endif
	.endif
.endm

.macro OP_ADC8 reg, byte
	.if \byte == 4
		tst gb_f,#flags_c
		orrne gb_a,gb_a,#1 << 23
		mov gb_f,#0
		movs gb_a,gb_a,lsl #1
		orreq gb_f,gb_f,#flags_z
		orrcs gb_f,gb_f,#flags_c
		tst gb_a,#1 << 28
		orrne gb_f,gb_f,#flags_h
	.else
		#Get carry flag
		tst gb_f,gb_f,lsl #4
		.if \byte > 0
			#Shift A to LSB
			mov gb_a,gb_a,lsr #24
			#Add with carry to the register, using XOR logic to check for carries
			eor r1,gb_a,\reg,lsr #\byte*8
			adc gb_a,gb_a,\reg,lsr #\byte*8
			eor r1,r1,gb_a
		.else
			#Special case if register is in LSB
			eor r1,\reg,gb_a,lsr #24
			adc gb_a,\reg,gb_a,lsr #24
			eor r1,r1,gb_a
		.endif
		#Shift A into MSB again, check for Z flag
		movs gb_a,gb_a,lsl #24
		movne gb_f,#0
		moveq gb_f,#flags_z
		#Check for carry and half-carry
		tst r1,#0x100
		orrne gb_f,gb_f,#flags_c
		tst r1,#0x10
		orrne gb_f,gb_f,#flags_h
	.endif
.endm

.macro OP_SBC8 reg, byte
	.if \byte == 4
		tst gb_f,#flags_c
		moveq gb_a,#0x00 << 24
		movne gb_a,#0xFF << 24
		moveq gb_f,#flags_n | flags_z
		movne gb_f,#flags_n | flags_c | flags_h
	.else
		#Get carry flag
		tst gb_f,gb_f,lsl #4
		.if \byte > 0
			#Shift A to LSB
			mov gb_a,gb_a,lsr #24
			#Add with carry to the register, using XOR logic to check for carries
			eor r1,gb_a,\reg,lsr #\byte*8
			adc gb_a,gb_a,\reg,lsr #\byte*8
			eor r1,r1,gb_a
		.else
			#Special case if register is in LSB
			eor r1,\reg,gb_a,lsr #24
			adc gb_a,\reg,gb_a,lsr #24
			eor r1,r1,gb_a
		.endif
		#Shift A into MSB again, check for Z flag
		movs gb_a,gb_a,lsl #24
		movne gb_f,#0
		moveq gb_f,#flags_z
		#Check for carry and half-carry
		tst r1,#0x100
		orrne gb_f,gb_f,#flags_c
		tst r1,#0x10
		orrne gb_f,gb_f,#flags_h
	.endif
.endm

.macro OP_AND reg, byte
	.if \byte == 4
		teq gb_a,#0
	.else
		ands gb_a,gb_a,\reg,lsl #24 - \byte*8
	.endif
	movne gb_f,#flags_h
	moveq gb_f,#flags_h | flags_z
.endm

.macro OP_XOR reg, byte
	.if \byte == 4
		mov gb_a,#0
		mov gb_f,#flags_z
	.else
		eor gb_a,gb_a,\reg,lsl #24 - \byte*8
		ands gb_a,gb_a,#0xFF << 24
		movne gb_f,#0
		moveq gb_f,#flags_z
	.endif
.endm
	
.macro OP_XORL reg, byte
	eors gb_a,gb_a,\reg,lsl #24 - \byte*8
	movne gb_f,#0
	moveq gb_f,#flags_z
.endm
	
.macro OP_OR reg, byte
	.if \byte == 4
		teq gb_a,#0
	.else
		orr gb_a,gb_a,\reg,lsl #24 - \byte*8
		ands gb_a,gb_a,#0xFF << 24
	.endif
	movne gb_f,#0
	moveq gb_f,#flags_z
.endm
	
.macro OP_ORL reg, byte
	orrs gb_a,gb_a,\reg,lsl #24 - \byte*8
	movne gb_f,#0
	moveq gb_f,#flags_z
.endm
	
.macro OP_CP8 reg, byte
	.if \byte == 4
		mov gb_f,#flags_n | flags_z
	.else
		.if \byte > 0
			mov r0,\reg,lsr #\byte*8
			OP_SUB8 r0, 0
		.else
			mov gb_f,#flags_n
			mov r1,gb_a,lsl #4
			cmp gb_a,\reg,lsl #24
			orreq gb_f,gb_f,#flags_z
			orrcc gb_f,gb_f,#flags_c
			cmp r1,\reg,lsl #28
			orrcc gb_f,gb_f,#flags_h
		.endif
	.endif
.endm
	
read_mem:
	@Placeholder yay!
	bx lr
	
read_mem_16:
	@Placeholder yay!
	bx lr
	
write_mem:
	@Placeholder yay!
	bx lr
	
write_mem_16:
	@Placeholder yay!
	bx lr
	
cpu_done:
	sub gb_pc,#1
	bx lr

opcode_00: @NOP
	NEXT 4
	
opcode_01: @LD BC,mn
	ldrb r0,[gb_pc],#1
	ldrb r1,[gb_pc],#1
	orr gb_bcde,r0,gb_bcde,lsl #16
	orr gb_bcde,gb_bcde,r1,lsl #8
	mov gb_bcde,gb_bcde,ror #16
	NEXT 12
	
opcode_02: @LD (BC),A
	mov r0,gb_bcde,lsr #16
	mov r1,gb_a,lsr #24
	WRITEMEM
	NEXT 8
	
opcode_03: @INC BC
	OP_INC16 gb_bcde, word_bc
	NEXT 8
	
opcode_04: @INC B
	OP_INC8 gb_bcde, byte_b
	NEXT 4
	
opcode_05: @DEC B
	OP_DEC8 gb_bcde, byte_b
	NEXT 4
	
opcode_06: @LD B,n
	OP_LD8IMM gb_bcde, byte_b
	NEXT 8
	
opcode_07: @RLCA
	movs gb_a,gb_a,lsl #1
	orrcs gb_a,gb_a,#1 << 24
	movcc gb_f,#0
	movcs gb_f,#flags_c
	NEXT 4
	
opcode_08: @LD (mn),SP
	ldrb r0,[gb_pc],#1
	ldrb r2,[gb_pc],#1
	mov r1,gb_sp,lsr #16
	orr r0,r0,r2,lsl #8
	WRITEMEM_16
	NEXT 20
	
opcode_09: @ADD HL,BC
	and gb_f,gb_f,#flags_z
	mov r0,gb_bcde,lsr #16
	mov r1,gb_hl,lsl #4
	adds gb_hl,gb_hl,r0,lsl #16
	orrcs gb_f,gb_f,#flags_c
	cmn r1,r0,lsl #20
	orrcs gb_f,gb_f,#flags_h
	NEXT 8
	
opcode_0A: @LD A,(BC)
	mov r0,gb_bcde,lsr #16
	READMEM
	mov gb_a,r0,lsl #24
	NEXT 8
	
opcode_0B: @DEC BC
	OP_DEC16 gb_bcde, word_bc
	NEXT 8
	
opcode_0C: @INC C
	OP_INC8 gb_bcde, byte_c
	NEXT 4
	
opcode_0D: @DEC C
	OP_DEC8 gb_bcde, byte_c
	NEXT 4
	
opcode_0E: @LD C,n
	OP_LD8IMM gb_bcde, byte_c
	NEXT 8
	
opcode_0F: @RRCA
	movs gb_a,gb_a,lsr #25
	orrcs gb_a,gb_a,#1 << 7
	movcc gb_f,#0
	movcs gb_f,#flags_c
	mov gb_a,gb_a,lsl #24
	NEXT 4
	
opcode_10: @STOP
	add gb_pc,gb_pc,#1
	NEXT 8
	
opcode_11: @LD DE,mn
	ldrb r0,[gb_pc],#1
	ldrb r1,[gb_pc],#1
	mov gb_bcde,gb_bcde,lsr #16
	orr gb_bcde,gb_bcde,r0,lsl #16
	orr gb_bcde,gb_bcde,r1,lsl #24
	mov gb_bcde,gb_bcde,ror #16
	NEXT 12
	
opcode_12: @LD (DE),A
	mov r0,gb_bcde,lsl #16
	mov r0,r0,lsr #16
	mov r1,gb_a,lsr #24
	WRITEMEM
	NEXT 8
	
opcode_13: @INC DE
	OP_INC16 gb_bcde, word_de
	NEXT 8
	
opcode_14: @INC D
	OP_INC8 gb_bcde, byte_d
	NEXT 4
	
opcode_15: @DEC D
	OP_DEC8 gb_bcde, byte_d
	NEXT 4
	
opcode_16: @LD D,n
	OP_LD8IMM gb_bcde, byte_d
	NEXT 8
	
opcode_17: @RLA
	tst gb_f,#flags_c
	orrne gb_a,gb_a,#1 << 23
	movs gb_a,gb_a,lsl #1
	movcc gb_f,#0
	movcs gb_f,#flags_c
	NEXT 4
	
opcode_18: @JR d
	ldrsb r0,[gb_pc],#1
	add gb_pc,gb_pc,r0
	NEXT 12
	
opcode_19: @ADD HL,DE
	and gb_f,gb_f,#flags_z
	mov r0,gb_hl,lsl #4
	adds gb_hl,gb_hl,gb_bcde,lsl #16
	orrcs gb_f,gb_f,#flags_c
	cmn r0,gb_bcde,lsl #20
	orrcs gb_f,gb_f,#flags_h
	NEXT 8
	
opcode_1A: @LD A,(DE)
	mov r0,gb_bcde,lsl #16
	mov r0,r0,lsr #16
	READMEM
	mov gb_a,r0,lsl #24
	NEXT 8
	
opcode_1B: @DEC DE
	OP_DEC16 gb_bcde, word_de
	NEXT 8
	
opcode_1C: @INC E
	OP_INC8 gb_bcde, byte_e
	NEXT 4
	
opcode_1D: @DEC E
	OP_DEC8 gb_bcde, byte_e
	NEXT 4
	
opcode_1E: @LD E,n
	OP_LD8IMM gb_bcde, byte_e
	NEXT 8
	
opcode_1F: @RRA
	@Get carry flag
	tst gb_f,gb_f,lsl #4
	mov gb_a,gb_a,rrx
	tst gb_a,#1 << 23
	bic gb_a,gb_a,#1 << 23
	moveq gb_f,#0
	movne gb_f,#flags_c
	NEXT 4
	
opcode_20: @JR NZ,d
	tst gb_f,#flags_z
	beq opcode_18
	add gb_pc,gb_pc,#1
	NEXT 8
	
opcode_21: @LD HL,mn
	ldrb r0,[gb_pc],#1
	ldrb r1,[gb_pc],#1
	mov gb_hl,r0,lsl #16
	orr gb_hl,gb_hl,r1,lsl #24
	NEXT 12
	
opcode_22: @LDI (HL),A
	mov r1,gb_a,lsr #24
	WRITEHL
	@Optimization! Flow into INC HL
	
opcode_23: @INC HL
	OP_INC16 gb_hl, word_hl
	NEXT 8
	
opcode_24: @INC H
	OP_INC8 gb_hl, byte_h
	NEXT 4
	
opcode_25: @DEC H
	OP_DEC8 gb_hl, byte_h
	NEXT 4
	
opcode_26: @LD H,n
	OP_LD8IMM gb_hl, byte_h
	NEXT 8
	
opcode_27: @DAA
	mov r0,#0
	mov r1,#0x9FFFFFFF
	
	tst gb_f,#flags_h @C is reset after this by the calculation of immediate value
	cmpeq r1,gb_a,lsl #4
	addlo r0,r0,#0x06 << 23
	
	tst gb_f,#flags_c @C is reset after this, too
	cmpeq r1,gb_a
	addlo r0,r0,#0x60 << 23
	
	#Reset Z and H flags
	bic gb_f,gb_f,#flags_z | flags_h
	
	@Test N flag, and add if 0 or subtract if 1. Note that the arithmetic is done shifted right by 1 for efficient carry flag detection.
	tst gb_f,#flags_n
	addeq gb_a,r0,gb_a,lsr #1
	rsbne gb_a,r0,gb_a,lsr #1
	@Shift left by 1 and detect the carry/zero
	movs gb_a,gb_a,lsl #1
	@Carry flag is "sticky" in DAA operation (can become set, but not reset)
	orrcs gb_f,gb_f,#flags_c
	@Set Z flag if result was zero
	orreq gb_f,gb_f,#flags_z
	
	NEXT 4
	
opcode_28: @JR Z,d
	tst gb_f,#flags_z
	beq opcode_18
	add gb_pc,gb_pc,#1
	NEXT 8
	
opcode_29: @ADD HL,HL
	and gb_f,gb_f,#flags_z
	movs gb_hl,gb_hl,lsl #1
	orrcs gb_f,gb_f,#flags_c
	tst gb_hl,#1 << 28
	orrne gb_f,gb_f,#flags_h
	NEXT 8
	
opcode_2A: @LDI A,(HL)
	READHL
	mov gb_a,r0,lsl #24
	OP_INC16 gb_hl, word_hl
	NEXT 8
	
opcode_2B: @DEC HL
	OP_DEC16 gb_hl, word_hl
	NEXT 8
	
opcode_2C: @INC L
	OP_INC8 gb_hl, byte_l
	NEXT 4
	
opcode_2D: @DEC L
	OP_DEC8 gb_hl, byte_l
	NEXT 4
	
opcode_2E: @LD L,n
	OP_LD8IMM gb_hl, byte_l
	NEXT 8
	
opcode_2F: @CPL
	eor gb_a,gb_a,#0xFF << 24
	orr gb_f,gb_f,#flags_h | flags_n
	NEXT 4
	
opcode_30: @JR NC,d
	tst gb_f,#flags_c
	beq opcode_18
	add gb_pc,gb_pc,#1
	NEXT 8
	
opcode_31: @LD SP,mn
	ldrb r0,[gb_pc],#1
	ldrb r1,[gb_pc],#1
	mov gb_sp,r0,lsl #16
	orr gb_sp,gb_sp,r1,lsl #24
	NEXT 12
	
opcode_32: @LDD (HL),A
	mov r1,gb_a,lsr #24
	WRITEHL
	OP_DEC16 gb_hl, word_hl
	NEXT 8
	
opcode_33: @INC SP
	OP_INC16 gb_sp, word_sp
	NEXT 8
	
opcode_34: @INC (HL)
	READHL
	mov r0,r0,lsl #24
	OP_INC8 r0, byte_a
	mov r1,r0,lsr #24
	WRITEHL
	NEXT 12
	
opcode_35: @DEC (HL)
	READHL
	mov r0,r0,lsl #24
	OP_DEC8 r0, byte_a
	mov r1,r0,lsr #24
	WRITEHL
	NEXT 12
	
opcode_36: @LD (HL),n
	ldrb r1,[gb_pc],#1
	WRITEHL
	NEXT 12
	
opcode_37: @SCF
	and gb_f,gb_f,#flags_z
	orr gb_f,gb_f,#flags_c
	NEXT 4
	
opcode_38: @JR C,d
	tst gb_f,#flags_c
	beq opcode_18
	add gb_pc,gb_pc,#1
	NEXT 8
	
opcode_39: @ADD HL,SP
	and gb_f,gb_f,#flags_z
	mov r0,gb_hl,lsl #4
	adds gb_hl,gb_hl,gb_sp
	orrcs gb_f,gb_f,#flags_c
	cmn r0,gb_sp,lsl #4
	orrcs gb_f,gb_f,#flags_h
	NEXT 8
	
opcode_3A: @LDD A,(HL)
	READHL
	mov gb_a,r0,lsl #24
	OP_DEC16 gb_hl, word_hl
	NEXT 8
	
opcode_3B: @DEC SP
	OP_DEC16 gb_sp, word_sp
	NEXT 8
	
opcode_3C: @INC A
	OP_INC8 gb_a, byte_a
	NEXT 4
	
opcode_3D: @DEC A
	OP_DEC8 gb_a, byte_a
	NEXT 4
	
opcode_3E: @LD A,n
	OP_LD8IMM gb_a, byte_a
	NEXT 8
	
opcode_3F: @CCF
	eor gb_f,gb_f,#flags_c
	bic gb_f,gb_f,#flags_h | flags_n
	NEXT 4
	
opcode_40: @LD B,B
	NEXT 4
	
opcode_41: @LD B,C
	bic gb_bcde,gb_bcde,#0xFF << 24
	and r0,gb_bcde,#0xFF << 16
	orr gb_bcde,gb_bcde,r0,lsl #8
	NEXT 4
	
opcode_42: @LD B,D
	bic gb_bcde,gb_bcde,#0xFF << 24
	and r0,gb_bcde,#0xFF << 8
	orr gb_bcde,gb_bcde,r0,lsl #16
	NEXT 4
	
opcode_43: @LD B,E
	bic gb_bcde,gb_bcde,#0xFF << 24
	orr gb_bcde,gb_bcde,gb_bcde,lsl #24
	NEXT 4
	
opcode_44: @LD B,H
	bic gb_bcde,gb_bcde,#0xFF << 24
	and r0,gb_hl,#0xFF << 24
	orr gb_bcde,gb_bcde,r0
	NEXT 4
	
opcode_45: @LD B,L
	bic gb_bcde,gb_bcde,#0xFF << 24
	orr gb_bcde,gb_bcde,gb_hl,lsl #8
	NEXT 4
	
opcode_46: @LD B,(HL)
	READHL
	bic gb_bcde,gb_bcde,#0xFF << 24
	orr gb_bcde,gb_bcde,r0,lsl #24
	NEXT 8
	
opcode_47: @LD B,A
	bic gb_bcde,gb_bcde,#0xFF << 24
	orr gb_bcde,gb_bcde,gb_a
	NEXT 4
	
opcode_48: @LD C,B
	bic gb_bcde,gb_bcde,#0xFF << 16
	and r0,gb_bcde,#0xFF << 24
	orr gb_bcde,gb_bcde,r0,lsr #8
	NEXT 4
	
opcode_49: @LD C,C
	NEXT 4
	
opcode_4A: @LD C,D
	bic gb_bcde,gb_bcde,#0xFF << 16
	and r0,gb_bcde,#0xFF << 8
	orr gb_bcde,gb_bcde,r0,lsl #8
	NEXT 4
	
opcode_4B: @LD C,E
	bic gb_bcde,gb_bcde,#0xFF << 16
	and r0,gb_bcde,#0xFF
	orr gb_bcde,gb_bcde,r0,lsl #16
	NEXT 4
	
opcode_4C: @LD C,H
	bic gb_bcde,gb_bcde,#0xFF << 16
	and r0,gb_hl,#0xFF << 24
	orr gb_bcde,gb_bcde,r0,lsr #8
	NEXT 4
	
opcode_4D: @LD C,L
	bic gb_bcde,gb_bcde,#0xFF << 16
	and r0,gb_hl,#0xFF << 16
	orr gb_bcde,gb_bcde,r0
	NEXT 4
	
opcode_4E: @LD C,(HL)
	READHL
	bic gb_bcde,gb_bcde,#0xFF << 16
	orr gb_bcde,gb_bcde,r0,lsl #16
	NEXT 8
	
opcode_4F: @LD C,A
	bic gb_bcde,gb_bcde,#0xFF << 16
	orr gb_bcde,gb_bcde,gb_a,lsr #8
	NEXT 4
	
opcode_50: @LD D,B
	bic gb_bcde,gb_bcde,#0xFF << 8
	and r0,gb_bcde,#0xFF << 24
	orr gb_bcde,gb_bcde,r0,lsr #16
	NEXT 4
	
opcode_51: @LD D,C
	bic gb_bcde,gb_bcde,#0xFF << 8
	and r0,gb_bcde,#0xFF << 16
	orr gb_bcde,gb_bcde,r0,lsr #8
	NEXT 4
	
opcode_52: @LD D,D
	NEXT 4
	
opcode_53: @LD D,E
	bic gb_bcde,gb_bcde,#0xFF << 8
	and r0,gb_bcde,#0xFF
	orr gb_bcde,gb_bcde,r0,lsl #8
	NEXT 4
	
opcode_54: @LD D,H
	bic gb_bcde,gb_bcde,#0xFF << 8
	and r0,gb_hl,#0xFF << 24
	orr gb_bcde,gb_bcde,r0,lsr #16
	NEXT 4
	
opcode_55: @LD D,L
	bic gb_bcde,gb_bcde,#0xFF << 8
	and r0,gb_hl,#0xFF << 16
	orr gb_bcde,gb_bcde,r0,lsr #8
	NEXT 4
	
opcode_56: @LD D,(HL)
	READHL
	bic gb_bcde,gb_bcde,#0xFF << 8
	orr gb_bcde,gb_bcde,r0,lsl #8
	NEXT 8
	
opcode_57: @LD D,A
	bic gb_bcde,gb_bcde,#0xFF << 8
	orr gb_bcde,gb_bcde,gb_a,lsr #16
	NEXT 4
	
opcode_58: @LD E,B
	bic gb_bcde,gb_bcde,#0xFF
	orr gb_bcde,gb_bcde,gb_bcde,lsr #24
	NEXT 4
	
opcode_59: @LD E,C
	bic gb_bcde,gb_bcde,#0xFF
	and r0,gb_bcde,#0xFF << 16
	orr gb_bcde,gb_bcde,r0,lsr #16
	NEXT 4
	
opcode_5A: @LD E,D
	bic gb_bcde,gb_bcde,#0xFF
	and r0,gb_bcde,#0xFF << 8
	orr gb_bcde,gb_bcde,r0,lsr #8
	NEXT 4
	
opcode_5B: @LD E,E
	NEXT 4
	
opcode_5C: @LD E,H
	bic gb_bcde,gb_bcde,#0xFF
	orr gb_bcde,gb_bcde,gb_hl,lsr #24
	NEXT 4
	
opcode_5D: @LD E,L
	bic gb_bcde,gb_bcde,#0xFF
	and r0,gb_hl,#0xFF << 16
	orr gb_bcde,gb_bcde,r0,lsr #16
	NEXT 4
	
opcode_5E: @LD E,(HL)
	READHL
	bic gb_bcde,gb_bcde,#0xFF
	orr gb_bcde,gb_bcde,r0
	NEXT 8
	
opcode_5F: @LD E,A
	bic gb_bcde,gb_bcde,#0xFF
	orr gb_bcde,gb_bcde,gb_a,lsr #24
	NEXT 4
	
opcode_60: @LD H,B
	bic gb_hl,gb_hl,#0xFF << 24
	and r0,gb_bcde,#0xFF << 24
	orr gb_hl,gb_hl,r0
	NEXT 4
	
opcode_61: @LD H,C
	bic gb_hl,gb_hl,#0xFF << 24
	and r0,gb_bcde,#0xFF << 16
	orr gb_hl,gb_hl,r0,lsl #8
	NEXT 4
	
opcode_62: @LD H,D
	bic gb_hl,gb_hl,#0xFF << 24
	and r0,gb_bcde,#0xFF << 8
	orr gb_hl,gb_hl,r0,lsl #16
	NEXT 4
	
opcode_63: @LD H,E
	bic gb_hl,gb_hl,#0xFF << 24
	orr gb_hl,gb_hl,gb_bcde,lsl #24
	NEXT 4
	
opcode_64: @LD H,H
	NEXT 4
	
opcode_65: @LD H,L
	bic gb_hl,gb_hl,#0xFF << 24
	orr gb_hl,gb_hl,gb_hl,lsl #8
	NEXT 4
	
opcode_66: @LD H,(HL)
	READHL
	bic gb_hl,gb_hl,#0xFF << 24
	orr gb_hl,gb_hl,r0,lsl #24
	NEXT 8
	
opcode_67: @LD H,A
	bic gb_hl,gb_hl,#0xFF << 24
	orr gb_hl,gb_hl,gb_a
	NEXT 4
	
opcode_68: @LD L,B
	bic gb_hl,gb_hl,#0xFF << 16
	and r0,gb_bcde,#0xFF << 24
	orr gb_hl,gb_hl,r0,lsr #8
	NEXT 4
	
opcode_69: @LD L,C
	bic gb_hl,gb_hl,#0xFF << 16
	and r0,gb_bcde,#0xFF << 16
	orr gb_hl,gb_hl,r0
	NEXT 4
	
opcode_6A: @LD L,D
	bic gb_hl,gb_hl,#0xFF << 16
	and r0,gb_bcde,#0xFF << 8
	orr gb_hl,gb_hl,r0,lsl #8
	NEXT 4
	
opcode_6B: @LD L,E
	bic gb_hl,gb_hl,#0xFF << 16
	and r0,gb_bcde,#0xFF
	orr gb_hl,gb_hl,r0,lsl #16
	NEXT 4
	
opcode_6C: @LD L,H
	bic gb_hl,gb_hl,#0xFF << 16
	and r0,gb_hl,#0xFF << 24
	orr gb_hl,gb_hl,r0,lsr #8
	NEXT 4
	
opcode_6D: @LD L,L
	NEXT 4
	
opcode_6E: @LD L,(HL)
	READHL
	bic gb_hl,gb_hl,#0xFF << 16
	orr gb_hl,gb_hl,r0,lsl #16
	NEXT 8
	
opcode_6F: @LD L,A
	bic gb_hl,gb_hl,#0xFF << 16
	orr gb_hl,gb_hl,gb_a,lsr #8
	NEXT 4
	
opcode_70: @LD (HL),B
	mov r1,gb_bcde,lsr #24
	WRITEHL
	NEXT 8
	
opcode_71: @LD (HL),C
	mov r1,gb_bcde,lsr #16
	WRITEHL
	NEXT 8
	
opcode_72: @LD (HL),D
	mov r1,gb_bcde,lsr #8
	WRITEHL
	NEXT 8
	
opcode_73: @LD (HL),E
	mov r1,gb_bcde
	WRITEHL
	NEXT 8
	
opcode_74: @LD (HL),H
	mov r1,gb_hl,lsr #24
	WRITEHL
	NEXT 8
	
opcode_75: @LD (HL),L
	mov r1,gb_hl,lsr #16
	WRITEHL
	NEXT 8
	
opcode_76: @HALT
	sub gb_pc,gb_pc,#1
	@Yay, time skipping!
	ands gb_cycles,gb_cycles,#3
	moveq gb_cycles,#4
	NEXT 4
	
opcode_77: @LD (HL),A
	mov r1,gb_a,lsr #24
	WRITEHL
	NEXT 8
	
opcode_78: @LD A,B
	and gb_a,gb_bcde,#0xFF << 24
	NEXT 4
	
opcode_79: @LD A,C
	mov gb_a,gb_bcde,lsl #8
	and gb_a,gb_a,#0xFF << 24
	NEXT 4
	
opcode_7A: @LD A,D
	mov gb_a,gb_bcde,lsl #16
	and gb_a,gb_a,#0xFF << 24
	NEXT 4
	
opcode_7B: @LD A,E
	mov gb_a,gb_bcde,lsl #24
	NEXT 4
	
opcode_7C: @LD A,H
	and gb_a,gb_hl,#0xFF << 24
	NEXT 4
	
opcode_7D: @LD A,L
	mov gb_a,gb_hl,lsl #8
	NEXT 4
	
opcode_7E: @LD A,(HL)
	READHL
	mov gb_a,r0,lsl #24
	NEXT 4
	
opcode_7F: @LD A,A
	NEXT 4
	
opcode_80: @ADD A,B
	OP_ADD8 gb_bcde, byte_b
	NEXT 4
	
opcode_81: @ADD A,C
	OP_ADD8 gb_bcde, byte_c
	NEXT 4
	
opcode_82: @ADD A,D
	OP_ADD8 gb_bcde, byte_d
	NEXT 4
	
opcode_83: @ADD A,E
	OP_ADD8 gb_bcde, byte_e
	NEXT 4
	
opcode_84: @ADD A,H
	OP_ADD8 gb_hl, byte_h
	NEXT 4
	
opcode_85: @ADD A,L
	OP_ADD8 gb_hl, byte_l
	NEXT 4
	
opcode_86: @ADD A,(HL)
	READHL
	OP_ADD8 r0, 0
	NEXT 8
	
opcode_87: @ADD A,A
	OP_ADD8 gb_a, byte_a
	NEXT 4
	
opcode_88: @ADC A,B
	OP_ADC8 gb_bcde, byte_b
	NEXT 4
	
opcode_89: @ADC A,C
	OP_ADC8 gb_bcde, byte_c
	NEXT 4
	
opcode_8A: @ADC A,D
	OP_ADC8 gb_bcde, byte_d
	NEXT 4
	
opcode_8B: @ADC A,E
	OP_ADC8 gb_bcde, byte_e
	NEXT 4
	
opcode_8C: @ADC A,H
	OP_ADC8 gb_hl, byte_h
	NEXT 4
	
opcode_8D: @ADC A,L
	OP_ADC8 gb_hl, byte_l
	NEXT 4
	
opcode_8E: @ADC A,(HL)
	READHL
	OP_ADC8 r0, 0
	NEXT 8
	
opcode_8F: @ADC A,A
	OP_ADC8 gb_a, byte_a
	NEXT 4
	
opcode_90: @SUB B
	OP_SUB8 gb_bcde, byte_b
	NEXT 4
	
opcode_91: @SUB C
	OP_SUB8 gb_bcde, byte_c
	NEXT 4
	
opcode_92: @SUB D
	OP_SUB8 gb_bcde, byte_d
	NEXT 4
	
opcode_93: @SUB E
	OP_SUB8 gb_bcde, byte_e
	NEXT 4
	
opcode_94: @SUB H
	OP_SUB8 gb_hl, byte_h
	NEXT 4
	
opcode_95: @SUB L
	OP_SUB8 gb_hl, byte_l
	NEXT 4
	
opcode_96: @SUB (HL)
	READHL
	OP_SUB8 r0, 0
	NEXT 8
	
opcode_97: @SUB A
	OP_SUB8 gb_a, byte_a
	NEXT 4
	
opcode_98: @SBC A,B
	OP_SBC8 gb_bcde, byte_b
	NEXT 4
	
opcode_99: @SBC A,C
	OP_SBC8 gb_bcde, byte_c
	NEXT 4
	
opcode_9A: @SBC A,D
	OP_SBC8 gb_bcde, byte_d
	NEXT 4
	
opcode_9B: @SBC A,E
	OP_SBC8 gb_bcde, byte_e
	NEXT 4
	
opcode_9C: @SBC A,H
	OP_SBC8 gb_hl, byte_h
	NEXT 4
	
opcode_9D: @SBC A,L
	OP_SBC8 gb_hl, byte_l
	NEXT 4
	
opcode_9E: @SBC A,(HL)
	READHL
	OP_SBC8 r0, 0
	NEXT 8
	
opcode_9F: @SBC A,A
	OP_SBC8 gb_a, byte_a
	NEXT 4
	
opcode_A0: @AND B
	OP_AND gb_bcde, byte_b
	NEXT 4
	
opcode_A1: @AND C
	OP_AND gb_bcde, byte_c
	NEXT 4
	
opcode_A2: @AND D
	OP_AND gb_bcde, byte_d
	NEXT 4
	
opcode_A3: @AND E
	OP_AND gb_bcde, byte_e
	NEXT 4
	
opcode_A4: @AND H
	OP_AND gb_hl, byte_h
	NEXT 4
	
opcode_A5: @AND L
	OP_AND gb_hl, byte_l
	NEXT 4
	
opcode_A6: @AND (HL)
	READHL
	OP_AND r0, 0
	NEXT 8
	
opcode_A7: @AND A
	OP_AND gb_a, byte_a
	NEXT 4
	
opcode_A8: @XOR B
	OP_XOR gb_bcde, byte_b
	NEXT 4
	
opcode_A9: @XOR C
	OP_XOR gb_bcde, byte_c
	NEXT 4
	
opcode_AA: @XOR D
	OP_XOR gb_bcde, byte_d
	NEXT 4
	
opcode_AB: @XOR E
	OP_XORL gb_bcde, byte_e
	NEXT 4
	
opcode_AC: @XOR H
	OP_XOR gb_hl, byte_h
	NEXT 4
	
opcode_AD: @XOR L
	OP_XORL gb_hl, byte_l
	NEXT 4
	
opcode_AE: @XOR (HL)
	READHL
	OP_XORL r0, 0
	NEXT 8
	
opcode_AF: @XOR A
	OP_XOR gb_a, byte_a
	NEXT 4
	
opcode_B0: @OR B
	OP_OR gb_bcde, byte_b
	NEXT 4
	
opcode_B1: @OR C
	OP_OR gb_bcde, byte_c
	NEXT 4
	
opcode_B2: @OR D
	OP_OR gb_bcde, byte_d
	NEXT 4
	
opcode_B3: @OR E
	OP_ORL gb_bcde, byte_e
	NEXT 4
	
opcode_B4: @OR H
	OP_OR gb_hl, byte_h
	NEXT 4
	
opcode_B5: @OR L
	OP_ORL gb_hl, byte_l
	NEXT 4
	
opcode_B6: @OR (HL)
	READHL
	OP_ORL r0, 0
	NEXT 8
	
opcode_B7: @OR A
	OP_OR gb_a, byte_a
	NEXT 4
	
opcode_B8: @CP B
	OP_CP8 gb_bcde, byte_b
	NEXT 4
	
opcode_B9: @CP C
	OP_CP8 gb_bcde, byte_c
	NEXT 4
	
opcode_BA: @CP D
	OP_CP8 gb_bcde, byte_d
	NEXT 4
	
opcode_BB: @CP E
	OP_CP8 gb_bcde, byte_e
	NEXT 4
	
opcode_BC: @CP H
	OP_CP8 gb_hl, byte_h
	NEXT 4
	
opcode_BD: @CP L
	OP_CP8 gb_hl, byte_l
	NEXT 4
	
opcode_BE: @CP (HL)
	READHL
	OP_CP8 r0, 0
	NEXT 8
	
opcode_BF: @CP A
	OP_CP8 gb_a, byte_a
	NEXT 4
	
opcode_C0: @RET NZ
	tst gb_f,#flags_z
	beq opcode_C9
	NEXT 8
	
opcode_C1: @POP BC
	mov r0,gb_sp,lsr #16
	READMEM_16
	orr gb_bcde,r0,gb_bcde,lsl #16
	mov gb_bcde,gb_bcde,ror #16
	add gb_sp,gb_sp,#2 << 16
	NEXT 12
	
opcode_C2: @JP NZ,mn
	tst gb_f,#flags_z
	beq opcode_C3
	add gb_pc,gb_pc,#2
	NEXT 12
	
opcode_C3: @JP mn
	ldrb r1,[gb_pc,#1]
	ldrb r0,[gb_pc],#2
	and gb_pc,r1,#0xF0
	ldr gb_pc,[gb_data,gb_pc,lsr #2]
	orr r0,r0,r1,lsl #8
	str gb_pc,[gb_data,#pc_base]
	add gb_pc,gb_pc,r0
	NEXT 16
	
opcode_C4: @CALL NZ,mn
	tst gb_f,#flags_z
	beq opcode_CD
	add gb_pc,gb_pc,#2
	NEXT 12
	
opcode_C5: @PUSH BC
	sub gb_sp,gb_sp,#2 << 16
	mov r0,gb_sp,lsr #16
	mov r1,gb_bcde,lsr #16
	WRITEMEM_16
	NEXT 16
	
opcode_C6: @ADD A,n
	ldrb r0,[gb_pc],#1
	OP_ADD8 r0, 0
	NEXT 8
	
opcode_C7: @RST 00h
	ldr r1,[gb_data,#pc_base]
	sub gb_sp,gb_sp,#2 << 16
	mov r0,gb_sp,lsr #16
	sub r1,gb_pc,r1
	ldr gb_pc,[gb_data,#mem_map_0000]
	WRITEMEM_16
	NEXT 16
	
opcode_C8: @RET Z
	tst gb_f,#flags_z
	bne opcode_C9
	NEXT 8
	
opcode_C9: @RET
	mov r0,gb_sp,lsr #16
	READMEM_16
	and gb_pc,r0,#0xF000
	ldr gb_pc,[gb_data,gb_pc,lsr #12]
	add gb_sp,gb_sp,#2 << 16
	add gb_pc,gb_pc,r0
	NEXT 12
	
opcode_CA: @JP Z,mn
	tst gb_f,#flags_z
	bne opcode_C3
	add gb_pc,gb_pc,#2
	NEXT 12
	
opcode_CB: @BITWISE INSTRUCTION PREFIX
	ldrb r0,[gb_pc],#1
	ldr r0,[pc,r0,lsl #2]
	add pc,pc,r0
	
opcode_CC: @CALL Z,mn
	tst gb_f,#flags_z
	bne opcode_CD
	add gb_pc,gb_pc,#2
	NEXT 12
	
opcode_CD: @CALL mn
	ldrb r1,[gb_pc,#1]
	ldrb r0,[gb_pc],#2
	and r2,r1,#0xF0
	ldr r2,[gb_data,r2,lsr #2]
	orr r0,r0,r1,lsl #8
	ldr r1,[gb_data,#pc_base]
	str r2,[gb_data,#pc_base]
	sub r1,gb_pc,r1
	add gb_pc,r2,r0
	sub gb_sp,gb_sp,#2 << 16
	mov r0,gb_sp,lsr #16
	WRITEMEM_16
	NEXT 24
	
opcode_CE: @ADC A,n
	ldrb r0,[gb_pc],#1
	OP_ADC8 r0, 0
	NEXT 8
	
opcode_CF: @RST 08h
	ldr r1,[gb_data,#pc_base]
	sub gb_sp,gb_sp,#2 << 16
	mov r0,gb_sp,lsr #16
	sub r1,gb_pc,r1
	ldr gb_pc,[gb_data,#mem_map_0000]
	WRITEMEM_16
	add gb_pc,gb_pc,#0x08
	NEXT 16
	
opcode_D0: @RET NC
	tst gb_f,#flags_c
	beq opcode_C9
	NEXT 8
	
opcode_D1: @POP DE
	mov r0,gb_sp,lsr #16
	READMEM_16
	mov gb_bcde,gb_bcde,lsr #16
	orr gb_bcde,r0,gb_bcde,lsl #16
	add gb_sp,gb_sp,#2 << 16
	NEXT 12
	
opcode_D2: @JP NC,mn
	tst gb_f,#flags_c
	beq opcode_C3
	add gb_pc,gb_pc,#2
	NEXT 12
	
opcode_D3: @INVALID
	sub gb_pc,gb_pc,#1
	NEXT 4
	
opcode_D4: @CALL NC,mn
	tst gb_f,#flags_c
	beq opcode_CD
	add gb_pc,gb_pc,#2
	NEXT 12
	
opcode_D5: @PUSH DE
	sub gb_sp,gb_sp,#2 << 16
	mov r0,gb_sp,lsr #16
	mov r1,gb_bcde
	WRITEMEM_16
	NEXT 16
	
opcode_D6: @SUB n
	ldrb r0,[gb_pc],#1
	OP_SUB8 r0, 0
	NEXT 8
	
opcode_D7: @RST 10h
	ldr r1,[gb_data,#pc_base]
	sub gb_sp,gb_sp,#2 << 16
	mov r0,gb_sp,lsr #16
	sub r1,gb_pc,r1
	ldr gb_pc,[gb_data,#mem_map_0000]
	WRITEMEM_16
	add gb_pc,gb_pc,#0x10
	NEXT 16
	
opcode_D8: @RET C
	tst gb_f,#flags_c
	bne opcode_C9
	NEXT 8
	
opcode_D9: @RETI
	mov r0,#1
	str r0,[gb_data,#IFF]
	b opcode_C9
	
opcode_DA: @JP C,mn
	tst gb_f,#flags_c
	bne opcode_C3
	add gb_pc,gb_pc,#2
	NEXT 12
	
opcode_DB: @INVALID
	sub gb_pc,gb_pc,#1
	NEXT 4
	
opcode_DC: @CALL C,mn
	tst gb_f,#flags_c
	bne opcode_CD
	add gb_pc,gb_pc,#2
	NEXT 12
	
opcode_DD: @INVALID
	sub gb_pc,gb_pc,#1
	NEXT 4
	
opcode_DE: @SBC A,n
	ldrb r0,[gb_pc],#1
	OP_SBC8 r0, 0
	NEXT 8
	
opcode_DF: @RST 18h
	ldr r1,[gb_data,#pc_base]
	sub gb_sp,gb_sp,#2 << 16
	mov r0,gb_sp,lsr #16
	sub r1,gb_pc,r1
	ldr gb_pc,[gb_data,#mem_map_0000]
	WRITEMEM_16
	add gb_pc,gb_pc,#0x18
	NEXT 16
	