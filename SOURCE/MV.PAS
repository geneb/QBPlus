{-------------------------------------------------------------------------
                                    mv

                        Unit to display memory view

                  Written for Borland Turbo Pascal V 6.0

                     Copyright 1991, by John H. Eckert
                           All Rights Reserved


                                                   ... a component of the
                                                   QuickBasic Programmer
                                                   Desk Accessories ...
-------------------------------------------------------------------------}
{ History:           
01/11/91   0.20   Split into mv, mvI and mvHelp units to reduce memory usage.
                  These units are overlays themselves, called by this overlaid
                  unit.
06/24/91   0.95   Windows 386 protection added to memory viewer.
}
{-------------------------------------------------------------------------}
{$F+}                               { Far calls needed for overlays }
{$O+}                               { Unit may be overlaid          }
UNIT mv;


{==========================================================================}
{================================= Interface ==============================}
{==========================================================================}
Interface


Uses Dos, Crt, pdaSubs, XMS, EMS, mvI, mvh;

PROCEDURE ViewMemory;


{==========================================================================}
{============================ Implementation ==============================}
{==========================================================================}
Implementation


{================================= ViewMemory =========================}
{ Displays memory in various modes. Governed by flag settings of DirectView
 (disable Int15 block moves of conventional and extended memory), and
 PortViewEnabled (allow display of values at the I/O ports).  Other display
 choices available w/in the routine.
 External Accesses -  (W means changes data )
      Data:                            Calls:
         Ch          W                       BorderTitlePrompt
         Mode        W                       ClearPrompt
         ShowLinear  W                       ClrScr
         Reg         W                       GetMem
         RealTime    W                       GotoXY
         PortViewEnabled                     WriteHexWord
         EMMThere                            WriteHexByte
         XMThere                             ClrEOL
         DirectView                          ReadKey
         HexStr                              KeyPressed
         HexDigits                           FreeMem
         SBank[]     W                       mvInfo
         GDT         W                       mvHelp
         XMSData     W                       cursor_on
         ptrXMSControl                       cursor_off
         EMMXMData   W
         MaxHunk
         ScrnLines
         AddrMode    W
         BankSize    W
         HunkSizes[]
         OffLimit    W
         BankLimit   W
         SegLimit    W
         SegSize     W
      Also, see data access by called routine mvInfo.
}

PROCEDURE ViewMemory;

