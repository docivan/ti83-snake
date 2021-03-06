.NOLIST
#define equ .equ
#define EQU .equ
#define end .end

; #######################################################################################
; SYSTEM CALLS AND ADDR
; #######################################################################################

; addresses
_vram				.equ		8E29h ; video mem

; functions
_blitBuf			.equ		5164h	; Copy the graph backup to the screen
_bufClr			.equ		515Bh	; Clear the graph backup

_drawText		.equ		4781h ; draw small text
_sGrFlags		.equ		20		; IY OFFSET VALUE
_txtWrToBuf		.equ		7	; bit offset for 
_penCol			.equ		8252h
_penRow			.equ		8253h

_runIndOff		.equ	 	4795h	; Turn off runindicator

_getKey			.equ		4A18h ; get pressed key
_textMode		.equ		47A1h ; switch to Home aka text mode

; #######################################################################################
; USER DEFINED CONSTANTS
; #######################################################################################

scr_w 			.equ	96
scr_h				.equ	64
scr_w_b			.equ	scr_w/8

score_pos_x		.equ	scr_w - 12 - 1 ; 4 pxl per number + 1 padding
score_area_x	.equ	score_pos_x - 2 ; score area x starts here, 2 pxl extra padding
score_area_y	.equ	8 ; score area y ends here

snake_len_max	.equ	64
apple_cnt		.equ	10
speed_inc		.equ	50

DIR_N				.equ	0
DIR_E				.equ	1
DIR_S				.equ	2
DIR_W				.equ	3

key_UP			.equ	4
key_DOWN			.equ	1
key_LEFT			.equ	2
key_RIGHT		.equ	3
key_ENTER		.equ	9

; #######################################################################################
; PROGRAM ENTRY POINT
; #######################################################################################

.LIST
.org 9327h

	; prep environment
	call _runIndOff         ; Turn off runindicator
	call reset_all
	call menu
	ret

reset_all:
	ld a,0
	ld (stop_game),a
	ld (paused),a
	ld (exit_game),a ; not necessary
	
	ld a,3
	ld (snake_len),a
	
	; 	.db  48, 31,  47, 31,  46, 31,
	ld hl,snake
	ld (hl),48
	inc hl
	ld (hl),31
	inc hl
	ld (hl),47
	inc hl
	ld (hl),31
	inc hl
	ld (hl),46
	inc hl
	ld (hl),31
	
	ld a,DIR_E
	ld (dir),a
	ld (nxt_dir),a
	
	ld hl,score_str
	ld (hl),'0'
	inc hl
	ld (hl),'0'
	inc hl
	ld (hl),'0'
	
	ld hl,1500
	ld (speed),hl
	
	ret

; #######################################################################################
; MENU
; #######################################################################################

exit_game: .db 0

menu:
	call _bufClr          ; Clear the graphbuf
	
	ld hl,menu_bkg
	ld de,_vram
	ld bc,scr_w*scr_h/8
	ldir
	
	call _blitBuf         ; Copy the graphbuf to the LCD
	
	ld d,0 ;prev menu cursor x
	ld e,0 ;prev menu cursor y
	ld b,0 ;menu cursor x
	ld c,0 ;menu cursor y
	call menu_draw_cursor
	call menu_handle_kb
	
	ld a,(exit_game)
	cp 1
	jp z,menu_exit_game
	
	call start_game
	
	call reset_all
	jp menu
	
menu_exit_game:
	call _textMode
	ret

; #######################################################################################
; draw cursor
; inputs: bc - new position, de - prev position
; #######################################################################################

;pre-defined cursor position for menu elements
cursor_pos_x: .db 3,34,65
cursor_pos_y: .db 31,47

menu_draw_cursor:
	push bc
	push de
	
	ld b,d
	ld c,e
	
	ld hl,cursor_pos_x
	ld d,0
	ld e,b
	add hl,de
	ld a,(hl)
	
	ld hl,cursor_pos_y
	ld e,c
	add hl,de
	ld b,(hl)
	
	ld d,a
	ld e,b
	push de
	call clr_pxl
	pop de
	ld a,d
	ld b,e
	
	inc a
	inc b
	push de
	call clr_pxl
	pop de
	ld a,d
	ld b,e
	
	inc b
	inc b
	call clr_pxl
	
	pop de
	pop bc
	
	push bc
	push de
	
	ld hl,cursor_pos_x
	ld d,0
	ld e,b
	add hl,de
	ld a,(hl)
	
	ld hl,cursor_pos_y
	ld e,c
	add hl,de
	ld b,(hl)
	
	ld d,a
	ld e,b
	push de
	call put_pxl
	pop de
	ld a,d
	ld b,e
	
	inc a
	inc b
	push de
	call put_pxl
	pop de
	ld a,d
	ld b,e
	
	inc b
	inc b
	call put_pxl
	
	call _blitBuf
	pop de
	pop bc
	
	ret

; #######################################################################################
; this blits a string directly onto the screen with double buffer
; #######################################################################################

loading_str: .db "LOADING...",0

print_loading:
	ld a,32
	ld (_penCol),a
	ld a,37
	ld (_penRow),a
	set _txtWrToBuf, (iy + _sGrFlags) 
	
	ld hl,loading_str
	call _drawText
	call _blitBuf
	ret

; #######################################################################################
; handle user input in menu
; #######################################################################################

menu_handle_kb:
	push bc
	push de
	call _getKey
	pop de
	pop bc
	
	cp key_UP
	jp z,menu_kp_UP
	cp key_DOWN
	jp z,menu_kp_DOWN
	cp key_LEFT
	jp z,menu_kp_LEFT
	cp key_RIGHT
	jp z,menu_kp_RIGHT
	cp key_ENTER
	jp z,menu_kp_ENTER
	
	jp menu_handle_kb

menu_kp_UP:
	ld d,b ; storing prev pos
	ld e,c ; storing prev pos
	
	ld a,c
	dec c
	cp 0
	jp nz,menu_kp_draw
	ld c,1
	jp menu_kp_draw
	
menu_kp_DOWN:
	ld d,b ; storing prev pos
	ld e,c ; storing prev pos
	
	ld a,c
	inc c
	cp 1
	jp nz,menu_kp_draw
	ld c,0
	jp menu_kp_draw
	
