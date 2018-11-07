{-------------------------------------------------------------------------
                                  PDAMath

                      Unit with special math routines

                  Written for Borland Turbo Pascal V 6.0

                     Copyright 1991, by John H. Eckert
                           All Rights Reserved


                                                   ... a component of the
                                                   QuickBasic Programmer
                                                   Desk Accessories ...
-------------------------------------------------------------------------}
{ History:           
04/25/91   0.88   Selected routines to support 64-bit integers
                  incorporated into this overlay unit.
}
{-------------------------------------------------------------------------}
{$F+}                               { Far calls needed for overlays }
{$O+}                               { Unit may be overlaid          }
UNIT PDAMath;

{  This unit provides specialty math routines not part of the standard
   Pascal language or Borland extensions.  As an overlay unit, it is
   brought into memory only by those units which use it.  Routines are:

      Sub64 -- a routine to subtract a 64 bit unsigned integer (qword).
               Pass the smaller value in MinusVal, the larger in Result
               and the difference is returned in Result. You can also
               use this to compare two qwords -- if the first value is
               bigger or equal to the second, the return code is 0,
               otherwise it is 1.

      Mult64 - multiplies two LongInts as though they were unsigned,
               returning a 64-bit unsigned value in the qword, Result.

      Div64 -- Divides the qword, Dividend, by Divisor, a longint treated
               as an unsigned value, and returns the quotient as an
               unsigned 64-bit qword in Dividend.

      Num64toStr -   Converts a 64-bit qword to a string with optional
               comma thousands separator.

   Function calls return a one byte non-zero error code.

   The init code of the unit allocates a small amount of heap space for
   a math table it computes on startup. The heap memory is not deallocated
   and is thus tied up throughout the program, and this unit should thus be
   called for initialization early so that its heap allocation will occur
   first and thereby reduce likelihood of eventual heap fragmentation.
}

{==========================================================================}
{================================= Interface ==============================}
{==========================================================================}
Interface


Uses Dos, Crt, pdaSubs;

Type
qWord                   = array[1..4] of Word;   { the 64-bit type         }
DNumsT                  = array[0..19] of qword; { our power of 10 table   }

Var
ptrDNum                 : ^DNumsT;

FUNCTION Sub64(var Result, MinusVal: qword): Byte;
FUNCTION Mult64(Multiplicand, Multiplier : LongInt; var Result : qWord) : Byte;
FUNCTION Div64(var Dividend: qword; Divisor : LongInt): Byte;
PROCEDURE Num64toStr(Int64 : qWord; var OutString : String; Comma : Boolean);
PROCEDURE MathInit;

{==========================================================================}
{============================ Implementation ==============================}
{==========================================================================}
Implementation



var
mResult                 : Byte;             { Math64 return code holder    }
lArg1, lArg2            : LongInt;          { Misc. longint arguments      }




{=============================== Sub64 ====================================}
{  Subtract a 64 bit value (MinusVal) by another 64 bit value (Result),
   leaving the answer in the value, Result.  Return byte is zero if success,
   else there was an underflow.
}
Function Sub64(var Result, MinusVal: qword): Byte;

Begin


