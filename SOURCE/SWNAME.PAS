{-------------------------------------------------------------------------

                                    swName

                  Unit to get name of a secondary child
                        for running in place of QB

                  Written for Borland Turbo Pascal V 6.0

                     Copyright 1991, by John H. Eckert
                           All Rights Reserved


                                                   ... a component of the
                                                   QuickBasic Programmer
                                                   Desk Accessories ...
-------------------------------------------------------------------------}
{ History:           
12/31/90   1.55   Born as an added function to a pop up memory viewer tool.               user-specified program.
01/03/91   0.10   Restructured to take on a support role in a package of
                  pop up tools called as overlays.  Version number reflects
                  the parent, resident kernel program.  Code to obtain a
                  filename moved to parent/other sibling units.
01/11/91   0.20   This Get name module extracted from QBC and placed in
                  separate unit.
04/08/91   0.85   Fixed no Esc on OK button, added "exe assumed" in  top
                  instruction box.
}
{-------------------------------------------------------------------------}
{$F+}
{$O+}                               { Unit may be overlaid          }
UNIT swName;
{==========================================================================}
{================================= Interface ==============================}
{==========================================================================}

INTERFACE


USES Dos, Crt, pdaSubs, SwapQB, PDAEDLN;

PROCEDURE GetChild2;


{==========================================================================}
{============================ Implementation ==============================}
{==========================================================================}
IMPLEMENTATION



PROCEDURE GetChild2;


LABEL GetChild2Canceled;

Const
MaxNameList = 100;
ElementSize = 13;                      { File name length, used by FileSort}

Type
NameList    = array[1..MaxNameList] of String13;

Var
SearchedName                  : PathStr;        { FSearch return name   } 
InBox, InBoxes, OKBox         : Byte;           { Input field indexes   }
OK                            : String13;       { The OK button text    }
Done                          : Boolean;        { Screen exit flag      }
SaveResult                    : Byte;           { I/O save return code  }
TmpStr                        : PathStr;        { Temp filename space   }
FoundName                     : SearchRec;      { Results of FSearch    }
Key                           : Char;           { Last input key code   }
i                             : Word;           { Generic index/counter }
NameListCount                 : Word;           { Number in file list   }
ptrNameList                   : ^NameList;      { Address of file list  }
RecPtr                        : Byte;
Choice                        : Word;           { Index of pick choice  }
Title                         : String13;       { Our menu title        }
Prompt                        : String70;       { Our menu prompt       }


{ Incorporate the picker procedure to display and get program file name to
switch to. }
{$I PICKER.PAS}
{$I FILESORT.PAS}                      {... and the file sorter }

Begin

{---- Draw a nice screen, with some prompt info }
swcanceled := False;                             { flag to continue or not }
ClrScr;
OK := '< OK >';
{ClearPrompt; }
Title := ' Switch ';
Prompt := ' Tab/Shift-tab: Next/Previous box  Enter: Accept  Esc: Cancel ';
BorderTitlePrompt( Title, Prompt);

GotoXY(4,3);Write('Program');
GotoXY(4,4);Write('list');
Box(17, 2, LLCol - ULCol - 17, 8);
Box(3, 12, LLCol - ULCol - 3, 3);
GotoXY(4, 13); Write(LastC2Name);
Box(3, 16, LLCol - ULCol - 3, 3);
GotoXY(4, 17); Write(LastC2parms);
Window(ULCol + 19, ULRow + 2, LLCol - 5, ULRow + 7);
Writeln('You can use Tab or Shift-tab to position to');
Writeln('this box for a list to choose from, or enter');
Writeln('the program name below, EXE extension assumed.');
Writeln('Enter any command line arguments as needed.');
Writeln;
Write('Pressing Esc on any field cancels.');

{---- Get the name of the second child }
WindMax := init_max; WindMin := init_min;
GotoXY(ULCol + 3, ULRow + 10);
Write('Enter name of program to execute:');
GotoXY(ULCol + 3, ULRow + 14);
Write('Enter any command line arguments:');
{ Show the OK prompt }
Window(ULCol + 33, ULRow + 18, ULCol + 39, ULRow + 18);
Write(OK);

Cursor_on;                                     { show cursor till done }

