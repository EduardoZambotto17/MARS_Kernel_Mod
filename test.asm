# SPIM S20 MIPS simulator.
# The default exception handler for spim.
#
# Copyright (C) 1990-2004 James Larus, larus@cs.wisc.edu.
# ALL RIGHTS RESERVED.
#
# SPIM is distributed under the following conditions:
#
# You may make copies of SPIM for your own use and modify those copies.
#
# All copies of SPIM must retain my name and copyright notice.
#
# You may not sell SPIM or distributed SPIM in conjunction with a commerical
# product or service without the expressed written consent of James Larus.
#
# THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE.
#
# 28/06/2025 (Ney Calazans)
#	- ATTENTION - For this code to compile in Mars, unset the check box
#		"Include this exception handler file in all assembler operations"
#		in the menu option "Settings --> Exception Handler...".
#	- This code was modified from the original one by James Larus, 
#		mostly to enable its use with the Mars compact memory model, see
#		detailed comments below.
# $Header: $


# Define the exception handling code.  This must go first!

	.kdata
__m1_:	.asciiz "  Exception "
__m2_:	.asciiz " occurred and ignored\n"
__e0_:	.asciiz "  [Interrupt] "
__e1_:	.asciiz	"  [TLB]"
__e2_:	.asciiz	"  [TLB]"
__e3_:	.asciiz	"  [TLB]"
__e4_:	.asciiz	"  [Address error in inst/data fetch] "
__e5_:	.asciiz	"  [Address error in store] "
__e6_:	.asciiz	"  [Bad instruction address] "
__e7_:	.asciiz	"  [Bad data address] "
__e8_:	.asciiz	"  [Error in syscall] "
__e9_:	.asciiz	"  [Breakpoint] "
__e10_:	.asciiz	"  [Reserved instruction] "
__e11_:	.asciiz	""
__e12_:	.asciiz	"  [Arithmetic overflow] "
__e13_:	.asciiz	"  [Trap] "
__e14_:	.asciiz	""
__e15_:	.asciiz	"  [Floating point] "
__e16_:	.asciiz	""
__e17_:	.asciiz	""
__e18_:	.asciiz	"  [Coproc 2]"
__e19_:	.asciiz	""
__e20_:	.asciiz	""
__e21_:	.asciiz	""
__e22_:	.asciiz	"  [MDMX]"
__e23_:	.asciiz	"  [Watch]"
__e24_:	.asciiz	"  [Machine check]"
__e25_:	.asciiz	""
__e26_:	.asciiz	""
__e27_:	.asciiz	""
__e28_:	.asciiz	""
__e29_:	.asciiz	""
__e30_:	.asciiz	"  [Cache]"
__e31_:	.asciiz	""
__excp:	.word __e0_, __e1_, __e2_, __e3_, __e4_, __e5_, __e6_, __e7_, __e8_, __e9_
	.word __e10_, __e11_, __e12_, __e13_, __e14_, __e15_, __e16_, __e17_, __e18_,
	.word __e19_, __e20_, __e21_, __e22_, __e23_, __e24_, __e25_, __e26_, __e27_,
	.word __e28_, __e29_, __e30_, __e31_
s1:	.word 0
s2:	.word 0

# This is the exception handler code that the processor runs when
# an exception occurs. It only prints some information about the
# exception, but can serve as a model of how to write a handler.
#
# Because we are running in the kernel, we can use $k0/$k1 without
# saving their old values.

#
# Exception vector address choice. 
#	Uncomment one of the the applicable lines below
#
# Below is the exception vector address for MIPS-1 (R2000):
#	.ktext 0x80000080
# Below is the exception vector address for MIPS32:
#	.ktext 0x80000180
# 25/06/2025 (Ney Calazans)
# Below is the exception vector address for the compact memory model of Mars
	.ktext 0x00004000
	
# Select the appropriate one for the mode in which SPIM is compiled.
	.set noat
