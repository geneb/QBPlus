{-------------------------------------------------------------------------

                                 QBCGet 

             Unit to get compile and link options for editing

                  Written for Borland Turbo Pascal V 6.0

                     Copyright 1991, by John H. Eckert
                           All Rights Reserved


                                                   ... a component of the
                                                   QuickBasic Programmer
                                                   Desk Accessories ...
-------------------------------------------------------------------------}
{ History:          
01/03/91   0.10   Originally a part of the stand alone utility, QBBC.EXE
                  Version 1.6, the code here has been restructured to tie
                  in as an overlay unit in the toolset. It depends upon the
                  Child2 unit to call its compile/link code located in an
                  external companion program.
01/11/91   0.20   This Get Options code moved to separate unit.
10/05/91   1.02   Recognize source files with non-.BAS extensions.
}
{-------------------------------------------------------------------------}
{$F+}                               { Far calls needed for overlays }
{$O+}                               { Unit may be overlaid          }
UNIT QBCGet;

{ This unit supports the line-based editor in QBC.  It gathers the data for
editing, placing it in the TextLine string array.  Data is from various
sources -- in order -- 1) from an existing .MQK file saved to disk in a
previous editing session, 2) from preset internal default compile and link
options combined with the contents of a .MAK file, or 3) the internal
defaults combined with the module(s) names specified by the user. This data
constitutes a "starter set" for the user to customize in the editor.
The internal defaults are custom tailored to the Crescent Software PDQ
library, if PDQ is detected as the resident Quicklibrary.
}

{==========================================================================}
{================================= Interface ==============================}
{==========================================================================}
INTERFACE


USES Crt, Dos, pdaSubs, pdartc, PDAEDLN, QBCHelp, QBC;


PROCEDURE GetOptions;                 { Only one public procedure       }


{==========================================================================}
{============================ Implementation ==============================}
{==========================================================================}

IMPLEMENTATION

{ ===============================  Get Options ========================}
{ Retrieve the data representing the compile and link options.  Called by
 the PDA kernel when they want to Build.EXE, this digs up stuff to edit,
 returning the results in the TextLine[] editing buffer. This also sets
 MainModPath, MainModDir, MainModName, and MainModExt to the source file
 currently being edited.

 External Accesses
      Variables:                       Calls:
               MainModPath  W                BorderTitlePromopt
               MainModDir   W                ClearPrompt
               MainModName  W                ClrScr
               MainModExt   W                cursor_on
               Textlines                     cursor_off
               Textline[]   W                GotoXY
               QBX                           KeyPressed
               DefaultOpts                   ReadKey
               LinkOpts     W                FSplit
               DefMap                        Assign
               DefLib       W                Reset
               MaxModules                    IOResult
               qbcChanged        W           EOF
               Ch                W           Close
               BufferUsage       W
               QBCing
               Sampling                      GetDir
               SamplingEnabled   W           New
            x   SampleRec        W           Dispose
               QlbName           W           Disable_Rtc
            x  ProfElapsed       W
            x  SampleBufferStart
            x  ptrSampleRec      W
            x  NextSampleRec     W
            x  SampleRecLength
            x  ptrNextSampleRec  W
            x  SampleBufferOverFlow W
               TotalSampleCounts    W
               TotalSampleTicks     W
               Rtc_PI            W
					FirstModAdjust
					CurrentNameOff
					ModNameAdjust
					NextModLink
					ptrMainModNum
}
PROCEDURE GetOptions;

LABEL GetOptionsDone;

