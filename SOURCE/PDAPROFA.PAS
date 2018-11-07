{-------------------------------------------------------------------------

                                 PDAPROFA 

                  Unit to analyze results of in-memory
                     program execution profiling

                  Written for Borland Turbo Pascal V 6.0

                     Copyright 1991, by John H. Eckert
                           All Rights Reserved


                                                   ... a component of the
                                                   QuickBasic Programmer
                                                   Desk Accessories ...
-------------------------------------------------------------------------}
{ History:          
01/15/91   0.10   Originally a part of the stand alone utility, QBPF.EXE,
                  the code here has been restructured as an overlay to
                  enable the sampling via the Int 8 ISR, to save sample data
                  to disk, and to analyze the sample data.  This is a scaled
                  down version of the stand alone, supporting only sampling
                  at subroutine level, and only at a maximum 18/sec rate.
02/01/91   0.50   Profiler unit split-out of analyzer for increased
                  granularity.
03/24/91   0.80   Adapted to display time as well as call count data for
                  each routine.
04/08/91   0.85   Real time clock periodic interrupt changes.
04/25/91   0.88   PDAMath support incorporated into Duration analysis.
04/26/91   0.90   64-bit math incorporated into both time and call profile
                  analysis.
05/05/91   0.92   Compute program elapsed time in seconds based on samples.
}
{-------------------------------------------------------------------------}
{$F+}                               { Far calls needed for overlays }
{$O+}                               { Unit may be overlaid          }
UNIT PDAProfa;

{Contains the procedure for tabulation and display of raw profile sampling
data stored in memory. Called by the main profiler menu procedure in pdaprof
unit. }

{==========================================================================}
{================================= Interface ==============================}
{==========================================================================}
INTERFACE


USES Crt, Dos, pdaSubs, PDAEDLN, PDAMath, pdaProfp;


PROCEDURE Analyze;                 { Only one public procedure         }


{==========================================================================}
{============================ Implementation ==============================}
{==========================================================================}

IMPLEMENTATION

{ =============================  Analyzer   ========================
 Displays a horizontal frequency distribution histogram reflecting the
 percentage of the total execution time the program spent in each routine,
 and the percentage of calls to each routine. A tabular display shows the
 average duration of each routine based on the call and tick counts. 
 Percentages are calculated from call and tick count values in the sample
 buffer, and displayed using the names of the procedures found in the name
 at the offset+3 of their sub number used in the p-code calls.  Sample data
 and name list data is drawn directly from their respective memory locations.
 The histograms are drawn dynamically when the data is displayed on screen
 so that scarce memory is conserved. Called from the main profiler menu.
 }
{ External Access:
   Variables:                          Calls:
      MaxCounts                           BorderTitlePrompt
      TextLine                            GotoXY
      SampleRecordLength                  MemW
      SampleRecordT                       GetDir
      TotalSampleCounts                   Window
      TotalSampleTicks                    ClrScr
      QBds                                ReadKey
      ptrSubList                          GetUpKey
      ptrCurrentSubSeg                    Div64
      SegNameList                         Mult64
      NameAdjust                          Write64
      NextSampleRec
      SampleBufferStart
      SampleBufferOverFlow
      StoredSampleRate
      ProfElapsed
      UpArrow
      DownArrow
      ULCol
      ULRow
      LLCol
      LLRow
}
PROCEDURE Analyze;
Label AnalyzeDone;

Const
SubNameLength = 18;                       { Chars in subname on chart      }
HistoLength   = 50;                       { Histogram length in columns    }
MaxCounts   = SizeOf(TextLine) Div SampleRecLength;
Time  = 1;                                { Define constants for analyze   }
Calls = 2;                                { types ...                      }
Duration = 3;

