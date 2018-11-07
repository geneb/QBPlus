'---- QuickBasic Memory Viewer
'---- Copyright 1991 John Eckert

DEFINT A-Z
TYPE HardwareConfigT                           '{ LIM Function 26 struc.}
   rawpagesize AS INTEGER
   alternateregsets AS INTEGER
   saveareasize AS INTEGER
   DMAregset AS INTEGER
   DMAchannelop AS INTEGER
END TYPE
'Emulated Pascal procedures and functions from PASSUBS.BAS
DECLARE FUNCTION MemW& (Segment AS ANY, offset AS ANY)
DECLARE FUNCTION GetCString$ (Segment&, offset&)
DECLARE FUNCTION GetString$ (Segment&, offset&)
DECLARE FUNCTION WhereY% ()
DECLARE FUNCTION WhereX% ()
DECLARE FUNCTION CarryClear% (flags%)
DECLARE FUNCTION DosVersion% ()
DECLARE SUB Dec (Number AS ANY, Amount AS ANY)
DECLARE SUB Inc (Number AS ANY, Amount AS ANY)
DECLARE SUB writes (Text$)
DECLARE SUB ClrScr ()
DECLARE SUB GotoXY (Column%, Row%)
DECLARE SUB ClrEOL ()
DECLARE SUB WriteHexByte (byte&)
DECLARE SUB WriteHexWord (Word&)
DECLARE SUB Writeln (Text$)

' $INCLUDE: 'QB.BI'
DIM SHARED Regx AS RegTypeX
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

CONST False = 0: True = NOT False

SUB MvInfo
'{ =============================== mvInfo ==============================
'  Displays information on Conventional, Expanded and Extended memory.  }

CONST False = 0: True = NOT False


DIM Ech AS STRING                             '{ our input character   }

'{ Used by the conventional memory parts }
DIM DOSmem AS LONG

'{ Used by Expanded and Extended routines }
DIM HardwareConfig AS HardwareConfigT
'EXBoth                     : Boolean;
'EMMResult,XMResult         : Byte;
'RawFree, RawCount          : Word;
'RawPageK                   : Byte;
'XMSize, XMFree             : Word;
'GeneralInfo, HMAStatus     : Byte;
'XMHandle, BytesK           : Word;

'{ Set up for the display, putting a box in left half of screen.  }
ClrScr
LOCATE 1, 30
PRINT "QuickBASIC Memory Viewer"
PRINT

'{ See if this BIOS supports int 15/88, - Get Extended Mem Size -       }
Regx.ax = &H8800                             '{ PC/XT and PS/2 30       }
InterruptX &H15, Regx, Regx                  '{ return &H80 and &H86    }
Int15Avail = Regx.ax                         '{ respectively in AH      }
IF CarryClear%(Regx.flags) AND (Int15Avail \ 16 < &H80) THEN     '{ & carry set.      }

   '{ We can't rely on size value returned by 15h/88h, since another
   'memory manager/os may have hooked int15h to protect extended
   'memory it may have taken for itself. }
   '{ Assume a cmos machine configuration data register exists that
   'has the actual extended memory size in 1K byte blocks.           }               
   OUT &H70, &H18                      '{ Select port &H18 for       }                                    
   TotalXM = INP(&H71) * 256           '{ high byte ...              }
   OUT &H70, &H17                      '{ ... port &H17 for low      }
   TotalXM = TotalXM + INP(&H71)
   IF (TotalXM > 0) AND (TotalXM < 33000) THEN '{ keep reasonable    }
      XMThere = True
   END IF  '{ int 15/88 Bios support }

   '{ Shared extended memory is easy if HIMEM.SYS is installed, let's see. }
   '{ We can find that out through the multiplex interrupt, Int &H2F       }
   Ver = DosVersion%                         '{ Int 2F supported only      }
   HimemSys = False                          '{ in DOS 3.0 or above.       }
   IF Ver MOD 256 >= 3 THEN                     '{ Himem.sys registers        }
                                             '{ itself with Int 2F and     }
      Regx.ax = &H4300                       '{ returns &H80 when 2F is    }
      InterruptX &H2F, Regx, Regx            '{ called w/ AX = &H43        }
      IF CarryClear%(Regx.flags) AND ((Regx.ax AND &HFF) = &H80) THEN
                                             '{ Now get the address of   }
         HimemSys = True                     '{ Himem's control function }
         Regx.ax = &H4310                    '{ returned in ES:BX and    }
         InterruptX &H2F, Regx, Regx         '{ place in our own pointer }
         segXMSControl = Regx.es             '{ variable.                }
         ofsXMSControl = Regx.bx             '{ variable.                }
      END IF
   END IF
