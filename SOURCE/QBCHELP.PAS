{-------------------------------------------------------------------------

                                 QBCHelp  

                  Unit to display help information in the
                        compile/link option editor.

                  Written for Borland Turbo Pascal V 6.0

                     Copyright 1991, by John H. Eckert
                           All Rights Reserved


                                                   ... a component of the
                                                   QuickBasic Programmer
                                                   Desk Accessories ...
-------------------------------------------------------------------------}
{ History:           
01/11/91   0.20   Unit extracted from QBC unit.
}
{-------------------------------------------------------------------------}
{$F+}                               { Far calls needed for overlays }
{$O+}                               { Unit may be overlaid          }
UNIT QBCHelp;


{==========================================================================}
{================================= Interface ==============================}
{==========================================================================}
INTERFACE


USES Crt, Dos, pdaSubs;

PROCEDURE HelpScreen;                 { Only one public procedure       }


{==========================================================================}
{============================ Implementation ==============================}
{==========================================================================}

IMPLEMENTATION

{ ===============================  Help/Instructions ========================
}
PROCEDURE HelpScreen;

{ Local Procedure that prompts and pauses for a  key }
Procedure WaitKey;
Begin
   GotoXY(24,17);
   Write('< Next >     < Esc = Quit Help >');
   GotoXY(26,17);
   Ch := GetKey;
End;

Begin
ClrScr;
Window( ULCol+1, ULRow+1, LLCol, LLRow );
Repeat
IF Ch <> #27 then 
   Begin
   ClrScr;
   Writeln;
   Writeln('     Line editing commands:');
   Writeln;
   Writeln('     Arrows    = move cursor one character or line');
   Writeln('     Home      = move cursor to beginning of line');
   Writeln('     End       = move cursor to end of line');
   Writeln('     Enter/Ins = insert a blank line (40 lines maximum)');
   Writeln('     Del       = delete line or character');
   Writeln('     ^Y        = cut a line and store in the one-line cut buffer');
   Writeln('     Shift-Ins = paste the line from the cut buffer');
   Writeln('     Esc       = cancel editing and return to QuickBasic');
   Writeln('     F2        = return to QuickBasic, saving changes to file');
   Writeln('     F10       = save changes to file, build executable file');
   WaitKey;
   End;

IF Ch <> #27 then 
   Begin
   ClrScr;
   Writeln;
   Writeln('    BC Options:                     旼컴컴  (PDS 7 additions) 컴컴커');
   Writeln;
   Writeln('    A   Assembly listing             Es   Share EMS');
   Writeln('    AH  Huge arrays                  FPa  Alternate Floating pt');
   Writeln('    D   Debug code                   FPi  Floating pt in-line');
   Writeln('    R   Row major arrays             Fs   Far strings');
   Writeln('    S   Strings to object file       G2   80286 instructions');
   Writeln('    O   Stand alone executable       Ib   ISAM buffers');
   Writeln('    E   On Error with RESUME         Ie   non-ISAM expan. memory');
   Writeln('    X   ON ERROR                     Ii   non-null ISAM indexes');
   Writeln('    W   Line event trapping          Lp   Protected mode');
   Writeln('    V   Statement event trapping     Lr   Real mode');
   Writeln('    Zd  SYMDEF information           Ot   Optimize procedure calls');
   Writeln('    Zi  Codeview information         Z    BC Error info');
   WaitKey;
   End;

IF Ch <> #27 then 
   Begin
   ClrScr;
   Writeln('LINK Options (QB 4.5, PDS 7)':47);
   Writeln;
   Writeln('  A     Alignment:Size               B     Batch mode');
   Writeln('  CO    Codeview information         CP    Space Allocation:para');
   Writeln('  DO    Segment ordering             E     Pack executable file');
   Writeln('  F     Far call optimization        INF   Process information');
   Writeln('  LI    Line numbers in map file     M     Public symbols in map file');
   Writeln('  NOD   Ignore default libraries     NOE   Ignore extended dictionary');
   Writeln('  NOF   No far call optimization     NOI   Preserve case sensitivity');
   Writeln('  NON   "No null" ordered segments   NOP   Disable segment packing');
   Writeln('  O     Overlay interrupt:number     PACKC Pack code:groups');
   Writeln('  PACKD Pack data:groups             PADC  Pad code segments ');
   Writeln('  PADD  Pad data segments            PAU   Pause before writing EXE');
   Writeln('  Q     Create Quick Library         SE    Maximum segments:number');
   Writeln('  ST    Stack size:bytes             W     Issue fixup warnings');
   WaitKey;
   End;

IF Ch <> #27 then 
   Begin
   ClrScr;
   Writeln('BC LINE SYNTAX':41);
   Writeln('  ['#39'|$][d:][\path\]BC sourcefile[optionlist];');
   Writeln('    (Space after BC and ending semi-colon are required.)');
   Writeln;
   Writeln('LINK LINE SYNTAX':42);
   Writeln('  ['#39'|$][d:][\path\]LINK[optionlist]');
   Writeln('  objfile1[+');
   Writeln('  objfile2[+');
   Writeln('  objfile3[+...');
   Writeln('  objfileN]]]');
   Writeln('  exefilename');
   Writeln('  mapfilename');
   Writeln('  libfile1 [libfile2 [...libfileN]];');
   Writeln;
   Writeln('  (Note, the only Link semi-colon is on the library line.)');
   WaitKey;
   End;
Until Ch = #27;
Window( ULCol, ULRow, LLCol, LLRow );
End; { Help information }

End.
