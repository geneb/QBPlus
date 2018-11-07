'---- QuickBasic Memory Viewer
'---- Copyright 1991 John Eckert

' This is a demo program provided with the QuickBasic Plus Programmer's Desk
' Accessories to illustrate Execution Profiling in combination with
' Macro keystroke recording and playback.  It is packed with optimization
' opportunities -- but which ones will make a noticeable difference in the
' program's performance?  That is where profiling comes in. Enable profiling
' in the QB Plus Profiling menu, then run this program.  When finished,
' use the Profiling Analyze feature to see where the program's time was spent.
' See the ProfilingInfo SUB for details and a practice lesson.
'
' A color display is assumed. Change default color values, and the Segment
' address (&HB800 to &HB000) in WriteHexByte SUB as needed to support a
' monochrome display and/or display adapter.
'
' Supports 43/50 line screens using the /H command line switch.
'
' This program emulates common Pascal syntax to expedite conversion of
' Pascal souce code into QuickBasic. Uses PASSUBS.BAS for this. Feel free
' to add additional features of your own from the QB Plus Pascal source code.
'
' Requires the QB.QLB (or QBX.QLB) default Quicklibrary.
'
'Use LONG for unsigned integers
DEFLNG A-Z

'Emulated Pascal procedures and functions from PASSUBS.BAS
DECLARE FUNCTION MemW& (Segment AS ANY, offset AS ANY)
DECLARE FUNCTION GetCString$ (Segment&, offset&)
DECLARE FUNCTION GetString$ (Segment&, offset&)
DECLARE FUNCTION WhereY% ()
DECLARE FUNCTION WhereX% ()
DECLARE FUNCTION CarryClear% (flags%)
DECLARE SUB Dec (Number AS ANY, Amount AS ANY)
DECLARE SUB Inc (Number AS ANY, Amount AS ANY)
DECLARE SUB writes (Text$)
DECLARE SUB GotoXY (Column%, Row%)
DECLARE SUB ClrScr ()
DECLARE SUB ClrEOL ()

'Our SUB's and FUNCTIONS
DECLARE SUB DisplayAscii (AMemSeg, AMemOff, Column%, Mode&)
DECLARE SUB DisplayHeaderLine ()
DECLARE SUB LastLinePrint (Text$, Col&)
DECLARE SUB ShowTechInfo ()
DECLARE SUB DisplayLineAddress (LMemSeg&, LMemOff&, LBank&, Mode&)
DECLARE SUB DisplayMemLine (AMemSeg&, AMemOff&, count&, Mode&)
DECLARE SUB WriteHexLong (LongInt&)
DECLARE SUB WriteHexWord (Word&)
DECLARE SUB WriteHexByte (byte&)
DECLARE SUB FindEMM ()
DECLARE FUNCTION CopyEtoC& (BBank&, BMemSeg&, BMemOff&, HunkLength&, AMemSeg&, AMemOff&)
DECLARE FUNCTION HandleCommand& (Ch$)
DECLARE SUB SwapAddr (OldMode&)
DECLARE SUB BrowseMemory ()
DECLARE FUNCTION GetMemCommand$ ()
DECLARE SUB DisplayMemHunk (AMemSeg&, AMemOff&, LBank&, LMemSeg&, LMemOff&, Mode&)
DECLARE SUB AdjustMemPtr (MBank&, MSeg&, MOfs&, MSize&, Upward&)


'MvIBas declaration
DECLARE SUB MvInfo ()

'
' XMS access is not a part of this program, but may be added by addition
' of various XMS support code. See Pascal source code. Some XMS specific
' references have been left in this program, but commented out, for the
' benefit of those who may wish to roll their own full-featured QuickBasic
' memory viewer-manipulation program.

' QBX users should change the following to include 'QBX.BI'
' $INCLUDE: 'QB.BI'

DIM SHARED outreg AS RegType, inreg AS RegType
DIM SHARED InRegx AS RegTypeX, OutRegx AS RegTypeX

'Create and initialize EMS data variables
COMMON SHARED EMMThere AS INTEGER
COMMON SHARED FreePgs AS INTEGER
COMMON SHARED PagesTotal AS INTEGER
COMMON SHARED PageSize AS INTEGER
COMMON SHARED EMMVer AS INTEGER
COMMON SHARED HandlesUsed AS INTEGER
COMMON SHARED HandlesTotal AS INTEGER
COMMON SHARED DisplayBuff() AS INTEGER
COMMON SHARED MaxHunk AS INTEGER

'Define the ultimate truths
CONST False = 0, True = NOT False

'Define key codes -- a one byte string each
DIM SHARED UpArrow AS STRING * 1
DIM SHARED LeftArrow AS STRING * 1
DIM SHARED PgUp AS STRING * 1
DIM SHARED HomeKey AS STRING * 1
DIM SHARED PgDn AS STRING * 1
DIM SHARED DownArrow  AS STRING * 1
DIM SHARED EndKey AS STRING * 1
DIM SHARED F1 AS STRING * 1
DIM SHARED F3  AS STRING * 1
DIM SHARED RightArrow AS STRING * 1