END IF

'{ Do regular memory stuff }
LOCATE , 6
PRINT "ÄÄÄÄÄ Conventional Memory ÄÄÄÄÄ"

PRINT
'{ Display the dos memory installed }
InterruptX &H12, Regx, Regx
DOSmem = CLNG(Regx.ax) * 1024
LOCATE , 6
PRINT "DOS memory (bytes)      "; : PRINT USING "#######"; DOSmem

'{ Display the dos memory available }
Regx.ax = &H4800
Regx.bx = &HFFFF
InterruptX &H21, Regx, Regx
DOSmem = CLNG(Regx.bx) * 16
LOCATE , 6
PRINT "DOS memory available    "; : PRINT USING "#######"; DOSmem
PRINT

'{ Retrieve our PSP -- only valid if DOS 3.0+ }
Regx.ax = &H6200
InterruptX &H21, Regx, Regx
PrefixSeg = Regx.bx

'{ Do info on our locations, so user can sort our chaff from his wheat }
'{ Get the length of our MCB as our approximate memory usage }
LOCATE , 6
writes "Memory Viewer length     "
PRINT USING "######"; MemW(PrefixSeg - 1, 3) * 16

'{ Show where we start }
LOCATE , 6
writes "  Starting segment        "
WriteHexWord (PrefixSeg)
PRINT "h"

'{ Give transfer buffer length }
LOCATE , 6
writes "View Buffer length        "
PRINT USING "#####"; MaxHunk

'{ and our transfer buffer area location }
LOCATE , 6
writes "  Address            "
WriteHexWord VARSEG(DisplayBuff(1))
writes ":"
WriteHexWord VARPTR(DisplayBuff(1))
PRINT "h"



'{ Do expanded memory stuff in a box on the right side.}
LOCATE 3, 44
PRINT "ÄÄÄÄÄÄÄ Expanded Memory ÄÄÄÄÄÄÄ"

'{ Tell them if we have no expanded memory }
IF NOT EMMThere THEN
   LOCATE , 44
   PRINT ("No expanded memory accessible.")
ELSE
    '{Reduce EMS driver version by a factor of 10, and display it as a real.
    'Use DIV and MOD integer operations to keep floating point routines from
    'being incorporated into the EXE -- saves 2K. }
    LOCATE , 44
    PRINT "EMM Driver Version        ";
    PRINT USING "##"; EMMVer \ 10; : PRINT ".";
    PRINT USING "##"; (EMMVer MOD 10) * 10

    '{ Now get page frame address }
    Regx.ax = &H4100
    InterruptX &H67, Regx, Regx
    PageFrame = Regx.bx

    '{ Get hardware congiguration data. It contains raw page size. }
    Regx.ax = &H5900
    Regx.es = VARSEG(HardwareConfig)
    Regx.di = VARPTR(HardwareConfig)
    InterruptX &H67, Regx, Regx
    RawPageK = HardwareConfig.rawpagesize * 16 \ 1024

    '{ Get more hardware configuration data - raw page stuff }
    Regx.ax = &H5901
    InterruptX &H67, Regx, Regx
    RawCount = Regx.dx
    RawFree = Regx.bx

    '{ -- Display the EMS info -- }
    LOCATE , 44
    writes "Page frame segment         "
    WriteHexWord CLNG(PageFrame)
    PRINT

    '{ We show them the raw page size and counts; beyond that it's up to
    '  them.  We assume (as does most software) a standard page size of 16K in
    '  this version of our viewer, meaning that funny things will happen if
    '  an application has set up the EMS driver to use a different page size-
    '  data in handles using a non-standard page size may not display
    '  reliably, or at all. }
    LOCATE , 44
    PRINT "Standard page size          16K"
    LOCATE , 44
    PRINT "Raw page size              "; : PRINT USING "###"; RawPageK;
    PRINT "K"

    LOCATE , 44
    PRINT "              Allocated   Total"
    LOCATE , 44
    PRINT "Standard Pages  - "; : PRINT USING "#####"; PagesTotal - FreePgs;
    PRINT "   "; : PRINT USING "#####"; PagesTotal
    LOCATE , 44
    PRINT "   Bytes (K)    - "; : PRINT USING "#####"; (PagesTotal - FreePgs) * PageSize;
    PRINT "   "; : PRINT USING "#####"; PagesTotal * PageSize
    LOCATE , 44
    IF NOT EXBoth THEN
    LOCATE , 44
       PRINT "Raw pages       - "; : PRINT USING "#####"; RawCount - RawFree;
       PRINT "   "; : PRINT USING "#####"; RawCount
       LOCATE , 44
       PRINT "   Bytes (K)    - "; : PRINT USING "#####"; ((RawCount - RawFree) * RawPageK);
       PRINT "   "; : PRINT USING "#####"; RawCount * RawPageK
    END IF
    LOCATE , 44
    PRINT "Handles         - "; : PRINT USING "#####"; HandlesUsed;
    PRINT "   "; USING "#####"; HandlesTotal
