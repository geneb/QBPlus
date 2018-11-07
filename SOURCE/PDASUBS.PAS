{-------------------------------------------------------------------------

                                    PDASUBS

       Unit containing common variables and routines for QB Plus modules

                  Written for Borland Turbo Pascal V 6.0

                     Copyright 1991, by John H. Eckert
                           All Rights Reserved


                                                   ... a component of the
                                                   QuickBasic Programmer
                                                   Desk Accessories ...
-------------------------------------------------------------------------}
{ History:           
01/11/91   0.20   Created in conjunction with overlay units.
01/15/91   0.30   Macro variables added.
04/08/91   0.85   Real time clock enable and variable declarations added.
04/15/91   0.86   Support for QB/X not in current directory.
04/25/91   0.88   PDAMath unit added.
04/29/91   0.91   Creation of profiler print unit.
05/05/91   0.92   Compute program elapsed time in seconds based on samples.
05/15/91   0.93   Misc: see PDA.
06/10/91   0.94   Name change support of PDA to QB Plus.
06/24/91   0.95   Windows 386 protection added to memory viewer.
07/16/91   1.00   
09/11/91   1.01   German version QB 4.5 code added; mouse save during Switch
                  Enable cursor for Child2.
10/05/91   1.02   Recognize source files with non-.BAS extensions.
10/10/91   1.10   Unit created to support console configuration, config file
						structure changed to match.
}
{-------------------------------------------------------------------------}
UNIT pdaSubs;

