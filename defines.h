/* Control register definitions */
#define CONTROL_IRQ 0x80
#define CONTROL_FIQ 0x40

/* Vector definitions */
#define VEC_IRQ *(unsigned*)0x38
#define VEC_FIQ *(unsigned*)0x3C

/* IRQ register definitions */
#define IRQ_MASKED_STATUS *(volatile unsigned*)0xDC000000
#define IRQ_RAW_STATUS *(volatile unsigned*)0xDC000004
#define IRQ_ENABLE *(volatile unsigned*)0xDC000008
#define IRQ_DISABLE *(volatile unsigned*)0xDC00000C
#define IRQ_CURR *(volatile unsigned*)0xDC000020
#define IRQ_CURR_ACK *(volatile unsigned*)0xDC000024
#define IRQ_ACK1 *(volatile unsigned*)0xDC000028
#define IRQ_ACK2 *(volatile unsigned*)0xDC00002C

/* FIQ register definitions */
#define FIQ_MASKED_STATUS *(volatile unsigned*)0xDC000100
#define FIQ_RAW_STATUS *(volatile unsigned*)0xDC000104
#define FIQ_ENABLE *(volatile unsigned*)0xDC000108
#define FIQ_DISABLE *(volatile unsigned*)0xDC00010C
#define FIQ_CURR *(volatile unsigned*)0xDC000120
#define FIQ_CURR_ACK *(volatile unsigned*)0xDC000124
#define FIQ_ACK1 *(volatile unsigned*)0xDC000128
#define FIQ_ACK2 *(volatile unsigned*)0xDC00012C

/* IRQ priority definitions */
#define IRQ_PRIORITY ((volatile unsigned*)0xDC000300)

/* IRQ type definitions */
#define IRQ_KEYPAD 16
#define IRQ_FASTTIMER 17
#define IRQ_TIMER1 18
#define IRQ_TIMER2 19
#define IRQ_LCD 21

/* KEYPAD register definitions */
#define KEYPAD_IRQ_RAW *(volatile unsigned*)0x900E0008
#define KEYPAD_IRQ_MASK *(volatile unsigned*)0x900E000C
#define KEYPAD_KEYS_0 *(volatile unsigned*)0x900E0010
#define KEYPAD_KEYS_1 *(volatile unsigned*)0x900E0014
#define KEYPAD_KEYS_2 *(volatile unsigned*)0x900E0018
#define KEYPAD_KEYS_3 *(volatile unsigned*)0x900E001C

/* FASTTIMER register definitions */
#define FASTTIMER_IRQ_RAW *(volatile unsigned*)0x900A0010
#define FASTTIMER_IRQ_MASK *(volatile unsigned*)0x900A0014

#define FASTTIMER_VALUE_0 *(volatile unsigned*)0x90010000
#define FASTTIMER_DIV_0 *(volatile unsigned*)0x90010004
#define FASTTIMER_CONTROL_0 *(volatile unsigned*)0x90010008
#define FASTTIMER_VALUE_1 *(volatile unsigned*)0x9001000C
#define FASTTIMER_DIV_1 *(volatile unsigned*)0x90010010
#define FASTTIMER_CONTROL_1 *(volatile unsigned*)0x90010014
#define FASTTIMER_TRIGGER_1 *(volatile unsigned*)0x90010018
#define FASTTIMER_TRIGGER_2 *(volatile unsigned*)0x9001001C
#define FASTTIMER_TRIGGER_3 *(volatile unsigned*)0x90010020
#define FASTTIMER_TRIGGER_4 *(volatile unsigned*)0x90010024
#define FASTTIMER_TRIGGER_5 *(volatile unsigned*)0x90010028
#define FASTTIMER_TRIGGER_6 *(volatile unsigned*)0x9001002C

/* TIMER1 register definitions */
#define TIMER1_IRQ_RAW *(volatile unsigned*)0x900A0018
#define TIMER1_IRQ_MASK *(volatile unsigned*)0x900A001C
#define TIMER1_VALUE_0 *(volatile unsigned*)0x900C0000
#define TIMER1_DIV_0 *(volatile unsigned*)0x900C0004
#define TIMER1_CONTROL_0 *(volatile unsigned*)0x900C0008
#define TIMER1_VALUE_1 *(volatile unsigned*)0x900C000C
#define TIMER1_DIV_1 *(volatile unsigned*)0x900C0010
#define TIMER1_CONTROL_1 *(volatile unsigned*)0x900C0014
#define TIMER1_TRIGGER_1 *(volatile unsigned*)0x900C0018
#define TIMER1_TRIGGER_2 *(volatile unsigned*)0x900C001C
#define TIMER1_TRIGGER_3 *(volatile unsigned*)0x900C0020
#define TIMER1_TRIGGER_4 *(volatile unsigned*)0x900C0024
#define TIMER1_TRIGGER_5 *(volatile unsigned*)0x900C0028
#define TIMER1_TRIGGER_6 *(volatile unsigned*)0x900C002C

/* TIMER2 register definitions */
#define TIMER2_IRQ_RAW *(volatile unsigned*)0x900A0020
#define TIMER2_IRQ_MASK *(volatile unsigned*)0x900A0024
#define TIMER2_VALUE_0 *(volatile unsigned*)0x900D0000
#define TIMER2_DIV_0 *(volatile unsigned*)0x900D0004
#define TIMER2_CONTROL_0 *(volatile unsigned*)0x900D0008
#define TIMER2_VALUE_1 *(volatile unsigned*)0x900D000C
#define TIMER2_DIV_1 *(volatile unsigned*)0x900D0010
#define TIMER2_CONTROL_1 *(volatile unsigned*)0x900D0014
#define TIMER2_TRIGGER_1 *(volatile unsigned*)0x900D0018
#define TIMER2_TRIGGER_2 *(volatile unsigned*)0x900D001C
#define TIMER2_TRIGGER_3 *(volatile unsigned*)0x900D0020
#define TIMER2_TRIGGER_4 *(volatile unsigned*)0x900D0024
#define TIMER2_TRIGGER_5 *(volatile unsigned*)0x900D0028
#define TIMER2_TRIGGER_6 *(volatile unsigned*)0x900D002C

/* Clock speed register definitions */
#define CLOCKSPEED_LOAD *(volatile unsigned*)0x900B0000
#define CLOCKSPEED_CONTROL *(volatile unsigned*)0x900B000C
#define SET_CLOCKSPEED 4
#define CLOCKSPEED_CURR *(volatile unsigned*)0x900B0024