menu_kp_LEFT:
	ld d,b ; storing prev pos
	ld e,c ; storing prev pos
	
	ld a,b
	dec b
	cp 0
	jp nz,menu_kp_draw
	ld b,2
	jp menu_kp_draw
	
menu_kp_RIGHT:
	ld d,b ; storing prev pos
	ld e,c ; storing prev pos
	
	ld a,b
	inc b
	cp 2
	jp nz,menu_kp_draw
	ld b,0
	jp menu_kp_draw

menu_kp_draw:
	call menu_draw_cursor
	jp menu_handle_kb
	
menu_kp_ENTER:
	push bc
	call print_loading
	call _bufClr
	pop bc
	; bc - stores current pointer position
	
	ld a,c
	cp 0 ; y-coor
	jp z,mkp_sel_y0
	
;if we are still here, y=1
	ld a,b
	cp 0
	jp z,mkp_sel_x0y1
	cp 1
	jp z,mkp_sel_x1y1
	jp mkp_sel_x2y1

mkp_sel_y0: ; y=0
	ld a,b
	cp 0
	jp z,mkp_sel_x0y0
	cp 1
	jp z,mkp_sel_x1y0
	jp mkp_sel_x2y0


mkp_sel_x0y0:
	ld de,lvl1_map
	ret
mkp_sel_x0y1:
	ld de,lvl2_map
	ret
mkp_sel_x1y0:
	ld de,lvl3_map
	ret
mkp_sel_x1y1:
	ld de,lvl4_map
	ret
mkp_sel_x2y0:
	ld de,lvl5_map
	ret

mkp_sel_x2y1: ; quit
	ld a,1
	ld (exit_game),a
	ret

; #######################################################################################
; GAMEOVER
; #######################################################################################

game_over:
	call _bufClr          ; Clear the graphbuf
	
	ld hl,game_over_bkg
	ld de,_vram
	ld bc,scr_w*scr_h/8
	ldir
	
	call _blitBuf         ; Copy the graphbuf to the LCD
	
game_over_wait_enter:
	call _getKey
	cp key_ENTER
	jp z,game_over_return
	jp game_over_wait_enter

game_over_return:
	call print_loading
	ret

; #######################################################################################
; START GAME
; #######################################################################################

start_game:
	call draw_map
	call prep_score
	
	;generate apples
	ld a,apple_cnt
	ld hl,apples
apple_loop:
	push af
	call gen_apple
	inc hl
	pop af
	
	dec a
	jp nz, apple_loop
	
	call draw_apples
	call draw_score
	
	call _blitBuf
	
	call game_loop
	ret

; #######################################################################################
; GAME LOOP
; #######################################################################################

dir:			.db	DIR_E
nxt_dir:		.db	DIR_E
snake_len:	.db	3
stop_game:	.db	0
speed:		.dw	1500 ; 3000 = ca 1 fps
score_str:	.db	"000",0
paused:		.db	0

game_loop:
	; below is the main vgame loop
	
	;if paused - do nothing
	ld hl,1
	ld a,(paused)
	cp 1
	jp z,gl_idle
	
	ld a,(nxt_dir)
	ld (dir),a
		
	;move
	call move_snake
	
	; handle collisions
	call handle_collisions
	
	call draw_snake
	;call draw_apples - this is only done when new apples appear
	
	call _blitBuf	;blit
	
	ld a,(stop_game) ; check if we finished
	cp 1
	jp z, game_loop_explode
	
	;idle while getting input
	ld a,(dir)
	ld (nxt_dir),a ; reset nxt_dir to direction currently heading
	
	ld hl,(speed)		; otherwise sleep for 30ms and loop
gl_idle:
	push hl
	call handle_input
	pop hl
	dec hl
	ld a,h
	or l
	jp nz, gl_idle
	
	jp game_loop
	ret

game_loop_explode:
	; TODO use the snake segments for an explosion!
	
	call game_over
	ret

; #######################################################################################

prep_score:
	; draw 1pxl border
	
	ld d,score_area_x
	ld e,0

ps_h_line_loop:
	ld a,d
	ld b,e
	push de
	call put_pxl
	pop de
	
	ld a,d
	ld b,e
	inc a
	push de
	call clr_pxl
	pop de
	
	ld a,d
	ld b,e
	add a,14
	
	push de
	call put_pxl
	pop de
	
	inc e
	ld a,e
	cp score_area_y
	jp nz, ps_h_line_loop
	
	inc d
	dec e

ps_v_line_loop:
	ld a,d
	ld b,e
	push de
	call put_pxl
	pop de
	
	ld a,d
	ld b,e
	dec b
	push de
	call clr_pxl
	pop de
	
	inc d
	ld a,d
	cp scr_w-1
	jp nz, ps_v_line_loop
	
	ret

draw_score
	ld a,score_pos_x
	ld (_penCol),a
	xor a
	ld (_penRow),a
	set _txtWrToBuf, (iy + _sGrFlags) 
	
	ld hl,score_str
	call _drawText
	ret

inc_score:
	ld hl, score_str+2
	ld b,3

isc_loop:
	ld a,(hl)
	inc a
	cp 3ah
	jp nz, is_store_and_draw_done
	
	ld a, 30h ; ascii for '0'
	ld (hl),a
	dec hl
	dec b
	jp z,is_draw_done ; if we have gone through all 3 numbers, return - this happens when score >999
							; => rollover to 000 gracefully
	jp isc_loop
	

is_store_and_draw_done:
	ld (hl),a
is_draw_done:
	call draw_score
	ret

; #######################################################################################
; draw_pxl_array: draw an array of 'e' pixels with coords starting at addr in 'hl'
;
; args: hl - array ptr, e - nr of words (ie coords: (x,y) = 1)
; #######################################################################################

draw_pxl_array:
	ld a,(hl)
	inc hl
	ld b,(hl)
	inc hl
	
	push hl
	push de
	call put_pxl
	pop de
	pop hl
	
	dec e
	jp nz, draw_pxl_array
	
	ret

; #######################################################################################
; draw_apples: draw all apples
; no args
; #######################################################################################

draw_apples:
	ld hl, apples
	ld e, (apple_cnt)
	
	call draw_pxl_array
	
	ret

