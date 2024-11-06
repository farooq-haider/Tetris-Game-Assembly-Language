[org 0x0100]
jmp start

score: db 'SCORE', 0
score_count: dw -10
time: db 'TIME', 0

tickcount: dw 0 ;controls the number of times int 8 (timer interrupt) occurs
minute_count: dw 0
second_count: dw -1

begin1: db 'Welcome to Tetris, An Old but Fun little Adventure.', 0
begin2: db 'Here are some Instructions to Help You out:', 0
instruct1: db '1) Use the left and right arrow keys to move the shapes.',0
instruct2: db '2) Time Limit: 5 minutes (Game will automatically end after 5 minutes).',0
instruct3: db '3) Pop 10 score will be added for every completed line.',0
current: dw 3
next_shape: dw 4

upcoming: db 'UPCOMING',0
shape: db 'SHAPE',0

end1: db 'Thank You for Playing, we hope you enjoyed the experience!',0
final_score: db 'FINAL SCORE',0
final_time: db 'FINAL TIME',0

Flag: db 1  ;flag = 0 corresponds to the end of game 

Launch:
	push bx
	push ax
	push di
	push es
	xor ax,ax  
	mov es,ax ;initialising ES to the start of IVT table
	
	;saving origional segments and offsets of default interrupt services 8 and 9:
	push word[es:9*4] 
	push word[es:9*4+2]
	push word[es:8*4]
	push word[es:8*4+2]
	
	;hooking keyboard and timer interrupts:
	cli
	mov word[es:9*4],Inputs
	mov word[es:9*4+2],cs
	mov word[es:8*4],Timer
	mov word[es:8*4+2],cs
	sti
	
	mov ax, 0xB800
	mov es, ax ;set ES to video memory
	
	mov di, 0	
	call Draw_Next_Shapes ;Drawing initial shapes
	
	;main loop to control flow of the game:
	Running:
		push 610
		call Delay ;slows shape movement
		push 0
		call Moving_The_Shape ;moving current shape downwards
		
		cmp byte[Flag],0 ;checking if flag was updated to zero
		je Game_Over
		
		cmp word[minute_count], 5 ;checking if time has reached the 5 minutes limit
		jb Running	
		
	Game_Over:
	xor ax,ax
	mov es,ax ;initialising ES to the start of IVT table
	
	;Unhooking Interrupts 8 and 9
	cli
	pop word[es:8*4+2]
	pop word[es:8*4]
	pop word[es:9*4+2]
	pop word[es:9*4]
	sti
	
	pop es
	pop di
	pop ax
	pop bx
	ret
	
;Following subroutine loads start screen showing game name and instructions:
StartScreen:
	push ax
	push 0F00h
	push begin1
	push 2588
	call PrintText

	push 0F00h
	push begin2
	push 2916
	call PrintText
	
	push 0F00h
	push instruct1
	push 3224
	call PrintText
	
	push 0F00h
	push instruct2
	push 3370
	call PrintText
	
	push 0F00h
	push instruct3
	push 3546
	call PrintText
	
	call Tetris
	
	mov ah, 0
	int 0x16
	
	pop ax
	ret

;Transition from start screen to main screen:
AnimatedStarting:
	push ax
	push cx
	push di
	push es
	
	push 0xB800
	pop es
	mov cx,80
	mov ax,1020h
	mov di,0
	left_to_right_starting1:
		push di
		push cx
		mov cx,25
		left_to_right_starting2:
			stosw
			add di,158
			loop left_to_right_starting2
		push 125
		call Delay
		pop cx
		pop di
		add di,2
		loop left_to_right_starting1
	mov cx,80
	mov di,158
	mov ah,30h
	right_to_left_starting1:
		push di
		push cx
		mov cx,25
		right_to_left_starting2:
			stosw
			add di,158
			loop right_to_left_starting2
		pop cx
		pop di
		push 125
		call Delay
		sub di,2
		loop right_to_left_starting1
	mov cx,25
	mov di,3840
	mov ah,10h
	bottom_to_top:
		push di
		push cx
		mov cx,80
		rep stosw
		push 200
		call Delay
		pop cx
		pop di
		sub di,160
		loop bottom_to_top
	pop es
	pop di
	pop cx
	pop ax
	ret
	
