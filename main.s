;****************** main.s ***************
; Program written by: Fawadul Haq and Rafael Herrejon
; Date Created: 2/4/2017
; Last Modified: 9/2/2017
; Brief description of the program
;   The LED toggles at 8 Hz and a varying duty-cycle
; Hardware connections (External: One button and one LED)
;  PE1 is Button input  (1 means pressed, 0 means not pressed)
;  PE0 is LED output (1 activates external LED on protoboard)
;  PF4 is builtin button SW1 on Launchpad (Internal) 
;        Negative Logic (0 means pressed, 1 means not pressed)
; Overall functionality of this system is to operate like this
;   1) Make PE0 an output and make PE1 and PF4 inputs.
;   2) The system starts with the the LED toggling at 8Hz,
;      which is 8 times per second with a duty-cycle of 20%.
;      Therefore, the LED is ON for (0.2*1/8)th of a second
;      and OFF for (0.8*1/8)th of a second.
;   3) When the button on (PE1) is pressed-and-released increase
;      the duty cycle by 20% (modulo 100%). Therefore for each
;      press-and-release the duty cycle changes from 20% to 40% to 60%
;      to 80% to 100%(ON) to 0%(Off) to 20% to 40% so on
;   4) Implement a "breathing LED" when SW1 (PF4) on the Launchpad is pressed:
;      a) Be creative and play around with what "breathing" means.
;         An example of "breathing" is most computers power LED in sleep mode
;         (e.g., https://www.youtube.com/watch?v=ZT6siXyIjvQ).
;      b) When (PF4) is released while in breathing mode, resume blinking at 8Hz.
;         The duty cycle can either match the most recent duty-
;         cycle or reset to 20%.
;      TIP: debugging the breathing LED algorithm and feel on the simulator is impossible.
; PortE device registers
GPIO_PORTE_DATA_R  EQU 0x400243FC
GPIO_PORTE_DIR_R   EQU 0x40024400
GPIO_PORTE_AFSEL_R EQU 0x40024420
GPIO_PORTE_DEN_R   EQU 0x4002451C
; PortF device registers
GPIO_PORTF_DATA_R  EQU 0x400253FC
GPIO_PORTF_DIR_R   EQU 0x40025400
GPIO_PORTF_AFSEL_R EQU 0x40025420
GPIO_PORTF_PUR_R   EQU 0x40025510
GPIO_PORTF_DEN_R   EQU 0x4002551C
GPIO_PORTF_LOCK_R  EQU 0x40025520
GPIO_PORTF_CR_R    EQU 0x40025524
GPIO_LOCK_KEY      EQU 0x4C4F434B  ; Unlocks the GPIO_CR register
SYSCTL_RCGCGPIO_R  EQU 0x400FE608

     IMPORT  TExaS_Init
     THUMB
     AREA    DATA, ALIGN=2
;global variables go here
cc   SPACE   4
	
     AREA    |.text|, CODE, READONLY, ALIGN=2
     THUMB
     EXPORT  Start
		 
Start
 ; TExaS_Init sets bus clock at 80 MHz
     BL  TExaS_Init ; voltmeter, scope on PD3
	 
 ; Initialization goes here
     BL  PortF_E_Init
	 BL  LED_off            ; Make sure LED starts at off
     MOV R0, #0x00          ; Clear the click_check counter
     LDR R1, =cc
     STR R0, [R1]
	 
     CPSIE  I    ; TExaS voltmeter, scope runs on interrupts
loop  
; main engine goes here

      BL   DC_0
      BL   DC_20
	  BL   DC_40
	  BL   DC_60
	  BL   DC_80
	  BL   DC_100
	  B    loop
	  
; ~~~~~~~~~~~~~~~~~~~SUBROUTINES~~~~~~~~~~~~~~~~~ ;

                                   ; ; ; ; ; ; ; ; ;   
                                   ; Duty Cycle  0 ;
                                   ; ; ; ; ; ; ; ; ; 
								   
; Makes sure LED is off at beginning  
DC_0 
  PUSH {LR,R4}
	  LDR  R1, =GPIO_PORTE_DATA_R  ; Clearing LED Output
	  LDR  R0, [R1]
	  BIC  R0, R0, #0x01
      STR  R0, [R1]