; #######################################################################################
; handle_collisions: check whether we have hit a wall, ourselves or an apple
; no args
; #######################################################################################

handle_collisions:
	; collision = if pxl head is on is already filled
	ld hl,snake
	ld a,(hl)
	inc hl
	ld b,(hl)
	
	ld d,a
	ld e,b
	push de
	call get_pxl
	pop de
	
	ret z ; no collisions
	
	; if apple = eat + elongate
	call is_an_apple
	cp 1
	jp nz, hc_die
	call grow
	ret
	
hc_die: ; else = die
	ld hl,stop_game
	ld (hl), 1
	ret

; #######################################################################################
; is_an_apple: check if there is an apple at position (d,e)
; returns a=1 if apple hit with hl pointing at x coor of that apple
; returns a=0 if apple was not hit
; #######################################################################################

is_an_apple:
	ld hl,apples
	ld b,apple_cnt
	
iaa_loop_x:
	dec b	; if run out of apples, quit
	jp pe, iaa_not_found
	
	ld a,(hl)
	cp d	; x-coor
	jp z,iaa_ck_y ; x-coords match
	inc hl
	inc hl
	jp iaa_loop_x

iaa_ck_y:
	inc hl
	ld a,(hl)
	cp e
	jp z, iaa_found
	inc hl
	jp iaa_loop_x
	
iaa_found:
	dec hl ; now points to x of the eaten apple!
	ld a,1
	ret

iaa_not_found:
	ld a,0
	ret


; #######################################################################################
; gen_apple: find random (x,y) coordinates that are not occupied by anything else, 
; 					then write these coords to mem addr hl (x) and hl+1 (y)
; 
; args: hl - addr to x coor of apple to be replaced
; #######################################################################################

gen_apple:
	; no need to clear old apple since snake head overwrites this
	push hl
	
ga_loop:
	
	call gen_rnd_xy
	
	ld d,a
	ld e,b
	
	; check that a,b is not within score area
	cp score_area_x
	jp nc, ga_loop ; x >= score_area_x
	
	ld a,b
	cp score_area_y+1
	jp c, ga_loop ; y < (score_area_y+1)
	
	ld a,d
	
	; check coords in a,b for collisions!
	push de
	call get_pxl
	pop de
	
	jp nz, ga_loop
	
	
	
	pop hl
	ld (hl),d
	inc hl
	ld (hl),e
	ret

; #######################################################################################
; grow: grow snake with one segment after eting an apple, generate a new apple
;
; args: hl = location of snake head / apple
; #######################################################################################

grow:
	;eat = replace apple with x @ hl
	;no need to clear old apple since snake head overwrites this
	call gen_apple
	
	; draw it
	ld a,d
	ld b,e
	call put_pxl
	
	;elongate
	;check if at max length
	ld a,(snake_len)
	cp snake_len_max
	jp nc, grow_speed
	
	ld hl,do_elongate
	inc (hl)
	
	; increase score
	call inc_score
	
	;finally, increase speed
grow_speed:
	ld hl,(speed)
	ld de,speed_inc
	or a
	sbc hl,de
	
	jp c, grow_sp_max ; if < 0
	jp z, grow_sp_max ; if == 0
	jp grow_sp_inc ; otherwise
	
grow_sp_max:
	ld hl,1
grow_sp_inc:
	ld (speed),hl
	ret

; #######################################################################################
; HANDLE INPUT
; #######################################################################################

paused_str: .db "PAU",0

handle_input
	call _getKey
	
	cp key_UP
	jp z,kp_UP
	cp key_DOWN
	jp z,kp_DOWN
	cp key_LEFT
	jp z,kp_LEFT
	cp key_RIGHT
	jp z,kp_RIGHT
	cp key_ENTER
	jp z,kp_ENTER
	ret

kp_UP:
	ld a,(dir)
	cp DIR_S
	ret z
	
	ld a, DIR_N
	ld (nxt_dir), a
	ret
	
kp_DOWN:
	ld a,(dir)
	cp DIR_N
	ret z
	
	ld a, DIR_S
	ld (nxt_dir), a
	ret
kp_LEFT:
	ld a,(dir)
	cp DIR_E
	ret z
	
	ld a, DIR_W
	ld (nxt_dir), a
	ret
kp_RIGHT:
	ld a,(dir)
	cp DIR_W
	ret z
	
	ld a, DIR_E
	ld (nxt_dir), a
	ret

kp_ENTER:
	;reset nxt_dir to ignore all input from kb while paused
	ld a,(dir)
	ld (nxt_dir),a
	
	ld a,(paused)
	xor 00000001b
	ld (paused),a
	
	cp 1 ; draw "PAUSED"
	jp z,kp_draw_paused
	
	call draw_score
	ret
	
kp_draw_paused:
	
	ld a,score_pos_x
	ld (_penCol),a
	xor a
	ld (_penRow),a
	set _txtWrToBuf, (iy + _sGrFlags) 
	
	ld hl,paused_str
	call _drawText
	call _blitBuf
	ret

; #######################################################################################
; MOVE SNAKE functions
; #######################################################################################

do_elongate:	.db	0

move_snake:
	ld a,(do_elongate)
	cp 1
	jp nz, ms_not_grown
	
	call grow_element
	jp ms_move
	
ms_not_grown: ; only if not growing
	call clear_tail
	
ms_move:
	call move_body
	call move_head
	
	ld a,(do_elongate)
	cp 1
	ret nz
	
	; if have grown...
	; not growing any more
	xor a
	ld (do_elongate),a
	
	; increase length variable
	ld hl, snake_len
	inc (hl)
	
	ret

grow_element:
	
	; copy last elem to len+1
	
	ld hl,snake
	ld de,(snake_len)
	
	add hl,de
	add hl,de
	
	ld d,h
	ld e,l
	
	dec de
	dec de
	
	ld a,(de)
	ld (hl),a
	
	inc hl
	inc de
	
	ld a,(de)
	ld (hl),a
	
	ret

clear_tail:
	;find tail
	ld hl,snake
	ld de,(snake_len)
	dec de
	
	add hl,de
	add hl,de
	
	ld a,(hl)
	inc hl
	ld b,(hl)
	
	call clr_pxl
	ret

