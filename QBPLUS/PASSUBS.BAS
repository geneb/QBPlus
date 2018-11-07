'---- QuickBasic Memory Viewer
'---- Copyright 1991 John Eckert

'--- PASSUUBS.BAS
'--- Contains SUBS and FUNCTIONS that emulate syntax of Pascal
DECLARE SUB ClrScr ()
DECLARE SUB ClrEOL ()
DECLARE SUB Dec (Number AS ANY, Amount AS ANY)
DECLARE FUNCTION GetCString$ (Segment&, offset&)
DECLARE FUNCTION GetString$ (Segment&, offset&)
DECLARE SUB GotoXY (Column%, Row%)
DECLARE SUB Inc (Number AS ANY, Amount AS ANY)
DECLARE FUNCTION MemW& (Segment AS ANY, offset AS ANY)
DECLARE FUNCTION WhereX% ()
DECLARE FUNCTION WhereY% ()
DECLARE FUNCTION DosVersion% ()
DECLARE FUNCTION DosVersion% ()
DECLARE SUB writes (Text$)
DECLARE SUB Writeln (Text$)

'We need the interrupt declaration and structure for Dos/BIOS calls
' $INCLUDE: 'QB.BI'

DEFINT A-Z
SUB ClrEOL
'CLears the reminder of screen line w/out moving cursor

SaveH = POS(0)
PRINT SPC(80 - SaveH);
LOCATE , SaveH

END SUB

DEFSNG A-Z
SUB ClrScr
'--- clears the current window
CLS

END SUB

DEFLNG A-Z
SUB Dec (Number, Amount)

Number = Number - Amount


END SUB

DEFSNG A-Z
FUNCTION DosVersion%

DIM Regs AS RegType

'{ Retrieve dos version number from Dos }
'Major in low byte, minor in high byte -- BCD format
'Retrieve: Major = DosVersion% MOD 256
'          Minor = DosVersion% \ 256
Regs.ax = &H3000
CALL Interrupt(&H21, Regs, Regs)
DosVersion% = Regs.ax

END FUNCTION

DEFLNG A-Z
FUNCTION GetCString$ (Segment, offset) STATIC
'
'  Copies a null-terminated series of characters at memory location
'  segment:offset into a Basic string.
'
DEF SEG = Segment
i% = 0
DO
Char$ = Char$ + CHR$(PEEK(offset + i%))
'PRINT CHR$(Char%);
i% = i% + 1
LOOP UNTIL PEEK(offset + i%) = 0
GetCString$ = Char$


END FUNCTION

FUNCTION GetString$ (Segment, offset) STATIC
'
' Returns a Basic string from memory location Segment:Offset where
' the first byte at that location is the length of the string that
' follows.
'

' Get memory values into valid range
Segment = Segment MOD 65536
offset = offset MOD 65536

DEF SEG = Segment                           'Point to segment
i% = 1
IF PEEK(offset) < 256 THEN
   Length% = PEEK(offset)                   'Pascal type string with leading
ELSE                                        'length byte
   Length% = 255
END IF

' Make room for string
Char$ = SPACE$(Length%)

'Don't go past end of segment
IF offset + Length% > 65535 THEN
   Length% = 65536 - offset
END IF

'Insert bytes into string until a "null" or length is reached
DO WHILE (PEEK(offset + i%) > 0) AND (i% <= Length%)
MID$(Char$, i%, 1) = CHR$(PEEK(offset + i%))
i% = i% + 1
LOOP

GetString$ = Char$


END FUNCTION

DEFSNG A-Z
SUB GotoXY (Column%, Row%)
LOCATE Row%, Column%
END SUB

DEFLNG A-Z
SUB Inc (Number, Amount)
'
Number = Number + Amount
'
END SUB

'                                MemW
'
'  Emulates the Pascal function returning the word at memory location
'  passed in Segment:Offset. We return the value as a long to provide
'  positive values in the range 32767-65536 like the Pascal "Word" type.
'
FUNCTION MemW (Segment, offset)
   DEF SEG = Segment
   Temp& = PEEK(offset + 1)
   MemW = PEEK(offset) + Temp& * 256
   'MemW = CINT(Temp&)
END FUNCTION

DEFSNG A-Z
FUNCTION WhereX%
' Returns the column of the current cursor position

WhereX% = POS(0)

END FUNCTION

FUNCTION WhereY%
' Returns the row of the current cursor position

WhereY% = CSRLIN

END FUNCTION

SUB Writeln (Text$)
' Outputs the string argument to the screen followed by CR/LF
PRINT Text$

END SUB

SUB writes (Text$)
' Outputs the string argument to the screen. We use the word Writes with an
' "s" to distinguish this SUB from the basic reserved word "Write"

PRINT Text$;


END SUB