Type
ptrString      = ^String;
SampleCounts   =  array[1..MaxCounts]     { We'll address the records as   }
                        of SampleRecT;    { an array.                      }

Var
Title                         : String13;
Prompt                        : String70;
Ch                            : Char;
i, j                          : Word;     { Generic counters                  }
ptrEndNameList                : ^Word;    { Offset of end of name list     }
ptrSubName                    : ptrString;  { ptr to  current sub name       }
ptrMainModName                : ptrString;  { ptr to main mod name            }
ptrNameLength                 : ^Byte absolute ptrSubName; { ptr to length }
NameOffset                    : Word;     { Offset of current subname      }
Drive                         : Byte;     { Dos default drive              }
CurrentDir                    : DirStr;   { Dos default dr/dir             }
Driveptr                      : Byte;
GotName                       : Boolean;
TotalSamples                  : LongInt;  { # samples in sample buffer     }
ptrSampleCount                : ^SampleCounts;  { Ptr to our workspace     }
TabulateCount                 : Word;     { Count of tabulation records    }
StartIndex                    : Word;     { First tabulate record on screen}
LineCounter                   : Byte;     { Current analysis display line  }
LastLine                      : Byte;     { Bottom scrn line of analysis   }
BarCol                        : Byte;     { Scrn columns in histogram      }
Percentage                    : Byte;     { Time/Call ratio for graph      }
Done                          : Boolean;  { Signals analysis viewing over  }
AnalyzeType                   : Byte;     { Time, Calls or Duration modes  }
Micrs                         : LongInt;  { Microseconds per sample        }
mResult                       : Byte;     { Hold math64 return codes       }
Temp64                        : qword;    { holds 64-bit interim results   }
Temp32                        : LongInt absolute Temp64; { lo val of above }
Str64                         : String absolute ExecStack;{ 64-bit string  }


CONST
{ QB's internal linked pointers to the names of loaded modules begins
  at a different offset depending upon the default drive.  We'll use a
  list of offsets for drives from A-P. If this PC has more drives than
  that, the owner will have to use QB on one between A-P if profiling
  desired. }
ModPtrs    = 16;                            { 16 drives, A-P            }
ModPtr         : ARRAY[1..ModPtrs] of Byte = ($10,$16,$14,$1A,$18,
                                              $1E,$1C,$2,$0,$6,$4,
                                              $A,$8,$E,$C,$12);




Begin
ClrScr;
Done        := False;                  { Flag for "had enough"       }
Title    := ' Profiler ';
Prompt := ' Up/Down Arrows  T=Time  C=Calls  D=Duration  P=Print  Esc=Exit ';
BorderTitlePrompt(Title, Prompt);


{ Bug out if no samples to analyze }
If (TotalSampleCounts + TotalSampleTicks) < 2 Then
   Begin
   GotoXY(1,3);
   Writeln('No sample data to analyze.');
   Writeln;
   Writeln('First, enable sampling from the Profiler menu, then return to ');
   Writeln('QuickBasic and run your program. Sampling data then will be ');
   Writeln('collected for you to analyze here.');
   Goto AnalyzeDone;
   End;

{ Obtain the memory location of the loaded Basic program routine name
list }
NameOffset := MemW[QBds:ptrSubList^ + ptrCurrentSubSeg^ - NameAdjust];
SegNameList := MemW[QBds: ptrSubList^ + NameSegAdjust];

{ Module/SUB listings -- let's see if we have a valid name list in memory.
We'll look for a valid fully qualified dos filespec at the first location
in the name list -- that is the filename of the first loaded module.}
{Get current drive and directory. We need this to locate the entry point
to the name listing.}
Drive := 0;                               { Default drive }
GetDir(Drive, CurrentDir);
Drive := Ord(CurrentDir[1]) - 64;

{ But since the current drive may have changed, we need to check for
valid data at this entry point, and be prepared to search at other entry
points for the first module name.}
DrivePtr := 0;
NameOffset := MemW[SegNameList:ModPtr[Drive]];
GotName := False;
Repeat
   ptrSubName := ptr(SegNameList, NameOffset + 3);
   IF ptrSubName^[2] = ':' then       { must have a valid filespec }
      GotName := True
   Else
      Begin
      Inc(DrivePtr);
      NameOffset := MemW[SegNameList:ModPtr[DrivePtr]];
      End;
until (DrivePtr > ModPtrs) or GotName;
ptrMainModName := ptrSubName;         { save ptr to  main mod name }

If not GotName then
   Begin
   GotoXY(1,3);
   Writeln('Listing of subroutine names not found in memory.');
   Writeln;
   Writeln('The unedited QuickBasic program from which the samples were');
   Writeln('collected must remain in memory so that the subroutines may be');
   Writeln('accessed at the same memory location they held during execution');
   Writeln('in order for sampling analysis to be valid.  You will need to');
   Writeln('delete the sample data at the Profiler menu, then return to');
   Writeln('QuickBasic and run the program again to collect new samples');
   Writeln('for analysis.');
   Goto AnalyzeDone;
   End;


   { OK, all set for analysis }
   Begin
   { A valid modulename means we can get the sub names, so set up pointer. }
   ptrEndNameList := ptr(SegNameList, $52);

   { Get the count of sample records }
   TabulateCount := (NextSampleRec - SampleBufferStart) Div SampleRecLength;

   { Orient Sample array to our sample buffer }
   ptrSampleCount := @TextLine;

   { Figure the microseconds between samples based on the sample rate }
   Micrs := 1000000 Div StoredSampleRate;

   { Figure the program's elapsed time in seconds by dividing the total
      sample count by sample rate per second.}
   mResult := Mult64(TotalSampleTicks, 1, Temp64); { Convert to 64 bit val }
   mResult := Div64(Temp64, StoredSampleRate);     { Divide by samples/sec }
   If mResult <> 0 Then
      ProfElapsed := 0                             { Make 0, if error, or  }
   Else
      ProfElapsed := Temp32;                       { Extract 32-bit val    }



   { Default to time display }
   AnalyzeType := Time;

   { Write and protect the top row header }
   Writeln('컴� Routine 컴컴컴컴컴컴컴컴 Time Percentage 컴컴컴컴컴컴컴컴컴컴컴컴컴');
   Window(ULCol, ULRow + 1, LLCol, LLRow);{ Protects top row            }
   StartIndex  := 1;                      { Begin at the first record   }
   LastLine    := 18;                     { Number of scrn display lines}

   Repeat

      { Display a screenful, or less if not enough for a screen full }
      ClrScr;
      LineCounter := 1;                   { Begin on top line           }
      j           := StartIndex;          { First tab element to show   }

      { We'll loop till out of tabulate array records, or bottom of window }
      While (j <= TabulateCount) and (LineCounter < LastLine) Do
         Begin
         { Only display routines whose numbers are within the list }
         If ptrSampleCount^[j].SubNum < ptrEndNameList^ Then
            Begin
            GotoXY(1, LineCounter);
            If ptrSampleCount^[j].SubNum = 0 then     { Main is ID'd as 0    }
               Write('Main Module')
            Else
               Begin                                   { Others have offset ptr}
               { Routine name begins in name list 3 bytes past its offset }
               ptrSubName := ptr(SegNameList, ptrSampleCount^[j].SubNum + 3);
               { Limit name so as not to spill onto bar graph }
               If Length(ptrSubName^) > SubNameLength Then
                  For i := 1 to SubNameLength Do
                     Write(ptrSubName^[i])
               Else
                  Write(ptrSubName^);
               End;

            { Position to start of bar graph }
            GotoXY(SubNameLength + 1, WhereY);

            Case AnalyzeType of
            Time: Begin

            { Figure the number of screen columns based on the count for this
              routine as a percentage of the total. Note this formula works best
              when HistoLength - the number of screen positions equal to 100% -
              evenly divides into 100, as it does here with the value of 50. It's
              best to keep it that way.  Avoid division involving zero.}
            If (ptrSampleCount^[j].SubTicks > 0) and (TotalSampleTicks > 0) Then
               { We'll use big math to accomodate LongInt overflow }
               Begin
               mResult := Mult64(ptrSampleCount^[j].SubTicks, 100, Temp64);
               mResult := Div64(Temp64, TotalSampleTicks);
               If mResult > 0 Then
                  Percentage := 0            { Division error, make Percentage = 0 }
               Else
                  Percentage := Byte(Temp64[1]);     { First byte of qword is least }
               End
            Else
               Percentage := 0;

            { Keep Histographs on screen, even if value is out of bounds }
            BarCol := Percentage div (100 Div HistoLength);
            If BarCol > HistoLength Then BarCol := HistoLength;

            { Routines with a percentage less than two produce a BarCol value
             of 0, and would thus have no bar, so we'll give them a very short
             one to avoid a spotty looking display.  }
            If BarCol = 0 then Write(#221) else Inverse(BarCol);

            { Locate the numerical percentage at the right of the screen window }
            GotoXY(SubNameLength + HistoLength + 1, WhereY);
            Write(Percentage:3,'%');
            End; { Time proportional display }



            Calls: Begin
            If (ptrSampleCount^[j].SubCount > 0) and (TotalSampleCounts > 0) Then
               { We'll use big math to accomodate LongInt overflow }
               Begin
               mResult := Mult64(ptrSampleCount^[j].SubCount, 100, Temp64);
               mResult := Div64(Temp64, TotalSampleCounts);
               If mResult > 0 Then
                  Percentage := 0            { Division error, make Percentage= 0 }
               Else
                  Percentage := Byte(Temp64[1]);
               End
            Else
               Percentage := 0;
            { Keep Histographs on screen, even if value is out of bounds }
            BarCol := Percentage div (100 Div HistoLength);
            If BarCol > HistoLength Then BarCol := HistoLength;
            If BarCol = 0 then Write(#221) else Inverse(BarCol);
            GotoXY(SubNameLength + HistoLength + 1, WhereY);
            Write(Percentage:3,'%');
            End; { Count proportional display }



            Duration : Begin
            { Convert call count to 64-bit value, put in Temporary result }
            mResult := Mult64(ptrSampleCount^[j].SubCount, 1, Temp64);
            Num64toStr(Temp64, Str64, True);    { Show it w/commas      }
            Write(Str64:14);
            { Make sure we don't divide by or into zero }
            If (ptrSampleCount^[j].SubTicks > 0) and(ptrSampleCount^[j].SubCount > 0) Then
               Begin
               { Figure total microseconds -- possible 64-bit value }
               mResult := Mult64(ptrSampleCount^[j].SubTicks, Micrs, Temp64);
               { Divide by the call counts for the average }
               mResult := Div64(Temp64, ptrSampleCount^[j].SubCount);
               If mResult <> 0 Then
                  Write('    Divide error')     { Display problem, if one  }
               Else
                  Begin
                  Num64toStr(Temp64, Str64, True);    { ..or value w/commas      }
                  Write(Str64:20);
                  End;
               End
            Else
               Write(0:20);
            End;{ Duration }
            End; {Case}

            { Point at next tabulation record and screen line }
            Inc(LineCounter);
            End; { Displaying valid record }
         Inc(j);
         End;



     Case AnalyzeType Of
     Time : Begin
     { Display the program's elapsed time (execution duration). This is
     actual running time. }
     Write('Program execution duration = ');
     Write(ProfElapsed,' seconds.');
     End; { time display }

     Calls : Begin
     Write('Total number of calls = ',TotalSampleCounts);
     End; { Calls display }

     Duration : Begin
     Writeln;
     GotoXY(8, WhereY);
     Write('(Average Duration values are in microseconds.)');
     End; { Duration }
     End;{Case}

     { Alert them to buffer overflow, bottom line }
     If SampleBufferOverFlow then Write(' SAMPLE OVERFLOW');

     { Locate the pointer at the right of the screen window }
     GotoXY(SubNameLength + HistoLength - 1, WhereY);
     If StartIndex > 1 Then
      If TabulateCount > j - 1 Then
         Write('More'#18)        { Both arrows -- stuff above and below    }
      Else
         Write('More'#24)        { Up arrow -- stuff above top line only   }
     Else
      If TabulateCount > j - 1 Then
         Write('More'#25);        { Down arrow -- stuff only below            }
         

     { Get their command ... }
     Ch := ReadKey;
     Case Ch of
         #0 : Begin
            Ch := ReadKey; { Extended keys }
            Case Ch of
               UpArrow  : Begin                { Point start at previous   }        
                           Dec(StartIndex);    { tabulation element        }
                           If StartIndex < 1 then StartIndex := 1;
                           End;
               DownArrow : Begin                { Point start at next      }
                           Inc(StartIndex);     { tabulation element       }
                           If StartIndex >= TabulateCount Then
                              StartIndex := TabulateCount;
                           End;
               F9        : Begin End;
               End; {Case }
            End; { Extended keys }
         #27 : Done := True;                    { Esc cancels displaying   }
         't','T' : Begin
                  AnalyzeType := Time;
                  Window(ULCol, ULRow, LLCol, LLRow);         { Restore standard window  }
                  GotoXY(1,1);
                  { Write and protect the top row header }
                  Writeln('컴� Routine 컴컴컴컴컴컴컴컴 Time Percentage 컴컴컴컴컴컴컴컴컴컴컴컴컴');
                  Window(ULCol, ULRow + 1, LLCol, LLRow);{ Protects top row            }
                  End;
         'c','C' : Begin
                  AnalyzeType := Calls;
                  Window(ULCol, ULRow, LLCol, LLRow);         { Restore standard window  }
                  GotoXY(1,1);
                  { Write and protect the top row header }
                  Writeln('컴� Routine 컴컴컴컴컴컴컴컴 Call Percentage 컴컴컴컴컴컴컴컴컴컴컴컴컴');
                  Window(ULCol, ULRow + 1, LLCol, LLRow);{ Protects top row            }
                  End;
         'd','D' : Begin
                  AnalyzeType := Duration;
                  Window(ULCol, ULRow, LLCol, LLRow);         { Restore standard window  }
                  GotoXY(1,1);
                  { Write and protect the top row header }
                  Writeln('컴� Routine 컴컴컴컴� Call count 컴 Average Duration                   ');
                  Window(ULCol, ULRow + 1, LLCol, LLRow);{ Protects top row            }
                  End;
         'p','P'  : Begin
                  ClearPrompt;
                  Window(ULCol, ULRow, LLCol, LLRow);         { Restore standard window  }
                  ClrScr;
                  Box(4, 2, 66, 15);
                  GotoXY(25, 3);
                  Write('Print Full Profiling Report');
                  Window(ULCol + 10, ULRow + 5, LLCol - 10, LLRow - 4);
                  Write('Report length is ',TabulateCount + 6,' lines, ');
                  Writeln('output to LPT1');
                  Writeln;
                  Writeln('Prepare printer. Press any key to begin, or');
                  Write('Press ESC to cancel...');
                  Cursor_on;
                  Ch := GetKey;
                  If Ch <> #27 Then PrintProfReport(ptrMainModName^);
                  Cursor_off;
                  Done := True;        { Return to main profiler menu }
                  End;

         End; {Case}
     Until Done;

   End; 

AnalyzeDone:
Window(ULCol, ULRow, LLCol, LLRow);         { Restore standard window  }
Writeln;
If Not Done then
   Repeat                                       { Wait for keypress from   }
      Ch:= GetUpKey;                            { the message screens.     }
   Until Ch = #27;
ClrScr;

End; { Analyze }

END. { PDAProfa unit }

