{-------------------------------------------------------------------------
                                    mvI

                 Unit to display memory viewer information

                  Written for Borland Turbo Pascal V 6.0

                     Copyright 1991, by John H. Eckert
                           All Rights Reserved


                                                   ... a component of the
                                                   QuickBasic Programmer
                                                   Desk Accessories ...
-------------------------------------------------------------------------}
{ History:           
01/11/91   0.20   Pulled out of the mv module.
06/17/91   0.94   Use zero length XMS handle to get handle count.
}
{-------------------------------------------------------------------------}
{$F+}                               { Far calls needed for overlays }
{$O+}                               { Unit may be overlaid          }
UNIT mvI;

{ Increased granularity of overlaid units permits reduction in overlay buffer
size, and thereby the resident memory requirements overall.  Thus, we build a
separate overlay unit to display memory information. This one shows
conventional memory usage in a left-hand box, and extended and expanded
memory in a right-hand box (if extended and expanded memory on board with
appropriate drivers.) A second page displays handles of EMS and/or XMS in use.
}

{==========================================================================}
{================================= Interface ==============================}
{==========================================================================}
INTERFACE


USES Crt, Dos, pdaSubs, XMS, EMS;

PROCEDURE mvInfo;                 { Only one public procedure        }


{==========================================================================}
{============================ Implementation ==============================}
{==========================================================================}

IMPLEMENTATION

{ =============================== mvInfo ==============================
  Displays information on Conventional, Expanded and Extended memory.  }
PROCEDURE mvInfo;

Type
HardwareConfigT = Record                           { LIM Function 26 struc.}
                 raw_page_size      : Word;
                 alternate_reg_sets : Word;
                 save_area_size     : Word;
                 DMA_reg_set        : Word;
                 DMA_channel_op     : Word;
                 End;


Var
Ech                        : Char;              { our input character   }

{ Used by the conventional memory parts }
DOSmem, QBLength           : LongInt;
QBMCBe, QBMCBc, QBPrefixSeg: Word;

{ Used by Expanded and Extended routines }
EXBoth                     : Boolean;
EMMResult,XMResult         : Byte;
RawFree, RawCount          : Word;
RawPageK                   : Byte;
HardwareConfig             : HardwareConfigT;
XMSize, XMFree             : Word;
GeneralInfo, HMAStatus     : Byte;
XMHandle, BytesK           : Word;

Begin
{ Set up for the display, putting a box in left half of screen.  }
ClrScr;
Box(2, 1, 34, 17);                                      { Make box          }
Window( ULCol + 2, ULRow, LLCol - 38, LLRow );          { Column left info  }

{ Do regular memory stuff }
Writeln;
Writeln('ÄÄÄÄÄ Conventional Memory ÄÄÄÄÄ');

Writeln;
{ Display the dos memory installed }
Intr($12, Reg);
DOSmem := LongInt(Reg.AX) * 1024;
Writeln('DOS memory (bytes)      ',DOSMem :7);

{ Display the dos memory available }
Reg.AX := $4800;
Reg.BX := $FFFF;
Intr($21, Reg);
DOSmem := LongInt(Reg.BX) * 16;
Writeln('DOS memory available    ',DOSMem :7);
Writeln;

{ Do info on our locations, so user can sort our chaff from his wheat }
{ Get the length of our MCB as our approximate memory usage }
Write('Memory Viewer length     ');
Write((MemW[PrefixSeg - 1: 3]) shl 4:6);

{ Show where we start }
Write('   Starting segment        ');
WriteHexWord(PrefixSeg);
Writeln('h');
(*
{ Give transfer buffer length }
Write('View Buffer length        ');
Writeln(MaxHunk:5);

{ and our transfer buffer area location }
Write('  Address            ');
WriteHexWord(Seg(DisplayBuff));
Write(':');
WriteHexWord(Ofs(DisplayBuff));
Writeln('h');
Writeln;
*)
{ Save screen storage length }
Write('Screen save area size     ');
Writeln(3520:5);

{ Save screen address }
Write('  Address            ');
WriteHexWord(ScreenStoreAddress shr 16); Write(':');
WriteHexWord(ScreenStoreAddress mod 65536);
Writeln('h');

Writeln;                            { Skip line }

