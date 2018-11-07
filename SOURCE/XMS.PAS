{-------------------------------------------------------------------------

                                     XMS

                   Unit to provided limited XMS support

                  Written for Borland Turbo Pascal V 6.0

                     Copyright 1991, by John H. Eckert
                           All Rights Reserved


                                                   ... a component of the
                                                   QB Plus Desk Accessories
-------------------------------------------------------------------------}
UNIT XMS;

{$F+}                               { Far calls needed for overlays }
{$O+}                               { Unit may be overlaid          }

Interface

Uses Dos, pdaSubs;
{ This unit examines the machine for evidence of extended memory. If its
BIOS supports the int15/88 Get Extended Memory Size function, then the size
in K is placed in Int15Avail;  and if there is a CMOS extended memory size
value that is in a reasonable range, that value is placed in TotalXM; and if
both are there, XMThere is made True.

Whether or not Extended memory is found via Int15 or CMOS, a further exam is
made for a operable XMS driver, and if found, XMThere and HimemSys is made
True with the XMS version supported in XMMVer, the driver's revision number
in HimemVer and the far pointer to the driver's control entry point in the
pointer ptrXMSControl.
}

PROCEDURE FindXMM;

Implementation


{ =============================== FindXMM ===============================
Determines whether extended memory and a driver for it exist and, if so,
sets up global information about XMM needed by other routines.

Exports values in:                           Calls:
   XMThere           W                          Intr
   Reg               W                          CarryClear
   Int15Avail        W                          DosVersion
   TotalXM           W
   HimemSys          W
   ptrXMSControl     W
   XMMVer            W
   HimemVer          W

}
PROCEDURE FindXMM;
var
  Ver                 : Word;
  ModelByte           : Byte absolute $F000:$FFFE;

Begin
XMThere := False;                          { Assume not  }

   { See if this BIOS supports int 15/88, - Get Extended Mem Size - }
   Reg.AX := $8800;                          { PC/XT and PS/2 30    }
   Intr($15,Reg);                            { return $80 and $86   }
   Int15Avail := Reg.AX;                     { respectively in AH   }
   IF (CarryClear and (Hi(Int15Avail) < $80)) OR     { & carry set. }
       (ModelByte = $FC) or (ModelByte = $F8) Then { PC's with CMOS  }
      Begin

      { We can't rely on size value returned by 15h/88h, since another
      memory manager/os may have hooked int15h to protect extended
      memory it may have taken for itself. }
      { Assume a cmos machine configuration data register exists that
      has the actual extended memory size in 1K byte blocks. }                     
      Port[$70] := $18;                      { Select port $18 for   }                                                
      TotalXM   := Port[$71] * 256;          { high byte ...         }
      Port[$70] := $17;                      { ... port $17 for low  }
      TotalXM   := TotalXM + Port[$71];
      If (TotalXM > 0) and (TotalXM < 33000) Then { keep reasonable  }
         XMThere := True;
      End;  { int 15/88 Bios support }

      { Shared extended memory is easy if HIMEM.SYS is installed, let's see. }
      { We can find that out through the multiplex interrupt, Int $2F        }
      Ver := DosVersion;                          { Int 2F supported only    }
      HimemSys := False;                          { in DOS 3.0 or above.     }
      If Lo(Ver) >= 3 then                        { Himem.sys registers      }
         Begin                                    { itself with Int 2F and   }
         Reg.AX := $4300;                         { returns $80 when 2F is   }
         Intr($2F, Reg);                          { called w/ AX = $43       }
         If CarryClear and (Reg.AL = $80) Then
            Begin                                 { Now get the address of   }
                                 { Himem's control function }
            Reg.AX := $4310;                      { returned in ES:BX and    }
            Intr($2F, Reg);                       { place in our own pointer }
            ptrXMSControl := Ptr(Reg.ES, Reg.BX); { variable.                }
            { Get XMS Version }
            XMMVer := $00;                        {    - XMS GetVersion -    }
            asm                                   { function returning a 16- }
               mov AX, XMMVer;                    { bit BCD number in AX, w/ }
               call [ptrXMSControl];              { major in hi, minor in lo }
               mov XMMVer, AX;                    { or zero, if failure      }
               mov HimemVer, BX;                  { Internal driver version  }
            end;
            If XMMVer > 0 then                    { XM exists, XMS works     }
               Begin
               XMThere := True;
               HimemSYS := True;
               End;
            End;  { Himem test }
         End;   { dos 3, himem test }

End; { FindXMM }

End. { XMS Unit }
