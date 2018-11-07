{-------------------------------------------------------------------------

                                    SwapQB

            Unit containing code copy QB to/from XMS, EMS or Disk


                  Written for Borland Turbo Pascal V 6.0
                  -- Contains Version-specific code --

                     Copyright 1991, by John H. Eckert
                           All Rights Reserved


                                                   ... a component of the
                                                   QuickBasic ToolSet ...
-------------------------------------------------------------------------}
{ History:           
12/31/90   1.55   Born as an added function to a pop up memory viewer tool.               
01/03/91   0.10   Restructured to take on a support role in a package of
                  pop up tools called as overlays.  Version number reflects
                  the parent, resident kernel program.  Code to obtain a
                  filename moved to parent/other sibling units.
02/01/91   0.50   Granularity improved by moving these memory swap routines
                  to this separate overlay unit.                  }
{-------------------------------------------------------------------------}
{$F+}
{$O+}                               { Unit may be overlaid          }
UNIT SwapQB;

{ Pass the PSP and length in bytes of the QuickBasic memory image to these
  routines. Provide return variables to receive error condition codes.
  In WheresQB, SwapOutQB also returns the location where QB was placed and
  this value must be passed to SwapInQB to find QB. Be sure the constants
  that WheresQB takes on are defined identically here, and in the calling
  unit(s).

  If QuickBasic cannot be swapped out, the process is canceled and the
  ErrSource and ErrCode return values indicate where and why.  This condition
  is not fatal and the calling routine can back out of the process.  However,
  if the swapped image of QuickBasic cannot be recovered by SwapInQB, the
  situation is fatal.  A return code = 0 in ErrSource indicates success,
  otherwise the value relates to XMS, EMS or DISK and the ErrorCode is the
  error reported by the respective driver. The calling routine should
  terminate the entire program as there will be no operable QuickBasic to
  return to.
}
{==========================================================================}
{================================= Interface ==============================}
{==========================================================================}

INTERFACE


USES Dos, Crt, pdaSubs
   ,XMS, EMS;

PROCEDURE SwapOutQB( var QBPrefixSeg   : Word;
                     var QBLength      : LongInt;
                     var WheresQB      : Byte;
                     var ErrSource     : Byte;
                     var ErrCode       : Byte);

PROCEDURE SwapInQB(  var QBPrefixSeg   : Word;
                     var QBLength      : LongInt;
                     var WheresQB      : Byte;
                     var ErrSource     : Byte;
                     var ErrCode       : Byte);


{==========================================================================}
{============================ Implementation ==============================}
{==========================================================================}
IMPLEMENTATION


{=============================== SwapOutQB ==============================
Copies the conventional memory image of QuickBasic to XMS, EMS or Disk.
That order is followed unless swDiskOnly is set, in which case the copy
target is disk in the file SwapName in the current directory.  If the copy
is successful, the ErrSource is returned = 0 and the storage location of QB
is in WheresQB. Otherwise, if ErrSource > 0 the cause of failure is in
ErrCode and WheresQB is NOWHERE.  Called by Child2.

  External accesses:
      Variables                           Procedure calls
         Reg               W                 GetDir
         HimemSys                            Intr
         ptrXMSControl                       DiskFree
         XMSXData          W                 Assign
         EMMThere                            Rewrite
         EMMXMData         W                 
         IOResult
         swDiskOnly                          
         DosError
         FatalErrorCode    W
         QBSwapName
         XEHandle          W
}

PROCEDURE SwapOutQB( var QBPrefixSeg   : Word;
                     var QBLength      : LongInt;
                     var WheresQB      : Byte;
                     var ErrSource     : Byte;
                     var ErrCode       : Byte);

CONST
NOWHERE = 0;
XMS     = 1;                    { These constants represent places where we }
EMS     = 2;                    { might have swapped QB into.                }
DISK    = 3;


