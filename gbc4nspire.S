	.include "defines.inc"
	
	.asciz "PRG"
	.global main
main:
	@save registers
	stmfd sp!,{r4-r11,lr}
	@update opcode table for position-independent code. ONLY DO THIS ONCE
	bl update_opcode_table
	@save os state
	bl save_os_state
	@create cpu
	bl create_cpu
	str r0,a_cpu
	
mainloop:
	ldr r0,a_cpu
	mov r1,#1	@Execute at least 1 cycle
	bl run_cpu
	b mainloop
	
	@delete cpu
	ldr r0,a_cpu
	bl delete_cpu
	@restore os state
	bl restore_os_state
	@restore registers and return
	ldmfd sp!,{r4-r11,pc}
	
a_cpu:
	.long 0
	
update_opcode_table:
	adr r0,main
	adrl r1,opcode_table
	mov r2,#256
1:
	ldr r3,[r1]
	subs r2,r2,#1
	add r3,r3,r0
	str r3,[r1],#4
	bne 1b
	bx lr
	
	.include "memory.S"
	.include "cpu.S"