'{ Constants for extended/function keys }
UpArrow = CHR$(72)
DownArrow = CHR$(80)
LeftArrow = CHR$(75)
RightArrow = CHR$(77)
PgUp = CHR$(73)
PgDn = CHR$(81)
HomeKey = CHR$(71)
EndKey = CHR$(79)
'{ function keys }
F1 = CHR$(59)
F3 = CHR$(61)

'Constants representing various memory display modes
CONST MByte = 1, MWord = 2, MLong = 3, MVect = 4, MAscii = 5, MInteger = 6
CONST MCmos = 8, MPort = 7

'{ Address mode codes - Conventional ONLY supported in the QB demo program }
CONST conventional = 1                  '{ Real mode, wraps at 1 meg       }
CONST Linear = 2                        '{ Linear addressing above 1 meg   }
CONST Expanded = 3                      '{ Use Lim 4.0 EMS driver > 1 meg  }
CONST XMSDrv = 4                        '{ Use XMS driver > 1 meg          }

DIM SHARED Prompt$
Prompt$ = "  Mode=BWLVAIPCR    View="
Prompt$ = Prompt$ + CHR$(27) + CHR$(26) + CHR$(24) + CHR$(25) + "PgUpDn<>  H Seg Ofs  Esc=Exit "

'Define address bookmark arrays
DIM SBank(1 TO 4) AS LONG
DIM SMemSeg(1 TO 4) AS LONG
DIM SMemOff(1 TO 4) AS LONG

'Declare beginning memory address variables
DIM SHARED BBank AS LONG, BMemOff  AS LONG, BMemSeg AS LONG
'Declare ending memory address variables
DIM SHARED EBank AS LONG, EMemOff  AS LONG, EMemSeg AS LONG
'Declare the various mode variables
DIM SHARED AddrMode AS INTEGER, RealTime AS INTEGER, Mode AS LONG
'Declare bank, segment, offset sizes and limits
DIM SHARED BankSize AS LONG, OffLimit AS LONG, BankLimit AS LONG
DIM SHARED SegLimit AS LONG, SegSize AS LONG
DIM SHARED FirstValidByte AS INTEGER, ValidBytes AS INTEGER

'{ Set the default to conventional addressing, byte display, no real time. }
RealTime = False
Mode = MByte
AddrMode = conventional

'Create a data structure and reserve space for EMS memory moves
TYPE EMMXMDataT
   HunkLen AS LONG                    '{ EMS bytes to transfer.    }
   SourceMemType AS STRING * 1        '{ Always 1. That's EMS.     }
   SourceHandle AS INTEGER            '{ page and ofs of EMS.      }
   SourceOffset AS INTEGER            '{ and ofs start as handle,  }
   SourcePage AS INTEGER              '{ Pass requested bank, seg  }
   TargetMemType AS STRING * 1        '{ Always 0 for conventional }
   TargetHandle AS INTEGER            '{ Always 0 for conventional }
   TargetOffset AS INTEGER            '{ Our display buffer addr   }
   TargetSeg AS INTEGER               '{      ""   ""              }
END TYPE
DIM SHARED EMMXMData AS EMMXMDataT



'Make size/limits consistent with addressing
'(Explanatory note -- Expanded (EMS) addressing uses the Bank variable for
' the EMS handle, which in that mode has a size of one and a limit equal to
' the number of EMS handles; uses the Segment variable for the EMS page which
' has a size of 16K and a limit equal to the handle's EMS page allocation.
'                 -- XMS(HIMEM.SYS) addressing uses the bank as an XMS handle
' with a size of one and a limit of FFFFh; segment/offset is together treated
' as a 32-bit linear offset within the handle so both segment and offset size
' are 1, with common limits of FFFFh.
'                -- Linear addressing uses the Bank variable as a 1 megabyte
' multiple with a size of 1 and a limit of Fh (15 megabytes), while segment
' and offset combine into a 24-bit linear address.
'   See the Pascal source for how this is used to reduce memory requirements
' in the memory viewer pascal unit.)
BankSize = 0
OffLimit = 65535
BankLimit = 65535
SegLimit = 65535
SegSize = &H1000

TYPE HardwareConfigT                           '{ LIM Function 26 struc.}
   rawpagesize AS INTEGER
   alternateregsets AS INTEGER
   saveareasize AS INTEGER
   DMAregset AS INTEGER
   DMAchannelop AS INTEGER
END TYPE

'Need to get video display information for further initialization
DIM SHARED NumLines, FGColor, BGColor

