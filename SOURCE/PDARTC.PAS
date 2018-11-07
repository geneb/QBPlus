{-------------------------------------------------------------------------
                                    pdartc

                Unit containing PDA's real time clock code

                  Written for Borland Turbo Pascal V 6.0

                     Copyright 1991, by John H. Eckert
                           All Rights Reserved


                                                   ... a component of the
                                                   QuickBasic Programmer
                                                   Desk Accessories ...
-------------------------------------------------------------------------}
{ History:           
04/08/91   0.85   Real time clock code lifted from QBProfiler.
}
{-------------------------------------------------------------------------}
{$F+}                               { Far calls needed for overlays }
{$O+}                               { Unit may be overlaid          }
UNIT pdartc;

{ Contains code to determine whether an AT compatible real time battery-run
   clock is installed, and to enable/disable the clock's periodic interrupt
   feature, and set the interrupt rate. The hardware must deliver the
   interrupt via INT 70h via the second interrupt controller and provide
   access to the RTC registers at Port 70h in the standard AT CMOS area,
   otherwise none of this will work. Works with PS/2's 50, 60, 70, 80.
   .. may have trouble with model 30.
}

{==========================================================================}
{================================= Interface ==============================}
{==========================================================================}
INTERFACE


USES Crt, Dos, pdaSubs;

PROCEDURE Disable_Rtc;
FUNCTION Find_Rtc : Boolean;
PROCEDURE SetRtcRate(Rate : Word);

{==========================================================================}
{============================ Implementation ==============================}
{==========================================================================}

IMPLEMENTATION


{============================  Enable_RTC  ============================
   Enables the AT compatible built-in real time clock periodic
   interrupts.  Called by main program at startup, and by counter
   increment interrupt handler on each RTC pulse.
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




{============================  Disable_RTC  ============================
   Disables the AT compatible built-in real time clock periodic
   interrupts.  Called by profiler and config units.
}
PROCEDURE Disable_RTC;
   BEGIN
   Port[$70] := $0B;                { select RTC register B       }
   RtcRegB := Port[$71];            { and check if already off.   }
   {IF ((RtcRegB AND $40) = 0) THEN }{ No, so set it.             }
     BEGIN
     RtcRegB := RtcRegB AND $BF;    { Clear bit six,              }
     Port[$70] := $0B;              { select RTC register B,      }
     Port[$71] := RtcRegB;          { and disable RTC.            }
     END;

   { Output from RTC is via IRQ8, so enable it also.}
   IRQ8 := Port[$A1];               { Retrieve the interrupt bit map, }
   IRQ8 := IRQ8 AND $FE;            { clear bit 0, and put it back.   }
   Port[$A1] := IRQ8;
   END;  { Disable_RTC }





{================================ SetRtcRate =========================}
{ Sets periodic interrupt interval on real time clock to rate passed in
   rate argument.
}
PROCEDURE SetRtcRate(Rate : Word);
Var
Divisor  : Byte;
RtcRegA  : Byte;


{============================ Enable/Disable ===============================
A pair of complementary inline asm macros that the compiler inserts directly
into the executable code to enable and disable processor interrupts at the
point wherever the procedure reference appears in the source code.
}
{ Re-enable interrupts }
PROCEDURE Enable; INLINE( $FB );    { STI }

{ Disable interrupts }
PROCEDURE Disable; INLINE( $FA );    { CLI }


Begin

{ Constrain to rates of 2 -- 32768 }
If Rate < 2 then Rate := 2;
If Rate > 32768 then Rate := 32768;

{ To convert from rate to divisor, shift the rate left, counting each shift,
   until 65536 is reached or exceeded. The number of shifts equal the
   divisor at the default time base frequency of 32.768KHz.(bit 5 of Rtc
   register Ah set) }
Divisor := 1;
While Rate < 32767 Do
   Begin
   Rate := Rate Shl 1;
   Inc(Divisor);
   End;

{ Now set the divisor into the low nibble of register Ah }
Disable;                               { Halt rupts a while                }
Port[$70]   := $A;                     { Select register Ah                }
RtcRegA     := Port[$71];              { and get into variable             }
RtcRegA := (RtcRegA AND $F0) + Divisor;{ Clear low nibble, replace w/ value}
Port[$70]   := $A;                     { Select register Ah                }
Port[$71]   := RtcRegA;                { and store variable                }
Enable;

End; { SetRtcRate }






{============================== Find_Rtc =============================}
{  Confirm presence of built-in real time clock (RTC). }
FUNCTION Find_Rtc : Boolean;
Const
   RTC_Feature_Mask  =  $60;              { bits 5 and 6 set - use AND  }

Var
   Regs                          : Registers;
   Model_Byte                    : Byte ABSOLUTE $F000:$FFFE;
   ptrFeature_Byte               : ^Byte;

Begin
IF (Model_Byte > $FC) OR (Model_Byte = $FB) THEN
   Find_RTC := False                { PC, XT, jr }
ELSE
   BEGIN
      { Byte 5 of system configuration table has bits 5-6 set if RTC. }
      Regs.AH :=  $C0;                  { Locate table and grab byte 5}
      intr( $15, Regs );
      ptrFeature_Byte := ptr( Regs.ES, Regs.BX + 5 );
      IF ( ptrFeature_Byte^ AND RTC_Feature_Mask ) <> 0 THEN
         Find_RTC := True
      ELSE
         Find_RTC := False;
   END;
End; { Find_Rtc }

END. { Rtc Unit }
