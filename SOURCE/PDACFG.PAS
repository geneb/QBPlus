{-------------------------------------------------------------------------

                                    PDACFG  

            Unit to handle configuration settings for QB Plus

                  Written for Borland Turbo Pascal V 6.0

                     Copyright 1991, by John H. Eckert
                           All Rights Reserved


                                                   ... a component of the
                                                   QuickBasic Programmer
                                                   Desk Accessories ...
-------------------------------------------------------------------------}
{ History:           
01/15/91   0.30   Unit created out of the standalone QBMacro utility and
                  other various programs.
02/10/91   0.70   Save and load configuration data functions added.
04/08/91   0.85   Incorporate use of RTC selection in config file.
05/15/91   0.93   Preserve original options on user ESC.
06/10/91   0.94   Name change support of PDA to QB Plus.
10/10/91   1.10   Unit created to support console configuration, config file
						structure changed to match.
}
{-------------------------------------------------------------------------}
{$F+}                               { Far calls needed for overlays }
{$O+}                               { Unit may be overlaid          }
UNIT PDACFG;

{ This unit takes care of configuration setting, including loading and saving
	settings from and to file.  Makes calls to DbgName, pdacfgo and pdacfgc
	for debugger, console and other user settings input.
 }

{==========================================================================}
{================================= Interface ==============================}
{==========================================================================}
INTERFACE


USES Crt, Dos, pdaSubs, dbgName, pdacfgo, pdacfgc;

