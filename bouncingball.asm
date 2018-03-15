;bouncingball.asm - Example ROM for the NES (Nintendo Entertainment System) showing a bouncing ball. Written in 6502 Assembly.
;by Mark Bouwman (https://github.com/MarkBouwman)
  
  .inesprg 1   ; 1x 16KB PRG code
  .ineschr 1   ; 1x  8KB CHR data
  .inesmap 0   ; mapper 0 = NROM, no bank swapping
  .inesmir 1   ; background mirroring

; Hardware constants CPU
ControllerPort1       = $4016
PPU_CTRL_REG1         = $2000
PPU_CTRL_REG2         = $2001
PPU_STATUS            = $2002
PPU_SPR_ADDR          = $2003
PPU_SPR_DATA          = $2004
PPU_SCROLL_REG        = $2005
PPU_ADDRESS           = $2006
PPU_DATA              = $2007

; Hardware constants PPU
PPU_Attribute_0_Hi  = $23               ; This is the PPU address of attribute table 0
PPU_Attribute_0_Lo  = $C0

; Sprite constants
sprite_RAM      = $0200                 ; starting point of the sprite data
sprite_YPOS     = $0200                 ; sprite Y position
sprite_Tile     = $0201                 ; sprite tile number
sprite_Attr     = $0202                 ; sprite attribute byte
sprite_XPOS     = $0203                 ; sprite X position

; Game constants
RIGHT_WALL               = $F4
LEFT_WALL                = $01
TOP_WALL                 = $03
BOTTOM_WALL              = $DB
BALL_SPEED               = $02
BALL_MOVEMENT_LEFT       = %00000010
BALL_MOVEMENT_RIGHT      = %00000001
BALL_MOVEMENT_UP         = %00000010
BALL_MOVEMENT_DOWN       = %00000001

; Variables
  .rsset $0000                          ; start variables at ram location 0
ball_x                  .rs 1           ; The X position of the ball 
ball_y                  .rs 1           ; The Y position of the ball
ball_movement_x         .rs 1           ; reserve 1 byte to store the ball movement state for X
ball_movement_y         .rs 1           ; reserve 1 byte to store the ball movement state for Y

  .bank 0
  .org $C000 
RESET:                                  ; This is the reset interupt
  SEI                                   ; disable IRQs
  CLD                                   ; disable decimal mode
  LDX #$40
  STX $4017                             ; disable APU frame IRQ
  LDX #$FF
  TXS                                   ; Set up stack
  INX                                   ; now X = 0
  STX PPU_CTRL_REG1                     ; disable NMI
  STX PPU_CTRL_REG2                     ; disable rendering
  STX $4010                             ; disable DMC channel IRQs

  JSR VBlankWait                        ; First wait for vblank to make sure PPU is ready

clrmem:                                 ; Simple loop to clear all the memory
  LDA #$00
  STA $0000, x
  STA $0100, x
  STA $0300, x
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x
  LDA #$FE
  STA $0200, x                          ;move all sprites off screen
  INX
  BNE clrmem
   
  JSR VBlankWait                        ; Second wait for vblank, PPU is ready after this

; init PPU
  LDA #%10010000                        ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  STA PPU_CTRL_REG1
  LDA #%00011110                        ; enable sprites, enable background, no clipping on left side
  STA PPU_CTRL_REG2

  LDA #$80                              ; set the initial position of the ball
  STA ball_x
  STA ball_y
  LDA #BALL_MOVEMENT_UP             
  STA ball_movement_y
  LDA #BALL_MOVEMENT_RIGHT
  STA ball_movement_x                   ; Initially the ball goes right and down

  JSR LoadPalette                       ; Load the color palette
  JSR SetBallTileConfig                 ; Load the ball sprites
; start game loop
GameLoop:
  JMP GameLoop                          ;jump back to GameLoop, infinite loop

; NMI
NMI:
  JSR SpriteDMA                         ; load in the sprites for the ball 

  LDA #%10010000                        ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  STA PPU_CTRL_REG1
  LDA #%00011110                        ; enable sprites, enable background, no clipping on left side
  STA PPU_CTRL_REG2
  LDA #$00                              ;tell the ppu there is no background scrolling
  STA PPU_SCROLL_REG

MoveLeft:
  LDA ball_movement_x
  AND #BALL_MOVEMENT_LEFT
  BEQ MoveLeftDone
  LDA ball_x
  SEC
  SBC #BALL_SPEED
  STA ball_x
  CMP #LEFT_WALL
  BCS MoveLeftDone
  LSR ball_movement_x
MoveLeftDone:  
MoveRight:
  LDA ball_movement_x
  AND #BALL_MOVEMENT_RIGHT
  BEQ MoveRightDone
  LDA ball_x
  CLC
  ADC #BALL_SPEED
  STA ball_x
  CMP #RIGHT_WALL
  BCC MoveRightDone
  ASL ball_movement_x
MoveRightDone:
MoveUp:
  LDA ball_movement_y
  AND #BALL_MOVEMENT_UP
  BEQ MoveUpDone
  LDA ball_y
  SEC
  SBC #BALL_SPEED
  STA ball_y
  CMP #TOP_WALL
  BCS MoveUpDone
  LSR ball_movement_y
MoveUpDone:
MoveDown:
  LDA ball_movement_y
  AND #BALL_MOVEMENT_DOWN
  BEQ MoveDownDone
  LDA ball_y
  CLC
  ADC #BALL_SPEED
  STA ball_y
  CMP #BOTTOM_WALL
  BCC MoveDownDone
  ASL ball_movement_y
MoveDownDone:

DrawBall:
  LDA ball_y
  STA sprite_YPOS
  STA sprite_YPOS+4
  CLC
  ADC #$08                              ; Add 8 to move to the next row
  STA sprite_YPOS+8
  STA sprite_YPOS+12
 
  LDA ball_x
  STA sprite_XPOS
  STA sprite_XPOS+8
  CLC
  ADC #$08                              ; Add 8 to move to the next column
  STA sprite_XPOS+4
  STA sprite_XPOS+12

  RTI                                   ; return from interrupt

; Sub routines
SpriteDMA:                              ; Sprite DMA subroutine                     
  LDA #$00
  STA PPU_SPR_ADDR
  LDA #$02                                                        
  STA $4014
  RTS
VBlankWait:
  BIT $2002
  BPL VBlankWait
  RTS  
LoadPalette:
  LDA PPU_STATUS                        ; read PPU status to reset the high/low latch
  LDA #$3F
  STA PPU_ADDRESS                       ; write the high byte of $3F00 address
  LDA #$10
  STA PPU_ADDRESS                       ; write the low byte of $3F00 address
  LDX #$00                              ; start out at 0
LoadPaletteLoop:
  LDA palette, x                        ; load data from address (palette + the value in x)
  STA PPU_DATA                          ; write to PPU
  INX                                   ; X = X + 1
  CPX #$10                              ; Compare X to hex $10, decimal 16 - copying 16 bytes = 4 sprites
  BNE LoadPaletteLoop                   ; Branch to LoadPalettesLoop if compare was Not Equal to zero
  RTS                                   ; if compare was equal to 32, keep going down 
SetBallTileConfig:
  LDX #$00
  LDY #$00
SetBallTileConfigLoop:                  ; Loop through the sprite setup / config and write it to the sprite addresses
  LDA BallSpriteSetup, y
  STA sprite_Tile,x
  LDA BallSpriteConfig, y
  STA sprite_Attr,x
  INX
  INX
  INX
  INX                                   ; Increment X four times to get to the next sprite
  INY
  CPY #$04
  BNE SetBallTileConfigLoop
  RTS  


  .bank 1
  .org $E000

palette:
  .db $0F,$20,$10,$00, $0F,$20,$10,$00, $0F,$20,$10,$00, $0F,$20,$10,$00


BallSpriteSetup:
  .db $00,$01,$10,$11

BallSpriteConfig:
  .db $00,$00,$00,$00


  .org $FFFA     
  .dw NMI                                         ; NMI interupt, jump to NMI label
  .dw RESET                                       ; Reset interupt, jump to RESET label
  .dw 0                                           ; external interrupt IRQ is not used

  .bank 2
  .org $0000
  .incbin "bouncingball.chr"