{-------------------------------------------------------------------------

                                     QBM  

         Unit to handle screen and disk portions of the macro player

                  Written for Borland Turbo Pascal V 6.0

                     Copyright 1991, by John H. Eckert
                           All Rights Reserved


                                                   ... a component of the
                                                   QuickBasic Programmer
                                                   Desk Accessories ...
-------------------------------------------------------------------------}
{ History:           
01/11/91   0.30   Unit created out of the standalone QBMacro utility.
02/01/91   0.50   Macro key view split out for increased granularity
}
{-------------------------------------------------------------------------}
{$F+}                               { Far calls needed for overlays }
{$O+}                               { Unit may be overlaid          }
UNIT QBM;

{ This unit contains the program code for display of the main macro menu, the
macro-select and command-select sub menus, and the display screens, except
for help, which flow from them. It is called by the main PDA module when the
Macro choice is selected. Code for loading a macro key file is in a separate
unit (shared by PDAInit for use during startup).  Code for recording and
playback of macro's is in the main module since it is hardware interrupt-
driven and must remain resident at all times. }

{==========================================================================}
{================================= Interface ==============================}
{==========================================================================}
INTERFACE


USES Crt, Dos, pdaSubs, PDAEDLN, QBMHelp, QBMFile, QBMV;

PROCEDURE MacroMenu;

{==========================================================================}
{============================ Implementation ==============================}
{==========================================================================}

IMPLEMENTATION

PROCEDURE MacroMenu;

TYPE
String128= String[128];
String82 = String[82];
String80 = String[80];
String40 = String[40];
String13 = String[13];
String11 = String[11];
String4  = String[4];
MacroFile_t = File of String82;


VAR
CurrentMacroLine, TopMacroLine: Byte;
LastMacroLine, TextChr        : Byte;
OldMacro                      : Byte;
Key                           : Char;       { Last input key code }
TmpStr                        : PathStr;
ModeName                      : String11;
Title                         : String13;
Prompt                        : String70;

{----------------------------------------------------------------------------}
{ Make all procedures/functions local to give them access to local variables }
{----------------------------------------------------------------------------}

{ =========================  Display Macro Key List ========================
}
PROCEDURE KeyPickList(var Choice:Byte; VAR ModeName:String11);
Var
i,j,Kol  : Byte;

