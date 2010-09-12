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

read_mem:
	and r2,r0,#0xF000
	ldr r2,[gb_data,r2,lsr #10]
	add r2,r2,r0
	ldrb r0,[r2]
	bx lr
	
read_mem_16:
	and r2,r0,#0xF000
	ldr r2,[gb_data,r2,lsr #10]
	tst r0,#1
	ldreqh r0,[r2,r0]
	bxeq lr
	ldrb r1,[r2,r0]!
	ldrb r0,[r2,#1]
	orr r0,r0,r1,lsl #8
	bx lr
	
write_mem:
	movs r2,r0,lsl #16
	cmp r2,#0xFF000000
	bge write_other
	and r2,r0,#0xF000
	ldr r2,[gb_data,r2,lsr #10]
	strb r1,[r2,r0]
	bx lr
	
write_mem_16:
	movs r2,r0,lsl #16
	cmp r2,#0xFF000000
	bxge lr
	and r2,r0,#0xF000
	ldr r2,[gb_data,r2,lsr #10]
	strb r1,[r2,r0]!
	mov r1,r1,lsr #8
	strb r1,[r2,#1]
	bx lr
	
write_other:
	blo write_rom
	movs r2,r2,lsl #8
	strmib r1,[gb_data,r2,asr #24]
	bxmi lr
	ldr r2,[pc,r2,lsr #22]
	add pc,pc,r2
	.long writeio_00 - writeio_offset
writeio_offset:
	.long writeio_01 - writeio_offset
	.long writeio_02 - writeio_offset
	.long writeio_03 - writeio_offset
	.long writeio_04 - writeio_offset
	.long writeio_05 - writeio_offset
	.long writeio_06 - writeio_offset
	.long writeio_07 - writeio_offset
	.long writeio_08 - writeio_offset
	.long writeio_09 - writeio_offset
	.long writeio_0A - writeio_offset
	.long writeio_0B - writeio_offset
	.long writeio_0C - writeio_offset
	.long writeio_0D - writeio_offset
	.long writeio_0E - writeio_offset
	.long writeio_0F - writeio_offset
	.long writeio_10 - writeio_offset
	.long writeio_11 - writeio_offset
	.long writeio_12 - writeio_offset
	.long writeio_13 - writeio_offset
	.long writeio_14 - writeio_offset
	.long writeio_15 - writeio_offset
	.long writeio_16 - writeio_offset
	.long writeio_17 - writeio_offset
	.long writeio_18 - writeio_offset
	.long writeio_19 - writeio_offset
	.long writeio_1A - writeio_offset
	.long writeio_1B - writeio_offset
	.long writeio_1C - writeio_offset
	.long writeio_1D - writeio_offset
	.long writeio_1E - writeio_offset
	.long writeio_1F - writeio_offset
	.long writeio_20 - writeio_offset
	.long writeio_21 - writeio_offset
	.long writeio_22 - writeio_offset
	.long writeio_23 - writeio_offset
	.long writeio_24 - writeio_offset
	.long writeio_25 - writeio_offset
	.long writeio_26 - writeio_offset
	.long writeio_27 - writeio_offset
	.long writeio_28 - writeio_offset
	.long writeio_29 - writeio_offset
	.long writeio_2A - writeio_offset
	.long writeio_2B - writeio_offset
	.long writeio_2C - writeio_offset
	.long writeio_2D - writeio_offset
	.long writeio_2E - writeio_offset
	.long writeio_2F - writeio_offset
	.long writeio_30 - writeio_offset
	.long writeio_31 - writeio_offset
	.long writeio_32 - writeio_offset
	.long writeio_33 - writeio_offset
	.long writeio_34 - writeio_offset
	.long writeio_35 - writeio_offset
	.long writeio_36 - writeio_offset
	.long writeio_37 - writeio_offset
	.long writeio_38 - writeio_offset
	.long writeio_39 - writeio_offset
	.long writeio_3A - writeio_offset
	.long writeio_3B - writeio_offset
	.long writeio_3C - writeio_offset
	.long writeio_3D - writeio_offset
	.long writeio_3E - writeio_offset
	.long writeio_3F - writeio_offset
	.long writeio_40 - writeio_offset
	.long writeio_41 - writeio_offset
	.long writeio_42 - writeio_offset
	.long writeio_43 - writeio_offset
	.long writeio_44 - writeio_offset
	.long writeio_45 - writeio_offset
	.long writeio_46 - writeio_offset
	.long writeio_47 - writeio_offset
	.long writeio_48 - writeio_offset
	.long writeio_49 - writeio_offset
	.long writeio_4A - writeio_offset
	.long writeio_4B - writeio_offset
	.long writeio_4C - writeio_offset
	.long writeio_4D - writeio_offset
	.long writeio_4E - writeio_offset
	.long writeio_4F - writeio_offset
	.long writeio_50 - writeio_offset
	.long writeio_51 - writeio_offset
	.long writeio_52 - writeio_offset
	.long writeio_53 - writeio_offset
	.long writeio_54 - writeio_offset
	.long writeio_55 - writeio_offset
	.long writeio_56 - writeio_offset
	.long writeio_57 - writeio_offset
	.long writeio_58 - writeio_offset
	.long writeio_59 - writeio_offset
	.long writeio_5A - writeio_offset
	.long writeio_5B - writeio_offset
	.long writeio_5C - writeio_offset
	.long writeio_5D - writeio_offset
	.long writeio_5E - writeio_offset
	.long writeio_5F - writeio_offset
	.long writeio_60 - writeio_offset
	.long writeio_61 - writeio_offset
	.long writeio_62 - writeio_offset
	.long writeio_63 - writeio_offset
	.long writeio_64 - writeio_offset
	.long writeio_65 - writeio_offset
	.long writeio_66 - writeio_offset
	.long writeio_67 - writeio_offset
	.long writeio_68 - writeio_offset
	.long writeio_69 - writeio_offset
	.long writeio_6A - writeio_offset
	.long writeio_6B - writeio_offset
	.long writeio_6C - writeio_offset
	.long writeio_6D - writeio_offset
	.long writeio_6E - writeio_offset
	.long writeio_6F - writeio_offset
	.long writeio_70 - writeio_offset
	.long writeio_71 - writeio_offset
	.long writeio_72 - writeio_offset
	.long writeio_73 - writeio_offset
	.long writeio_74 - writeio_offset
	.long writeio_75 - writeio_offset
	.long writeio_76 - writeio_offset
	.long writeio_77 - writeio_offset
	.long writeio_78 - writeio_offset
	.long writeio_79 - writeio_offset
	.long writeio_7A - writeio_offset
	.long writeio_7B - writeio_offset
	.long writeio_7C - writeio_offset
	.long writeio_7D - writeio_offset
	.long writeio_7E - writeio_offset
	.long writeio_7F - writeio_offset
	
write_rom:
	bx lr
	
writeio_00:
writeio_01:
writeio_02:
writeio_03:
writeio_04:
writeio_05:
writeio_06:
writeio_07:
writeio_08:
writeio_09:
writeio_0A:
writeio_0B:
writeio_0C:
writeio_0D:
writeio_0E:
writeio_0F:
writeio_10:
writeio_11:
writeio_12:
writeio_13:
writeio_14:
writeio_15:
writeio_16:
writeio_17:
writeio_18:
writeio_19:
writeio_1A:
writeio_1B:
writeio_1C:
writeio_1D:
writeio_1E:
writeio_1F:
writeio_20:
writeio_21:
writeio_22:
writeio_23:
writeio_24:
writeio_25:
writeio_26:
writeio_27:
writeio_28:
writeio_29:
writeio_2A:
writeio_2B:
writeio_2C:
writeio_2D:
writeio_2E:
writeio_2F:
writeio_30:
writeio_31:
writeio_32:
writeio_33:
writeio_34:
writeio_35:
writeio_36:
writeio_37:
writeio_38:
writeio_39:
writeio_3A:
writeio_3B:
writeio_3C:
writeio_3D:
writeio_3E:
writeio_3F:
writeio_40:
writeio_41:
writeio_42:
writeio_43:
writeio_44:
writeio_45:
writeio_46:
writeio_47:
writeio_48:
writeio_49:
writeio_4A:
writeio_4B:
writeio_4C:
writeio_4D:
writeio_4E:
writeio_4F:
writeio_50:
writeio_51:
writeio_52:
writeio_53:
writeio_54:
writeio_55:
writeio_56:
writeio_57:
writeio_58:
writeio_59:
writeio_5A:
writeio_5B:
writeio_5C:
writeio_5D:
writeio_5E:
writeio_5F:
writeio_60:
writeio_61:
writeio_62:
writeio_63:
writeio_64:
writeio_65:
writeio_66:
writeio_67:
writeio_68:
writeio_69:
writeio_6A:
writeio_6B:
writeio_6C:
writeio_6D:
writeio_6E:
writeio_6F:
writeio_70:
writeio_71:
writeio_72:
writeio_73:
writeio_74:
writeio_75:
writeio_76:
writeio_77:
writeio_78:
writeio_79:
writeio_7A:
writeio_7B:
writeio_7C:
writeio_7D:
writeio_7E:
writeio_7F:
	bx lr
	