VAR
Title                         : String13;        { Our window title        }
temp                          : rec_ptr;         { Module record type      }
ObjFiles, J                   : Byte;            { Counters                }
ObjDir                        : DirStr;          { Used for building .obj  }
ObjName                       : NameStr;         { file spec's in the data }
ObjExt                        : ExtStr;          {  ""      ""    ""    "  }
SubList, Sublink, NextSublink : Word;            { Mod/Sub table ptrs      }
SubSeg, Subnum                : Word;            {    "     "     "     "  }
ptrModuleName                 : ModuleNameptr;   { In-mem module ptrs      }
ModList, Modlink              : Word;            { In-mem module ptrs      }
EndTable, PrevEntry, NextEntry: Word;            {  "  "     "     "       }
ModSeg, Modnum                : Word;            {  "  "     "     "       }
NameOffset                    : Word;            {  "  "     "     "       }
Modules                       : rec_ptr;         { In-mem module ptrs      }
ModuleCount                   : Byte;            { In-mem module count     }
Key                           : Char;            { Last input key code     }

{ As local procedures, the following can share the local (stack) variables. }



{============================== is_empty ===============================
  The is_empty function checks to see if the sub list is empty.
}
FUNCTION is_empty( VAR target : rec_ptr ) : Boolean;

BEGIN
    IF (target = NIL ) THEN
        is_empty := True
    ELSE
        is_empty := False;
END; { is_empty }




{================================ push =================================
  Procedure push adds a record to the front of the list.
}
PROCEDURE pushModuleInfo( VAR ptrModulename   : ModuleNameptr;
                          VAR module_ptr      : rec_ptr );

VAR
   temp : rec_ptr;

BEGIN
    New( temp );
    temp^.next_module   := module_ptr;
    module_ptr          := temp;
    module_ptr^.ptrname := ptrModulename;
    Inc(ModuleCount);
END; { push }





{============================= DumpSubInfo ==============================
  empties the sub list.
}
PROCEDURE DumpModuleInfo( VAR s1 : rec_ptr );

VAR
    temp : rec_ptr;

BEGIN
    WHILE NOT is_empty( s1 ) DO
        BEGIN
        temp := s1;
        s1 := s1^.next_module;
        Dispose( temp );
        END;
     ModuleCount := 0;
END; { procedure dumpsubinfo }



{ ============================= BuildModuleList ========================}
{ Retrieve the names of the modules, and their offsets in the Module/Sub
 name segment and put the information in a linked list.  }
PROCEDURE BuildModuleList;


{ Local procedure to return a pointer to a module's name in the name segment
  given the module's index number to it's entry in the SubList.}
Procedure GetModName;
Begin
	{ At this module index, retrieve the NameOffset value}
	NameOffset := MemW[QBds: Sublist + ModNum + ModNameAdjust];
	{ Or the Active Window area if this module is in Active screen window }
	If NameOffset = $FFFF then
		NameOffset := MemW[QBds: CurrentNameOff];
	{ Point at module's name in the Name Segment }
	ptrModuleName := ptr(ModSeg, NameOffset + 3);
End; { GetModName }


Begin
DumpModuleInfo( Modules );               { Clear old list               }

SubList := ptrSubList^;                     { Get loc. of start of sub list}
ModSeg  := memw[ QBds:SubList + NameSegADjust];{ Get segment of name list }

{ Store the main module name first on the heap}
ModNum := ptrMainModNum^;            { Main mod's index number          }
GetModName;                          { Make pointer to it's name        }
MainModPath := ptrModuleName^;       { Save in the pathspec             }
pushModuleInfo (ptrModuleName, Modules);  { and first on the heap       }

{ Now set to first module index in the entries }
ModNum := MemW[QBds: SubList + FirstModAdjust];

{Then walk the module entry chain, storing each one's name on heap      }
Repeat

   If ModNum <> ptrMainModNum^ then  { Don't duplicate main module name	}
      { put module name at the head of the linked list on the heap }
      IF ModuleCount < MaxModules then
         Begin
         GetModName;
         pushModuleInfo (ptrModuleName, Modules);
         End;

   { Get next module index number in chain from link member of this entry }
	ModNum := MemW[QBds: SubList + ModNum + NextModLink];

until (ModNum = $FFFF) or (ModuleCount >= MaxModules);
End;  { BuildModuleList }




(*{ ===============================  Show modules ========================}
{ Retrieve the names of the modules ... }
PROCEDURE ShowModules;
VAR
   temp  : rec_ptr;

Begin
ClrScr;
BuildModuleList;
temp := modules;                            { Get loc. of start of mod list   }
Writeln('Module List');
if is_empty( Modules) then
   begin
   Writeln;
   Writeln('No Modules');
   end
   else
      While temp <> Nil Do
         begin
         IF (WhereX > 1) and (WhereX < 34) then GotoXY(35, WhereY) ELSE Writeln;
         Write(temp^.ptrname^);
         temp := temp^.next_module;
         end;
End;  { ShowModules } *)




{ ==== MAIN ROUTINE BEGINS HERE ========== }
Begin

{ Initialize the heap-based module list pointer
 and count of linked module names. }

{ Hopefully, we will have disposed of the memory
 occupied in the heap on leaving here previously.
 IMPORTANT: See note at end of this unit. }
Modules           := NIL;
ModuleCount       := 0;

{ Set up our screen }
Title := ' Build .EXE ';
BorderTitlePrompt(Title,Title);
ClearPrompt;
ClrScr;
Cursor_on;

{ Coordinate with profiler; we share the sample buffer area with it }
If BufferUsage = Sampling Then
   Begin
   GotoXY(12, 10); Write('Edit buffer currently in use by Profiler.');
   GotoXY(5, 12); Write('Disable Profiler sampling and discard samples (Y/N)? ');
   Repeat
      Ch := GetUpKey;
   Until Ch in [ 'Y', 'N', #27];
      Case Ch OF
         #27, 'N' : Begin
                  MainModPath := '';  { Clear this out to force reloading  }
                  Goto GetOptionsDone;{ on the next trip back.             }
                  End;
         'Y'      : { Push profiler aside }
                  Begin
                  MainModPath := '';  { Clear this out to force reloading  }
                  SamplingEnabled := False;       { Turn off profiler      }
                (*   ProfElapsed := 0;        { Init execution timer ticker   }
                  { Initialize sample buffer }
                  SampleRec := SampleBufferStart;{ create new record for   }
                  ptrSampleRec^.SubNum := 0;     { the main "SUB"          }
                  ptrSampleRec^.SubCount  := 1;  { initing its counters to }
                  ptrSampleRec^.SubTicks  := 0;  { 1 and 0.                }
                  { Post end marker also.             }
                  NextSampleRec := SampleRec + SampleRecLength;
                  ptrNextSampleRec^.SubNum := $FFFF; 
                  SampleBufferOverFlow := False; { Init overflow flag      }*)
                  TotalSampleCounts := 0;
                  TotalSampleTicks := 0;
                  If Rtc_PI Then                { Stop the periodic interrupt}
                     Begin                      { from running when sampling }
                     Disable_Rtc;               { is not enabled.            }
                     Rtc_PI := False;
                     End;
                  End;  { 'Y' }
      End; { case }
   End;

{ Take over the textline buffer, letting others know by placing our
ownership flag in BufferUsage. }
BufferUsage := QBCing;


{ --- Dig up module/configuration data to edit.     }

{ Data may already be in memory, or we may be       }
{ asked to make up a starter set.  Data in memory   }
{ always has a main module file name present.       }
IF Length(MainModPath) > 0 THEN           { Already loaded. Keep?       }
   Begin
   GotoXY(12,11);
   Write('Keep working with current data (Y/N)? ');
   Ch := chr(0);
   Repeat
      Begin
      IF KeyPressed then Ch :=ReadKey;
      Ch := Upcase(Ch);
      Case Ch OF
         #27      :Goto GetOptionsDone;
         'N'      :
                  Begin
                  MainModPath := '';  { Clear out existing data   }
                  FOR I := 1 to TextLines Do
                     TextLine[ I ] := '';
                  End;  { 'N' }
      End; { case }
      End;
   Until (Ch = 'N') or (Ch = 'Y');
   End;

IF Length(MainModPath) = 0 THEN           { Nothing already on hand     }
   Begin
   FOR I := 1 to TextLines Do             { Clear out existing data  }
      TextLine[ I ] := '';
   BuildModuleList;
   IF is_empty(Modules) THEN            { No module names available   }
      Begin
      ClrScr; GotoXY(8,11);
      Write('You must first load a QuickBasic Source file.  Press ESC.');
      Ch := chr(0);
      Repeat If KeyPressed THEN Ch := ReadKey; Until Ch = #27;
      GOTO GetOptionsDone
      End;  { is empty }

   { Get .MQK data ... }
   FSplit(MainModPath, MainModDir, MainModName, MainModExt);
   Assign(OptFile, MainModDir + MainModName + '.MQK');
   {$I-} Reset(OptFile); {$I+}   {Suspend error trap during reset }
   IF IOResult = 0 then
      BEGIN
      I := 0;
      While not EOF(OptFile) do
         begin
         Inc(I);
         Readln(OptFile, TextLine[I]);
         End;
      Close(OptFile)
      END  { getting .MQK }

   Else                          { No .MQK, so try .MAK or memory }
      Begin
      Assign(OptFile, MainModDir + MainModName + '.MAK');
      {$I-} Reset(OptFile); {$I+}   {Suspend error trap during reset }
      IF IOResult = 0 then          { Got .MAK, so use it }
         BEGIN
         I := 0;
         While not EOF(OptFile) do
            Begin
            Inc(I);
            Readln(OptFile, TextLine[I]);
            TextLine[ I ] := Concat('BC ',MainModDir,
                                    TextLine[ I ],
                                    DefaultOpts,';');
            End;
         Close(OptFile)
         END

         Else  { No .MAK, so put module names from memory into edit area }
            Begin
            temp := Modules;  I := ModuleCount;
            While (temp <> Nil) and (I > 0) Do
               Begin
               TextLine[ I ] := Concat('BC ',temp^.ptrname^, DefaultOpts,';');
               temp := temp^.next_module;
               Dec(I);
               End;
            I := ModuleCount;
            DumpModuleInfo( Modules );       { Clear module list        }
            End;

      { Now add BC defaults and LINK default options }
      { Set up specific defaults applicable to QBX and PDQ }
      { Use QBX's version of QB.QLB, if loaded }
      If QBX and (QlbName = 'QB') then QlbName := 'QBX';

      { Assume the default library for standalone .EXE files }
      { Also note the trailing semi-colon. }
      DefLib   := 'BCOM45.LIB;';                      { Default library    }
      If QBX then DefLib := 'BCL71EFR;';              { What the heck:     }
                                                      { PDS - standalone   }
                                                      {     - emulator     }
                                                      {     - far strings  }
                                                      {     - real mode    }



      { Add the "/L"-specifed QuickLibary's .LIB counterpart } 
      { Again (see note above on the .qlb's), we could use an environment
        drive/subdirectory path here, but won't.
       We'll make the starter set for the current directory, and then
       the computer owner can type in his preference, if different. }
      IF Length(QlbName) > 0 then
         DefLib :=  QlbDir + QlbName + '.LIB ' + DefLib;

      { Here's PDQ support ... }
      If (qlbName = 'PDQ') or (qlbName = 'PDQ7') Then
         Begin
         { Note the trailing semi-colon }
         If QBX Then DefLib := QlbDir + 'BASIC7.LIB '+ QlbDir + 'PDQ.LIB;'
         Else DefLib := QlbDir + 'PDQ.LIB;';
         LinkOpts := 'LINK /NOE/NOD/SE:512/F/PACKC';
         End;
      { PDQ NOTE: Running in the environment with PDQ usually means the use
      of a QuickBasic support module, PDQSUBS.BAS, which is not intended to
      be compiled and linked with the .EXE file. We aren't set up to exclude
      this module from the starter set, however. }

      ObjFiles := I; Inc(I);
      TextLine[ I ] := LinkOpts; Inc(I);
      J := I - 1;
      For I := I TO I + ObjFiles - 1 Do
         Begin
         FSplit(Copy(TextLine[I - J], 4, Pos('.',TextLine[I-J])-4),
                ObjDir, ObjName, ObjExt);
         TextLine[I] := ObjName + '.OBJ';
         IF (I - J) < ObjFiles then TextLine[I] := Concat(TextLine[I],'+');
         End;
      Inc(I);  TextLine[ I ] := MainModDir + MainModName + '.EXE';
      Inc(I);  TextLine[ I ] := DefMap;
      Inc(I);  TextLine[ I ] := DefLib;
      qbcChanged := True;                 { New data, save before compiling }
      End;  { creating stuff from .MAK or memory }
   End;  { getting stuff not on hand }

GetOptionsDone:

{ We need to clear our module list and release the heap before leaving this
  routine, since  1) we don't need the data anymore
                  2) someone else might be able to use the heap space
                  3) our pointer (Modules) to our heap linked list becomes
                     invalid when we leave here, since it is on the stack
                     and we won't be able to free the memory once we leave,
                     thus setting things up for a potential heap exhaustion.
}
If ModuleCount > 0 Then
   DumpModuleInfo( Modules );              

Cursor_off;
Ch:= #0;

End; { GetOptions }

END. { QBCGet Unit }