'Set up screen   (use /h on commandline for maximum # lines)
NumLines = 25                             'Assume 25 to start
IF INSTR(COMMAND$, UCASE$("/h")) THEN NumLines = 50    'If /H, go for 50
'Set error handler to drop back to 43, or 25 if that's all supported
ON ERROR GOTO ScreenTest
WIDTH 80, NumLines                        'Set lines/adjust on error
ON ERROR GOTO 0                           'Restore normal error messages

'Do colors while we are at it (Assume a color display)
FGColor = 7: BGColor = 1                  'Default colors
COLOR FGColor, BGColor


'Set viewer screen lines/sizes governed by the screen display size
DIM SHARED ScrnLines AS INTEGER, SLine AS INTEGER
DIM SHARED MaxBytesPerLine AS INTEGER
ScrnLines = NumLines - 2                      '{ # of memory display lines }
MaxBytesPerLine = 48                          '{ acsii mode is max         }
MaxHunk = ScrnLines * MaxBytesPerLine         '{ Keep below 1 K            }

'Reserve space for Expanded/Extended memory display buffer
DIM DisplayBuff(1 TO MaxHunk \ 2) AS INTEGER

'{ Init names of modes for display on last window line }
DIM SHARED ModeNames(1 TO 8) AS STRING * 7
ModeNames(1) = "Byte"
ModeNames(2) = "Word"
ModeNames(3) = "Long"
ModeNames(4) = "Vector"
ModeNames(5) = "Ascii"
ModeNames(6) = "Integer"
ModeNames(7) = "Port"
ModeNames(8) = "CMOS"

'{ Init bytes per screen line for each view mode }
DIM SHARED SlineBytes AS LONG
DIM SHARED BytesPerLine(1 TO 8) AS LONG
BytesPerLine(1) = 16
BytesPerLine(2) = 16
BytesPerLine(3) = 16
BytesPerLine(4) = 16
BytesPerLine(5) = 48
BytesPerLine(6) = 16
BytesPerLine(7) = 16
BytesPerLine(8) = 16

'{ Init bytes per screen for the various view modes  }
DIM SHARED HunkLength AS LONG
DIM SHARED HunkSizes(1 TO 8) AS LONG
HunkSizes(1) = 16 * ScrnLines
HunkSizes(2) = 16 * ScrnLines
HunkSizes(3) = 16 * ScrnLines
HunkSizes(4) = 16 * ScrnLines
HunkSizes(5) = 48 * ScrnLines
HunkSizes(6) = 16 * ScrnLines
HunkSizes(7) = 16 * ScrnLines
HunkSizes(8) = 16 * ScrnLines

' Program begins about here
CLS

'Test for EMS
FindEMM

'Initialize memory start location to 0000:0000:0000
BBank = 0
BMemOff = 0
BMemSeg = 0

BrowseMemory

END

'Target of ON ERROR to find video adapter's largest supported screen size
ScreenTest:
IF NumLines = 50 THEN NumLines = 43: RESUME
IF NumLines = 43 THEN NumLines = 25: RESUME

SUB AdjustMemPtr (MBank, MSeg, MOfs, MSize, Upward)
'======================== Adjust Memory Pointer =======================}
' Increments (or decrements if Upward is FALSE) the passed memory pointers
' by the value in Msize, rolling over each of the pointer components at their
' respective sizes, or wrapping them to zero at their respective limits which
' are contained in a series of global variables with values dependant upon
' the type of memory being addressed -- conventional, expanded or extended.}
CONST OffSize = 1


   IF AddrMode = Expanded THEN     '{ Use Bank for Handle, Segment for Page }
      'We retrieve the requested EMS handle's page count, and convert
      'PageSize (in K) to bytes, so that we can wrap pointers at the handle's
      'memory boundaries in this procedure, as well as in the command key
      'handlers in the main program when they change beginning segment and
      'bank values.
      OffLimit = PageSize * 1024 - 1   '{ Zero-align page size for handle  }
      BankLimit = HandlesTotal - 1     '{ Zero-align bank limit            }
      SegSize = 1                      '{ 1 page per offset size           }
      inreg.ax = &H4C00                '{ Get page count for handle        }
      inreg.dx = MBank                 '{ (EMS Handle is in Bank)          }
      Interrupt &H67, inreg, outreg    '{ Call EMM driver                  }
      SegLimit = outreg.bx - 1         '{ Zero-align pages for this handle }
      AH = outreg.ax AND &HFF00        'Isolate OutReg.AH
      IF AH <> 0 THEN SegLimit = 0     '{ EMM error, data invalid }
   ELSE           '{ Setup values for Conventional, Linear, and most of XMS }
       OffLimit = 65535
       BankLimit = 65535
       SegSize = &H1000
       SegLimit = 65535
   END IF

   '{ Treat XMS adjustments in extended memory as 32-bit address }
   IF (MBank > 0) AND (AddrMode = XMSDrv) THEN SegSize = 1

   '{ The Bank value in conventional memory is always 0 }
   IF AddrMode > conventional THEN BankSize = 1 ELSE BankSize = 0


   '{ Do upward adjust and rollover/wrap }
   IF Upward THEN
    IF OffLimit - MOfs <= MSize THEN
       MOfs = 0
       IF MSeg >= SegLimit + 1 - SegSize THEN
          MSeg = 0
          '{If Extended Then MSeg}
          IF MBank > BankLimit - BankSize THEN
             MBank = 0
          ELSE
             Inc MBank, BankSize
          END IF
       ELSE
           Inc MSeg, SegSize
       END IF
    ELSE
       Inc MOfs, MSize
    END IF

    '{ Adjust downward with wrap back at zero }
    ELSE
          IF MSize > MOfs THEN
             MOfs = OffLimit + 1 '{wrap ofs}
             IF MSeg = 0 THEN
                '{ Adjust the Bank, wrapping/rolling as needed }
                IF MBank = 0 THEN
                   MBank = BankLimit + 1 - BankSize
                ELSE
                    Dec MBank, BankSize
                END IF
                MSeg = SegLimit + 1 - SegSize  '{ Wrap/Roll the Seg-Page }
                '{ Need to set to last page of prev EMS handle }
                IF AddrMode = Expanded THEN
                   inreg.ax = &H4C00      '{ Get page count for handle       }
                   inreg.dx = MBank       '{ (EMS Handle is in Bank)         }
                   Interrupt &H67, inreg, outreg '{ Call EMM driver                 }
                   MSeg = outreg.bx - 1   '{ Zero-align pages for this handle}
                   AH = outreg.ax AND &HFF00          'Isolate OutReg.AH
                   IF AH <> 0 THEN MSeg = 0        '{ Empty handle   }
                END IF
               'end of MSeg = 0 }
             ELSE
                Dec MSeg, SegSize              '{ MSeg > 0, no wrap needed }
             END IF
          END IF
       Dec MOfs, MSize
   END IF

