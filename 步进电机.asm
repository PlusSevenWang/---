				.MODEL SMALL
EXTRN			InitKeyDisplay:NEAR, GetKeyA:NEAR, DisPlay8:NEAR
I08259_0		EQU		0250H
I08259_1		EQU		0251H
Con_8253		EQU		0263H
T0_8253			EQU		0260H
I08255_Con		EQU		0273H	;CS3
I08255_PC		EQU		0272H
				.STACK	100
				.DATA
StepControl		DB		0	;下一次送给步进电机的值
buffer			DB		8 DUP (0)	;显示缓冲区，8个字节
SpeedNo			DB		0	;选择哪一级速度
StepDelay		DB		0	;转动一步后，延时常数
StartStepDelay	DB		0	;若选择速度过快,延时由长到短，最终使用对应延时常数
StartStepDelayl	DB		0	;StartStepDelay
bFirst			DB		0	;有没有转动过步进电机
bClockwise		DB		0	;1顺时针方向 0逆时针方向转动
bNeedDisplay		DB		0	;已转动一步，需要显示新步数
StepCount		DW		0	;需要转动的步数
StepDelayTab	DB		250,125,83,62,50,42,36,32,28,25,22,21
				.CODE
START:			MOV	AX, @DATA
				MOV	DS, AX	
				MOV	ES, AX	
				NOP		
				CALL	InitKeyDisplay		;初始化键盘、数码管控制器（8255）
				MOV	bFirst, 1	;有没有转动过步进电机
				MOV	bClockwise, 1		;顺时针方向
				MOV	StepControl, 33H	;下一次送给步进电机的值
				MOV	SpeedNo, 5	;第五级速度
				CALL	Init8255
				CALL	Init8253
				CALL	Init8259
				CALL	Wrilntver
				MOV	buffer,0	;显示缓冲器初始化
				MOV	buffer+1, 0
				MOV	buffer+2, 0
				MOV	buffer+3, 0
				MOV	buffer+4, 10H
				MOV	AL, SpeedNo
				MOV	buffer+5, AL
				MOV	buffer+6, 10H
				MOV	buffer+7, 0
STAR2:			LEA		SI,buffer
				CALL	Display8
STAR3:			CALL	GetKeyA
				JB		STAR5
				CMP	bNeedDisplay, 0
				JZ		STAR3
				MOV	bNeedDisplay, 0
				CALL	Step_SUB_l
				JMP		STAR2
STAR5:			CLI		;终止步进电机转动
				CMP	AL, 10
				JNB		STAR1
				MOV	AH, buffer+2
				MOV	buffer+3, AH
				MOV	AH, buffer+1
				MOV	buffer+2, AH
				MOV	AH, buffer
				MOV	buffer+1, AH
				MOV	buffer, AL
				JMP		STAR2
STAR1:			CMP	AL, 14
				JNB		STAR2
				LEA		SI, DriverTab
				SUB		AL, 10
				SHL		AL, 1
				XOR		AH, AH
				MOV	BX, AX
				JMP		CS:WORD PTR [SI+BX]
DriverTab:		
				DW		Direction		;转动方向
				DW		Speed_up	;提高转速
				DW		Speed_Down	;降低转速
				DW		Exec			;步进电机根据方向、转速、步数开始转动
Direction:		CMP	bClockwise, 0
				JZ		Clockwise
				MOV	bClockwise, 0
				MOV	buffer+7, 1
AntiClockwise:	CMP	bFirst, 0
				JZ		AntiClockwisel
				MOV	StepControl, 91H
				JMP		Directionl
AntiClockwisel:	MOV	AL, StepControl
				MOV CL,2
				ROR		AL, CL			;****************
				MOV	StepControl, AL
				JMP		Directionl
Clockwise:		MOV	bClockwise, 1
				MOV	buffer+7, 0
CMP	bFirst, 0
				JZ		Clockwisel
				MOV	StepControl, 33H
				JMP		Directionl
Clockwisel:		MOV	AL, StepControl
				MOV CL,2
				ROL		AL, CL			;*************
				MOV	StepControl, AL
Directionl:		JMP		STAR2
Speed_up:		MOV	AL, SpeedNo
				CMP	AL, 11
				JZ		Speed_up2
