{-------------------------------------------------------------------------
                                 GETEDLIN

                An "Include" routine for gathering input

                  Written for Borland Turbo Pascal V 6.0

                     Copyright 1991, by John H. Eckert
                           All Rights Reserved


                                                   ... a component of the
                                                   QB Plus Desk Accessories
-------------------------------------------------------------------------}
{ INCLUDE ROUTINE -- GETEDLN.PAS

 Procedure for gathering an input line, with insert/delete editing within
 a fixed-length field constrained to a single screen line.  The input field
 is limited to the lesser of the length parameter or the right screen margin.
 Input is terminated with either:
         Esc            - restoring the original input line, if any
         Enter          - passing whatever has been entered into TextLine
         Tab, Shift-tab - same as enter
 A code corresponding to the termination key is returned in the Key
 parameter, #27, #13, #9, or #15 respectively.
 }


PROCEDURE GetEditLine(var  TextLine    : String;
                           StrLength   : Byte;
                      var  Key         : Char);

TYPE
String80  = String[80];

CONST
Printables: SET OF Char = [' '..'}'];                 { Init sets }

VAR
Ch                                     : Char;
HCurSaveX,HCurSaveY                    : Byte;
ScrnCols, MaxTextLen, LM               : Byte;
TextChr                                : Byte;
CutBuffer                              : String80;
Done, Cancelled                        : Boolean;

{ Local procedures have access to all the local variables and arguments }

{===========================  ShiftKey ===============================}
{ ShiftKey returns True if either shift key is currently down}
FUNCTION ShiftKey:Boolean;
BEGIN
IF (Odd(Mem[$40:$17]) OR ( Mem[$40:$17] AND 2 <> 0)) THEN
   ShiftKey := True
   ELSE
      ShiftKey := False;
END;


{================================ RefreshLine ==========================
This called by the editor to re-display a line of text after changes.
The current cursor position is preserved. }
PROCEDURE RefreshLine;
VAR
   CurSaveX, CurSaveY   : Byte;

BEGIN
   { Save cursor location }
   CurSaveX := WhereX;
   CurSaveY := WhereY;

   GotoXY( LM, WhereY );
   ClrEOL;
   Write( TextLine);

   { Restore cursor position }
   GotoXY( CurSaveX, CurSaveY );
END;


{==== Main Routine ====== }
Begin


MaxTextLen        := StrLength;
cancelled         := False;
done              := False;
CutBuffer         := TextLine;
ScrnCols          := 79;
LM                := WhereX;

{ Only one screen line capacity }
If MaxTextLen > 79 then MaxTextLen := 79;


{ Display any default string passed to us for editing }
Write(TextLine);
TextChr           := WhereX - LM + 1;


REPEAT
  ch := ReadKey;
  CASE ch OF
      #0,#224 : BEGIN { extended key codes }
           ch := ReadKey;
           CASE ch OF
               #15 : { shift-tab }
                     Done := True;
               #71 : { home }
                     BEGIN
                     TextChr := 1;
                     GotoXY( TextChr + LM - 1, WhereY );
                     END;
               #75 : { left arrow }
                     IF TextChr > 1 THEN
                        BEGIN
                        TextChr := TextChr - 1;
                        GotoXY( TextChr + LM - 1, WhereY );
                        END;
               #77 : { right arrow }
                     IF (TextChr + LM - 1) < ScrnCols THEN
                        BEGIN
                        TextChr := TextChr + 1;
                        GotoXY( TextChr + LM - 1, WhereY );
                        END;
               #79 : { end }
                     BEGIN
                     TextChr := Length(TextLine) + 1;
                     GotoXY( TextChr + LM - 1, WhereY);
                     END;
               #5 : { Shift-Ins }
                     IF ShiftKey THEN
                        Begin
                        TextLine := CutBuffer;
                        RefreshLine;
                        End;
               #83 : { DEL character/line }
                     BEGIN
                     IF TextChr <= Length( TextLine) THEN
                        BEGIN
                        Delete( TextLine, TextChr, 1);
                        RefreshLine;
                        END;
                     END;
               END; { function key values }
           END; { extended key codes }
      #25 : { Control - Y } {DelLine;}
            BEGIN
            TextLine := '';               
            RefreshLine;
            END;
      #8 : { BackDEL }
            IF (TextChr > 1) THEN
               BEGIN
               TextChr := TextChr - 1;
               IF (TextChr <= Length( TextLine)) THEN
                  BEGIN
                     Delete( TextLine, TextChr, 1);
                     RefreshLine;
                  END;
               GotoXY( TextChr + LM - 1, WhereY );
               END;
      #13 : { enter }
            Done := True;
      #9  : { tab }
            Done := True;
      #27 : { ESC }
            Begin
            TextLine := CutBuffer;
            RefreshLine;
            cancelled := True;
            End{;}
      ELSE { Add/insert character }
            IF (Ch = '0') AND ShiftKey THEN
               Begin
               TextLine := CutBuffer;
               RefreshLine;
               End
            ELSE
            IF (Ch IN Printables) AND
                  (Length(TextLine) < MaxTextLen) AND
                  ((LM + Length(TextLine)) < ScrnCols) THEN
               BEGIN
               IF (TextChr > Length(TextLine)) THEN
                  TextChr := Length(TextLine) + 1;
               Insert( ch, TextLine, TextChr );
               TextChr := TextChr + 1;
               GotoXY( TextChr + LM - 1, WhereY );
               RefreshLine;
               END;
         END; { case }
UNTIL done OR cancelled;
Key := Ch;

End; { GetEditInput }
