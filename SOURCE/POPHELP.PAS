{-------------------------------------------------------------------------
                                    PopHelp

               Unit to handle main popup window and main help

                  Written for Borland Turbo Pascal V 6.0

                     Copyright 1991, by John H. Eckert
                           All Rights Reserved


                                                   ... a component of the
                                                   QuickBasic Programmer
                                                   Desk Accessories ...
-------------------------------------------------------------------------}
{ History:           
02/07/91   0.60   Pulled out of the main PDA module.
04/15/91   0.86   Follow PATH to find PDABUILD.EXE
06/10/91   0.94   Name change support of PDA to QB Plus.
10/10/91   1.10   Store colors directly to TextAttr, since TP's TextColor
						and TextBackGround routines suppress bit 7 and thereby
                  limit background to 8 colors.
}
{-------------------------------------------------------------------------}
{$F+}                               { Far calls needed for overlays }
{$O+}                               { Unit may be overlaid          }
UNIT PopHelp;

{ Although representing some performance compromise, placing the main pop up
window and its associated support routines and help screen into an overlaid
unit reduces the size of resident code.  Since exit from QB Plus back to QB
is always via this unit, it will always be resident in the overlay buffer
whenever the popup keys are pressed (except for the very first time), and
thus will respond instantly. Called from the main QB Plus unit, it then
calls other overlay units to handle the menu subfunctions.
}

{==========================================================================}
{================================= Interface ==============================}
{==========================================================================}
INTERFACE


USES  Crt, Dos, pdaSubs,  Child2, swName, dbgName,
      mv,
      QBC, QBCGet, QBM, QBMFile, PDACFG, PDAEDLN,
      PDAProf;

PROCEDURE Popup;                 { The main pop up code     }
PROCEDURE HelpScreen;            { The main help screen     }


{==========================================================================}
{============================ Implementation ==============================}
{==========================================================================}

IMPLEMENTATION

PROCEDURE SaveScreen(VAR ptrVidSave : Pointer);
{ Copies screen contents to heap at ptrVidSave. The screen's base
  address will already have been placed into the word, AdapterBase,
  and the portion of screen to save is in the constant declarations.
  These must match those in the complementary procedure, RestoreScreen.
}

Const
VidOffset   = 320;                     { Start of video line 4             }
VidSize     = 3520;                    { Bytes to save, lines 4 thru 25    }

Var
ptrVidBuffer : Pointer;                { Source pointer to video to save   }

Begin
{Make a pointer into the video buffer }
ptrVidBuffer := ptr(AdapterBase, VidOffset);

GetMem(ptrVidSave, VidSize);           { Allocate heap, and move the video }
Move(ptrVidBuffer^,ptrVidSave^,VidSize); { contents to it.                 }

End; { SaveScreen }
 


PROCEDURE RestoreScreen(VAR ptrVidSave : Pointer);
{ Copies heap bytes at the pointer argument to the screen at the
  location given by the constant declarations, which must match those
  in the complementary procedure, SaveScreen. The screen's base
  address will already have been placed into the word, AdapterBase.
}

Const
VidOffset   = 320;                     { Start of video line 4             }
VidSize     = 3520;                    { Bytes to save, lines 4 thru 25    }

Var
ptrVidBuffer : Pointer;                { Source pointer to video to save   }

Begin
{Make a pointer into the video buffer }
ptrVidBuffer := ptr(AdapterBase, VidOffset);

Move(ptrVidSave^,ptrVidBuffer^,VidSize); { Move heap bytes to video area   }
FreeMem(ptrVidSave, VidSize);          { and release heap.                 }

End; { RestoreScreen }
 





{ ===============================  Help/Instructions ========================
}
Procedure HelpScreen;
Begin
Title :=  ' General Help ';
BorderTitlePrompt(Title, Prompt);
ClearPrompt;
ClrScr;

Repeat
   Writeln;
   Writeln(' o  Use Build to compile and link your program from within QB');
   Writeln('    using all available compiler and linker options.');
   Writeln;
   Writeln(' o  Invoke external Debugger for program listed in Change Settings.');
   Writeln;
   Writeln(' o  The Profiler analyzes a program while it executes to show where');
   Writeln('    the program spends most of its execution time.');
   Writeln;
   Writeln(' o  View conventional | expanded | extended memory, the I/O ports');
   Writeln('    and CMOS area by byte, word, integer, long integer and vector.');
   Writeln;
   Writeln(' o  Record key strokes as a Macro to play back from a single key.');
   Writeln;
   Writeln(' o  Use Switch to jump between Quickbasic and other programs.');
   Writeln;
   Writeln(' o  Customize the desk accessories to your preferences.');


   GotoXY(33, 19); Write('< OK >'); GotoXY(35,19);
   cursor_on;
   Ch := GetKey;
   cursor_off;

