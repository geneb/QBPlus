{-------------------------------------------------------------------------

                                    Child2

            Unit to swap out running memory image of QuickBasic,
               load and execute another program, and return.

                  Written for Borland Turbo Pascal V 6.0
                  -- Contains Version-specific code --

                     Copyright 1991, by John H. Eckert
                           All Rights Reserved


                                                   ... a component of the
                                                   QB Plus Desk Accessories
-------------------------------------------------------------------------}
{ History:           
12/31/90   1.55   Born as an added function to a pop up memory viewer tool.               
01/03/91   0.10   Restructured to take on a support role in a package of
                  pop up tools called as overlays.  Version number reflects
                  the parent, resident kernel program.  Code to obtain a
                  filename moved to parent/other sibling units.
02/01/91   0.50   Granularity improved by moving the memory swap routines
                  to a separate overlay unit.
09/11/91   1.01   German version QB 4.5 code added. Mouse save during switch.
						Enable cursor for Child2.
10/10/91   1.10   Code to save/restore blink/intensity settings in support
						of our 16 color backgrounds.  Blink is ON to Child prog but
						is off in QB and QB Plus.
}
{-------------------------------------------------------------------------}
{$F+}
{$O+}                               { Unit may be overlaid     }
UNIT Child2;

{ Pass the desired program filespec in the PathStr, Child2Name; and any
  command line arguments in PathStr, Child2Parms.  This unit will copy the
  conventional memory image of QuickBasic, and any loaded source files, in
  priority to XMS, EMS, or the current disk directory, then load and execute
  the file Child2Name, thereafter restoring QuickBasic to memory.  Prior to
  executing Child2Name, the current screen is saved and cleared (unless the
  boolean, NoClrScrn is set), and restored when Child2Name terminates.

  Any module using this unit must save a copy of the Interrupt Vector Table
  (at segment 0000h, offset 0000h to FFFFh) in the array IVTSave before
  spawning QuickBasic.  Use the statement:

                  Move(CurrentIVT, IVTSave, SizeOf(IVTSave));

  This call MUST be issued between the SwapVectors call and the Exec call to
  QuickBasic, so that a pure copy (one not containing TP vectors) is saved.
  This copy is used by SwapQB to replace vectors unhooked from QuickBasic
  while it is swapped out.

  If QuickBasic cannot be swapped out, the process is canceled.  If the
  swapped image of QuickBasic cannot be recovered, the situation is
  considered fatal and a call to Halt is made, invoking the main module
  ExitProc.  
}  
{==========================================================================}
{================================= Interface ==============================}
{==========================================================================}

INTERFACE


USES Dos, Crt, pdaSubs,
    XMS, EMS,
   SwapQB;


PROCEDURE RunSecondChild;


{==========================================================================}
{============================ Implementation ==============================}
{==========================================================================}
IMPLEMENTATION

    
{============================ Enable/Disable ===============================
A pair of complementary inline asm macros that the compiler inserts directly
into the executable code to enable and disable processor interrupts at the
point wherever the procedure reference appears in the source code.
}
{ Re-enable interrupts }
PROCEDURE Enable; INLINE( $FB );    { STI }

{ Disable interrupts }
PROCEDURE Disable; INLINE( $FA );    { CLI }



{===============================  RunSecondChild===========================}
{ This procedure is called from the popup to run a secondary child process.
  This occurs in conjunction with the Debugger, Build Exe, and Switch
  procedures.  It saves QB's context and swaps out QB to give the child
  process plenty of memory to run in, then puts everything back.


  External accesses:  ( including access by subordinate SwapQB routines )
      Variables                           Procedure calls
         Reg               W                 GetDir
         PatchOK           W                 SwapVectors
         QBInts            W                 Intr
         QBIVT[]           W                 DiskFree
         CurrentIVT[]      W                 Assign
         HimemSys                            Rewrite
         ptrXMSControl                       GetKey
         XMSXData          W                 Move
         EmmThere                            Exec
         EMMXMData         W                 GotoXY
         IOResult                            ClrEOL
         swDiskOnly                          TextMode
         WindMax           W                 Cursor_on
         WindMin           W                 ChDir
         init_max                            Delay
         init_min                            carryclear
         TextAttr          W                 Cursor_off
         OldAttr
         LastMode
         NoClrScrn
         segExecStack
         offExecStack
         QBExecReturn      W
         offTSRStackc
         segTSRStackc
         Child2Name
         Child2parms
         DosError
         FatalErrorCode    W
         TPIntsInIVT       W
			XEHandle          W
         AdapterMode       W
         CrtModeSet

}