Scroll_The_Frame:
	push bp
	mov bp,sp
	push ax
	push cx
	push si
	push di
	push es
	push ds
	
	mov ax,0xB800
	mov es,ax ;set ES to video memory
	mov ds,ax ;set DS to video memory
	
	mov di,[bp+4] ;bp+4 holds starting point of the full row that needs to be removed
	add di,98 ;our frame is of 50 columns, pointing to the end of the full row
	mov si,di
	sub si,160 ;setting source one row above the fully colored row
	
	scroll_a_row:
		push di
		push si
		mov cx,50 ;cx holds width of frame
		
		std ;auto decrement mode
		rep movsw
		
		pop si
		pop di
		
		;moving si and di to point one row above the current positions:
		sub di,160
		sub si,160
		cmp si,486 ;486 is the starting point of out main frame
		ja scroll_a_row
		
	;printing default attributes on top most row of the main frame:
	mov ax,7020h 
	mov di,486
	mov cx,50
	cld
	rep stosw
	pop ds
	pop es
	pop di
	pop si
	pop cx
	pop ax
	pop bp
	ret 2

Moving_The_Shape:
	push bp
	mov bp,sp
	
	;checking the type of shape currently in motion:
	cmp word[current],1
	je MovP 
	cmp word[current],2
	je MovL
	cmp word[current],3
	je MovS
	cmp word[current],4
	je MovR
	
	MovP:
	push word[bp+4]
	call Moving_Plus
	jmp stop_the_move
	MovL:
	push word[bp+4]
	call Moving_L
	jmp stop_the_move
	MovS:
	push word[bp+4]
	call Moving_Square
	jmp stop_the_move
	MovR:
	push word[bp+4]
	call Moving_Rect
	stop_the_move:
	pop bp
	ret 2

Moving_Rect:
	push bp
	mov bp,sp
	push ax
	push cx
	
	mov cx,11 ;width of rectangle
	mov ax,7020h 
	push di
	;point di two rows down to scan the screen below the rectangle of height two:
	add di,320 
	repe scasw
	;if cx is zero, rectangle can move down
	cmp cx,0
	pop di
	
	jne StopAndDrawNext4
	
	;Checking movement type:
	cmp word[bp+4],0
	je just_down4
	cmp word[bp+4],1 
	je left_down4
	cmp word[bp+4],2
	je right_down4
	
	StopAndDrawNext4:
	push 6020h ;make stopped shape orange
	push di
	call Draw_Rect_For_Game
	call ScanScreen
	call Draw_Next_Shapes
	jmp END4
	
	;printing default background colored shape on the current position
	just_down4:
	push 7020h
	push di
	call Draw_Rect_For_Game
	
	;setting di one row down, and printing the new shape there
	add di,160 
	push 4020h
	push di
	call Draw_Rect_For_Game
	jmp END4
	
	;left movement 
	left_down4:
	mov cx,3 
	push di	
	;scanning left side of the shape
	left_check4:
		push cx
		sub di,2
		cld
		mov cx,2
		repe scasw
		cmp cx,0
		pop cx
		jne exit41 ;if cx is not zero then you cannot move left
		add di,158
		loop left_check4
		
	;if the control reaches here then you are free to move left 
	pop di
	jmp continue41
	exit41:
	pop di
	jmp END4
	continue41:
	push 7020h
	push di
	call Draw_Rect_For_Game
	sub di,2
	push 4020h
	push di
	call Draw_Rect_For_Game
	jmp END4
	
	;right movement:
	right_down4:
	mov cx,3
	push di
	right_check4:
		push cx
		add di,20 ;set di to the right of rectangle
		cld
		mov cx,2
		repe scasw
		cmp cx,0
		pop cx
		jne exit42 ;if cx is not zero then you cannot move left
		add di,136
		loop right_check4
		
	;if the control reaches here then you are free to move left 
	pop di
	jmp continue42
	exit42:
	pop di
	jmp END4
	continue42:
	push 7020h
	push di
	call Draw_Rect_For_Game
	add di,2
	push 4020h
	push di
	call Draw_Rect_For_Game
	END4:
	pop cx
	pop ax
	pop bp
	ret 2

