{-------------------------------------------------------------------------
                                    pdaInit

                  Unit to initialize variables in QB Plus

                  Written for Borland Turbo Pascal V 6.0

                     Copyright 1991, by John H. Eckert
                           All Rights Reserved


                                                   ... a component of the
                                                   QuickBasic Programmer
                                                   Desk Accessories ...
-------------------------------------------------------------------------}
{ History:           
01/11/91   0.20   Created out of PDA main module, and support unit
                  initialization code.
04/08/91   0.85   Real time clock initialization added.
04/15/91   0.86   Support for QB/X not in current directory.
04/25/91   0.88   Call to initialize PDAMath unit.
05/06/91   0.92   Search PDA's path for QB, accomodate space delimimted
                  Parm variable.
06/10/91   0.94   Name change support of PDA to QB Plus.
06/24/91   0.95   Windows 386 protection added to memory viewer.
10/10/91   1.10   Init the keyboard and colors.
}
{-------------------------------------------------------------------------}
{$F+}                               { Far calls needed for overlays }
{$O+}                               { Unit may be overlaid          }
UNIT pdaInit;

{ By gathering all of the one-time startup stuff into one module, we reduce
memory otherwise required if startup code for each unit were left in the
various units.  This way, initialization code is loaded once, and discarded.
}

{==========================================================================}
{================================= Interface ==============================}
{==========================================================================}
INTERFACE


USES Overlay, Crt, Dos, pdaSubs, PDAMath,
   XMS, EMS,  mv, pdartc,
   SwapQB, QBC, QBMFile, PdaCfg;

PROCEDURE pdaSetUp;                 { Only one public procedure         }


{==========================================================================}
{============================ Implementation ==============================}
{==========================================================================}

IMPLEMENTATION

PROCEDURE pdaSetUp;
Var
QlbPath                       : PathStr;        { Quicklib name         }
tempstr                       : String80;       { Built-in BC and       }
CfgLoadResult                 : Word;           { Results of cfg load   }
QBFound                       : Boolean;        { Results of qb search  }
SearchedName                  : PathStr;        { FSearch return name   } 
FoundName                     : SearchRec;      { Results of FSearch    }
TmpStr                        : PathStr;        { Temp filename space   }
WinVersion                    : Word;           { Windows version       }
KeyBdOut                      : Byte;           { Work area for key rate}
Begin
CheckBreak        := False;
qbcChanged        := False;                  
QBFound           := False;
Child2Name        := '';
Child2parms       := '';
LastC2Name        := '';
LastC2parms       := '';
MainModPath       := '';
MainModDir        := '';            
MainModName       := '';            
MainModExt        := '';
MacDir            := '';
MacName           := '';
MacExt            := '';
DefLib            := '';
Qlbname           := '';
QlbDir            := '';
QlbExt            := '';
DebugFile         := '';
Debugger          := 'cv';
DbgOpts           := '';
QBKeyPress        := nil;
QBKeybdFlags      := nil;
BIOSKeybdFlags    := nil;
ptrSubList        := nil;
ForeColor         := Black;
BackColor         := LightGray;
KeyCPS            := 0;
KeyDelay          := 0;        { Keyboard rates        }
KeyBdAutoSet      := False;
KeyBdRateChanged  := False;
QBX               := False;
PatchOK           := False;    { Init to False to delay patch till QB load }
QBds              := 0;
QBes              := 0;
Popped            := False;
QPcs              := CSeg;
QPPre             := PrefixSeg;
QPds              := DSeg;
QPss              := SSeg;
FatalErrorCode    := 0;
PlayKeyOpt        := 1;
EndRecordKeyOpt   := 1;
PopUpKeyOpt       := 1;
KeyCount          := 0;
PlayPause         := 0;
PlayPauseInt      := 0;
AltAction         := 0;
KeyDown           := False;
KeyWasDown        := False;
PlayingMacro      := False;
GettingMacroKey   := False;
Recording         := False;
MacrosChanged     := False;
MKey              := 0;
Stuffed           := False;
SampleHead        := 1;
SampleTail        := 1;
NameAdjust        := 0;
NameSegAdjust     := 0;
NameOffset        := 0;          
SegNameList       := 0;          
BufferUsage       := None;          
SamplingEnabled   := False;            
ProgramRunning    := False;            
SampleCounter     := 0;       
SampleInterval    := 0;       
ProfElapsed       := 0;
{ Ver .8 profiler vars }
ptrSampleRec      := @TextLine;
ptrNextSampleRec  := ptrSampleRec;
SampleBufferStart := SampleRec;
SampleBufferTop   := SampleRec + (TextLines * 70) - 10;
SampleBufferOverFlow := False;   
TotalSampleCounts := 0;
TotalSampleTicks  := 0;
Int70Hooked       := False;
Rtc_PI            := False;
SampleTSource     := SysTick;
SampleRIndex      := 1;
SampleRate        := SampleRates[SampleRIndex];
StoredSampleRate  := SampleRate;
NoClrScrn         := False;
swDiskOnly        := False;
PortViewEnabled   := False;
DirectView        := False;
PopupKeyOpt       := 1;
RealTime          := True;
Win386            := False;
NoWin386XMS       := False;


