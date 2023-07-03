  .org $8000
  .org $c000

IN          = $0200   ;*Input buffer
XAML        = $24     ;*Index pointers
XAMH        = $25
STL         = $26
STH         = $27
L           = $28
H           = $29
YSAV        = $2A
MODE        = $2B
MSGL        = $2C
MSGH        = $2D
COUNTER     = $2E
CRC         = $2F
CRCCHECK    = $30

PORTB = $6000
PORTA = $6001
DDRB = $6002
DDRA = $6003

E  = %01000000
RW = %00100000
RS = %00010000

ACIA_DATA = $5000
ACIA_STATUS = $5001
ACIA_CMD = $5002
ACIA_CTRL = $5003

RESET:
      LDA #$00
      STA ACIA_STATUS
      LDA #$1F        ; 8-N-1, 19200 baud
      STA ACIA_CTRL
      LDA #$0B        ; No parity, no echo, no interrupts
      STA ACIA_CMD
      LDX #$FF
      TXS
      LDA #%11111111  ; All pins on port B to output
      STA DDRB
      LDA #%10111111
      STA DDRA
      JSR LCD_INIT
      LDA #%00101000  ; Set 4-bit mode; 2-line display; 5x8 font
WOZMON:
      JSR LCD_INSTRUCTION
      LDA #%00001110  ; Display on; cursor on; blink off
      JSR LCD_INSTRUCTION
      LDA #%00000110  ; Increment and shift cursor; don't shift display
      JSR LCD_INSTRUCTION
      LDA #%00000001  ; Clear display
      JSR LCD_INSTRUCTION
      LDX #0
PRINT_MSG:
      LDA LCD_MSG, x
      BEQ DONE_1
      JSR PRINT_CHAR
      INX
      JMP PRINT_MSG
DONE_1:
      LDX #0
SEND_MSG:
      LDA CONS_MSG, x
      BEQ DONE_2
      JSR SEND_CHAR
      INX
      JMP SEND_MSG
DONE_2:
      LDA #$0D        ; Send CR
      JSR ECHO        ; Output it.
      LDA  #$1B       ; Begin with escape
NOTCR:
      CMP #$08        ; Backspace key?
      BEQ BACKSPACE   ; Yes.
      CMP #$1B        ; ESC?
      BEQ ESCAPE      ; Yes.
      INY             ; Advance text index.
      BPL NEXTCHAR    ; Auto ESC if line longer than 127.
ESCAPE:
      LDA   #$5C      ; "\"
      JSR ECHO        ; Output it.
GETLINE:
      LDA #$0D        ; Send CR
      JSR ECHO        ; Output it.
      LDY #$01        ; Initiallize text index.
BACKSPACE:
      DEY             ; Backup text index.
      BMI GETLINE     ; Beyond start of line, reinitialize.
NEXTCHAR:
      LDA ACIA_STATUS ; Check status.
      AND #$08        ; Key ready?
      BEQ NEXTCHAR    ; Loop until ready.
      LDA ACIA_DATA   ; Load character. B7 will be '0'.
      STA IN,Y        ; Add to text buffer.
      JSR ECHO        ; Display character.
      CMP #$0D        ; CR?
      BNE NOTCR       ; No.
      LDY #$FF        ; Reset text index.
      LDA #$00        ; For XAM mode.
      TAX             ; 0->X.
SETBLOCK:
      ASL
SETSTOR:
      ASL             ; Leaves $7B if setting STOR mode.
      STA MODE        ; $00 = XAM, $74 = STOR, $B8 = BLOK XAM.
BLSKIP:
      INY             ; Advance text index.
NEXTITEM:
      LDA IN,Y        ; Get character.
      CMP #$0D        ; CR?
      BEQ GETLINE     ; Yes, done this line.
      CMP #$2E        ; "."?
      BCC BLSKIP      ; Skip delimiter.
      BEQ SETBLOCK    ; Set BLOCK XAM mode.
      CMP #$3A        ; ":"?
      BEQ SETSTOR     ; Yes, set STOR mode.
      CMP #$52        ; "R"?
      BEQ RUN         ; Yes, run user program.
      STX L           ; $00->L.
      STX H           ; and H.
      STY YSAV        ; Save Y for comparison.
NEXTHEX:
      LDA IN,Y        ; Get character for hex test.
      EOR #$30        ; Map digits to $0-9.
      CMP #$0A        ; Digit?
      BCC DIG         ; Yes.
      ADC #$88        ; Map letter "A"-"F" to $FA-FF.
      CMP #$FA        ; Hex letter?
      BCC NOTHEX      ; No, character not hex.
DIG:
      ASL
      ASL             ; Hex digit to MSD of A.
      ASL
      ASL
      LDX #$04        ; Shift count.
HEXSHIFT:
      ASL             ; Hex digit left MSB to carry.
      ROL L           ; Rotate into LSD.
      ROL H           ; Rotate into MSD's.
      DEX             ; Done 4 shifts?
      BNE HEXSHIFT    ; No, loop.
      INY             ; Advance text index.
      BNE NEXTHEX     ; Always taken. Check next character for hex.
NOTHEX:
      CPY YSAV        ; Check if L, H empty (no hex digits).
      BEQ ESCAPE      ; Yes, generate ESC sequence.
      BIT MODE        ; Test MODE byte.            
      BVC NOTSTOR     ; B6=0 for STOR, 1 for XAM and BLOCK XAM
      LDA L           ; LSD's of hex data.
      STA (STL, X)    ; Store at current "store index".
      INC STL         ; Increment store index.
      BNE NEXTITEM    ; Get next item. (no carry).
      INC STH         ; Add carry to 'store index' high order.
