{-------------------------------------------------------------------------

                                 PDAPROF 

            Unit to handle in-memory program execution profiling

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
                  granularity
03/24/91   0.80   Adaptations made to conform with routine call counting in
                  addition to timed sampling.
04/08/91   0.85   Real time clock profiling using periodic interrupt added.
05/05/91   0.92   Compute program elapsed time in seconds based on samples.
05/15/91   0.93   PDAPROFH help unit created from PDAPROF.
}
{-------------------------------------------------------------------------}
{$F+}                               { Far calls needed for overlays }
{$O+}                               { Unit may be overlaid          }
UNIT PDAProf;

{Provides code within the unit to allow user to set profiling conditions,
obtain on-line help on profiling, and delete old sample data from the
sample buffer. Also calls the analyze code in the subordinate overlay unit
to display profiling results.}

{==========================================================================}
{================================= Interface ==============================}
{==========================================================================}
INTERFACE


USES Crt, Dos, pdaSubs, pdartc, PDAEDLN, pdaprofa, pdaprofh;


PROCEDURE Profiler;                 { Only one public procedure         }


{==========================================================================}
{============================ Implementation ==============================}
{==========================================================================}

IMPLEMENTATION
{ External Access:
   Variables:                          Calls:
      MaxCounts                           BorderTitlePrompt
      TextLine                W           GotoXY
      SampleRecordLength                  MemW
      SampleRecordT                       GetDir
      TotalSampleCounts       W           Window
      TotalSampleTicks        W           ClrScr
      QBds                                ReadKey
      ptrSubList                          GetUpKey
      ptrCurrentSubSeg                    WriteHexWord
      SegNameList                         cursor_on
      NameAdjust                          Box
      NextSampleRec           W           cursor_off
      SampleBufferStart       W           GetKey
      StoredSampleRate        W           Analyze
      ProfElapsed             W           SetRtcRate
      QBXVer                              Disable_Rtc
      QBcsE                               Enable_Rtc
      ProgramRunning
      SamplingEnabled         W
      SampleRate              W
      BufferUsage             W
      Sampling                W
      SampleRec               W
      SampleBufferStart       W
      ptrSampleRec            W
      ptrNextSampleRec        W
      SampleBufferOverFlow    W
      TotalSampleCounts       W
      SampleRIndex            W
      Use_Rtc                 W
      SampleRates
      SampleTSource           W
      Rtc_PI                  W
}

{ =============================  Profiler   ========================
}
PROCEDURE Profiler;

