/* gb_data struct offsets */
.equ mem_map_0000, 0x000
.equ mem_map_1000, 0x004
.equ mem_map_2000, 0x008
.equ mem_map_3000, 0x00C
.equ mem_map_4000, 0x010
.equ mem_map_5000, 0x014
.equ mem_map_6000, 0x018
.equ mem_map_7000, 0x01C
.equ mem_map_8000, 0x020
.equ mem_map_9000, 0x024
.equ mem_map_A000, 0x028
.equ mem_map_B000, 0x02C
.equ mem_map_C000, 0x030
.equ mem_map_D000, 0x034
.equ mem_map_E000, 0x038
.equ mem_map_F000, 0x03C
.equ pc_base, 0x040
.equ IFF, 0x044


/* GBZ80 register aliases */
gb_a .req r4
gb_bcde .req r5
gb_hl .req r6
gb_sp .req r7
gb_f .req r8
gb_pc .req r9
gb_cycles .req r10
gb_data .req r11
	
/* GBZ80 register byte identifiers */
.equ byte_a, 4
.equ byte_b, 3
.equ byte_c, 2
.equ byte_d, 1
.equ byte_e, 0
.equ byte_h, 3
.equ byte_l, 2
	
/* GBZ80 register word identifiers */
.equ word_bc, 1
.equ word_de, 0
.equ word_hl, 2
.equ word_sp, 2

/* GBZ80 flags */
.equ flags_z, 1 << 31
.equ flags_n, 1 << 30
.equ flags_h, 1 << 29
.equ flags_c, 1 << 28
	
/* Control register definitions */
.equ CONTROL_IRQ, 0x80
.equ CONTROL_FIQ, 0x40

/* Vector definitions */
.equ VEC_IRQ, 0x38
.equ VEC_FIQ, 0x3C

/* IRQ register definitions */
.equ IRQ_MASKED_STATUS, 0xDC000000
.equ IRQ_RAW_STATUS, 0xDC000004
.equ IRQ_ENABLE, 0xDC000008
.equ IRQ_DISABLE, 0xDC00000C
.equ IRQ_CURR, 0xDC000020
.equ IRQ_CURR_ACK, 0xDC000024
.equ IRQ_ACK1, 0xDC000028
.equ IRQ_ACK2, 0xDC00002C

/* FIQ register definitions */
.equ FIQ_MASKED_STATUS, 0xDC000100
.equ FIQ_RAW_STATUS, 0xDC000104
.equ FIQ_ENABLE, 0xDC000108
.equ FIQ_DISABLE, 0xDC00010C
.equ FIQ_CURR, 0xDC000120
.equ FIQ_CURR_ACK, 0xDC000124
.equ FIQ_ACK1, 0xDC000128
.equ FIQ_ACK2, 0xDC00012C

/* IRQ priority definitions */
.equ IRQ_PRIORITY, 0xDC000300

/* IRQ type definitions */
.equ IRQ_KEYPAD, 16
.equ IRQ_FASTTIMER, 17
.equ IRQ_TIMER1, 18
.equ IRQ_TIMER2, 19
.equ IRQ_LCD, 21

/* KEYPAD register definitions */
.equ KEYPAD_IRQ_RAW, 0x900E0008
.equ KEYPAD_IRQ_MASK, 0x900E000C
.equ KEYPAD_KEYS_0, 0x900E0010
.equ KEYPAD_KEYS_1, 0x900E0014
.equ KEYPAD_KEYS_2, 0x900E0018
.equ KEYPAD_KEYS_3, 0x900E001C

/* FASTTIMER register definitions */
.equ FASTTIMER_IRQ_RAW, 0x900A0010
.equ FASTTIMER_IRQ_MASK, 0x900A0014

.equ FASTTIMER_VALUE_0, 0x90010000
.equ FASTTIMER_DIV_0, 0x90010004
.equ FASTTIMER_CONTROL_0, 0x90010008
.equ FASTTIMER_VALUE_1, 0x9001000C
.equ FASTTIMER_DIV_1, 0x90010010
.equ FASTTIMER_CONTROL_1, 0x90010014
.equ FASTTIMER_TRIGGER_1, 0x90010018
.equ FASTTIMER_TRIGGER_2, 0x9001001C
.equ FASTTIMER_TRIGGER_3, 0x90010020
.equ FASTTIMER_TRIGGER_4, 0x90010024
.equ FASTTIMER_TRIGGER_5, 0x90010028
.equ FASTTIMER_TRIGGER_6, 0x9001002C

/* TIMER1 register definitions */
.equ TIMER1_IRQ_RAW, 0x900A0018
.equ TIMER1_IRQ_MASK, 0x900A001C
.equ TIMER1_VALUE_0, 0x900C0000
.equ TIMER1_DIV_0, 0x900C0004
.equ TIMER1_CONTROL_0, 0x900C0008
.equ TIMER1_VALUE_1, 0x900C000C
.equ TIMER1_DIV_1, 0x900C0010
.equ TIMER1_CONTROL_1, 0x900C0014
.equ TIMER1_TRIGGER_1, 0x900C0018
.equ TIMER1_TRIGGER_2, 0x900C001C
.equ TIMER1_TRIGGER_3, 0x900C0020
.equ TIMER1_TRIGGER_4, 0x900C0024
.equ TIMER1_TRIGGER_5, 0x900C0028
.equ TIMER1_TRIGGER_6, 0x900C002C

/* TIMER2 register definitions */
.equ TIMER2_IRQ_RAW, 0x900A0020
.equ TIMER2_IRQ_MASK, 0x900A0024
.equ TIMER2_VALUE_0, 0x900D0000
.equ TIMER2_DIV_0, 0x900D0004
.equ TIMER2_CONTROL_0, 0x900D0008
.equ TIMER2_VALUE_1, 0x900D000C
.equ TIMER2_DIV_1, 0x900D0010
.equ TIMER2_CONTROL_1, 0x900D0014
.equ TIMER2_TRIGGER_1, 0x900D0018
.equ TIMER2_TRIGGER_2, 0x900D001C
.equ TIMER2_TRIGGER_3, 0x900D0020
.equ TIMER2_TRIGGER_4, 0x900D0024
.equ TIMER2_TRIGGER_5, 0x900D0028
.equ TIMER2_TRIGGER_6, 0x900D002C