loop_0	  
      BL   breathe
	  BL   check_click
	  ADDS R0, R0, #0x00
	  BEQ  loop_0
	  
  POP {LR,R4}
      BX   LR	  
	                               ; ; ; ; ; ; ; ; ; 
	                               ; Duty Cycle 20 ;
                                   ; ; ; ; ; ; ; ; ;
								   
; Creates Duty Cycle of 20% of 8 Hz
; Modifies: R0, R1, R2, (R3)

DC_20  
  PUSH {LR,R4}                     ; Preserve 8-byte alignment by pushing and popping an even number of registers
loop_20
      BL   breathe
      BL   check_click
	  ADDS R0, #0                  ; register used to check
	  BNE  return_20               ; compare, and if clicked, branch to "return"
	  
	  
	  BL   PortE_In
	  ORR  R2, R0, #0xFFFFFFFE     ; Get the output bit
      MVN  R2, R2                  ; Toggle output
      BIC  R0, R0, #0x01           ; Clear old output
      ADD  R0, R0, R2              ; Place new output
      BL   PortE_Out
      
	  ANDS R1, R0, #0x01           ; decide whether to stall high or low
	  BNE  stall_high20            ; 25 ms
	  B    stall_low20             ; 100 ms 


stall_high20            ; Delay for the high portion of 20% Duty Cycle: 25ms
	  MOV  R1, #5
stall_a
	  MOV  R0, #65000
stall_b
      SUBS R0, #1
	  BNE  stall_b
	  SUBS R1, R1, #1
      BNE  stall_a
	  
	  B    loop_20

stall_low20           ; Delay for the low portion of 20% Duty Cycle: 100ms
      MOV  R1, #35
stall_c
      MOV  R0, #65000
stall_d
      SUBS R0, R0, #1              ; Delay the toggle
      BNE  stall_d
      SUBS R1, R1, #1              ; Do this 20 times for 1/16 of a second
	  BNE  stall_c
	 
	  B    loop_20                   ; Branch back to check if switch is pressed 

return_20	  
  POP  {LR,R4}
      BX   LR     
	  
                                   ; ; ; ; ; ; ; ; ;
                                   ; Duty Cycle 40 ;
								   ; ; ; ; ; ; ; ; ;            
								   
; Creates Duty Cycle of 40% of 8 Hz;
DC_40
  PUSH {LR,R4}
loop_40
      BL   breathe
      BL   check_click
      ADDS R0, #0                  ; register used to check
	  BNE  return_40               ; compare, and if clicked, branch to "return"
	  
	  
	  BL   PortE_In
	  ORR  R2, R0, #0xFFFFFFFE     ; Get the output bit
      MVN  R2, R2                  ; Toggle output
      BIC  R0, R0, #0x01           ; Clear old output
      ADD  R0, R0, R2              ; Place new output
      BL   PortE_Out
      
	  ANDS R1, R0, #0x01           ; decide whether to stall high or low
	  BNE  stall_high40            ; 50 ms  
	  B    stall_low40             ; 75 ms


stall_high40            ; Delay for the high portion of Duty Cycle
	  MOV  R1, #12
stall_e
	  MOV  R0, #56000
stall_f
      SUBS R0, #1
	  BNE  stall_f
	  SUBS R1, R1, #1
      BNE  stall_e
	  
	  B    loop_40

stall_low40             ; Delay for the low portion of Duty Cycle
      MOV  R1, #18
stall_g
      MOV  R0, #56000
stall_h
      SUBS R0, R0, #1              ; Delay the toggle
      BNE  stall_h
      SUBS R1, R1, #1              ; Do this 20 times for 1/16 of a second
	  BNE  stall_g
	 
	  B    loop_40                   ; Branch back to check if switch is pressed 

return_40	  
  POP  {LR,R4}
      BX   LR     

                                   ; ; ; ; ; ; ; ; ;
                                   ; Duty Cycle 60 ;
								   ; ; ; ; ; ; ; ; ;            
								   
; Creates Duty Cycle of 60% of 8 Hz;
DC_60
  PUSH {LR,R4}
loop_60
      BL   breathe
      BL   check_click
      ADDS R0, #0                  ; register used to check
	  BNE  return_60               ; compare, and if clicked, branch to "return"
	  
	  
	  BL   PortE_In
	  ORR  R2, R0, #0xFFFFFFFE     ; Get the output bit
      MVN  R2, R2                  ; Toggle output
      BIC  R0, R0, #0x01           ; Clear old output
      ADD  R0, R0, R2              ; Place new output
      BL   PortE_Out
      
	  ANDS R1, R0, #0x01           ; decide whether to stall high or low
	  BNE  stall_high60            ; 75 ms  
	  B    stall_low60             ; 50 ms       


