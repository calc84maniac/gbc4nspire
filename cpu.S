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
		tst gb_f,gb_f,lsr #5
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
		tst gb_f,gb_f,lsr #5
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
	tst gb_a,gb_a,lsl #8
	movcc gb_f,#0
	movcs gb_f,#flags_c
	bic gb_a,gb_a,#1 << 24
	mov gb_a,gb_a,rrx
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
	tst gb_f,gb_f,lsr #5
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
	
	tst gb_f,#flags_h << 2,2 @C is reset after this by the calculation of immediate value
	cmpeq r1,gb_a,lsl #4
	addlo r0,r0,#0x06 << 23
	
	tst gb_f,#flags_c << 2,2 @C is reset after this, too
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
	
opcode_E0: @LD ($FF00+n),A
	ldrb r0,[gb_pc],#1
	mov r1,gb_a,lsr #24
	orr r0,r0,#0xFF00
	WRITEMEM
	NEXT 12
	
opcode_E1: @POP HL
	mov r0,gb_sp,lsr #16
	READMEM_16
	mov gb_hl,r0,lsl #16
	add gb_sp,gb_sp,#2 << 16
	NEXT 12
	
opcode_E2: @LD ($FF00+C),A
	mov r0,gb_bcde,lsr #16
	orr r0,r0,#0xFF00
	mov r1,gb_a,lsr #24
	WRITEMEM
	NEXT 8
	
opcode_E3: @INVALID
	sub gb_pc,gb_pc,#1
	NEXT 4
	
opcode_E4: @INVALID
	sub gb_pc,gb_pc,#1
	NEXT 4
	
opcode_E5: @PUSH HL
	sub gb_sp,gb_sp,#2 << 16
	mov r0,gb_sp,lsr #16
	mov r1,gb_hl,lsr #16
	WRITEMEM_16
	NEXT 16
	
opcode_E6: @AND n
	ldrb r0,[gb_pc],#1
	OP_AND r0, 0
	NEXT 8
	