GetMem(ptrNameList, SizeOf(NameList));       { Allocate some heap }

{ Make a list of  EXE file names }
TmpStr :=  '*.EXE';
FindFirst(TmpStr, Archive, FoundName);
i := 0;
while (DosError = 0) and (i < MaxNameList) do
begin
  Inc(i);
  ptrNameList^[i] := FoundName.Name;
  FindNext(FoundName);
end;
NameListCount := i;
DosError := 0;    { Clear error 18 -- No More Files -- from code }

{Call the sorter }
FileNameSort(ptrNameList^, 1, NameListCount);

InBoxes := 4; InBox := 2; OKBox := 4; Done := False; Choice := 0;
Repeat
   Case InBox of

      1: Begin { get program choice from list }
         Window(ULCol, ULRow, LLCol, LLRow);
         GotoXY(17, 2);

         { Call the picker }
         Picker(ptrNameList^, NameListCount, Choice, Key);

         If Key = #27 then                                                             Begin
            swCanceled := True;
            Goto GetChild2Canceled;
            End;

         If Key = #13 Then LastC2Name := ptrNameList^[Choice];

         End; { Debug file }

      2: Begin { Get the program name }
         Window(ULCol + 3, ULRow + 12, LLCol - 3, ULRow + 12);
         ClrEOL;
         GetEditLine(LastC2Name, LLCol - ULCol - 3, Key);
         If Key = #27 then
            Begin
            swCanceled := True;
            Goto GetChild2Canceled;
            End;
         { Tack .EXE on LastC2name name,if not there already }
         FOR i := 1 TO Length( LastC2name ) DO      { Make all uppercase}
            LastC2name[ I ] := UpCase( LastC2name[I] );
         If Length(LastC2name) > 0 then
            Begin
            i := pos('.EXE', LastC2name);           { to look for .EXE or }
            If i = 0 Then                           { .COM, so we can tack}
               Begin                                { on .EXE if needed.  }
               i := pos('.COM', LastC2name);
               If i = 0 then LastC2name := LastC2name + '.EXE';
               End;
            End;
         End; { LastC2name name }


      3: Begin{ get any parms }
         Window(ULCol + 3, ULRow + 16, LLCol - 3, ULRow + 16);
         ClrEOL;
         GetEditLine(LastC2parms, LLCol - ULCol - 3, Key);
         If Key = #27 then
            Begin
            swCanceled := True;
            Goto GetChild2Canceled;
            End;
         End; { parms }


      4: Begin { OK box }
         Window(ULCol + 33, ULRow + 18, ULCol + 39, ULRow + 18);
         GetEditLine(OK, 1, Key);
         If Key = #27 then
            Begin
            swCanceled := True;
            Goto GetChild2Canceled;
            End;
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

{ Selections done, now let's do final preparations }
{ Clear upper box for status/error messages }
Window(ULCol + 17, ULRow + 2, LLCol - 4, ULRow + 7 );
ClrScr;
Child2Name     := LastC2name;
Child2parms    := LastC2parms;

If Child2Name = '' then
   Begin
   swCanceled := True;
   Goto GetChild2Canceled;
   End;

FOR i := 1 TO Length( Child2Name ) DO               { Make all uppercase}
      Child2Name[ I ] := UpCase( Child2Name[I] );
i := pos('.EXE', Child2Name);                       { to look for .EXE or }
If i = 0 Then                                       { .COM, so we can tack}
   Begin                                            { on .EXE if needed.  }
   i := pos('.COM', Child2Name);
   If i = 0 then Child2Name := Child2Name + '.EXE';
   End;

SearchedName := FSearch(Child2Name,GetEnv('PATH'));
if SearchedName = '' then
    Begin
    Writeln(Child2Name,' not found.  Operation canceled.');
    Delay(3000);
    swCanceled := True;
    Goto GetChild2Canceled;
    End
else
    Begin
    Child2Name := FExpand(SearchedName);
    { Show full path }
    WriteLn('Program found as ', Child2Name);
    End;

GetChild2Canceled:
FreeMem(ptrNameList, SizeOf(NameList));      { Release the memory }
{Leave the cursor on for messages in Child2 and for the second child}

End; { GetChild2Name }

End. { SwapQB Unit }
