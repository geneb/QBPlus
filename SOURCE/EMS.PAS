{-------------------------------------------------------------------------

                                     EMS

                   Unit to provided limited EMS support

                  Written for Borland Turbo Pascal V 6.0

                     Copyright 1991, by John H. Eckert
                           All Rights Reserved


                                                   ... a component of the
                                                   QB Plus Desk Accessories
-------------------------------------------------------------------------}
UNIT EMS;

Interface

{$F+}                               { Far calls needed for overlays }
{$O+}                               { Unit may be overlaid          }

Uses Dos, pdaSubs;

PROCEDURE FindEMM;

Implementation


{ =============================== FindEMM ===============================
Determines whether expanded memory and a driver for it exist and, if so,
sets up global information about EMM needed by other routines.

Exports values in:                              Calls:
      EMMThere          W                          Intr
      Reg               W
      EMMVer            W
      FreePages         W
      PagesTotal        W
      PageSize          W
      HandlesUsed       W
      HandlesTotal      W

}
PROCEDURE FindEMM;
Type
EMMNameT = Array[1..8] of Char;                    { This allows us to de- }
                                                   { reference and compare }
                                                   { EMM's 8-byte ID toÄÄ¿ }
Const                                              {                     ³ }
EMMID             : EMMNameT = ('E','M','M','X','X','X','X','0'); { <ÄÄÄÄÙ }

Var
EMMResult         : Byte;
EMMName           : ^EMMNameT;                     {Eventual ptr to ID bytes} 

Begin

{ Let's see if we have expanded memory manager resident }     
EMMThere := False;                                  { Assume not there    } 
Reg.AX  := $3567;                          { Call DOS for the int 67 vector }
Intr($21, Reg);                            { We make a pointer to the 8-byte}
EMMName := Ptr(Reg.ES, $A);                { ID with EMM's seg in ES and the}
If EMMName^ = EMMID then                   { offset of $0A, then dereference}
   Begin                                   { and compare to EMMXXXX0        }
   { Now get version }
   Reg.AX    := $4600;
   Intr($67, Reg);
   EMMResult := Reg.AH;                                { Look for trouble    }
   EMMVer    := Reg.AL;                                { BCD formatted       }
   If (EMMResult = 0) and (EMMVer >= 40) Then          { Need LIM 4.0 or up  }
      Begin
      EMMThere := True;                                { Whew, made it     }
      { Get Unallocated and total page count }                
      Reg.AX     := $4200;                              
      Intr($67, Reg);
      FreePgs    := Reg.BX;
      PagesTotal := Reg.DX;
      PageSize   := 16; {K}                            { 16K is standard   }

      { Get handles in use }
      Reg.AX        := $4B00;
      Intr($67, Reg);
      HandlesUsed   := Reg.BX;

      { Get handles in all }
      Reg.AX        := $5402;
      Intr($67, Reg);
      HandlesTotal  := Reg.BX;  
      End;
  End;
End; { FindEMM }
End. { EMS UNIT }