PROCEDURE ConfigSetting;                  { User's change settings code    }
FUNCTION SaveCFG : Word;                  { Writes Cfg vars to Cfg file    }
FUNCTION LoadCFG : Word;                  { Retrieves Cfg vars from file   }

{==========================================================================}
{============================ Implementation ==============================}
{==========================================================================}

IMPLEMENTATION

{=============================  SaveCfg ===================================
  Writes variables that constitute the user definable configuration setup
  to the file QBP.CFG.  It's in the same subdirectory as we (QBP.EXE) are;
  unless we can't find ourselves, in which case we'll write the file in the
  current directory.  The Result code returned is equal to the DosError
  series. See the body of code for variables saved. Called by ConfigSetting.
}
FUNCTION SaveCfg : Word;

Label  EndSaveCfg;

{ Declare a record to hold all the desired config variables }
Type
CfgRec = RECORD
   cPopUpKeyOpt      : Byte;
   cQBSwapName       : String13;
   cAutoSaveInt      : Byte;
   cDirectView       : Boolean;
   cPortViewEnabled  : Boolean;
   cRealTime         : Boolean;
   cNoClrScrn        : Boolean;
   cswDiskOnly       : Boolean;
   cDebugger         : PathStr;
   cDbgOpts          : String24;
   cEndRecordKeyOpt  : Byte;
   cPlayKeyOpt       : Byte;
   cPlayPauseInt     : Byte;
   cSampleInterval   : Byte;
   cUse_Rtc          : Boolean;
	cCheckSnow        : Boolean;
	cForeColor        : Byte;
	cBackColor        : Byte;
   cKeyBdAutoSet     : Boolean;
   cKeyCPS           : Byte;
   cKeyDelay         : Byte;
	End; { Cfg Record }

Var
ptrCfg         : ^CfgRec;        { Used to access Cfg values when on heap  }
ErrCode        : Word;           { Temporary storage of error info         }
CfgFile        : File of CfgRec; { Our Cfg file handle                     }
CfgPath        : PathStr;        { Cfg's full pathname                     }
CfgDir         : DirStr;         { Cfg's drive and directory               }
CfgName        : NameStr;        { Cfg's name                              }
CfgExt         : ExtStr;         { Cfg's extension                         }

Begin
{ Put together a filename for Cfg based on our EXE path & name }
FSplit(Paramstr(0), CfgDir, CfgName, CfgExt);
If CfgName = '' then CfgName := 'QBP';    { In case we don't know own name }
CfgPath := CfgDir + CfgName + '.CFG';

{ Gather up the variables to be saved on the heap }
GetMem( ptrCfg, SizeOf(CfgRec));
ptrCfg^.cPopUpKeyOpt       := PopUpKeyOpt;
ptrCfg^. cQBSwapName       := QBSwapName;
ptrCfg^. cAutoSaveInt      := AutoSaveInt;
ptrCfg^. cDirectView       := DirectView;
ptrCfg^. cPortViewEnabled  := PortViewEnabled;
ptrCfg^. cRealTime         := RealTime;
ptrCfg^. cNoClrScrn        := NoClrScrn;
ptrCfg^. cswDiskOnly       := swDiskOnly;
ptrCfg^. cDebugger         := Debugger;
ptrCfg^. cDbgOpts          := DbgOpts;
ptrCfg^. cEndRecordKeyOpt  := EndRecordKeyOpt;
ptrCfg^. cPlayKeyOpt       := PlayKeyOpt;
ptrCfg^. cPlayPauseInt     := PlayPauseInt;
ptrCfg^. cSampleInterval   := SampleInterval;
ptrCfg^. cUse_Rtc          := Use_Rtc;
ptrCfg^. cCheckSnow        := CheckSnow;
ptrCfg^. cForeColor        := ForeColor;
ptrCfg^. cBackColor        := BackColor;
ptrCfg^. cKeyBdAutoSet     := KeyBdAutoSet;
ptrCfg^. cKeyCPS           := KeyCPS;
ptrCfg^. cKeyDelay         := KeyDelay;

{ open the file and save the record from the heap }
Assign(CfgFile, CfgPath);
ErrCode := 0;
DosError := 0;
{$I-}                                   { Disable error handler, open & }
Rewrite(Cfgfile);{$I+}                  { empty the file.               }
ErrCode := IOResult;

If ErrCode <> 0 Then Goto EndSaveCfg     { Attempted open failed, exit  }
Else
   Begin                                 { We're open, now write the    }
   {$I-} Write(CfgFile, ptrCfg^);        { one and only record.         }
   ErrCode := IOResult;
   Close(CfgFile);  {$I+}                { OK, now try and close        }
   ErrCode := IOResult;
   End;

EndSaveCfg:
{ Tidy things up before leaving }
FreeMem( ptrCfg, SizeOf(CfgRec));        { Release the heap memory.     }
SaveCfg := ErrCode;                      { Pass back the result code.   }

End; { SaveCfg }




{=============================  LoadCfg ===================================
  Retrieves variables that constitute the user definable configuration setup
  from the file QBP.CFG.  We look for it in the same subdirectory as we
  (QBP.EXE) are; then in the in the current directory.  The Result code
  returned is equal to the DosError series. See the body of code for
  variables saved. Called by PDAInit unit at start prior to command line
  switching, so that the latter take priority.
}
FUNCTION LoadCfg : Word;

Label  EndLoadCfg;

{ Declare a record to hold all the desired config variables }
Type
CfgRec = RECORD
   cPopUpKeyOpt      : Byte;
   cQBSwapName       : String13;
   cAutoSaveInt      : Byte;
   cDirectView       : Boolean;
   cPortViewEnabled  : Boolean;
   cRealTime         : Boolean;
   cNoClrScrn        : Boolean;
   cswDiskOnly       : Boolean;
   cDebugger         : PathStr;
   cDbgOpts          : String24;
   cEndRecordKeyOpt  : Byte;
   cPlayKeyOpt       : Byte;
   cPlayPauseInt     : Byte;
   cSampleInterval   : Byte;
   cUse_Rtc          : Boolean;
   cCheckSnow        : Boolean;
	cForeColor        : Byte;
	cBackColor        : Byte;
   cKeyBdAutoSet     : Boolean;
   cKeyCPS           : Byte;
   cKeyDelay         : Byte;
   End; { Cfg Record }

Var
ptrCfg         : ^CfgRec;        { Used to access Cfg values when on heap  }
ErrCode        : Word;           { Temporary storage of error info         }
CfgFile        : File of CfgRec; { Our Cfg file handle                     }
CfgPath        : PathStr;        { Cfg's full pathname                     }
CfgDir         : DirStr;         { Cfg's drive and directory               }
CfgName        : NameStr;        { Cfg's name                              }
CfgExt         : ExtStr;         { Cfg's extension                         }

Begin
{ Put together a filename for Cfg based on our EXE path & name }
FSplit(Paramstr(0), CfgDir, CfgName, CfgExt);
If CfgName = '' then CfgName := 'QBP';    { In case we don't know own name }
CfgPath := CfgDir + CfgName + '.CFG';

{ See if such a file exists in that directory }

{ Try the current directory }


{ Reserve space on heap for the variables in file }
GetMem( ptrCfg, SizeOf(CfgRec));


{ open the file and put the record on the heap }
Assign(CfgFile, CfgPath);
ErrCode := 0;
DosError := 0;
{$I-}                                   { Disable error handler, open & }
ReSet(Cfgfile);{$I+}                    { set pointer to start.         }
ErrCode := IOResult;

If ErrCode <> 0 Then Goto EndLoadCfg     { Attempted open failed, exit  }
Else
   Begin                                 { We're open, now read record  }
   {$I-} Read(CfgFile, ptrCfg^);         { There is only one.           }
   ErrCode := IOResult;
   Close(CfgFile);  {$I+}                { OK, now try and close        }
   ErrCode := IOResult;
   End;

{ Copy the settings into the actual variables }
PopUpKeyOpt       := ptrCfg^.cPopUpKeyOpt;
QBSwapName        := ptrCfg^.cQBSwapName;
AutoSaveInt       := ptrCfg^.cAutoSaveInt;
DirectView        := ptrCfg^.cDirectView;
PortViewEnabled   := ptrCfg^.cPortViewEnabled;
RealTime          := ptrCfg^.cRealTime;
NoClrScrn         := ptrCfg^.cNoClrScrn;
swDiskOnly        := ptrCfg^.cswDiskOnly;
Debugger          := ptrCfg^.cDebugger;
DbgOpts           := ptrCfg^.cDbgOpts;
EndRecordKeyOpt   := ptrCfg^.cEndRecordKeyOpt;
PlayKeyOpt        := ptrCfg^.cPlayKeyOpt;
PlayPauseInt      := ptrCfg^.cPlayPauseInt;
SampleInterval    := ptrCfg^.cSampleInterval;
Use_Rtc           := ptrCfg^.cUse_Rtc;
CheckSnow         := ptrCfg^.cCheckSnow;
ForeColor         := ptrCfg^.cForeColor;
BackColor         := ptrCfg^.cBackColor;
KeyBdAutoSet      := ptrCfg^.cKeyBdAutoSet;
KeyCPS	         := ptrCfg^.cKeyCPS;
KeyDelay	         := ptrCfg^.cKeyDelay;

EndLoadCfg:
{ Tidy things up before leaving }
FreeMem( ptrCfg, SizeOf(CfgRec));        { Release the heap memory.     }
LoadCfg := ErrCode;                      { Pass back the result code.   }

End; { LoadCfg }





{===========================  ConfigSetting ===============================
   This is the main configuration setting menu, with local procedures for
   handling the debugger, macro key and other settings information obtained
   from the user.  Called by the main PDA menu, it also calls the SaveCfg
   function to store settings to disk.}
PROCEDURE ConfigSetting;
VAR
Title                         : String13;
Prompt                        : String70;
SaveResult                    : Word;

CONST
PlayKey          : Array[1..3] of String11 = ('Caps Lock',
                                             'Scroll Lock',
                                             'Num Lock');
CombKey          : Array[1..2] of String13 = ('Control-Shift',
                                             ' Both Shifts ');


{ =============================  CommandKeySelect  ========================
}
PROCEDURE CommandKeySelect;
VAR
{ Local variables to store options till user says "change" with Enter key }
tPlayKeyOpt       : Byte;
tEndRecordKeyOpt  : Byte; 
tPopUpKeyOpt      : Byte;
tPlayPauseInt     : Byte;

BEGIN

{We used a smaller window in the QBMacro program }
ClrScr;
ULRow := 5;
ULCol := 9;
Window( ULCol, ULRow, LLCol - 2, LLRow );
Box(WhereX, WhereY, Lo(WindMax) - Lo(WindMin) - 1, 14);

{ Put options into temporary variables }
tPlayKeyOpt       := PlayKeyOpt;
tEndRecordKeyOpt  := EndRecordKeyOpt;
tPopUpKeyOpt      := PopUpKeyOpt;
tPlayPauseInt     := PlayPauseInt;

cursor_on;
Repeat
   GotoXY(26,2);Write('Macro Keys');
   GotoXY(10,4);Write('<P>layback key (',PlayKey[tPlayKeyOpt],')   ');
   GotoXY(16,5);Write('(must be "double tapped")');
   GotoXY(10,7);Write('<E>nd Keystroke record sequence (',CombKey[tEndRecordKeyOpt],')');
   GotoXY(16,8);Write('(press keys in combination)');
   GotoXY(10,10);Write('<M>enu pop up key (',CombKey[tPopUpKeyOpt],')');
   GotoXY(16,11);Write('(press keys in combination)');
   GotoXY(10,13);Writeln('<D>elay between play keystrokes = ',tPlayPauseInt,'/18th sec. ');

   GotoXY(19,16);Write('< OK >     < Esc = Cancel >'); GotoXY(21,16);
   Repeat
   Ch := GetUpKey;
   Until (Ch IN ['P','E','M','D',#27 ,#13]);
   Case Ch of
   'P' : Begin
         Inc(tPlayKeyOpt);
         If tPlayKeyOpt > 3 then tPlayKeyOpt := 1;
         End;
   'E' : Begin
         Inc(tEndRecordKeyOpt);
         If tEndRecordKeyOpt > 2 then tEndRecordKeyOpt := 1;
         End;
   'M' : Begin
         Inc(tPopupKeyOpt);
         If tPopupKeyOpt > 2 then tPopupKeyOpt := 1;
         End;
   'D' : Begin
         Inc(tPlayPauseInt);
         If tPlayPauseInt > 18 then tPlayPauseInt := 0;
         End;
   End;
Until (Ch IN [#27, #13]);

{ If Enter, make the temporaries permanent }
IF Ch = #13 then
   Begin
   PlayKeyOpt        := tPlayKeyOpt;
   EndRecordKeyOpt   := tEndRecordKeyOpt;
   PopUpKeyOpt       := tPopUpKeyOpt;
   PlayPauseInt      := tPlayPauseInt;
   End;


{ Undo QBMacro's smaller window size }
ULRow := 4;
ULCol := 4;
Window( ULCol, ULRow, LLCol, LLRow );
cursor_off;
ClrScr;
END; { CommandKeySelect }



{====== THE MAIN PART OF UNIT ======}
{ We can either give a main menu, or just chain the pages together
 for the various selection categories, ie startup switch overrides, etc. }
Begin

Title    := ' Settings ';

Repeat
   Prompt   := ' Press the key corresponding to desired selection ';
   BorderTitlePrompt(Title, Prompt);
   ClrScr;
   Box(19, 2, LLCol - ULCol - 35, LLRow - ULRow - 3);
   GotoXY(25,4);Write('<D>ebugger settings');
	GotoXY(25,6);Write('<M>acro key settings');
   GotoXY(25,8);Write('<C>olor settings');
   GotoXY(25,10);Write('<K>eyboard settings');
   GotoXY(25,12);Write('<O>ther settings');
   GotoXY(25,14);Writeln('<S>ave settings to file');

   GotoXY(20,18);Write('<D, M, C, K, O, S>    <Esc = Quit>'); GotoXY(43,18);
   cursor_on;

   Repeat
   Ch := GetUpKey;
	Until (Ch IN ['D','M','O','S','C','K',#27 ,#13]);

   Cursor_off;
   IF Ch = #13 then Ch := #27;
   Case Ch of
   'D' : Begin
         { Setup prompt line for GetDebuggerInfo}
         Prompt   := ' Tab=Next box  Shift-tab=Prev box  Enter=Accept  Esc=Quit ';
         BorderTitlePrompt(Title, Prompt);
         GetDebuggerInfo;
         {Window( ULCol, ULRow, LLCol, LLRow ); }
         Ch := #0;                            { Stay in Cfg menu     }
         End;
   'M' : Begin
         CommandKeySelect;
         Ch := #0;                            { Stay in Cfg menu     }
         End;
   'O' : OtherSettings;
   'C' : ColorSettings;
   'K' : KeyBoardSettings;
	'S' : Begin
         ClrScr;
         GotoXY(5, 8);
         Writeln('Saving configuration settings.');
         SaveResult := SaveCfg;
         If SaveResult <> 0 Then
            Begin
            GotoXY(5,11);
            Write('Error code ',SaveResult,' encountered.  Press a key ...');
            Ch := GetKey;
            Ch := #0;                         { Stay in Cfg menu     }
            End;
         End;
      End; {Case}
Until Ch IN [#27 ,#13];



Ch := #0;                              { Stay in main menu on return    }

End; {MacroMenu }

END. { QBM Unit }