Var
Title                         : String13;
Prompt                        : String70;
Ch                            : Char;
i, j                          : Word;     { Generic counters                  }
NameOffset                    : Word;     { Offset of current subname      }
TotalSamples                  : LongInt;  { # samples in sample buffer     }
{ Temporaries for display pending user acceptance }
tSamplingEnabled              : Boolean;
tSampleRate                   : Word;
tSampleRIndex                 : Byte;
tTotalSamples                 : LongInt;
tDiscard                      : Boolean;


{ =========================== InitSampleBuffer  ========================
   Initializes the profiling sample buffer. Called when the profiling is
   first enabled and whenever samples are discarded.
}
PROCEDURE InitSampleBuffer;
Begin
   { Initialize sample buffer }
   SampleRec := SampleBufferStart;        { create new record for       }
   ptrSampleRec^.SubNum := 0;             { for the main "SUB"          }
   ptrSampleRec^.SubCount  := 1;          { initing its counters to     }
   ptrSampleRec^.SubTicks  := 0;          { 1 and 0.                    }
   NextSampleRec := SampleRec + SampleRecLength;   { Post end marker    }
   ptrNextSampleRec^.SubNum := $FFFF;     {  also.                      }
   SampleBufferOverFlow := False;         { overflow flag and return    }
   TotalSampleCounts := 1;                { anticipate call to main     }
   TotalSampleTicks := 0;
End; {InitSampleBuffer}





{ =============================  Information   ========================
Provides a display of technical information to assist in developing and
debugging profile process.}
PROCEDURE Information;
Begin
      ClrScr;
      Writeln('Profiler Information');
      Write('QBX Version: ',QBXVer,' QBcs: ');
      WriteHexWord(QBcs); Write(' QBds: '); WriteHexWord(QBds);
      Write(' QBcsE: '); WriteHexWord(QBcsE); Writeln;
      Writeln;

      Write(' SampleBuffer: '); WriteHexWord(Seg(SampleBufferStart));
      Write(':'); WriteHexWord(Ofs(SampleBuffer));
      Write(' Sample records = ', (NextSampleRec - SampleRec) div SampleRecLength);
      If SampleBufferOverFlow = True then
         Writeln(' Overflow')
      Else
         Writeln;
      Writeln;

      Write('Sublist: '); WriteHexWord(ptrSubList^);
      Write(' CurrentSubSeg: '); WriteHexWord(ptrCurrentSubSeg^);
      Writeln; {Writeln;}

      Write('NameAdjust: '); WriteHexWord(NameAdjust);
      Write(' NameSegAdjust: '); WriteHexWord(NameSegAdjust);
      Writeln;

      NameOffset := MemW[QBds:ptrSubList^ + ptrCurrentSubSeg^ - NameAdjust];
      SegNameList := MemW[QBds: ptrSubList^ + NameSegAdjust];
      Write('NameOffset: '); WriteHexWord(NameOffset);
      Write(' SegNameList: '); WriteHexWord(SegNameList);
      Writeln; {Writeln;}
      If ProgramRunning Then
         Writeln('Program running.')
      Else
         Writeln('Program not running.');

      Writeln('SampleRIndex = ',SampleRIndex,' (',SampleRates[SampleRIndex],') sps');
      Write('Source is ');
      If SampleTSource = SysTick Then
         Write('system timer, ')
      Else
         Write('real-time clock, ');

      If Rtc_PI = False then
         Write(' rtc off, ')
      Else
         Write(' rtc on, ');

      If Use_Rtc then
         Writeln(' RTC allowed.')
      Else
         Writeln(', RTC not allowed.');

      Repeat
         Ch:= GetUpKey;
      Until Ch = #27;

End; { Information }






{ === Main Procedure === }
Begin
ClrScr;
Title    := ' Profiler ';
Prompt   := ' Press key corresponding to desired selection ';
BorderTitlePrompt(Title, Prompt);

{ Get the count of samples }
TotalSamples := TotalSampleTicks;

{Preserve permanent settings}
tDiscard             := False;
tSamplingEnabled     := SamplingEnabled;
tSampleRate          := SampleRate;
tSampleRIndex        := SampleRIndex;
tTotalSamples        := TotalSamples;

Repeat

Box(8, 4, 25, 11);
Box(42,4, 25, 11);
Box(4, 2, 67, 15);
GotoXY(17, 3); Write('Set up'); GotoXY(51, 3); Write('Review');

{ Left Panel }
GotoXY(10, 6); Write('<P>rofile sampling');

GotoXY(13, 7);
If tSamplingEnabled then
   Write('- ENABLED  -')
Else
   Write('- Disabled -');

GotoXY(10, 9);
If Use_Rtc Then
   Write('<R>ate of sampling')
Else
   Write('Sampling rate');
GotoXY(13, 10); Write( tSampleRate:5,' per second');

{ Right Panel }
GotoXY(45, 6);If tTotalSamples > 0 Then
                  Write(tTotalSamples:10, ' samples') Else
                  Write('  There are no    ');
GotoXY(45,8); If tTotalSamples > 0 Then
                  Write('<A>nalyze samples') Else
                  Write('  samples in the ');
GotoXY(45,10); If tTotalSamples > 0 Then
                  Write('<D>iscard samples') Else
                  Write('  sample buffer. ');
GotoXY(43,11); Write('_______________________');
GotoXY(51,13); Write('<H>elp');

GotoXY(25,18); Write('< OK >       < Esc = Cancel >'); GotoXY(27,18);
cursor_on;
Repeat
   Ch := GetUpKey;
Until (Ch IN ['P','D','R','A','H', #19, #27, #13]);
cursor_off;

Case Ch of
'P' : Begin  { Toggle profiling }
      tSamplingEnabled := not tSamplingEnabled;
      End;
'D' : Begin  { Discard Samples }
      tDiscard := True;
      tTotalSamples := 0;
      end;
'R' : Begin  { Rate change }
      Inc(tSampleRIndex);
      If Not Use_Rtc then tSampleRIndex := 1;      { System ticker only    }
      If tSampleRIndex > SampleRateList then
         tSampleRIndex := 1;
      tSampleRate := SampleRates[tSampleRIndex];
      { Warn if potential for screwy sample data }
      If (StoredSampleRate <> tSampleRate) and (tTotalSamples > 0) Then
         Begin
         ClrScr;
         GotoXY(1,5);
         Writeln('WARNING --- the sample rate you have selected, ',tSampleRate,', is different');
         Writeln('from the rate used to collect the last samples (',StoredSampleRate,').');
         Writeln;
         Writeln('To ensure valid profile sampling data, you should either: ');
         Writeln('  - set the current rate to ',StoredSampleRate,' or');
         Writeln('  - discard the last samples.');
         Writeln;
         Write('Press a key to continue ...');
         Ch := GetKey;
         Ch := #0;
         ClrScr;
         End;
      End;
'A' : Begin
      If tTotalSamples > 0 Then
         Begin
         Analyze; { Show results }
         BorderTitlePrompt(Title, Prompt);
         End;
      End;
'H' : Begin { Help Information }
      pfHelpInfo;
      End; { information }
#19 : Begin { Secret information }
      {Information;}
      End;
End; { Case }

Until Ch IN [#27, #13];


{ Set profiling configuration based on above selections}
If Ch = #13 Then                     { Only if user said so, not cancel }
   Begin

   { Turn on/off actual sampling }
   If tSamplingEnabled <> SamplingEnabled Then
      Begin
      Ch := 'Y';                     { Assume use of buffer }
      { Check for multi-use and permission to overwrite }
      If (BufferUsage = QBCing) and qbcChanged Then
         Begin
         ClrScr;
         GotoXY(25,10);Writeln('Sample buffer in use by Build EXE.');
         GotoXY(20,12);Write('Lose unsaved changes to compile/link options (Y/N)?');
         Repeat
            Ch := GetUpKey;
         Until Ch in  ['Y','N'];
         ClrScr;
         End;
      If Ch = 'Y' Then
         Begin
         SamplingEnabled := tSamplingEnabled;
         { Signal others of our buffer ownership }
         BufferUsage := Sampling;
         { Initialize sample buffer,if needed }
         SampleRec := SampleBufferStart;        
         If ptrSampleRec^.SubNum <> 0 Then InitSampleBuffer;
         End;
      End;  { SamplingEnabled setup }

   { Clear out the buffer, if requested }
   If tDiscard Then InitSampleBuffer;


   { Set any new sampling rate }
   If SampleRate <> tSampleRate Then
      Begin
      SampleRate     := tSampleRate;
      SampleRIndex   := tSampleRIndex;
      If SampleRIndex > 1 Then SetRtcRate(SampleRate);
      End;

   { Record sample rate }
   StoredSampleRate := SampleRate;

   If SampleRIndex = 1 then                      { The first rate in the rate }
      SampleTSource := SysTick                   { array list is the system,  }
      Else SampleTSource := RTC;                 { others are the Rtc's       }

   If (SampleTSource = Systick) or
   (Rtc_PI and (Not SamplingEnabled)) Then       { Stop the periodic interrupt}
      Begin                                      { from running when sampling }
      Disable_Rtc;                               { is not enabled or Systick. }
      Rtc_PI := False;
      End;

   If SamplingEnabled and Use_Rtc Then           { Turn on periodic interrupt }
      If SampleTSource = RTC then                { if sampling enabled with an}
         Begin                                   { Rtc sampling rate in effect}
         Enable_Rtc;
         Rtc_PI := True;
         End;
   End; { setting up }

End; { Profiler main routine }

END. { PDAProf unit }

