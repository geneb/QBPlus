PROGRAM QBP;

{ QBP.PAS is the pop-up Programmers's Desk Accessories for QB/QBX.EXE.  This
  main module calls QB/QBX as a child process, hooks itself into QB/QBX and
  is then serviced by QB/QBX's edit input loop for pop up.  The pop up
  presents a selection menu to various accessories, some built-in as TP
  overlay units, and others as external .EXE files.}

  { Important note: If this program is compiled using a different name,
  the TextLine array in the Subs unit must be changed to reflect the name
  change so that overlays may be found at startup. }

{ Written for QuickPascal  Copyright 1989-90 John Eckert       }
{ Adapted for Turbo Pascal December 1, 1990, John Eckert       }

{-------------------------------------------------------------------------}

{ History:           ( origins were in QuickProfiler )
12/04/89   1.0
02/24/90   1.1    Extract module names from memory as starter set
08/18/90   1.2    Reduce to 25 line screen save; integer array stack for
                  exec call.
09/09/90   1.3    QBX conversion
12/07/90   1.4    Convert to Turbo Pascal - DummyReturn for storage of DSeg
                  at cs:0000; ; use BIOS data area to identify monitor --
                  save bytes.   TP version uses 2.5K less than QP's
                  Cut memory - direct screen buffer, 22x80 screen save, cut
                  ExecStack in half, stack cut
12/26/90   1.5    Move entire set of memory view routines out of profiler and
                  into a separate program (QBMEM); add routines to deal with
                  memory over 1 meg via int15h/87h and/or EMS/XMS drivers;
                  add CMOS and Port viewing code; conditional compilation
                  to produce a small, limited function alternate program;
                  add help screen and clean up code for others to be able to
                  use and maybe understand.
12/27/90   1.51   Add information screen on our program's conventional
                  memory usage; EMS and XMS driver information, and list of
                  allocated EMS and XMS handles.
12/31/90   1.55   Add function to swap QB to XMS, EMS or disk and run a
                  user-specified program.
01/02/91   1.56   Split into units to better support a collection of QB pop
                  up, standalone, and combinations thereof. 
01/03/91   0.10   Unit reorientation of version 1.56 embracing the strategy
                  of a small resident pop up kernel, provokes a shift in
                  function and design.  The modified approach involves
                  overlaid units containing the "tools", one of which is a
                  new swapping tool which instead of being a single function,
                  independent module, now supports both the overlay units and
                  external programs, but yet is an overlay unit itself so as
                  to minimize resident code.
01/11/91  0.20    Units made more granular to reduce overlay buffer size and
                  thus resident memory requirements.
01/15/91  0.30    Macro function added, separate overlaid text line editor.
01/24/91  0.40    Profiler added.
02/01/91  0.50    Child2 segmented into a SwapQB utility unit (granularity)
                  and also pdaprof into pdaprofa, and QBM into QBMV
02/07/91  0.60    Main popup, mouse, screen save/restore and main help screen
                  pulled out of this main PDA module and into an overlaid
                  unit to further reduce resident memory required.
02/10/91  0.70    Load and save disk file configuration settings added to
                  PDACFG unit.
03/18/91  0.71    Make Dos unit an overlay (saves 520 bytes), various minor
                  other corrections.
04/08/91  0.85    Use real time clock in profiling, adding RTC unit.
04/15/91  0.86    Support for QB/X not in current directory.
04/25/91  0.88    Extended integer support for profiler analysis added by
                  incorporation of PDAMath overlay unit.
04/25/91  0.89    Suspend time sampling during recording of call samples
                  to reduce skewing of routine duration calculations.
04/26/91  0.90    Restore above sampling as results with short, repetitively
                  called routines too highly subject to stroboscopic effects.
                  64-bit math incorporated into both time and call profile
                  analysis.
04/29/91   0.91   Creation of profiler print unit.
05/05/91   0.92   Compute program elapsed time in seconds based on samples.
                  Search PDA's path for QB, accomodate space-delimited
                  Parm variable.
05/15/91   0.93   Misc: Eliminate sharing of Call_Int procedure, cut some
                  spaces from text displays, release version conditionals,
                  polish up the profile printer, abolish delete procedure
                  call to save stack in ISR's, allow cancel on config and
                  profiler settings, separate profiler help unit.
06/10/91   0.94   Name change to QB Plus (QBP), with accompanying file,
                  overlay name, and support unit changes.
06/24/91   0.95   Windows 386 protection added to memory viewer.
07/16/91   1.00
09/11/91   1.01   German version QB 4.5 code added. Mouse save during switch.
                  Enable cursor for Child2.
10/05/91   1.02   Recognize source files with non-.BAS extensions.
10/10/91   1.10   Unit created to support console configuration, config file
						structure changed to match.
}
{-------------------------------------------------------------------------}



{$UNDEF NoQB}     { Define NoQB to test just the popup portion of the program
                    with no installation of QB }

{$UNDEF NoInt8}   { Define NoInt8 to test program with no Int 8 interrupt
                     flow coming through the program }

{$F+}                        { Far calls needed for overlays }
{$O+}                        { Support for overlaid units     }
{$S-}                         { Stack checking off }



{$M 3000, 5180, 5180 }        {3.5K heap needed for screen save            }
                              {84*18=1512 heap for module names in QBC, or }
                              {350*4=1400 for profiler count workspace, or }
                              {48*18=864 for memview buffer, or            }



USES
    Overlay, Dos, Crt, pdaInit, pdaSubs, PDAMath,
    XMS, EMS, mv, pdartc,
    Child2, swName, dbgName,QBC, QBCGet, QBM,
    QBMFile, PDACFG, PDAEDLN, PDAProf, PopHelp;



{ Overlay units as follows }
{$O pdaInit}
{$O PDAMath}
{$O pdartc}
{$O PopHelp}
{$O PDACFG}
{$O PDACFGO}
{$O PDACFGC}
{$O PDAEDLN}
{$O XMS}
{$O EMS}
{$O mv}
{$O mvI}
{$O mvh}
{$O Child2}
{$O SwapQB}
{$O swName}
{$O dbgName}
{$O QBC}
{$O QBCGet}
{$O QBCHelp}
{$O QBM}
{$O QBMV}
{$O QBMFile}
{$O QBMHelp}
{$O PDAProf}
{$O PDAProfa}
{$O PDAProfp}
{$O PDAProfh}