{ We'll set pointers to both values }
asm
   Mov @Result, 0                { Clear return flag assuming success   }
   push ds                       { Need to save ds                      }
   lds si, MinusVal              { Value to subtract in ds:si           }
   les di, Result                { Subtrahend/result in es:si           }
   mov cx, 8                     { 8 bytes to subtract                  }
   cld                           { Upward direction                     }
   clc                           { Start with clear carry               }

   { Subtract bytes one by one, low to high. }
@Sub:
   lodsb                         { Get next byte of the MinusVal        }
   sbb byte ptr [es:di], al      { Subtract from Result -> Result       }
   inc di                        { Point to next Result byte            }
   loop @Sub                     { Go for cx (8) bytes total            }

   { Restore register }
   pop ds

   { Signal return code underflow }
   rcl @Result, 1                { Shift any carry(underflow) in return }
end; {asm}
End; { Sub64 }






{============================= Mult64 ===================================}
{  Multiply Unsigned Longs, producing a 64-bit unsigned result. A return
   value of zero indicates success.
}
Function Mult64(Multiplicand, Multiplier : LongInt; var Result : qWord) : Byte;


Begin

asm
   les di, Result                    { Point es:di at 64 bit result and    }
   xor ax, ax                        { Init (zero) the area                }
   mov [es:di],ax
   mov [es:di+2],ax
   mov [es:di+4],ax
   mov [es:di+6],ax

   mov @Result, al                     { Also zero the result code.        }

   { Multiply low word of multiplier
      by multiplicand, store in results}
   mov ax, Word ptr Multiplier
   mul word ptr Multiplicand
   mov [es:di], ax;
   mov [es:di+2],dx;
   mov ax, Word ptr Multiplier + 2
   mul word ptr Multiplicand + 2
   mov [es:di+4], ax;
   mov [es:di+6], dx;

   { Multiply high word of multiplier
      by multiplicand, add into results, place
      shifted two to the left}
   mov ax, Word ptr Multiplier + 2
   mul word ptr Multiplicand
   add [es:di+2], ax;
   adc [es:di+4],dx;
   mov ax, 0
   adc [es:di+6], ax;
   mov ax, Word ptr Multiplier
   mul word ptr Multiplicand + 2
   add [es:di+2], ax;
   adc [es:di+4], dx;
   mov ax, 0
   adc [es:di+6], ax;
end; {asm}

End; { Multiply }





{=============================== Div64 ====================================}
{  Divide a 64 bit value (Dividend) by an unsigned long integer (Divisor),
   discarding any remainder, and returning the Quotient in Dividend.  Return
   byte is zero if success, else is 1 for division by/into zero.
}
Function Div64(var Dividend: qword; Divisor : LongInt): Byte;

Var
   Bits        : Byte;

Begin

Div64 := 0;                            { Assume success           }

{ Don't divide by zero, return error code. }
If Divisor = 0 then
   Begin
   Div64 := 1;
   Exit;
   End;

{ Don't divide into zero either, return error code. }
If (Dividend[1] = 0) and (Dividend[2] = 0)
   and (Dividend[3] = 0) and (Dividend[4] = 0) then
   Begin
   Div64 := 1;
   Exit;
   End;

{ Routine to divide Result by bx:cx with quotient back in Dividend.  We'll
  gradually shift dividend up and when an amount greater than the divisor
  spills out the top, we'll subtract the divisor from it and put a bit into
  the bottom of the dividend as a building quotient. }
asm
   mov Bits, 64                        { 64-bit divide               }
   xor ax, ax                          { Clear the target compare    }
   xor dx, dx                          { area.                       }
   mov bx, Word ptr Divisor+2          { Divisor into bx:cx          }
   mov cx, Word Ptr Divisor
   les di, Dividend                    { point es:di at Dividend     }
    
@Divide:
   { Shift a bit from top of Dividend into dx:ax                           }
   shl word ptr [es:di], 1     { Shift zero into quotient at this point    }
   rcl word ptr [es:di+2], 1   { Everything else up one place  ...         }
   rcl word ptr [es:di+4], 1
   rcl word ptr [es:di+6], 1
   rcl ax, 1                    { ... and into dx:ax                       }
   rcl dx, 1
   jc @q_inc                    { Overflowed dx:ax, bump quotient          }

   { Compare dx:ax to divisor in bx:cx }
   cmp dx, bx
   jb @NextBit
   ja @q_inc
   cmp ax, cx
   jb @NextBit

   { Reduce top of Dividend by value of divisor, and increment quotient. }
@q_inc:
   sub ax, cx                      { Subtract low order, overflow into CF, }
   sbb dx, bx                      { then hi order with CF.                }
   add word ptr [es:di], 1         { put in a 1 since divisor < dividend.  }

   { Repeat process for next of the 64 bits until we've done all 64  }
@NextBit:
   dec Bits
   cmp Bits, 0
   jne @Divide                      { keep going 64 times                  }
end; { asm }
End;{ Divide }





{================================ Num64toStr ==============================}
{ Converts a 64-bit unsigned integer, to a pascal string.  Insert comma
   separators if Comma is true. The qword array, dnum, must first have been
   initialized to powers of 10 from 1 to 1 x 10^19.  The OutString argument
   must point to a string of at least 25 characters.
}
Procedure  Num64toStr(Int64 : qWord; var OutString : String; Comma : Boolean);
Var
   dn, sn, dd        : Byte;        { Decimal, string and decimal val ptrs }
   mpResult          : Byte;        { For storing results of Sub64         }
   CommaCounter      : Byte;        { Place counter for comma              }
   FirstDigit        : Boolean;     { False if output is in leading spaces }
   Snum              : String[80];  { Work space to build ascii string     }
   qTemp             : qword;       { Temp qword storage                   }


Begin

{ Constrain field length to 80 }
{If Places > 80 then Places := 80; }
Sn := 1;

{ Assume Dnum array has been initialized }

{Init other stuff }
FirstDigit := False;             { Flag for leading blanks                 }
dn := 19;                        { Point at largest power of ten           }
dd := 0;                         { Init decimal value builder to 0         }
CommaCounter := 3;               { Init comma place counter for 20-byter   }

{ Successively subtract powers of 10 from the 64 bit value,
  placing the appropriate decimal character at the proper place
  position in the output string.  We begin with 1 x 10^19. }
Repeat
   qTemp := Int64;                  { Store temporarily for the sub/compare}
   If Sub64(qTemp, ptrdnum^[dn]) = 0 Then    { 0 when qTemp is less or equ.}
      Begin
      mpResult := Sub64(Int64, ptrdnum^[dn]);{ Subtract this power of ten  }
      inc(dd);                            { Increment the multiplier       }
      If FirstDigit = False then          { Indicate we have our first     }
         FirstDigit := True;              { digit & end of leading blanks  }
      End
   Else
      Begin                               { If 10-power is > qword, then   }
      If FirstDigit then                  { put in  the  }
         Begin                            { ascii value of decimal multipr }
         Snum[sn] := chr(dd + $30);
         inc(sn);                         { Point to next text position,   }
         End;
      dec(dn);                            { next lower power of ten, and   }
      dd := 0;                            { reset decimal multiplier.      }
      If Comma then Inc(CommaCounter);    { Advance comma cntr if enabled. }
      If CommaCounter > 3 Then            
         Begin                            { If time to insert comma, reset }
         CommaCounter := 1;               { comma counter, and insert it   }
         If (FirstDigit) and
            (dn > 0) then                 { in string if we are in the     }
            Begin
            Snum[sn] := ',';               { digits, else stuff another    }
            Inc(Sn);                       { Skip ahead to next asc pos    }
            End;
         End;
      End;
Until dn = 0;                             { Keep at it till last 10-power  }


dec(Sn);                                  { Point Sn back at last digit    }
If FirstDigit then                        { If we have a value to output,  }
   Snum[0]:= chr(Sn)                      { truncate string to text length }
Else
   Begin                                  { Otherwise, set string length to}
   Sn := 1;                               { one digit, a zero.             }
   Snum := '0';
   End;

{ Print the result }
(*If Places > Sn Then                       { Output the leading banks where  }
   For i := Sn to Places - 1 Do           { ascii text len is less than    }
      Write(' ');                         { specified field length.        }
Write(Snum);*)                              { Now do the ascii value string   }

{ Pass string back }
OutString := Snum;
End; { Write64 }




{----======++++++::::::<<<<<< INITIALIZATION >>>>>>::::::++++++======-------}
{___________________________________________________________________________}
{=============================== MathInit ==================================}
{  Initializes the PDAMath unit, creating a table of powers of 10 for
   displaying 64 bit unsigned integers.
}
PROCEDURE MathInit;
Begin

{ Get some heap for table data. We'll keep through whole program. }
GetMem(ptrDNum, SizeOf(DNumsT));         { 160 bytes }


{ Init array of powers of 10 }
mResult  := Mult64(0, 1, ptrDNum^[0]);
mResult  := Mult64(1, 1, ptrDNum^[1]);
lArg1    := 1;
lArg2    := 1;
For i := 2 to 10 Do
   Begin
   lArg1 := lArg1 * 10;
   mResult := Mult64(lArg1, lArg2, ptrDNum^[i]);
   End;

For i := 11 to 19  Do
   Begin
   lArg2 := lArg2 * 10;
   mResult := Mult64(lArg1, lArg2, ptrDNum^[i]);
   End;
End; { MathInit }
End. { PDAMath Unit }