Moving_Square:
	push bp
	mov bp,sp
	push ax
	push cx
	mov cx,9
	mov ax,7020h
	push di
	add di,640
	repe scasw
	cmp cx,0
	pop di
	jne StopAndDrawNext3
	;Checking movement type:
	cmp word[bp+4],0
	je just_down3
	cmp word[bp+4],1
	je left_down3
	cmp word[bp+4],2
	je right_down3
	StopAndDrawNext3:
	push 6020h
	push di
	call Draw_Square
	call ScanScreen
	call Draw_Next_Shapes
	jmp END3
	just_down3:
	push 7020h
	push di
	call Draw_Square
	add di,160
	push 4020h
	push di
	call Draw_Square
	jmp END3
	left_down3:
	mov cx,5
	push di
	left_check3:
		push cx
		sub di,2
		cld
		mov cx,2
		repe scasw
		cmp cx,0
		pop cx
		jne exit31
		add di,158
		loop left_check3
	pop di
	jmp continue31
	exit31:
	pop di
	jmp END3
	continue31:
	push 7020h
	push di
	call Draw_Square
	sub di,2
	push 4020h
	push di
	call Draw_Square
	jmp END3
	right_down3:
	mov cx,5
	push di
	right_check3:
		push cx
		add di,16
		cld
		mov cx,2
		repe scasw
		cmp cx,0
		pop cx
		jne exit32
		add di,140
		loop right_check3
	pop di
	jmp continue32
	exit32:
	pop di
	jmp END3
	continue32:
	push 7020h
	push di
	call Draw_Square
	add di,2
	push 4020h
	push di
	call Draw_Square
	END3:
	pop cx
	pop ax
	pop bp
	ret 2

Moving_L:
	push bp
	mov bp,sp
	push ax
	push cx
	mov cx,9
	mov ax,7020h
	push di
	add di,800
	repe scasw
	cmp cx,0
	pop di
	jne StopAndDrawNext2
	;Checking movement type:
	cmp word[bp+4],0
	je just_down2
	cmp word[bp+4],1
	je left_down2
	cmp word[bp+4],2
	je right_down2
	StopAndDrawNext2:
	push 6020h
	push di
	call Draw_L_Shape
	call ScanScreen
	call Draw_Next_Shapes
	jmp END2
	just_down2:
	push 7020h
	push di
	call Draw_L_Shape
	add di,160
	push 4020h
	push di
	call Draw_L_Shape
	jmp END2
	left_down2:
	mov cx,6
	push di
	sub di,2
	left_check2:
		cmp word[es:di],7020h
		jne exit21
		add di,160
		loop left_check2
	pop di
	jmp continue21
	exit21:
	pop di
	jmp END2
	continue21:
	push 7020h
	push di
	call Draw_L_Shape
	sub di,2
	push 4020h
	push di
	call Draw_L_Shape
	jmp END2
	right_down2:
	mov cx,4
	push di
	add di,4
	right_check2:
		cmp word[es:di],7020h
		jne exit22
		add di,160
		loop right_check2
	pop di
	jmp continue22
	exit22:
	pop di
	jmp END2
	continue22:
	cmp word[es:di+656],7020h
	jne END2
	push 7020h
	push di
	call Draw_L_Shape
	add di,2
	push 4020h
	push di
	call Draw_L_Shape
	END2:
	pop cx
	pop ax
	pop bp
	ret 2