Begin
Repeat
   ClrScr;
   Box(1, 2, 28, 14);
   GotoXY((64-Length(ModeName)) Div 2,1); Write(ModeName);
   GotoXY( 3, 2);   Write('  Keystrokes Recorded ');
   Box(39, 2, 19, 14);
   GotoXY(45, 2);  Writeln(' Free ');
   { Do the used list }
   J := 3; Kol := 2;
   For i := 1 to MacroLines Do
      Begin
      IF Ord(MacroLine[i,0]) > 2 then
         Begin
         GotoXY(Kol,J);Write(MacroLine[i,1],(Ord(MacroLine[i,0])-2)DIV 2:3);
         IF MacroLine[i,2] <> #127 then
            Write('->',MacroLine[i,2]);
         Inc(j);
         If j > 14 Then
            Begin
            j:= 3;
            Inc(Kol,9);
            End;
         End;
       End;
   { Now the free list }
   J := 3; Kol := 42;
   For i := 1 to MacroLines Do
      Begin
      IF Ord(MacroLine[i,0]) < 3 then
         Begin
         GotoXY(Kol,J);Write(MacroLine[i,1]);
         If MacroLine[i, 2] <> #127 Then
            Write(#26,MacroLine[i,2]);
         Inc(j);
         If j > 14 Then
            Begin
            j:= 3;
            Inc(Kol,5);
            End;
         End;
       End;

   GotoXY(12,17);
   Write('<Press A-Z, 0-9 for macro>   <Esc = cancel>');
   GotoXY(46,17);
   Ch := GetUpKey;
   If Ch = #13 Then Ch := #27;
Until (Ch IN MacroKeys) or (Ch = #27);
Choice := Ord(Ch);
End;




{====== THE MAIN PART OF UNIT ======}
Begin
Title    := ' Macro Keys ';
Prompt   := ' Press the key corresponding to desired selection ';
BorderTitlePrompt(Title, Prompt);

ClrScr;
ULRow := 5;
ULCol := 9;
Window( ULCol, ULRow, LLCol, LLRow );

cursor_on;

Repeat
   GotoXY(10,2);Writeln('<L>oad macro keystrokes from file');
   GotoXY(10,4);Writeln('<S>ave macro keystrokes to file');
   GotoXY(10,6);Writeln('<V>iew macro keystrokes loaded in memory');
   GotoXY(10,8);Writeln('<R>ecord macro keystrokes');
   GotoXY(10,10);Writeln('<P>layback recorded macro keystrokes');
   GotoXY(10,12);Writeln('<J>oin, remove join, of one key to another. ');
   GotoXY(16,16);Writeln('< Esc=Quit >      < Help >');
   GotoXY(37,16);

   Repeat
      Ch := GetUpKey;
   Until (Ch IN ['L','S','V','R','P'(*,'C'*),'H','J', #27 ,#13]);
   IF Ch = #13 then Ch := 'H';
   Case Ch of
   'L' : Begin
         ClrScr;
         GotoXY(28,2);Write('LOAD FILE');
         Ch := 'Y';
         IF MacrosChanged Then
            Begin
            GotoXY(5,4);Write('Keystrokes recorded in memory have changed.');
            GotoXY(5,6);Write('Lose the changes (Y/N)? ');
            Repeat
             Ch := GetUpKey;
            Until (Ch IN ['Y','N',#27]);
            End; {MacrosChanged}
         IF Ch = 'Y' then
            Begin
            GotoXY(5,8);Write('Enter the name of file: ');
            TmpStr := '';
            GetEditLine(TmpStr, 40, Key);
            (*Readln(TmpStr); *)
            If Length(TmpStr) > 0 then
               Begin
               FSplit(TmpStr, MacDir, MacName, MacExt);
               If MacExt = '' then MacExt := '.KQF';
               TmpStr := MacDir + MacName + MacExt;
               LoadKeyFile(TmpStr);
               End; {Length(MacName) > 0}
            End;  {Ch = 'Y'}
         ClrScr;
         End;  {Load}
   'S' : Begin
         ClrScr;
         GotoXY(28,2);Write('SAVE FILE');
         GotoXY(5,10);
         SaveMacros;
         ClrScr;
         End;
   'J' : Begin
         ChKey := 0; ModeName := 'JOIN FROM';
         KeyPickList(ChKey, ModeName);
         ClrScr;
         If ChKey <> 27 then
            Begin
            MacroKey := Chr(ChKey);       { Valid macro key          }
            Macro := MacroNum(MacroKey);
            Ch := 'C';
            If MacroLine[Macro,2] <> #127 then
               Begin
               ClrScr;
               GotoXY(17,8); Write('Key ',MacroKey,' already joined to ',MacroLine[Macro,2]);
               GotoXY(11,16);Write('<Change Join>  <Remove Join>  <Esc = Cancel>');
               GotoXY(47,16);
               Repeat
               Ch := GetUpKey;
               Until Ch IN ['C', 'R', #27];
               IF Ch = 'R' Then
                  Begin
                  MacroLine[Macro, 2] := #127;
                  MacrosChanged := True;
                  ClrScr;
                  End;
               End;
            If Ch = 'C' Then
               Begin
               ChKey := 0; ModeName := 'JOIN ' + MacroKey + ' TO';
               KeyPickList(ChKey, ModeName);
               ClrScr;
               If ChKey <> 27 then
                  Begin
                  OldMacro := Macro;
                  MacroKey := Chr(ChKey);       { Valid macro key          }
                  Macro := MacroNum(MacroKey);
                  MacrosChanged := True;
                  IF Macro > 0 Then MacroLine[OldMacro, 2] := MacroKey;
                  End;
               End;
            End;
         End;
   'V' : Begin
         ChKey := 0; ModeName := 'VIEW';
         KeyPickList(ChKey, ModeName);
         If ChKey <> 27 then ViewMacroKey(ChKey);
         ClrScr;
         Ch := #0;
         End;
   'P' : Begin
         PutChr(Ord('m'),MacroStat);
         ChKey := 0; ModeName := 'PLAY';
         KeyPickList(ChKey, ModeName);
         ClrScr;
         If ChKey <> 27 then
            Begin
            MacroKey := Chr(ChKey);       { Valid macro key          }
            Macro := MacroNum(MacroKey);
            PlayingMacro := True;         { Flag invokes macro player}
            NextKey := 2;                 { Init Keystroke pointer   }
            Ch := #27;
            End
         Else
            Begin
            PutChr(Ord(' '),MacroStat);
            Ch := #0;
            End;
         End;
   'R' : Begin
         ChKey := 0; ModeName := 'RECORD';
         KeyPickList(ChKey, ModeName);
         If ChKey <> 27 Then
            Begin                        { Recording invoked, set it up }
            Ch := #27;                   { and set Ch to leave popup    }
            MacroKey := Chr(ChKey);      { Valid macro key              }
            Macro := MacroNum(MacroKey);
            PutChr(Ord('r'),MacroStat);
            { The following clears out  any existing "join" }
            {MacroLine[Macro] := MacroKey + #127;}{ clear target storage record  }
            { This method leaves any existing "join" in place. }
            MacroLine[Macro, 0] := #2;   { Reduce length to 2           }
            Recording := True;
            End
         Else
            Begin                         { Recording request canceled, }
            Ch := #0;                     { return to menu.             }
            ClrScr;
            End;
         End;
   'H' : QBMHelpScreen;
   End;
Until (Ch = #27);
Ch := #0;                              { Stay in main menu on return    }

{SetMacOptionsDone: }
If Recording Then                      { put recording sym. on QB's scrn}
   Begin
   PutChr(Ord('r'),MacroStat);
   PutChr(Ord(MacroKey),MacroStat+2);
   Ch := #27;                           { Exit main menu on return         }
   End;
IF PlayingMacro Then                   { put playing sym. on QB's scrn  }
   Begin
   PutChr(Ord('p'),MacroStat);
   PutChr(Ord(MacroKey),MacroStat+2);
   Ch := #27;                           { Exit main menu on return         }
   End;

ULRow := 4;
ULCol := 4;
Window( ULCol, ULRow, LLCol, LLRow );
cursor_off;

End; {MacroMenu }

END. { QBM Unit }