move_body:
	ld hl,snake
	ld de,(snake_len)
	dec de
	
	add hl,de
	add hl,de
	inc hl
	
	; now copy
	ld d,h
	ld e,l	; now both pointing at y-coor of the last elem
	
	dec de
	dec de	; de is now 1 segm ahead
	
	ld a,(snake_len)
	dec a
	add a,a
	ld b,a

ms_cpy_loop:
	ld a,(de)
	ld (hl),a
	dec hl
	dec de
	dec b
	jp nz,ms_cpy_loop
	
	ret
	
	; 00 00 00
	
	; move in current dir
move_head:
	ld a,(dir)
	cp DIR_N
	jp z,mv_north
	cp DIR_S
	jp z,mv_south
	cp DIR_W
	jp z,mv_west
	cp DIR_E
	jp z,mv_east
	
mv_south:
	ld hl,snake
	inc hl
	ld a,(hl)
	inc a
	cp scr_h
	jp c, noob_south
	ld a,0
noob_south:  			; not out of bounds
	ld (hl),a
	ret
	
mv_north:
	ld hl,snake
	inc hl
	ld a,(hl)
	dec a
	jp p, noob_north	;>=0
	ld a,scr_h-1
noob_north:  			; not out of bounds
	ld (hl),a
	ret
	
mv_west:
	ld hl,snake
	ld a,(hl)
	dec a
	jp p, noob_west ; >=0
	ld a,scr_w-1
noob_west:  			; not out of bounds
	ld (hl),a
	ret

mv_east:
	ld hl,snake
	ld a,(hl)
	inc a
	cp scr_w
	jp c, noob_east
	ld a,0
noob_east:  			; not out of bounds
	ld (hl),a
	ret


; #######################################################################################
; delay: idle for a given number of cycles (given by de) in multiplicants of 0xffff
;
; input: delay de * 0xffff
; returns nothing
; #######################################################################################

;6 MHz, ie 6 000 000 / s
; 1ms = 1000 / s
; thus need to perform 6000 cycles for 1 ms

delay:
	ld hl,249				; 24*249 = 5976 cycles + 29 for the outer = 6005c
	
delay_loop:
	dec hl					; 6 cycles
	ld a,h					; 4 cycles	; cp low byte
	or l						; 4 cycles	; cmp with hi byte - if both not 0 - continue inner loop
	jp nz, delay_loop		; 10 cycles
	
	dec de					;6c
	ld a,d					;4c
	or e						;4c
	ret z						;5c
	jp delay					;10c

; thus 24c per inner loop + 29c for outer

; #######################################################################################
; draw_snake: draw snake
;
; no inputs
; returns nothing
; #######################################################################################

draw_snake:
	ld hl, snake
	ld d,0
	ld de, (snake_len)
	
	call draw_pxl_array
	
	ret

; #######################################################################################
; draw_map: draw initial map
;
; de - points to chosen level map
; returns nothing
; #######################################################################################

dmloopvar: .db 48
dmbytecnt: .db	3

draw_map:
	;reset loop vars
	ld a,48
	ld (dmloopvar),a
	ld a,3
	ld (dmbytecnt),a
	
	;start drawing
	ld hl,_vram-1
	;ld de,lvl2_map ; de should be set to chosen map before this function is called!
	ld b,00000001b
	rr b ;carry primed with 1

dmloop:
	rr b				;shift to next bit in map mask byte
	jp z,dmnxtbyte	;if it is zero, load next byte from map
	
	inc hl 			;switch to next byte in _vram for every two bits in map
	ld a,(de)		;get current map byte
	and b				;and mask
	jp z,dmbit2		;if empty - go to next bit
	ld c,11110000b
	call draw_tile
dmbit2:
	rr b				;shift to next bit in map mask byte
	ld a,(de)		;get current map byte
	and b				;and mask
	jp z,dmloop		;if there is nothing to draw, continue with next 2 bits
	ld c,00001111b
	call draw_tile
	ld a,(hl)		;load vram byte
	or c				;apply it on top of already drawn mem
	ld (hl),a		;cp to vram
	jp dmloop
dmnxtbyte:
	inc de			;load next map byte
	
	ld a,(dmloopvar)
	dec a
	ret z
	ld (dmloopvar),a
	
	ld a,(dmbytecnt)
	dec a
	ld (dmbytecnt),a
	jp nz,dmloop
	
	ld a,3
	ld (dmbytecnt),a
	
	push af
	push de
	ld de,36
	add hl,de
	pop de
	pop af
	
	jp dmloop		;continue

draw_tile
	push bc
	push de
	push hl
	
	ld b,4
	ld de,12

dt_loop:
	ld a,(hl)
	or c
	ld (hl),a
	
	add hl,de
	dec b
	jp nz, dt_loop
	
	pop hl
	pop de
	pop bc
	ret

; #######################################################################################
; gen_rnd_xy: generate random coords (a,b) within screen limits
;
; no inputs
; returns nothing
; #######################################################################################
gen_rnd_xy:
	; gen y
	ld a,scr_h-1
	call gen_rnd
	ld b,a
	; gen x
	push bc
	ld a,scr_w-1
	call gen_rnd
	pop bc
	; done
	ret

; #######################################################################################
; PIXEL MANIPULATION
; #######################################################################################

; #######################################################################################
; put_pxl: put pixel at (a,b)
;
; kills bascially everything
; returns nothing
; #######################################################################################

put_pxl:
	call get_vram_addr
	
	ld hl, bitmasks
	ld b,0
	add hl,bc
	ld c,(hl) ; bitmask is now stored in c
	
	ld hl, _vram
	add hl,de
	ld a,(hl)
	or c			; XOR
	
	ld (hl),a 	; put back the byte
	ret

; #######################################################################################
; clr_pxl: clear pixel at (a,b)
;
; kills bascially everything
; returns nothing
; #######################################################################################

clr_pxl:
	;the same as put_pxl, but with an extra NOT (cpl) and AND
	call get_vram_addr
	
	ld hl, bitmasks
	ld b,0
	add hl,bc
	ld c,(hl) ; bitmask is now stored in c
	ld a,c
	cpl			;NOT
	ld c,a
	
	ld hl, _vram
	add hl,de
	ld a,(hl)
	and c			; AND
	
	ld (hl),a 	; put back the byte
	ret