PROCEDURE RunSecondChild;

Label Child2Canceled;

var
DOSmem, QBLength, SwapBytes   : LongInt;        { Vars. to hold QB length  }
QBMCBe, QBMCBc, QBPrefixSeg   : Word;           { and location in memory.  }
QBDrive                       : Byte;           { number from DOS, A=0...  }
QBSubdirectory                : String;         { Default while QB active  }
IntSeg                        : ^Word;          { Holds IVT seg, number and}
IntNum, i, QBInts             : Byte;           { counters to find QB ISR's}
ch2Result, swResult, sbResult : Byte;           { Child/swap result codes  }
swCh                          : Char;           { 'Press any key' into here}
canceled                      : Boolean;        { Flag to abort operation  }
swErrSource, swErrCode        : Byte;           { SwapQB result codes 0=OK }
WheresQB                      : Byte;           { Tells us where we put QB }

{ Variables used in saving video prior to Exec call }
ptrVidSaveArea, ptrVidBuffer  : Pointer;        { To/From addresses        }
ScreenRows, CurAttr           : Byte;           { QB's rows, our colors    }
ScreenBytes                   : Word;           { Color=8000, Momo = 2000  }
CurSaveX, CurSaveY, ScrMode   : Byte;           { Cursor loc, screen mode  }
CurWindSaveMax, CurWindSaveMin: Word;           { current window settings  }
ms_StateSize                  : Word;           { Bytes for mouse state    }
ms_StateStored                : Boolean;        { True when state stored   }
ms_StateStorage               : Pointer;        { loc on heap              }
OurVidMode                    : Byte;           { Current video adap state }


CONST
NOWHERE = 0;
XMS     = 1;                    { These constants represent places where we }
EMS     = 2;                    { might have swapped QB into.                }
DISK    = 3;

{ We have several things assumed by the time we get here:
   1. That we will have already saved a copy of the IVT ( at 0000:0000-FFFF )
      as it existed just before QB was EXEC'd.
   2. That we will have already examined this PC for XMS or EMS for possible
      swapping storage in lieu of a disk file.
   3. That we have saved the address of our PSP before EXEC'ing QB.
   4. That we are using an internal stack of our own, and not QB's, and not
      our ExecStack we switched in before exec'ing QB.
   5. That we came here from QB's edit loop, which means we have a text
      screen in effect and we are not in the midst of a DOS or BIOS call.
   6. That we have saved all CPU registers as QB had them.
   7. That all significant video settings and a copy of QB's screen
      image have been saved in our data space.
   8. For TP 6.0, we have preserved the values of the stack segment and
      pointer as they existed on entry to the Exec call that started QB as
      the first child process.
}

{----------------------------------------------------------------------------}
{ Make all procedures/functions local to give them access to local variables }
{----------------------------------------------------------------------------}


{=============================== ClearQBInts ==============================
Identifies interrupt vectors in the Interrupt Vector Table that have been
redirected by QB to Interrupt Service Routines within QB, saves these pointer
values, and then replaces them with the original contents of these vector
pointers saved in CurrentIVT before we Exec'd QB.  This routine also restores
the original values of interrupts we've hooked for ourselves, so that we are
left with a full set of the original vectors when we were started from DOS.
We do this with anything pointing between QB's PSP and the top of DOS memory
based on Int 13. The latter value converted to bytes must placed into the
long variable DosMem prior to this call.}
Procedure ClearQBInts;
Var
IntNum,  i  : Byte;
DosMemSeg   : Word;

Begin
{ Find int vectors pointing into QB's code (and list them, if debugging) }
(*Writeln('Interrupts pointing within QB:');*)
{Convert top of Dos memory to a segment }
DosMemSeg := (DosMem shr 4) + 1;
i := 0;
For IntNum := 0 to 255 Do
    Begin
    IntSeg := ptr(0, (IntNum shl 2) + 2);
    If (IntSeg^ > QBMCBc) and (IntSeg^ < DosMemSeg) then
       Begin
       If i < 30 then            { Only save first 30 QB vectors found }
         Begin
          QBIVT[i].Num := IntNum;
          QBIVT[i].Vector := MemL[ 0: (IntNum shl 2)];
       (*    WriteHexByte(IntNum);
          Write('=');
          WriteHexVect(QBIVT[i].Vector);
          Write(', '); *)
          Inc(i);
         End;
       End;
    End;
QBInts := i - 1;                    { $FF means no ints found for QB }
(*Write('Total of ',QBInts + 1); *)

{ Put the original copies of these vectors back into the current IVT, thus
   unhooking QB from the interrupt table }
Disable;                            { Disable rupts for safety. We do this }
If QBInts <> $FF Then               { for the duration of the whole set    }
   Begin                            { because a changed IVT entry could    }
   For i := 0 to QBInts Do          { call one that didn't change yet.     }
      Begin
      CurrentIVT[QBIVT[i].Num] := IVTSave[QBIVT[i].Num];
      End;
   End;
Enable;                             { Reenable rupts                 }
(*Write(', now unhooked,'); *)

{ Now unhook the rupts we took over when we popped up.  We want to have the
original values back in the IVT at the time we swap our TP vectors back in
so that the original DOS values contained in the SaveIntXX variables are
preserved for our eventual program end.}
Disable;
ptrInt3F^   := IVTSave[$3F];
ptrInt9^    := IVTSave[ $9];
ptrInt16^   := IVTSave[$16]; 
Enable;

End; { ClearQBInts }





{=============================== RestoreQBInts ==============================
Reverses the process of ClearQBInts by placing saved copies of QB's internal
interrupt service routines back into the Interupt Vector Table.  It also
restores the interrupts we "borrow" back from QB while in our pop up and
which were also swapped out during the execution of the second child.
}
Procedure RestoreQBInts;
Var
i     : Byte;

Begin
   {   Put back out ISR hooks we took over from QB at pop up. }
   Disable;
   ptrInt3F^ := Our3F;
   ptrInt9^ := Our9; 
   ptrInt16^ := Our16; 
   Enable;

   {---- Restore QB's interrupt vectors }
   { Swap the saved copy of QB's captured int vectors back into current IVT }
   Disable;                            { Disable rupts for safety          }
   If QBInts <> $FF Then               { Keep them off through the whole   }
      Begin                            { restoration process since one     }
      For i := 0 to QBInts Do          { could conceivably call another.   }
         Begin                         {  ( a long shot, but we're safe )  }
         CurrentIVT[QBIVT[i].Num] := QBIVT[i].Vector;
         End;
      End;
   Enable;                             { Reenable rupts                 }
   Writeln('QB vectors reattached.');

End; { RestoreQBInts }





{======== MAIN ROUTINE BEGINS HERE ============}
Begin
canceled := False;                             { flag to continue or not }



{  ---- First, we need to save all other QB context settings --- }
{Call DOS for Drive }
Reg.AH := $19;
Intr($21, Reg);
QBDrive := Reg.AL;                                 { 0 = A, etc       }

{ Call GetDir for directory }
GetDir(0, QBSubdirectory);                         { 0 = Default drive }

{ EMS page map up to Child2 to save/restore if it uses EMS. }




{ ---- Obtain QB's memory location, environment block, code block and
PrefixSeg.}
QBMCBe := PrefixSeg + MemW[PrefixSeg - 1: 3];
QBMCBc := QBMCBe + MemW[QBMCBe: 3] + 1;
QBPrefixSeg := QBMCBc + 1;
QBLength := LongInt(MemW[QBMCBc: 3]) shl 4;
{ Get the dos memory installed. }
Intr($12, Reg);
DOSMem := LongInt(Reg.AX)  * 1024;
{ Calc number bytes from QB to end of DOS memory. We do it this way, rather
than QBLength, since QB may have given memory back to DOS via SETMEM, then
put something in there that should be preserved. }
SwapBytes := DosMem - (LongInt(QBPrefixSeg) shl 4);




{---- Unhook any interrupts QB hooked, saving QB's entry addresses.
Set a flag to keep Int_8 handler from "Patching" our second child
as we fiddle with the Int 4 vector. It regards a change in int4 as a
signal that QB has loaded/unloaded/reloaded itself. }
PatchOK := False;

{ Call routine to put original DOS vectors into IVT in place of vectors
hooked by QB and us during pop up. We want a clean IVT prior to SwapVectors.
We unhook everything between QB's PSP and the top of Dos memory.}
ClearQBInts;

{ Put our own interrupts that we unhooked when calling QB, back in effect,
exchanging them with the saved DOS values we've just placed back in there. }
{ We'll need our vectors for dealing with any exceptions till new child is
called. }
SwapVectors;
TPIntsInIVT := True;                   { Mark TP's ISR's are hooked in  }




{---- Copy QB to safety }
{ Set up params for the save }
WheresQB := NOWHERE;                    { Not yet in XMS, EMS or DISK   }
XEHandle := 0;                          { Handle value save variable    }

{ Call the swap routine }
SwapOutQB(QBPrefixSeg, SwapBytes, WheresQB, swErrSource, swErrCode);

{ Errors at this point are recoverable. Back out via jump to Child2Canceled.}
If swErrSource > 0 Then
   Begin
   Case swErrSource Of
      XMS   :  Write('XMS');
      EMS   :  Write('EMS');
      DISK  :  Write('DISK');
   End; { Case }
   Writeln(' swap failed, code ',swErrCode,'. Operation canceled.');
   Write('Press a key ...');
   swCh := GetKey;
   Goto Child2Canceled;
   End;




{---- Call DOS to deallocate QB's memory }
{ Leave QB's PSP and a video save area }
Reg.AX := $4A00;
Reg.ES := QBPrefixSeg;
Reg.BX := 505;                          { room for large screen video   }
Intr($21, Reg);                         { 50 lines * 160 = 8000 bytes   }

{ A problem here is also recoverable, since we haven't overwritten anything.
  We can jump to Child2Canceled to restore the vectors. }
If not CarryClear Then
   Begin
   Writeln('QB memory shrink failed, code ', Reg.AX);
   Write('Operation canceled. Press a key ...');
   swCh := GetKey;
   Goto Child2Canceled;
   End;




{---- Save current screen (ours on top of QB's) }
ptrVidSaveArea := ptr(QBPrefixSeg + 5, 0);
IF Mem[$0: $463 ] = $B4 Then
   Begin
   ScreenBytes    := 2000;
   ptrVidBuffer   := ptr($B000, 0);             { Screen line 1 in mono }
   End
Else
   Begin
   ScreenBytes    := 8000;
   ptrVidBuffer   := ptr($B800, 0);             { Screen line 1 in color }
   End;

Move(ptrVidBuffer^, ptrVidSaveArea^, ScreenBytes);   { There goes screen }

{ And Cursor location }
CurSaveX := WhereX;
CurSaveY := WhereY;
Cursor_on;                                 { Reenable cursor for child2    }

{ Save window and color settings, then expand and restore start colors     }
ScrMode := LastMode;
CurAttr  := TextAttr;
OurVidMode := AdapterMode;                       { Current adapter value   }
CurWindSaveMax := WindMax;                       { current window settings }
CurWindSaveMin := WindMin;           
WindMax := init_max;                              { Go back to original    }
WindMin := init_min;                              { screen size.           }
TextAttr := OldAttr;                              { Restore original colors}
ScreenRows := Mem[$40:$84];                       { Get QB's # screen rows }
If ScreenRows = 0 Then ScreenRows := 24;
If Hi(WindMax) <> ScreenRows Then                 { and see if different   }
   Begin                                          { from ours, and if so,  }
   WindMax := WindMax and $00FF;                  { Clear original row val }
   WindMax := WindMax or Word(ScreenRows shl 8);  { & replace with QB's.   }
   End;

{ Save Mouse state if we have a mouse }
ms_StateStored := False;                          { assume we don't        }
If mouse_present then
   Begin
   { get size of storage required }
   asm
      mov ax, 21                                   { Mouse State Storage   }
      int ms_call                                  { Requirement func.     }
      mov ms_StateSize, bx
   end; {asm}
   If ms_StateSize < MaxAvail then                 { Only save if heap space}
      Begin
      GetMem(ms_StateStorage, ms_StateSize);
      Reg.ax := 22;                                { Save state, funct. 22  }
      Reg.dx := LongInt(ms_StateStorage) and $FFFF;{ at location passed in	 }
      Reg.es := LongInt(ms_StateStorage) SHR 16;   { ES:DX                  }
      Intr($33,Reg);
		ms_StateStored := True;
		Reg.ax := 0;                                 { Reset mouse to disable }
      intr($33, Reg);                              { QB's user interrupt    }
      end;
	End;




{ --- Clear screen and enable blink by default unless we have
  a /NOCLS command switch }
If not NoClrScrn Then
   Begin
   ClrScr;
   AdapterMode := AdapterMode or $20;     { Set bit 5                      }
   Port[CrtModeSet] := AdapterMode;       { send to adapter controller     }
   { Call BIOS for EGA/VGA systems }
   Reg.AX := $1003;                       { Toggle blink/intensity         }
   Reg.BL := 01;                          { 1 turns blink on              }
   Intr($10, Reg);
   End;




{---- Swap our vectors back out in preparation for calling new child }
SwapVectors;
TPIntsInIVT := False;                     { Mark TP's ISR's as unhooked }



{ ---- Stack switch }
{  We'd like  to set up a secondary execstack for second child, but ... 
   we will be using the same ss/sp as we did in the pending Exec of QB, so
   we must save the return address from that call, and restore it after this
   Exec call so that the return from the pending QB call works properly.  All
   this is necessary because the TP Exec call is not re-entrant -- it uses a
   single ss/sp storage area that is overwritten each call, which means that
   if we were to use a different stack here in this second call, Exec would
   switch this second stack in after QB ends, rather than the first stack, and
   the return from the first call would come back here instead of there. The
   ideal answer would be for us to preserve and restore the Exec ss/sp area.
   Unfortunately, the variables we need are hidden away in the DOS unit.
   Since we can't get at them, we'll preserve the return address on ExecStack.
   This fix is version specific to TP 6.0 and depends on an 8-byte parameter
   call stack, cleared by the Exec routine on return (retf 8), so that the
   return address we want is sp - 12, and the guarantee that we are setting
   up the offExecStack here to the exact same value of sp that existed on
   entry to the first Exec call. }
   QBExecReturn := MemL[ SegExecStack: offExecStack - $C ];


   { Now do the switch }
   INLINE
      (
      $FA/                    { cli                                     }
      $89/$26/offTsrStackc/   { mov offTsrStackc, sp ; Save TSR stack   }
      $8C/$16/segTsrStackc/   { mov segTsrStackc, ss                    }
      $8B/$26/offExecStack/   { mov sp, offExecStack ; Load Exec stack  }
      $8E/$16/segExecStack/   { mov ss, segExecStack                    }
      $FB                     { sti                                     }
      );



{---- Exec the second child }
Exec(Child2Name, Child2parms);



{---- Restore our TSR stack }
INLINE
   (
   $FA/                       { cli                  }
   $8B/$26/offTsrStackc/      { mov  sp, offTsrStackc }
   $8E/$16/segTsrStackc/      { mov  ss, segTsrStackc }
   $FB                        { sti                  }
   );

{ Now that we are back from our second Exec call, stuff the return address
   of our first Exec call back into the Exec stack that Exec will be using
   after QB exits.  TP 6.0 }
MemL[ SegExecStack: offExecStack - $C ] := QBExecReturn;



{ --- Preserve how things went for child, but defer
   any reports till we get our video, etc back }
ch2Result := DosError;



{ Restore our vectors }
SwapVectors;
TPIntsInIVT := True;                   { Mark TP's ISR's are hooked in  }




{ --- Wait for keypress before clearing child's screen
  this prompt goes on the child's display, whatever that is.}
GotoXY(1,25);
ClrEOL;
Write('Dos exit code ',DosExitCode,'. Press any key to continue');
{Write('V: ',OurVidMode,' A: ',AdapterMode,' C: ',CrtModeSet); }
swCh := GetKey;


{ ----Video stuff }
{  Compare text modes/colors to what we had before EXEC'ing and restore
   along with drive/subdirectory and anything else that must be put back
   to what is was before we called the kid. }

{ Also clears the screen. This is not always guaranteed to properly catch
 all possible CGA/EGA/VGA mode and point combinations. }
If Mem[$40:$84] <> ScreenRows Then           { If Child changed QB's rows,}
   Begin                                     { cross fingers; assume not  }
   If ScreenRows > 25 then                   { mono since rows changed, & }
      TextMode(C80 + Font8x8)                { set to 43/50 line screen,  }
   Else
      TextMode(Lo(LastMode));                { or set to 25, if it was.   }
   End;
WindMax := CurWindSaveMax;                       { window settings }
WindMin := CurWindSaveMin;
TextAttr := CurAttr;                       { Restore current    colors   }
GotoXY(CurSaveX, CurSaveY);                { Put curs where it was < Exec}
Cursor_on;                                 { Reenable cursor for now     }

{ Restore previous screen mode blink/intensity, if needed. }
If OurVidMode <> AdapterMode Then
   Begin
	AdapterMode := OurVidMode;             { Restore prior adapter cmd set  }
   Port[CrtModeSet] := AdapterMode;       { send to adapter controller     }
   { Call BIOS for EGA/VGA systems }
   Reg.AX := $1003;                       { Toggle blink/intensity         }
   Reg.BL := 00;                          { 0 turns blink off              }
   Intr($10, Reg);
   End;

{ Screen coming back }
Move(ptrVidSaveArea^, ptrVidBuffer^, ScreenBytes);  { Our/QB screen back }

{ Mouse restore }
If ms_StateStored Then
   begin
   Reg.ax := 23;
   Reg.dx := LongInt(ms_StateStorage) and $FFFF;
   Reg.es := LongInt(ms_StateStorage) SHR 16;
	Intr($33,Reg);
   ms_StateStored := False;
   FreeMem(ms_StateStorage, ms_StateSize);
	end;



{ ---- Restore other context settings }
{ Drive and Subdirectory.  Call DOS for Drive, see if changed. }
Reg.AH := $19;
Intr($21, Reg);
If Reg.AL <> QBDrive Then                          { change it back  }
   { Possible error via criterr
    is picked up in ChDir that follows.}
   Begin
   Reg.AH := $0E;
   Reg.DL := QBDrive;                              { 0 = A, etc       }
   Intr($21, Reg);
   End;

{ Call ChDir to restore subdirectory }
{$I-}ChDir(QBSubdirectory);{$I+}
swResult := IOResult;
If swResult <> 0 Then                  { Maybe trouble here, we won't be }
   Begin                               { able to retrieve QB, if on disk }

   { Just indicate the condition at this point, as a warning. }
   Writeln('Error code ',swResult,' restoring subdirectory ',QBSubdirectory);
   Delay(3000);

   { Now, see if fatal ... and terminate program if it is. }
   If WheresQB = DISK Then
      Begin
      Writeln('QB is unrecoverable.');
      Write('Press a key to exit to DOS ...');
      swCh := GetKey;
      TextMode(LastMode);
      Halt( swErrCode );         { Unexpected end of program, pass code    }
      End;
   End;                       { We'll leave via ExitProc in main program }




{ See if everything went OK for our second child }
If ch2Result > 0 then
   Begin
   Write('Error code ',ch2Result,' invoking ',Child2Name);
   If ch2Result = 2 then Write(' -- program not found.')
   Else if ch2Result = 8 then Write(' -- insufficient memory.');
   Writeln;
   Delay(3000);
   End
Else
   Writeln;




{---- Ask DOS to reallocate QB's memory }
Reg.AX := $4A00;
Reg.ES := QBPrefixSeg;
Reg.BX := QBLength shr 4;
Intr($21, Reg);

{ If problem, it's fatal, otherwise go on to reload QB }
If not CarryClear Then
   Begin
   Writeln('DOS memory restore failure.');
   swErrSource := 4;                      { Set codes for the later     }
   swErrCode   := Reg.AX;                 { routine that handles fatal  }
   End                                    { errors coming out of swap.  }
Else
   Begin
   {Got memory, so reload QB }
   Writeln('Reloading QuickBasic.');
   SwapInQB(QBPrefixSeg, SwapBytes, WheresQB, swErrSource, swErrCode);
   End;



{--- Give message and terminate everything if fatal error encountered in
   either the memory allocation or swap for QB's reloading.  W/out QB, there
   is no point in continuing. Hopefully, there will not have been unsaved
   basic program text in QB at the time we were popped up -- it will be lost.}
If swErrSource > 0 Then
   Begin
   Case swErrSource Of
      XMS   :  Write('XMS');
      EMS   :  Write('EMS');
      DISK  :  Write('DISK');
      4     :  Write('QB');
   End; { Case }
   Writeln(' swap failed, code ',swErrCode,'. QB is unrecoverable.');
   Write('Press a key to exit to DOS ...');
   swCh := GetKey;
   TextMode(LastMode);
   Halt( swErrCode );         { Unexpected end of program, pass code    }
   End;                       { We'll leave via ExitProc in main program }




Child2Canceled:
{ Clear out the TP vectors in preparation for restoring QB's and our popup }
SwapVectors;
TPIntsInIVT := False;                     { Mark TP's ISR's as unhooked }

{ Now put the saved QB vectors, and our vectors we borrowed back from QB
while in this pop up routine, back into their proper places in the IVT }
RestoreQBInts;

PatchOK := True;                  {  Safe for int_8 to patch now, if needed}
cursor_off;



End; { RunSecondChild }

End. { Of Unit Child2 }