{$F+}                               { Far calls needed for overlays }
{$S-}                               { Stack checking off, ISR's call here }

{This unit contains the common code shared by resident and overlay
routines alike. It must therefore be resident itself.

The unit's data declarations contain all the type, constant and variable
declarations for all units.  If memory were no object, data private to a
unit would be declared within the unit's implementation section, while unit
data accessible outside the unit would be declared in its interface part.
This encapsulation protects against data "aliasing" -- a variable in one part
of the program used for one purpose also appearing unknowingly in another part
of the program and being used for some other, possibly conflicting, purpose.

However, all variables and enumerated constants reside in DSeg (DGROUP)
regardless of their declaration, and occupy space there even when the unit
itself is not in memory. By placing all variables in a common unit, we can
manage the data area better. For example, we can take advantage of the Pascal
union, variant record, and absolute variable declarations to share the same
memory among different variables.  Thus, when an overlaid unit is "out", its
otherwise unused variables can be used by another overlaid unit that is "in".
}
{==========================================================================}
{================================= Interface ==============================}
{==========================================================================}
Interface

Uses Dos,Crt;

TYPE
   String4 = String[4];
   String6 = String[6];
   String11 = String[11];
   String13 = String[13];
   String24 = String[24];
   String40 = String[40];
   String70 = String[70];
   String80 = String[80];
   String82 = String[82];
   String128 =String[128];


{--- XMS type declarations }
Byte8 = array[0..7] of Byte;                         { 6 of these in a GDT }
GDTType = Record   { Structure of Global Descriptor Table, Int15h/87h Move }
    Dummy            : Byte8;                        { Init to 0           }
    GDTSeg           : Byte8;                        { Init to 0           }
    SourceSegLimit   : Word;                         { Init to 0           }
    SourceSegOff     : Word;                         { lo-16 of 24-bit addr}
    SourceBank       : Byte;                         { hi-8 of 24-bit addr }
    SourceRights     : Byte;                         { Always $93          }
    SourceReserved   : Word;                         { Init to 0           }
    TargetSegLimit   : Word;                         { Init to 0           }
    TargetSegOff     : Word;                         { lo-16 of 24-bit addr}
    TargetBank       : Byte;                         { hi-8 of 24-bit addr }
    TargetRights     : Byte;                         { Always $93          }
    TargetReserved   : Word;                         { Init to 0           }
    BiosCode         : Byte8;                        { Init to 0           }
    BiosStack        : Byte8;                        { Init to 0           }
    End;

ExtMemMoveStruct = Record { Structure for XMS Himem.Sys Block Move      }
    Length           : LongInt;           { Bytes to transfer           }
    SourceHandle     : Word;              { Handle of Source block      }
    SourceOffset     : LongInt;           { 32-bit offset for source    }
    DestHandle       : Word;              { Handle of destination       }
    DestOffset       : LongInt;           { 32-bit offset to destination}
    End;
    { Usage Note: If SourceHandle/DestHandle = 0, then conventional memory
                  respectively is assumed and the corresponding offsets are
                  treated as standard segment:offset pairs, rather than
                  32-bit addresses.}

{--- EMS Type declarations }
HandleNameT = Array[1..8] of Char;        { Device driver ID bytes  }

EMMXMDataT = Record   { Structure for LIM function 24 Move/Exchange }
HunkLen        : LongInt;                 { EMS block size to move  }
SourceMemType  : Byte;                    { 1 = expanded memory     }
SourceHandle   : Word;                    { EMS source handle       }
SourceOffset   : Word;                    { Offset w/in EMM page    }
SourcePage     : Word;                    { EMS source page         }
TargetMemType  : Byte;                    { 0 = conventional memory }
TargetHandle   : Word;                    { 0 for conventional mem  }
TargetOffset   : Word;                    { Conventional Offset     }
TargetSeg      : Word;                    { Conventional Segment    }
End;

IVTEntry = Record  { Structure of a record to save an interrupt # and vector}
   Num   : Byte;
   Vector: LongInt;
   End;

{--- QBC Type declarations }
   rec_ptr     = ^module_rec;
   ModuleNamePtr = ^PathStr;
   module_rec     = RECORD                         { Items in linked    }
      ptrname     : ModuleNameptr;                 { module name list.  }
      next_module : rec_ptr
      END;

{--- Memory Viewer Types }
HexString   = Array[1..4] of Char;
String7     = String[7];

{--- Macro types }
   MacroFile_t = File of String82;


{--- Profiler Types }
SampleRecT = RECORD                  { Sample buffer record for the  }
   SubNum   : Word;                  { sampled SUB's name offset,    }
   SubCount : LongInt;               { call counts, and              }
   SubTicks : LongInt;               { timer tick counts.            }
   End;


CONST
{ Global Constants }
ms_call = $33;                { mouse interrupt number }
iret    = $cf;                { iret (return from interrupt) instruction }
Printables: SET OF Char = [' '..'}'];                 { Init sets }
Lowercase:  SET OF Char = ['a'..'z'];                 { Init sets }
HexChar : ARRAY[0..15] Of Char = '0123456789ABCDEF';
{ Define single line box characters }
ULCorner    = Chr(218);
URCorner    = Chr(191);
LLCorner    = Chr(192);
LRCorner    = Chr(217);
HBar        = Chr(196);
VBar        = Chr(179);
LineCross   = Chr(197);
TDown       = Chr(194);
TUp         = Chr(193);
TRight      = Chr(195);
TLeft       = Chr(180);

{ Config menu popup key option names }
CombKey          : Array[1..2] of String13 = ('Control-Shift',
                                             ' Both Shifts ');
{ Key constants }
Tab   = #9;

{ Constants for extended function keys }
UpArrow   = #72;  DownArrow  = #80;
LeftArrow = #75;  RightArrow = #77;
PgUp      = #73;  PgDn       = #81;
HomeKey   = #71;  EndKey     = #79;
Ins       = #82;  Del        = #83;

Ctrl_PrtSc     = #114;
Ctrl_LeftArrow = #115;  Ctrl_RightArrow  = #116;
Ctrl_PgUp      = #132;  Ctrl_PgDn        = #118;
Ctrl_Home      = #119;  Ctrl_End         = #117;

NullKey = #3;  Sh_Tab = #15;

{ alt- letter keys }
Alt_A = #30;  Alt_B = #48;  Alt_C = #46;  Alt_D = #32;  Alt_E = #18;
Alt_F = #33;  Alt_G = #34;  Alt_H = #35;  Alt_I = #23;  Alt_J = #36;
Alt_K = #37;  Alt_L = #38;  Alt_M = #50;  Alt_N = #49;  Alt_O = #24;
Alt_P = #25;  Alt_Q = #16;  Alt_R = #19;  Alt_S = #31;  Alt_T = #20;
Alt_U = #22;  Alt_V = #47;  Alt_W = #17;  Alt_X = #45;  Alt_Y = #21;
Alt_Z = #44;

{ alt- number keys }
Alt_1 = #120;  Alt_2 = #121; Alt_3 = #122;  Alt_4 = #123;
Alt_5 = #124;  Alt_6 = #125; Alt_7 = #126;  Alt_8 = #127;
Alt_9 = #128;  Alt_0 = #129;
Alt_minus = #130;  Alt_equals  = #131;

{ function keys }
F1 = #59;  F2 = #60;  F3 = #61;  F4 = #62;  F5  = #63;
F6 = #64;  F7 = #65;  F8 = #66;  F9 = #67;  F10 = #68;

{ shift- function keys }
Sh_F1 = #84;  Sh_F2 = #85;  Sh_F3 = #86;  Sh_F4 = #87;  Sh_F5  = #88;
Sh_F6 = #89;  Sh_F7 = #90;  Sh_F8 = #91;  Sh_F9 = #92;  Sh_F10 = #93;

{ ctrl- function keys }
Ctrl_F1 =  #94;  Ctrl_F2  =  #95;  Ctrl_F3 =  #96;  Ctrl_F4 = #97;
Ctrl_F5 =  #98;  Ctrl_F6  =  #99;  Ctrl_F7 = #100;  Ctrl_F8 = #101;
Ctrl_F9 = #102;  Ctrl_F10 = #103;

{ alt- function keys }
Alt_F1 = #104;  Alt_F2  = #105;  Alt_F3 = #106;  Alt_F4 = #107;
Alt_F5 = #108;  Alt_F6  = #109;  Alt_F7 = #110;  Alt_F8 = #111;
Alt_F9 = #112;  Alt_F10 = #113;

{ extended function keys }
F11      = #133;       F12      = #134;
Sh_F11   = #135;       Sh_F12   = #136;
Ctrl_F11 = #137;       Ctrl_F12 = #138;
Alt_F11  = #139;       Alt_F12  = #140;


{ --- QBC CONST's }
MaxModules = 18;                                { Module name capacity     }
{ QBC Build.EXE edit buffer }
    { Yes, this is a lot of precious memory set aside for the edit buffer. }
    { We'll share it with the buffer used by the memory viewer, and the
     Profiler sampler, but that means we'll have to save and reload our
     options data on every call.
     We use a buffer status flag the units share to decide if one of the
     other units 'messed up' the data in it.
     Also, we'll use it as workspace, and for passing along the pathspec
     for QB/QBX found by PDAInit at startup to Exec QB/QBX. by PDA.  See the
     QBPathStr declaration in the VAR block.}

    { In meantime, we store our Overlay name in lines 3&4 and command line
      help information in lines FirstHelpLine - LastHelpLine as long as
      the space is there. All this gets used at startup, then discarded.}
    TextLines     = 40;
    FirstHelpLine = 5;
    LastHelpLine  = 21;
    TextLine         : ARRAY [ 1..TextLines ] of String70 =
				('The QB Plus Desk Accessories, Version 1.10  10-Oct-91',
            'Copyright 1989-91, by John H. Eckert  All rights reserved.',
            'qbp.exe',                { Our .exe file name for Dos 2.1     }
            'qbp.ovr',                { Our overlay file name, if separate }
            '',
            '________________  Usage Information  __________________ ',
            '',
            'Press Ctrl-Shift to pop up accessories within QuickBasic',
            '',
            'Command line switches available:',
            '/?        - This help display',
            '/NX       - Disallow direct viewing of extended memory',
            '/NEO      - Disallow overlays in expanded memory',
            '/SS       - Pop up key combination Left Shift  -  Right Shift',
            '/DO       - Disk-only swaps of QuickBasic; not XMS or EMS',
            '/NOCLS    - No clearing of QB screen during swap',
            '/PV       - I/O port viewing enable',
            '/KF[fn]   - Load Macro key file [fn] on startup',
            '/RTC      - Use installed real time clock for profiling',
            '/NORTC    - Do not use real time clock for profiling',
            '/Q:[path] - Drive/directory with QB/QBX, if not current',
            '','','','','','','',
            '','','','','','','','',
            '','','','');


{ Child2/SwapQB Constants }
QBSwapName : String13 = 'QBSWAP.$$$';     { File where QB image is placed  }

{ Memory Viewer Default Values }
{ Mode format codes }
MByte = 1;
MWord = 2;
MLong = 3;
MVect = 4;
MAscii = 5;
MInteger = 6;                                  
MPort = 7;
Mcmos = 8;

{ Address mode codes }
Conventional = 1;                          { Real mode, wraps at 1 meg     }
Linear       = 2;                          { Linear addressing above 1 meg }
Expanded     = 3;                          { Use Lim 4.0 EMS driver > 1 meg}     
XMSDrv       = 4;                          { Use XMS driver > 1 meg        }

{ Default to conventional addressing }
AddrMode : Byte = 1;
BankSize : Byte = 0;
OffLimit : Word = $FFFF;
BankLimit: Word = $FFFF;
SegLimit : Word = $FFFF;
SegSize  : Word = $1000;

ScrnLines = 18;                                 { # of memory display lines }
MaxBytesPerLine = 48;                           { acsii mode is max         }
MaxHunk = ScrnLines * MaxBytesPerLine;          { Keep below 1 K            }


{--- Memory View Consts }
{ Init set used in hex<->decimal conversions }
HexDigits : Set of Char = ['0'..'9','A'..'F'];

{ Init names of modes for display on last window line }
ModeNames : Array[1..8] of String7 = ('Byte', 'Word',
                                      'Long','Vector',
                                      'Ascii','Integer',
                                      'Port', 'CMOS');

{ Init bytes per screen line for each view mode }
BytesPerLine : Array[1..8] of Byte = (16, 16, 16,
                                     16, 48, 16, 16, 16);

{ Init bytes per screen for the various view modes  }
HunkSizes    : Array[1..8] of Word = (16 * ScrnLines,
                                     16 * ScrnLines,
                                     16 * ScrnLines,
                                     16 * ScrnLines,
                                     48 * ScrnLines,
                                     16 * ScrnLines,
                                     16 * ScrnLines,
                                     16 * ScrnLines);


{ Macro Constants }
   MacroKeys: SET OF Char = ['0'..'9','A'..'Z','a'..'z'];
   MacroStat = $88;              { Screen buff offset to first macro stat }
   ALT_DOWN = $08;                                       { Masks to set/reset}
   ALT_UP   = $F7;                                       { Keydb ALTkey flag }
   CTRL_DOWN = $04;                                      { Masks to set/reset}
   CTRL_UP   = $FB;                                      { Keydb CTLkey flag }
   LSHFT_DOWN = $02;                                     { Masks to set/reset}
   LSHFT_UP   = $FD;                                     { Keydb LSTkey flag }
   RSHFT_DOWN = $01;                                     { Masks to set/reset}
   RSHFT_UP   = $FE;                                     { Keydb RSFkey flag }
    MaxMacros  = 36;                            { Macro capacity            }
    MacroLines = 36;
    MacroLine        : ARRAY [ 1..MacroLines ] of String82 =
            ('A','B',
            'C',
            'D','E','F','G','H','I','J','K',
            'L','M','N','O','P',
            'Q',
            'R','S','T',
            'U','V','W','X','Y','Z','1','2',
            '3','4','5','6','7','8','9','0');
    HiTrigger  = 800 DIV 55;                        { Double-tap thresholds }
    LoTrigger  = 100 DIV 55;                        { ( in timer ticks )    }


{ --- Profiler constants }
MaxSamples  = (TextLines * 70) DIV 2;           { We share the textline buff}
None        = 0;                                { Codes to reflect the     }
Sampling    = 1;                                { current usage of shared  }
QBCing      = 2;                                { buffer (in BufferUsage)  }
SampleRecLength   = SizeOf(SampleRecT);         { Bytes in each sample rec }
SysTick     = 0;                                { The PC system timer tick }
Rtc         = 1;                                { The RTC periodic intrupt }
SampleRateList = 8;                             { Number of sample rates   }
SampleRates : array[1..SampleRateList] of Word= { Samples/sec available    }
              (18,                              { 1st is always systimer,  }
               32, 64, 128, 256, 512,           { then RTC rates           }
               1024, 2048);

VAR
{ --- QBP Main module variables }
{We clear a spot within our DSeg as a stack on which the Exec parms are
pushed by TP as part of the Exec call.  This area serves multiple use --
for calling QB initially, then again whenever we call any secondary child
process when we've swapped QB out of memory.  Between such calls the first
500 bytes are safe to use for temporary work space.}
ExecStack                     : ARRAY [ 1..512 ] of Word; { first.    }

segTsrStack, offTsrStack      : Word;             { Our stack save area    }
segAppStack, offAppStack      : Word;             { for saving QB's stack  }
DErrCode, DXCode              : Byte;             { for DosError, DOsExit  }
mouse_present                 : Boolean;          { True if MOUSE present  }
AdapterBase                   : Word;             { Screen buff start      }
r                             : Registers;        { scratch Regs variable  }
mi                            : Pointer;          { mouse int vector num   }
Reg                           : Registers;        { CPU Register record    }
Parm                          : String128;         { Concat'ed Cmd line    }
QBPathStr                     : PathStr absolute TextLine;  {QB's path     }
ch                            : Char;              { generic character     }
PopUpKeyOpt                   : Byte;              { Which hot key active  }
ULRow                         : Byte;              { Location of upper     }
ULCol                         : Byte;              { left of pop up box    }
LLRow, LLCol                  : Byte;              { Lower right of box    }
Title, Prompt                 : String80;          { Title/prompt pointers }
init_max, init_min            : Word;              { start scrn attribs    }
OldAttr                       : Byte;              { ""     ""    ""       }
CrtModeSet                    : Word;              { Adapter mode set reg. }
AdapterMode                   : Byte absolute $0:$465;{ Current adap set   }
QBVidMode                     : Byte;              { Temp storage QB mode  }
ForeColor, BackColor				: Byte;					{ Color values				}
KeyCPS, KeyDelay              : Byte;              { Keyboard rates        }
KeyBdAutoSet, KeyBdRateChanged: Boolean;           { When to/whether chngd }
QBCurSize, CurSize            : Word;              { start and QB's ..     }
ptrScreenStore                : Pointer;           {scrn save/restore      }
ScreenStoreAddress            : LongInt absolute ptrScreenStore;
segExecStack, offExecStack    : Word;              { Init'd by Parent      }
QBX                           : Boolean;           { True if QBX, else QB  }
QBXVer                        : Word;              { QBX Version * 100     }
ptrCheckHotKey                : pointer;           { ptr to our patch code }
ptrDSegSave, ptrPatchVal      : ^Word;             { ptr to QB patch loc   }
PatchedVal                    : Word;              { Our word val w/in QB  }
PatchOK                       : Boolean;           { Prevent Non-QB patch  }
QBcs, QBcsE, QBds, QBes       : Word;              { Segment values of     }
QPcs, QPds, QPPre, QPss       : Word;              { various QB functions  }
GotQBcs                       : Boolean;           { QB patch/install flag }
i,j                           : Byte;              { generic counters      }
done                          : Boolean;
x, y, CurX, CurY              : Byte;
Popped                        : Boolean;
QBKeyPress                    : ^Byte;
QBKeybdFlags, BIOSKeybdFlags  : ^Byte;
{ Interrupt and timer variables }
old_8, old_9                  : Pointer;           { Saved int vectors.    }
ExitSave                      : Pointer;           { for old ExitProc      }
IOResultCode                  : Byte;
AutoSaveInt                   : Byte;
TPIntsInIVT                   : Boolean;           { True when TP ISR's in }
Our3F, QB3F                   : LongInt;           { Space for Int 3F swaps}
ptrInt3F                      : ^LongInt;          { We'll aim this at 3Fh }
ptrInt9                       : ^LongInt;          { We'll aim this at 9h  }
Our9, QB9                     : LongInt;           { Space for Int 9 swaps }
ptrInt16                      : ^LongInt;          { We'll aim this at 16h }
Our16, QB16                   : LongInt;           { Space for Int 16 swaps}

{--- XMS Variables }
XMThere                       : Boolean;         { XMS driver presence      }
HimemSys                      : Boolean;         { HIMEM.SYS XMS driver here}
ptrXMSControl                 : Pointer;         { HIMEM.SYS entry address  }
XMMVer, HimemVer              : Word;            { XMS, HIMEM.SYS ver #'s   }
TotalXM, Int15Avail           : Word;            { Extd K per CMOS, Int15h  }

{--- EMS Variables }
EMMThere                      : Boolean;         { EMS,XMS driver presence  }
EMMVer                        : Byte;            { EMS driver version #     }
PageSize                      : Word;            { Standard page is 16K     }
PageFrame, FreePgs            : Word;            { EMS config, status info  }
PagesTotal                    : Word;            { EMS config, status info  }
HandlesUsed                   : Word;            { EMS config, status info  }
HandlesTotal                  : Word;            { EMS config, status info  }

{ --- QBC variables }
OptFile                       : Text;             { used in Assign      }
ExitQB                        : Boolean;
Compile                       : Boolean;     { Return flag requests compilation. }
cancelled                     : Boolean;
QlbName                       : NameStr;          { passed in cmd          }
QlbDir                        : DirStr;           { line and put           }
QlbExt                        : ExtStr;           { into LINK parms.       }
DefaultOpts, DefLib           : String80;         { Built-in BC and        }
DefMap, DefList, LinkOpts     : String80;         {  LINK defaults         }
qbcChanged                    : Boolean;         { Text changes not saved   }
MainModPath                   : PathStr;         { Full Main module name.   }
MainModDir                    : DirStr;          { Components of path,      }
MainModName                   : NameStr;         { name . . .               }
MainModExt                    : ExtStr;          {  . . . and extension.    }
ptrMainModNum        : ^Word;       { Loc of main module's index number     }
FirstModAdjust       : Word;        { Loc first valid modnum in entries     }
CurrentNameOff       : Word;        { Loc NameOffset of module in active win}
ModNameAdjust        : Byte;        { NameOffset member in Mod entry        }
NextModLink          : Byte;        { Link member to next mod entry         }

                        (*{  The compile/link options file may be located }*)
                        (*{  from the above data by:                      }*)
                        (*{    MainModDir + MainModName + '.MQK'          }*)



{ --- Memory Viewer variables }
DirectView                    : Boolean;         { Disallows Linear Mode    }
PortViewEnabled               : Boolean;         { True = allow MPort mode  }
RealTime                      : Boolean;         { secondary mode flags     }
Mode                          : Byte;            { current view mode        }
BMemOff, BMemSeg, BBank       : Word;            { memory Pointer locations }
SBank                         : Array[1..4] of Word;   { S=bookmark storage }
SMemSeg                       : Array[1..4] of Word;   { S=bookmark storage }
SMemOff                       : Array[1..4] of Word;   { S=bookmark storage }
ShowLinear                    : Boolean;         { 24-bit linear Addr 1 & 2 }  
{ More MV Vars -- also shared with SwapQB}
{ We must create these in DSeg; their segments are passed in ds register }
HandleName                    : HandleNameT;     { EMS 8-byte handle ID     }
EMMXMData                     : EMMXMDataT;      { EMS transfer param table }
XMSXData                      : ExtMemMoveStruct;{ XMS transfer param table }
GDT                           : GDTType;         { Int15h/87h transfer param}



{ --- Child2/SwapQB variables }
NoClrScrn                     : Boolean;  { No Clr before child2 ParamStr  }
swDiskOnly                    : Boolean;  { Swap to disk, not EMS/XMS      }
Child2Name, Child2parms       : PathStr;  { Name/arg parameters            }
LastC2Name, LastC2parms       : PathStr;  { Storage for above              }
XEHandle                      : Word;     { EMS/XMS handle in effect       }
FatalErrorCode                : Byte;     { flag to halt QB with code      }
swCanceled                    : Boolean;  { Whether to continue the swap   }
{ Reserve room for storing all the interrupt vectors, and ones QB changed }
IVTSave                       : Array[0..255] of LongInt;
CurrentIVT                    : Array[0..255] of LongInt absolute $0:0;
{ SwapQB Exclusive VAR's }
QBIVT                         : Array[0..30] of IVTEntry;
segTsrStackc, offTsrStackc    : Word;             {stack save area-child}
QBExecReturn                  : LongInt;          { return addr on exec }


{ Debugger variables }
dbgCanceled                   : Boolean;  { Returned true they changed mind}
Debugger, DebugFile           : PathStr;  { Debugger and debugged names    }
DbgOpts                       : String24; { Debugger switches              }


{ -- Macro variables }
LastScrl, LastCapsl, LastNuml : Boolean;     { toggle key states     }
LastCaps, LastScroll          : Boolean;     { toggle key states     }
Stuffed                       : Boolean;
StuffedCount                  : Word;
EndRecordKeyOpt               : Byte;
PlayKeyOpt, MKey, AltAction   : Byte;
PlayPause, PlayPauseInt       : Byte;
RKey, ChKey                   : Byte;
KeybdFlags                    : Byte;
KeyDown, KeyWasDown, Recording: Boolean;
KeyCount                      : Word;
PlayingMacro, GettingMacroKey : Boolean;
Macro, NextKey                : Byte;        {current macro and key  }
MacroKey                      : Char;        {stroke ptr and key     }
MacDir                        : DirStr;
MacName                       : NameStr;
MacExt                        : ExtStr;
MacroFile                     : MacroFile_t;
MacrosChanged                 : Boolean;


{ -- Profiler variables }
SampleHead, SampleTail        : Word;        { Pointers to SampleBuff data }
ptrSubList                    : ^Word;       { Offset in QBDs of SubList   }
ptrCurrentSubSeg              : ^Word;       { Addr w/ SubSeg Sublist ofs  }
ptrCurrentSub                 : ^Word;       { Addr w/Sub sublist ofs      }
NameAdjust, NameSegAdjust     : Word;        { QB specific displacements   }
NameOffset                    : Word;        { Sub name loc. in NameList   }
SegNameList                   : Word;        { Segment addr of NameList    }
BufferUsage                   : Byte;        { Shared buffer semaphore     }
{ Here we declare our sample buffer right on top of TextLine string array  }
SampleBuffer   : array[ 1..MaxSamples ] of Word absolute TextLine;
SamplingEnabled               : Boolean;     { Signals Int8 collection     }
ProgramRunning                : Boolean;     { True when program runs      }
SampleCounter                 : Byte;        { Delay countr between samples}
SampleInterval                : Byte;        { Delay count in ticks        }
ProfElapsed                   : LongInt;     { Accumulated prog. ticks     }
{ Version .8 profiler variables }
ptrSampleRec, ptrNextSampleRec: ^SampleRecT; { Pointers to sample data     }
{ Declare the offset portions of above pointers as integer variables       }
SampleRec                     : Integer absolute ptrSampleRec;
NextSampleRec                 : Integer absolute ptrNextSampleRec;
SampleBufferTop               : Integer;     { Offset of top of samplebuff }
SampleBufferStart             : Integer;     { Offset of buffer start      }
SampleBufferOverflow          : Boolean;     { Flags no more sample room   }
TotalSampleCounts             : LongInt;     { Total call count            }
TotalSampleTicks              : LongInt;     { Total tick counts           }
old_70                        : Pointer;     { Saved int vector.           }
our_70                        : Pointer;     { Location of our int 70 ISR  }
Int70Hooked                   : Boolean;     { True if we've hooked int 70 }
RtcRegB, RtcRegC, IRQ8        : Byte;        { RT Clock locations.         }
Has_Rtc                       : Boolean;     { If on-board RTC found       }
Use_Rtc                       : Boolean;     { If RTC to be used           }
Rtc_PI                        : Boolean;     { Periodic rupt is active     }
SampleTSource                 : Byte;        { Either Rtc or Systimer      }
SampleRIndex                  : Byte;        { Array index of current rate }
SampleRate                    : Word;        { Current samples per second  }
StoredSampleRate              : Word;        { Rate existing samples taken }

{ Windows support variables }
Win386                        : Boolean;     { True, if any 386 win version}
NoWin386XMS                   : Boolean;     { Warn on XMS handle viewing  }



FUNCTION CarryClear : Boolean;
PROCEDURE ms_show;
PROCEDURE ms_hide;
PROCEDURE cursor_off;
PROCEDURE cursor_on;
PROCEDURE PutChr(By : Byte; Offs : Word);
PROCEDURE Inverse(Count : Word);
FUNCTION MacroNum( MacroKey:Char ):Byte;
FUNCTION GetKey : Char;
FUNCTION GetUpKey : Char;
FUNCTION ScrollLock:Boolean;
FUNCTION NumLock:Boolean;
FUNCTION CapsLock:Boolean;
FUNCTION CtrlKey:Boolean;
FUNCTION ShiftKey:Boolean;
FUNCTION LShiftKey:Boolean;
FUNCTION RShiftKey:Boolean;
PROCEDURE Box( X, Y, Width, Height : Integer);
PROCEDURE WriteHexByte( Number: Byte);
PROCEDURE WriteHexWord(WordNumber: Word);
PROCEDURE ClearPrompt;
PROCEDURE BorderTitlePrompt(Title : String80;
                            Prompt: String80);
PROCEDURE Enable_RTC;


{==========================================================================}
{============================ Implementation ==============================}
{==========================================================================}
Implementation



{============================= CarryClear ==============================
  Returns the state of the carry flag in a boolean, based on global variable
  Reg, a Register type structure.
}
FUNCTION CarryClear : Boolean;
Begin
CarryClear := Reg.Flags and FCarry = $0000
End;





{============================ ms_show ==================================
This is real-mode mouse function 1.
}
PROCEDURE ms_show;
    BEGIN
    r.AX := 1;
    Intr( ms_call, r );
    END;




{==========================  ms_hide  ====================================
This is real-mode mouse function 2.  
}
PROCEDURE ms_hide;
    BEGIN
    r.AX:=2;
    Intr( ms_call, r );
    END;





{============================= cursor_off ==============================
  Procedure cursor_off turns off the text cursor, by setting bit 5 of the
  CurSize ending scanline component.  The actual visible cursor size must
  first have been placed in CurSize by an Int10/F call.
}
PROCEDURE cursor_off;
VAR
    regs : Registers;

BEGIN
    WITH regs DO BEGIN
        AX := $0100;
		  CX := CurSize OR $2000;
        Intr( $10, regs )
    END;
END; { procedure cursor_off }





{============================= cursor_on ==============================
  Procedure cursor_on turns on the text cursor.  Standard BIOS method
  used here will run into trouble with EGA/VGA cursor emulation on EGA
  cards with the "bug" but extra code needed to deal with this is left
  out for memory space considerations.  Original cursor size must have
  first been recorded in CurSize, as this routine merely clears bit 5
  of ending scan line to restore a value set to an illegal size by
  cursor_off.
}
PROCEDURE cursor_on;
VAR
    regs : Registers;

BEGIN
    WITH regs DO BEGIN
        AX := $0100;
        CX := CurSize AND $1FFF;
        Intr( $10, regs )
    END;
END; { procedure cursor_on }






{==================================  GetKey  ===============================}
{ Waits for a keypress, then returns with the ASCII code if a regular
  keypress, or the character #0 if a special function or cursor key.
}

FUNCTION GetKey : Char;
Var
Ourch : Char;

Begin
      Repeat until Keypressed;
      OurCh := ReadKey;
      If OurCh = #0 then
         Begin
         { Flush all extended keysbut shift tab }
         OurCh := ReadKey;
         If OurCh <> Sh_tab then OurCh := #0;
         End;
      GetKey := OurCh;
End; { GetKey }





{============================== GetUpKey ===========================}
{ Waits for keypress, returning the upper case version of character
  whose key was pressed.  Cursor and function keys return #0.
}
FUNCTION GetUpKey : Char;
Var
Ourch : Char;

Begin
OurCh := GetKey;
GetUpKey := UpCase(OurCh);
End; { GetUpKey }





{===========================  ScrollLock ===============================}
{ ScrollLock returns True if scroll lock key is currently down}
FUNCTION ScrollLock:Boolean;
BEGIN
IF ( Mem[$40:$18] AND $10 <> 0) THEN
      ScrollLock := True
   ELSE
      ScrollLock := False;
END;





{===========================  NumLock ===============================}
{ NumLock returns True if num lock key is currently down}
FUNCTION NumLock:Boolean;
BEGIN
IF ( Mem[$40:$18] AND $20 <> 0) THEN
      NumLock := True
   ELSE
      NumLock := False;
END;





{===========================  CapsLock ===============================}
{ CapsLock returns True if caps lock key is currently down}
FUNCTION CapsLock:Boolean;
BEGIN
IF ( Mem[$40:$18] AND $40 <> 0) THEN
      CapsLock := True
   ELSE
      CapsLock := False;
END;





{===========================  CtrlKey ===============================}
{ CtrlKey returns True if Ctrl key now depressed }
FUNCTION CtrlKey:Boolean;
BEGIN
IF ( Mem[$40:$17] AND $04 <> 0) THEN
      CtrlKey := True
   ELSE
      CtrlKey := False;
END;





{===========================  ShiftKey ===============================}
{ ShiftKey returns True if either shift key is currently down}
FUNCTION ShiftKey:Boolean;
BEGIN
IF (Odd(Mem[$40:$17]) OR ( Mem[$40:$17] AND 2 <> 0)) THEN
   ShiftKey := True
   ELSE
      ShiftKey := False;
END;





{===========================  LShiftKey ===============================}
{ LShiftKey returns True if L shift key is currently down}
FUNCTION LShiftKey:Boolean;
BEGIN
IF (Odd(Mem[$40:$17])) THEN
   LShiftKey := True
   ELSE
      LShiftKey := False;
END;





{===========================  RShiftKey ===============================}
{ RShiftKey returns True if right shift key is currently down}
FUNCTION RShiftKey:Boolean;
BEGIN
IF ( Mem[$40:$17] AND 2 <> 0) THEN
   RShiftKey := True
   ELSE
      RShiftKey := False;
END;





{ =========================== CharShow =================================
  Displays the character at the screen position corresponding to the
  screen buffer offset passed in the call, ie 0 = col 1, 2 = col 2, 4=3.
  ScreenBuff must already be initialized according to adapter, B800 or B000.
  CGA's will get snow - only use within ISR's where you can't use Pascal's
  Write because of reentrancy problems.
  }
PROCEDURE PutChr(By : Byte; Offs : Word);
BEGIN
Mem[AdapterBase:Offs] := By;
End; { PutChr }





{ =============================== Inverse ===============================}
{ Inverts the color of a line of "Count" characters at the current cursor
position using direct screen writes.  The screen buffer base address must
have first been stored in the external variable AdapterBase. The neat
things here are the simplicity of the routine, and that the first call
highlights, and a repeat call unhighlights.  On the other hand, we don't
screen out the high intensity and blink values -- which aren't a problem
where we are using only black and white.}
PROCEDURE Inverse(Count : Word);
VAR
Loc   : Word;
i     : Word;
ATTRA : Byte;
ATTRB : Byte;

Begin
{ Figure the actual screen position relative to the window settings, and
point at the attribute byte preceding the first character.}
Loc := ((WhereX + Lo(WindMin)) * 2) + ((WhereY - 1 + Hi(WindMin)) * 160) - 1;

i := 0;
While i < Count * 2 do
   Begin
   { Retrieve the attribute byte }
   ATTRA := Mem[AdapterBase: Loc + i];

   { Make a copy. }
   ATTRB :=ATTRA;

   { Swap the attribute's high and low nibbles.  Do that by clearing the
   complementary nibbles of the two copies, then smash them together.}
   Mem[AdapterBase: Loc + i] := (ATTRA SHR 4) or (ATTRB SHL 4);
   Inc(i,2);
   End;

End; { Inverse }






{ ===============================  Macro Number ===========================
   Given a macro character, returns the byte index to the character's
   keystroke storage position in the MacroLines array, or 0 if the
   character is not a valid macro character.}
FUNCTION MacroNum( MacroKey:Char ):Byte;
Var
i     : Byte;
BEGIN
i := 0;
If MacroKey IN MacroKeys Then
   Begin
   i := MacroLines + 1;
   Repeat Dec(i); Until ( i = 0 ) or (MacroKey = MacroLine[ i, 1 ])
   End;
MacroNum := i;
END; {MacroNum}





{==================================  Box  ===============================}
{ Draws a box frame at UL coords. X,Y within a text window using the
   current screen colors. }
PROCEDURE Box( X, Y, Width, Height : Integer);
VAR
   I,J   :  Integer;

BEGIN
   IF X < 0 then X := (80 - Width) DIV 2;       { Negative X centers box }
                                                { Draw top line }
   GotoXY(X, Y);  Write(ULCorner);
   FOR I := 3 TO Width DO Write(HBar);
   Write(URCorner);
                                             { Draw bottom line }
   GotoXY(X, (Y + Height) - 1);  Write(LLCorner);
   FOR I := 3 TO Width DO Write(HBar);
   Write(LRCorner);
                                             { Draw sides }
   FOR I := 1 to Height - 2 DO
      BEGIN
         GotoXY(X, Y + I); Write(VBar);
         GotoXY((X + Width) - 1, Y + I); Write(VBar);
      END
END;     { Box }






{============================  WriteHexByte ================================}
{ Prints the hex equivalent of the value passed in the argument, Number.    }
PROCEDURE WriteHexByte( Number: Byte);
VAR
   HiNibble, LoNibble : Byte;

BEGIN
   LoNibble := Number AND $0F;
   HiNibble := Number SHR 4;
   Write(HexChar[ HiNibble ], HexChar[ LoNibble ]);
END; {WriteHexByte }






{============================  WriteHexWord ================================}
{ Prints the hex equivalent of the value passed in the argument, WordNumber.}
PROCEDURE WriteHexWord(WordNumber: Word);
Begin
     WriteHexByte(Hi(WordNumber));
     WriteHexByte(Lo(WordNumber));
End; { WriteHexWord }







{ ============================== ClearPrompt =========================
 Clears the prompt from the bottom border line. Window settings are
 preserved.  }
PROCEDURE ClearPrompt;

var
WindULSave  : Word;                     { Reserve temporary space for  }
WindLRSave  : Word;                     { entry window settings.       }

Begin
WindLRSave  := WindMax;                 { save current window size      }
WindULSave  := WindMin;                  

WindMax     := init_max;                { restore original window size  }
WindMin     := init_min;                    

GotoXY(ULCol + 1, LLRow +1); For i := 1 to LLCol - ULCol do Write('Ä');

WindMax     := WindLRSave;              { restore entry window size     }
WindMin     := WindULSave;

End; { Clear prompt }






{ ============================== BorderTitlePrompt =========================
 Draws the window outline, displays the window title at top, and prompt on
 bottom line.  Returns with window limits set to protect the border.  Called
 by Main on startup and by Help and Info routines which clear the prompt
 from the lower border line while they are showing their stuff.
 }
PROCEDURE BorderTitlePrompt(Title : String80;
                            Prompt: String80);

Begin

WindMax := init_max;                    { restore original window size  }
WindMin := init_min;                    { restore original window size  }

{ Draw the border at window edge, and our title at top left. }
Box(UlCol - 1, ULRow -1, LLCol - ULCol + 3, LLRow - ULRow + 3); 
GotoXY( ULCol + 2, ULRow - 1);
Write(Title);

{ Prompt line at bottom of box -- centered }
GotoXY( 1 + ULCol + ((LLCol - ULCol) - Length(Prompt)) div 2, LLRow + 1);
Write(Prompt);

{ Reduce window limits to within the border }
Window( ULCol, ULRow, LLCol, LLRow );
End; { BorderTitlePrompt }




{ == STACK CHECKING LIMIT == STACK CHECKING LIMIT == STACK CHECKING LIMIT == }
{$S-} {Turn Stack checking off for following routines... }

{============================  Enable_RTC  ============================
   Enables the AT compatible built-in real time clock periodic
   interrupts.  Called by counter increment interrupt handler on each
   RTC pulse.
}
PROCEDURE Enable_RTC;
   BEGIN
   Port[$70] := $0B;                { select RTC register B    }
   RtcRegB := Port[$71];             { and check if already on.   }
   IF ((RtcRegB AND $40) = 0) THEN  { No, so set it.           }
     BEGIN
     RtcRegB := RtcRegB OR $40;        { Set bit six,             }
     Port[$70] := $0B;              { select RTC register B,   }
     Port[$71] := RtcRegB;          { and enable RTC.          }
     END;

   { Output from RTC is via IRQ8, so enable it also.}
   IRQ8 := Port[$A1];               { Retrieve the interrupt bit map, }
   IRQ8 := IRQ8 AND $FE;            { clear bit 0, and put it back.   }
   Port[$A1] := IRQ8;
   END;  { Enable_RTC }

END. { of PDASubs unit }