; get pixel val from (a,b)
; returns a

get_pxl:
	; TODO
	call get_vram_addr
	
	ld hl, bitmasks
	ld b,0
	add hl,bc
	ld c,(hl) ; bitmask is now stored in c
	
	ld hl, _vram
	add hl,de
	ld a,(hl)
	and c			; AND
	
	ret

; #######################################################################################
; get_vram_addr: convert coords (a,b) to array idx (de) and which bit to flip (c)
;
; kills bascially everything
; returns de, c
; #######################################################################################

get_vram_addr:	
	; idx = y*scr_w_ch + (int)(x/8)
	; bit = rest after div
	
	ld d,a
	ld e,8
	push de
	
	; y*scr_w_b
	ld a,b
	ld b,scr_w_b
	call mul 		;result in hl
	
	pop de	; get ready for division
	push hl 	; push result on the stack
	call div	; now a = result, b = rest
	
	ld d,0
	ld e,a
	
	pop hl
	add hl,de
	
	; return values
	ld d,h
	ld e,l
	
	ld c,b
	
	ret


; #######################################################################################
; div: perform multiplication of two 8 byte integers hl = a*b
;
; kills de, hl, ab
; returns hl
; #######################################################################################

mul:
	ld hl,0
	ld d,0
	
	; is a == 0?
	cp d
	jp z, mul_zero
	
	; speed up by forking according to a>b?
	cp b
	jp c,mul_b_lt_a
	
	;a>b
	ld e,a
	jp mul_loop
    
	;b>a
mul_b_lt_a:
	ld e,b
	ld b,a

mul_loop:
	add hl,de
	dec b
	jp pe, mul_zero ; b == -1, ie was == 0
	jp nz, mul_loop
	
	ret
	
mul_zero: ; multipleier is zero
	ld hl,0
	ret
    

; #######################################################################################
; div_unsafe: perform 8 byte integer division d = a/b, e = rest
; NB! div/0 will hang the machine!
;
; kills <none>
; returns de
; #######################################################################################
div_unsafe:
	ld d,0
	
div_unsafe_loop:
	inc d
	sub b
	jp nc, div_unsafe_loop
	
	dec d
	add a,b
	ld e,a 
	ret


; #######################################################################################
; div: perform 8 byte integer division a = d/e, b = rest
;
; kills <none>
; returns ab
; #######################################################################################

div:
	; avoid div/0
	ld a,0
	cp e
	jp nz, div_non_zero
	ld b,0
	ret

div_non_zero:
	ld a,d
	ld d,0
div_loop:
	inc d
	sub e
	jp nc, div_loop
	
	dec d		; wind back div counter with 1
	add a,e	; add divident to get rest
	
	; store in de
	ld b,a
	ld a,d
	ret


; #######################################################################################
; gen_rnd: generate a random number from 0 up to and including max
;
; reg a = max value <256
; kills e
; returns a
; #######################################################################################

rnd_seed: .db 123

gen_rnd:
	ld e,a
	push de			; save parsed params
	
	; the slow old method
	;call _rndFloat	; call internal routine
   ;ld a,(_OP1+6)	; get the random nr stored in (OP1 + 6)
   
   ; the faster r-reg method
   ld a,(rnd_seed)
   ld d,a
   ld a,r
   add a,d
   ld (rnd_seed),a
   
   pop de 			; get parsed params back
gen_rnd_loop:
	sub e				; a-e
	jp nc,gen_rnd_loop ; if result < 0, continue
	
	add a,e			; add max_val to result to make it positive
	ld e,a			; store it in e
	
	; this is to make this function inclusive of max_val
	ld a,r			; get mem refresh register
	and 00000010b	; mask bit 6 only (the last bit (7) is not altered by mem refresh)
	jp z,gen_rnd_finished
	
	inc e				; if the bit is 1, increase value
	
gen_rnd_finished:
	ld a,e			; store return value in a
	ret

; #######################################################################################
; sprites and other mem defines

; LUTS

bitmasks:
	.db 10000000b ;0
	.db 01000000b ;1
	.db 00100000b ;2
	.db 00010000b ;3
	.db 00001000b ;4
	.db 00000100b ;5
	.db 00000010b ;6
	.db 00000001b ;7

; stores location of all snake segments
snake:
	.db  48, 31,  47, 31,  46, 31, 255,255, 255,255, 255,255, 255,255, 255,255,
	.db 255,255, 255,255, 255,255, 255,255, 255,255, 255,255, 255,255, 255,255,
	.db 255,255, 255,255, 255,255, 255,255, 255,255, 255,255, 255,255, 255,255,
	.db 255,255, 255,255, 255,255, 255,255, 255,255, 255,255, 255,255, 255,255,
	.db 255,255, 255,255, 255,255, 255,255, 255,255, 255,255, 255,255, 255,255,
	.db 255,255, 255,255, 255,255, 255,255, 255,255, 255,255, 255,255, 255,255,
	.db 255,255, 255,255, 255,255, 255,255, 255,255, 255,255, 255,255, 255,255,
	.db 255,255, 255,255, 255,255, 255,255, 255,255, 255,255, 255,255, 255,255

; stores location of all apples
apples:
	.db 10,10, 15,10, 20,10, 25,10, 30,10,
	.db 35,10, 40,10, 45,10, 50,10, 55,10

; assets

; LVL 1
lvl1_map: ;3x16 bytes
	.db 10000000b,00011000b,00000000b,
	.db 00000000b,00010000b,00100000b,
	.db 00011011b,00011000b,11111000b,
	.db 00001110b,00001000b,01110000b,
	.db 00011011b,00011000b,11111000b,
	.db 00000000b,00010000b,00100000b,
	.db 00000000b,00110000b,00000000b,
	.db 10111011b,11000001b,01110111b,
	.db 11101110b,11100111b,11011101b,
	.db 00000000b,00011100b,00000000b,
	.db 00000100b,00001000b,00000000b,
	.db 00011111b,00011000b,11011000b,
	.db 00001110b,00010000b,01110000b,
	.db 00011111b,00011000b,11011000b,
	.db 00000100b,00001000b,00000000b,
	.db 00000000b,00011000b,00000001b,

