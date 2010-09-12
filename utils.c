#include <os.h>
#include "defines.h"

char my_rom[32768] = {0x21,0x80,0xFF,0x35,0x20,0xFD,0x23,0x18,0xFA};

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
	
	char* gb_rom;
	char* gb_wram;
	char* gb_sram;
	char* gb_vram;
	char* gb_fram;
	
	int IFF;
	
	unsigned gb_a_backup;
	unsigned gb_bcde_backup;
	unsigned gb_hl_backup;
	unsigned gb_sp_backup;
	unsigned gb_f_backup;
	char* gb_pc_backup;
};
	
struct gb_data* create_cpu()
{
	struct gb_data* cpu;
	char* fram;
	fram = malloc(4*1024 + sizeof(struct gb_data));
	cpu = (struct gb_data*)(fram + 4*1024);
	
	cpu->gb_rom = my_rom;
	cpu->gb_wram = malloc(8*1024);
	cpu->gb_sram = malloc(8*1024);
	cpu->gb_vram = malloc(8*1024);
	cpu->gb_fram = fram;
	
	cpu->pc_base = cpu->mem_map_0000 = cpu->mem_map_1000 = cpu->mem_map_2000 = cpu->mem_map_3000
	= cpu->mem_map_4000 = cpu->mem_map_5000 = cpu->mem_map_6000 = cpu->mem_map_7000 = cpu->gb_rom;
	
	cpu->mem_map_8000 = cpu->mem_map_9000 = cpu->gb_vram - 0x8000;
	
	cpu->mem_map_A000 = cpu->mem_map_B000 = cpu->gb_sram - 0xA000;
	
	cpu->mem_map_C000 = cpu->mem_map_D000 = cpu->gb_wram - 0xC000;
	
	cpu->mem_map_E000 = cpu->gb_wram - 0xE000;
	
	cpu->mem_map_F000 = cpu->gb_fram - 0xF000;
	
	cpu->IFF = 0;
	
	cpu->gb_a_backup = cpu->gb_bcde_backup = cpu->gb_hl_backup = cpu->gb_sp_backup = cpu->gb_f_backup = 0;
	cpu->gb_pc_backup = cpu->pc_base + 0x0000;
	
	return cpu;
}
	
void delete_cpu(struct gb_data* cpu)
{
	free(cpu->gb_wram);
	free(cpu->gb_sram);
	free(cpu->gb_vram);
	free(cpu->gb_fram); //This also frees the cpu object itself
}
	
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