{ =======================================================================
  Dummy procedure for storage of our DSeg.
  =======================================================================

 IMPORTANT -- THIS MUST ALWAYS BE THE FIRST DEFINED PROCEDURE SO THAT
 THE TURBO PASCAL COMPILER PLACES IT AT CS:0000 IN THE EXE CODE.
 DO NOT PUT ANY OTHER PROCEDURES AHEAD OF IT, EVEN BY $I.

This empty procedure is called once at the start of the main program to
ensure linking into final module and should never be called again as its
first word is overwritten by storage of our DSeg value by the initialization
code in the main program. Storage of DSeg here in the code segment provides
for access by our ISR's upon entry. }
Procedure DummyReturn;
   Begin

   End; {DummyReturn}

    




{============================ Enable/Disable ===============================
A pair of complementary inline asm macros that the compiler inserts directly
into the executable code to enable and disable processor interrupts at the
point wherever the procedure reference appears in the source code.
}
{ Re-enable interrupts }
PROCEDURE Enable; INLINE( $FB );    { STI }

{ Disable interrupts }
PROCEDURE Disable; INLINE( $FA );    { CLI }






Procedure StuffBuffBIOS(var ArgumentString : String4);
{ Argument string consists of up to 4 keystrokes to be stuffed
into the keyboard buffer.  Extended characters are preceded by a
chr(0) in the ArgumentString. The keyboard is flushed of any
waiting keystrokes by this call, and only the standard key buffer
location is supported -- in fact a call to this routine might
disable other keyboard enhancers. Note that this procedure does
not disable interrupts while stuffing the buffer because it is
only called by ISR's which are operating with rupts off already.
}

Var
   Headptr  : Word Absolute $0000:$041A;
   Tailptr  : Word Absolute $0000:$041C;
   Buffer   : ^String40;
   I        : Byte;

Begin
   If Length(ArgumentString) > 0 Then        { Null string invalid   }
      Begin
      Buffer := Ptr($0000,$041E);            { point at keybd buffer }

      Headptr := $01E;                       { Set head to bottom .. }
      Tailptr := $01E + Length(ArgumentString);    { ..tail to end.  }
                                             { Stuff string          }
      Move(ArgumentString[1], Buffer^, Length(ArgumentString));
      End;
End;  { Stuff BufferBIOS }





{ == STACK CHECKING LIMIT == STACK CHECKING LIMIT == STACK CHECKING LIMIT == }
{$S-} { Turn stack checking off at all times for routines within ISR's
         since we don't do a stack switch; and for this patch code, since
         stack checking is based on our DSeg which is not yet loaded in DS
         at the point where QB sends processing here.}

{ ===========================  CheckHotKey ============================}
{ QB.EXE is patched after being loaded such that its keyboard entry
   loop, while in the editing mode, calls this routine which checks for
   the key combination for the popup options window and calls the
   procedure for it if the hot key is pressed. }
PROCEDURE CheckHotKey;
begin
   INLINE      {  Push the registers, and set BP and DS ... }
   (
   $9C/              { push flags               ; flags := [SP+18]    }
   $50/              { push   ax                ; AX := [SP+16]       }
   $53/              { push   bx                ; BX := [SP+14]       }
   $51/              { push   cx                ; CX := [SP+12]       }
   $52/              { push   dx                ; DX := [SP+10]       }
   $56/              { push   si                ; SI := [SP+8]        }
   $57/              { push   di                ; DI := [SP+6]        }
   $1E/              { push   ds                ; DS := [SP+4]        }
   $06/              { push   es                ; ES := [SP+2]        }
   $2E/$A1/$00/$00/  { mov ax, word ptr cs:[0]  ; Recover our DSeg we }
   $8E/$D8           { mov ds, ax               ; stored at CS:0      }
   );

   { Show profiler we're editing, not running }
   ProgramRunning := False;

   { Test for hotkey combination }
   { Shift - Ctrl or Both Shifts invokes popup screen }
   IF ((PopupKeyOpt = 1) and (ShiftKey and CtrlKey)) or
      ((PopupKeyOpt = 2) and (LShiftKey and RShiftKey)) then
      BEGIN
        { Save current stack of Quickbasic, and set our original stack.
          This is for safety since we don't know the state of the
          Quickbasic stack, but we do know the state of our own stack.
          Turn off interrupts during the stack switch.
        }
        INLINE
            (
            $FA/                { cli                                  }
            $89/$26/offAppStack/{ mov offAppStack, sp ; Save app stack }
            $8C/$16/segAppStack/{ mov segAppStack, ss                  }
            $8B/$26/offTsrStack/{ mov sp, offTsrStack ; Load TSR stack }
            $8E/$16/segTsrStack/{ mov ss, segTsrStack                  }
            $FB                 { sti                                  }
         );

         asm
            mov bp,0;           { End the bp chain on our stack to prevent }
         end;                   { an endless overlay recall loop.          }

      { Exchange Int 3F vectors with QB, so we can do our overlays, and
      exchange 9 and 16 ints so extended keys work correctly in QB 4.5. }
      Disable;
      QB3F := ptrInt3F^;
      ptrInt3F^ := Our3F;
      QB9 := ptrInt9^;
      ptrInt9^ := Our9; 
      QB16 := ptrInt16^;
      ptrInt16^ := Our16; 
      Enable; 

      If not Popped then PopUp;     { Puts our window up over QB and we    }
                                    { do all our visible things from there }

      { Give QB its Ints 3F, 16 and 9 back, now that we're done. }
      Disable;
      ptrInt3F^ := QB3F;
      ptrInt9^ := QB9;
      ptrInt16^ := QB16;
      Enable;

        { Restore QB's stack. }
        INLINE
            (
            $FA/                    { cli                  }
            $8B/$26/offAppStack/    { mov  sp, offAppStack }
            $8E/$16/segAppStack/    { mov  ss, segAppStack }
            $FB                     { sti                  }
            );

      END;


{ Exit by executing version-specific code patched out of QB at our hook. }
Case QBXVer Of
	710: Begin
   INLINE      {  Pop the registers, and return to QBX.EXE 7.1 ... }
   (
   $07/              { pop    es                ; ES := [SP+2]        }
   $1F/              { pop    ds                ; DS := [SP+4]        }
   $5F/              { pop    di                ; DI := [SP+6]        }
   $5E/              { pop    si                ; SI := [SP+8]        }
   $5A/              { pop    dx                ; DX := [SP+10]       }
   $59/              { pop    cx                ; CX := [SP+12]       }
   $5B/              { pop    bx                ; BX := [SP+14]       }
   $58/              { pop    ax                ; AX := [SP+16]       }
   $9D/              { pop    flags             ; Flags := [SP+18]    }
   $5D/              { pop    bp                ; BP := [SP]          }
   $83/$3E/$D6/$30/$00/{ cmp word ptr [30D6],00 ; transplanted QBX code}
   $CB               { ret    FAR               ; return              }
   );
   End;

   700: Begin
   INLINE      {  Pop the registers, and return to QBX.EXE 7.0 ... }
   (
   $07/              { pop    es                ; ES := [SP+2]        }
   $1F/              { pop    ds                ; DS := [SP+4]        }
   $5F/              { pop    di                ; DI := [SP+6]        }
   $5E/              { pop    si                ; SI := [SP+8]        }
   $5A/              { pop    dx                ; DX := [SP+10]       }
   $59/              { pop    cx                ; CX := [SP+12]       }
   $5B/              { pop    bx                ; BX := [SP+14]       }
   $58/              { pop    ax                ; AX := [SP+16]       }
   $9D/              { pop    flags             ; Flags := [SP+18]    }
   $5D/              { pop    bp                ; BP := [SP]          }
   $83/$3E/$1E/$30/$00/{ cmp word ptr [301E],00 ; transplanted QBX code}
   $CB               { ret    FAR               ; return              }
   );
   End;

   451: Begin
   INLINE      {  Pop the registers, and return to QB.EXE ... (German)}
   (
   $07/              { pop    es                ; ES := [SP+2]        }
   $1F/              { pop    ds                ; DS := [SP+4]        }
   $5F/              { pop    di                ; DI := [SP+6]        }
   $5E/              { pop    si                ; SI := [SP+8]        }
   $5A/              { pop    dx                ; DX := [SP+10]       }
   $59/              { pop    cx                ; CX := [SP+12]       }
   $5B/              { pop    bx                ; BX := [SP+14]       }
   $58/              { pop    ax                ; AX := [SP+16]       }
   $9D/              { pop    flags             ; Flags := [SP+18]    }
   $5D/              { pop    bp                ; BP := [SP]          }
   $83/$3E/$BA/$33/$00/{ cmp word ptr [33BA],00 ; transplanted QB code}
   $CB               { ret    FAR               ; return              }
   );
   End;

Else
   Begin
   INLINE      {  Pop the registers, and return to QB.EXE ... }
   (
   $07/              { pop    es                ; ES := [SP+2]        }
   $1F/              { pop    ds                ; DS := [SP+4]        }
   $5F/              { pop    di                ; DI := [SP+6]        }
   $5E/              { pop    si                ; SI := [SP+8]        }
   $5A/              { pop    dx                ; DX := [SP+10]       }
   $59/              { pop    cx                ; CX := [SP+12]       }
   $5B/              { pop    bx                ; BX := [SP+14]       }
   $58/              { pop    ax                ; AX := [SP+16]       }
   $9D/              { pop    flags             ; Flags := [SP+18]    }
   $5D/              { pop    bp                ; BP := [SP]          }
   $83/$3E/$6A/$32/$00/{ cmp word ptr [326A],00 ; transplanted QB code}
   $CB               { ret    FAR               ; return              }
   );
	End;
  End; {Case}
end; { CheckHotKey }




{ ==============================  AddChr ================================}
{ Adds a character to the end of a string, minimizing stack space usage.
  Caller must be ensure the resulting size does not overflow the string's
  allocated maximum length. Called by ISR's that have limited stack space. }
PROCEDURE AddChr(Var CombineString :String82; Var AddCharacter : Char);
Begin
   CombineString[0] := Succ(CombineString[0]);
   CombineString[Ord(CombineString[0])] := AddCharacter;
End;




{ ===========================  GetBasNewline ============================}
{ QB.EXE is patched after being loaded such that this routine is called
   each time a new source line is begun by an executing program.  Its
   function is to enable the program running flag so the sample collection
   code in our_int8/70 captures only valid program data when sampling is
   enabled.  To minimize overhead on the running basic program, only those
   CPU registers actually used in the procedure are saved and restored.  If
   any changes are made to the Pascal code in this procedure, be sure to
   examine the object code to ensure it doesn't affect unsaved registers.}
PROCEDURE GetBasNewline;
begin
   INLINE      {  Push some registers, and set BP and DS ... }
   (
   $9C/              { push flags               ; flags              }
   $50/              { push   ax                ; AX                 }
   $1E/              { push   ds                ; DS                 }
   $2E/$A1/$00/$00/  { mov ax, word ptr cs:[0]  ; Recover our DSeg we }
   $8E/$D8           { mov ds, ax               ; stored at CS:0      }
   );

   ProgramRunning := True;    { mov byte ptr [DS:ProgramRunning], 01 }

Case QBXVer of                { mov ax, [QBXVer]   }
   700: Begin { QBX Ver 7.0 } { cmp ax, 02BC       }
   INLINE      {  Pop the registers, and return to QBX.EXE ... }
   (
   $1F/                    { pop    ds                                     }
   $58/                    { pop    ax                                     }
   $9D/                    { pop    flags                                  }
   $5D/                    { pop    bp                                     }
   $80/$3E/$1A/$19/$00/    { cmp byte ptr [191A],00   ; transplanted QB code}
   $CB                     { ret    FAR               ; return              }
   );
   End;

   710: Begin { QBX Ver 7.1 }
   INLINE      {  Pop the registers, and return to QBX.EXE ... }
   (
   $1F/                    { pop    ds                                     }
   $58/                    { pop    ax                                     }
   $9D/                    { pop    flags                                  }
   $5D/                    { pop    bp                                     }
   $80/$3E/$16/$04/$00/    { cmp byte ptr [416],00 ; transplanted QB code  }
   $CB                     { ret    FAR               ; return              }
   );
   End;

   451: Begin   { Qb 4.5 German version }
   INLINE      {  Pop the registers, and return to QB.EXE ... }
   (
   $1F/                    { pop    ds                                     }
   $58/                    { pop    ax                                     }
   $9D/                    { pop    flags                                  }
   $5D/                    { pop    bp                                     }
   $83/$3E/$E8/$31/$00/    { cmp word ptr [31E8],00   ; transplanted QB code}
   $CB                     { ret    FAR               ; return              }
   );
   End;

Else
   Begin   { Qb 4.5 }
   INLINE      {  Pop the registers, and return to QB.EXE ... }
   (
   $1F/                    { pop    ds                                     }
   $58/                    { pop    ax                                     }
   $9D/                    { pop    flags                                  }
   $5D/                    { pop    bp                                     }
   $83/$3E/$98/$30/$00/    { cmp word ptr [3098],00   ; transplanted QB code}
   $CB                     { ret    FAR               ; return              }
   );
   End;
End; { Case }
end; { GetBasNewline }



{ ===========================  StoreSample ============================}
{ Stores profiling sample data, either a call count or a tick count
   depending on the SampleType flag, for the basic SUB or FUNCTION that
   is currently executing. Creates a new sample record, or updates
   existing record in the sample buffer, pointed at by ptrSampleBuffer.
   Returns True if storage was successful, otherwise if sample buffer
   overflows, this routine sets the SampleBufferOverFlow flag to True
   and returns a False boolean value. This routine is called by the Int 8/70
   handler(s), and the BasSubEntry routine, which in the latter case should
   disable rupts before the call to prevent conflicts.}
FUNCTION StoreSample(SampleType : Byte): Boolean;
Const
CountTicks = 1;            { Identifies the caller as the Int 8/70 handler } 
CountCalls = 2;            { ... or the BasSubEntry procedure.             }

Begin
StoreSample := False;      { Assume not successful }

{ A segment value of FFFF is invalid }
NameOffset := MemW[QBds:ptrSubList^ + ptrCurrentSubSeg^];
{ If not FFFF then get the name pointer for the name list }
If NameOffset <> $FFFF Then
   Begin

   { Use 0000 for the main module }
   If ptrCurrentSub^ = $FFFF Then      { MainModulesub num is $FFFF  }
      NameOffset := 0
   Else
      NameOffset := MemW[QBds:ptrSubList^ + ptrCurrentSubSeg^ - NameAdjust];

   { Find its record in the SampleBuffer.  We manipulate an integer cast on
   top of a record pointer, thus effectively adjusting the ptr's offset.   }
   SampleRec := NextSampleRec - SampleRecLength;{ Search from last position }
   While (SampleRec >= SampleBufferStart) and
         (ptrSampleRec^.SubNum <> NameOffset) Do
      Dec(SampleRec, SampleRecLength);

   If SampleRec < SampleBufferStart Then        { Not found }
      Begin
      If NextSampleRec < SampleBufferTop Then
         Begin                                  { If room in SampleBuffer, }
         SampleRec := NextSampleRec;            { create new record at end }
         ptrSampleRec^.SubNum := NameOffset;    { for this SUB/FUNC,       }
         ptrSampleRec^.SubCount  := 0;          { initing its counters to  }
         ptrSampleRec^.SubTicks  := 0;          { 0.                       }
         Inc(NextSampleRec, SampleRecLength);   { Bump the end marker up-  }
         ptrNextSampleRec^.SubNum := $FFFF;     {  ward also.              }
         End
      Else
         Begin                                  { If not room, set the     }
         SampleBufferOverFlow := True;          { overflow flag and return }
         Exit;
         End;
      End;

    { Increment the appropriate counter }
    If SampleType = CountTicks Then
      Inc(ptrSampleRec^.SubTicks)
    Else
      Inc(ptrSampleRec^.SubCount);

    { Let caller know we were successful }
    StoreSample:= True;
    End;

End; {StoreSample}




{ ===========================  BasSubEntry ============================}
{ QB.EXE is patched after being loaded such that this routine is called
   each time a new sub or function is begun by an executing program.  Its
   function is to count the number of times each sub is called for profiler
   sampling. To minimize overhead on the running basic program, only those
   CPU registers actually used in the procedure are saved and restored.  If
   any changes are made to the Pascal code in this procedure, be sure to
   examine the object code to ensure it doesn't affect unsaved registers.}
PROCEDURE BasSubEntry;
Const
CountCalls = 2;                 { Our identifier to StoreSamples }

begin
   INLINE      {  Push some registers, and set BP and DS ... }
   (
   $9C/              { push flags               ; flags                 }
   $50/              { push   ax                ; AX                    }
   $1E/              { push   ds                ; DS                    }
   $2E/$A1/$00/$00/  { mov ax, word ptr cs:[0]  ; Recover our DSeg we   }
   $8E/$D8           { mov ds, ax               ; stored at CS:0        }
   );

If SamplingEnabled then
   Begin
   { Save more registers }
   asm
      push bx;
      push cx;
      push dx;
      push es;
      push si;
      push di;
   End; {asm}
   { Add one to the Sub's calls counter and the total counts }
   Disable;                      {Lock out int 8/70 ISRs, that share this call }
   {SamplingEnabled := False; }     { Suspend sampling during sampling     }
   If StoreSample(CountCalls) Then Inc(TotalSampleCounts);
   {SamplingEnabled := True;  }     { Restore sampling                     }
   Enable;                       {Restore interrupts }

   { Restore the registers }
   asm
      pop di;
      pop si;
      pop es;
      pop dx;
      pop cx;
      pop bx;
   End; {asm}
   End;

   {  Pop the registers, and return to QB/QBX.EXE ... }
      asm
         pop ds;                                      
         pop ax;
         popf;
         pop bp;
         inc si;               { Transplanted QB/QBX code }
         inc si;
         seges lodsw;
         add si,  ax;
         retf;
      end;{ asm }

end; {BasSubEntry}




{ ============================  StartPlayKey  ========================
 Checks if the Play key combination, a double tap, has been invoked,
 returning True if so.  Called by the timer ISR each tick. }
FUNCTION StartPlayKey:Boolean;
BEGIN
StartPlayKey := False;
Case PlayKeyOpt of
   1: KeyDown := CapsLock;
   2: KeyDown := ScrollLock;
   3: KeyDown := NumLock;
End; { Case }

If (KeyDown) and (not KeyWasDown) Then        { First press             }
   Begin
   KeyWasDown := True;
   Inc(KeyCount);                             { Start/continue timing   }
   End;
If (KeyWasDown) then     { First press release     }
   IF not KeyDown Then
         Begin
         Inc(KeyCount);                             { Start/continue timing   }
         If KeyCount > HiTrigger then               { Too much time - cancel  }
            Begin
            KeyWasDown  := False;
            KeyCount    := 0;
            End;
         End
      Else
         Begin
         If (KeyCount > LoTrigger) and             { in target zone, set flag}
            (KeyCount < HiTrigger) then
            Begin
            StartPlayKey   := True;
            KeyCount       := 0;
            KeyWasDown     := False;
            End;
         End;
End; {StartPlayKey}





{ =========================== PlayNextKey =================================
  Called from the timer ISR whenever PlayingMacro Flag is True and the
  PlayPause countdown, decremented by the timer ISR, hits zero. The current
  macro has already been set by GetMacroKey within the Int 9 ISR, or the
  PlayMacro/MacroPickKey of the popup menu. Feeds the next set of macro key
  strokes from current macro to QB's buffers.  Since QB handles the ALT key
  in real time, we must pause extra between the ALT down, the ALT up, and the
  keystrokes stuffed into the input buffer for QB to process them. This
  routine automatically shuts itself off when the end of the macro is reached
  or switches to the beginning of a new macro if a "join" is in effect.
  Also it recharges the PlayPause delay. }
Procedure PlayNextKey;
VAR
StuffString          : String4;
ThisKey, ScanKey     : Byte;

BEGIN
StuffString := '';
If MemW[$40:$1C] = MemW[$40:$1A] Then      { Keybd buffer head-tail  }
   Begin                                   { same, so can feed more. }
   Inc(NextKey);
   If NextKey >= Length(MacroLine[Macro]) then
      Begin
      PutChr(Ord(' '),MacroStat); PutChr(Ord(' '),MacroStat+2); PutChr(Ord(' '),MacroStat+4);
      PlayingMacro := False;
      { If join in effect, point at target macro }
      If MacroLine[Macro,2] <> #127 then
         Begin
         MacroKey := MacroLine[Macro,2];
         Macro := MacroNum(MacroKey);
         IF Macro > 0 then                   { Valid macro key          }
            Begin
            PutChr(Ord('p'),MacroStat);
            PutChr(Ord(MacroKey),MacroStat + 2);
            NextKey := 2;                       { Init Keystroke pointer   }
            PlayingMacro := True;
            End;
         End;
      End
   Else
      Begin
      If StuffString[0] < #2 Then
         Begin
         Inc(PlayPause,PlayPauseInt);         {Set Delay count          }
         ThisKey := Ord(MacroLine[Macro,NextKey]);
         { Minimum stack string concatenate}
         StuffString[0] := Succ(StuffString[0]);
         StuffString[Ord(StuffString[0])] := Chr(ThisKey);
         Inc(NextKey);
         ScanKey := Ord(MacroLine[Macro,NextKey]);
         If (ThisKey = 0) or (ThisKey = 224) then
            PutChr(ScanKey,MacroStat+4)
         Else
            PutChr(ThisKey,MacroStat+4);

         If ScanKey < 248 then                { Regular key getsstuffed }
            Begin
            { Minimum stack string concatenate}
            StuffString[0] := Succ(StuffString[0]);
            StuffString[Ord(StuffString[0])] := Chr(ScanKey);
            End
         Else
            Begin
            Case ScanKey of
               255:BIOSKeybdFlags^ := BIOSKeybdFlags^ OR ALT_DOWN;
               254:BIOSKeybdFlags^ := BIOSKeybdFlags^ and ALT_UP;
               253:BIOSKeybdFlags^ := BIOSKeybdFlags^ OR CTRL_DOWN;
               252:BIOSKeybdFlags^ := BIOSKeybdFlags^ and CTRL_UP;
               251:BIOSKeybdFlags^ := BIOSKeybdFlags^ OR LSHFT_DOWN;
               250:BIOSKeybdFlags^ := BIOSKeybdFlags^ and LSHFT_UP;
               249:BIOSKeybdFlags^ := BIOSKeybdFlags^ OR RSHFT_DOWN;
               248:BIOSKeybdFlags^ := BIOSKeybdFlags^ and RSHFT_UP;
            End;
            If PatchOK Then
               Begin
               QBKeybdFlags^   := BIOSKeybdFlags^;         { QB's also    }
               QBKeyPress^     := 1;                       { Alert QB      }
               End;
            Inc(PlayPause,2);                               { in timer ticks }
            StuffString[0] := Pred(StuffString[0]);
            End;
         End;
      End;
   End;
If StuffString <> '' Then
   { Put the sequence into the keyboard buffer    }
   Begin
   StuffBuffBIOS(StuffString);
   If PatchOK Then
      Begin
      QBKeyPress^     := 1;                           { Alert QB     }
      End;
   End;

END;





{ =========================== PatchQB =================================
   This procedure is called (via timer interrupts) after QB.EXE is started
   and until QB is resident, at which time QB's various code and data
   segments are identified and patch points installed to point at patch
   code in this parent program.  The routine is called thereafter when the
   patch bytes placed in QB change, signifying QB has unloaded itself --
   typically to compile a program.}
PROCEDURE PatchQB;
Var
   ISROffset   : Word;                       { Stores QB's IVT int 4 Ofs }

BEGIN
   { Monitor int 4 vector.  When it changes, QB has initialized. }
If memw[ $0000:$0012 ] <> QBcs then       { QBloaded now, so patch}
   Begin
   ISROffset:= memw[$0000:$0010];            { Get version specific ofs }

   Case ISROffset Of
   $57:                                      { QBX 7.1  }
      begin
      QBX := True;
      QBXVer := 710;
      QBcs  := memw[ $0000:$0012 ];          {int 4 Seg  $66   below    }
      QBds  := memw[ QBcs+ $66:$01AE ];      {QB's code Seg; DSeg value }
      GotQBcs        := True;                {is at cs:0446             }
      QBcsE          := QBcs - $09F3+ $66;   {QB cs for edit keydb loop }
      QBKeyPress     := ptr( QBds, $1EE6);   {QB's flag for keypressed  }
      QBKeybdFlags   := ptr( QBds, $20A7);   {QB's copy of keyb'd flags }
      BIOSKeybdFlags := ptr(  $40,   $17);   {BIOS keyboard flags byte  }
      { Patch QB.EXE input loop to call our CheckHotKey procedure }
      ptrCheckHotKey := @CheckHotKey;
      ptrPatchVal    := Ptr( QBcsE, $695 );   { Location of patch point }
      Mem [QBcsE:$695]  := $9A;               {FAR CALL operator        }
      MemW[QBcsE:$696]  := Ofs(CheckHotKey);  {Pointer to our procedure }
      MemW[QBcsE:$698]  := Seg(CheckHotKey);  { placed in QBcs edit loop}
      PatchedVal        := ptrPatchVal^;      { record value at patch point }
      ptrSubList        := ptr(QBds, $2D26);  { Addr sublist offset in ds  }
      ptrCurrentSubSeg  := ptr(Qbds, $2D3C);  { Bytes to SubSeg in SubList }
      ptrCurrentSub     := ptr(Qbds, $2D40);  { Bytes to SubSeg in SubList }
      NameAdjust        := $14;               { Bytes Name->Seg in SubList }
      NameSegAdjust     := $18;               { Bytes to NameSeg in SubList}
      { Patch QBX.EXE Newline function to call our GetBasNewline procedure }
      Mem[QBcs+$24D:$2CB1] := $9A;               {FAR CALL operator        }
      MemW[QBcs+$24D:$2CB2]   := Ofs(GetBasNewline);{Pointer to our procedure }
      MemW[QBcs+$24D:$2CB4]   := Seg(GetBasNewline);{ placed at Newline       }
      { Patch QBX.EXE EnSub function to call our BasSubEntry procedure }
      Mem [QBcs+$24D:$30A8]   := $90;               {NOP instruction          }
      Mem [QBcs+$24D:$30A9]   := $9A;               {FAR CALL operator        }
      MemW[QBcs+$24D:$30AA]   := Ofs(BasSubEntry);{Pointer to our procedure   }
      MemW[QBcs+$24D:$30AC]   := Seg(BasSubEntry);{ placed at Newline         }
      { QBCGet locations }
		ptrMainModNum     := ptr(QBds, $2D36);{ main module's index number}
		FirstModAdjust    := $D2;  { Loc first valid modnum in entries    }
		CurrentNameOff    := $2D26+$50;{ NameOffset of module in active win}
		ModNameAdjust     := $4;   { NameOffset member in Mod entrym      }
		NextModLink       := $12;  { Link member to next mod entry        }
      end;

    $5D:                                            { Version 7.0 }
      begin                                         { QBX specific }
      QBX := True;
      QBXVer := 700;
      QBcs  := memw[ $0000:$0012 ] + 0;      {int 4 Seg        below       }
      QBds  := memw[ QBcs:$0446 ];           {QB's code Seg; DSeg value    }
      GotQBcs        := True;                {is at cs:0446                }
      QBcsE          := QBcs - $095B;        {QB cs for edit keydb loop    }
      QBKeyPress     := ptr( QBds, $1CB6);   {QB's flag for keypressed     }
      QBKeybdFlags   := ptr( QBds, $2B16);   {QB's copy of keyb'd flags    }
      BIOSKeybdFlags := ptr(  $40,   $17);   {BIOS keyboard flags byte     }
      { Patch QB.EXE input loop to call our CheckHotKey procedure }
      ptrCheckHotKey := @CheckHotKey;
      ptrPatchVal    := Ptr( QBcsE, $9D3 );   { Location of patch point    }
      Mem [QBcsE:$9D3]  := $9A;               { FAR CALL operator          }
      MemW[QBcsE:$9D4]  := Ofs(CheckHotKey);  { Pointer to our procedure   }
      MemW[QBcsE:$9D6]  := Seg(CheckHotKey);  { placed in QBcs edit loop.  }
      PatchedVal        := ptrPatchVal^;      { Record patch point value   }
      ptrSubList        := ptr(QBds, $2C68);  { Addr sublist offset in ds  }
      ptrCurrentSubSeg  := ptr(Qbds, $2C7E);  { Bytes to SubSeg in SubList }
      ptrCurrentSub     := ptr(Qbds, $2C82);  { Bytes to SubSeg in SubList }
      NameAdjust        := $14;               { Bytes Name->Seg in SubList }
      NameSegAdjust     := $18;               { Bytes to NameSeg in SubList}
      { Patch QBX.EXE Newline function to call our GetBasNewline procedure }
      Mem[QBcs+$24C:$2DB7] := $9A;               {FAR CALL operator        }
      MemW[QBcs+$24C:$2DB8]   := Ofs(GetBasNewline);{Pointer to our procedure }
      MemW[QBcs+$24C:$2DBA]   := Seg(GetBasNewline);{ placed at Newline       }
      { Patch QBX.EXE EnSub function to call our BasSubEntry procedure }
      Mem [QBcs+$24C:$319E]   := $90;               {NOP instruction          }
      Mem [QBcs+$24C:$319F]   := $9A;               {FAR CALL operator        }
      MemW[QBcs+$24C:$31A0]   := Ofs(BasSubEntry);{Pointer to our procedure   }
      MemW[QBcs+$24C:$31A2]   := Seg(BasSubEntry);{ placed at Newline         }
      { QBCGet locations }
      ptrMainModNum     := ptr(QBds, $2C76);{ main module's index number}
      FirstModAdjust    := $D2;  { Loc first valid modnum in entries    }
      CurrentNameOff    := $2C68+$56;{ NameOffset of module in active win}
		ModNameAdjust     := $4;   { NameOffset member in Mod entrym      }
		NextModLink       := $12;  { Link member to next mod entry        }
      end;

   $C58:
      begin                             { QB4.5 German version specific }
      QBXVer := 451;
      QBcs  := memw[ $0000:$0012 ] + 3413;   {int 4 Seg is 3413 below   }
      QBds  := QBcs + $1B34;                 {QB's code Seg; DSeg value }
      GotQBcs        := True;                {                          }
      QBcsE          := QBcs - $16E5;        {QB cs for edit keydb loop }
      QBKeyPress     := ptr( QBds, $210C);   {QB's flag for keypressed  }
      QBKeybdFlags   := ptr( QBds, $2F7F);   {QB's copy of keyb'd flags }
      BIOSKeybdFlags := ptr(  $40,   $17);   {BIOS keyboard flags byte  }
      { Patch QB.EXE input loop to call our CheckHotKey procedure }
      ptrCheckHotKey    := @CheckHotKey;
      ptrPatchVal       := Ptr(QBcsE, $930);  { Location of patch point    }
      Mem [QBcsE:$930]  := $9A;               { FAR CALL operator          }
      MemW[QBcsE:$931]  := Ofs(CheckHotKey);  { Pointer to our procedure   }
      MemW[QBcsE:$933]  := Seg(CheckHotKey);  { placed in QBcs edit loop   }
      PatchedVal        := ptrPatchVal^;      { record value at patch point }
		ptrSubList        := ptr(QBds, $30B4);  { Addr sublist offset in ds  }
		ptrCurrentSubSeg  := ptr(Qbds, $30C8);  { Bytes to SubSeg in SubList }
		ptrCurrentSub     := ptr(Qbds, $30CC);  { Bytes to SubSeg in SubList }
		NameAdjust        := $12;               { Bytes Name->Seg in SubList }
		NameSegAdjust     := $16;               { Bytes to NameSeg in SubList}
		{ Patch QB.EXE Newline function to call our GetBasNewline procedure }
		Mem [QBcs:$2A2A]  := $9A;               {FAR CALL operator        }
		MemW[QBcs:$2A2B]  := Ofs(GetBasNewline);{Pointer to our procedure }
		MemW[QBcs:$2A2D]  := Seg(GetBasNewline);{ placed at Newline       }
		{ Patch QB.EXE EnSub function to call our BasSubEntry procedure }
		Mem [QBcs:$2D81]  := $90;               {NOP instruction          }
		Mem [QBcs:$2D82]  := $9A;               {FAR CALL operator        }
		MemW[QBcs:$2D83]  := Ofs(BasSubEntry);{Pointer to our procedure   }
		MemW[QBcs:$2D85]  := Seg(BasSubEntry);{ placed at Newline         }
      { QBCGet locations }
		ptrMainModNum     := ptr(QBds, $30C0);{ main module's index number}
      FirstModAdjust    := $CA;  { Loc first valid modnum in entries    }
      CurrentNameOff    := $30B4+$74;{ NameOffset of module in active win}
		ModNameAdjust     := $4;   { NameOffset member in Mod entrym      }
      NextModLink       := $10;  { Link member to next mod entry        }
		end;

   Else
      begin                                       { QB4.5 specific }
      QBXVer := 450;
      QBcs  := memw[ $0000:$0012 ] + 3412;   {int 4 Seg is 3412 below   }
      QBds  := memw[ QBcs:$3993 ];           {QB's code Seg; DSeg value }
      GotQBcs        := True;                {is at cs:3993             }
      QBcsE          := QBcs - $16D2;        {QB cs for edit keydb loop }
      QBKeyPress     := ptr( QBds, $1FD6);   {QB's flag for keypressed  }
      QBKeybdFlags   := ptr( QBds, $2E25);   {QB's copy of keyb'd flags }
      BIOSKeybdFlags := ptr(  $40,   $17);   {BIOS keyboard flags byte  }
      { Patch QB.EXE input loop to call our CheckHotKey procedure }
      ptrCheckHotKey    := @CheckHotKey;
      ptrPatchVal       := Ptr(QBcsE, $930);  { Location of patch point    }
      Mem [QBcsE:$930]  := $9A;               { FAR CALL operator          }
      MemW[QBcsE:$931]  := Ofs(CheckHotKey);  { Pointer to our procedure   }
      MemW[QBcsE:$933]  := Seg(CheckHotKey);  { placed in QBcs edit loop   }
      PatchedVal        := ptrPatchVal^;      { record value at patch point }
      ptrSubList        := ptr(QBds, $2F64);  { Addr sublist offset in ds  }
      ptrCurrentSubSeg  := ptr(Qbds, $2F78);  { Bytes to SubSeg in SubList }
      ptrCurrentSub     := ptr(Qbds, $2F7C);  { Bytes to SubSeg in SubList }
      NameAdjust        := $12;               { Bytes Name->Seg in SubList }
      NameSegAdjust     := $16;               { Bytes to NameSeg in SubList}
      { Patch QB.EXE Newline function to call our GetBasNewline procedure }
      Mem [QBcs:$2A2A]  := $9A;               {FAR CALL operator        }
      MemW[QBcs:$2A2B]  := Ofs(GetBasNewline);{Pointer to our procedure }
      MemW[QBcs:$2A2D]  := Seg(GetBasNewline);{ placed at Newline       }
      { Patch QB.EXE EnSub function to call our BasSubEntry procedure }
      Mem [QBcs:$2D81]  := $90;               {NOP instruction          }
      Mem [QBcs:$2D82]  := $9A;               {FAR CALL operator        }
      MemW[QBcs:$2D83]  := Ofs(BasSubEntry);{Pointer to our procedure   }
		MemW[QBcs:$2D85]  := Seg(BasSubEntry);{ placed at Newline         }
      { QBCGet locations }
      ptrMainModNum     := ptr(QBds, $2f70);{ main module's index number}
      FirstModAdjust    := $CA;  { Loc first valid modnum in entries    }
      CurrentNameOff    := $2F64+$74;{ NameOffset of module in active win}
		ModNameAdjust     := $4;   { NameOffset member in Mod entrym      }
      NextModLink       := $10;  { Link member to next mod entry        }
      end;
   End;{Case}
End; { Patching }
END;  {Patch QB }





{===========================    our_INT70   ===========================
  The following procedure replaces the interrupt handler code called by
  INT $70.  It is invoked once every real time clock tick.
}
PROCEDURE our_int70; INTERRUPT;
Const
CountTicks = 1;      { Identify our call to Store Profile Sample }
Var
Test1    : Word absolute $0:$04F0;   { Places we can see from the memory   }
Test2    : Word absolute $0:$04FE;   { viewer to know whether ISR works.   }

BEGIN
   {Inc(Test1); }                       { Shows if this ISR is called      }

    { Call the original interrupt handler to do its work. Do not call
      this last, as it may disable further interrupts if the wait
      count which the old routine handles expires.  (INT $70 services a
      series of counter bytes at $40:$9C which tie in with the daily alarm
      and System Wait functions of INT $15/83 and INT $15/86).  Existing
      routine in BIOS INT $70 should also handle clearing of hardware
      interrupt, but we do this also just in case, to avoid loss of the
      next interrupt.
      }
   asm
      pushf                               { Simulate INT call              }
      call [old_70]
   end; {asm}

   {Inc(Test2);   }                       { Shows if return from old to us }

   If SamplingEnabled and ProgramRunning Then
      If StoreSample(CountTicks) Then Inc(TotalSampleTicks);

   { Re-enable periodic interrupts in case regular (old-int-70)
   disabled them. }
   Enable_RTC;

   { Clear hardware interrupt on interrupt controller, in case, also }
   Port[$A0] := $20;             { Second controller on AT }
   Port[$20] := $20;             { Primary controller all PC's }

END; { procedure our_int70 }




{===========================   Our_INT9  ===========================
  The following procedure replaces the interrupt handler code called by
  INT $9 whenever QB/QBX is active, but not when our window is popped up.
  It is invoked once every keypress, and when GetMacroKey or
  Recording or Play flags are set, it grabs or copies keystrokes of
  interest to us before QB can get it's hands on them via Int 16.
  When recording, it adds the key character and scan code, or in the case
  of shift keys, a special code, to the recording macro. Grabbed keys
  are echoed to upper left of screen.
  When GetMacroKey, it grabs the keystroke out of keyboard buffer and
  flushes the buffer to keep the key away from QB.
  When Playing, it checks for an ESC keypress and then cancels play.
}

PROCEDURE Our_int9; INTERRUPT;
VAR
By          : Byte;
Wo          : Word;
RKeyChar    : Char;
BEGIN
KeybdFlags := BIOSKeybdFlags^;     { Preserve pre-keypress state of shifts }

{  Call the original int 9 ISR to do its work. That includes the BIOS
   processing the scan code into a kybdbuff entry. }
asm
   pushf                               { Simulate INT call           }
   call [old_9]
end; {asm}

If Recording Then
   { Shift - Ctrl or Both Shifts cancel recording }
   IF ((EndRecordKeyOpt = 1) and (ShiftKey and CtrlKey)) or
      ((EndRecordKeyOpt = 2) and (LShiftKey and RShiftKey)) then
      BEGIN
      Recording := not Recording;  { Clear recording flag   }
      { remove the last key stored - it's the first of the end-record combo }
      If Length(MacroLine[Macro]) < 81 then
         Delete(MacroLine[Macro],Length(MacroLine[Macro]) - 1, 2);
      { Remove screen recording indicators   }
      PutChr(Ord(' '),MacroStat); PutChr(Ord(' '),MacroStat+2); PutChr(Ord(' '),MacroStat+4);
      End;

If Recording Then
   If MemW[$40:$1C] <> MemW[$40:$1A] Then     { Keybd buffer head-tail  }
      Begin                                   { differ, meaning a       }
      Wo := Mem[$40:$1A];                     { character, or function  }
      By := Mem[$40:Wo];                      { key there.  Get it.     }
      RKey := By;
      MacrosChanged := True;

      If MacroLine[Macro,0] > #80 Then        { Switch macro keys at end}
         If MacroLine[Macro,2] in MacroKeys Then   { if join in effect  }
            Begin
            MacroKey := MacroLine[Macro,2];   { Make the join key the   }
            Macro := MacroNum(MacroKey);      { current macro, and show }
            PutChr(Ord(MacroKey), MacroStat + 2); { macro key on screen.}
            End;

      PutChr(RKey,MacroStat+4);               { Show key on screen and, }
      If MacroLine[Macro,0] < #81 Then        {  if room, store in macro}
         Begin
         RKeyChar := Chr(RKey);
         AddChr(MacroLine[Macro], RKeyChar);
         End;

      By := Mem[$40:Wo+1];                    { Get scan code, and      }
      IF (RKey = 0) or (RKey = 224) then      { display it for extended }
         Begin                                { keys.                   }
         PutChr(By,MacroStat+4);
         End;

      If MacroLine[Macro,0] > #81 Then        { Switch macro keys at end}
         If MacroLine[Macro,2] in MacroKeys Then   { if join in effect  }
            Begin
            MacroKey := MacroLine[Macro,2];   { Make the join key the   }
            Macro := MacroNum(MacroKey);      { current macro, and show }
            PutChr(Ord(MacroKey), MacroStat + 2); { macro key on screen.}
            End;

      RKey := By;
      If MacroLine[Macro,0] < #82 Then        { store scan code also    }
         Begin
         RKeyChar := Chr(RKey);
         AddChr(MacroLine[Macro], RKeyChar);
         End;
      If MacroLine[Macro,0] > #75 Then        { sound warning           }
         Begin
         Sound(250);
         Delay(18);
         NoSound;
         End;
      End
   Else
      { Handle Alt/Shift/Ctrl key event, if one }
      If KeybdFlags <> BIOSKeybdFlags^ then
         Begin
         { Strip out changed bit, isolate it and convert to key code }
         Case KeybdFlags XOR BIOSKeybdFlags^ of
            ALT_DOWN :
               RKey := ((ALT_DOWN AND BIOSKeybdFlags^) SHR 3) + 254;
            CTRL_DOWN :
               RKey := ((CTRL_DOWN AND BIOSKeybdFlags^) SHR 2) + 252;
            LSHFT_DOWN :
               RKey := ((LSHFT_DOWN AND BIOSKeybdFlags^) SHR 1) + 250;
            RSHFT_DOWN :
               RKey := ((RSHFT_DOWN AND BIOSKeybdFlags^)) + 248;
         End;
         PutChr(RKey,MacroStat+4);           { Show on screen.          }
         MacrosChanged := True;
         If MacroLine[Macro,0] > #80 Then        { Switch macro keys at end}
            If MacroLine[Macro,2] in MacroKeys Then   { if join in effect  }
               Begin
               MacroKey := MacroLine[Macro,2];   { Make the join key the   }
               Macro := MacroNum(MacroKey);      { current macro, and show }
               PutChr(Ord(MacroKey), MacroStat + 2); { macro key on screen.}
               End;

         If MacroLine[Macro,0] < #81 Then
            Begin
            RKeyChar := #0;
            AddChr(MacroLine[Macro], RKeyChar);
            RKeyChar := Chr(RKey);
            AddChr(MacroLine[Macro], RKeyChar);
            End;

         If MacroLine[Macro,0] > #75 Then        { sound warning           }
            Begin
            Sound(250);
            Delay(18);
            NoSound;
            End;
         {AltAction := 5;}                   { ticks delay for QB to get}
         End;

If GettingMacroKey Then
   If MemW[$40:$1C] <> MemW[$40:$1A] Then     { Keybd buffer head-tail  }
      Begin                                   { differ, meaning a       }
      Wo := Mem[$40:$1A];                     { character, or function  }
      By := Mem[$40:Wo];                      { key there.  Get it.     }
      IF By = 0 then                          { Get two bytes and add   }
         Begin
         {Inc(Wo,2);
         If Wo > $3C then Wo := $1E;}
         By := Mem[$40:Wo+1];
         End;
      MKey := Ord(UpCase(Chr(By)));           { Convert to upper char   }
      IF MKey = 27 Then                       { Clear ctrl, shift, alt  }
         BIOSKeybdFlags^ := BIOSKeybdFlags^ AND $F0;  { down flags      }
      PutChr(Ord(MKey),MacroStat+2);          { in MKey, clear buffer.  }
      MemW[$40:$1C] := MemW[$40:$1A];
      GettingMacroKey := False;               { Set flags for next act, }
      End;

{ Cancel macro play if ESC pressed }
IF PlayingMacro Then
   If MemW[$40:$1C] <> MemW[$40:$1A] Then     { Keybd buffer head-tail  }
      Begin                                   { differ, something there }
      {Check most recent scan code for ESC key}
      Wo := Mem[$40:$1C];                     { Backup from tail        }
      If Wo = $1E then Wo := $3C;             { Accomodate wrap around  }
      Dec(Wo,2);
      By := Mem[$40:Wo];                      {             Get it.     }
      IF (By = 27) or (Mem[$40:Wo+1] = 1) then
         Begin
         MemW[$40:$1C] := MemW[$40:$1A];      { Flush buffer            }
         PlayingMacro := False;               { disable playing         }
         PutChr(Ord(' '),MacroStat);          { Clear screen symbols    }
         PutChr(Ord(' '),MacroStat+2);
         PutChr(Ord(' '),MacroStat+4);
         End;
      End;
END;






{===========================   Our_INT8  ===========================
  The following procedure replaces the interrupt handler code called by
  INT $8.  It is invoked once every BIOS clock tick -- and monitors the
  load status of QB, ensuring our patch point stays intact, feeds keystrokes
  to QB when playkey is active, places recording symbol on top line
  when recording active, and calls sample collection when profiling active.
}

PROCEDURE Our_int8; INTERRUPT;
Const
CountTicks = 1;      { Identifiy our call to Store Profile Sample }

BEGIN

{ Get QB's code and data segments if not already gotten. }
IF Not GotQBcs THEN If PatchOK then PatchQB;

{ Monitor integrity of patch point. If value changed, QB has
unloaded itself, probably to "make exe", so we'll clear our patch
flag to begin checking for QB reinstallation for us to repatch. }
If PatchedVal <> ptrPatchVal^ Then
   Begin
   QBcs := memw[ $0000:$0012 ];
   GotQBcs  := False;
   End;
  
If Recording Then                      { put recording sym. on QB's scrn}
   Begin
   PutChr(Ord('r'),MacroStat);
   PutChr(Ord(MacroKey),MacroStat+2);
   End;

IF PlayingMacro Then
   If PlayPause > 0 Then Dec(PlayPause) Else PlayNextKey;


If StartPlayKey Then                        { Alert Int 9 ISR to catch  }
   Begin                                    { and eat next keypress.    }
   GettingMacroKey := True;                 { It puts it in MKey and    }
   PutChr(Ord('m'),MacroStat);              { clears flag when key got. }
   MKey := 0;
   End;
If MKey <> 0 Then                          { Int 9 got a key awhile     }
   If MKey = 27 Then                       { Is it cancel? Yes.         }
      Begin
      PutChr(Ord(' '),MacroStat);          { Remove screen symbol     }
      PutChr(Ord(' '),MacroStat + 2);      { Remove screen symbol     }
      MKey := 0;
      End
   Else
   If Chr(Mkey) IN MacroKeys Then
         Begin
         MacroKey := Chr(MKey);              { Valid macro key          }
         Macro := MacroNum(MacroKey);
         MKey := 0;
         PutChr(Ord('p'),MacroStat);
         PlayingMacro := True;               { Flag invokes macro player}
         NextKey := 2;                       { Init Keystroke pointer   }
         End
      Else
         Begin                               { Invalid macro key, so    }
         MKey := 0;                          { set flag to keep trying  }
         GettingMacroKey := True;
         End;

{If SamplingEnabled and ProgramRunning Then
   Inc(ProfElapsed);}                  { add one to elapsed time tick count  }

If SampleTSource = SysTick then
   If SamplingEnabled and ProgramRunning Then
      If StoreSample(CountTicks) Then Inc(TotalSampleTicks);  

{ Call the original int 8 ISR to do its work }
asm
   pushf                               { Simulate INT call           }
   call [old_8]
end; {asm}

{ Clear hardware interrupt on interrupt controller. }
Port[$20] := $20;                            { Primary controller all PC's }

END;  { Our_int8 }






{===========================  ExitProgram   ===========================}
{ Procedure to restore the interrupt vectors and screen settings, and
  anything else, whenever the program halts unexpectedly.  This routine
  is registered with ExitProc to be called automatically. }
{$F+} PROCEDURE ExitProgram;{$F-}
   BEGIN
   DErrCode := DosError;                  { Store any error info  }
   DXCode   := DosExitCode;

   { If an unanticipated, unrecoverable error occurs in our code -- such as
   in the pop up -- while QB is running, we need to be sure we disconnect all
   the IVT hooks into QB, then be sure the state of the SaveIntXX variables
   contain the original DOS vectors our program loaded there at startup. They
   are restored to the IVT at shutdown. }
   If not TPIntsInIVT then
      Begin
      Disable;
      Move(IVTSave, CurrentIVT, SizeOf(IVTSave));
      Enable;
      SwapVectors;
      End;

{$IFNDEF NoInt8}
    ExitProc := exitsave;                  { Restore exit vector  }
   { UnHook the hardware interrupt INT 8 }
   SetIntVec( $8, old_8);
{$ENDIF}
   SetIntVec( $9, old_9);

   { Unhook the int 70 vector, if we'd hooked it }
   If Int70Hooked Then
      Begin
      SetRtcRate(1024);                   { Restore default Rtc PI rate    }
      Disable_Rtc;                        { Shut off periodic interrupt,   }
      SetIntVec( $70, old_70);            { if we started it, first.       }
      End;

   Cursor_on;                               { Be sure cursor restored }
   Writeln;

	{ Restore keyboard rate, if changed }
   If KeyBdAutoSet Then
      Begin
      Port[$60] := $F3;              { Send cmd in plenty of time for }
      Delay(10);                     { hardware recovery before our   }
		Port[$60] := $2C;              { standard value is sent.        }
		End;                           { Delay=500ms, repeat=10cps      }

   IF DErrCode + DxCode = 0 then
      Write('QB Plus terminated normally.')
      else
      begin
      write('QB Plus exit code: ',DxCode,', Dos error code: ',DErrCode);
      Case DErrCode of
         2: writeln(' Program not found.');
         8: writeln(' Insufficient memory.')
      else Writeln;
      End; { case }
      End;
   End; {Exit Program}






{---------------------------  Main Program -----------------------------}
{=======================================================================}
BEGIN
{ We set a flag that reflects certain Interrupt Vector Table entries point
at our ISR code.  We'll be swapping them in and out, and exchanging some with
child processes including QB.  Since our exit code copies the values in the
SaveIntXX variables back into the IVT at shutdown, we must ensure that before
shutdown, our ISR's are hooked and that the original DOS values are in the
SaveINTXX area.  The state of this flag will tell us whether shutdown is
about to occur when our ISR's are not hooked, so we can do a SwapVectors to
put things into the proper state.}
TPIntsInIVT := True;                   { Mark TP's ISR's are hooked in  }



{ Make sure we can locate our overlays.  If we're running in Dos 3.0 +, we
can get our own name from Dos. }
OvrInit(Paramstr(0));

{ If this fails, then we're either in pre-dos 3.0, or our overlays are not
in our .exe file, or there is some other problem. Try our default name stored
in our DGroup when we were compiled.}
If OvrResult <> OvrOK then
   Begin
   OvrInit(TextLine[3]);

{ If this failed, our last effort will be with a separate .ovr file of the
default filename.  A fourth possibility - separate files that have both
been changed from the default filename - would require extra processing and
additional resident memory to handle, so we won't bother.}
   If OvrResult <> OvrOK then
      Begin
      OvrInit(TextLine[4]);
      If OvrResult <> OvrOK then
         Begin
         Write('Cannot continue - Error ',OvrResult);
         Case OvrResult Of
            OvrNotFound : Writeln(' Overlay file not found.');
            OvrIOError  : Writeln(' I/O error reading overlay file.');
            OvrNoMemory : Writeln(' Insufficient heap for overlay.');
         Else
            Writeln(' Overlay system error.');
         End; {Case}
         Halt(1);                                 { Terminate Here }
         End;
      End;
  End;



{ Combine comand line options into a single string. }
Parm  := '';
FOR I := 1 TO ParamCount DO
   Begin
   { Basic load filename is delimited by a space, not '/' }
   If Pos('/' ,ParamStr(I)) = 0 Then
      Parm := Parm + ' ';            { Put back space TP stripped }
   Parm := Parm + ParamStr(I);
   End;
{ Convert to all uppercase. }
FOR I := 1 TO Length( Parm ) DO
      Parm[ I ] := UpCase( Parm[I] );



{ See if command line switch to disallow overlays in EMS, and if
not, put the overlay code into EMS. }
If Pos('/NEO', Parm) = 0 Then
   Begin
   OvrInitEMS;  { Detect and use EMS }
   If OvrResult <> OvrOK Then
      If OvrResult = OvrIOError Then
         Begin
         Writeln('Cannot continue. I/O error reading overlay file.');
         Halt(1);
         End;
   End
Else
   Begin
   { Get the NEO out of the parms so we don't confuse QB }
   I := Pos( '/NEO', Parm );
   Delete(Parm, I, Length('/NEO'));
   End;



{ Test for Expanded and Extended memory }
EMMThere := False;                  { Assume  none of it is there    }
XMThere  := False;
HimemSys := False;
FindEMM;                            { If found, sets EMThere, inits EMS data }
FindXMM;                            { If found, sets XMThere, inits XMS data }



{ Call initialization unit to set everything up.
 If QuickBasic cannot be found, then this call will
 not return -- the program will halt in the routine
 with a message, and thus this call must come before
 intercept of any ISR's, etc. }
pdaSetUp;



{$IFNDEF NoInt8}
{ Hook the hardware interrupt INT 8 }
GetIntVec( $8, old_8);
SetIntVec( $8, @our_int8);
{$ENDIF }

{ Hook the hardware interrupt INT 9 }
GetIntVec( $9, old_9);
SetIntVec( $9, @our_int9);

{ Hook the hardware interrupt INT 70, if requested at startup. }
our_70 := @our_int70;           { Store our ISR entry point for other units }
If Use_Rtc Then
   Begin
   GetIntVec( $70, old_70);
   SetIntVec( $70, @our_int70);
   Int70Hooked := True;
   End;

{Set up ExitProc routine }
ExitSave := ExitProc;                     { Preserve prior value  }
ExitProc := @ExitProgram;                 { Register routine      }




{ Save our DSeg at start of our code segment
   .. for patch code to be able to find when coming from QB.EXE}
DummyReturn;                       {Call Dummy to ensure linking in.EXE}
ptrDSegSave    := ptr(CSeg,0);
ptrDSegSave^   := DSeg;





{ Call QB with command line passed to us }
    { Save stack of TSR for popup use, swap in special stack for Exec call. }

    { IMPORTANT -- if this program contains a routine to swap out QB and call
      a second child process, the actual stack pointer at the start of the
      source program Exec call must equal offExecStack, since we use that
      in the second exec call, and the two must be the same.  That means no
      stack saves between here and there, nor a call to exec in a
      sub procedure }

    { Point at end of space cleared for exec stack }
    segExecStack := Seg(ExecStack);
    offExecStack := Ofs(ExecStack) + SizeOf(ExecStack);

     INLINE
         (
         $FA/                 { cli                                     }
         $89/$26/offTsrStack/ { mov offTsrStack, sp ; Save TSR stack    }
         $8C/$16/segTsrStack/ { mov segTsrStack, ss                     }
         $8B/$26/offExecStack/{ mov sp, offExecStack ; Load Exec stack  }
         $8E/$16/segExecStack/{ mov ss, segExecStack                    }
         $FB                  { sti                                     }
      );
   SwapVectors;                            
   TPIntsInIVT := False;                  { Mark TP's ISR's as unhooked }

   {$IFDEF NoQB}
   Popup;
   DErrCode := 0;                         { Always OK in test     }
   Halt;

   {$ELSE}
   Qbcs  := memw[ $0000:$0012 ];
   GotQBcs  := False;           { Now safe to start monitoring for QB }
   PatchOk := True;               { Now safe to start monitoring for QB }

   { Save a copy of the interrupt vector table as it existed without our
      vectors.  We'll need it to unhook QB's vectors while QB is swapped
      out, and to shut down QB in event of an unrecoverable error of ours. }
   Move(CurrentIVT, IVTSave, SizeOf(IVTSave));

   Exec(QBPathStr, Parm);
   DErrCode := DosError;                  { Store any error info  }
   DXCode   := DosExitCode;
   {$ENDIF }

   Writeln;
   IF DErrCode + DXCode > 0 then
      begin
      write('QB exit code: ',DXCode,', Dos error code: ',DErrCode);
      Case DErrCode of
         2: writeln(' Program not found.');
         8: writeln(' Insufficient memory.')
         else Writeln;
         end; { case }
      End;

   SwapVectors;
   TPIntsInIVT := True;                   { Mark TP's ISR's are hooked in  }
   { Restore original stack. }
   INLINE
         (
         $FA/                    { cli                  }
         $8B/$26/offTsrStack/    { mov  sp, offTsrStack }
         $8E/$16/segTsrStack/    { mov  ss, segTsrStack }
         $FB                     { sti                  }
         );



Ch := 'N';
IF MacrosChanged Then
   Begin
   Writeln('Keystrokes recorded in memory have changed.');
   Write('Save the changes (Y/N)? ');
   Repeat
   Ch := GetUpKey;
   Until (Ch IN ['Y','N',#27]);
   End; {MacrosChanged}
If Ch = 'Y' then
   Begin
   Writeln{('File name: ',TmpStr)};
   SaveMacros;
   End;



ExitProgram;

END.