Moving_Plus:
	push bp
	mov bp,sp
	push ax
	push cx
	cmp word[es:di+800],7020h	;Checking Whether we reached the bottom of our main game frame.
	cmp word[es:di+802],7020h	;Checking Whether we reached the bottom of our main game frame.
	jne StopAndDrawNext
	jne StopAndDrawNext
	;checking screen below Plus left wing.
	mov cx,5
	mov ax,7020h
	push di
	add di,472
	repe scasw
	cmp cx,0
	pop di
	jne StopAndDrawNext
	;checking screen below Plus right wing.
	push di
	mov cx,5
	add di,484
	repe scasw
	cmp cx,0
	pop di
	jne StopAndDrawNext
	;Checking movement type:
	cmp word[bp+4],0
	je just_down1
	cmp word[bp+4],1
	je left_down1
	jmp right_down1
	StopAndDrawNext:
	push 6020h
	push di
	call Draw_Plus
	call ScanScreen
	call Draw_Next_Shapes
	jmp END1
	just_down1:
	push 7020h
	push di
	call Draw_Plus
	add di,160
	push 4020h
	push di
	call Draw_Plus
	jmp END1
	left_down1:
	mov cx,2
	push di
	sub di,2
	top_left_check:
		cmp word[es:di],7020h
		jne exit11
		add di,160
		loop top_left_check
	pop di
	jmp continue11
	exit11:
	pop di
	jmp END1
	continue11:
	mov cx,3
	push di
	add di,478
	bottom_left_check:
		cmp word[es:di],7020h
		jne exit12
		add di,160
		loop bottom_left_check
	pop di
	jmp continue12
	exit12:
	pop di
	jmp END1
	continue12:
	cmp word[es:di+470],7020h
	jne END1
	cmp word[es:di+630],7020h
	jne END1
	push 7020h
	push di
	call Draw_Plus
	sub di,2
	push 4020h
	push di
	call Draw_Plus
	jmp END1
	right_down1:
	mov cx,2
	push di
	add di,4
	top_right_check:
		cmp word[es:di],7020h
		jne exit13
		add di,160
		loop top_right_check
	pop di
	jmp continue13
	exit13:
	pop di
	jmp END1
	continue13:
	cmp word[es:di+492],7020h
	jne END1
	cmp word[es:di+652],7020h
	jne END1
	mov cx,3
	push di
	add di,484
	bottom_right_check:
		cmp word[es:di],7020h
		jne exit14
		add di,160
		loop bottom_right_check
	pop di
	jmp continue14
	exit14:
	pop di
	jmp END1
	continue14:
	push 7020h
	push di
	call Draw_Plus
	add di,2
	push 4020h
	push di
	call Draw_Plus
	END1:
	pop cx
	pop ax
	pop bp
	ret 2
	
;checking the entire game frame for any possible increments in score:
ScanScreen:
	push ax
	push cx
	push di
	push es
	
	push 0xB800
	pop es
	mov ax,6020h 	;attributes of stopped shapes
	mov di,486 		;starting point of main frame
	mov cx,19 		;number of rows of main frame
	scanNextRow:
		push di
		push cx
		mov cx,51 	;width of main frame
		cld
		repe scasw
		cmp cx,0
		pop cx
		pop di
		jne nextIteration
		
		;updating the return value (intended for di) to manage the scroll frame
		push cx
		mov cx,750
		BlinkingLoop:
			push 7020h
			push di
			push 50
			push 1
			call Draw_Rectangle
			push cx
			call Delay
			push 6020h
			push di
			push 50
			push 1
			call Draw_Rectangle
			push cx
			call Delay
			sub cx,250
			jnz BlinkingLoop
		pop cx
		call UpdateScore
		push di
		call Scroll_The_Frame
		nextIteration:
		add di,160
		loop scanNextRow
	pop es
	pop di
	pop cx
	pop ax
	ret

CheckTopRow: ;to check if frame is full till top and ends game
		push ax
		push cx
		push di
		
		mov cx,51
		mov ax,6020h
		mov di,486
		repne scasw
		cmp cx,0
		je NoIssues
		mov byte[Flag],0
		NoIssues:
		pop di
		pop cx
		pop ax
		ret

;transition from main screen to end screen
AnimatedEnding:
	push ax
	push cx
	push di
	push es
	
	mov ax,0720h
	push 0xB800
	pop es
	mov di,0
	mov cx,2000
	eraseRow:
		push cx
		mov cx,80
		cld
		LeftToRight:
			stosw
			push 30
			call Delay
			loop LeftToRight
		pop cx
		sub cx,80
		cmp cx,0
		je stopClearing
		push cx
		mov cx,80
		add di,158
		std
		RightToLeft:
			stosw
			push 30
			call Delay
			loop RightToLeft
		pop cx
		sub cx,80
		add di,162
		jmp eraseRow
	stopClearing:
	pop es
	pop di
	pop cx
	pop ax
	ret

Delay:
	push bp
	mov bp, sp
	push cx
	
	mov cx, [bp+4]
	delay1:
		push cx
		delay2:
			nop
			nop
			nop
			loop delay2
		pop cx
		loop delay1
	pop cx
	mov sp, bp
	pop bp
	ret 2