END SUB

SUB BrowseMemory
DIM Ch AS STRING

'This is the memory view loop
DO
   'Refresh the bottom line prompt
   LastLinePrint Prompt$, (80 - LEN(Prompt$)) \ 2

   'Clear keypress character
   Ch = ""

   'Set up memory block size and line length for given mode
   SlineBytes = BytesPerLine(Mode)
   HunkLength = HunkSizes(Mode)

   'Set display line pointers to beginning of target memory block
   LMemSeg = BMemSeg
   LMemOff = BMemOff
   LBank = BBank

   '{ Set End pointers to end of target memory block }
   EMemSeg = BMemSeg                     '{ Set end pointers first to }
   EMemOff = BMemOff                     '{ the start of target block }
   EBank = BBank                         '{ so adjust w/rollover works}
   '{ Now adjust end pointers upward with rollover as needed }
   AdjustMemPtr EBank, EMemSeg, EMemOff, HunkLength, True

   'Set address pointers to memory block to display
   IF AddrMode = conventional THEN
                                          '{ We display from the actual  }
      AMemSeg = LMemSeg                  '{ memory address when showing }
      AMemOff = LMemOff                  '{ conventional memory.        }
      ValidBytes = HunkLength            '{ All of the data in the      }
      FirstValidByte = 0                 '{ display area is thus valid. }
   ELSEIF AddrMode = Expanded THEN
      AMemSeg = VARSEG(DisplayBuff(1))
      AMemOff = VARPTR(DisplayBuff(1))
      ValidBytes = HunkLength
      FirstValidByte = 0
  
      '{ Attempt to copy }
      E2CResult = CopyEtoC(BBank, BMemSeg, BMemOff, HunkLength, AMemSeg, AMemOff)
      IF (E2CResult <> 0) THEN              '{ Failed for some reason...   }
         ValidBytes = 0                    '{ This keeps invalid data off }
      END IF

'{ Here's the special case of split display of two different EMS handle areas.
'  This requires two moves, with the additional complication that the addresses
'  in either or both handle areas are out of the range of allocated memory.
'  Thus we need to set a pointer to what's good and what's not good data in
'  our display buffer area.}
      IF (BBank <> EBank) THEN
         '{ Get fragment at top of first handle area }
         GoodBytes = (OffLimit - BMemOff) + 1'{ Watch: assumes EMS size is current}
         E2CResult = CopyEtoC(BBank, BMemSeg, BMemOff, GoodBytes, AMemSeg, AMemOff)
         IF E2CResult <> 0 THEN         '{ First part no good, so set start of}
            FirstValidByte = GoodBytes  '{ valid data to point past its area  }
         END IF
         '{ Now go for bottom of next handle }
         E2CResult = CopyEtoC(EBank, 0, 0, HunkLength - GoodBytes, AMemSeg, AMemOff + GoodBytes)
         IF E2CResult <> 0 THEN               '{ Second no good, so set valid bytes }
            ValidBytes = GoodBytes - FirstValidByte   '{ to count in first part    }
         ELSE                                         '{ Otherwise, add upper part }
            ValidBytes = HunkLength - FirstValidByte '{ to lower part.            }
         END IF
      END IF
   END IF
      
   'Display a screenful of lines
   DisplayMemHunk AMemSeg, AMemOff, LBank, LMemSeg, LMemOff, Mode

   'Get KeyBoard command
   Ch = INKEY$
   IF LEN(Ch) OR (NOT RealTime) THEN
      Result = HandleCommand(Ch)
   END IF