stall_high60            ; Delay for the high portion of Duty Cycle
	  MOV  R1, #29
stall_i
	  MOV  R0, #60000
stall_j
      SUBS R0, #1
	  BNE  stall_j
	  SUBS R1, R1, #1
      BNE  stall_i
	  
	  B    loop_60

stall_low60            ; Delay for the low portion of Duty Cycle
      MOV  R1, #11
stall_k
      MOV  R0, #60000
stall_l
      SUBS R0, R0, #1              ; Delay the toggle
      BNE  stall_l
      SUBS R1, R1, #1              ; 8 repeats = 25 ms
	  BNE  stall_k
	 
	  B    loop_60                 ; Branch back to check if switch is pressed 

return_60	  
  POP  {LR,R4}
      BX   LR 
	  
                                   ; ; ; ; ; ; ; ; ;
                                   ; Duty Cycle 80 ;
								   ; ; ; ; ; ; ; ; ;     
								   
; Creates Duty Cycle of 80% of 8 Hz;
DC_80
  PUSH {LR,R4}
loop_80
      BL   breathe
      BL   check_click
      ADDS R0, #0                  ; register used to check
	  BNE  return_80               ; compare, and if clicked, branch to "return"
	  
	  
	  BL   PortE_In
	  ORR  R2, R0, #0xFFFFFFFE     ; Get the output bit
      MVN  R2, R2                  ; Toggle output
      BIC  R0, R0, #0x01           ; Clear old output
      ADD  R0, R0, R2              ; Place new output
      BL   PortE_Out
      
	  ANDS R1, R0, #0x01           ; decide whether to stall high or low
	  BNE  stall_high80  
	  B    stall_low80


stall_high80         ; Delay for the high portion of Duty Cycle
	  MOV  R1, #40
stall_m
	  MOV  R0, #61800
stall_n
      SUBS R0, #1
	  BNE  stall_n
	  SUBS R1, R1, #1
      BNE  stall_m
	  
	  B    loop_80

stall_low80          ; Delay for the low portion of Duty Cycle
      MOV  R1, #10
stall_o
      MOV  R0, #61800
stall_p
      SUBS R0, R0, #1              ; Delay the toggle
      BNE  stall_p
      SUBS R1, R1, #1              ; 8 repeats = 25 ms
	  BNE  stall_o
	 
	  B    loop_80                   ; Branch back to check if switch is pressed 

return_80	  
  POP  {LR,R4}
      BX   LR 
	  
	                               ; ; ; ; ; ; ; ; ; ;
                                   ; Duty Cycle 100  ;
								   ; ; ; ; ; ; ; ; ; ;            
								   
; Creates Duty Cycle of 100% of 8 Hz;
DC_100 
  PUSH {LR,R4}
      
	  LDR  R1, =GPIO_PORTE_DATA_R 
	  LDR  R0, [R1]
	  ORR  R0, R0, #0x01
      STR  R0, [R1]
loop_100	  
      BL   breathe
	  LDR  R1, =GPIO_PORTE_DATA_R 
	  LDR  R0, [R1]
	  ORR  R0, R0, #0x01
      STR  R0, [R1]
	  BL   check_click
	  ADDS R0, R0, #0x00
	  BEQ  loop_100
	  
  POP  {LR,R4}
      BX   LR
	                               ; ; ; ; ; ; ; ; ; ;
	                               ;     Breathe     ;
								   ; ; ; ; ; ; ; ; ; ;
									
; Activates "breathing" LED for as long as PF4 is low
; PF4 negative logic: 0 if pressed, 1 if not pressed
; Modifies:
breathe
  PUSH {LR,R4,R5,R6,R7,R8}
 
;;;;;;;;;;;;;;;;;;;;;
 BL   check_breathe ;  
 ADDS R0, R0, #0x00 ;
 BNE  return_breathe;
;;;;;;;;;;;;;;;;;;;;; 
					MOV  R3, #1                  ; Initializing the stalling registers
					MOV  R4, #39
					MOV  R5, #1
					MOV  R6, #-1 

loop_breathe      	
                    
;;;;;;;;;;;;;;;;;;;;;
 BL   check_breathe ;
 ADDS R0, R0, #0x00 ;
 BNE  return_breathe;	  