PrintText:
	push bp
	mov bp, sp
	push ax
	push es
	push si
	push di
	mov ax, 0xB800
	mov es, ax
	mov di, [bp+4]
	mov ax, [bp+8]
	mov si, [bp+6]
	
	cld
	nextchar:
		lodsb
		stosw
		cmp byte[si], 0
		jne nextchar

	pop di
	pop si
	pop es
	pop ax
	mov sp, bp
	pop bp
	ret 6

PrintNumbers:
	push bp
	mov bp, sp
	push ax
	push bx
	push cx
	push dx
	push di
	push es
	
	mov ax, 0xB800
	mov es, ax
	mov ax, [bp+4]
	mov bx, 10
	mov cx, 0

	split:
		mov dx, 0
		div bx
		add dx, 30h
		push dx
		inc cx
		test ax, 0xFFFF
		jnz split
	
	mov dx, [bp+8]
	mov di, [bp+6]

	nextnum:
		pop ax
		mov ah, dh
		stosw
		loop nextnum

	pop es
	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	mov sp, bp
	pop bp
	ret 6

PrintScore:
	push bp
	mov bp, sp
	push 5
	push word[bp+8]
	push word[bp+6]
	push word[bp+4]
	call PrintInAPattren
	mov sp, bp
	pop bp
	ret 6

PrintTime:
	push bp
	mov bp, sp
	push 2
	push word[bp+8]
	push word[bp+6]
	push word[bp+4]
	call PrintInAPattren
	mov sp, bp
	pop bp
	ret 6

PrintInAPattren:
	push bp
	mov bp, sp
	push ax
	push bx
	push cx
	push dx
	push di
	push es
	
	mov ax, 0xB800
	mov es, ax
	mov ax, [bp+4]
	mov bx, 10
	mov cx, [bp+10]

	splitscore:
		mov dx, 0
		div bx
		add dx, 30h
		push dx
		loop splitscore
	
	mov dx, [bp+8]
	mov di, [bp+6]
	mov cx, [bp+10]
	
	nextscorenum:
		pop ax
		mov ah, dh
		stosw
		loop nextscorenum

	pop es
	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	mov sp, bp
	pop bp
	ret 6

clrscr
	push 0720h
	push 0
	push 80
	push 25
	call Draw_Rectangle
	ret

Borders:
	push ax
	push cx
	push di
	push es
	mov ax, 0xB800
	mov es, ax
	mov ax, 0x1E20

	mov di, 0
	mov cx, 80
	push cx
	;Top Row:
	rep stosw
	
	mov di, 3840
	pop cx
	;Bottom Row:
	rep stosw
	
	mov di, 160
	
	left:
		stosw
		add di, 158
		cmp di, 4000
		jb left

	mov di, 318
	right:
		stosw
		add di, 158
		cmp di, 4000
		jb right
	
	pop di
	pop es
	pop cx
	pop ax
	ret

Divider:
	push ax
	push cx
	push di
	push es
	push 0xB800
	pop es
	mov di, 110
	mov ax, 0x1e20
	draw:
		stosw
		add di, 158
		cmp di, 4000
		jb draw
	mov di, 324
	mov ax, 3020h
	push di
	mov cx, 52
	push cx
	frametop:
		stosw
		loop frametop
	pop cx
	pop di
	add di, 160
	frameleft:
		stosw
		add di, 158
		cmp di, 3680
		jb frameleft
	sub di, 158
	dec cx
	framebottom:
		stosw
		loop framebottom
	sub di, 162
	frameright:
		stosw
		sub di, 162
		cmp di, 428
		ja frameright
	mov ax, 7020h
	mov di, 486
	mov cx, 50
	framebackground:
		push di
		push cx
		rep stosw
		pop cx
		pop di
		add di, 160
		cmp di, 3520
		jb framebackground
	pop es
	pop di
	pop cx
	pop ax
	ret

Draw_Rectangle:
	push bp
	mov bp,sp
	push ax
	push bx
	push cx
	push di
	push es
	push 0xb800
	pop es
	mov di,[bp+8]
	mov bx,[bp+4]
	mov cx,[bp+6]
	mov ax,[bp+10]
	loop1:
		push cx
		push di
		rep stosw
		pop di
		pop cx
		add di,160
		dec bx
		jnz loop1
		
	pop es
	pop di
	pop cx
	pop bx
	pop ax
	mov sp,bp
	pop bp
	ret 8

