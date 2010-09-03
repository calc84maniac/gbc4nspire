	.include "defines.inc"
	
	.asciz "PRG"
	.global main
main:
	#save registers
	stmfd sp!,{r4-r11,lr}
	bl save_os_state
	bl restore_os_state
	#restore registers and return
	ldmfd sp!,{r4-r11,pc}
	
	.include "cpu.S"