k_start:
	move $k1 $at		# Save $at
	.set at
	sw $v0 s1		# This code is not re-entrant, we can't trust $sp
	sw $a0 s2		# But, we need to use these registers

	mfc0 $k0 $13		# Cause register
	srl $a0 $k0 2		# Extract ExcCode Field
	andi $a0 $a0 0xf

	# Print information about exception.
	#
	li $v0 4		# syscall 4 (print_str)
	la $a0 __m1_
	syscall

	li $v0 1		# syscall 1 (print_int)
	srl $a0 $k0 2		# Extract ExcCode Field
	andi $a0 $a0 0xf
	syscall

	li $v0 4		# syscall 4 (print_str)
	andi $a0 $k0 0x3c
	lw $a0 __excp($a0)
	nop
	syscall

	bne $k0 0x18 ok_pc	# Bad PC exception requires special checks
	nop

	mfc0 $a0 $14		# EPC
	andi $a0 $a0 0x3	# Is EPC word-aligned?
	beq $a0 0 ok_pc
	nop

	li $v0 10		# Exit on really bad PC
	syscall

ok_pc:
	li $v0 4		# syscall 4 (print_str)
	la $a0 __m2_
	syscall

	srl $a0 $k0 2		# Extract ExcCode Field
	andi $a0 $a0 0xf
	bne $a0 0 ret		# 0 means exception was an interrupt
	nop

# Interrupt-specific code goes here!
# Don't skip instruction at EPC since it has not executed.


ret:
# Return from (non-interrupt) exception. Skip offending instruction
# at EPC to avoid infinite loop.
#
	mfc0 $k0 $14		# Bump EPC register
	addiu $k0 $k0 4		# Skip faulting instruction
				# (Need to handle delayed branch case here)
	mtc0 $k0 $14


# Restore registers and reset procesor state
#
	.set noat
	move $at $k1		# Restore $at
	.set at
	lw $v0 s1		# Restore other registers
	lw $a0 s2

	mtc0 $0 $13		# Clear Cause register

	mfc0 $k0 $12		# Set Status register
	ori  $k0 0x1		# Interrupts enabled
	mtc0 $k0 $12

# Return from exception on MIPS32:
k_end:	eret

# Return sequence for MIPS-I (R2000):
#	rfe			# Return from exception handler
				# Should be in jr's delay slot
#	jr $k0
#	 nop



# Standard startup code.  Invoke the routine "main" with arguments:
#	main(argc, argv, envp)
#
	.text
	.globl __start
__start:
	lw $a0 0($sp)		# argc
	addiu $a1 $sp 4		# argv
	addiu $a2 $a1 4		# envp
	sll $v0 $a0 2
	addu $a2 $a2 $v0

# 	25/06/2025
#	Line below commented by Ney Calazans to enable the exception handler assembly to succeed
	jal main
	nop

	li $v0 10
	syscall			# syscall 10 (exit)

	.globl __eoth
__eoth:

# 	19/07/2025 (Ney Calazans)
#	This a trial code to dump the contents of the kernel text memory for the
#	MARS simulator. 
#	Why doing this? Because the MARS simulator does not has a built-in "Dump 
#	Memory" option for this text code 
#
main:	la	$a0,ktext_filename	# get kernel text filename
	li	$a1,9			# set file flag to Create&Append 
	li	$a2,0			# set mode to 0, MARS ignore it, anyway
	li	$v0,13			# set syscall code to Open File service
	syscall				# and create the file
	sltiu	$t0,$v0,3		# if file descriptor is <3, something wrong happened
	bnez	$t0,fileCrErr		# jump if file creation did not succeeded
# When here, file creation succeeded, let us write to it
	move	$s0,$v0			# save valid file descriptor to $s0
	move	$a0,$s0			# prepare file writing with file descriptor
	la	$a1,kc_header		# prepare the output buffer pointer
	li	$a2,12			# no. of chars to write, size of header line kc_header
	li	$v0,15			# set syscall code to Write to File service
	syscall				# and write first file line
	bltz	$v0,fileWrErr		# jump if file write resulted in error
# When here, file created and written with first line.
#	Now, starts writing the kernel text to it
	la	$s1,k_start		# generate pointer to the kernel text start
	la	$s2,k_end		# generate pointer to the kernel text end
	addiu	$s2,$s2,1		# increment kernel text pointer after end