Draw_L_Shape:
	push bp
	mov bp,sp
	push ax
	push di
	
	mov ax,[bp+6]
	mov di,[bp+4]
	push ax
	push di
	push 2
	push 5
	call Draw_Rectangle
	
	add di,644
	push ax
	push di
	push 6
	push 1
	call Draw_Rectangle
	
	pop di
	pop ax
	pop bp
	ret 4

Draw_Plus:
	push bp
	mov bp,sp
	push ax
	push di
	
	mov ax,[bp+6]
	mov di,[bp+4]
	push ax
	push di
	push 2
	push 5
	call Draw_Rectangle
	
	add di, 312
	push ax
	push di
	push 10
	push 1
	call Draw_Rectangle
	
	pop di
	pop ax
	mov sp,bp
	pop bp
	ret 4
 
 
Draw_Square:
	push bp
	mov bp,sp
	push word[bp+6]
	push word[bp+4]
	push 8
	push 4
	call Draw_Rectangle
	pop bp
	ret 4
	
Draw_Rect_For_Game:
	push bp
	mov bp,sp
	push word[bp+6]
	push word[bp+4]
	push 10
	push 2
	call Draw_Rectangle
	pop bp
	ret 4

Draw_Next_Shapes:
	call CheckTopRow
	cmp byte[Flag],0
	jne Continue_Game
	ret
	Continue_Game:
	push ax
	push cx
	mov ax,7020h
	inc word[current]
	cmp word[current],5
	jne continue
	;checking the type of shape to be printed next
	mov word[current],1
	continue:
	cmp word[current],1
	je Plus
	cmp word[current],3
	je Square
	cmp word[current],2
	je L
	jmp Rectangle	;If the rest of conditions are false,then this will be true.
	Plus:
	mov di,536
	cmp word[es:di+640],7020h
	jne UpdateFlag
	cmp word[es:di+642],7020h
	jne UpdateFlag
	mov cx,11
	mov ax,7020h
	push di
	add di,312
	repe scasw
	cmp cx,0
	pop di
	jne UpdateFlag
	push 4020h
	push di
	call Draw_Plus
	jmp ending
	L:
	mov di,532
	push di
	mov cx,9
	add di,640
	repe scasw
	cmp cx,0
	pop di
	jne UpdateFlag
	push 4020h
	push di
	call Draw_L_Shape
	jmp ending
	Square:
	mov di,528
	push di
	add di,480
	mov cx,9
	repe scasw
	cmp cx,0
	pop di
	jne UpdateFlag
	push 4020h
	push di
	call Draw_Square
	jmp ending
	UpdateFlag:
	mov byte[Flag],0
	pop cx
	pop ax
	jmp Draw_Next_Shapes
	Rectangle:
	mov di,526
	mov cx,11
	push di
	add di,160
	repe scasw
	cmp cx,0
	pop di
	jne UpdateFlag
	push 4020h
	push di
	call Draw_Rect_For_Game
	jmp ending
	ending:
	call Draw_Upcomming_Shape
	pop cx
	pop ax
	ret

Draw_Upcomming_Shape:
	push 7020h
	push 2032
	push 23
	push 11
	call Draw_Rectangle
	push 4020h
	inc word[next_shape]
	cmp word[next_shape],5
	jne continue2
	mov word[next_shape],1
	continue2:
	cmp word[next_shape],1
	je Plus2
	cmp word[next_shape],2
	je L2
	cmp word[next_shape],3
	je Square2
	cmp word[next_shape],4
	je Rectangle2
	Plus2:
	push 2534
	call Draw_Plus
	jmp ending2
	L2:
	push 2528
	call Draw_L_Shape
	jmp ending2
	Square2:
	push 2688
	call Draw_Square
	jmp ending2
	Rectangle2:
	push 2686
	call Draw_Rect_For_Game
	ending2:
	ret

 