; LVL 2
lvl2_map: ;3x16 bytes
	.db 00001000b,00000000b,00001000b,
	.db 11101011b,11111111b,11101011b,
	.db 00001010b,00000000b,00101000b,
	.db 01111010b,11111111b,10101110b,
	.db 00001010b,10000000b,10101000b,
	.db 11101010b,10111110b,10101011b,
	.db 00001010b,10100010b,10101000b,
	.db 01111010b,10100000b,10101110b,
	.db 00001010b,10100000b,10101000b,
	.db 11101010b,10111111b,10101011b,
	.db 00001010b,10000000b,00101000b,
	.db 01111010b,11111111b,11101110b,
	.db 00001010b,00000000b,00001000b,
	.db 11101011b,11111111b,11111011b,
	.db 00001000b,00000000b,00000000b,
	.db 01111000b,00000000b,00000000b,

; LVL 3
lvl3_map: ;3x16 bytes
	.db 10000000b,00011000b,00011111b,
	.db 11000000b,00011000b,00001111b,
	.db 11000000b,00001100b,00001111b,
	.db 01100000b,00001110b,00000111b,
	.db 01100000b,10000110b,00000111b,
	.db 00110001b,11000110b,00110011b,
	.db 00110000b,10000011b,00110011b,
	.db 00111000b,00000011b,00000001b,
	.db 00111000b,00000001b,10000001b,
	.db 00011100b,00000001b,10000000b,
	.db 00011100b,00001000b,11000000b,
	.db 00001110b,00011100b,11000010b,
	.db 00000110b,00001000b,01100000b,
	.db 00100011b,00000000b,01100000b,
	.db 00000011b,00000000b,00110000b,
	.db 00000011b,10000000b,00110000b,
	
; LVL 4
lvl4_map: ;3x16 bytes
	.db 00000110b,00011000b,01100000b,
	.db 00000000b,00000000b,00000000b,
	.db 00110000b,11000011b,00001100b,
	.db 00110000b,11000011b,00001100b,
	.db 00000000b,00000000b,00000000b,
	.db 00000110b,00011000b,01100000b,
	.db 00000110b,00011000b,01100000b,
	.db 00000000b,00000000b,00000000b,
	.db 00110000b,11000011b,00001100b,
	.db 00110000b,11000011b,00001100b,
	.db 00000000b,00000000b,00000000b,
	.db 00000110b,00011000b,01100000b,
	.db 00000110b,00011000b,01100000b,
	.db 00000000b,00000000b,00000000b,
	.db 00110000b,11000011b,00001100b,
	.db 00000000b,00000000b,00000000b,

; LVL 5
lvl5_map: ;3x16 bytes
	.db 00000011b,00110011b,00110000b,
	.db 11000000b,00000000b,00000000b,
	.db 11001100b,11001100b,11001000b,
	.db 11001100b,11001100b,11001000b,
	.db 11001100b,11001100b,11001000b,
	.db 11001100b,11001100b,11001000b,
	.db 00001100b,11111111b,11001000b,
	.db 00011111b,11000000b,11111000b,
	.db 00010011b,00000000b,00110000b,
	.db 00010011b,00110011b,00110011b,
	.db 00010011b,00110011b,00110011b,
	.db 00010011b,00110011b,00110011b,
	.db 00010011b,00110011b,00110011b,
	.db 00010011b,00110011b,00110011b,
	.db 00000000b,00000000b,00000000b,
	.db 11001100b,11001100b,11001100b,

