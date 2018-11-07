{-------------------------------------------------------------------------

                                 QBMHelp  

                     Unit to display help about macros

                  Written for Borland Turbo Pascal V 6.0

                     Copyright 1991, by John H. Eckert
                           All Rights Reserved


                                                   ... a component of the
                                                   QuickBasic Programmer
                                                   Desk Accessories ...
-------------------------------------------------------------------------}
{ History:           
01/11/91   0.30   Unit created out of the standalone QBMacro utility.
}
{-------------------------------------------------------------------------}
{$F+}                               { Far calls needed for overlays }
{$O+}                               { Unit may be overlaid          }
UNIT QBMHelp;

{ This unit contains the help screens for the macro key accessory.  It is
called form the main macro menu. }

{==========================================================================}
{================================= Interface ==============================}
{==========================================================================}
INTERFACE


USES Crt, Dos, pdaSubs;

PROCEDURE QBMHelpScreen;

{==========================================================================}
{============================ Implementation ==============================}
{==========================================================================}

IMPLEMENTATION


{ ===============================  Help/Instructions ========================
}
Procedure QBMHelpScreen;
Begin
ClrScr;
Repeat
   Begin
   ClrScr;
   GotoXY(29, 1); Writeln('HELP');
   Writeln(' Choose the "R" option to record a series of up to 40');
   Writeln(' keystrokes within a single macro key (A-Z, 0-9). Halt');
   Writeln(' recording with your selected "End Record" key combination.');
   Writeln(' While in QB, "double-tap" the "play" key, then your macro');
   Writeln(' key, to execute the recorded keystrokes. Esc cancels Play.');
   Writeln('');
   Writeln(' Record/Playback status ("r" or "p") appears on the QB top');
   Writeln(' line. The single "m" prompts for your macro Playback key.');
   Writeln('');
   Writeln(' "Join" causes Playback to continue from one key to another.');
   Writeln('');
   Writeln(' Change command keys with the "C" option. Save recorded');
   Writeln(' keystrokes to file and load them into memory with the');
   Writeln(' "S" and "L" options.  A ".KQF" extension is assumed.');
   GotoXY(24, 17); Write('<Esc = Quit Help>.'); GotoXY(31, 17);
   Ch := GetKey;
   End;

Until  (Ch = #27) or (Ch = #13);
Ch := #0;
ClrScr;
End; { Help information }

END. { QBMHelp }