UpdateTime:
	push ax
	push di
	push es
	push 0xB800
	pop es
	mov di, 612
	mov ah, 0x0A
	mov al, ':'
	inc word[second_count]
	cmp word[second_count], 59
	jbe skipchanges
	mov word[second_count], 0
	inc word[minute_count]
	skipchanges:
	push 8A00h
	push 610
	push word[minute_count]
	call PrintNumbers
	stosw
	push 8A00h
	push 614
	push word[second_count]
	call PrintTime
	pop es
	pop di
	pop ax
	ret
	
UpdateScore:
	add word[score_count],10
	push 0A00h
	push 1090
	push word[score_count]
	call PrintScore
	ret

PrintAllEssentials:
	call clrscr
	call Borders
	call StartScreen
	
	call AnimatedStarting
	call clrscr
	
	call Borders
	call Divider
	
	push 0A00h
	push score
	push 930
	call PrintText
	
	push 0A00h
	push time
	push 450
	call PrintText
	
	call UpdateScore
	call UpdateTime
	
	push 0A00h
	push upcoming
	push 1568
	call PrintText
	
	push 0A00h
	push shape
	push 1730
	call PrintText
	ret

EndScreen:
	call AnimatedEnding
	push ax
	push di
	push es
	call Borders
	push 0F00h
	push end1
	push 3542
	call PrintText
	
	push 0F00h
	push final_score
	push 2740
	call PrintText
	
	push 0E00h
	push 2906
	push word[score_count]
	call PrintScore
	
	push 0F00h
	push final_time
	push 2840
	call PrintText
	
	mov ax,0xB800
	mov es,ax
	mov ah,0Eh
	mov al,':'
	mov di,3008
	push 0E00h
	push 3006
	push word[minute_count]
	call PrintNumbers
	stosw
	push 0E00h
	push 3010
	push word[second_count]
	call PrintTime
	call game_over
	
	pop es
	pop di
	pop ax
	ret

;My interupt service routines:
Timer:
	push ax
	cmp word[minute_count],5	;Time Over, Stop The Game.
	je return
	inc word[cs:tickcount]
	cmp word[cs:tickcount],18	;18 calls of int 8 is aproximately equal to 1 real life second.
	jb return	;No changes if tickcount is less than 18.
	mov word[tickcount],0	;Resetting tickcount.
	call UpdateTime
	return:
	;End of ISR.
	mov al,0x20
	out 0x20,al
	pop ax
	iret

Inputs:
	push ax
	in al,0x60	;Reading Keyboard scan codes.
	cmp al,0x4b	;Check for left arrow key press.
	je left_hit
	cmp al,0x4d	;Check for right arrow key press.
	je right_hit
	jmp no_hit	;If neither of the above was found, then continue normal progression.
	left_hit:
	push 1	;Parameter for left movement of the shapes.
	call Moving_The_Shape
	push 1
	call Moving_The_Shape
	jmp no_hit
	right_hit:
	push 2	;Parameter for right movement of the shapes.
	call Moving_The_Shape
	push 2
	call Moving_The_Shape
	no_hit:
	;End of ISR.
	mov al,0x20
	out 0x20,al
	pop ax
	iret

Tetris:

push 1000
call Delay
;t
push 0x3000
push 498
push 9
push 1
call Draw_Rectangle
push 0x3000
push 504
push 3
push 9
call Draw_Rectangle

push 1000
call Delay
;e
push 0x3000
push 522
push 9
push 1
call Draw_Rectangle
push 0x3000
push 522
push 3
push 9
call Draw_Rectangle
push 0x3000
push 1162
push 9
push 1
call Draw_Rectangle
push 0x3000
push 1802
push 9
push 1
call Draw_Rectangle

push 1000
call Delay
;t
push 0x3000
push 544
push 9
push 1
call Draw_Rectangle
push 0x3000
push 550
push 3
push 9
call Draw_Rectangle

push 1000
call Delay
;r
push 0x3000
push 566
push 3
push 9
call Draw_Rectangle
push 0x3000
push 566
push 8
push 1
call Draw_Rectangle
push 0x3000
push 1366
push 8
push 1
call Draw_Rectangle
push 0x3000
push 738
push 3
push 4
call Draw_Rectangle
push 0x3000
push 1532
push 3
push 1
call Draw_Rectangle
push 0x3000
push 1696
push 3
push 1
call Draw_Rectangle
push 0x3000
push 1858
push 3
push 1
call Draw_Rectangle

push 1000
call Delay
;i
push 0x3000
push 590
push 3
push 9
call Draw_Rectangle