;;;;;;;;;;;;;;;;;;;;;

                 ; Starting new DC ;
                    MOV  R7, #10                 ; Do current DC for X number iterations
					ADDS R3, R3, R5              ; If either R3 or R4 become 0,
					BEQ  min_up                  ; it's time to go backwards
					ADDS R4, R4, R6
					BEQ  max_down

continue_DC         ADDS R7, R7, #0
                    BEQ  loop_breathe
					
                    BL   PortE_In
	                ORR  R2, R0, #0xFFFFFFFE     ; Get the output bit
                    MVN  R2, R2                  ; Toggle output
                    BIC  R0, R0, #0x01           ; Clear old output
                    ADD  R0, R0, R2              ; Place new output
                    BL   PortE_Out
	  
                    ANDS R1, R0, #0x01           ; decide whether to stall high or low
                    BNE  stall_high_b 
                    B    stall_low_b

stall_high_b        MOV  R1, R3
stall_y             MOV  R0, #1000 ; <-- decrease for 80 Hz
stall_q             SUBS R0, #1
	                BNE  stall_q
	                SUBS R1, R1, #1              ; R3 is high stall counter 
                    BNE  stall_y                   
					B    continue_DC
					
stall_low_b         MOV  R1, R4
stall_x             MOV  R0, #1000
stall_r             SUBS R0, #1
                    BNE  stall_r
					SUBS R1, R1, #1              ; R4 is low stall counter
					BNE  stall_x
					SUB  R7, R7, #1              ; a DC iteration after end of every low
;;;;;;;;;;;;;;;;;;;;; 
 BL   check_breathe ;
 ADDS R0, R0, #0x00 ;
 BNE  return_breathe;	  
;;;;;;;;;;;;;;;;;;;;;
					B    continue_DC

min_up              MVN  R5, R5                  ; Now, we add the stall registers in the
                    ADD  R5, #1                  ; opposite direction by switching the signs
                    MVN  R6, R6                  ; of their in- and de-crement registers
					ADD  R6, #1
					BL   LED_off                 ; in this case, keep the LED off for a while
					; stalling a little
					MOV  R1, #10
stall_s             MOV  R0, #1000
stall_t             SUBS R0, #1
	                BNE  stall_t
	                SUBS R1, R1, #1
                    BNE  stall_s
					; reinitialize the registers
					MOV  R3, #1
					MOV  R4, #39
					
					B    continue_DC
					
max_down            MVN  R5, R5                  
                    ADD  R5, #1                  
                    MVN  R6, R6
					ADD  R6, #1
					BL   LED_on
					; stalling a little
					MOV  R1, #10
stall_u             MOV  R0, #1000
stall_v             SUBS R0, #1
	                BNE  stall_v
	                SUBS R1, R1, #1
                    BNE  stall_u
					; reinitialize the registers, but backwards
					MOV  R3, #39
					MOV  R4, #1
					
					B    continue_DC

return_breathe
  POP  {R8,R7,R6,R5,R4,LR}
      BX   LR
      	  
	
;------------check_click-------------
; Checks if the button PE1 was pressed AND released too
; Keeps track of a counter that tells if the button was pressed since
; before the beginning of the subroutine
; Modifies: R1, R2, R3
; Inputs: none
; Output: R0, 1 if yes, 0 if no
check_click

      LDR  R3, =cc                   ; Address of click counter
      LDR  R1, =GPIO_PORTE_DATA_R    
	  
