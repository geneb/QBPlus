{-------------------------------------------------------------------------

                                    PDACFGC  

            Unit to gather console configuration settings for QB Plus

                  Written for Borland Turbo Pascal V 6.0

                     Copyright 1991, by John H. Eckert
                           All Rights Reserved


                                                   ... a component of the
                                                   QuickBasic Programmer
                                                   Desk Accessories ...
-------------------------------------------------------------------------}
{ History:           
01/15/91   0.30   Unit created out of the standalone QBMacro utility and
                  other various programs.
02/10/91   0.70   Unit separated from PDACFGO to increase granularity.
04/08/91   0.85   Real time clock option added
05/15/91   0.93   Preserve original options on user ESC.
06/10/91   0.94   Name change support of PDA to QB Plus.
10/10/91   1.10   Unit created to support console configuration
}
{-------------------------------------------------------------------------}
{$F+}                               { Far calls needed for overlays }
{$O+}                               { Unit may be overlaid          }
UNIT PDACFGC;

{ This unit gathers input on keyboard and color display settings.  Called
 by PDACFG unit main menu when <C> or <K> options are chosen.
 }

{==========================================================================}
{================================= Interface ==============================}
{==========================================================================}
INTERFACE


USES Crt, Dos, pdaSubs;

PROCEDURE ColorSettings;
PROCEDURE KeyboardSettings;                

{==========================================================================}
{============================ Implementation ==============================}
{==========================================================================}

IMPLEMENTATION

{=========================== ColorSettings =================================
 Gathers user input on color configuration settings.
 }
PROCEDURE ColorSettings;

Var
Title                         : String13;
Prompt                        : String70;
ColorNames							: String128;
i                             : Byte;
AttrSave                      : Word;        { Starting colors             }
AttrSetting                   : Boolean;     { Fore = 0, Back = True       }
NewForeColor, NewBackColor    : Byte;        { Proposed colors             }

Begin
Title := ' Settings ';
Prompt   := ' Arrows=Select  Enter=Accept  Esc=Quit ';
BorderTitlePrompt(Title, Prompt);
ColorNames := 'Black  Blue   Green  Cyan   Red    MagentaBrown  White  ' +
				  'Gray   BrBlue BrGreenBrCyan BrRed  Pink   Yellow BrWhite';

ClrScr;
Box(42, 1, 30, 19);
AttrSave := TextAttr;                 { Save existing colors             }
NewForeColor := ForeColor;            { Initialize proposed colors       }
NewBackColor := BackColor;
AttrSetting := False;                 { Start with foreground color      }

{ Info on left }
GotoXY(15, 3);
Write('DISPLAY COLORS');
GotoXY(1,5);
Writeln('  Use the Right and Left Arrow keys to');
Writeln('  select between Foregound and Back-');
Writeln('  ground color lists.  Use Up and Down');
Writeln('  Arrow keys to move the Arrow Head on');
Writeln('  screen to the desired color.');

Repeat

   { Show sample text in proposed colors }
   GotoXY(15, 13);
   { Set colors -- direct to TextAttr to preserve hi-intensity background  }
   TextAttr := (TextAttr AND $0F) or (NewBackColor Shl 4); 
   TextAttr := (TextAttr and $F0) or NewForeColor;
   Write('  Sample Text  ');

   { Display color choices in current color }
   TextAttr := AttrSave;

   { Show the attribute }
   GotoXY(46, 2);
   Write('ForeGround ');
   GotoXY(59, 2);
   Write('BackGround');

   For i := 0 to 15 Do
      Begin
      GotoXY(46, i + 3);
         If i = NewForeColor then
            If not AttrSetting Then Write('->') else Write('Ш ')
         Else
            Write('  ');
     Write(Copy(ColorNames, i * 7 + 1, 7));
     GotoXY(59, I + 3);
     If i = NewBackColor Then
        If AttrSetting Then Write('->') else Write('Ш ')
     Else
        Write('  ');
     Write(Copy(ColorNames, i * 7 + 1, 7));
     End;

     Ch := ReadKey;
     If Ch = #0 Then Ch := ReadKey;
     Case Ch of
       UpArrow:
         Begin
         If not AttrSetting Then
           Begin
           NewForeColor := NewForeColor - 1;
           If NewForeColor > 15 then NewForeColor := 15;
           End
         Else
           Begin
           NewBackColor := NewBackColor - 1;
           If NewBackColor > 15 then NewBackColor := 15;
           End;
         End;
       DownArrow:
         Begin
         If not AttrSetting Then
            Begin
            NewForeColor := NewForeColor + 1;
            If NewForeColor > 15 then NewForeColor := 0;
            End
         Else
            Begin
            NewBackColor := NewBackColor + 1;
            If NewBackColor > 15 then NewBackColor := 0;
            End;
         End;
      LeftArrow, RightArrow: AttrSetting := not AttrSetting;
      End; {Case}

