; Declare a code data AREA, which allows the linker 
 ; to allocate the code segment memory space 
 ; Name it Printer 
 
 AREA Printer, CODE, READONLY 
 
 ; Import some routines from a library to allow printing 
 IMPORT PrintHex 
 IMPORT PrintString 
 IMPORT PrintChar 
 IMPORT PrintHello 
 IMPORT PrintDecimal
 IMPORT fputc 
 
 IMPORT SystemInit ; link to C code 
 EXPORT Reset_Handler ; export the reset handler’s address to C 
 EXPORT SVC_Handler
 THUMB
 PRESERVE8
ENTRY ; indicate to the linker where to start the code 
 
Reset_Handler ; also indicate where to start 
 BL SystemInit ; Invoke C code to configure the SoC correctly 
 
Start ; user code label for the start (optional) 
 ;main
 
 ;initialise process stack 
 LDR r1, =0x20010000
 MSR PSP, r1
 
 ;initialise baseId
 MOV r0, #0
 push{r0} ;push main id
 push{r1} ;push last main stack position
 push{r0} ;push lastid
 push{r0} ;push lastid
 
 LDR r0, =osrunning
 BL PrintString ;we're still in handler mode, so we're allowed to directly access print

 ; And re-print it on the terminal 
 BL Mode_Switch 
 
 ;test PrintDecimal
 ;MOV r0, #50012
 ;SVC 2
 
 LDR r1, =ProcessTable; initialise counter 
 ;LDR r2, =ProcessTable 
 LDR r3, =ProcessTableEnd
 