; check for button pressed already (cc=#1)
      LDR  R0, [R3]
	  ADDS R0, #0
	  BNE  release                   ; If pressed alread, check for released
	 
; check for new press
	  LDR  R0, [R1]                  ; Read and check PE1
	  ANDS R2, R0, #0x02             
	  BEQ  no_click                  
	  MOV  R2, #0x01
	  STR  R2, [R3]
	  
release
      LDR  R0, [R1]                  ; Check if released now
      ANDS R2, R0, #0x02
	  BNE  no_click
	  MOV  R0, #0x00                 ; Clear counter
	  STR  R0, [R3]
	  MOV  R0, #0x01                 ; yes signal
	  BX   LR

no_click
      MOV  R0, #0x00                 ; no signal	  
	  BX   LR

;-----------check_breathe------------
; Checks PF4 and returns whether its button
; (negative logic) is high or low
; If button is pressed (PF4 = 0), R0 = 0
; If button isn't pressed (PF4 = 1), R0 = 1
; Inputs: none
; Outputs: R0 (1 or 0)
; Modifies: R0, R1
check_breathe
      LDR  R1, =GPIO_PORTF_DATA_R
	  LDR  R0, [R1]
	  ANDS R0, R0, #0x10             ; check PF4
	  BEQ  return_check_breathe      ; If PF4 = zero, that will be the output anyway
	  MOV  R0, #0x01
return_check_breathe
      BX   LR

;------------LED_off-----------------
; Turns the LED on Port E off
; Modifies: R0, R1
LED_off
      LDR  R1, =GPIO_PORTE_DATA_R
	  LDR  R0, [R1]
	  BIC  R0, #0x01
	  STR  R0, [R1]
	  BX   LR
	  
;------------LED_on------------------
; Turns the LED on Port E on (full brightness)
; Modifies: R0, R1
LED_on
      LDR  R1, =GPIO_PORTE_DATA_R
	  LDR  R0, [R1]
	  ORR  R0, #0x01
	  STR  R0, [R1]
	  BX   LR

;------------PortE_In----------------
; Returns R0 with the value of Port E's Data register
PortE_In
      LDR  R1, =GPIO_PORTE_DATA_R
	  LDR  R0, [R1]
      BX   LR

;------------PortE_Out---------------
; Stores R0 into the Port E Data register
PortE_Out 
      LDR  R1, =GPIO_PORTE_DATA_R
	  STR  R0, [R1]
      BX   LR

;------------PortF_E_Init------------
; Initialize GPIO Port F for negative logic switches on PF0 and
; PF4 as the Launchpad is wired.  Weak internal pull-up
; resistors are enabled, and the NMI functionality on PF0 is
; disabled.  Make the RGB LED's pins outputs.
; Initialize GPIO Port E. PE1 is positive logic input. 
; and PE0 is positive logic output.
; Input: none
; Output: none
; Modifies: R0, R1, R2
PortF_E_Init
    LDR R1, =SYSCTL_RCGCGPIO_R      ; 1) activate clock for Port F and E
    LDR R0, [R1]
    ORR R0, R0, #0x30               ; set bit 5 and 6 to turn on clock
    STR R0, [R1]
    NOP
    NOP                             ; allow time for clock to finish
    LDR R1, =GPIO_PORTF_LOCK_R      ; 2) unlock the lock register
    LDR R0, =0x4C4F434B             ; unlock GPIO Port F Commit Register
    STR R0, [R1]
    LDR R1, =GPIO_PORTF_CR_R        ; enable commit for Port F
    MOV R0, #0xFF                   ; 1 means allow access
    STR R0, [R1]
   ;LDR R1, =GPIO_PORTF_AMSEL_R     ; 3) disable analog functionality
   ;MOV R0, #0                      ; 0 means analog is off
   ;STR R0, [R1]
   ;LDR R1, =GPIO_PORTF_PCTL_R      ; 4) configure as GPIO
   ;MOV R0, #0x00000000             ; 0 means configure Port F as GPIO
   ;STR R0, [R1]
    LDR R1, =GPIO_PORTF_DIR_R       ; 5) set direction register
    MOV R0,#0x0E                    ; PF0 and PF7-4 input, PF3-1 output
    STR R0, [R1]
    LDR R1, =GPIO_PORTF_AFSEL_R     ; 6) regular port function
    MOV R0, #0                      ; 0 means disable alternate function
    STR R0, [R1]
    LDR R1, =GPIO_PORTF_PUR_R       ; pull-up resistors for PF4,PF0
    MOV R0, #0x11                   ; enable weak pull-up on PF0 and PF4
    STR R0, [R1]
    LDR R1, =GPIO_PORTF_DEN_R       ; 7) enable Port F digital port
    MOV R0, #0xFF                   ; 1 means enable digital I/O
    STR R0, [R1]
;PortE_Init
    LDR R1, =GPIO_PORTE_DIR_R       ; 1) set direction register
    MOV R0,#0x01                    ; PE1 input, PE0 output
    STR R0, [R1]
	LDR R1, =GPIO_PORTE_DEN_R       ; 3) enable Port E digital port
    MOV R0, #0x03                   ; 1 means enable digital I/O
    STR R0, [R1]
    BX  LR


     ALIGN      ; make sure the end of this section is aligned
     END        ; end of file