; main menu bkg
menu_bkg:
	.db 11111111b,11001101b,10111111b,11111000b,00001111b,11111000b,00000000b,00000000b,01111110b,00000000b,00000000b,00000000b,
	.db 10000000b,00011111b,00011111b,00000011b,11100111b,11111011b,11101110b,01100011b,00111100b,11101001b,00110010b,01011110b,
	.db 00111111b,10110000b,00000111b,01000100b,00010011b,11111000b,10000100b,10010100b,10011101b,00001101b,01001010b,10010000b,
	.db 01110000b,01000111b,11110001b,00100010b,01001001b,11111110b,10000100b,01100001b,00111100b,11001011b,01111011b,00011100b,
	.db 00100001b,11111110b,00011100b,10011111b,00000100b,11111110b,10000100b,10010100b,10011100b,00101001b,01001010b,10010000b,
	.db 10000111b,00000011b,00010110b,00100011b,00000010b,01111110b,10001110b,01100011b,00111101b,11001001b,01001010b,01011110b,
	.db 11101100b,00000001b,10001010b,01000100b,01110001b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,
	.db 11001000b,00000000b,10000001b,00010011b,10001000b,11111111b,11111111b,11111111b,11111111b,11111111b,11111111b,11111100b,
	.db 11011000b,10000000b,11000011b,00111000b,00100100b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000010b,
	.db 10010001b,00010000b,01000000b,10111111b,11110010b,10101010b,10101010b,10101010b,10101010b,10101010b,10101010b,10000010b,
	.db 10010111b,01000000b,00000010b,10000000b,00000001b,11111111b,11111111b,11111111b,11111111b,11111111b,11111111b,11000010b,
	.db 10010110b,01010000b,10001000b,10011111b,11111111b,11111111b,11111111b,11111111b,11111111b,11111111b,11111111b,11100010b,
	.db 10100111b,10001000b,00100000b,10100000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00100010b,
	.db 10100111b,10100100b,00000001b,10100001b,01010101b,01010101b,01010101b,01010101b,01010101b,01010101b,01010101b,00100010b,
	.db 10110110b,11011000b,00000000b,10100001b,11111111b,11111111b,11111111b,11111111b,11111111b,11111111b,11111111b,10100010b,
	.db 10010111b,11101001b,00101000b,10100010b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00100010b,
	.db 10010111b,10101010b,00000001b,10100010b,10101010b,10101010b,10101010b,10101010b,10101010b,10101010b,10101010b,10100010b,
	.db 11001011b,11110100b,10100001b,00100001b,11111111b,11111111b,11111111b,11111111b,11111111b,11111111b,11111111b,11000010b,
	.db 11000101b,11111010b,01000110b,00100000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000010b,
	.db 11110110b,00111111b,10001100b,10100101b,01010101b,01010101b,01010101b,01010101b,01010101b,01010101b,01010101b,01010010b,
	.db 11110011b,11000000b,00111001b,10101111b,11111111b,11111111b,11111111b,11111111b,11111111b,11111111b,11111111b,11111110b,
	.db 11111000b,01111111b,11100011b,10011111b,11111111b,11111111b,11111111b,11111111b,11111111b,11111111b,11111111b,11111100b,
	.db 11111110b,00000000b,00001111b,11000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000001b,
	.db 11111111b,11111111b,11111111b,11111111b,11111111b,11111111b,11111111b,11111111b,11111111b,11111111b,11111111b,11111111b,
	.db 00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,
	.db 10000011b,11111111b,11111111b,11110000b,00000111b,11111111b,11111111b,11100000b,00001111b,11111111b,11111111b,11000001b,
	.db 00000010b,00000000b,11000000b,00010000b,00000100b,00000010b,00000011b,11100000b,00001000b,10101010b,10101000b,01000000b,
	.db 10000010b,00010000b,11000000b,00010000b,00000110b,00000011b,00000001b,11100000b,00001100b,00000000b,00000000b,01000001b,
	.db 00000010b,00111000b,11000111b,00010000b,00000110b,00000001b,10001000b,11100000b,00001101b,01010101b,01010100b,01000000b,
	.db 10000010b,00111000b,11000101b,00010000b,00000101b,00001000b,11000000b,01100000b,00001101b,01010101b,01010100b,01000001b,
	.db 00000010b,00010000b,11000000b,00010000b,00000101b,10001000b,01100000b,01100000b,00001101b,01010101b,01010100b,01000000b,
	.db 10000010b,00000000b,11000000b,00010000b,00000100b,10000000b,00110001b,00100000b,00001101b,01010101b,01010100b,01000001b,
	.db 00000011b,11111111b,11111111b,11110000b,00000100b,01000000b,00011000b,00100000b,00001001b,11111111b,11111100b,01000000b,
	.db 10000010b,00000000b,11000000b,00010000b,00000100b,00110000b,00001100b,00100000b,00001000b,10101010b,10101000b,11000001b,
	.db 00000010b,00000000b,11000010b,00010000b,00000100b,00011000b,11000110b,00100000b,00001000b,10101010b,10101000b,11000000b,
	.db 10000010b,00101000b,11000111b,00010000b,00000100b,00001100b,01100011b,00100000b,00001000b,10101010b,10101000b,11000001b,
	.db 00000010b,00111000b,11000111b,00010000b,00000101b,10000100b,00000001b,00100000b,00001000b,10101010b,10101000b,11000000b,
	.db 10000010b,00000000b,11000010b,00010000b,00000101b,00000110b,00000000b,10100000b,00001000b,00000000b,00000000b,11000001b,
	.db 00000010b,00000000b,11000000b,00010000b,00000100b,00000011b,00000000b,11100000b,00001000b,01010101b,01010000b,01000000b,
	.db 10000011b,11111111b,11111111b,11110000b,00000111b,11111111b,11111111b,11100000b,00001111b,11111111b,11111111b,11000001b,
	.db 00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,
	.db 10000011b,11111111b,11111111b,11110000b,00000111b,11111111b,11111111b,11100000b,00001111b,11111111b,11111111b,11000001b,
	.db 00000010b,00000000b,00000000b,00010000b,00000100b,00000000b,00000000b,00100000b,00001000b,00000000b,00000000b,01000000b,
	.db 10000011b,00000000b,00000000b,00010000b,00000101b,00010001b,00010001b,00100000b,00001000b,01100000b,01111111b,01000001b,
	.db 00000010b,00011111b,11111110b,00110000b,00000100b,01000100b,01000100b,00100000b,00001000b,01110000b,01000001b,01000000b,
	.db 10000011b,00010000b,00000010b,00010000b,00000101b,00010001b,00010001b,00100000b,00001000b,00100000b,01011001b,01000001b,
	.db 00000010b,00010111b,11111010b,00110000b,00000100b,01000100b,01000100b,00100000b,00001000b,01101100b,01011001b,01000000b,
	.db 10000011b,00010100b,00001010b,00010000b,00000101b,00010001b,00010001b,00100000b,00001000b,01110000b,01000001b,01000001b,
	.db 00000010b,00010100b,00101010b,00110000b,00000100b,01000100b,01000100b,00100000b,00001000b,10100000b,01000101b,01000000b,
	.db 10000011b,00010111b,11101010b,00010000b,00000101b,00010001b,00010001b,00100000b,00001001b,00110000b,01000001b,01000001b,
	.db 00000010b,00010000b,00001010b,00110000b,00000100b,01000100b,01000100b,00100000b,00001000b,00111000b,01000001b,01000000b,
	.db 10000011b,00011111b,11111010b,00010000b,00000101b,00010001b,00010001b,00100000b,00001000b,01100100b,01000001b,01000001b,
	.db 00000010b,00000000b,00000010b,00110000b,00000100b,01000100b,01000100b,00100000b,00001000b,01000100b,01000001b,01000000b,
	.db 10000010b,00000000b,00000000b,00010000b,00000101b,00010001b,00010001b,00100000b,00001000b,10000010b,01111111b,01000001b,
	.db 00000011b,11111111b,11111111b,11110000b,00000100b,00000000b,00000000b,00100000b,00001000b,00000000b,00000000b,01000000b,
	.db 10000000b,00000000b,00000000b,00000000b,00000111b,11111111b,11111111b,11100000b,00001111b,11111111b,11111111b,11000001b,
	.db 00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00110000b,10001001b,00100000b,00010000b,11000100b,
	.db 01010100b,11000000b,01100010b,01110010b,01100111b,00000101b,00100000b,01001001b,01010101b,01010000b,00101000b,00101010b,
	.db 01010101b,01000000b,01010101b,00100101b,01010100b,00000101b,01010000b,10110100b,01010101b,00100010b,10101000b,01000010b,
	.db 01010101b,11011000b,01100101b,00100111b,01100110b,01100110b,01010000b,10100100b,10010101b,01010010b,10101000b,00100100b,
	.db 01010101b,01010100b,01000101b,00100101b,01000100b,01010101b,01010000b,01001001b,00010101b,01010010b,10101000b,00101000b,
	.db 01001001b,01010100b,01000010b,00100101b,01000111b,01010101b,00100000b,00110001b,11001001b,00100001b,00010010b,11001110b,
	.db 00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,

