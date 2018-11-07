{-------------------------------------------------------------------------

                                     QBC  

            Unit to edit compile and link options in an edit buffer
                     and save to an external disk file

                  Written for Borland Turbo Pascal V 6.0

                     Copyright 1991, by John H. Eckert
                           All Rights Reserved


                                                   ... a component of the
                                                   QuickBasic Programmer
                                                   Desk Accessories ...
-------------------------------------------------------------------------}
{ History:           
01/03/91   0.10   Originally a part of the stand alone utility, QBBC.EXE
                  Version 1.6, the code here has been restructured to tie
                  in as an overlay unit in the toolset. It depends upon the
                  Child2 unit to call its compile/link code located in an
                  external companion program.
01/11/91   0.20   Help screen and Get Options moved to separate units.
}
{-------------------------------------------------------------------------}
{$F+}                               { Far calls needed for overlays }
{$O+}                               { Unit may be overlaid          }
UNIT QBC;

{ This unit contains a line-based editor for creating a set of compiler and
linker options that can then be accessed by an external companion program to
build an executable file. The advantage here is that the programmer can use
options that are not provided within the QB environment, yet does not have
to exit to the command line to invoke them. Further, incremental compile and
link features are available, and with swapping out of QB, the full memory
area is available for BC and LINK to use.  This version of QB Plus is
able to build a starter set of compile/link options from the source files
loaded in QB. This version will also tailor the starter set to the Crescent
Software PDQ library, if it detects PDQ as the resident Quicklibrary.
}

{==========================================================================}
{================================= Interface ==============================}
{==========================================================================}
INTERFACE


USES Crt, Dos, pdaSubs, QBCHelp;


PROCEDURE EditOptions;                 { Only one public procedure         }


{==========================================================================}
{============================ Implementation ==============================}
{==========================================================================}

IMPLEMENTATION


{=============================== EditOptions ========================== }
{ This is the main Build.EXE routine. It is called by the kernel resident
within QB/QBX when they request the Build menu option. We'll present
a list of compile/link options for editing. The options may already be in
memory from a previous editing session, may be loaded from disk, or may be
constructed from information extracted from QB, from a .MAK file on disk,
or a simple set created from defaults and a user-supplied filename. Getting
data into the TextLine buffer is done by QBCGet called by the PDA kernel
prior to calling us here.

The current options may be saved any time during editing, and are saved
automatically when the routine is exited with the "Done" and "qbcChanged"
flags both set to true (Editing + F2 or F10 key pressed). The QBP kernel will
need to sound warning if "qbcChanged" and not saved when this routine is left
with ESC, and the data is about to be overwritten by other modules that
share the TextLine buffer.

If Compile flag is set on exit, the QBP kernel calls the Child2 unit with
the external Build program name and, as the command line argument to it,
the name of the .MQK file where the current compile/link options have been
stored. }

{ External Access:
   Variables:                          Calls:
               Printables                    ShiftKey
               MainModPath                   Assign
               MainModDir                    Rewrite
               MainModName                   IOResult
               MainModExt                    KeyPressed
               OptFile                       ReadKey
               TextLine[] W                  GotoXY
               LLCol                         ClrScr
               ULCol                         Cursor_on
               LLRow                         Cursor_off
               ULRow                         BorderTitlePrompt
               Compile    W                  ClearPrompt
               qbcChanged W                  FSplit
                                             Write(ln)
}

PROCEDURE EditOptions;
LABEL SetOptionsDone;

VAR
I                                      : Byte;
HCurSaveX,HCurSaveY                    : Byte;
Title                                  : String13;
Prompt                                 : String70;
ScrnCols, MaxTextLen, ScrnLines        : Byte;
CurrentTextLine, TopTextLine           : Byte;
LastTextLine, TextChr                  : Byte;
CurrentScrnLine                        : Byte;        { Various Editor     }
InsertLine                             : Boolean;
CutBuffer                              : String70;
Done, Cancelled                        : Boolean;

{ Local procedures share local, stack-based variables above, thus avoiding
 need to use up resident DSeg RAM. }

{================================ RefreshText ==========================
This called by the editor to re-display a page of text after changes and
to do the vertical scrolling. The current cursor position is preserved.} 
PROCEDURE RefreshText;
VAR
   CurSaveX, CurSaveY, I ,Row : Byte;