MainLoopStart
 
 ;LDR r0, [r2, r1, LSL #2]
 CMP r1, r3 ; compare the chosen address with the final address of the table
 ;BLGT Err_ProcessOutOfRange; if we're at an invalid process id, error out
 BGE MainLoopEnd ; if we're at the end of the table, finish 
 LDR r0, [r1]
 SVC 5 
 ADD r1, r1, #4; increment counter
 B MainLoopStart
MainLoopEnd
 
 LDR r0, =osfinishing
 SVC 4
 
 B Stop
 
SVC_Handler
 ;MOV r0, #0xbeef
 PUSH{lr}
 PUSH{lr}
 ;BL PrintHex
 MOV r3, r0
 ;get SVC operand
 TST lr, #4
 ITE eq ; check which mode we came from
 MRSEQ r0, MSP ; load the relevant stack pointer
 MRSNE r0, PSP
 LDR r1, [r0, #24] ; stacked PC
 LDRB r1, [r1, #-2] ; get SVC instruction’s operand
 
 LDR r2, =SVCTable 
 LDR r0, [r2, r1, LSL #2] 
 LDR r1, =SVCTableEnd
 CMP r0, r1 ; compare the chosen address with the final address of the table
 ;PUSH{r0}
 BLGT Err_SVCOutOfRange
 MOV r1, r0
 MOV r0, r3
 BLX r1
 
 POP{lr}
 POP{lr}
 ;MOV r2, #4
 ;POP{r0}
 ;MOV r0, #42
 ;PUSH{r0}
 BX lr
 
SVC_Kill
 pop{r0} ;pop lr from SVC_Handler
 pop{r0} ;pop lr from SVC_Handler
 pop{r1} ;pop id counter
 pop{r1} ;pop id counter
 pop{r2, r3}; pop data about current process, to throw away
 mov r2, r0
 pop{r0}; get current process stack pointer
 push{r0}; put it back so the stack is preserved
 push{r1}; return id counter to stack
 push{r1}; return id counter to stack
 push{r2} ;return lr
 push{r2} ;return lr
 ;we are now done with the main stack 
 
 ;resume last process here
 
 LDMFD r0!, {r11, r10, r9, r8, r7, r6, r5, r4} ;restore other registers
 
 MSR PSP, r0; update PSP. there is no longer any way of recovering the old process directly 
 
 ;normal recovery should now be in play

 BX lr
 
;create the process addressed by r0
SVC_Create
 ;get lr saved by previous
 pop{r3}
 pop{r3}
 ;get the id
 pop{r1}
 pop{r1}
 ADD r1, #1 ;r1 now contains my id 
 
 ;work on the process stack
 MRS r2, PSP
 ;MOV r4, #0x5464
 STMFD r2!, {r11, r10, r9, r8, r7, r6, r5, r4} ;push all remaining registers to stack
 
 ;r5 is saved, so we can reuse it
 MOV r5, r3
 
 pop{r9}; dispose of the previous stackpointer for the *current* process
 ;put the final sp in r2 
 push{r2} ;update it 
 
 LDR r3, =0x20010000
 
 MOV r4, #400
 MUL r4, r4, r1
 
 ADD r2, r3, r4
 
 push{r1, r2} ;add my id and initial sp (this value doesnt matter while I'm running) to MSP`
 push{r1} ;update the last id value
 push{r1}
 push{r5}
 push{r5}
 ;we are now done with updating the main stack
 
 ;work on the process stack
 
 ;at this point, 
 ;0xFFFFFFFF default LR
 ;0x01000000 default xPSR
 MOV r6, #0x01000000; put default xPSR value in r0 
 MOV r5, r0 ;put new pc in r5
 MOV r4, #0xFFFFFFFF; put default LR value in r0
 MOV r7, r2
 ;reset remaining main registers
 MOV r0, #1
 MOV r1, #2
 MOV r2, #3
 MOV r3, #0  
 
 
 STMFD r7!, {r6, r5, r4}
; STMFD r7!, {r12, r6, r5, r4}
 STMFD r7!, {r12, r3, r2, r1, r0}
; STMFD r7!, {r0, r1, r2}
 MSR PSP, r7 ;update the stack pointer
 
 ;reset all registers that won't be overwritten
 MOV r4, #0
 MOV r5, #0
 MOV r6, #0
 MOV r7, #0
 MOV r8, #0
 MOV r9, #0
 MOV r10, #0
 MOV r11, #0 
 
 ;return to our newly created process, via the SVC_Handler
 BX lr
 
Switch ;put the address of the corresponding process into r0
 ;POP{r0}
 MOV r1, r0 ;move the id, so we can overwrite r0
 LDR r2, =ProcessTable 
 LDR r0, [r2, r1, LSL #2] 
 LDR r1, =ProcessTableEnd
 CMP r0, r1 ; compare the chosen address with the final address of the table
 ;PUSH{r0}
 BLGT Err_ProcessOutOfRange
 BX lr 

Mode_Switch 
 MOV r0, #0x2 ; set stack to PSP 
 MSR CONTROL, r0 ; do it 
 ISB ; wait for it to be done 
 
 MOV r0, #0x03 ; set privilege level to User. 
 ; N.B. Cannot combine this to single MSR instruction with 
 ; above PSP change when using RVDS ISSM!! 
 MSR CONTROL, r0 
 ISB 
 BX lr
 
HelloWorld
 LDR r0, =helloworld
 SVC 4
 SVC 0
 
HelloMars
 LDR r0, =hellomars
 SVC 4
 SVC 0
 
HelloGalaxy
 LDR r0, =hellogalaxy
 SVC 4
 SVC 0
 
Err_ProcessOutOfRange 
 LDR r0, =procoutofrangerr 
 SVC 4
 BL Stop
 
Err_SVCOutOfRange 
 LDR r0, =svcoutofrangerr 
 SVC 4
 BL Stop

 ; ================ 
 ; End your program 
 ; ================ 
Stop 
 B Stop 
 
 ; Declare some strings to be printed out 
 ; These are constants and represent the data area 
 ALIGN
ProcessTable
 DCD HelloWorld
 DCD HelloMars
 DCD HelloGalaxy
ProcessTableEnd

SVCTable
 DCD SVC_Kill
 DCD PrintHex
 DCD PrintDecimal
 DCD PrintChar
 DCD PrintString
 DCD SVC_Create
SVCTableEnd

youlike 
 DCB "You like: ",0 

osrunning 
 DCB "OS running",0 

osfinishing 
 DCB "Goodbye!",0 
 
helloworld 
 DCB "Hello, world!",0  
 
hellomars 
 DCB "Hello, mars!",0  
 
hellogalaxy
 DCB "Hello, galaxy!",0  
 
procoutofrangerr
 DCB "Error: requested process id is out of range",0  

svcoutofrangerr
 DCB "Error: requested SVC id is out of range",0  
 ALIGN 
 
 
 END 