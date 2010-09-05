#include <os.h>
#include "defines.h"

struct gb_data
{
	char* mem_map_0000;
	char* mem_map_1000;
	char* mem_map_2000;
	char* mem_map_3000;
	char* mem_map_4000;
	char* mem_map_5000;
	char* mem_map_6000;
	char* mem_map_7000;
	char* mem_map_8000;
	char* mem_map_9000;
	char* mem_map_A000;
	char* mem_map_B000;
	char* mem_map_C000;
	char* mem_map_D000;
	char* mem_map_E000;
	char* mem_map_F000;
	
	char* pc_base;
	int IFF;
	
};
	
struct os_state
{
	int clock_speed;
	int enabled_irqs;
	int irq_vec;
	int fasttimer_mask;
	int timer1_mask;
	int timer2_mask;
	int irq_priorities[32];
};
	
struct os_state* save_os_state()
{
	// Create a struct holding memory-mapped IO data to be restored upon exit.
	struct os_state* state;
	state = malloc(sizeof(struct os_state));
	
	// Save current clock speed.
	state->clock_speed = CLOCKSPEED_CURR;
	
	// Save bitfield of enabled IRQs.
	state->enabled_irqs = IRQ_ENABLE;
	
	// Save irq vector
	state->irq_vec = VEC_IRQ;
	
	// Save timer interrupt masks.
	state->fasttimer_mask = FASTTIMER_IRQ_MASK;
	state->timer1_mask = TIMER1_IRQ_MASK;
	state->timer2_mask = TIMER2_IRQ_MASK;
	
	// Save interrupt priorities.
	int i;
	for(i = 0; i < 32; i++)
		state->irq_priorities[i] = IRQ_PRIORITY[i];
	
	return state;
}

void restore_os_state(struct os_state* state)
{
	// Restore clock speed.
	CLOCKSPEED_LOAD = state->clock_speed;
	CLOCKSPEED_CONTROL = SET_CLOCKSPEED;
	
	// Restore bitfield of enabled IRQs.
	IRQ_DISABLE = 0xFFFFFFFF;
	IRQ_ENABLE = state->enabled_irqs;
	
	// Restore IRQ vector
	VEC_IRQ = state->irq_vec;
	
	// Restore timer interrupt masks.
	FASTTIMER_IRQ_MASK = state->fasttimer_mask;
	TIMER1_IRQ_MASK = state->timer1_mask;
	TIMER2_IRQ_MASK = state->timer2_mask;
	
	// Restore interrupt priorities.
	int i;
	for(i = 0; i < 32; i++)
		IRQ_PRIORITY[i] = state->irq_priorities[i];
	
	// Turn off fasttimer
	FASTTIMER_CONTROL_0 = 0x10;
	FASTTIMER_CONTROL_1 = 0x10;
	
	// Turn off timer1
	TIMER1_CONTROL_0 = 0x10;
	TIMER1_CONTROL_1 = 0x10;
	
	// Restore known state of timer2 (in OS 1.1 at least)
	TIMER2_VALUE_0 = 32;
	TIMER2_DIV_0 = 9;
	TIMER2_CONTROL_0 = 0x01;
	TIMER2_VALUE_1 = 0;
	TIMER2_DIV_1 = 0;
	TIMER2_CONTROL_1 = 0x0A;
	TIMER2_TRIGGER_1 = 0;
	TIMER2_TRIGGER_2 = 0xFFFF;
	
	free(state);
}