END IF

'IF NOT EXBoth THEN PRINT                                  '{ Skip a line }

'{ Next do Extended Memory Info }
'We only show existence in QB version. XMS driver code is commented out as
'an exercise for the QuickBASIC programmer to convert to assembly code.
LOCATE , 44
PRINT "ÄÄÄÄÄÄÄ Extended Memory ÄÄÄÄÄÄÄ"

IF NOT XMThere THEN
   LOCATE , 44
   PRINT "No extended memory found."
ELSE
     LOCATE , 44
    PRINT "Total extended memory is ";
    PRINT USING "#####"; TotalXM; : PRINT "K"
     LOCATE , 44
    PRINT "Total directly available ";
    PRINT USING "#####"; Int15Avail; : PRINT "K"
    IF HimemSys THEN
       '{ Here we give the XMS specification version that the XMS driver
       ' is written for, and then the specific internal version of this driver}
        LOCATE , 44
        PRINT "XMS entry at         ";
        WriteHexWord (segXMSControl)
        PRINT ":";
        WriteHexWord (ofsXMSControl)
        PRINT "h"

'       PRINT "XMS spec/version  "; XMMVer \ 16; ".";
'       WriteHexByte XMMVer MOD 16
'       PRINT " / "; HimemVer \ 16; ".";
'       WriteHexByte HimemVer MOD 16
'       PRINT

       '{ Get XMS free memory, in K }
       '{ Himem.sys provides function &H08 to obtain free memory sizes,   }
       '{ but no function to return the number of free handles unless    }
       '{ info is requested using a valid handle. Since we don't know any}
       '{ previously allocated handle, we request one of our own, get the}
       '{ free handle count, then release our handle.                    }
       'asm                                
       '   mov AH, &H8                         '{ - QueryFreeExtendedMem.- }
       '   call [ptrXMSControl]           
       '   mov XMFree, ax                     '{ AX is largest free block }
       '   mov XMSize, dx                     '{ DX is total free memory  }
                                             '{  - Get XMS handles -     }
       '   mov AH, &H9                         '{ Request a block          }
       '   mov dx, 1                          '{ one K-byte long          }
       '   call [ptrXMSControl]               '{ Returns handle in DX     }
       '   push dx                            '{ Save it                  }
       '   mov AH, &HE                         '{ - Get Handle info -      }
       '   call [ptrXMSControl]           
       '   mov EMMResult, al                  '{ 1 if ok, 0 if not ok     }
       '   mov GeneralInfo, bl                '{ BL=handles if al = 1, or }
                                             '{ BL = &H81, VDISK detected }
       '   mov AH, &HA                         '{ Free block               }
       '   pop dx                             '{ that we requested        }
       '   call [ptrXMSControl]
'       END '{asm}                        
       LOCATE , 44
'      PRINT "Largest XMS free block   "; XMFree; "K"
       LOCATE , 44
'      PRINT "Total XMS available is   "; XMSize; "K"
'      If EMMResult = 1 Then
          LOCATE , 44
'         PRINT "XMS handles available     "; GeneralInfo + 1
'      Else
          LOCATE , 44