LOOP UNTIL Ch = CHR$(27)

END SUB

FUNCTION CarryClear% (flags%)

CarryClear% = ((flags% AND 1) = 0)

END FUNCTION

FUNCTION CopyEtoC (BBank, BMemSeg, BMemOff, HunkLength, AMemSeg, AMemOff)
'{ =============================== CopyEtoC ==============================
'  Copies a block from extended or expanded memory to conventional memory,
'  using one of three methods, Int15h/87h, EMS transfer, or XMS transfer,
'  depending upon the address mode, Real/Linear, Expanded, or XMS,
'  respectively in effect. In EMS and XMS, BBank refers to a handle.  For
'  EMS, BMemSeg and BMemOff refer to Page and Offset within page; for XMS,
'  they represent a standard segment/offset pair to be linearized into a
'  32-bit offset within a handle's XMS block.}

EMMResult = 0                                '{ EMM return code         }
EMMXMData.TargetSeg = AMemSeg                '{ Our display buffer addr   }
EMMXMData.TargetOffset = AMemOff             '{        ""   ""            }
EMMXMData.TargetHandle = 0                   '{ Always 0 for conventional }
EMMXMData.TargetMemType = CHR$(0)            '{        ""    ""           }
EMMXMData.SourcePage = BMemSeg               '{ Pass requested bank, seg  }
EMMXMData.SourceOffset = BMemOff             '{ and ofs start as handle,  }
EMMXMData.SourceHandle = BBank               '{ page and ofs of EMS.      }
EMMXMData.SourceMemType = CHR$(1)            '{ Always 1. That's EMS.     }
EMMXMData.HunkLen = HunkLength               '{ EMS bytes to transfer.    }

IF HunkLength > 0 THEN
   '{ Call Int 67h for move, pointing to our EMMXMData struc. }
   InRegx.ax = &H5700
   InRegx.si = VARPTR(EMMXMData.HunkLen)      '{ First member of EMMXMData.  }
   InRegx.ds = VARSEG(EMMXMData.HunkLen)      '{ DS used in call, thus don't }
   InterruptX &H67, InRegx, OutRegx           '{ make EMMXMData a stack var. }
   EMMResult = OutRegx.ax AND &HFF00          'Isolate OutReg.AH
   CopyEtoC = EMMResult
ELSE                                          'Nothing to transfer, so we
   CopyEtoC = 0                               'report success, of course.
END IF

END FUNCTION

SUB DisplayAscii (AMemSeg, AMemOff, AsciiCol%, Mode)
DIM Blanked AS INTEGER
  
   'Set up segment for the memory display area
   DEF SEG = AMemSeg

  
   IF (NOT Blanked) THEN
      IF (i >= ValidBytes) THEN
         ClrEOL
         Blanked = True
      ELSE
         'Show a series of ASCII according to the current mode
         SELECT CASE Mode
            CASE MAscii, MByte               'Only Ascii & Byte modes have ascii
               GotoXY AsciiCol%, WhereY      'but their start points and length
               FOR i = 0 TO SlineBytes - 1   'differ, the former passed to us.
                  AsChr% = PEEK(AMemOff + i) 'Get byte at memory location, convert
                  IF AsChr% < 32 THEN AsChr% = ASC(".")   'Ctrl chars to "."'s and
                  'Optimize Step 6 -- eliminate "Writes" SUB call
                  'PRINT CHR$(AsChr%);
                  writes CHR$(AsChr%)                     'output it as a character
               NEXT
            CASE ELSE
         END SELECT
      END IF
   END IF
END SUB

SUB DisplayHeaderLine

IF (Mode = MCmos) OR (Mode = MPort) THEN  'Skip addrs headings on these modes
ELSE
    IF AddrMode = Expanded THEN           '{ Do other Address Headings }
       writes "Hndl³Page:Ofstº EMS "
       Regx.AX = &H5300
       Regx.DX = BBank
       Regx.ES = VARSEG(HandleName)            '{ incl EMS handle name      }
       Regx.DI = VARPTR(HandleName)
       'InterruptX &H67, RegX, RegX
       AH = Regx.AX AND &HFF00
       IF AH = 0 THEN
         DEF SEG = VARSEG(HandleName)
         FOR i = 0 TO 7
           IF PEEK(VARPTR(HandleName) + i) > 0 THEN
               PRINT PEEK(VARPTR(HandleName) + i);
           END IF
         NEXT
       END IF
    ELSE
        IF ShowLinear AND (AddrMode = Linear) THEN
           writes "Linearº "
        ELSEIF AddrMode = XMSDrv THEN writes "Hndl³ Offset º XMS"
        ELSE
            writes "Huge³Sgmt:Ofstº "
        END IF
    END IF
  
    ClrEOL
    writes " "
    writes ModeNames(Mode)
    writes " "
    IF RealTime THEN writes " (Real time)"
    ClrEOL