{ Get QB's environment block and code block and PrefixSeg}
QBMCBe := PrefixSeg + MemW[PrefixSeg - 1: 3];
QBMCBc := QBMCBe + MemW[QBMCBe: 3] + 1;
QBPrefixSeg := QBMCBc + 1;
QBLength := LongInt(MemW[QBMCBc: 3]) shl 4;

Write('QB Environment MCB        '); WriteHexWord(QBMCBe); Writeln('h');
Write('QB code MCB               '); WriteHexWord(QBMCBc); Writeln('h');
Write('QB PSP segment            '); WriteHexWord(QBPrefixSeg); Writeln('h');
Write('QB data segment           '); WriteHexWord(QBds); Writeln('h');
Writeln('QB MCB length           ', QBLength :7);


{ Do expanded memory stuff in a box on the right side.}
Window( ULCol + 37, ULRow, LLCol, LLRow );          { Column right box   }
Box(1, 1, 34, 17);                                  { Make box           }
Window( ULCol + 38, ULRow, LLCol, LLRow );          { Column right info  }

{ If this machine has both an XMS and an EMS driver installed (like QEMM), we
 abbreviate the information to fit both EMS and XMS within the screen box.  }
If EMMThere and HimemSys then EXBoth := True Else EXBoth := False;
If not EXBoth then Writeln;
Writeln('ÄÄÄÄÄÄÄ Expanded Memory ÄÄÄÄÄÄÄ');

{ Tell them if we have no expanded memory }
If Not EMMThere then
   Begin
   Writeln('No expanded memory accessible.');
   End
Else
    Begin
    {Reduce EMS driver version by a factor of 10, and display it as a real.
    Use DIV and MOD integer operations to keep floating point routines from
    being incorporated into the EXE -- saves 2K. }
    Writeln('EMM Driver Version         ',EMMVer Div 10 :2, '.', EMMVer MOD 10);

    { Now get page frame address }
    Reg.AX    := $4100;
    Intr($67, Reg);
    PageFrame := Reg.BX;

    { Get hardware congiguration data. It contains raw page size. }
    Reg.AX := $5900;
    Reg.ES := Seg(HardwareConfig);
    Reg.DI := Ofs(HardwareConfig);
    Intr($67, Reg);
    RawPageK := HardwareConfig.raw_page_size * 16 Div 1024;

    { Get more hardware configuration data - raw page stuff }
    Reg.AX   := $5901;
    Intr($67, Reg);
    RawCount := Reg.DX;
    RawFree  := Reg.BX;

    { -- Display the EMS info -- }
    Write  ('Page frame segment         '); WriteHexWord(PageFrame); Writeln;

    { We show them the raw page size and counts; beyond that it's up to
      them.  We assume (as does most software) a standard page size of 16K in
      this version of our viewer, meaning that funny things will happen if
      an application has set up the EMS driver to use a different page size-
      data in handles using a non-standard page size may not display
      reliably, or at all. }
    Writeln('Standard page size          16K');
    Writeln('Raw page size              ',  RawPageK:3,'K');

    Writeln('              Allocated   Total');
    Writeln('Standard Pages  - ',PagesTotal - FreePgs:5,'   ',PagesTotal:5);
    Writeln('   Bytes (K)    - ',(PagesTotal - FreePgs) * PageSize:5,'   ',PagesTotal * PageSize:5);
    If not EXBoth then
       begin
       Writeln('Raw pages       - ',RawCount - RawFree:5,'   ',RawCount:5);
       Writeln('   Bytes (K)    - ',((RawCount - RawFree) * RawPageK):5,
                                      '   ',RawCount * RawPageK:5);
       End;
    Writeln('Handles         - ',HandlesUsed:5,'   ',HandlesTotal:5);
    End;

If not EXBoth then Writeln;                                 { Skip a line }

{ Next do Extended Memory Info }
Writeln('ÄÄÄÄÄÄÄ Extended Memory ÄÄÄÄÄÄÄ');

If not XMThere then
   Writeln('No extended memory found.')
Else
    Begin
    Writeln('Total extended memory is ',TotalXM:5,'K');
    Writeln('Total directly available ',Int15Avail:5,'K');
    If HimemSys Then
       begin
       { Here we give the XMS specification version that the XMS driver
        is written for, and then the specific internal version of this driver}
       Write('XMS spec/version  ',Hi(XMMVer):2,'.');
       WriteHexByte(Lo(XMMVer)); Write(' / ',Hi(HimemVer):2,'.');
       WriteHexByte(Lo(HimemVer)); Writeln;

       { Get XMS free memory, in K }
       { Himem.sys provides function $08 to obtain free memory sizes,   }
       { but no function to return the number of free handles unless    }
       { info is requested using a valid handle. Since we don't know any}
       { previously allocated handle, we request one of our own, get the}
       { free handle count, then release our handle.                    }
       asm                                   
          mov AH, $08;                       { - QueryFreeExtendedMem.- }
          call [ptrXMSControl];              
          mov XMFree, AX;                    { AX is largest free block }
          mov XMSize, DX;                    { DX is total free memory  }
                                             {  - Get XMS handles -     }
          mov AH, $09;                       { Request a block          }
          mov DX, 0;                         { one K-byte long          }
          call [ptrXMSControl];              { Returns handle in DX     }
          push DX;                           { Save it                  }
          mov AH, $0E;                       { - Get Handle info -      }
          call [ptrXMSControl];              
          mov EMMResult, AL;                 { 1 if ok, 0 if not ok     }
          mov GeneralInfo, BL;               { BL=handles if al = 1, or }
                                             { BL = $81, VDISK detected }
          mov AH, $0A;                       { Free block               }
          pop DX;                            { that we requested        }
          call [ptrXMSControl];
       end;{asm}                             
      Writeln('Largest XMS free block   ',XMFree:5,'K');
      Writeln('Total XMS available is   ',XMSize:5,'K');
      If EMMResult = 1 Then
         Writeln('XMS handles available     ',GeneralInfo + 1:5)
      Else
         If GeneralInfo = $81 then Writeln('VDISK device installed.');
      end;  { Himem info }
   End;    { Extended info }

   Window( ULCol, ULRow, LLCol, LLRow );       { Restore normal window      }

   { Clear the memory display prompt, put ours up and wait for command }
   ClearPrompt;
   IF HimemSys or EMMThere then                     { Offer handle info      }
      begin
      GotoXY(24,19);
      Write('< Handles >     < Cancel >'#8#8#8#8#8#8);
      end
   Else
      Begin
      GotoXY(34,19);
      Write('< OK >'#8#8#8#8);
      end;                                         { 'H' gets handles      }
   cursor_on;
   Repeat Ech := GetKey Until Ech IN [#27,#13, 'h','H'];
   cursor_off; 
   ClrScr;

 If (UpCase(Ech) = 'H') and (HimemSys or EMMThere) Then
   Begin
   Window( ULCol + 1, ULRow, LLCol - 1, LLRow );      
   GotoXY(22,19); Write('Searching handle list...'); GotoXY(1,1);

   { Display header }
   For i := 1 to 5 do
       Write('Hndle Bytes   ');

   { Display a list of valid EMS handles and lengths }
   If EMMThere Then
      Begin
      For XMHandle := 0 to HandlesTotal do
          Begin
           asm                     
              mov ax, $4C00;                 { - GetHandlePages function - }
              mov dx, XMHandle;              { for the requested handle    }
              int $67;
              mov XMResult, ah;              { 0 if ok, >0 if not, with    }
              mov BytesK, bx;                { handle's pages in bx        }
           end;
           { If Handle valid; show it and bytes }
           If XMResult = 0 then
              Begin
              WriteHexWord(XMHandle);
              If EXBoth then Write('e') Else Write('-');
              { Page size is in K, so the next calc works out to K }
              Write(BytesK * PageSize:5,'K   ');
              End;
          End;
       End; { EMS handles }

   { Display a list of valid XMS handles and lengths }
   If HimemSys Then
      Begin
      { First test for HMA in use.  Try to allocate HMA }
      asm
        mov ax, $0100;                 { - Request HMA Function    - }
        mov dx, $FFFF;                 { Ask for the whole thing     }
        call [ptrXMSControl];
        mov XMResult, al;              { 1 if ok, 0 if not           }
        mov HMAStatus, bl;             { save  condition code        }
      end; { asm }

      If XMResult = 1 Then
      asm
        { Now deallocate for others to use }
        mov ax, $0200;                 { - Release HMA Function    - }
        call [ptrXMSControl];          { Assume success              }
      end; { asm }
      Write('HMA -');

      { If our allocation was successful, HMA works and is not in use, so
        display its size in K }
      If XMResult = 1 then Write(64:5,'K   ');

      { Otherwise show its status }
      Case HMAStatus of
         $91            : Write('in use   ');
         $90, $80       : Write('none     ');
         $81            : Write('VDISK    ');
      End; { case }

      For XMHandle := 1 to 65535 do          { We don't know XMS capacity, }
          Begin                              { so must check all possible. }
           asm                     
              mov ax, $0E00;                 { - GetHandleInfo function -  }
              mov dx, XMHandle;              { for the requested handle    }
              call [ptrXMSControl];
              mov XMResult, al;              { 1 if ok, 0 if not, with the }
              mov BytesK, dx;                { or handle's block length (K)}
           end;
           { If Handle valid; show it and bytes }
           If XMResult > 0 then
              Begin
              WriteHexWord(XMHandle);
              If EXBoth then Write('x') Else Write('-');
              Write(BytesK:5,'K   ');
              End;
          End;
      End; { XMS handles }

   Window( ULCol, ULRow, LLCol, LLRow );           { Restore normal window      }
   GotoXY(1,19); ClrEOL;
   GotoXY(34,19); Write('< OK >'#8#8#8#8); cursor_on;
   Repeat Until GetKey IN [#27,#13]; cursor_off;
   End;   { Showing handles }

BorderTitlePrompt(Title,       { Show border, title and prompt.}
                  Prompt);

ClrScr;

End; { mvInfo }

End.
