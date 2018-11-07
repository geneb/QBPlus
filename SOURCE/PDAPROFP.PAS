{-------------------------------------------------------------------------

                                 PDAPROFP 

                  Unit to print results of in-memory
                     program execution profiling

                  Written for Borland Turbo Pascal V 6.0

                     Copyright 1991, by John H. Eckert
                           All Rights Reserved


                                                   ... a component of the
                                                   QuickBasic Programmer
                                                   Desk Accessories ...
-------------------------------------------------------------------------}
{ History:          
04/29/91   0.91   Creation of this print unit, called by profile analyzer.
05/05/91   0.92   Compute program elapsed time in seconds based on samples.
}
{-------------------------------------------------------------------------}
{$F+}                               { Far calls needed for overlays }
{$O+}                               { Unit may be overlaid          }
UNIT PDAProfp;

{Contains the procedure for tabulation and display of raw profile sampling
data stored in memory and printing it on the printer. Called by the profiler
analyze unit, pdaprofa.
unit. }

{==========================================================================}
{================================= Interface ==============================}
{==========================================================================}
INTERFACE


USES Crt, Dos, pdaSubs, PDAEDLN, PDAMath;


PROCEDURE PrintProfReport(var MainModName:String); { Only one public procedure    }


{==========================================================================}
{============================ Implementation ==============================}
{==========================================================================}

IMPLEMENTATION

{ External Access:
   Variables:                          Calls:
      MaxCounts                           
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
      NextSampleRec                       Assign
      SampleBufferStart                   WhereX
      SampleBufferOverFlow                WhereY
      StoredSampleRate
      ProfElapsed
      UpArrow
      DownArrow
      ULCol
      ULRow
      LLCol
      LLRow
      PrintPort
      Ch
      IOResult
}


{ =============================  PrintReport   ========================
 Prints a report of all relevant sampling analysis, including time and call
 percentages, call counts and average duration for each routine.  A header
 for the report shows the totals and the sample rate in effect during the
 sample collection.
 }
PROCEDURE PrintProfReport(var MainModName: String);

Label EndPrint;

Const
SubNameLength = 20;                       { Chars in subname on chart      }
MaxCounts   = SizeOf(TextLine) Div SampleRecLength;