TONEXTITEM:
      JMP NEXTITEM    ; Get next command item.
RUN:
      JMP (XAML)      ; Run at current XAM index.
NOTSTOR:
      BMI XAMNEXT     ; B7=0 for XAM, 1 for BLOCK XAM.
      LDX #$02        ; Byte count.
SETADR:
      LDA L-1,X       ; Copy hex data to
      STA STL-1,X     ; "store index".
      STA XAML-1,X    ; And to "XAM index'.
      DEX             ; Next of 2 bytes.
      BNE SETADR      ; Loop unless X = 0.
NXTPRNT:
      BNE PRDATA      ; NE means no address to print.
      LDA #$0D        ; CR.
      JSR ECHO        ; Output it.
      LDA XAMH        ; 'Examine index' high-order byte.
      JSR PRBYTE      ; Output it in hex format.
      LDA XAML        ; Low-order "examine index" byte.
      JSR PRBYTE      ; Output it in hex format.
      LDA #$3A        ; ":".
      JSR ECHO        ; Output it.
PRDATA:
      LDA #$20        ; Blank.
      JSR ECHO        ; Output it.
      LDA (XAML,X)    ; Get data byte at 'examine index".
      JSR PRBYTE      ; Output it in hex format.
XAMNEXT:
      STX MODE        ; 0-> MODE (XAM mode).
      LDA XAML
      CMP L           ; Compare 'examine index" to hex data.
      LDA XAMH
      SBC H
      BCS TONEXTITEM  ; Not less, so no more data to output.
      INC XAML
      BNE MOD8CHK     ; Increment 'examine index".
      INC XAMH
MOD8CHK:
      LDA XAML        ; Check low-order 'exainine index' byte
      AND #$07        ; For MOD 8=0
      BPL NXTPRNT     ; Always taken.
PRBYTE:
      PHA             ; Save A for LSD.
      LSR
      LSR
      LSR             ; MSD to LSD position.
      LSR
      JSR PRHEX       ; Output hex digit.
      PLA             ; Restore A.
PRHEX:
      AND #$0F        ; Mask LSD for hex print.
      ORA #$30        ; Add "0".
      CMP #$3A        ; Digit?
      BCC ECHO        ; Yes, output it.
      ADC #$06        ; Add offset for letter.

ECHO:
      PHA             ; Save A
      STA ACIA_DATA   ; Output character
      LDA #$FF        ; Initialise delay loop.
TXDELAY:
      DEC             ; Decrement A
      BNE TXDELAY     ; Until A gets to 0.
      PLA             ; Restore A.
      RTS             ; Return.

LCD_WAIT:
      PHA
      LDA #%11110000  ; LCD data is input
      STA DDRB
LCDBUSY:
      LDA #RW
      STA PORTB
      LDA #(RW | E)
      STA PORTB
      LDA PORTB       ; Read high nibble
      PHA             ; and put on stack since it has the busy flag
      LDA #RW
      STA PORTB
      LDA #(RW | E)
      STA PORTB
      LDA PORTB       ; Read low nibble
      PLA             ; Get high nibble off stack
      AND #%00001000
      BNE LCDBUSY
      LDA #RW
      STA PORTB
      LDA #%11111111  ; LCD data is output
      STA DDRB
      PLA
      RTS

LCD_INIT:
      PHA
      LDA #%00000010  ; Set 4-bit mode
      STA PORTB
      ORA #E
      STA PORTB
      AND #%00001111
      STA PORTB
      PLA
      RTS

LCD_INSTRUCTION:
      JSR LCD_WAIT
      PHA
      LSR
      LSR
      LSR
      LSR             ; Send high 4 bits
      STA PORTB
      ORA #E          ; Set E bit to send instruction
      STA PORTB
      EOR #E          ; Clear E bit
      STA PORTB
      PLA
      PHA
      AND #%00001111  ; Send low 4 bits
      STA PORTB
      ORA #E          ; Set E bit to send instruction
      STA PORTB
      EOR #E          ; Clear E bit
      STA PORTB
      PLA
      RTS

PRINT_CHAR:
      JSR LCD_WAIT
      PHA
      LSR
      LSR
      LSR
      LSR             ; Send high 4 bits
      ORA #RS         ; Set RS
      STA PORTB
      ORA #E          ; Set E bit to send instruction
      STA PORTB
      EOR #E          ; Clear E bit
      STA PORTB
      PLA
      PHA
      AND #%00001111  ; Send low 4 bits
      ORA #RS         ; Set RS
      STA PORTB
      ORA #E          ; Set E bit to send instruction
      STA PORTB
      EOR #E          ; Clear E bit
      STA PORTB
      PLA
      RTS

SEND_CHAR:
      STA ACIA_DATA
      PHA
TX_WAIT:
      LDA ACIA_STATUS
      AND #$10        ; check tx buffer status flag
      BEQ TX_WAIT     ; loop if tx buffer not empty
      JSR TX_DELAY
      PLA
      RTS

TX_DELAY:
      PHX
      LDX #100
TX_DELAY_1:
      DEX
      BNE TX_DELAY_1
      PLX
      RTS

LCD_MSG:  .asciiz "BE WozMon $C005  "
CONS_MSG:  .asciiz "--<<(( BE WozMon at $C005 ))>>--"

      .org $FFFA

      .word $0F00     ; NMI vector
      .word RESET     ; RESET vector
      .word $0000     ; IRQ vector