END IF

END SUB

SUB DisplayLineAddress (LBank, LMemSeg, LMemOff, Mode)
'Shows the starting hex address of the current display line at cursor in the
'format appropriate to the mode

SELECT CASE Mode
   CASE MPort, MCmos
      writes " "
      WriteHexWord LMemOff
      writes " ³ "
   CASE MByte TO MInteger
      WriteHexWord LBank
      writes "³"
      WriteHexWord LMemSeg
      writes ":"
      WriteHexWord LMemOff
END SELECT

writes "º "



END SUB

SUB DisplayMemHunk (AMemSeg, AMemOff, LBank, LMemSeg, LMemOff, Mode)
'Displays a screenful of memory values from the actual memory location
'beginning AmemSeg:AmemOffset, but with the displayed location of LBank:
'LMemSeg:LMemOff, formatted in accordance with mode.

DIM HandleName AS STRING * 8
DIM AH AS INTEGER, i AS INTEGER


GotoXY 1, 1
FOR SLine% = 1 TO ScrnLines%
   GotoXY 1, SLine%
   DisplayLineAddress LBank, LMemSeg, LMemOff, Mode
  
  
   'Store Ascii column portion of display
   IF Mode = MByte THEN
      AsciiCol% = WhereX + 35                'Byte mode on right
   ELSE
       AsciiCol% = WhereX                    'Ascii mode is whole row
   END IF

  
   IF SLine% * SlineBytes <= FirstValidByte THEN
      ClrEOL               '{ Bypass invalid data in display buffer        }
   ELSE
      DisplayMemLine AMemSeg, AMemOff, SlineBytes, Mode

      'Display ASCII portions for certain modes
      DisplayAscii AMemSeg, AMemOff, AsciiCol%, Mode
   END IF

   'Adjust ValidByte pointer
   IF ValidBytes > SlineBytes THEN
       ValidBytes = ValidBytes - SlineBytes
   ELSE
      ValidBytes = 0
   END IF

  
   '{ Advance screen line and display address memory offset pointers,
   ' rolling over to the next Segment and Bank as necessary  }
   AdjustMemPtr LBank, LMemSeg, LMemOff, SlineBytes, True
   AdjustMemPtr LBank, AMemSeg, AMemOff, SlineBytes, True


NEXT  'Do another line till last line


'Display current mode and memory address labels
GotoXY 1, SLine%                          'Position to next line
DisplayHeaderLine                         'Output it

END SUB

SUB DisplayMemLine (AMemSeg, AMemOff, count, Mode)
DIM Blanked AS INTEGER

'Display a count series of memory values at the current cursor position in
'the format specified by Mode

' Force everything into range
AMemSeg = AMemSeg MOD 65536
IF AMemOff + count > 65536 THEN count = 65536 - AMemOff


'Set the segment for peek
DEF SEG = AMemSeg

FOR i% = 0 TO count - 1
'Be sure the bytes are valid; if not, do blanks the rest of line
IF (NOT Blanked) THEN
   IF (i >= ValidBytes) THEN
      ClrEOL
      Blanked = True
   ELSE
      SELECT CASE Mode
         CASE MByte
            WriteHexByte (PEEK(AMemOff + i%))
            'Profiler Optimize line
            'PRINT RIGHT$("00" + HEX$(PEEK(AMemOff + i%)), 2);
            'GOSUB WriteHB
            IF i% = 7 THEN PRINT " ";
         CASE MWord
            WriteHexWord (PEEK(AMemOff + i%) + CLNG(PEEK(AMemOff + i% + 1)) * 256)
            PRINT " ";
            i% = i% + 1
         CASE MLong
            i% = i% + 2                  'Reverse the word order
            WriteHexWord (PEEK(AMemOff + i%) + CLNG(PEEK(AMemOff + i% + 1)) * 256)
            i% = i% - 2
            WriteHexWord (PEEK(AMemOff + i%) + CLNG(PEEK(AMemOff + i% + 1)) * 256)
            PRINT " ";
            i% = i% + 3
         CASE MVect
            i% = i% + 2                  'Reverse the word order
            WriteHexWord (PEEK(AMemOff + i%) + CLNG(PEEK(AMemOff + i% + 1)) * 256)
            PRINT ":";
            i% = i% - 2
            WriteHexWord (PEEK(AMemOff + i%) + CLNG(PEEK(AMemOff + i% + 1)) * 256)
            PRINT " ";
            i% = i% + 3
         CASE MInteger
            LongVal = (PEEK(AMemOff + i%) + CLNG(PEEK(AMemOff + i% + 1)) * 256)
            PRINT USING "######"; LongVal + 65536 * (LongVal > 32767);
            PRINT " ";
            i% = i% + 1
         CASE MAscii
            Char = (PEEK(AMemOff + i%))
            IF Char > 31 THEN PRINT CHR$(Char);  ELSE PRINT ".";
         CASE MCmos
            OUT &H70, (AMemOff + i%) MOD 256
            CmosVal = INP(&H71)
            WriteHexByte CmosVal
            IF (i% + 1) MOD 4 = 0 THEN writes " "
            writes " "
         CASE ELSE
            PRINT "  ";
      END SELECT
   END IF