BEGIN
   { Save cursor location }
   CurSaveX := WhereX;
   CurSaveY := WhereY;
   Row := 0;
   ClrScr;

   { Position current text lines to the screen lines }
   IF ScrnLines < TextLines - TopTextLine + 1 THEN
      LastTextLine := TopTextLine + ScrnLines - 1
   ELSE
      LastTextLine := TextLines;

   { Display the text to be edited }
   FOR I := TopTextLine to LastTextLine DO
      BEGIN
      Row := Row + 1;
      GotoXY( 1, Row );
      Write(TextLine[ I ]);
      END;

   { Restore cursor position }
   GotoXY( CurSaveX, CurSaveY );
END;  { Refresh Text }





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

   GotoXY( 1, WhereY );
   ClrEOL;
   Write( TextLine[ CurrentTextLine ]);

   { Restore cursor position }
   GotoXY( CurSaveX, CurSaveY );
END;





{================================ FindLast ========================== }
{The file format is very unstructured, so we have to examine each line
to determine where the end is.  This function is called by the editor to
see if there is room to insert a line when asked to do so by the user. }
FUNCTION FindLast : Byte;
VAR
   I     : Byte;
   Found : Boolean;

BEGIN
   I := TextLines;                         { Start from end of file and    }
   Found := False;                         { work back to find the first   }
                                           { non-empty line.               }
   REPEAT
      IF (TextLine[ I ] <> '') OR (I = 0) THEN
         BEGIN
         FindLast := I;
         Found := True;
         END;
      I := I - 1;
   UNTIL Found;
END;  { FindLast }





{====  The Main Editing Routine Starts Here ==== }
Begin
{ Initialize variables }
ScrnLines         := LLRow - ULRow + 1;
ScrnCols          := LLCol - ULCol + 1;
MaxTextLen        := SizeOf(TextLine[1]);
If ScrnCols < MaxTextLen Then            { Constrain text to window wdth }
   MaxTextLen := ScrnCols;
TopTextLine       := 1;
TextChr           := 1;
CurrentScrnLine   := 1;
CurrentTextLine   := 1;
CutBuffer         := '';
{ShowModules; }
InsertLine        := False;                      { init control flags }
cancelled         := False;
done              := False;
{qbcChanged          := False;  }
Title := ' Build .EXE ';
Prompt := ' F1=Help      F2=Exit/Save      Esc=Exit/Cancel      F10=Build EXE ';
Compile := False;                         { Assume no desire to compile at }
                                          { this point.                    }

{ Initialize the screen window }
BorderTitlePrompt(Title, Prompt);
ClrScr;
Cursor_on;

{ Initialize to start of text and display it }
RefreshText;