wr_linl:				# Start of the line write loop 
	slt	$t0,$s2,$s1		# while $s1 points to a valid kernel text address, do
	bne	$t0,$zero,end_kt	#	at the end, leave write line loop
	
	move	$a0,$s0			# if not, prepare file writing descriptor
	la	$a1,hex_prefix		# prepare the output buffer pointer to "0x"
	li	$a2,2			# no. of chars to write, size of hex_prefix
	li	$v0,15			# set syscall code to Write to File service
	syscall				# and write kernel text address hex prefix
	
	addiu	$sp,$sp,-8		# allocate 2 words in the stack
	sw	$s1,4($sp)		# at the stack bottom put kernel text address to treat
	sw	$ra,0($sp)		# at the stack top save current return address
	jal 	HexVal_tr		# go treat the kernel address value
	lw	$ra,0($sp)		# retrieve the return address saved on the stack
	lw	$a1,4($sp)		# retrieve the pointer to the generated string
	addiu	$sp,$sp,8		# deallocate the stack
	move	$a0,$s0			# prepare file writing with file descriptor
	li	$a2,8			# no. of chars to write, size of hex data string
	li	$v0,15			# set syscall code to Write to File service
	syscall				# and write current kernel text address
	
	move	$a0,$s0			# Now, prepare file writing descriptor
	la	$a1,two_sps_hp		# prepare the output buffer pointer to "  0x"
	li	$a2,4			# no. of chars to write, size of two_sps_hp
	li	$v0,15			# set syscall code to Write to File service
	syscall				# and write kernel text data hex prefix
	
	addiu	$sp,$sp,-8		# allocate 2 words in the stack
	lw	$t0,0($s1)		# get data pointed to by current kernel text address
	sw	$s1,4($sp)		# at the stack bottom put kernel text data to treat
	sw	$ra,0($sp)		# at the stack top save current return address
	jal 	HexVal_tr		# go treat the kernel data value
	lw	$ra,0($sp)		# retrieve the return address saved on the stack
	lw	$a1,4($sp)		# retrieve the pointer to the generated string
	addiu	$sp,$sp,8		# deallocate the stack
	move	$a0,$s0			# prepare file writing with file descriptor
	li	$a2,8			# no. of chars to write, size of hex data string
	li	$v0,15			# set syscall code to Write to File service
	syscall				# and write current kernel text data
	
	move	$a0,$s0			# prepare file writing descriptor
	la	$a1,newline		# prepare the output buffer pointer to "\n"
	li	$a2,1			# no. of chars to write, size of hex_prefix
	li	$v0,15			# set syscall code to Write to File service
	syscall				# and write the newline char
	# Here, the loop maintenance instructions
	addiu	$s1,$s1,4		# update pointer to the next kernel memory line
	j	wr_linl
end_kt:
endprog:

# Routine to deal with 32-bit hexadecimal address and data
HexVal_tr:
	# Test code to see if file structure is correctly generated
	la	$t0,Hexval_tp		# retrieve hex treatment text buffer
	sw	$t0,4($sp)		# return it below the top of the stack
	# En of test code to see if file structure is correctly generated
	jr	$ra			# return from hex value treatment
	
# When here, close the file, and leave
	move	$a0,$s0			# get saved file descriptor
	li	$v0,16			# set syscall code to Close File service
	syscall				# and close the the file
	jr	$ra
# End of program here
fileCrErr:				# File Creation error treatment 
	la	$a0,CrErr_text
	li	$v0,4
	syscall
	j	endprog
fileWrErr:				# File Write error treatment 
	la	$a0,CrErr_text
	li	$v0,4
	syscall
	j	endprog

	
# Standard Data Segment memory region.
#
		.data
ktext_filename:	.asciiz		"kerneltext.txt"
# Ney Calazans (20/07/2025) - For now, I only managed to create the file
# 	on the folder MARS run. I will later see if it is possible to change this.
kc_header:	.asciiz		"Kernel Code\n"		# First line of kernel text file 
hex_prefix:	.asciiz		"0x"			# Prefix to line address
two_sps_hp:	.asciiz		"  0x"			# Prefix to data contents
newline:	.asciiz		"\n"			# End-of-Line char
CrErr_text:	.asciiz		"File creation error!\n"
WrErr_text:	.asciiz		"File write error!\n"
Hexval_tp:	.asciiz		"00000000"		# For now just a valid test string