Until Ch in [#27, #13];

If Ch = #13 then
   Begin
   ForeColor := NewForeColor;
   TextAttr := (TextAttr and $F0) or ForeColor;
   BackColor := NewBackColor;
	TextAttr := (TextAttr AND $0F) or (BackColor Shl 4);
	End;

Ch := #0;                              { Stay with parent menu       }
end; { Color settings }



{=========================== KeyBoardSettings =================================
 Gathers user input on keyboard configuration settings.
 }
PROCEDURE KeyBoardSettings;

Var
Title                         : String13;
Prompt                        : String70;
i                             : Byte;
tKeyCPS, tKeyDelay            : Byte;        { Temporary rates            }
KeyBdOut                      : Byte;        { Value to output to keyboard}
SettingCPS                    : Boolean;     { Which, CPS/Delay is current}
tKeyBdAutoSet                 : Boolean;     { Temporary autoset option   }


Begin
Title    := ' Settings ';
Prompt   := ' Arrows=Select  A=Auto-set  Enter=Accept  Esc=Quit ';
BorderTitlePrompt(Title, Prompt);

ClrScr;
{ Info on left }
GotoXY(15, 4);
Write('KEYBOARD');
GotoXY(1,6);
Writeln('  Use the Up and Down Arrow keys');
Writeln('  to  select between Repeat Rate');
Writeln('  and  Delay.  Use the  Left and');
Writeln('  Right Arrow keys  to move  the');
Writeln('  Arrow Head  on screen  to  the');
Writeln('  desired value.   Press the "A"');
Writeln('  key  to toggle the  option  to');
Writeln('  have  these  settings emplaced');
Write('  by QB Plus at startup.');

GotoXY(3, 16);
Write('[ ] Automatic at startup');

GotoXY(49, 2);
Writeln('Repeat Rate');
GotoXY(44, 3);
Write('(Characters per second)');
GotoXY(40, 5);
Write('30  20  15  10 8  6 5  4  3    2');
GotoXY(40, 6);
Write(  'юдддадддадддаддаддададдаддадддды');
GotoXY(53, 11);
Write('Delay');
GotoXY(48 ,12);
Write('(Milliseconds)');
GotoXY(39, 14);
Write('250       500       750      1000');
GotoXY(40, 15);
Write(  'юдддддддддадддддддддаддддддддды');

{ Initialize our temporary rates values }
tKeyCPS := KeyCPS;
tKeyDelay := KeyDelay * 10;
SettingCPS := True;
tKeyBdAutoSet := KeyBdAutoSet;

Repeat
   GotoXY(4,16);
   If tKeyBdAutoSet Then Write('X') Else Write(' ');

   GotoXY(40, 7);
   For i := 0 to 31 Do
      If i = tKeyCPS then
         If SettingCPS then Write(#24) else Write(#251)
      Else Write(' ');

   GotoXY(40, 16);
   i := 0;
   While i < 31 Do
      Begin
      If i = tKeyDelay then
         If Not SettingCPS then Write(#24) Else Write(#251)
      Else Write(' ');
      Inc(i, 10);
      GotoXY(WhereX+9, WhereY);
      End;

   Ch := ReadKey; If Ch = #0 then Ch := ReadKey;
   Case Ch of
      UpArrow, DownArrow : SettingCPS := Not SettingCPS;
      LeftArrow:
         If SettingCPS Then
            Begin
            tKeyCPS := tKeyCPS - 1;
            If tKeyCPS > 31 then tKeyCPS := 31;
            End
         Else
            Begin
            tKeyDelay := tKeyDelay - 10;
            If tKeyDelay > 30 then tKeyDelay := 30;
            End;
      RightArrow:
         If SettingCPS Then
            Begin
            tKeyCPS := tKeyCPS + 1;
            If tKeyCPS > 31 then tKeyCPS := 0;
            End
         Else
            Begin
            tKeyDelay := tKeyDelay + 10;
            If tKeyDelay > 30 then tKeyDelay := 0;
            End;
      'A','a' : tKeyBdAutoSet := not tKeyBdAutoSet;
      End; { Case}
Until Ch in [#13, #27];

If Ch = #13 Then
   Begin
   (* Not all BIOS' support int 16/03h, so we'll write directly to kybd.
	asm
	 mov ax, $0305
	 mov bh, KeyDelay
	 mov bl, KeyCPS
	 int $16
	end {asm} *)
   Port[$60] := $F3;              { Send cmd in plenty of time for         }
   KeyCPS := tKeyCPS;             { hardware recovery before our           }
   KeyDelay := tKeyDelay DIV 10;  { value is sent.                         }
   KeyBdOut := 0;
   KeyBdOut := KeyDelay Shl 5;
   KeyBdOut := KeyBdOut or KeyCPS;
   Delay(10);                     { ... some more delay for insrnce        }
   Port[$60] := KeyBdOut;
   KeyBdRateChanged := True;      { Flag signals exit code to restore      }
   KeyBdAutoSet := tKeyBdAutoSet;
   End;

Ch := #0;                              { Stay with parent menu             }
end; { Keyboard settings }

END. { PDACFGC Unit }