Var
BlockLength, QBBlocks, Block  : Word;        { Temp parms for swapping  }
XENeeded                      : Word;        { EMS/XMS request variables}
XEResult, XEInfo              : Byte;        { EMS/XMS result codes     }
swResult                      : Byte;        { Child/swap result codes  }
OfsXMSData, SegXMSData        : Word;        { Location of XMS parm tbl }
SwapFile                      : File;        { Name for QB's disk image }
ptrQBStart                    : Pointer;     { QB's Memory image start  }
Canceled                      : Boolean;     { 1=unrepairable trouble   }

Begin
{ Init return values }
ErrSource   := NOWHERE;
ErrCode     := 0;
WheresQB    := NOWHERE;

Canceled := False;
{ Enter the XMS/EMS areas only if DiskOnly has not been selected }
IF not swDiskOnly Then
Begin
{ Do save to XMS first, if present }
XEResult := 0;                                  { Assume failure }
If HimemSys Then
  Begin
 { Write('XMS transfer..'); }
  { Get a handle of adequate size }
  XENeeded := (QBLength DIV 1024) + 1; { In K rounded up to have enough }
  asm
   mov ah, $09;                                 { -- Get Handle --      }
   mov dx, XENeeded;                            { K bytes to allocate   }
   call [ptrXMSControl];                        { XMS entry location    }
   mov XEHandle, dx;                            { Here's the handle     }
   mov XEResult, al;                            { 1=ok, 0=problem w/    }
   mov XEInfo, bl;                              { error code in bl      }
  end; {asm}

  If XEResult = 1 Then              { Successful, so try to  save QB    }
     Begin
     With XMSXData Do
     Begin
     SourceOffset  := LongInt(QBPrefixSeg) shl 16;
     SourceHandle  := 0;                        { Conventional        }
     DestHandle    := XEHandle;                 { XMS handle          }
     DestOffset    := 0;                        { Start of XMS handle }
     Length        := QBLength;                 { Must be even #.     }
     OfsXMSData    := Ofs(XMSXData);            { Make ptr for XMS.   }
     SegXMSData    := Seg(XMSXData);            { Seg be in DSeg.     }
     End; { With XMSXData }
     asm
      mov AH, $0B;                        { - MoveExtended function -  }
      mov si, OfsXMSData;                 { ds:si points to xfer parms }
      call [ptrXMSControl];               { Put ofs in si, ds has Seg  }
      mov XEResult, AL;                   { 0 means error; 1 = ok      }
      mov XEInfo, BL;                     { Recover any error code     }
     end; { asm }

     IF XEResult = 1 then
      WheresQB := XMS                     { Leave a signpost to find QB }
     Else                                 { if successful.              }
         Begin
         asm                              { Failed, deallocate the handle  }
            mov ah, $0A;                        { -- Release Handle --  }
            mov dx, XEHandle;                   { passed in dx          }
            call [ptrXMSControl]                { call XMS              }
            mov XEResult, al;                   { 0=error, 1=ok         }
            mov XEInfo, bl;                     { Recover error code    }
         end;
         { If deallocate failed, not much we can do about it; if
          it succeeded, we'll still set results to failure, since we
          want the EMS/Disk save processes to take over QB's swap out. }
         ErrSource   := XMS;
         ErrCode     := XEInfo;
         XEResult    := 0;
         End;
     End; { Transferring bytes }
 { Writeln('done.'); }
  End; { XMS Xfer }




IF (WheresQB = NOWHERE) and (EMMThere) then
   Begin
  { Get a handle of adequate size }
  {Write('EMS transfer..');}
  XENeeded := (QBLength DIV (PageSize * 1024)) + 1;{ rounded up to have enough }
  Reg.ax := $4300;                           { -- Allocate Pages --     }
  Reg.bx := XENeeded;                        { Number  needed           }
  Intr($67, Reg);                            { call EMM                 }
  XEHandle  := Reg.dx;                       { here's the handle if     }
  XEResult := Reg.ah;                        {     no error comes back  }

  If XEResult = 0 then                    { Only do xfer if good handle }
   Begin
   With EMMXMData Do
      Begin
      TargetSeg      := 0;                 { Beginning of EMS handle   }
      TargetOffset   := 0;                 {        ""   ""   page     }
      TargetHandle   := XEHandle;          { page and ofs of EMS.      }
      TargetMemType  := 1;                 { Always 1. That's EMS.     }
      SourcePage     := QBPrefixSeg;       { Pass QB's start location  }
      SourceHandle   := 0;                 { Always 0 for conventional }
      SourceOffset   := 0;                 {        ""    ""           }
      SourceMemType  := 0;                 {        ""    ""           }
      HunkLen        := QBLength;          { bytes to transfer.        }

      { Call Int 67h for move, pointing to our EMMXMData struc. }
      Reg.AX := $5700;
      Reg.SI := Ofs(HunkLen);          { First member of EMMXMData.  }
      Reg.DS := DSeg;                  { DS used in call, thus don't }
      Intr($67, Reg);                  { make EMMXMData a stack var. }
      XEResult := Reg.AH;
      ErrCode  := XEResult;            { Preserve poss problem info  }

      { Face up to success and with failure }
      If XEResult = 0 then             { Worked, so . . .            }
         WheresQB := EMS               { Leave crumb trail to QB     }
      Else
         Begin                         { Didn't work, so .. .        }
         { If xfer failed, deallocate the EMS handle }
         Reg.ax := $4500;                          { -- Release pages-- }
         Reg.dx := XEHandle;                       { the useless handle }
         Intr($67, Reg);                           { Call EMM to do it  }
         XEResult := Reg.ah;                       { 0=ok, else err code}
         ErrSource := EMS;                         { Pass bad news back }
         End;                                      { Now up to next guy }

      End; {With EMMXMData}
   End;  { Allocated handle }
   {Writeln('done.'); }
  End; { Expanded transfer}
End; { not swDiskOnly }





{ A disk swap is our last resort, if XMS and EMS didn't work out,
 or if the swDiskOnly flag is set to True. }
If WheresQB = NOWHERE then
   Begin
 { Write('Disk transfer..'); }
   {---- Check for sufficient space to swap QB into }
   BlockLength := 16384 shr 4;                           { segment terms }
   QBBlocks := QBLength DIV (BlockLength shl 4);         { Count blocks  }
   If DiskFree(0) < QBLength + (BlockLength shl 4) Then
         Begin                                           { message & quit}
         canceled := True;
         ErrCode := DosError;
         If ErrCode = 0 Then
            ErrCode := 8;                  { Dos's insufficient memory code }
         ErrSource := DISK;
         End;  { space/access failure }

   If not canceled then
      Begin
      { Open a file of BlockLength * 16 record lengths }
      Assign(SwapFile, QBSwapName);                      { Open a file   }
      {$I-}Rewrite(SwapFile, BlockLength Shl 4); {$I+}   { w/16K records }
      ErrCode := IOResult;
      If ErrCode <> 0 Then                               { Trouble, give }
         Begin                                           { message & quit}
         canceled := True;
         ErrSource := DISK;
         End  { open failure }
      Else
         Begin
         For Block := 0 to QBBlocks do   { We go for an extra block to catch }
            Begin                         { any trailing fragment of block   }
            If not canceled Then 
               Begin
               ptrQBStart := ptr(QBPrefixSeg + (Block * BlockLength), 0);
               {$I-}BlockWrite(SwapFile, ptrQBStart^, 1);{$I+}
               ErrCode := IOResult;
               If ErrCode <> 0 Then                      { Trouble, give }
                  Begin                                  { message & quit}
                  canceled := True;
                  ErrSource := DISK;
                  End; { if ErrCode }
               End;  { Xferring }
            End; { For Block }
         {$I-}Close(SwapFile);{$I+}
         ErrCode := IOResult;
         If ErrCode <> 0 Then                            { Trouble, give }
            Begin                                        { message & quit}
            canceled := True;
            ErrSource := DISK;
            End; { if ErrCode }
         End;  { else }
      End;  { not canceled }
   If not canceled Then WheresQB := DISK;                { Made it to disk}
   {Writeln('done.');}
   End;  { disk xfer }

End;






{=============================== SwapInQB ==============================
Restores the conventional memory image of QuickBasic from XMS, EMS or Disk,
depending upon the setting in WheresQB. If the copy is successful, the
boolean Canceled is returned False, FatalErrorCode is zero.  Otherwise,
if Canceled is True, the cause of failure is in FatalErrorCode. 
  External accesses:
      Variables                           Procedure calls
         Reg               W                 GetDir
         HimemSys                            Intr
         ptrXMSControl                       DiskFree
         XMSXData          W                 Assign
         EMMThere                            Rewrite
         EMMXMData         W                 
         IOResult
         swDiskOnly                          
         DosError
         FatalErrorCode    W
         QBSwapName

}
PROCEDURE SwapInQB(  var QBPrefixSeg   : Word;
                     var QBLength      : LongInt;
                     var WheresQB      : Byte;
                     var ErrSource     : Byte;
                     var ErrCode       : Byte);

CONST
NOWHERE = 0;
XMS     = 1;                    { These constants represent places where we }
EMS     = 2;                    { might have swapped QB into.                }
DISK    = 3;

Var
BlockLength, QBBlocks, Block  : Word;           { Temp parms for swapping  }
XENeeded                      : Word;           { EMS/XMS request variables}
XEResult, XEInfo              : Byte;           { EMS/XMS result codes     }
OfsXMSData, SegXMSData        : Word;           { Location of XMS parm tbl }
SwapFile                      : File;           { Name for QB's disk image }
ptrQBStart                    : Pointer;        { QB's Memory image start  }
Canceled                      : Boolean;        { 1=unrepairable trouble   }

Begin
{ Init return variables }
ErrSource   := NOWHERE;
ErrCode     := 0;

Canceled    := False;
If WheresQB = XMS Then
   Begin
     With XMSXData Do
     Begin
     SourceOffset  := 0;                           { Start of XMS handle }
     SourceHandle  := XEHandle;                    { XMS handle          }
     DestHandle    := 0;                           { Conventional        }
     DestOffset    := LongInt(QBPrefixSeg) shl 16;     { Where QB belongs}
     Length        := QBLength;                    { Must be even #.     }
     OfsXMSData    := Ofs(XMSXData);               { Make ptr for XMS.   }
     SegXMSData    := Seg(XMSXData);               { Seg be in DSeg.     }
     End; { With XMSXData }
     asm
      mov AH, $0B;                           { - MoveExtended function -  }
      mov si, OfsXMSData;                    { ds:si points to xfer parms }
      call [ptrXMSControl];                  { Put ofs in si, ds has Seg  }
      mov XEResult, AL;                      { 0 means error; 1 = ok      }
      mov XEInfo, BL;                        { Recover any error code     }
     end; { asm }

     IF XEResult = 1 then
      WheresQB := NOWHERE                 { Leave a signpost to find QB    }
     Else                                 { Failed, report fatality        }
      Begin
      ErrCode  := XEInfo;
      ErrSource := XMS;
      End;

     { Deallocate our handle }
     asm
      mov ah, $0A;                                 { -- Release Handle --  }
      mov dx, XEHandle;                            { passed in dx          }
      call [ptrXMSControl]                         { call XMS              }
      mov XEResult, al;                            { 0=error, 1=ok         }
      mov XEInfo, bl;                              { Recover error code    }
     end;

     { If deallocate failed, not much we can do about it. }
     XEResult := 0;
   End; { Transferring XMS bytes }




IF WheresQB = EMS then
   Begin
   With EMMXMData Do
      Begin
      TargetSeg      := QBPrefixSeg;       { Pass QB's start location  }
      TargetHandle   := 0;                 { Always 0 for conventional }
      TargetOffset   := 0;                 {        ""    ""           }
      TargetMemType  := 0;                 {        ""    ""           }
      SourceHandle   := XEHandle;          { page and ofs of EMS.      }
      SourcePage     := 0;                 { Beginning of EMS handle   }
      SourceOffset   := 0;                 {        ""   ""   page     }
      SourceMemType  := 1;                 { Always 1. That's EMS.     }
      HunkLen        := QBLength;          { bytes to transfer.        }

      { Call Int 67h for move, pointing to our EMMXMData struc. }
      Reg.AX := $5700;
      Reg.SI := Ofs(HunkLen);          { First member of EMMXMData.  }
      Reg.DS := DSeg;                  { DS used in call, thus don't }
      Intr($67, Reg);                  { make EMMXMData a stack var. }
      XEResult := Reg.AH;
      End; {With EMMXMData}

      { Face up to success and with failure }
      If XEResult = 0 then
         WheresQB := NOWHERE           { Show QB's no longer in EMS  }
      Else
         Begin
         { If xfer failed, }
         ErrCode := XEResult;             { QB stuck in EMS, show why and  }
         ErrSource := EMS;                { where.                         }
         Canceled := True;                { rest operation called off      }
         End;                             { house is about to collapse    }

      { deallocate the EMS handle }
      Reg.ax := $4500;                          { -- Release pages-- }
      Reg.dx := XEHandle;                       { the useless handle }
      Intr($67, Reg);                           {  Call EMM          }
      XEResult := Reg.ah                        { 0=ok, else err code}
  End; { Expanded transfer back}





If WheresQB = DISK then
   Begin
   BlockLength := 16384 shr 4;                           { segment terms }
   QBBlocks := QBLength DIV (BlockLength shl 4);         { Count blocks  }
   Assign(SwapFile, QBSwapName);
   {$I-}Reset(SwapFile, BlockLength Shl 4); {$I+}
   ErrCode := IOResult;
   If ErrCode <> 0 Then                                  { Trouble, give }
      Begin                                              { message & quit}
      ErrSource := DISK;
      canceled := True;                                                   
      End;
   End;

If (WheresQB = DISK) and (not Canceled) Then
   Begin
   For Block := 0 to QBBlocks do         { We go for an extra block to catch }
      Begin                              { any trailing fragment of block    }
      If not Canceled then
         Begin
         ptrQBStart := ptr(QBPrefixSeg + (Block * BlockLength), 0);
         {$I-}BlockRead(SwapFile, ptrQBStart^, 1); {$I+}
         ErrCode := IOResult;
         If ErrCode <> 0 Then                            { Trouble, give }
            Begin                                          { message & quit}
            ErrSource := DISK;
            canceled := True;             { realizes big trouble is ahead. }
            End;  { fatal read failure }
         End;  { not canceled }
      End; { for block }
   Close(SwapFile);
   Write('QB reloaded');
   WheresQB := NOWHERE;
   Erase(SwapFile);
   End;  { on DISK and not canceled }

End; { SwapInQB }

END. { SwapQB unit }