game_over_bkg:
	.db 00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,
	.db 00011011b,11011111b,11110011b,11011101b,11100000b,11011000b,00000000b,00110110b,01111101b,11100001b,10110001b,11101100b,
	.db 00111011b,11000111b,01111011b,11111110b,11110001b,11011100b,00000000b,01110111b,00111101b,11100011b,10111001b,11111110b,
	.db 01111011b,11000111b,01111011b,11011110b,11110011b,11011110b,00000000b,11110111b,10111110b,11000111b,10111101b,11101110b,
	.db 01111011b,11000101b,01111011b,01011110b,11010011b,11011110b,00000000b,10110111b,10011110b,11000110b,10111101b,11100110b,
	.db 01011010b,11001111b,01011011b,11011010b,11110011b,01000000b,00000000b,11110110b,10010111b,11000111b,10000001b,10100000b,
	.db 01111011b,11001111b,01111011b,11011110b,11110011b,11000010b,00000000b,11110111b,10011111b,10000111b,10000101b,11100000b,
	.db 00111011b,11001111b,01111011b,11011110b,11110001b,11000100b,00000000b,01110111b,00001111b,00000011b,10001001b,11100000b,
	.db 00011011b,11000111b,11111011b,11011110b,11110000b,11111000b,00000000b,00110110b,00001111b,10000001b,11110001b,11100000b,
	.db 00000011b,11000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,
	.db 00000011b,10000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,
	.db 00011000b,00000000b,00000000b,00000000b,00000000b,00000111b,11110000b,00000000b,00000000b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,00000000b,00000000b,00111111b,11111110b,00000000b,00000000b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,00000000b,00000000b,11111111b,11111111b,10000000b,00000000b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,00000000b,00000001b,11111111b,11111111b,11000000b,00000000b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,00000000b,00000011b,11111111b,11111111b,11100000b,00000000b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,00000000b,00000111b,11111111b,11111111b,11110000b,00000000b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,00000000b,00001111b,11111111b,11111111b,11111000b,00000000b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,00000000b,00011111b,11111111b,11111111b,11111100b,00000000b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,00000000b,00011111b,11111111b,11111111b,11111100b,00000000b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,00000000b,00011111b,11111111b,11111111b,11111100b,00000000b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,00111100b,00111111b,11111111b,11111111b,11111110b,00011110b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,00111110b,00111111b,11111111b,11111111b,11111110b,00111110b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,01111111b,00111111b,11111111b,11111111b,11111110b,01111111b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,01111111b,10111111b,11111111b,11111111b,11111110b,11111111b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,11111111b,10111111b,11111111b,11111111b,11111110b,11111111b,10000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000001b,11111111b,10111111b,11111111b,11111111b,11111110b,11111111b,11000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,11111111b,10111111b,11111111b,11111111b,11111111b,11111111b,10000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,11111111b,11111111b,11111111b,11111111b,11111111b,11111111b,10000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,01111111b,11010111b,11011111b,11111101b,11110101b,11111111b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,00000111b,11011100b,00000111b,11110000b,00111101b,11110000b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,00000000b,00011100b,00000011b,11100000b,00011100b,00000000b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,00000000b,00001100b,00000001b,11000000b,00011100b,00000000b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,00000000b,00001100b,00000011b,11100000b,00011000b,00000000b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,00000000b,00011100b,00000011b,11100000b,00011100b,00000000b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,00000000b,00111100b,00000111b,11110000b,00011100b,00000000b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,00000000b,00011100b,00011110b,10111100b,00011100b,00000000b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,00000000b,00011111b,11111100b,10011111b,11111100b,00000000b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,00000000b,00001111b,11111100b,10011111b,11111000b,00000000b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,00000000b,00000111b,11111100b,10011111b,11110000b,00000000b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,00000000b,00000011b,11111100b,10011111b,11100000b,00000000b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,00000000b,00000011b,00111111b,10111110b,01100000b,00000000b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,00000000b,00001111b,00111111b,11111110b,01111000b,00000000b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,00000000b,00111011b,00111111b,11111110b,11111110b,00000000b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,00000011b,11111011b,10011111b,11111100b,11101111b,11000000b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,01111111b,11111011b,11101111b,11111111b,11111111b,11111111b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,11111111b,11111101b,11111111b,01101011b,11011111b,11111111b,10000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,11111111b,11111001b,11111001b,01001111b,10001111b,11111111b,10000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,11111111b,11100000b,11111110b,00011111b,10000011b,11111111b,10000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,01111111b,11000000b,11111010b,00001111b,10000001b,11111111b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,00111111b,10000000b,01111111b,11111111b,00000000b,11111110b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,00111111b,00000000b,01111111b,11111110b,00000000b,01111110b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,00111110b,00000000b,00111111b,11111100b,00000000b,01111100b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,00000000b,00000000b,00001111b,11111000b,00000000b,00000000b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,00000000b,00000000b,00000111b,11110000b,00000000b,00000000b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,
	.db 00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,
	.db 00000001b,10011001b,10011001b,10001101b,00101110b,11011000b,01110010b,00001000b,10010010b,11101010b,01010010b,11000000b,
	.db 00100001b,01010101b,00100010b,00001001b,10100100b,10010100b,00100101b,00010101b,01011010b,01001011b,01010010b,10001000b,
	.db 01111001b,10011001b,10010001b,00001101b,01100100b,11011000b,00100101b,00010001b,01010110b,01001010b,11010010b,11011110b,
	.db 00010001b,00010101b,00001000b,10001001b,00100100b,10010100b,00100101b,00010101b,01010010b,01001010b,01010010b,10000100b,
	.db 00000001b,00010101b,10110011b,00001101b,00100100b,11010100b,00100010b,00001000b,10010010b,01001010b,01001100b,11000000b,
	.db 00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,

.end