Speed_upl:		INC		AL
				MOV	SpeedNo, AL
				MOV	buffer+5, AL
Speed_up2:		JMP		STAR2
Speed_Down:		MOV	AL, SpeedNo
				CMP	AL, 0
				JZ		SpeedDownl
				DEC		AL
				MOV	SpeedNo, AL
				MOV	buffer+5, AL
SpeedDownl:		JMP		STAR2
Exec:			MOV	bFirst, 0
				CALL	TakeStepCount
				LEA		BX, StepDelayTab
				MOV	AL,SpeedNo
				XLAT
				MOV	StepDelay, AL
				CMP	AL, 50
				JNB		Execl
				MOV	AL, 50
Execl:			MOV	StartStepDelay, AL
				MOV	StartStepDelayl, AL
				STI
				JMP		STAR2
TIMERO:			PUSH	AX
				PUSH	DX
				DEC		StartStepDelay
				JNZ		TIMERO_1
				MOV	AL, StartStepDelayl
				CMP	AL, StepDelay
				JZ		TIMER0_2
				DEC		AL
				MOV	StartStepDelayl, AL
 
TIMER0_2:		MOV	StartStepDelay, AL
				MOV	AL, StepControl
				MOV	DX, I08255_PC
				OUT		DX, AL
				CMP	bClockwise, 0
				JNZ		TIMER0_3
				ROR		AL, 1
				JMP		TIMER0_4
TIMER0_3:		ROL		AL, 1
TIMER0_4:		MOV	StepControl, AL
				CMP	StepCount, 0
				JZ		TIMERO_1
				MOV	bNeedDisplay, 1
				DEC		StepCount
				JNZ		TIMERO_1
				add		sp, 8	;小写部分不允许使用单步、单步进入命令
popf
cli
pushf	
				sub		sp, 8
nop	
TIMERO_1:		MOV	DX, I08259_0
				MOV	AL, 20H
				OUT		DX, AL
				POP		DX
				POP		AX
				IRET
Step_SUB_l		PROC	NEAR
				MOV	CX,4
				LEA		BX, buffer
Step_SUB_l_l:		DEC		BYTE PTR [BX]
				CMP	BYTE PTR [BX],0FFH
				JNZ		Step_SUB_l_2
				MOV	BYTE PTR [BX],9
				INC		BX
				LOOP	Step_SUB_l_l
Step_SUB_l_2:		RET	
Step_SUB_l		ENDP	
TakeStepCount	PROC	NEAR
				MOV	AL, buffer+3		;转动步数送入StepCount
				MOV	BX, 10
				MUL		BL
				ADD	AL,buffer+2
				MUL		BL
ADD	AL, buffer+1
ADC		AH, 0
MUL		BX
ADD	AL, buffer
ADC		AH,0
MOV	StepCount, AX
RET	

TakeStepCount	ENDP
Init8255 		PROC	NEAR
				MOV	DX, I08255_Con
				MOV	AL, 81H
				OUT	DX, AL	;8255 PC输出
				DEC	DX
				MOV	AL, 0FFH
				OUT	DX, AL	;0FFH->8255 PC
				RET

Init8255		ENDP
Init8253 		PROC	NEAR
MOV	DX, Con_8253
MOV	AL, 35H
OUT		DX, AL	;计数器TO设置在模式2状态,BCD码计数
MOV	DX, T0_8253
MOV	AL, 10H
OUT		DX, AL
MOV	AL, 02H
OUT		DX, AL	;CLK0/210
RET	

Init8253			ENDP
Init8259			PROC	NEAR
MOV	DX, I08259_0
MOV	AL, 13H
OUT		DX, AL
MOV	DX, I08259_1
MOV	AL, 08H
OUT		DX, AL
MOV	AL, 09H
OUT		DX, AL
MOV	AL, 0FEH
OUT		DX, AL
RET
Init8259			ENDP	
Wrilntver			PROC	NEAR
PUSH	ES
MOV	AX, 0
MOV	ES, AX
MOV	DI, 20H
LEA		AX, TIMERO
STOSW	
MOV	AX, CS
STOSW	
POP		ES
RET	

Wrilntver			ENDP	
END		START


