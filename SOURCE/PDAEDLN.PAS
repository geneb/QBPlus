{-------------------------------------------------------------------------

                                  PDAEDLN

            Unit to gather/edit a line of text from the keyboard

                  Written for Borland Turbo Pascal V 6.0

                     Copyright 1991, by John H. Eckert
                           All Rights Reserved


                                                   ... a component of the
                                                   QuickBasic Programmer
                                                   Desk Accessories ...
-------------------------------------------------------------------------}
{ History:           
01/15/91   0.30   Unit created out of the GetEdLn include utility.
}
{-------------------------------------------------------------------------}
{$F+}                               { Far calls needed for overlays }
{$O+}                               { Unit may be overlaid          }
UNIT PDAEDLN;

{ We put this into an overlay unit to be shared by several other units that
need this routine.  It would take space full-time in the SUBs unit, and
since Turbo Pascal allows one overlay to call another, this unit need only
be loaded when the others call it.  Further, since these calling units are
smaller than the overlay buffer size, both the caller and this unit can
be active concurrently.
 }
{==========================================================================}
{================================= Interface ==============================}
{==========================================================================}
INTERFACE


USES Crt, Dos, pdaSubs;

PROCEDURE GetEditLine(var  TextLine    : String;
                           StrLength   : Byte;
                      var  Key         : Char);
PROCEDURE Picker( Var PickList;     { Generic variable parameter }
                      Elements      : Word;
                  Var Choice        : Word;
                  Var Key           : Char);

{==========================================================================}
{============================ Implementation ==============================}
{==========================================================================}

IMPLEMENTATION

{$I GetEdLn.PAS}
{$I PICKER.PAS}
END. { PDAEDLN Unit }