REPEAT
  ch := ReadKey;
  CASE ch OF
      #0,#224 : BEGIN { extended key codes }
           ch := ReadKey;
           CASE ch OF
               #59 : { Display BC and LINK options }
                     BEGIN
                     HCurSaveX := WhereX; HCurSaveY := WhereY;
                     ClearPrompt;
                     HelpScreen;
                     BorderTitlePrompt(Title, Prompt);
                     GotoXY( HCurSaveX, HCurSaveY );
                     RefreshText;
                     END;
               #82 : { Insert - InsLine;}
                     InsertLine := True;
               #71 : { home }
                     BEGIN
                     TextChr := 1;
                     GotoXY( TextChr, WhereY );
                     END;
               #72 : { up arrow }
                     IF CurrentTextLine > 1 THEN
                        BEGIN
                        IF WhereY = 1 THEN
                           IF TopTextLine > 1 THEN
                              BEGIN                { Scroll down }
                              TopTextLine := TopTextLine - 1;
                              RefreshText;
                              END;
                        CurrentTextLine := CurrentTextLine -1;
                        GotoXY( WhereX, WhereY - 1 );
                        END;
               #75 : { left arrow }
                     IF TextChr > 1 THEN
                        BEGIN
                        TextChr := TextChr - 1;
                        GotoXY( TextChr, WhereY );
                        END;
               #77 : { right arrow }
                     IF TextChr < ScrnCols THEN
                        BEGIN
                        TextChr := TextChr + 1;
                        GotoXY( TextChr, WhereY );
                        END;
               #79 : { end }
                     BEGIN
                     TextChr := Length(TextLine[CurrentTextLine]) + 1;
                     GotoXY( TextChr, WhereY);
                     END;
               #80 : { down arrow }
                     IF CurrentTextLine < TextLines THEN
                        BEGIN
                        IF WhereY = ScrnLines THEN
                           BEGIN
                           TopTextLine := TopTextLine + 1;
                           RefreshText;
                           END;
                        CurrentTextLine := CurrentTextLine + 1;
                        GotoXY( WhereX, WhereY + 1 );
                        END;
               #83 : { DEL character/line }
                        BEGIN
                           IF TextLine[ CurrentTextLine ] = '' THEN  { zap line }
                              BEGIN
                              FOR I := CurrentTextLine TO TextLines - 1 DO   { copy down }
                                 TextLine[ I ] := TextLine[ I + 1 ];
                              TextLine[ TextLines ] := '';              { empty the top one }
                              RefreshText;
                              qbcChanged :=True;
                              END
                           ELSE                                  { zap chr }
                              IF TextChr <= Length( TextLine[ CurrentTextLine ]) THEN
                                 BEGIN
                                 Delete( TextLine[ CurrentTextLine ], TextChr, 1);
                                 RefreshLine;
                                 qbcChanged := True;
                                 END
                        END;
               #68 : { Quit to compile (F10) }
                        BEGIN
                        Compile  := True;
                        Done     := True;
                        END;
               #60 : { Quit/Save (F2) }
                        BEGIN
                        qbcChanged  := True;          { Force file save }
                        Done        := True;
                        END;
               END; { function key values }
           END; { extended key codes }
      #25 : { Control - Y } {DelLine;}
            BEGIN
            CutBuffer := TextLine[ CurrentTextLine ];
            FOR I := CurrentTextLine TO TextLines - 1 DO   { copy down }
               TextLine[ I ] := TextLine[ I + 1 ];
            TextLine[ TextLines ] := '';              { empty the top one }
            qbcChanged :=True;
            RefreshText;
            END;
      #8 : { BackDEL }
            IF (TextChr > 1) THEN
               BEGIN
               TextChr := TextChr - 1;
               IF (TextChr <= Length( TextLine[ CurrentTextLine ])) THEN
                  BEGIN
                     Delete( TextLine[ CurrentTextLine ], TextChr, 1);
                     RefreshLine;
                     qbcChanged :=True;
                  END;
               GotoXY( TextChr, WhereY );
               END;
      #13 : { enter }
            InsertLine := True;
      #27 : { ESC }
            cancelled := True;
      ELSE { Add/insert character }
            IF (Ch = '0') AND ShiftKey THEN
               InsertLine := True
            ELSE
            IF (Ch IN Printables) AND
                  (Length(TextLine[ CurrentTextLine ]) < MaxTextLen) THEN
               BEGIN
               IF (TextChr > Length(TextLine[ CurrentTextLine ])) THEN
                  TextChr := Length(TextLine[ CurrentTextLine ]) + 1;
               Insert( ch, TextLine[ CurrentTextline ], TextChr );
               TextChr := TextChr + 1;
               GotoXY( TextChr, WhereY );
               qbcChanged :=True;
               RefreshLine;
               END;
         END; { case }
   IF InsertLine THEN
      IF FindLast < TextLines THEN    { must be empty's }
         BEGIN                   { copy up to make room }
         FOR I := TextLines - 1 DOWNTO CurrentTextLine DO
            TextLine[ I + 1 ] := TextLine[ I ];
         IF ShiftKey THEN
            TextLine[ CurrentTextLine ] := CutBuffer
         ELSE
            TextLine[ CurrentTextLine ] := '';
         RefreshText;
         qbcChanged :=True;
         InsertLine := False;
         END;
UNTIL done OR cancelled;

If Done and qbcChanged then  { Save changes to file }
   Begin
   ClrScr;
   Writeln;
   FSplit(MainModPath, MainModDir, MainModName, MainModExt);
   Writeln('Saving to ', MainModDir + MainModName + '.MQK');
   Assign(OptFile, MainModDir + MainModName + '.MQK');
   {$I-} Rewrite(OptFile); {$I+}   {Suspend error trap during reset }
   IF IOResult = 0 then
      BEGIN
      For I := 1 to TextLines Do
         begin
         Writeln(OptFile, TextLine[I]);
         End;
      qbcChanged := False;
      Close(OptFile)
      END  { writing .MQK }
   Else
      Begin
      Writeln;
      Writeln('Error ',IOResult,' attempting to save data. ');
      Write('Press a key to return to QuickBasic...');
      Repeat until KeyPressed; Ch := ReadKey;
      IF Ch = #0 then Ch :=ReadKey;
      End;
   End;

If Compile Then
   Begin
   ClearPrompt;
   ClrScr;
   Writeln('Building ',MainModPath,'.');
   End;

SetOptionsDone:
Cursor_off;
Ch := #0;

End; { EditOptions }

End.