END IF
NEXT
EXIT SUB

WriteHB:
'Original code
PRINT RIGHT$("00" + HEX$(byte), 2); : RETURN

END SUB

SUB FindEMM
'{ =============================== FindEMM ===============================
'Determines whether expanded memory and a driver for it exist and, if so,
'sets up global information about EMM needed by other routines.

'Exports values in:                              Calls:
'      EMMThere          W                          Interruptx
'      Reg               W
'      EMMVer            W
'      FreePages         W
'      PagesTotal        W
'      PageSize          W
'      HandlesUsed       W
'      HandlesTotal      W

'}

EMMResult = 0


'{ Let's see if we have expanded memory manager resident }
EMMThere = False                                '{ Assume not there    }
InRegx.ax = &H3567                        '{ Call DOS for the int 67 vector }
InterruptX &H21, InRegx, OutRegx          '{ We make a pointer to the 8-byte}
DEF SEG = OutRegx.es                      '{ ID with EMM's seg in ES and the}
FOR i = 10 TO 17                          '{ offset of 10 bytes.            }
EMMID$ = EMMID$ + CHR$(PEEK(i))           ' Compare to the string "EMMXXXX0"
NEXT

IF EMMID$ = "EMMXXXX0" THEN               'It matched, so the EMS driver is
   '{ Now get version }                   'resident and hooked up.
   InRegx.ax = &H4600
   InterruptX &H67, InRegx, OutRegx
   EMMResult = OutRegx.ax AND &HFF00                 '{ Look for trouble    }
   EMMVer = OutRegx.ax AND &HFF                      '{ BCD formatted       }
   IF (EMMResult = 0) AND (EMMVer >= 40) THEN        '{ Need LIM 4.0 or up  }
      EMMThere = True                                '{ Whew, made it     }
      '{ Get Unallocated and total page count }
      InRegx.ax = &H4200
      InterruptX &H67, InRegx, OutRegx
      FreePgs = OutRegx.bx
      PagesTotal = OutRegx.dx
      PageSize = 16    '{K}                            '{ 16K is standard   }

      '{ Get handles in use }
      InRegx.ax = &H4B00
      InterruptX &H67, InRegx, OutRegx
      HandlesUsed = OutRegx.bx

      '{ Get handles in all }
      InRegx.ax = &H5402
      InterruptX &H67, InRegx, OutRegx
      HandlesTotal = OutRegx.bx
      END IF
  END IF
  '{ FindEMM }

END SUB

FUNCTION HandleCommand (Ch AS STRING)
    
'DIM Ch AS STRING

DO WHILE LEN(Ch) = 0
   Ch = INKEY$
LOOP

IF LEN(Ch) > 1 THEN     '{ Special function keys }
   Ch = RIGHT$(Ch, 1)
   SELECT CASE Ch
      CASE F3: MvInfo
      'CASE F1: mvHelpScreen
      CASE PgUp: IF BMemSeg = 0 THEN BMemSeg = SegLimit + 1 - SegSize ELSE Dec BMemSeg, SegSize
      CASE PgDn: IF BMemSeg = SegLimit + 1 - SegSize THEN BMemSeg = 0 ELSE Inc BMemSeg, SegSize
      CASE UpArrow:
              AdjustMemPtr BBank, BMemSeg, BMemOff, HunkSizes(Mode), False
      CASE DownArrow:
              BMemOff = EMemOff
              BMemSeg = EMemSeg
              BBank = EBank
      CASE LeftArrow: AdjustMemPtr BBank, BMemSeg, BMemOff, BytesPerLine(Mode), False
      CASE RightArrow: AdjustMemPtr BBank, BMemSeg, BMemOff, BytesPerLine(Mode), True
      CASE HomeKey: BMemOff = 0
      CASE EndKey: BMemOff = OffLimit - HunkSizes(Mode) + 1
   END SELECT '{ Case }