Var
IntVal                        : Integer;         { For the Integer view mode }
DisplayBuff                   : LongInt;
ptrDisplayBuff                : Pointer;
SegDisplayBuff                : Word;
OfsDisplayBuff                : Word;
LMemOff, EMemOff              : Word;            { memory Pointer locations }
LMemSeg, EMemSeg              : Word;            { B=begin, L=display line  }
AMemSeg, AMemOff              : Word;            { E=end block, A=actual    }
LBank, EBank                  : Word;            { for 1-meg or E/XMS handle}
SlineBytes, Sline             : Byte;            { current line/line bytes  }
HunkLength                    : Word;            { bytes in one screenful   }
ValidBytes, FirstValidByte    : Word;            { # good bytes in dispbuff }
GoodBytes                     : Word;            { temporary storage above  }
Blanked                       : Boolean;         { flags line already cleard}
AsciiCol                      : Byte;            { start column for ascii   }
AsChr                         : Char;            {<temporary storage used   }
HexStr                        : String4;         {<in receiving/converting  }
HexValStr                     : HexString;       {<keyboard hex string input}
OldMode                       : Byte;            { Last addr mode used      }
E2CResult                     : Byte;            { E2C copy result code     }
LinearByte                    : Byte;            { Hi 8-bits of 24-bit'er   }
LinearWord                    : Word;            { Lo 16-bits of 24-bit'er  }


{ Provide these support routines as local, to give them access to stack vars}

{============================  InputWordHex ================================}
{ Gathers a string of hex digits from the keyboard at the current cursor line
  returning the equivalent binary value.  The first -- up to four -- valid hex
  chars in the input string (HexStr) are used and non-hex chars are ignored.
  Input of all non-hex chars returns zero.  This function operates on the
  global string, HexStr, so as to save 256 bytes of stack otherwise consumed
  if created as a temporary local variable.  }
FUNCTION InputWordHex : Word;
Var
Holder            : Word;
WordHolder        : Word;
i, Shift, CharVal : Byte;

Begin
   { Get a keyboard string containing hex }
   cursor_on;                              
   Readln(HexStr);                  { Provides automatc editing via Crt unit }
   cursor_off;

   {Clean up the input line after us }
   GotoXY(1, WhereY);
   ClrEOL;

   { Initialize the place to build our word }
   WordHolder := 0;
   { and multiplier for each nibble position }
   Shift := 0;

   { Read back from end of string, increasing our target word value by the
   amount of each valid hex char in the string, according to its position.
   If more than 4 valid hex digits in the string, overwriting from the right
   cause the first 4 valid hex chars to remain in the result. }
   For i := Length(HexStr) Downto 1 Do
      Begin
      HexStr[i] := UpCase(HexStr[i]);
      If (HexStr[i] in HexDigits) and (Shift < 5) Then
         Begin
         CharVal := Pos(HexStr[i], HexChar) - 1;
         WordHolder := WordHolder + CharVal Shl (Shift * 4);
         Inc(Shift);
         End;
      End;
   InputWordHex := WordHolder;
End; { InputWordHex }





{============================  WriteHexLong ================================}
{ Prints the hex equivalent of the value passed in the argument, LongNumber.}
PROCEDURE WriteHexLong(LongNumber: LongInt);
Var
WordNumber : Word;
Begin
     WordNumber := LongNumber Shr 16;
     WriteHexByte(Hi(WordNumber));
     WriteHexByte(Lo(WordNumber));
     WordNumber := LongNumber Mod 65536;
     WriteHexByte(Hi(WordNumber));
     WriteHexByte(Lo(WordNumber));
End; { WriteHexWord }





{===========================  WriteHexVector ===============================}
{ Prints the hex equivalent of the value passed in the argument, VectNumber.}
PROCEDURE WriteHexVect(VectNumber: LongInt);
Var
WordNumber : Word;
Begin
     WordNumber := VectNumber Shr 16;
     WriteHexByte(Hi(WordNumber));
     WriteHexByte(Lo(WordNumber));
     Write(':');
     WordNumber := VectNumber Mod 65536;
     WriteHexByte(Hi(WordNumber));
     WriteHexByte(Lo(WordNumber));
End; { WriteHexWord }






{======================== Adjust Memory Pointer =======================}
{ Increments (or decrements if Upward is FALSE) the passed memory pointers
 by the value in Msize, rolling over each of the pointer components at their
 respective sizes, or wrapping them to zero at their respective limits which
 are contained in a series of global variables with values dependant upon
 the type of memory being addressed -- conventional, expanded or extended.}
PROCEDURE AdjustMemPtr( Var MBank : Word;
                        Var MSeg  : Word;
                        Var MOfs  : Word;
                        MSize : Word;
                        Upward : Boolean);
Const
OffSize = $1;


Begin
   If AddrMode = Expanded Then     { Use Bank for Handle, Segment for Page }
      Begin
      { We retrieve the requested EMS handle's page count, and convert
      PageSize (in K) to bytes, so that we can wrap pointers at the handle's
      memory boundaries in this procedure, as well as in the command key
      handlers in the main program when they change beginning segment and
      bank values. }
      OffLimit  := PageSize * 1024 - 1;   { Zero-align page size for handle  }
      BankLimit := HandlesTotal - 1;      { Zero-align bank limit            }
      SegSize   := 1;                     { 1 page per offset size           }
      Reg.AX    := $4C00;                 { Get page count for handle        }
      Reg.DX    := MBank;                 { (EMS Handle is in Bank)          }
      Intr($67, Reg);                     { Call EMM driver                  }
      SegLimit  := Reg.BX - 1;            { Zero-align pages for this handle }
      IF Reg.AH <> 0 Then SegLimit := 0;  { EMM error, data invalid          }
      End
   Else             { Setup values for Conventional, Linear, and most of XMS }
       Begin
       OffLimit  :=$FFFF;
       BankLimit := $FFFF;
       SegSize   := $1000;
       SegLimit  := $FFFF;
       End;

   { Treat XMS adjustments in extended memory as 32-bit address } 
   If (MBank > 0) and (AddrMode = XMSDrv) then SegSize := $1;

   { The Bank value in conventional memory is always 0 }
   If AddrMode > Conventional then BankSize := 1 Else BankSize := 0;


   { Do upward adjust and rollover/wrap }
   If  Upward Then
    Begin
    If OffLimit - MOfs <= MSize Then
       Begin
       MOfs := 0;
       If MSeg >= SegLimit + 1 - SegSize Then
          Begin
          MSeg := 0;
          {If Extended Then MSeg}
          If MBank > BankLimit - BankSize Then
             MBank := 0
          Else                                     
             Inc(MBank, BankSize);
          End
       Else
           Inc(MSeg, SegSize);
       End
    Else
       Inc(MOfs, MSize);
    End

    { Adjust downward with wrap back at zero }
    Else
       Begin
          If MSize > MOfs Then
             Begin
             MOfs := OffLimit + 1; {wrap ofs}
             If MSeg = 0 Then
                begin
                { Adjust the Bank, wrapping/rolling as needed }
                IF MBank = 0 Then
                   Begin
                   MBank := BankLimit + 1 - BankSize;
                   End
                Else
                    Dec(MBank, BankSize);
                MSeg := SegLimit + 1 - SegSize;  { Wrap/Roll the Seg-Page }
                { Need to set to last page of prev EMS handle }
                If AddrMode = Expanded Then
                   Begin
                   Reg.AX := $4C00;     { Get page count for handle       }
                   Reg.DX := MBank;     { (EMS Handle is in Bank)         }
                   Intr($67, Reg);      { Call EMM driver                 }
                   MSeg   := Reg.BX - 1;{ Zero-align pages for this handle}
                   If Reg.AH <> 0 Then MSeg := 0;        { Empty handle   }
                   End;
                end { MSeg = 0 }
             else
                Dec(MSeg, SegSize);              { MSeg > 0, no wrap needed }
             End;
          
       Dec(MOfs, MSize);
       End;

End; { AdjustMemPtr }





{=============================== SwapAddr =============================}
{ Exchanges save area values with current values of beginning address
  pointers.  Called at each switch to and from EMS/XMS to provide separate
  "address bookmarks" for each address mode. }
PROCEDURE SwapAddr(OldMode : Byte);

Begin

{ Save current mode's beginning address display pointers}
SBank[ OldMode ]   := BBank;  
SMemSeg[ OldMode ] := BMemSeg;
SMemOff[ OldMode ] := BMemOff;

{ Load stored pointers for next mode }
BBank   := SBank[ AddrMode ];
BMemSeg := SMemSeg[ AddrMode ];
BMemOff := SMemOff[ AddrMode ];

End; { SwapAddr }






{================================= Linearize =============================
Convert an address in segment-offset-megabyte block style to a 24-bit linear
address returned as a word containing the low order 16 bits and a byte with
the high order 8 bits. }
PROCEDURE Linearize( BBank, BMemSeg, BMemOff : Word; 
                      var HiByte : Byte;
                      var BaseWord : Word);
Var
lTemp : Longint;

Begin

lTemp    := LongInt(BMemSeg) * 16 + BMemOff;  { Seg:Off to 20 bits  }  
HiByte   := BBank SHL 4;                      { Bank to bits 21-24  }
HiByte   := HiByte or (lTemp Div 65536);      { Shift in bits 17-20 }
BaseWord := lTemp Mod 65536;                  { Put 1-16 in a word. }

End; { Linearize }





{ =============================== CopyEtoC ==============================
  Copies a block from extended or expanded memory to conventional memory,
  using one of three methods, Int15h/87h, EMS transfer, or XMS transfer,
  depending upon the address mode, Real/Linear, Expanded, or XMS,
  respectively in effect. In EMS and XMS, BBank refers to a handle.  For
  EMS, BMemSeg and BMemOff refer to Page and Offset within page; for XMS,
  they represent a standard segment/offset pair to be linearized into a
  32-bit offset within a handle's XMS block.}
FUNCTION CopyEtoC(BBank, BMemSeg, BMemOff, HunkLength, AMemSeg, AMemOff:Word):Byte;

Var                        
EMMResult                  : Byte;       { EMM return code         }

XMBlockEnd                 : LongInt;
XMResult, XMSCode          : Byte;
SegGDT, OfsGDT             : Word;
OfsXMSData, SegXMSData     : Word;
BytesAvail                 : Word;            

Begin
IF AddrMode = Linear Then              { Do the Int15h transfer }
Begin
With GDT Do
     Begin
     { Initialize our Global Descriptor Table }      
     For i := 0 to 7 Do                              { Init arrays to 0    }
         Dummy[i] := 0;
     BiosCode := Dummy;
     BiosStack := Dummy;
     GDTSeg := Dummy;                                { Now others to 0     }
     SourceReserved := 0;
     TargetReserved := 0;
     SourceRights := $93;                            { Access rights are   }
     TargetRights := $93;                            { always $93.         }
     SourceSegLimit := $FFFF;                        { Standard segment    }
     TargetSegLimit := $FFFF;                        { size.
     { Now our specific address locations }
     { We need to convert our bank value which represents a multiple of 1 Meg}
     { along with the Segment and Offset words into a 24 bit address, then   }
     { split the high 8 bits off into a separate byte we can position into   }
     { the GDT in the correct order for a 24 bit linear address. }
     Linearize(BBank, BMemSeg, BMemOff, SourceBank, SourceSegOff);
     Linearize(0, AMemSeg, AMemOff, TargetBank, TargetSegOff);

     { Now call Int 15h for the move }
     Reg.AX := $8700;                                { - BIOS Move Ext. -  }
     Reg.CX := HunkLength Div 2;                     { Words to be moved   }
     Reg.ES := Seg(GDT);                             { ES:SI points to our }
     Reg.SI := Ofs(GDT);                             { GDT.                }
     Intr($15, Reg);  
     CopyEtoC  := Reg.AH;
     End; { With GDT}
End  { Extended Int 15 transfer }

Else if AddrMode = XMSDrv then
   { Handle 0 is conventional memory, and XMS offset for this is the    }
   { standard Seg:Off pair, rather than a 32-bit linear address.        }
   { Instead of adding more code to do both methods, just deal with     }
   { transferring extended memory handle blocks, since we can see       }
   { conventional memory directly. So, don't come here w/XMS & BBank=0, }
   { 'cause you'll get no bytes xferred and ValidBytes will say 0.      }
   Begin
   With XMSXData Do
     Begin
     { Get number of bytes available to transfer }
     If BBank = 0 Then          { Source is conventional memory; we're  }
        ValidBytes := 0         { not set to do this, return zero bytes }

     Else                                 { Source is extended memory   }
        Begin                             { Validate the handle and get }
(*      Write('About to check handle ',BBank,' size.  Press key...');
        Ch := GetKey; Ch := #0;*)
        asm                               { it's allocated block size.  }
           mov ax, $0E00;                 { -Get handle info function-  }
           mov dx, BBank;                 { for the requested handle    }
           call [ptrXMSControl];
           mov XMResult, al;              { 1 if ok, 0 if not, with the }
           mov XMSCode, bl;               { error in BL                 }
           mov BytesAvail, dx;            { or handle's block length (K)}
        end;
        { Handle invalid; thus, so too are the display bytes }
        If XMResult = 0 then
            ValidBytes := 0
        { Constrain bytes requested to those available   }
        Else
            Begin
            { Convert block's end in K to bytes }
            XMBlockEnd    := LongInt(BytesAvail) * 1024;
            { Convert seg:off to 32-bit linear }
            SourceOffset  := LongInt(BMemSeg) shl 16 + BMemOff;
            { Compare start of transfer block to end of handle's block }
            If SourceOffset >= XMBlockEnd Then
               { Past end of block, nothing to xfer }
               ValidBytes := 0
            Else
                Begin
                If (XMBlockEnd - SourceOffset) < HunkLength Then
                   { Less than requested available, so reduce request }
                   ValidBytes := XMBlockEnd - SourceOffset
                Else
                    ValidBytes := HunkLength;
                End;
            End;
        End;

     If ValidBytes > 0 then 
     { Call XMS function $0B to copy a block of memory to our display buffer
       area. Call the XMSControl entry point, with AH := $0B, and DS:SI
       pointing at XMSXData structure.  Handle values of 0 refer to
       conventional memory, with corresponding offsets treated as Segment:
       Offset pairs, otherwise offsets are 32-bit addresses.  If source
       and destination blocks overlap in conventional memory, only those
       moves where destination is higher than source are guaranteed to work
       properly. We avoid this by refusing source handle of zero. }
          Begin
          SourceHandle  := BBank;                    { Always in extended  }
          DestHandle    := 0;                        { Always in conv.     }
          DestOffset    := (LongInt(AMemSeg) shl 16) + AMemOff;
          Length        := ValidBytes;               { Must be even #.     }
          OfsXMSData    := Ofs(XMSXData);            { Make ptr for XMS.   }
          SegXMSData    := Seg(XMSXData);            { Seg be in DSeg.     }
(*        Writeln;
          Writeln('Status prior to memory move ...');
          Writeln('ValidBytes = ',ValidBytes);
          Writeln('HunkLength = ', HunkLength);
          Writeln('BytesAvail = ', BytesAvail);
          Writeln('XMResult   = ', XMResult);
          Writeln('XMSCode    = ', XMSCode);
          Writeln('XMBlockEnd = ', XMBlockEnd);
          Writeln('SourceHandle= ', SourceHandle);
          Writeln('SourceOffset= ', SourceOffset);
          Writeln('DestHandle  = ', DestHandle);
          Writeln('DestOffset  = ', DestOffset);
          Writeln('Length      = ', Length);
          Writeln('SegXMSData  = ', SegXMSData);
          Writeln('OfsXMSData  = ', OfsXMSData);
          Write('Press key for move...');
          Ch := GetKey; Ch := #0;
*)
          asm
             mov AH, $0B;                   { - MoveExtended function -  }
             mov si, OfsXMSData;            { ds:si points to xfer parms }
             call [ptrXMSControl];          { Put ofs in si, ds has Seg  }
             mov XMResult, AL;              { 0 means error; 1 = ok      }
             mov XMSCode, BL;               { Recover any error code     }
          end;
(*        Writeln;
          Writeln('XMResult = ', XMResult, 'XMSCode = ', XMSCode);
          Write('Press a key for display ...');
          Ch := GetKey; Ch := #0;*)
          End; { Transferring bytes }

     { Convert XMS return code to "0 = OK else Error code > 0" so as to be
       consistent with Int15h and EMS result convention.   }
     If XMResult = 0 then
        CopyEtoC := XMSCode
     Else
         CopyEtoC := 0;
     End; { with XMSXData }
   End { XMS transfer }


Else
    Begin
    With EMMXMData Do
         Begin
         TargetSeg      := AMemSeg;           { Our display buffer addr   }
         TargetOffset   := AMemOff;           {        ""   ""            }
         TargetHandle   := 0;                 { Always 0 for conventional }
         TargetMemType  := 0;                 {        ""    ""           }
         SourcePage     := BMemSeg;           { Pass requested bank, seg  }
         SourceOffset   := BMemOff;           { and ofs start as handle,  }
         SourceHandle   := BBank;             { page and ofs of EMS.      }
         SourceMemType  := 1;                 { Always 1. That's EMS.     }
         HunkLen        := HunkLength;        { EMS bytes to transfer.    }

         IF HunkLength > 0 THEN           { Don't move if nothing to move }
            { Call Int 67h for move, pointing to our EMMXMData struc. }
            Begin
            Reg.AX := $5700;
            Reg.SI := Ofs(HunkLen);          { First member of EMMXMData.  }
            Reg.DS := DSeg;                  { DS used in call, thus don't }
            Intr($67, Reg);                  { make EMMXMData a stack var. }
            CopyEtoC := Reg.AH;
            End
         Else                                { Nothing to transfer, so we  }
            CopyEtoC := 0;                   { report success, of course.  }

         End; {With EMMXMData}
    End; { Expanded transfer}
End; { CopyEtoC }






{ ===========  MAIN ROUTINE BEGINS HERE  ============== }
Begin

{ Set up our title and prompts.  We define this text as literal so it is
placed in the code segment, and thus swapped out of memory with its overlay
rather than take up permanent space in the data segment. }
Title    := ' Memory Viewer ';
Prompt   := ' F1=Help  F3=Inf  Mode=BWLVAIPCR View='+#27#26#24#25+'PgUpDn<>H Seg Ofs  Esc=Exit ';

BorderTitlePrompt(Title,       { Show border, title and prompt.}
                  Prompt);
ClrScr;

{ Grab some heap space for our display buffer. We copy extended/expanded
memory data here because it is easier to display from conventional memory. }
GetMem(ptrDisplayBuff, MaxHunk);             { Get enough for largest block}
DisplayBuff := LongInt(ptrDisplayBuff);      { Cast pointer to a long so we}
SegDisplayBuff := DisplayBuff shr 16;        { can calculate segment and   }
OfsDisplayBuff := DisplayBuff and $0000FFFF; { offset words for Mem[].     }


{ This is the memory view loop. }
Repeat

{ Clear keypress character }
Ch := #0;

{ Set up memory block size and line length for given mode }
SLineBytes := BytesPerLine[Mode];
HunkLength := HunkSizes[Mode];

{ Set End pointers to end of target memory block }
EMemSeg := BMemSeg;                     { Set end pointers first to }
EMemOff := BMemOff;                     { the start of target block }
EBank   := BBank;                       { so adjust w/rollover works}
{ Now adjust end pointers upward with rollover as needed }
AdjustMemPtr(EBank, EMemSeg, EMemOff, HunkLength, True);

{ Set display line pointers to beginning of target memory block }
LMemSeg := BMemSeg;
LMemOff := BMemOff;
LBank   := BBank;

{ Set address pointers to memory block to display } 
If (AddrMode = Conventional) Then
      Begin                                { We display from the actual  }
      AMemSeg := LMemSeg;                  { memory address when showing }
      AMemOff := LMemOff;                  { conventional memory.        }
      ValidBytes := HunkLength;            { All of the data in the      }
      FirstValidByte := 0;                 { display area is thus valid. }
      End
Else
   Begin
   AMemSeg := SegDisplayBuff;             { Extended/Expanded memory    }
   AMemOff := OfsDisplayBuff;             { is copied to a display area }
   ValidBytes := HunkLength;              { Assume the data in the      }
   FirstValidByte := 0;                   { display area will be valid. }
   ValidBytes := HunkLength;

   { Attempt to copy }
   E2CResult := CopyEtoC(BBank, BMemSeg, BMemOff, HunkLength, AMemSeg, AMemOff);
   IF (E2CResult > 1) Then              { Failed for some reason...   }
      ValidBytes := 0;                  { This keeps invalid data off }
   End;

{ Here's the special case of split display of two different EMS handle areas.
  This requires two moves, with the additional complication that the addresses
  in either or both handle areas are out of the range of allocated memory.
  Thus we need to set a pointer to what's good and what's not good data in
  our display buffer area.}
If (BBank <> EBank) Then
   Begin
   { Get fragment at top of first handle area }
   GoodBytes := (OffLimit - BMemOff) + 1;{ Watch: assumes EMS size is current}
   E2CResult := CopyEtoC(BBank, BMemSeg, BMemOff, GoodBytes, AMemSeg, AMemOff);
   IF E2CResult <> 0 Then               { First part no good, so set start of}
      FirstValidByte := GoodBytes;      { valid data to point past its area  }
   { Now go for bottom of next handle }
   E2CResult := CopyEtoC(EBank, 0, 0, HunkLength - GoodBytes,
                                AMemSeg, AMemOff + GoodBytes);
   IF E2CResult <> 0 Then               { Second no good, so set valid bytes }
      ValidBytes := GoodBytes - FirstValidByte   { to count in first part    }
   Else                                          { Otherwise, add upper part }
      ValidBytes := HunkLength - FirstValidByte; { to lower part.            }
                    
   End;

{ Display a screenful of lines }
GotoXY( 1, 1 );
For SLine := 1 to ScrnLines Do
    Begin
    GotoXY(1, SLine);

    { Display the address }
    Case Mode of
    MPort,Mcmos : Begin
          { Use the offset for ports/CMOS }
          Write(' ');
          WriteHexWord(LMemOff);
          Write(' ³ ');
          End;
    MByte .. MInteger: Begin
          If ShowLinear and (AddrMode = Linear) Then
             Begin
             Linearize(LBank,LMemSeg,LMemOff, LinearByte, LinearWord);
             WriteHexByte(LinearByte);
             WriteHexWord(LinearWord);
             End
          Else
              Begin
              WriteHexWord(LBank);
              Write('³');
              If AddrMode = XMSDrv Then
                 If BBank > 0 Then                { XMS is a 32-bit offset }
                    WriteHexLong(LongInt(LMemSeg) shl 16 + LMemOff)
                 Else                             { except in conventional }
                    WriteHexLong(LongInt(LMemSeg) * 16 + LMemOff)
              Else
                  Begin
                  WriteHexWord(LMemSeg);
                  Write(':');
                  WriteHexWord(LMemOff);
                  End;
              End;
          Write('º ');
          End;
    End; { Case }

    { Store column of Ascii part of display }
    If Mode = MByte Then
       AsciiCol := WhereX + 35
    else
       AsciiCol := WhereX;

    Blanked := False;
    If (SLine * BytesPerLine[Mode]) <= FirstValidByte Then
       ClrEol               { Bypass invalid data in display buffer        }
    Else
    Begin
    { Display numeric stuff in format depending on mode }
    For i := 0 to SLineBytes - 1 Do
        Begin
        If (Not Blanked) Then
           If (i >= ValidBytes) Then
           Begin ClrEOL; Blanked := True; End Else
           Begin
           Case Mode of
           MByte : Begin { Byte format }
                   {If Odd(i) then
                     Begin
                     HighVideo;
                     WriteHexByte(Mem[AMemSeg:AMemOff + i]);
                     LowVideo;
                     End
                   Else }
                     WriteHexByte(Mem[AMemSeg:AMemOff + i]);
                   If i = 7 then Write(' ');
                   End;
           MWord : Begin  { Word format }
                   WriteHexWord(MemW[AMemSeg:AMemOff + i]);
                   Inc(i);
                   Write(' ');
                   End;
           MLong : Begin  { Long format }
                   WriteHexLong(MemL[AMemSeg:AMemOff + i]);
                   Inc(i,3);
                   Write(' ');
                   End;
           MVect : Begin { Far Vector format }
                   WriteHexVect(MemL[AMemSeg:AMemOff + i]);
                   Inc(i,3);
                   Write(' ');
                   End;
           MInteger : Begin  { Integer format }
                   IntVal := MemW[AMemSeg:AMemOff + i];
                   Write(IntVal:7);
                   Inc(i);
                   {Write(' '); }
                   End;
           MPort : Begin  { Port format }
                   WriteHexByte(Port[LMemOff + i]);
                   If (i + 1) mod 4 = 0 then Write(' ');
                   Write(' ');
                   End;
           Mcmos : Begin  { cmos format }
                   { Tell port $70 which register we want} 
                   Port[$70] := Lo(LMemOff + i);
                   { Now retrieve the value from Port $71 }
                   WriteHexByte(Port[$71]);
                   If (i + 1) mod 4 = 0 then Write(' ');
                   Write(' ');
                   End;
           End;  { Case }
           End;
        End;
        Write(' ');

        { Now display ASCII stuff for certain modes }
        Case Mode of
        MAscii, MByte :   { Full ascii and ascii portion of byte mode }
                Begin
                GotoXY(AsciiCol, WhereY);
                Blanked :=  False;
                For i := 0 to SLineBytes - 1 Do
                    Begin
                    If (Not Blanked) Then
                       If (i >= ValidBytes) Then
                          Begin ClrEOL; Blanked := True; End Else
                    Begin
                    AsChr := Chr(Mem[AMemSeg:AMemOff + i]);
                    If AsChr < #32 Then AsChr := '.';   { Ctrl chars }
                    Write(AsChr);
                    End;
                    End;
                End;
        End; { Case }
        If ValidBytes > SlineBytes Then
           Dec(ValidBytes, SlineBytes) Else ValidBytes := 0;
        End;
    { Advance screen line and display address memory offset pointers,
      rolling over to the next Segment and Bank as necessary  }
      AdjustMemPtr(LBank, LMemSeg, LMemOff, SlineBytes, True);
      AdjustMemPtr(LBank, AMemSeg, AMemOff, SlineBytes, True);
      End;

    { Show the mode name on bottom line }
    GotoXY(1, SLine + 1);
    {Writeln; }
    If (Mode = Mcmos) or (Mode = MPort) Then { Skip these addrs headings }
    Else
    Begin
    If AddrMode = Expanded Then                         { Do other Address Headings }
       Begin
       Write('Hndl³Page:Ofstº EMS ');
       Reg.AX := $5300;
       Reg.DX := BBank;
       Reg.ES := Seg(HandleName);            { incl EMS handle name      }
       Reg.DI := Ofs(HandleName);
       Intr($67, Reg);
       If Reg.AH = 0 Then For i := 1 to 8 do
           If HandleName[i] > #0 then Write(HandleName[i]);
       End
    Else
        If ShowLinear and (AddrMode = Linear) Then
           Write('Linearº ')
        Else If AddrMode = XMSDrv then Write('Hndl³ Offset º XMS')
        Else
            Write('Huge³Sgmt:Ofstº ');
    End;
    ClrEOL;
    Write(' ',ModeNames[Mode],' ');
    If RealTime then Write(' (Real time)');
    ClrEOL;

    
    If (Not RealTime) or (RealTime and KeyPressed) Then
      Begin
      { get keyboard command }
      Ch := ReadKey;
      IF Ch =  Chr(0) THEN    { Special function keys }
         Begin
         Ch := ReadKey;
         CASE  Ch  OF
               F3   : mvInfo;
               F1   : mvHelpScreen;

               PgUp : IF BMemSeg = 0 Then BMemSeg := SegLimit + 1 - SegSize Else DEC( BMemSeg, SegSize);
               PgDn : If BMemSeg = SegLimit + 1 - SegSize Then BMemSeg := 0 Else INC( BMemSeg, SegSize);
               UpArrow :
                    AdjustMemPtr(BBank, BMemSeg, BMemOff, HunkSizes[Mode], False);
               DownArrow : Begin
                    BMemOff := EMemOff;
                    BMemSeg := EMemSeg;
                    BBank   := EBank;
                    End;
               LeftArrow   : AdjustMemPtr(BBank, BMemSeg, BMemOff, BytesPerLine[Mode], False);
               RightArrow  : AdjustMemPtr(BBank, BMemSeg, BMemOff, BytesPerLine[Mode], True);
               HomeKey     : BMemOff := 0;
               EndKey      : BMemOff := OffLimit - HunkSizes[Mode] + 1;
               End; { Case }
         End
      Else { Do regular keys }
      Begin
         Ch := UpCase(Ch);
         CASE  Ch  OF
            '<' ,  ','  : IF BBank = 0 Then BBank := BankLimit + 1 - BankSize Else DEC( BBank, BankSize);
            '>' ,  '.'  : If BBank = BankLimit + 1 - BankSize Then BBank := 0 Else INC( BBank, BankSize);
            ':',   ';'  : Begin ShowLinear := not ShowLinear; ClrScr; End;
            'B'         : Begin Mode := MByte;    ClrScr; End;
            'W'         : Begin Mode := MWord;    ClrScr; End;
            'V'         : Begin Mode := MVect;    ClrScr; End;
            'L'         : Begin Mode := MLong;    ClrScr; End;
            'I'         : Begin Mode := MInteger; ClrScr; End;
            'A'         : Begin Mode := MAscii;   ClrScr; End;
            'P'         : Begin IF PortViewEnabled Then Mode := MPort;
                                 ClrScr; End;
            'C'         : Begin Mode := Mcmos; ClrScr; LMemOff := 0; End;
            'R'         : Begin RealTime := Not RealTime; ClrScr; End;
            'E'         : IF EMMThere Then
                             Begin
                             ClrScr;
                             OldMode := AddrMode;
                             If AddrMode = Expanded then
                                 If DirectView Then
                                    AddrMode := Conventional
                                 Else
                                    AddrMode := Conventional + Ord(XMThere)
                             Else
                                 AddrMode := Expanded;
                             SwapAddr(OldMode);
                             End;
            'X'         : If HimemSys Then
                             Begin
                             ClrScr;
                             OldMode := AddrMode;
                             If AddrMode <> XMSDrv then
                                If (Win386 and NoWin386XMS) Then
                                  Begin
                                  If ShowWin386XMS Then
                                     AddrMode := XMSDrv
                                  Else
                                    AddrMode := OldMode;
                                  End
                                Else
                                  AddrMode := XMSDrv
                             Else
                                If DirectView Then
                                   AddrMode := Conventional
                                Else
                                   AddrMode := Conventional + Ord(XMThere);
                             SwapAddr(OldMode);
                             End;
            'H'         : Begin
                          If AddrMode > Conventional Then
                             Begin
                             GotoXY(1, WhereY);
                             ClrEOL;
                             Write('Enter Huge or Handle value in hex: ');
                             BBank := InputWordHex;
                             End;
                          End;
            'O'         : Begin
                          GotoXY(1, WhereY);
                          ClrEOL;
                          Write('Enter offset value in hex: ');
                          BMemOff := InputWordHex;
                          End;
            'S'         : Begin
                          GotoXY(1, WhereY);
                          ClrEOL;
                          Write('Enter segment value in hex: ');
                          BMemSeg := InputWordHex;
                          End;

            End; { Case }
      End;
      END;

   UNTIL  Ch = Chr(27); { wait for Escape }

FreeMem(ptrDisplayBuff, MaxHunk);
Ch := #0;               { This means we'll stay in the PDA menu, rather than
                          returning directly to QB.  }
End; { View Memory }

End. { mv unit }