Until  (Ch = #27) or (Ch = #13);
Ch := #0;
ClrScr;
End; { Help information }



{===============================  PopUp  ===========================}
PROCEDURE PopUp;
LABEL PopUpDone;

VAR
NoClrScrnSave     : Boolean;           { Temp storage of NoClrScrn switch }
FoundName         : SearchRec;         { FSearch results                   }
PathList          : String absolute ExecStack;  { Borrow from bottom of it }

BEGIN
Popped := True;                        { in use flag }
IF Mouse_present THEN ms_hide;         { Turn off mouse cursor          }
init_max := WindMax;                    { save original window size     }
init_min := WindMin;                    { save original window size     }
SaveScreen(PtrScreenStore);             { save current screen contents  }
CurX := WhereX;                         { save cursor location          }
CurY := WhereY;
OldAttr  := TextAttr;                   { Save current color }
{Save the QB cursor size for us to restore on return to QB.  The first  }
{call to Cursor_on sets the cursor size to the one we got from DOS.     }
Reg.AX := $0F00;                       { Get current display mode for   }
Intr($10, Reg);                        { active display page needed in  }
Reg.AX := $0300;                       { the read cursor info call.     }
                                       { It is in BH.                   }
Intr($10, Reg);                        { Returns cursor size in CX      }
QBCurSize := Reg.CX;                   { Put it away.                   }

{ Create a bordered window at rows 3 - 20, Cols 3 to 73 }
ULRow := 4;                             { Location of upper left of }
ULCol := 4;                               {     our pop up box       }
LLCol := Lo(WindMax) - 4;
LLRow := 25 - 3;        {LLRow := Hi(WindMax) - 3; for a large window }
{ Do the shadow shifted 1 down and 2 right}
TextBackGround( Black );                 { Color is black on anything      }
Window( ULCol + 1, ULRow, LLCol + 3, LLRow + 2 );
ClrScr;                                 { Paint it black. }
WindMax := init_max;                    { restore original window size  }
WindMin := init_min;                    { restore original window size  }
{ Set colors -- direct to TextAttr to preserve hi-intensity background  }
{ Note: QB's default is hi-intensity (not blink), just like us.         }
TextAttr := (TextAttr AND $0F) or (BackColor Shl 4); 
TextAttr := (TextAttr and $F0) or ForeColor;


Repeat
   cursor_off;
   Prompt   := ' Press key corresponding to desired selection ';
   Title    := ' QB Plus ';
   BorderTitlePrompt(Title,       { Show border, title and prompt.}
                     Prompt);
   ClrScr;                                 { Paint inside white.           }
   {Write('   for QuickBasic'); }
   { Options Box }
   Box(12, 2, LLCol - ULCol - 21, LLRow - ULRow - 3);
   GotoXY(20,13);Write('<S>witch programs  <C>hange settings');
   GotoXY(20,10);Write('<V>iew memory      <M>acro keystrokes');
   GotoXY(20, 4);Write('<B>uild Executable Program File');
   GotoXY(20, 7);Write('<D>ebugger         <P>rofiler');

   GotoXY(25,18);Write('<Esc=Cancel>      <Help>');
   cursor_on;                         { This sets cursor to our cursor  }
   GotoXY(44,18);


   Repeat
      Ch := GetUpKey;
   Until (Ch IN ['S','V','B','M','C','D','P',#27 ,#13]);

   IF Ch = #13 then Ch := 'H';
   cursor_off;

   Case Ch of
   'P' : Profiler;
   'V' : ViewMemory;
   'H' : HelpScreen;
   'D' : Begin
         Child2Name := Debugger;             { Specified debugger pathspec }
         { Automatically use the name of the current Build EXE file, if there
         is one. }
         If (DebugFile = '') and (Length(MainModPath) > 0) Then
            DebugFile := MainModDir + MainModName + '.EXE';
         Child2Parms := DbgOpts + ' ' + DebugFile;
         ClrScr;
         If DebugFile <> '' then
            Begin
            Writeln('Executing ',Child2Name, Child2Parms);
            RunSecondChild;
            End
         Else
            Begin
            Writeln('You must first specify a program to debug.');
            Writeln('Enter its file name in the Debugger portion of Settings menu.');
            Write('Press a key to return to the main menu . . .');
            Ch := GetKey;
            Ch := #0;
            End;
         End;
   'M' : MacroMenu;
   'B' : Begin
         Compile := False;
         GetOptions;
         If Length(MainModPath) > 0 Then EditOptions;
         If Compile Then
            Begin
            Child2Name  := 'QBPBUILD.EXE';    { Builder name and target.   }
            { Look for it in the current directory }
            FindFirst(Child2Name, Archive, FoundName);
            If DosError <> 0 Then
               Begin                  { Not found, build a search path list }
               FSplit(ParamStr(0), MacDir, MacName, MacExt);   { Our dir.   }
               { Add our directory to Dos Path }
               PathList := GetEnv('PATH') + ';' + MacDir;
               Child2Name  := FSearch(Child2Name, PathList);
               End;
            If Child2Name = '' Then
               Begin
               Write('QBPBUILD.EXE not found. Press a key..');
               Ch := GetKey;
               End
            Else
               Begin
               Child2Parms :=  MainModDir + MainModName + '.MQK';
               NoClrScrnSave := NoClrScrn;   { Save NoClrScrn state and    }
               NoClrScrn :=  False;          { set to clear screen.        }
               RunSecondChild;               { Run the .EXE builder.       }
               NoClrScrn := NoClrScrnSave;   { Restore NoClrScrn switch    }
               End;
            End;
         End;
   'S' : Begin
         GetChild2;
         If not swCanceled then RunSecondChild;
         End;
   'C' : ConfigSetting;
   Else
   End;  { Case }

Until (Ch = #27);

PopUpDone:
{ Restore initial window }
WindMax := init_max;                   { save original window size      }
WindMin := init_min;                   { save original window size      }
RestoreScreen(PtrScreenStore);         { restore screen contents        }
GotoXY(CurX, CurY);                    { and cursor location...         }
TextAttr := OldAttr;                   { Restore original color         }
Reg.AX := $0100;                       { Restore original cursor size   }
Reg.CX := QBCurSize;
Intr( $10, Reg );
IF Mouse_present THEN ms_show;         { Turn on mouse cursor           }
Popped := False;                       { Safe to call now ...           }
END;

End. {PopHelp Unit}