{ Initialize Win 386 variables. }
asm;
   Mov AX, $1600;                   { Windows ID code                }
   Int $2F;                         { Call multiplex interrupt.      }
   Mov WinVersion, ax;
End; {asm}
If (Lo(WinVersion) = 0) or (Lo(WinVersion) = $80) Then
   { No enhanced Windows API running }
Else
   Begin
   Win386       := True;
   NoWin386XMS  := True;
   End;


{ Call PDAMath to initialize }
MathInit;


{ Identify screen type and base address }
CrtModeSet := MemW[$0: $463] + 4;
IF Mem[$0: $463 ] = $B4 Then
   AdapterBase := $B000
Else
    AdapterBase := $B800;

{Save the DOS cursor size for us to use }
Reg.AX := $0F00;                 { Get current display mode for   }
Intr($10, Reg);                  { active display page needed in  }
Reg.AX := $0300;                 { the read cursor info call.     }
                                 { It is in BH.                   }
Intr($10, Reg);                  { Returns cursor size in CX      }
CurSize := Reg.CX;

{ See if a real time clock is on board and
  set up to use it if found. Do this before
  reading config file, and paramstr so they
  take precedence.}
Has_Rtc := Find_Rtc;
Use_Rtc  := Has_Rtc;


{ Initialize the pointer to int 3F's vector }
ptrInt3F := ptr($0000,$00FC);

{Point at the int 9 vector }
ptrInt9 := ptr($0000,$0024);

{Point at the int 16 vector }
ptrInt16 := ptr($0000,$0058);



{ Tell them who we are }
Writeln;
Writeln(TextLine[1]);
Writeln(TextLine[2]);



{ Save the current int 3F value - ours - since this 
  is the int vector TP 6.0 uses to call overlays.
  QB also uses it with its Quicklibraries, so we must
  restore it when we are not popped up. }
Our3F := ptrInt3F^;

{ Save our int 9 also, for popup in 4.5}
Our9 := ptrInt9^;
{ Save our int 16 also, for popup in 4.5 }
Our16 := ptrInt16^;



{ If we have a "/?", display help and exit }
IF Pos( '/?', Parm ) > 0 THEN
   Begin
   For i := FirstHelpLine to LastHelpLine DO
      Writeln(TextLine[i]);
   Halt;
   End;




{ Get configuration settings from file }
CfgLoadResult := LoadCfg;
If CfgLoadResult <> 0 then
   If CfgLoadResult <> 2 then { Ignore file not found }
      Writeln('Error detected in configuration file -- not loaded.');



{ Look for QB/QBX and halt if not found.
  (   We'll borrow the macro key file pathspec variables
   and some TextLines for temporary work space.) }
{  Retrieve any path/name from command line }
IF Pos( '/Q:', Parm ) > 0 THEN
   Begin
   I := Pos( '/Q:', Parm );
   J := I + 3; Done := False;
   { Extract the pathname, if there }
   While (Not Done) AND (J <= Length(Parm)) do
      Begin
      { Name must be between /Q: and next /,
         space, or end of command tail  }
      IF Parm[J] IN ['/',' '] then
         Begin
         Dec(J);
         Done  := True;
         End;
      Inc(J);
      End;
   Dec(J);
   { No name found, use current directory}
   IF (J - I) <= 3 then
      TmpStr := FExpand('')
   Else                      {Extract name/path }
      TmpStr := Copy(Parm, I + 3, J - (I + 2));
   Delete(Parm, I, J - I + 1);

   { Get the components of path spec }
   FSplit(TmpStr, MacDir, MacName, MacExt);
  {   Writeln('Command = ',TmpStr);}
   End; { QB Path }

QBPathStr := '';
If MacExt = '' then MacExt := '.EXE';
{ If we have a drive/directory, then use it }
If MacDir <> '' Then
   { Spec'd first, then QB, then QBX }
   Begin
   If MacName = '' Then MacName := 'QB';
   TmpStr := MacDir + MacName + MacExt;
   FindFirst(TmpStr, Archive, FoundName);
   If DosError = 0 Then QbFound := True
   Else
      Begin
      If MacName <> 'QB' Then MacName := 'QB';
      TmpStr := MacDir + MacName + MacExt;
      FindFirst(TmpStr, Archive, FoundName);
      If DosError = 0 Then QbFound := True
      Else
         Begin
         MacName := 'QBX';
         TmpStr := MacDir + MacName + MacExt;
         FindFirst(TmpStr, Archive, FoundName);
         If DosError = 0 Then QbFound := True;
         End;
      End;
   If QbFound Then
      QBPathStr := TmpStr;
 { Writeln('MacDir=',TmpStr,'->',QBPathStr); }
   End;

{ Now try current directory }
If Not QbFound Then
   Begin
   MacDir := FExpand('');
   { QB first, then QBX }
   MacName := 'QB';
   TmpStr := MacDir + MacName + MacExt;
   FindFirst(TmpStr, Archive, FoundName);
   If DosError = 0 Then QbFound := True
   Else
      Begin
      MacName := 'QBX';
      TmpStr := MacDir + MacName + MacExt;
      FindFirst(TmpStr, Archive, FoundName);
      If DosError = 0 Then QbFound := True;
      End;
   If QbFound Then
      QBPathStr := TmpStr;
 { Writeln('NoMacDir=',TmpStr,'->',QBPathStr);}
   End;

{ Lastly, try along the path= spec }
If Not QbFound Then
   Begin
   { Add our directory to the search list}
   FSplit(Paramstr(0), MacDir, MacName, MacExt);
   TmpStr := GetEnv('PATH') + ';' + MacDir;
   { QB first, then QBX }
   SearchedName := FSearch('QB.EXE', TmpStr);
   If SearchedName = '' Then
      Begin
      SearchedName := FSearch('QBX.EXE', TmpStr);
      End;
   If SearchedName <> '' Then
      Begin
      QbFound := True;
      QBPathStr := FExpand(SearchedName);
      End;
 { Writeln('Searched=',TmpStr,'->',QBPathStr); }
   End;

{ Pathspec is in TextLine[1], or halt everything }
If Not QbFound Then
   Begin
   Writeln(QBPathStr);
   Writeln('Cannot locate QuickBASIC.  Program ended.');
   Halt(2);
   End;
   



{ See if user doesn't want clear screen for Child2 }
{ Set to True if there is a /NOCLS parmstr }
IF Pos( '/NOCLS', Parm ) > 0 THEN
   Begin
   { Get the NOCLS out of the parms so we don't confuse QB }
   I := Pos( '/NOCLS', Parm );
   Delete(Parm, I, Length('/NOCLS'));
   NoClrScrn := True;
   End;




{ See if user doesn't want to use memory for swapping Child2 }
{ Set to True if there is a /DO ( Disk Only) parmstr }
IF Pos( '/DO', Parm ) > 0 THEN
   Begin
   { Get the DO out of the parms so we don't confuse QB }
   I := Pos( '/DO', Parm );
   Delete(Parm, I, Length('/DO'));
   swDiskOnly := True;
   End;




{ See if reading and viewing of ports is to be allowed }
{ Set to True if there is a /PV ( Port View) parmstr }
IF Pos( '/PV', Parm ) > 0 THEN
   Begin
   { Get the /PV out of the parms so we don't confuse QB }
   I := Pos( '/PV', Parm );
   Delete(Parm, I, Length('/PV'));
   PortViewEnabled := True;
   End;




{ See if Real Time Clock is to be used or not }
{ Set to True if there is a /RTC parmstr,
 or False if there is /NORTC parmstr. }
IF Pos( '/RTC', Parm ) > 0 THEN
   Begin
   { Get the /RTC out of the parms so we don't confuse QB }
   I := Pos( '/RTC', Parm );
   Delete(Parm, I, Length('/RTC'));
   Use_Rtc := True;
   End;
IF Pos( '/NORTC', Parm ) > 0 THEN
   Begin
   { Get the /NORTC out of the parms so we don't confuse QB }
   I := Pos( '/NORTC', Parm );
   Delete(Parm, I, Length('/NORTC'));
   Use_Rtc := False;
   End;




{ See whether Linear View Mode (Using the Int15 MoveBlock)
  routine is to be initially disabled.  This may be needed where
  conflicts arise with child or parent processes using Dos Extender
  software. When this is enabled, the memory viewer will display the
  conventional memory addresses only.  Access to extended memory will
  only be available via an XMS driver (HIMEM.SYS), or an EMS emulator
  loaded before us.}
{ Set to True if there is a /NX ( No Extended Move) parmstr }
IF Pos( '/NX', Parm ) > 0 THEN
   Begin
   { Get the /NX out of the parms so we don't confuse QB }
   I := Pos( '/NX', Parm );
   Delete(Parm, I, Length('/NX'));
   DirectView := True;
   End;

{ We also need to disable the BIOS Int15 MoveBlock under Windows386,
  since Win386 regards such calls as System Integrity violations and
  will halt our program. }
If Win386 then DirectView := True;


{ See if there is a hot key preference }
{ Set to 1 (Ctrl-Shift), else 2 (Shift-Shift) if
   /SS switch (Shift-Shift) parmstr }
IF Pos( '/SS', Parm ) > 0 THEN
   Begin
   { Get the /SS out of the parms so we don't confuse QB }
   I := Pos( '/SS', Parm );
   Delete(Parm, I, Length('/SS'));
   PopupKeyOpt := 2;
   End;




{  Retrieve the name of startup key macro key file, from command line,
   user specified, or standard if /KF switch }
IF Pos( '/KF', Parm ) > 0 THEN
   Begin

   I := Pos( '/KF', Parm );
   J := I + 3; Done := False;
   { Extract the filename, if there }
   While (Not Done) AND (J <= Length(Parm)) do
      Begin
      { Name must be between /KF and next / or
        space, or end of command tail  }
      IF Parm[J] IN ['/',' '] then
         Begin
         Dec(J);
         Done  := True;
         End;
      Inc(J);
      End;
   Dec(J);
   { No name found, use default }
   IF (J - I) <= 3 then
      TempStr := 'QBMAC.KQF'
   Else                      {Extract name }
      TempStr := Copy(Parm, I + 3, J - (I + 2));
   Delete(Parm, I, J - I + 1);

   { Form a full path based on current drive/dir }
   FSplit(TempStr, MacDir, MacName, MacExt);
   If MacExt = '' then MacExt := '.KQF';
   TempStr := MacDir + MacName + MacExt;

   { Load up the key file}
   LoadKeyFile(TempStr);

   End; {Loading macrofile}





{ Change keyboard rates if requested }
If KeyBdAutoSet Then
	Begin
	Port[$60] := $F3;              { Send cmd in plenty of time for         }
                                  { hardware recovery before our           }
											 { value is sent.                         }
	KeyBdOut := 0;
	KeyBdOut := KeyDelay Shl 5;
	KeyBdOut := KeyBdOut or KeyCPS;
	Delay(10);                     { ... some more delay for insrnce        }
	Port[$60] := KeyBdOut;
   KeyBdRateChanged := True;      { Flag signals exit code to restore      }
   End;




{ Check for mouse driver }
GetIntVec( ms_call, mi );
IF mi = NIL THEN               { mouse interrupt vector null }
    mouse_present := False
ELSE IF Byte(mi^) = iret THEN  { vector points to iret }
    mouse_present := False
ELSE
    mouse_present := True;




{================================= mvSetDefaults ==========================}
{ Initalize additional memory view variables }
Mode := MByte;
AddrMode := Conventional; 
BMemOff := 0; BBank := 0; BMemSeg := $00;

{ Init extra memory variables }
ShowLinear := False;                { default Huge/Seg:Ofs address display }
For i := 1 to 4 do
    Begin                           { set all address "bookmarks" to 0     }
    SBank[i]    := 0;
    SMemOff[i]  := 0;
    SMemSeg[i]  := 0;
    End;

{ Enable linear mode viewing if we've found the
 capability and it has not been de-selected at startup. }
If XMThere and (not DirectView) then
   AddrMode := Linear;





{============================ AnalyzeCommandLine ====================== }
{ Parses the command line with which QB was started to identify user-
specified options relevant to compiling and linking loaded programs.
This information is used to construct a starter set of compile/link
options if no file for the currently loaded, or user-specified, basic
program exists on disk.  The command line as specified to us was placed
into the string "parm" and arguments applicable to us removed before it
was used in the Exec call to  QB.
If information is not found on the command line, pre-designated defaults
are used.
}


MainModPath := '';                                      { Source/EXE   }
QlbPath  := '';                                         { Quicklibrary }

{ --- Extract the name of any Quicklibrary that was requested }
{ NOTE: We don't actually know at this point whether it successfully loaded,
  but that doesn't matter, since this is only a starter set.}
IF Pos( '/L', Parm ) > 0 THEN
   Begin
   { Isolate the L value, if specified, into TempStr }                            
   I := Pos( '/L', Parm );
   TempStr := Copy(Parm, I + 2, Length(Parm) - I - 1);
   I := Pos( '/', TempStr );
   IF I > 0 then Delete(TempStr, I, Length(TempStr) - I + 1);

   { Now we either have a file name, or nothing }
   IF ((I = 0) and (Length(TempStr) = 0))           { Nothing means QB.QLB }
      or (TempStr = 'QB') then TempStr := 'QB.QLB';

   { Here, we simply assume the current directory and hook it on front.    }
   { We could use FSearch to look for an environment path to the .qlb's but
   who bothers to set that all up on their PC. }
   QlbPath := FExpand(TempStr);     { Do that for both the special .QLB }
   IF Length(QlbPath) = 0 then QlbPath := FExpand('QB.QLB'); { & QB.QLB }

   { Split full pathspec into component pieces for later ease of access
     in specifying the companion .LIB file. }
   FSplit(QlbPath, QlbDir, QlbName, QlbExt);

   End;

{ --- Now for Basic Compiler switches }
{ We'll just start with some commonly used BC options, even though they
 may not be implied from the command line starting QB/QBX. }
DefaultOpts := '/O/S/T';

{ Add specified switches }
IF Pos( '/AH', Parm ) > 0 THEN
   DefaultOpts := Concat('/AH', DefaultOpts);
IF Pos( '/MBF', Parm ) > 0 THEN
   DefaultOpts := Concat('/MBF', DefaultOpts);
IF Pos( '/C:', Parm ) > 0 THEN
   Begin                            { Get C: value, if specified }
   I := Pos( '/C:', Parm );
   TempStr := Copy(Parm, I + 1, Length(Parm) - I);
   I := Pos( '/', TempStr );
   IF I > 0 then Delete(TempStr, I, Length(TempStr) - I + 1);
   DefaultOpts := Concat(DefaultOpts, Concat('/',TempStr));
   End
   Else                             { Otherwise set C: to 512     }
   DefaultOpts := Concat(DefaultOpts,'/C:512');

{ --- Work up the options for the linker }

DefMap   := 'NUL';                                 { Default map file   }
DefList  := 'NUL';                                 { Default list file  }
LinkOpts := 'LINK /EX/SE:512/F/PACKC';             { Default link       }


End;  { pdaSetup }

End.  { pdaInit unit }