ELSE '{ Do regular keys }
   Ch = UCASE$(Ch)
   SELECT CASE Ch
      CASE "<", ",": IF BBank = 0 THEN BBank = BankLimit + 1 - BankSize ELSE Dec BBank, BankSize
      CASE ">", ".": IF BBank = BankLimit + 1 - BankSize THEN BBank = 0 ELSE Inc BBank, BankSize
      CASE ":", ";": ShowLinear = NOT ShowLinear: ClrScr
      CASE "B": Mode = MByte: ClrScr
      CASE "W": Mode = MWord: ClrScr
      CASE "V": Mode = MVect: ClrScr
      CASE "L": Mode = MLong: ClrScr
      CASE "I": Mode = MInteger: ClrScr
      CASE "A": Mode = MAscii: ClrScr
      CASE "P": IF PortViewEnabled THEN Mode = MPort: ClrScr
      CASE "C": Mode = MCmos: ClrScr: LMemOff = 0
      CASE "R": RealTime = NOT RealTime: ClrScr
      CASE "E"
               IF EMMThere THEN
                  ClrScr
                  OldMode = AddrMode
                  IF AddrMode = Expanded THEN
                      IF DirectView THEN
                         AddrMode = conventional
                      ELSE
                         AddrMode = conventional + ABS(XMThere)
                      END IF
                  ELSE
                      AddrMode = Expanded
                  END IF
                  SwapAddr OldMode
               END IF
      CASE "X"
               IF HimemSys THEN
                  ClrScr
                  OldMode = AddrMode
                  IF AddrMode <> XMSDrv THEN
                     AddrMode = XMSDrv
                  ELSE
                      IF DirectView THEN
                         AddrMode = conventional
                      ELSE
                         AddrMode = conventional + ABS(XMThere)
                      END IF
                  END IF
                  SwapAddr OldMode
               END IF
      CASE "H"
               IF AddrMode > conventional THEN
                  GotoXY 1, WhereY
                  ClrEOL
                  writes ("Enter Huge or Handle value in hex: ")
                  INPUT ; "", HexVal$
                  BBank = VAL("&H" + HexVal$) MOD 65536
               END IF
      CASE "O": GotoXY 1, WhereY
                ClrEOL
                writes ("Enter offset value in hex: ")
                INPUT ; "", HexVal$
                BMemOff = VAL("&H" + HexVal$) MOD 65536
      CASE "S": GotoXY 1, WhereY
                ClrEOL
                writes ("Enter segment value in hex: ")
                INPUT ; "", HexVal$
                BMemSeg = VAL("&H" + HexVal$) MOD 65536
      END SELECT '{ Case }
END IF

'GetMemCommand$ = Ch

END FUNCTION

SUB LastLinePrint (Text$, Col)
   'VIEW PRINT
   COLOR BGColor, FGColor
   LOCATE NumLines, Col
   PRINT Text$;
   COLOR FGColor, BGColor
   'VIEW PRINT 1 TO NumLines - 1
END SUB

SUB SwapAddr (OldMode)

'{=============================== SwapAddr =============================}
'{ Exchanges save area values with current values of beginning address
'  pointers.  Called at each switch to and from EMS/XMS to provide separate
'  "address bookmarks" for each address mode. }

SHARED SBank() AS LONG, SMemSeg() AS LONG, SMemOff() AS LONG

'{ Save current mode's beginning address display pointers}
SBank(OldMode) = BBank
SMemSeg(OldMode) = BMemSeg
SMemOff(OldMode) = BMemOff

'{ Load stored pointers for next mode }
BBank = SBank(AddrMode)
BMemSeg = SMemSeg(AddrMode)
BMemOff = SMemOff(AddrMode)

END SUB

SUB WriteHexByte (byte) STATIC
' Prints a hex word at the cursor
Hexdigits$ = "0123456789ABCDEF"

'Original code
PRINT RIGHT$("00" + HEX$(byte), 2); : EXIT SUB

'Optimize step 1 - Reduce string handling  (slight improvement )
'IF Byte < 16 THEN PRINT "0";
'PRINT HEX$(Byte); : EXIT SUB

'Optimize step 3 - Eliminate Basic's Hex conversion  ( got worse )
'PRINT MID$(Hexdigits$, Byte \ 16 + 1, 1);
'PRINT MID$(Hexdigits$, Byte MOD 16 + 1, 1); : EXIT SUB

'Optimize step 4 - Direct screen write      ( in between )
'DEF SEG = &HB800: Spot% = CSRLIN * 160 + (POS(0) * 2): HiNibble = Byte \ 16
'IF HiNibble > 9 THEN POKE Spot%, 55 + HiNibble ELSE POKE Spot%, 48 + HiNibble
'LoNibble = Byte MOD 16: IF LoNibble > 9 THEN POKE Spot% + 2, 55 + LoNibble ELSE POKE Spot% + 2, 48 + LoNibble: EXIT SUB





END SUB

SUB WriteHexLong (LongInt)
' Prints a hex long at the cursor

PRINT RIGHT$("00000000" + HEX$(LongInt), 8);

END SUB

SUB WriteHexWord (Word)
' Prints a hex word at the cursor

PRINT RIGHT$("0000" + HEX$(Word), 4);

END SUB

