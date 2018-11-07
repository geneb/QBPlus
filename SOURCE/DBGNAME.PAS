{-------------------------------------------------------------------------

                                    dbgName

            Unit to get external debugger file name, switches and
                  the name of the executable to be debugged

                  Written for Borland Turbo Pascal V 6.0
                  -- Contains Version-specific code --

                     Copyright 1991, by John H. Eckert
                           All Rights Reserved


                                                   ... a component of the
                                                   QuickBasic Programmer
                                                   Desk Accessories ...
-------------------------------------------------------------------------}
{ History:           
01/11/91   0.20   Created as a special purpose name/command argument version
                  of the unit that gets anything to be swapped for QB. This
                  one remembers and offers specific choices unique to the
                  external debugger, taking advantage of our inside knowledge
                  on what's in QB, and/or what has just been compiled.
01/15/91   0.30   Modified to be called by the configuration unit. This gives
                  a one-key entry from the main popup menu to the debugger
                  once the debugger name, parms and debug file are specified.
}
{-------------------------------------------------------------------------}
{$F+}
{$O+}                               { Unit may be overlaid          }
UNIT dbgName;
{==========================================================================}
{================================= Interface ==============================}
{==========================================================================}

INTERFACE


USES Dos, Crt, pdaSubs, SwapQB, PDAEDLN;


PROCEDURE GetDebuggerInfo;


{==========================================================================}
{============================ Implementation ==============================}
{==========================================================================}
IMPLEMENTATION


PROCEDURE GetDebuggerInfo;
LABEL GetdbgCanceled;

Var
SearchedName                  : PathStr;
Key                           : Char;
InBox, InBoxes, OKBox         : Byte;
OK                            : String13;
Done                          : Boolean;

Begin

{---- Draw a nice screen, with some prompt info }
dbgcanceled := False;                             { flag to continue or not }
OK := '< OK >';
ClrScr;
GotoXY(29,1);Write(' Debugger Setup ');


{ Draw the boxes  for instructions and arguments }
Box(3, 2, LLCol - ULCol - 3, 7);


{ Fill upper box with information }
Window(ULCol + 6, ULRow + 2, LLCol - 5, ULRow + 6);
Writeln('Enter the file specification for your debugger, any');
Writeln('command line arguments it needs, and the file specification');
Writeln('of the program to be debugged.');
Writeln;
Write('Pressing Esc on any field cancels.');


{ Display the field labels and contents for each entry box }
WindMax := init_max; WindMin := init_min;
GotoXY(ULCol + 2, ULRow + 9);
Write('Debugger file name:  ', Debugger);
Box(ULCol + 22, ULRow + 8, LLCol - ULCol - 23, 3);


GotoXY(ULCol + 2, ULRow + 12);
Write('Debugger  commands:  ', DbgOpts);
Box(ULCol + 22, ULRow + 11, LLCol - ULCol - 23, 3);


GotoXY(ULCol + 2, ULRow + 15);
IF (Length(MainModName) > 0) and (DebugFile = '') Then
   DebugFile := MainModDir + MainModName + '.EXE';
Write('Program to debug:    ', DebugFile);
Box(ULCol + 22, ULRow + 14, LLCol - ULCol - 23, 3);


{ Show the OK prompt }
Window(ULCol + 33, ULRow + 18, ULCol + 39, ULRow + 18);
Write(OK);


Cursor_on;                                     { show cursor till done }
InBoxes := 4; InBox := 1; OKBox := 4; Done := False;
Repeat
Case InBox of

   1: Begin { Get the debugger name }
      Window(ULCol + 23, ULRow + 9, LLCol - 3, ULRow + 9);
      GetEditLine(Debugger, LLCol - ULCol - 23, Key);
      If Key = #27 then
         Begin
         dbgCanceled := True;
         Goto GetdbgCanceled;
         End;
      { Tack .EXE on debugger name,if not there already }
      FOR i := 1 TO Length( Debugger ) DO            { Make all uppercase  }
            Debugger[ I ] := UpCase( Debugger[I] );
      If Length(Debugger) > 0 then
         Begin
         i := pos('.EXE', Debugger);                  { to look for .EXE or }
         If i = 0 Then                                { .COM, so we can tack}
            Begin                                     { on .EXE if needed.  }
            i := pos('.COM', Debugger);
            If i = 0 then Debugger := Debugger + '.EXE';
            End;
         End;
      End; { Debugger name }


   2: Begin{ get any parms }
      Window(ULCol + 23, ULRow + 12, LLCol - 3, ULRow + 12);
      GetEditLine(DbgOpts, LLCol - ULCol - 23, Key);
      If Key = #27 then
         Begin
         dbgCanceled := True;
         Goto GetdbgCanceled;
         End;
      End; { parms }

   3: Begin { get debug program name }
      Window(ULCol + 23, ULRow + 15, LLCol - 3, ULRow + 15);
      GetEditLine(DebugFile, LLCol - ULCol - 23, Key);
      If Key = #27 then
         Begin
         dbgCanceled := True;
         Goto GetdbgCanceled;
         End;
      { Tack .EXE on debug file name also,if not there already }
      FOR i := 1 TO Length( DebugFile ) DO             { Make all uppercase}
         DebugFile[ I ] := UpCase( DebugFile[I] );
      If Length(DebugFile) > 0 then
         Begin
         i := pos('.EXE', DebugFile);                  { to look for .EXE or }
         If i = 0 Then                                 { .COM, so we can tack}
            Begin                                      { on .EXE if needed.  }
            i := pos('.COM', DebugFile);
            If i = 0 then DebugFile := DebugFile + '.EXE';
            End;
         End;
      End; { Debug file }

   4: Begin { OK box }
      Window(ULCol + 33, ULRow + 18, ULCol + 39, ULRow + 18);
      GetEditLine(OK, 1, Key);
      If Key = #13 Then Done := True;
      End;
End; { Case }


{ Previous box if shift tab, wrapping }
If Key = Sh_Tab then
   Begin
   Dec(InBox);
   If InBox < 1 Then
      InBox := InBoxes;
   End;


{ Next box if tab pressed, wrapping }
If (Key = Tab) or (Key = #13) then
   Begin
   Inc(InBox);
   If InBox > InBoxes Then
      InBox := 1;
   End;

Until Done or (Key = #27);


{ Clear upper box for status/error messages }
Window(ULCol + 6, ULRow + 2, LLCol - 5, ULRow + 6 );
ClrScr;


If Debugger = '' then
   Begin
   dbgCanceled := True;
   Goto GetdbgCanceled;
   End;



SearchedName := FSearch(Debugger,GetEnv('PATH'));
if SearchedName = '' then
    Begin
    Writeln(Debugger,' not found.  Operation canceled.');
    Delay(3000);
    dbgCanceled := True;
    Goto GetdbgCanceled;
    End
else
    Begin
    Debugger := FExpand(SearchedName);
    { Show full path }
    WriteLn('Program found as ', Debugger);
    End;


GetdbgCanceled:
End; { GetDebugger }

End.