opcode_E7: @RST 20h
	ldr r1,[gb_data,#pc_base]
	sub gb_sp,gb_sp,#2 << 16
	mov r0,gb_sp,lsr #16
	sub r1,gb_pc,r1
	ldr gb_pc,[gb_data,#mem_map_0000]
	WRITEMEM_16
	add gb_pc,gb_pc,#0x20
	NEXT 16
	
opcode_E8: @ADD SP,d
	ldrsb r0,[gb_pc],#1
	mov r1,gb_sp,lsl #8
	mov r2,gb_sp,lsl #12
	mov gb_f,#0
	cmn r1,r0,lsl #24
	orrcs gb_f,gb_f,#flags_c
	cmn r2,r0,lsl #28
	orrcs gb_f,gb_f,#flags_h
	add gb_sp,gb_sp,r0,lsl #16
	NEXT 16
	
opcode_E9: @JP HL
	and r0,gb_hl,#0xF0000000
	ldr r0,[gb_data,r0,lsr #26]
	add gb_pc,r0,gb_hl,lsr #16
	NEXT 4
	
opcode_EA: @LD (mn),A
	ldrb r0,[gb_pc],#1
	ldrb r2,[gb_pc],#1
	mov r1,gb_a,lsr #24
	orr r0,r0,r2,lsl #8
	WRITEMEM
	NEXT 16
	
opcode_EB: @INVALID
	sub gb_pc,gb_pc,#1
	NEXT 4
	
opcode_EC: @INVALID
	sub gb_pc,gb_pc,#1
	NEXT 4
	
opcode_ED: @INVALID
	sub gb_pc,gb_pc,#1
	NEXT 4
	
opcode_EE: @XOR n
	ldrb r0,[gb_pc],#1
	OP_XORL r0, 0
	NEXT 8
	
opcode_EF: @RST 28h
	ldr r1,[gb_data,#pc_base]
	sub gb_sp,gb_sp,#2 << 16
	mov r0,gb_sp,lsr #16
	sub r1,gb_pc,r1
	ldr gb_pc,[gb_data,#mem_map_0000]
	WRITEMEM_16
	add gb_pc,gb_pc,#0x28
	NEXT 16
	
opcode_F0: @LD A,($FF00+n)
	ldrb r0,[gb_pc],#1
	orr r0,r0,#0xFF00
	READMEM
	mov gb_a,r0,lsl #24
	NEXT 12
	
opcode_F1: @POP AF
	mov r0,gb_sp,lsr #16
	READMEM_16
	mov gb_a,r0,lsl #16
	and gb_a,gb_a,#0xFF << 24
	and gb_f,r0,#flags_z | flags_n | flags_h | flags_c
	add gb_sp,gb_sp,#2 << 16
	NEXT 12
	
opcode_F2: @LD A,($FF00+C)
	mov r0,gb_bcde,lsr #16
	orr r0,r0,#0xFF00
	READMEM
	mov gb_a,r0,lsl #24
	NEXT 8
	
opcode_F3: @DI
	mov r0,#0
	str r0,[gb_data,#IFF]
	NEXT 4
	
opcode_F4: @INVALID
	sub gb_pc,gb_pc,#1
	NEXT 4
	
opcode_F5: @PUSH AF
	sub gb_sp,gb_sp,#2 << 16
	mov r0,gb_sp,lsr #16
	orr r1,gb_f,gb_a,lsr #16
	WRITEMEM_16
	NEXT 16
	
opcode_F6: @OR n
	ldrb r0,[gb_pc],#1
	OP_ORL r0, 0
	NEXT 8
	
opcode_F7: @RST 30h
	ldr r1,[gb_data,#pc_base]
	sub gb_sp,gb_sp,#2 << 16
	mov r0,gb_sp,lsr #16
	sub r1,gb_pc,r1
	ldr gb_pc,[gb_data,#mem_map_0000]
	WRITEMEM_16
	add gb_pc,gb_pc,#0x30
	NEXT 16
	
opcode_F8: @LD HL,SP+d
	ldrsb r0,[gb_pc],#1
	mov r1,gb_sp,lsl #8
	mov r2,gb_sp,lsl #12
	mov gb_f,#0
	cmn r1,r0,lsl #24
	orrcs gb_f,gb_f,#flags_c
	cmn r2,r0,lsl #28
	orrcs gb_f,gb_f,#flags_h
	add gb_hl,gb_sp,r0,lsl #16
	NEXT 12
	
opcode_F9: @LD SP,HL
	mov gb_sp,gb_hl
	NEXT 8
	
opcode_FA: @LD A,(mn)
	ldrb r0,[gb_pc],#1
	ldrb r1,[gb_pc],#1
	orr r0,r0,r1,lsl #8
	WRITEMEM
	mov gb_a,r0,lsl #24
	NEXT 16
	
opcode_FB: @EI
	mov r0,#1
	str r0,[gb_data,#IFF]
	NEXT 4
	
opcode_FC: @INVALID
	sub gb_pc,gb_pc,#1
	NEXT 4
	
opcode_FD: @INVALID
	sub gb_pc,gb_pc,#1
	NEXT 4
	
opcode_FE: @CP n
	ldrb r0,[gb_pc],#1
	OP_CP8 r0, 0
	NEXT 8
	
opcode_FF: @RST 38h
	ldr r1,[gb_data,#pc_base]
	sub gb_sp,gb_sp,#2 << 16
	mov r0,gb_sp,lsr #16
	sub r1,gb_pc,r1
	ldr gb_pc,[gb_data,#mem_map_0000]
	WRITEMEM_16
	add gb_pc,gb_pc,#0x38
	NEXT 16

.macro OP_RLC reg, byte
	.if \byte == 4
		movs gb_a,gb_a,lsl #1
		movcc gb_f,#0
		movcs gb_f,#flags_c
		orrcss gb_a,gb_a,#1 << 24
		orreq gb_f,gb_f,#flags_z
	.else
		.if \byte < 0
			tst \reg,\reg,lsr #8
			movcc gb_f,#0
			movcs gb_f,#flags_c
			adc \reg,\reg,\reg
			ands r1,\reg,#0xFF
			orreq gb_f,gb_f,#flags_z
		.else
			.if \byte == 3
				eor r1,\reg,\reg,lsl #1
				bic r1,r1,#0xFF << 24
				eors \reg,r1,\reg,lsl #1
				biccc \reg,\reg,#1 << 24
				orrcs \reg,\reg,#1 << 24
				movcc gb_f,#0
				movcs gb_f,#flags_c
			.else
				tst \reg,#1 << (\byte*8 + 7)
				eor r1,\reg,\reg,lsl #1
				bic r1,r1,#0xFF << (\byte*8)
				eor \reg,r1,\reg,lsl #1
				.if \byte > 0
					biceq \reg,\reg,#1 << (\byte*8)
				.endif
				orrne \reg,\reg,#1 << (\byte*8)
				moveq gb_f,#0
				movne gb_f,#flags_c
			.endif
			tst \reg,#0xFF << (\byte*8)
			orreq gb_f,gb_f,#flags_z
		.endif
	.endif
.endm

.macro OP_RRC reg, byte
	.if \byte == 4
		tst \reg,\reg,lsl #8
		movcc gb_f,#0
		movcs gb_f,#flags_c
		bic \reg,\reg,#1 << 24
		movs \reg,\reg,rrx
		orreq gb_f,gb_f,#flags_z
	.else
		.if \byte < 0
			movs r1,\reg,lsr #1
			movcc gb_f,#0
			movcs gb_f,#flags_c
			orrcss r1,r1,#1 << 7
			orreq gb_f,gb_f,#flags_z
		.else
			.if \byte == 0
				eor r1,\reg,\reg,lsr #1
				bic r1,r1,#0xFF
				eors \reg,r1,\reg,lsr #1
				biccc \reg,\reg,#1 << 7
				orrcs \reg,\reg,#1 << 7
				movcc gb_f,#0
				movcs gb_f,#flags_c
			.else
				tst \reg,#1 << (\byte*8)
				eor r1,\reg,\reg,lsr #1
				bic r1,r1,#0xFF << (\byte*8)
				eor \reg,r1,\reg,lsr #1
				.if \byte < 3
					biceq \reg,\reg,#1 << (\byte*8 + 7)
				.endif
				orrne \reg,\reg,#1 << (\byte*8 + 7)
				moveq gb_f,#0
				movne gb_f,#flags_c
			.endif
			tst \reg,#0xFF << (\byte*8)
			orreq gb_f,gb_f,#flags_z
		.endif
	.endif
.endm

.macro OP_RL reg, byte
	.if \byte == 4
		tst gb_f,#flags_c
		orrne gb_a,gb_a,#1 << 23
		movs gb_a,gb_a,lsl #1
		movcc gb_f,#0
		movcs gb_f,#flags_c
		orreq gb_f,gb_f,#flags_z
	.else
		.if \byte < 0
			tst gb_f,gb_f,lsr #5
			tst \reg,#1 << 7
			moveq gb_f,#0
			movne gb_f,#flags_c
			adc \reg,\reg,\reg
			ands r1,\reg,#0xFF
			orreq gb_f,gb_f,#flags_z
		.else
			.if \byte == 3
				eor r1,\reg,\reg,lsl #1
				bic r1,r1,#0xFF << 24
				tst gb_f,#flags_c
				biceq \reg,\reg,#1 << 23
				orrne \reg,\reg,#1 << 23
				eors \reg,r1,\reg,lsl #1
			.else
				tst \reg,\reg,lsl #25 - \byte*8
				tst gb_f,#flags_c
				eor r1,\reg,\reg,lsl #1
				bic r1,r1,#0xFF << (\byte*8)
				eor \reg,r1,\reg,lsl #1
				.if \byte > 0
					biceq \reg,\reg,#1 << (\byte*8)
				.endif
				orrne \reg,\reg,#1 << (\byte*8)
			.endif
			movcc gb_f,#0
			movcs gb_f,#flags_c
			tst \reg,#0xFF << (\byte*8)
			orreq gb_f,gb_f,#flags_z
		.endif
	.endif
.endm

.macro OP_RR reg, byte
	.if \byte == 4
		tst \reg,\reg,lsl #8
		tst gb_f,#flags_c
		movcc gb_f,#0
		movcs gb_f,#flags_c
		mov \reg,\reg,lsr #1
		orrne \reg,\reg,#1 << 31
		ands \reg,\reg,#0xFF << 24
		orreq gb_f,gb_f,#flags_z
	.else
		.if \byte < 0
			movs r1,\reg,lsr #1
			tst gb_f,#flags_c
			movcc gb_f,#0
			movcs gb_f,#flags_c
			orrnes r1,r1,#1 << 7
			orreq gb_f,gb_f,#flags_z
		.else
			.if \byte == 0
				eor r1,\reg,\reg,lsr #1
				bic r1,r1,#0xFF
				eors \reg,r1,\reg,lsr #1
				tst gb_f,#flags_c
				movcc gb_f,#0
				movcs gb_f,#flags_c
				biceq \reg,\reg,#1 << 7
				orrne \reg,\reg,#1 << 7
			.else
				tst \reg,\reg,lsr #1 + \byte*8
				tst gb_f,#flags_c
				eor r1,\reg,\reg,lsr #1
				bic r1,r1,#0xFF << (\byte*8)
				eor \reg,r1,\reg,lsr #1
				.if \byte < 3
					biceq \reg,\reg,#1 << (\byte*8 + 7)
				.endif
				orrne \reg,\reg,#1 << (\byte*8 + 7)
				movcc gb_f,#0
				movcs gb_f,#flags_c
			.endif
			tst \reg,#0xFF << (\byte*8)
			orreq gb_f,gb_f,#flags_z
		.endif
	.endif
.endm

.macro OP_SLA reg, byte
	.if \byte == 4
		movs gb_a,gb_a,lsl #1
		movcc gb_f,#0
		movcs gb_f,#flags_c
		orreq gb_f,gb_f,#flags_z
	.else
		.if \byte < 0
			movs \reg,\reg,lsl #25
			movcc gb_f,#0
			movcs gb_f,#flags_c
			orreq gb_f,gb_f,#flags_z
			mov r1,\reg,lsr #24
		.else
			.if \byte == 3
				eor r1,\reg,\reg,lsl #1
				bic r1,r1,#0xFF << 24
				eors \reg,r1,\reg,lsl #1
				bic \reg,\reg,#1 << 24
				movcc gb_f,#0
				movcs gb_f,#flags_c
			.else
				tst \reg,#1 << (\byte*8 + 7)
				eor r1,\reg,\reg,lsl #1
				bic r1,r1,#0xFF << (\byte*8)
				eor \reg,r1,\reg,lsl #1
				.if \byte > 0
					bic \reg,\reg,#1 << (\byte*8)
				.endif
				moveq gb_f,#0
				movne gb_f,#flags_c
			.endif
			tst \reg,#0xFF << (\byte*8)
			orreq gb_f,gb_f,#flags_z
		.endif
	.endif
.endm

.macro OP_SRA reg, byte
	.if \byte == 4
		tst \reg,#1 << 24
		moveq gb_f,#0
		movne gb_f,#flags_c
		bic \reg,\reg,#1 << 24
		movs \reg,\reg,asr #1
		orreq gb_f,gb_f,#flags_z
	.else
		.if \byte < 0
			mov r1,\reg,lsl #24
			movs r1,r1,asr #25
			movcc gb_f,#0
			movcs gb_f,#flags_c
			orreq gb_f,gb_f,#flags_z
		.else
			.if \byte == 0
				eor r1,\reg,\reg,lsr #1
				bic r1,r1,#0x7F
				eors \reg,r1,\reg,lsr #1
				movcc gb_f,#0
				movcs gb_f,#flags_c
			.else
				tst \reg,#1 << (\byte*8)
				eor r1,\reg,\reg,lsr #1
				bic r1,r1,#0x7F << (\byte*8)
				eor \reg,r1,\reg,lsr #1
				moveq gb_f,#0
				movne gb_f,#flags_c
			.endif
			tst \reg,#0xFF << (\byte*8)
			orreq gb_f,gb_f,#flags_z
		.endif
	.endif
.endm

.macro OP_SWAP reg, byte
	.if \byte == 4
		mov r1,\reg,lsl #4
		orr \reg,r1,\reg,lsr #4
		ands \reg,\reg,#0xFF << 24
		movne gb_f,#0
		moveq gb_f,#flags_z
	.else
		.if \byte < 0
			mov r1,\reg,lsl #4
			orr r1,r1,\reg,lsr #4
			ands r1,r1,#0xFF
			movne gb_f,#0
			moveq gb_f,#flags_z
		.else
			and r1,\reg,#0xFF << (\byte*8)
			mov r0,r1,lsl #4
			orr r0,r0,r1,lsr #4
			ands r0,r0,#0xFF << (\byte*8)
			bic \reg,\reg,#0xFF << (\byte*8)
			orr \reg,\reg,r0,lsl #\byte*8
			movne gb_f,#0
			moveq gb_f,#flags_z
		.endif
	.endif
.endm
	
.macro OP_SRL reg, byte
	.if \byte == 4
		tst \reg,#1 << 24
		moveq gb_f,#0
		movne gb_f,#flags_c
		bic \reg,\reg,#1 << 24
		movs \reg,\reg,lsr #1
		orreq gb_f,gb_f,#flags_z
	.else
		.if \byte < 0
			movs r1,\reg,lsr #1
			movcc gb_f,#0
			movcs gb_f,#flags_c
			orreq gb_f,gb_f,#flags_z
		.else
			.if \byte == 0
				eor r1,\reg,\reg,lsr #1
				bic r1,r1,#0xFF
				eors \reg,r1,\reg,lsr #1
				bic \reg,\reg,#1 << 7
				movcc gb_f,#0
				movcs gb_f,#flags_c
			.else
				tst \reg,#1 << (\byte*8)
				eor r1,\reg,\reg,lsr #1
				bic r1,r1,#0xFF << (\byte*8)
				eor \reg,r1,\reg,lsr #1
				bic \reg,\reg,#1 << (\byte*8 + 7)
				moveq gb_f,#0
				movne gb_f,#flags_c
			.endif
			tst \reg,#0xFF << (\byte*8)
			orreq gb_f,gb_f,#flags_z
		.endif
	.endif
.endm

.macro OP_BIT reg, byte, bit
	and gb_f,gb_f,#flags_c
	.if \byte == 4
		tst \reg,#1 << (24 + \bit)
	.else
		tst \reg,#1 << (\byte*8 + \bit)
	.endif
	orreq gb_f,gb_f,#flags_h
	orrne gb_f,gb_f,#flags_h | flags_z
.endm

.macro OP_RES reg, byte, bit
	.if \byte == 4
		bic \reg,\reg,#1 << (24 + \bit)
	.else
		.if \byte < 0
			bic r1,\reg,#1 << \bit
		.else
			bic \reg,\reg,#1 << (\byte*8 + \bit)
		.endif
	.endif
.endm

.macro OP_SET reg, byte, bit
	.if \byte == 4
		orr \reg,\reg,#1 << (24 + \bit)
	.else
		.if \byte < 0
			orr r1,\reg,#1 << \bit
		.else
			orr \reg,\reg,#1 << (\byte*8 + \bit)
		.endif
	.endif
.endm
	
bitop_00: @RLC B
	OP_RLC gb_bcde, byte_b
	NEXT 8
	
bitop_01: @RLC C
	OP_RLC gb_bcde, byte_c
	NEXT 8
	
bitop_02: @RLC D
	OP_RLC gb_bcde, byte_d
	NEXT 8
	
bitop_03: @RLC E
	OP_RLC gb_bcde, byte_e
	NEXT 8
	
bitop_04: @RLC H
	OP_RLC gb_hl, byte_h
	NEXT 8
	
bitop_05: @RLC L
	OP_RLC gb_hl, byte_l
	NEXT 8
	
bitop_06: @RLC (HL)
	READHL
	OP_RLC r0, -1
	WRITEHL
	NEXT 16
	
bitop_07: @RLC A
	OP_RLC gb_a, byte_a
	NEXT 8
	
bitop_08: @RRC B
	OP_RRC gb_bcde, byte_b
	NEXT 8
	
bitop_09: @RRC C
	OP_RRC gb_bcde, byte_c
	NEXT 8
	
bitop_0A: @RRC D
	OP_RRC gb_bcde, byte_d
	NEXT 8
	
bitop_0B: @RRC E
	OP_RRC gb_bcde, byte_e
	NEXT 8
	
bitop_0C: @RRC H
	OP_RRC gb_hl, byte_h
	NEXT 8
	
bitop_0D: @RRC L
	OP_RRC gb_hl, byte_l
	NEXT 8
	
bitop_0E: @RRC (HL)
	READHL
	OP_RRC r0, -1
	WRITEHL
	NEXT 16
	
bitop_0F: @RRC A
	OP_RRC gb_a, byte_a
	NEXT 8
	
bitop_10: @RL B
	OP_RL gb_bcde, byte_b
	NEXT 8
	
bitop_11: @RL C
	OP_RL gb_bcde, byte_c
	NEXT 8
	
bitop_12: @RL D
	OP_RL gb_bcde, byte_d
	NEXT 8
	
bitop_13: @RL E
	OP_RL gb_bcde, byte_e
	NEXT 8
	
bitop_14: @RL H
	OP_RL gb_hl, byte_h
	NEXT 8
	
bitop_15: @RL L
	OP_RL gb_hl, byte_l
	NEXT 8
	
bitop_16: @RL (HL)
	READHL
	OP_RL r0, -1
	WRITEHL
	NEXT 16
	
bitop_17: @RL A
	OP_RL gb_a, byte_a
	NEXT 8
	
bitop_18: @RR B
	OP_RR gb_bcde, byte_b
	NEXT 8
	
bitop_19: @RR C
	OP_RR gb_bcde, byte_c
	NEXT 8
	
bitop_1A: @RR D
	OP_RR gb_bcde, byte_d
	NEXT 8
	
bitop_1B: @RR E
	OP_RR gb_bcde, byte_e
	NEXT 8
	
bitop_1C: @RR H
	OP_RR gb_hl, byte_h
	NEXT 8
	
bitop_1D: @RR L
	OP_RR gb_hl, byte_l
	NEXT 8
	
bitop_1E: @RR (HL)
	READHL
	OP_RR r0, -1
	WRITEHL
	NEXT 16
	
bitop_1F: @RR A
	OP_RR gb_a, byte_a
	NEXT 8
	
bitop_20: @SLA B
	OP_SLA gb_bcde, byte_b
	NEXT 8
	
bitop_21: @SLA C
	OP_SLA gb_bcde, byte_c
	NEXT 8
	
bitop_22: @SLA D
	OP_SLA gb_bcde, byte_d
	NEXT 8
	
bitop_23: @SLA E
	OP_SLA gb_bcde, byte_e
	NEXT 8
	
bitop_24: @SLA H
	OP_SLA gb_hl, byte_h
	NEXT 8
	
bitop_25: @SLA L
	OP_SLA gb_hl, byte_l
	NEXT 8
	
bitop_26: @SLA (HL)
	READHL
	OP_SLA r0, -1
	WRITEHL
	NEXT 16
	
bitop_27: @SLA A
	OP_SLA gb_a, byte_a
	NEXT 8
	
bitop_28: @SRA B
	OP_SRA gb_bcde, byte_b
	NEXT 8
	
bitop_29: @SRA C
	OP_SRA gb_bcde, byte_c
	NEXT 8
	
bitop_2A: @SRA D
	OP_SRA gb_bcde, byte_d
	NEXT 8
	
bitop_2B: @SRA E
	OP_SRA gb_bcde, byte_e
	NEXT 8
	
bitop_2C: @SRA H
	OP_SRA gb_hl, byte_h
	NEXT 8
	
bitop_2D: @SRA L
	OP_SRA gb_hl, byte_l
	NEXT 8
	
bitop_2E: @SRA (HL)
	READHL
	OP_SRA r0, -1
	WRITEHL
	NEXT 16
	
bitop_2F: @SRA A
	OP_SRA gb_a, byte_a
	NEXT 8
	
bitop_30: @SWAP B
	OP_SWAP gb_bcde, byte_b
	NEXT 8
	
bitop_31: @SWAP C
	OP_SWAP gb_bcde, byte_c
	NEXT 8
	
bitop_32: @SWAP D
	OP_SWAP gb_bcde, byte_d
	NEXT 8
	
bitop_33: @SWAP E
	OP_SWAP gb_bcde, byte_e
	NEXT 8
	
bitop_34: @SWAP H
	OP_SWAP gb_hl, byte_h
	NEXT 8
	
bitop_35: @SWAP L
	OP_SWAP gb_hl, byte_l
	NEXT 8
	
bitop_36: @SWAP (HL)
	READHL
	OP_SWAP r0, -1
	WRITEHL
	NEXT 16
	
bitop_37: @SWAP A
	OP_SWAP gb_a, byte_a
	NEXT 8
	
bitop_38: @SRL B
	OP_SRL gb_bcde, byte_b
	NEXT 8
	
bitop_39: @SRL C
	OP_SRL gb_bcde, byte_c
	NEXT 8
	
bitop_3A: @SRL D
	OP_SRL gb_bcde, byte_d
	NEXT 8
	
bitop_3B: @SRL E
	OP_SRL gb_bcde, byte_e
	NEXT 8
	
bitop_3C: @SRL H
	OP_SRL gb_hl, byte_h
	NEXT 8
	
bitop_3D: @SRL L
	OP_SRL gb_hl, byte_l
	NEXT 8
	
bitop_3E: @SRL (HL)
	READHL
	OP_SRL r0, -1
	WRITEHL
	NEXT 16
	
bitop_3F: @SRL A
	OP_SRL gb_a, byte_a
	NEXT 8
	
bitop_40: @BIT 0,B
	OP_BIT gb_bcde, byte_b, 0
	NEXT 8
	
bitop_41: @BIT 0,C
	OP_BIT gb_bcde, byte_c, 0
	NEXT 8
	
bitop_42: @BIT 0,D
	OP_BIT gb_bcde, byte_d, 0
	NEXT 8
	
bitop_43: @BIT 0,E
	OP_BIT gb_bcde, byte_e, 0
	NEXT 8
	
bitop_44: @BIT 0,H
	OP_BIT gb_hl, byte_h, 0
	NEXT 8
	
bitop_45: @BIT 0,L
	OP_BIT gb_hl, byte_l, 0
	NEXT 8
	
bitop_46: @BIT 0,(HL)
	READHL
	OP_BIT r0, 0, 0
	NEXT 12
	
bitop_47: @BIT 0,A
	OP_BIT gb_a, byte_a, 0
	NEXT 8
	
bitop_48: @BIT 1,B
	OP_BIT gb_bcde, byte_b, 1
	NEXT 8
	
bitop_49: @BIT 1,C
	OP_BIT gb_bcde, byte_c, 1
	NEXT 8
	
bitop_4A: @BIT 1,D
	OP_BIT gb_bcde, byte_d, 1
	NEXT 8
	
bitop_4B: @BIT 1,E
	OP_BIT gb_bcde, byte_e, 1
	NEXT 8
	
bitop_4C: @BIT 1,H
	OP_BIT gb_hl, byte_h, 1
	NEXT 8
	
bitop_4D: @BIT 1,L
	OP_BIT gb_hl, byte_l, 1
	NEXT 8
	
bitop_4E: @BIT 1,(HL)
	READHL
	OP_BIT r0, 0, 1
	NEXT 12
	
bitop_4F: @BIT 1,A
	OP_BIT gb_a, byte_a, 1
	NEXT 8
	
bitop_50: @BIT 2,B
	OP_BIT gb_bcde, byte_b, 2
	NEXT 8
	
bitop_51: @BIT 2,C
	OP_BIT gb_bcde, byte_c, 2
	NEXT 8
	
bitop_52: @BIT 2,D
	OP_BIT gb_bcde, byte_d, 2
	NEXT 8
	
bitop_53: @BIT 2,E
	OP_BIT gb_bcde, byte_e, 2
	NEXT 8
	
bitop_54: @BIT 2,H
	OP_BIT gb_hl, byte_h, 2
	NEXT 8
	
bitop_55: @BIT 2,L
	OP_BIT gb_hl, byte_l, 2
	NEXT 8
	
bitop_56: @BIT 2,(HL)
	READHL
	OP_BIT r0, 0, 2
	NEXT 12
	
bitop_57: @BIT 2,A
	OP_BIT gb_a, byte_a, 2
	NEXT 8
	
bitop_58: @BIT 3,B
	OP_BIT gb_bcde, byte_b, 3
	NEXT 8
	
bitop_59: @BIT 3,C
	OP_BIT gb_bcde, byte_c, 3
	NEXT 8
	
bitop_5A: @BIT 3,D
	OP_BIT gb_bcde, byte_d, 3
	NEXT 8
	
bitop_5B: @BIT 3,E
	OP_BIT gb_bcde, byte_e, 3
	NEXT 8
	
bitop_5C: @BIT 3,H
	OP_BIT gb_hl, byte_h, 3
	NEXT 8
	
bitop_5D: @BIT 3,L
	OP_BIT gb_hl, byte_l, 3
	NEXT 8
	
bitop_5E: @BIT 3,(HL)
	READHL
	OP_BIT r0, 0, 3
	NEXT 12
	
bitop_5F: @BIT 3,A
	OP_BIT gb_a, byte_a, 3
	NEXT 8
	
bitop_60: @BIT 4,B
	OP_BIT gb_bcde, byte_b, 4
	NEXT 8
	
bitop_61: @BIT 4,C
	OP_BIT gb_bcde, byte_c, 4
	NEXT 8
	
bitop_62: @BIT 4,D
	OP_BIT gb_bcde, byte_d, 4
	NEXT 8
	
bitop_63: @BIT 4,E
	OP_BIT gb_bcde, byte_e, 4
	NEXT 8
	
bitop_64: @BIT 4,H
	OP_BIT gb_hl, byte_h, 4
	NEXT 8
	
bitop_65: @BIT 4,L
	OP_BIT gb_hl, byte_l, 4
	NEXT 8
	
bitop_66: @BIT 4,(HL)
	READHL
	OP_BIT r0, 0, 4
	NEXT 12
	
bitop_67: @BIT 4,A
	OP_BIT gb_a, byte_a, 4
	NEXT 8
	
bitop_68: @BIT 5,B
	OP_BIT gb_bcde, byte_b, 5
	NEXT 8
	
bitop_69: @BIT 5,C
	OP_BIT gb_bcde, byte_c, 5
	NEXT 8
	
bitop_6A: @BIT 5,D
	OP_BIT gb_bcde, byte_d, 5
	NEXT 8
	
bitop_6B: @BIT 5,E
	OP_BIT gb_bcde, byte_e, 5
	NEXT 8
	
bitop_6C: @BIT 5,H
	OP_BIT gb_hl, byte_h, 5
	NEXT 8
	
bitop_6D: @BIT 5,L
	OP_BIT gb_hl, byte_l, 5
	NEXT 8
	
bitop_6E: @BIT 5,(HL)
	READHL
	OP_BIT r0, 0, 5
	NEXT 12
	
bitop_6F: @BIT 5,A
	OP_BIT gb_a, byte_a, 5
	NEXT 8
	
bitop_70: @BIT 6,B
	OP_BIT gb_bcde, byte_b, 6
	NEXT 8
	
bitop_71: @BIT 6,C
	OP_BIT gb_bcde, byte_c, 6
	NEXT 8
	
bitop_72: @BIT 6,D
	OP_BIT gb_bcde, byte_d, 6
	NEXT 8
	
bitop_73: @BIT 6,E
	OP_BIT gb_bcde, byte_e, 6
	NEXT 8
	
bitop_74: @BIT 6,H
	OP_BIT gb_hl, byte_h, 6
	NEXT 8
	
bitop_75: @BIT 6,L
	OP_BIT gb_hl, byte_l, 6
	NEXT 8
	
bitop_76: @BIT 6,(HL)
	READHL
	OP_BIT r0, 0, 6
	NEXT 12
	
bitop_77: @BIT 6,A
	OP_BIT gb_a, byte_a, 6
	NEXT 8
	
bitop_78: @BIT 7,B
	OP_BIT gb_bcde, byte_b, 7
	NEXT 8
	
bitop_79: @BIT 7,C
	OP_BIT gb_bcde, byte_c, 7
	NEXT 8
	
bitop_7A: @BIT 7,D
	OP_BIT gb_bcde, byte_d, 7
	NEXT 8
	
bitop_7B: @BIT 7,E
	OP_BIT gb_bcde, byte_e, 7
	NEXT 8
	
bitop_7C: @BIT 7,H
	OP_BIT gb_hl, byte_h, 7
	NEXT 8
	
bitop_7D: @BIT 7,L
	OP_BIT gb_hl, byte_l, 7
	NEXT 8
	
bitop_7E: @BIT 7,(HL)
	READHL
	OP_BIT r0, 0, 7
	NEXT 12
	
bitop_7F: @BIT 7,A
	OP_BIT gb_a, byte_a, 7
	NEXT 8
	
bitop_80: @RES 0,B
	OP_RES gb_bcde, byte_b, 0
	NEXT 8
	
bitop_81: @RES 0,C
	OP_RES gb_bcde, byte_c, 0
	NEXT 8
	
bitop_82: @RES 0,D
	OP_RES gb_bcde, byte_d, 0
	NEXT 8
	
bitop_83: @RES 0,E
	OP_RES gb_bcde, byte_e, 0
	NEXT 8
	
bitop_84: @RES 0,H
	OP_RES gb_hl, byte_h, 0
	NEXT 8
	
bitop_85: @RES 0,L
	OP_RES gb_hl, byte_l, 0
	NEXT 8
	
bitop_86: @RES 0,(HL)
	READHL
	OP_RES r0, 0, 0
	WRITEHL
	NEXT 16
	
bitop_87: @RES 0,A
	OP_RES gb_a, byte_a, 0
	NEXT 8
	
bitop_88: @RES 1,B
	OP_RES gb_bcde, byte_b, 1
	NEXT 8
	
bitop_89: @RES 1,C
	OP_RES gb_bcde, byte_c, 1
	NEXT 8
	
bitop_8A: @RES 1,D
	OP_RES gb_bcde, byte_d, 1
	NEXT 8
	
bitop_8B: @RES 1,E
	OP_RES gb_bcde, byte_e, 1
	NEXT 8
	
bitop_8C: @RES 1,H
	OP_RES gb_hl, byte_h, 1
	NEXT 8
	
bitop_8D: @RES 1,L
	OP_RES gb_hl, byte_l, 1
	NEXT 8
	
bitop_8E: @RES 1,(HL)
	READHL
	OP_RES r0, 0, 1
	WRITEHL
	NEXT 16
	
bitop_8F: @RES 1,A
	OP_RES gb_a, byte_a, 1
	NEXT 8
	
bitop_90: @RES 2,B
	OP_RES gb_bcde, byte_b, 2
	NEXT 8
	
bitop_91: @RES 2,C
	OP_RES gb_bcde, byte_c, 2
	NEXT 8
	
bitop_92: @RES 2,D
	OP_RES gb_bcde, byte_d, 2
	NEXT 8
	
bitop_93: @RES 2,E
	OP_RES gb_bcde, byte_e, 2
	NEXT 8
	
bitop_94: @RES 2,H
	OP_RES gb_hl, byte_h, 2
	NEXT 8
	
bitop_95: @RES 2,L
	OP_RES gb_hl, byte_l, 2
	NEXT 8
	
bitop_96: @RES 2,(HL)
	READHL
	OP_RES r0, 0, 2
	WRITEHL
	NEXT 16
	
bitop_97: @RES 2,A
	OP_RES gb_a, byte_a, 2
	NEXT 8
	
bitop_98: @RES 3,B
	OP_RES gb_bcde, byte_b, 3
	NEXT 8
	
bitop_99: @RES 3,C
	OP_RES gb_bcde, byte_c, 3
	NEXT 8
	
bitop_9A: @RES 3,D
	OP_RES gb_bcde, byte_d, 3
	NEXT 8
	
bitop_9B: @RES 3,E
	OP_RES gb_bcde, byte_e, 3
	NEXT 8
	
bitop_9C: @RES 3,H
	OP_RES gb_hl, byte_h, 3
	NEXT 8
	
bitop_9D: @RES 3,L
	OP_RES gb_hl, byte_l, 3
	NEXT 8
	
bitop_9E: @RES 3,(HL)
	READHL
	OP_RES r0, 0, 3
	WRITEHL
	NEXT 16
	
bitop_9F: @RES 3,A
	OP_RES gb_a, byte_a, 3
	NEXT 8
	
bitop_A0: @RES 4,B
	OP_RES gb_bcde, byte_b, 4
	NEXT 8
	
bitop_A1: @RES 4,C
	OP_RES gb_bcde, byte_c, 4
	NEXT 8
	
bitop_A2: @RES 4,D
	OP_RES gb_bcde, byte_d, 4
	NEXT 8
	
bitop_A3: @RES 4,E
	OP_RES gb_bcde, byte_e, 4
	NEXT 8
	
bitop_A4: @RES 4,H
	OP_RES gb_hl, byte_h, 4
	NEXT 8
	
bitop_A5: @RES 4,L
	OP_RES gb_hl, byte_l, 4
	NEXT 8
	
bitop_A6: @RES 4,(HL)
	READHL
	OP_RES r0, 0, 4
	WRITEHL
	NEXT 16
	
bitop_A7: @RES 4,A
	OP_RES gb_a, byte_a, 4
	NEXT 8
	
bitop_A8: @RES 5,B
	OP_RES gb_bcde, byte_b, 5
	NEXT 8
	
bitop_A9: @RES 5,C
	OP_RES gb_bcde, byte_c, 5
	NEXT 8
	
bitop_AA: @RES 5,D
	OP_RES gb_bcde, byte_d, 5
	NEXT 8
	
bitop_AB: @RES 5,E
	OP_RES gb_bcde, byte_e, 5
	NEXT 8
	
bitop_AC: @RES 5,H
	OP_RES gb_hl, byte_h, 5
	NEXT 8
	
bitop_AD: @RES 5,L
	OP_RES gb_hl, byte_l, 5
	NEXT 8
	
bitop_AE: @RES 5,(HL)
	READHL
	OP_RES r0, 0, 5
	WRITEHL
	NEXT 16
	
bitop_AF: @RES 5,A
	OP_RES gb_a, byte_a, 5
	NEXT 8
	
bitop_B0: @RES 6,B
	OP_RES gb_bcde, byte_b, 6
	NEXT 8
	
bitop_B1: @RES 6,C
	OP_RES gb_bcde, byte_c, 6
	NEXT 8
	
bitop_B2: @RES 6,D
	OP_RES gb_bcde, byte_d, 6
	NEXT 8
	
bitop_B3: @RES 6,E
	OP_RES gb_bcde, byte_e, 6
	NEXT 8
	
bitop_B4: @RES 6,H
	OP_RES gb_hl, byte_h, 6
	NEXT 8
	
bitop_B5: @RES 6,L
	OP_RES gb_hl, byte_l, 6
	NEXT 8
	
bitop_B6: @RES 6,(HL)
	READHL
	OP_RES r0, 0, 6
	WRITEHL
	NEXT 16
	
bitop_B7: @RES 6,A
	OP_RES gb_a, byte_a, 6
	NEXT 8
	
bitop_B8: @RES 7,B
	OP_RES gb_bcde, byte_b, 7
	NEXT 8
	
bitop_B9: @RES 7,C
	OP_RES gb_bcde, byte_c, 7
	NEXT 8
	
bitop_BA: @RES 7,D
	OP_RES gb_bcde, byte_d, 7
	NEXT 8
	
bitop_BB: @RES 7,E
	OP_RES gb_bcde, byte_e, 7
	NEXT 8
	
bitop_BC: @RES 7,H
	OP_RES gb_hl, byte_h, 7
	NEXT 8
	
bitop_BD: @RES 7,L
	OP_RES gb_hl, byte_l, 7
	NEXT 8
	
bitop_BE: @RES 7,(HL)
	READHL
	OP_RES r0, 0, 7
	WRITEHL
	NEXT 16
	
bitop_BF: @RES 7,A
	OP_RES gb_a, byte_a, 7
	NEXT 8
	
bitop_C0: @SET 0,B
	OP_SET gb_bcde, byte_b, 0
	NEXT 8
	
bitop_C1: @SET 0,C
	OP_SET gb_bcde, byte_c, 0
	NEXT 8
	
bitop_C2: @SET 0,D
	OP_SET gb_bcde, byte_d, 0
	NEXT 8
	
bitop_C3: @SET 0,E
	OP_SET gb_bcde, byte_e, 0
	NEXT 8
	
bitop_C4: @SET 0,H
	OP_SET gb_hl, byte_h, 0
	NEXT 8
	
bitop_C5: @SET 0,L
	OP_SET gb_hl, byte_l, 0
	NEXT 8
	
bitop_C6: @SET 0,(HL)
	READHL
	OP_SET r0, 0, 0
	WRITEHL
	NEXT 16
	
bitop_C7: @SET 0,A
	OP_SET gb_a, byte_a, 0
	NEXT 8
	
bitop_C8: @SET 1,B
	OP_SET gb_bcde, byte_b, 1
	NEXT 8
	
bitop_C9: @SET 1,C
	OP_SET gb_bcde, byte_c, 1
	NEXT 8
	
bitop_CA: @SET 1,D
	OP_SET gb_bcde, byte_d, 1
	NEXT 8
	
bitop_CB: @SET 1,E
	OP_SET gb_bcde, byte_e, 1
	NEXT 8
	
bitop_CC: @SET 1,H
	OP_SET gb_hl, byte_h, 1
	NEXT 8
	
bitop_CD: @SET 1,L
	OP_SET gb_hl, byte_l, 1
	NEXT 8
	
bitop_CE: @SET 1,(HL)
	READHL
	OP_SET r0, 0, 1
	WRITEHL
	NEXT 16
	
bitop_CF: @SET 1,A
	OP_SET gb_a, byte_a, 1
	NEXT 8
	
bitop_D0: @SET 2,B
	OP_SET gb_bcde, byte_b, 2
	NEXT 8
	
bitop_D1: @SET 2,C
	OP_SET gb_bcde, byte_c, 2
	NEXT 8
	
bitop_D2: @SET 2,D
	OP_SET gb_bcde, byte_d, 2
	NEXT 8
	
bitop_D3: @SET 2,E
	OP_SET gb_bcde, byte_e, 2
	NEXT 8
	
bitop_D4: @SET 2,H
	OP_SET gb_hl, byte_h, 2
	NEXT 8
	
bitop_D5: @SET 2,L
	OP_SET gb_hl, byte_l, 2
	NEXT 8
	
bitop_D6: @SET 2,(HL)
	READHL
	OP_SET r0, 0, 2
	WRITEHL
	NEXT 16
	
bitop_D7: @SET 2,A
	OP_SET gb_a, byte_a, 2
	NEXT 8
	
bitop_D8: @SET 3,B
	OP_SET gb_bcde, byte_b, 3
	NEXT 8
	
bitop_D9: @SET 3,C
	OP_SET gb_bcde, byte_c, 3
	NEXT 8
	
bitop_DA: @SET 3,D
	OP_SET gb_bcde, byte_d, 3
	NEXT 8
	
bitop_DB: @SET 3,E
	OP_SET gb_bcde, byte_e, 3
	NEXT 8
	
bitop_DC: @SET 3,H
	OP_SET gb_hl, byte_h, 3
	NEXT 8
	
bitop_DD: @SET 3,L
	OP_SET gb_hl, byte_l, 3
	NEXT 8
	
bitop_DE: @SET 3,(HL)
	READHL
	OP_SET r0, 0, 3
	WRITEHL
	NEXT 16
	
bitop_DF: @SET 3,A
	OP_SET gb_a, byte_a, 3
	NEXT 8
	
bitop_E0: @SET 4,B
	OP_SET gb_bcde, byte_b, 4
	NEXT 8
	
bitop_E1: @SET 4,C
	OP_SET gb_bcde, byte_c, 4
	NEXT 8
	
bitop_E2: @SET 4,D
	OP_SET gb_bcde, byte_d, 4
	NEXT 8
	
bitop_E3: @SET 4,E
	OP_SET gb_bcde, byte_e, 4
	NEXT 8
	
bitop_E4: @SET 4,H
	OP_SET gb_hl, byte_h, 4
	NEXT 8
	
bitop_E5: @SET 4,L
	OP_SET gb_hl, byte_l, 4
	NEXT 8
	
bitop_E6: @SET 4,(HL)
	READHL
	OP_SET r0, 0, 4
	WRITEHL
	NEXT 16
	
bitop_E7: @SET 4,A
	OP_SET gb_a, byte_a, 4
	NEXT 8
	
bitop_E8: @SET 5,B
	OP_SET gb_bcde, byte_b, 5
	NEXT 8
	
bitop_E9: @SET 5,C
	OP_SET gb_bcde, byte_c, 5
	NEXT 8
	
bitop_EA: @SET 5,D
	OP_SET gb_bcde, byte_d, 5
	NEXT 8
	
bitop_EB: @SET 5,E
	OP_SET gb_bcde, byte_e, 5
	NEXT 8
	
bitop_EC: @SET 5,H
	OP_SET gb_hl, byte_h, 5
	NEXT 8
	
bitop_ED: @SET 5,L
	OP_SET gb_hl, byte_l, 5
	NEXT 8
	
bitop_EE: @SET 5,(HL)
	READHL
	OP_SET r0, 0, 5
	WRITEHL
	NEXT 16
	
bitop_EF: @SET 5,A
	OP_SET gb_a, byte_a, 5
	NEXT 8
	
bitop_F0: @SET 6,B
	OP_SET gb_bcde, byte_b, 6
	NEXT 8
	
bitop_F1: @SET 6,C
	OP_SET gb_bcde, byte_c, 6
	NEXT 8
	
bitop_F2: @SET 6,D
	OP_SET gb_bcde, byte_d, 6
	NEXT 8
	
bitop_F3: @SET 6,E
	OP_SET gb_bcde, byte_e, 6
	NEXT 8
	
bitop_F4: @SET 6,H
	OP_SET gb_hl, byte_h, 6
	NEXT 8
	
bitop_F5: @SET 6,L
	OP_SET gb_hl, byte_l, 6
	NEXT 8
	
bitop_F6: @SET 6,(HL)
	READHL
	OP_SET r0, 0, 6
	WRITEHL
	NEXT 16
	
bitop_F7: @SET 6,A
	OP_SET gb_a, byte_a, 6
	NEXT 8
	
bitop_F8: @SET 7,B
	OP_SET gb_bcde, byte_b, 7
	NEXT 8
	
bitop_F9: @SET 7,C
	OP_SET gb_bcde, byte_c, 7
	NEXT 8
	
bitop_FA: @SET 7,D
	OP_SET gb_bcde, byte_d, 7
	NEXT 8
	
bitop_FB: @SET 7,E
	OP_SET gb_bcde, byte_e, 7
	NEXT 8
	
bitop_FC: @SET 7,H
	OP_SET gb_hl, byte_h, 7
	NEXT 8
	
bitop_FD: @SET 7,L
	OP_SET gb_hl, byte_l, 7
	NEXT 8
	
bitop_FE: @SET 7,(HL)
	READHL
	OP_SET r0, 0, 7
	WRITEHL
	NEXT 16
	
bitop_FF: @SET 7,A
	OP_SET gb_a, byte_a, 7
	NEXT 8
	