Type
SampleCounts   =  array[1..MaxCounts]     { We'll address the records as   }
                        of SampleRecT;    { an array.                      }

Var
Lst                           : Text;     { Print output target            }
ptrEndNameList                : ^Word;    { Offset of end of name list     }
ptrSampleCount                : ^SampleCounts;  { Ptr to our workspace     }
ptrSubName                    : ^String;  { ptr to  current sub name       }
TabulateCount                 : Word;     { Count of tabulation records    }
Ch                            : Char;
i, j                          : Word;     { Generic counters               }
Percentage                    : Byte;     { Time/Call ratio for graph      }
Micrs                         : LongInt;  { Microseconds per sample        }
mResult                       : Byte;     { Hold math64 return codes       }
Temp64                        : qword;    { holds 64-bit interim results   }
Str64                         : String absolute ExecStack;{ for 64-bit val }
OutString                     : String absolute ExecStack;{ for printing   }


Type
String2     = String[2];

Const
CR          : String2 = #13#10;{ Carriage return/line feed                 }



{=============================== PrintOut ============================}
{  Print the string to the printer (Lst) within the field defined by
   Places. Lst must be assigned to the desired parallel port prior to
   this call.  If a printer error, routine puts messge on screen and
   requests user to retry or cancel printing. If cancel, the return
   value is false, otherwise it is true.}
FUNCTION PrintOut(Var PrintString : String; Places : Byte): Boolean;

Var
SaveX, SaveY      : Word;     { Stored cursor location               }
Ch                : Char;     { Keypress result                      }
Done              : Boolean;  { Ok to exit flag                      }


Begin
SaveX := WhereX;
SaveY := WhereY;
Done := False;
Repeat
   {$I-}Write(Lst, PrintString : Places);{I$+}
   If IoResult <> 0 Then
      Begin
      GotoXY(SaveX, SaveY);
      Write('Printer error. Retry(Y/N)?');
      Repeat Ch := GetUpKey; Until Ch IN ['Y','N',#27];
      If (Ch = 'N') or (Ch = #27) Then
         Begin
         Done := True;
         PrintOut := False;
         End;
      End
   Else
      Done := True;
Until Done;
GotoXY(SaveX, SaveY);
Write('                          ');
GotoXY(SaveX, SaveY);
End; {PrintOut}


Begin

{ Get the output device set up }
Assign(Lst, 'LPT1');
{$I-}Rewrite(Lst);{$I+}
If IOResult > 0 then
   Begin
   Write('Output device not ready. Press a key ...');
   Ch := GetKey;
   Exit;
   End;


{ A valid modulename means we can get the sub names, so set up pointer. }
ptrEndNameList := ptr(SegNameList, $52);

{ Get the count of sample records }
TabulateCount := (NextSampleRec - SampleBufferStart) Div SampleRecLength;

{ Orient Sample array to our sample buffer }
ptrSampleCount := @TextLine;

{ Figure the microseconds between samples based on the sample rate }
Micrs := 1000000 Div StoredSampleRate;

{Do header }

If not PrintOut(CR,0) then Goto EndPrint;     { Get to left margin         }
OutString := 'Program: ' + MainModName;
If not PrintOut(OutString, 0) then Goto EndPrint;
If not PrintOut(CR,0) then Goto EndPrint;

OutString := 'Rate: ';
If not PrintOut(OutString, 0) then Goto EndPrint;
mResult := Mult64(StoredSampleRate, 1, Temp64);
Num64toStr(Temp64, Str64, False);    { Show it w/ no commas    }
If not PrintOut(Str64, 0) then Goto EndPrint;
OutString := ' Samples: ';
If not PrintOut(OutString, 0) then Goto EndPrint;
mResult := Mult64(TotalSampleTicks, 1, Temp64);
Num64toStr(Temp64, Str64, True);    { Show it w/commas      }
If not PrintOut(Str64, 0) then Goto EndPrint;
OutString := ' Calls: ';
If not PrintOut(OutString, 0) then Goto EndPrint;
mResult := Mult64(TotalSampleCounts, 1, Temp64);
Num64toStr(Temp64, Str64, True);    { Show it w/commas      }
If not PrintOut(Str64, 0) then Goto EndPrint;
OutString := ' Seconds: ';
If not PrintOut(OutString, 0) then Goto EndPrint;
mResult := Mult64(ProfElapsed, 1, Temp64);
Num64toStr(Temp64, Str64, True);    { Show it w/commas      }
If not PrintOut(Str64, 0) then Goto EndPrint;
If not PrintOut(CR,0) then Goto EndPrint;

OutString := 'Routine              Time %  Call %    Call Count    Average Duration';
If not PrintOut(OutString, 0) then Goto EndPrint;
If not PrintOut(CR,0) then Goto EndPrint;
OutString :='-';
For i := 1 to 69 Do
   If not PrintOut(OutString, 0) then Goto EndPrint;
If not PrintOut(CR,0) then Goto EndPrint;

{ Now do the data . . . }
j           := 1;          { First tab element to show   }
{ We'll loop till out of tabulate array records, or Esc is pressed }
While (j <= TabulateCount) Do
   Begin
   { Only display routines whose numbers are within the list }
   If ptrSampleCount^[j].SubNum < ptrEndNameList^ Then
      Begin
      If ptrSampleCount^[j].SubNum = 0 then     { Main is ID'd as 0    }
         Begin
         OutString :='Main Module          ';           { length of 20 }
         If not PrintOut(OutString, 0) then Goto EndPrint;
         End
      Else
         Begin                                   { Others have offset ptr}
         { Routine name begins in name list 3 bytes past its offset }
         ptrSubName := ptr(SegNameList, ptrSampleCount^[j].SubNum + 3);
         { Limit name so as not to mess up print line }
         If Length(ptrSubName^) > SubNameLength Then
            For i := 1 to SubNameLength Do
               Begin
               OutString := ptrSubName^[i];
               If not PrintOut(OutString, 0) then Goto EndPrint;
               End
            Else
               Begin
               OutString := ptrSubName^;
               If not PrintOut(OutString, 0) then Goto EndPrint;
               { Pad with spaces to Subnamelength }
               For i := Length(ptrSubName^) to SubNameLength Do
                  Begin
                  OutString := ' ';
                  If not PrintOut(OutString, 0) then Goto EndPrint;
                  End;
               End;
         End;


         { Figure the time percentage.  Avoid division involving zero.}
         If (ptrSampleCount^[j].SubTicks > 0) and (TotalSampleTicks > 0) Then
            { We'll use big math to accomodate LongInt overflow }
            Begin
            mResult := Mult64(ptrSampleCount^[j].SubTicks, 100, Temp64);
            mResult := Div64(Temp64, TotalSampleTicks);
            If mResult > 0 Then
               mResult := Mult64(0, 0, Temp64)
               {Percentage := 0 }       { Division error, make Percentage = 0 }
            Else
               Percentage := Byte(Temp64[1]);{ First byte of qword is least }
            End
         Else
            mResult := Mult64(0, 0, Temp64);
            {Percentage := 0;}

         { Print time percentage }
         {Str(Percentage, OutString);}
         Num64toStr(Temp64, Str64, True);    { ..or value w/commas      }
         If not PrintOut(Str64, 5) then Goto EndPrint;
         OutString := '%';
         If not PrintOut(OutString, 0) then Goto EndPrint;


         { Figure call percentage and print it }
         If (ptrSampleCount^[j].SubCount > 0) and (TotalSampleCounts > 0) Then
            { We'll use big math to accomodate LongInt overflow }
            Begin
            mResult := Mult64(ptrSampleCount^[j].SubCount, 100, Temp64);
            mResult := Div64(Temp64, TotalSampleCounts);
            If mResult > 0 Then
               mResult := Mult64(0, 0, Temp64)
               {Percentage := 0}            { Division error, make Percentage= 0 }
            Else
               Percentage := Byte(Temp64[1]);
            End
         Else
            mResult := Mult64(0, 0, Temp64);
            {Percentage := 0;}
         {Str(Percentage, OutString);}
         Num64toStr(Temp64, Str64, True);    { ..or value w/commas      }
         If not PrintOut(Str64, 7) then Goto EndPrint;
         OutString := '%';
         If not PrintOut(OutString, 0) then Goto EndPrint;


         { Output call count }
         { Convert call count to 64-bit value, put in Temporary result }
         mResult := Mult64(ptrSampleCount^[j].SubCount, 1, Temp64);
         Num64toStr(Temp64, Str64, True);    { Show it w/commas      }
         If not PrintOut(Str64, 14) then Goto EndPrint;



         { Figure average duration and output it }
         { Make sure we don't divide by or into zero }
         If (ptrSampleCount^[j].SubTicks > 0) and(ptrSampleCount^[j].SubCount > 0) Then
            Begin
            { Figure total microseconds -- possible 64-bit value }
            mResult := Mult64(ptrSampleCount^[j].SubTicks, Micrs, Temp64);
            { Divide by the call counts for the average }
            mResult := Div64(Temp64, ptrSampleCount^[j].SubCount);
            If mResult <> 0 Then
               Begin
               OutString := '    Divide error';     { Display problem, if one    }
               If not PrintOut(OutString, 0) then Goto EndPrint;
               End
            Else
               Begin
               Num64toStr(Temp64, Str64, True);    { ..or value w/commas      }
               If not PrintOut(Str64, 20) then Goto EndPrint;
               End;
            End
         Else
            Begin
            OutString := '0';
            If not PrintOut(OutString, 20) then Goto EndPrint;
            End;
      End;

   Inc(j);
   If not PrintOut(CR,0) then Goto EndPrint;    { CR/LF}

   { See if user wants to cancel }
   If Keypressed then
      Begin
      Ch := GetUpKey;
      If Ch = #27 Then Goto EndPrint
      End;
   End;


   { Alert them to buffer overflow, bottom line }
   If SampleBufferOverFlow then
      Begin
      OutString := ' SAMPLE OVERFLOW';
      If not PrintOut(OutString, 0) then Goto EndPrint;
      If not PrintOut(CR,0) then Goto EndPrint;    { CR/LF}
      End;

{ Skip line at bottom }
If not PrintOut(CR, 0) then Goto EndPrint;      { CR/LF}

EndPrint:
   Close(Lst);

End;

End. { PdaProfp Unit }