push 1000
call Delay
;s
push 0x3000
push 604
push 8
push 1
call Draw_Rectangle
push 0x3000
push 762
push 3
push 3
call Draw_Rectangle
push 0x3000
push 1244
push 8
push 1
call Draw_Rectangle
push 0x3000
push 1416
push 3
push 3
call Draw_Rectangle
push 0x3000
push 1882
push 9
push 1
call Draw_Rectangle
ret

game_over:

;G
push 0x4020
push 372
push 5
push 1
call Draw_Rectangle
push 0x4020
push 530
push 2
push 1
call Draw_Rectangle
push 0x4020
push 688
push 2
push 2
call Draw_Rectangle
push 0x4020
push 1010
push 2
push 1
call Draw_Rectangle
push 0x4020
push 1172
push 5
push 1
call Draw_Rectangle
push 0x4020
push 856
push 3
push 1
call Draw_Rectangle
push 0x4020
push 858
push 2
push 2
call Draw_Rectangle

push 600
call Delay

;A

push 0x4020
push 388
push 3
push 1
call Draw_Rectangle
push 0x4020
push 546
push 2
push 1
call Draw_Rectangle
push 0x4020
push 704
push 2
push 4
call Draw_Rectangle
push 0x4020
push 552
push 2
push 1
call Draw_Rectangle
push 0x4020
push 714
push 2
push 4
call Draw_Rectangle
push 0x4020
push 864
push 7
push 1
call Draw_Rectangle

push 600
call Delay

;M 
push 0x4020
push 400
push 2
push 6
call Draw_Rectangle
push 0x4020
push 564
push 1
push 2
call Draw_Rectangle
push 0x4020
push 726
push 1
push 2
call Draw_Rectangle
push 0x4020
push 410
push 2
push 6
call Draw_Rectangle
push 0x4020
push 568
push 1
push 2
call Draw_Rectangle

push 600
call Delay

;E 
push 0x4020
push 416
push 2
push 6
call Draw_Rectangle
push 0x4020
push 416
push 7
push 1
call Draw_Rectangle
push 0x4020
push 736
push 4
push 1
call Draw_Rectangle
push 0x4020
push 1216
push 7
push 1
call Draw_Rectangle

push 600
call Delay

;o
push 0x4020
push 1490
push 5
push 1
call Draw_Rectangle
push 0x4020
push 1648
push 2
push 4
call Draw_Rectangle
push 0x4020
push 1658
push 2
push 4
call Draw_Rectangle
push 0x4020
push 2290
push 5
push 1
call Draw_Rectangle
push 0x4020
push 1648
push 2
push 4
call Draw_Rectangle

push 600
call Delay

;v
push 0x4020
push 1504
push 2
push 3
call Draw_Rectangle
push 0x4020
push 1826
push 2
push 2
call Draw_Rectangle
push 0x4020
push 1988
push 3
push 2
call Draw_Rectangle
push 0x4020
push 2310
push 1
push 1
call Draw_Rectangle
push 0x4020
push 1832
push 2
push 2
call Draw_Rectangle
push 0x4020
push 1514
push 2
push 3
call Draw_Rectangle

push 600
call Delay

;e
push 0x4020
push 1520
push 7
push 1
call Draw_Rectangle
push 0x4020
push 1520
push 2
push 6
call Draw_Rectangle
push 0x4020
push 1840
push 4
push 1
call Draw_Rectangle
push 0x4020
push 2320
push 7
push 1
call Draw_Rectangle

push 600
call Delay

;r
push 0x4020
push 1536
push 2
push 6
call Draw_Rectangle
push 0x4020
push 1536
push 6
push 1
call Draw_Rectangle
push 0x4020
push 2016
push 5
push 1
call Draw_Rectangle
push 0x4020
push 1706
push 2
push 2
call Draw_Rectangle
push 0x4020
push 1864
push 1
push 1
call Draw_Rectangle
push 0x4020
push 2182
push 3
push 1
call Draw_Rectangle
push 0x4020
push 2344
push 3
push 1
call Draw_Rectangle
ret

start:
	call PrintAllEssentials
	call Launch
	call EndScreen
	mov ah,0
	int 16h
	mov ax, 4c00h
	int 21h