'         IF GeneralInfo = &H81 THEN PRINT "VDISK device installed."
      END IF  '{ Himem info }
   END IF    '{ Extended info }


   '{ Clear the memory display prompt, put ours up and wait for command }
   IF HimemSys OR EMMThere THEN                     '{ Offer handle info      }
      GotoXY 24, 25
      PRINT "< Handles >     < Cancel >";
      GotoXY WhereX - 8, WhereY
   ELSE
      GotoXY 34, 25
      PRINT "< OK >";
      GotoXY WhereX - 4, WhereY
   END IF                                          '{ 'H' gets handles      }
   LOCATE , , 1
   DO: Ech = INPUT$(1): LOOP UNTIL INSTR(CHR$(27) + CHR$(13) + "hH", Ech) > 0
   LOCATE , , 0
   ClrScr

 IF (UCASE$(Ech) = "H") AND (HimemSys OR EMMThere) THEN
   GotoXY 22, 25: writes "Searching handle list..."
   GotoXY 1, 1

   '{ Display header }
   FOR i = 1 TO 5
       writes "Hndle Bytes     "
   NEXT

   '{ Display a list of valid EMS handles and lengths }
   IF EMMThere THEN
      FOR XMHandle = 0 TO HandlesTotal
           Regx.ax = &H4C00                 '{ - GetHandlePages function - }
           Regx.dx = XMHandle               '{ for the requested handle    }
           InterruptX &H67, Regx, Regx
           XMResult = Regx.ax AND &HFF00    '{ 0 if ok, >0 if not, with    }
           BytesK = Regx.bx                 '{ handle's pages in bx        }
           '{ If Handle valid  show it and bytes }
           IF XMResult = 0 THEN
              WriteHexWord CLNG(XMHandle)
              IF EXBoth THEN PRINT "e";  ELSE PRINT "-";
              '{ Page size is in K, so the next calc works out to K }
              PRINT USING "#####"; BytesK * PageSize; : PRINT "K     ";
           END IF
       NEXT
   END IF '{ EMS handles }

   '{ Display a list of valid XMS handles and lengths }
   'If HimemSys Then
      '{ First test for HMA in use.  Try to allocate HMA }
      'asm
      '  mov ax, &H100                   '{ - Request HMA Function    - }
      '  mov dx, &HFFFF                  '{ Ask for the whole thing     }
      '  call [ptrXMSControl]
      '  mov XMResult, al               '{ 1 if ok, 0 if not           }
      '  mov HMAStatus, bl              '{ save  condition code        }
    '  END  '{ asm }

    '  If XMResult = 1 Then
      'asm
        '{ Now deallocate for others to use }
       ' mov ax, &H200                  '{ - Release HMA Function    - }
       ' call [ptrXMSControl]           '{ Assume success              }
    '  END  '{ asm }
    '  writes ("HMA -")

      '{ If our allocation was successful, HMA works and is not in use, so
      '  display its size in K }
    '  If XMResult = 1 then writes(64:5,"K   ")

      '{ Otherwise show its status }
    '  Select Case HMAStatus
    '     case &H91            : writes("in use   ")
    '     case &H90, &H80      : writes("none     ")
    '     case &H81            : writes("VDISK    ")
    '  END select '{ case }

    '  For XMHandle = 1 to 65535 do          '{ We don't know XMS capacity, }
    '      Begin                              '{ so must check all possible. }
          ' asm                  
          '    mov ax, &HE00                   '{ - GetHandleInfo function -  }
          '    mov dx, XMHandle               '{ for the requested handle    }
          '    call [ptrXMSControl]
          '    mov XMResult, al               '{ 1 if ok, 0 if not, with the }
          '    mov BytesK, dx                 '{ or handle's block length (K)}
     '      END
           '{ If Handle valid  show it and bytes }
     '      If XMResult > 0 then
     '         WriteHexWord (XMHandle)
     '         IF EXBoth THEN writes ("x") ELSE writes ("-")
     '         writes(BytesK:5,"K   ")
     '     END if
     ' next  '{ XMS handles }

   GotoXY 1, 25
   ClrEOL
   GotoXY 34, 25
   PRINT "< OK >";
   GotoXY WhereX - 4, WhereY
   LOCATE , , 1
   DO: Ech = INPUT$(1): LOOP UNTIL INSTR(CHR$(27) + CHR$(13), Ech) > 0
   LOCATE , , 0
 END IF   '{ Showing handles }


ClrScr


END SUB

