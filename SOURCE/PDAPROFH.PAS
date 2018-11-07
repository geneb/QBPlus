{-------------------------------------------------------------------------

                                 PDAPROFH 

                  The Help Unit for execution profiling

                  Written for Borland Turbo Pascal V 6.0

                     Copyright 1991, by John H. Eckert
                           All Rights Reserved


                                                   ... a component of the
                                                   QuickBasic Programmer
                                                   Desk Accessories ...
-------------------------------------------------------------------------}
{ History:          
05/15/91   0.93   Unit created from PDAPROF.
}
{-------------------------------------------------------------------------}
{$F+}                               { Far calls needed for overlays }
{$O+}                               { Unit may be overlaid          }
UNIT PDAProfh;

{Provides a help screen for the profiler.}

{==========================================================================}
{================================= Interface ==============================}
{==========================================================================}
INTERFACE


USES Crt, pdaSubs;


PROCEDURE pfHelpInfo;           { Only one public procedure         }


{==========================================================================}
{============================ Implementation ==============================}
{==========================================================================}

IMPLEMENTATION

{ =============================  pfHelpInformation   ========================
Provides a display of help information to assist in developing and
debugging profile process.}
PROCEDURE pfHelpInfo;
Begin
      ClrScr;
      Writeln('Profiler Help Information':48);
      {Writeln; }
      Writeln(' The Profiler, when enabled, periodically records the subroutine or');
      Writeln(' function your running program is executing at that moment.  Sampling');
      Writeln(' occurs at 18 times per second, or up to 2048 per second with a real');
      Writeln(' time clock. Each call to a routine is also counted.  Sampling is auto-');
      Writeln(' matically suspended when the program is halted and resumes auto-');
      Writeln(' matically when that program or another program is run.  Be sure to ');
      Writeln(' delete any previous samplings when starting a new session, or program.');
      Writeln;
      Writeln(' Analysis tells you where your program spent its time when the samples');
      Writeln(' were being collected and the number of times each routine was called,');
      Writeln(' presented as individual horizontal bar graphs.  Select "Time" and');
      Writeln(' "Calls" respectively.  For the average duration of each routine, ');
      Writeln(' select "Duration".  "Print" produces a complete hard copy report.');
      Writeln;
      Writeln(' Warning: Sample data overwites the Compile/Link options editing area.');
      Writeln(' Before enabling sampling, save its contents if you want it preserved.');

      GotoXY(33,19); Write('< OK >');GotoXY(35,19);
      cursor_on;
      Ch := GetKey;
      ClrScr;
      Ch := #0;

End; { pfHelpInfo }
End. {Unit}
