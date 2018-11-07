{-------------------------------------------------------------------------
                                  PICKER

                An "Include" routine for picking filenames

                  Written for Borland Turbo Pascal V 6.0

                     Copyright 1991, by John H. Eckert
                           All Rights Reserved


                                                   ... a component of the
                                                   QB Plus Desk Accessories
-------------------------------------------------------------------------}

{ =============================== Picker ===============================}
{ A limited purpose picklist utility functionally similar to QuickBasic's.
Pass the address of the first element in an array of fixed-length strings,
and the number of elements. The chosen element index is returned in Choice
and the code of the last keypress in Key (to distinguish a simple enter from
cancel and field movement commands.) The selection box is drawn with the
upper left of the box at the current cursor position, and the screen is not
saved; however the caller's window settings and cursor position are preserved.
The routine uses the Box and Inverse procedures.

Limitations are in the passed array which must be of String[13] element size
and 100 elements maximum.  As a caller, be sure to match the array declaration
of the passed picklist with the declaration in this procedure. If the array
is on the heap and accessed via a pointer, call this routine as follows:

            Picker(ptrNameList^, NameListCount, Choice, Key);

If the array NameList is in the data segment, use:

            Picker(NameList, NameListCount, Choice, Key);
 
}

PROCEDURE Picker( Var PickList;     { Generic variable parameter }
                      Elements      : Word;
                  Var Choice        : Word;
                  Var Key           : Char);

CONST
MaxNameList    = 100;                       { Our defaults are 100 elements}
ColWidth       = 13;                        { Each list column is 13 wide  }
Cols           = 4;                         { List columns are four        }
Rows           = 6;                         { horiz. pick rows are 6       }
ScrCols        = Cols * ColWidth;           { Screen cols within box       }
ScrnOnes       = Rows * Cols;               { Total elements in box        }

TYPE
OneString      = String[ColWidth];          { Definition of our data array}
NameList       = array[1..MaxNameList] of OneString;

Var
ElementList    : NameList absolute PickList; { Overlay our array onto parm }
Ch             : Char;                       { Holds the current keypress  }
i              : Byte;                       { Generic counter             }
OrgWinMax      : Word;                       { Cursor and screen save info }
OrgWinMin      : Word;
OrgWhereX      : Byte;
OrgWhereY      : Byte;
OrgAttr        : Byte;
OurWhereX      : Byte;                       { Cursor position relative to }
OurWhereY      : Byte;                       { the full screen.            }
UpperLeftOne   : Word;                       { Element in upper left of box}
LastULone      : Word;                       { Previous element there      }
CurrentOne     : Word;                       { Current highlighted element }
LowerRightOne  : Word;                       { Element in box lower right  }
LastOne        : Word;                       { Last element in the array   }
Done           : Boolean;                    { Flag that choosing is over  }

Begin
{ Save particulars of the window and cursor }
OrgWhereY   := WhereY;
OrgWhereX   := WhereX;
OrgWinMax   := WindMax;
OrgWinMin   := WindMin;
OrgAttr     := TextAttr;
{ Compute absolute cursor position for Window }
OurWhereX   := OrgWhereX + Lo(OrgWinMin);
OurWhereY   := OrgWhereY + Hi(OrgWinMin);


{Make a box at the picker site }
Box(OrgWhereX, OrgWhereY, ScrCols + 2, Rows + 2);

{ Limit things to within the box }
Window(OurWhereX + 1, OurWhereY + 1, OurWhereX + ScrCols, OurWhereY + Rows);
ClrScr;

{ Initialize total count }
LastOne := Elements;

{ Use the passed Choice index, if not zero }
If (Choice > 0) and (Choice <= LastOne) then
   Begin
   UpperLeftOne   := Choice;
   LastULone      := 0;
   CurrentOne     := Choice;
   End

{ Otherwise, start with the beginning of the array }
Else
   Begin
   UpperLeftOne   := 1;
   LastULone      := 0;
   CurrentOne     := 1;
   End;

Done           := False;
Repeat

   { If necessary, move upperleft element so current element will show in box}
   While CurrentOne < UpperLeftOne Do Dec(UpperLeftOne, Rows);
   While CurrentOne > (UpperLeftOne + ScrnOnes - 1) Do Inc(UpperLeftOne, Rows);

   { Redraw the listing if upper left changed }
   If UpperLeftOne <> LastULone Then
      Begin
      ClrScr;
      LastULone   := UpperLeftOne;
      i := UpperLeftOne; LowerRightOne := UpperLeftOne;
      While (LowerRightOne <= LastOne) and
            (LowerRightOne < (UpperLeftOne + ScrnOnes)) Do
         Begin
         GotoXY(1 + ((i - UpperLeftOne) Div Rows * ColWidth),
               1 + ((i - UpperLeftOne) Mod Rows));
         Write(ElementList[i]);
         Inc(i);
         Inc(LowerRightOne);
         End;
      End;

   { Position cursor at current element and highlight it }
   GotoXY(1 + ((CurrentOne - UpperLeftOne) Div Rows * ColWidth),
         1 + ((CurrentOne - UpperLeftOne) Mod Rows));
   Inverse(13);

  { Respond to keypress }
  ch := ReadKey;
  CASE ch OF
      #0,#224 : BEGIN { extended key codes }
           ch := ReadKey;
           CASE ch OF
               #71 : { home }
                     CurrentOne := 1;
               #80 : { down arrow }
                     IF CurrentOne < LastOne THEN
                        Inc(CurrentOne);
               #75 : { left arrow }
                     IF (CurrentOne > Rows)  THEN
                        Dec(CurrentOne, Rows);
               #77 : { right arrow }
                     IF CurrentOne + Rows < LastOne THEN
                        Inc(CurrentOne, Rows)
                     Else if LastOne - CurrentOne <= Rows Then
                        CurrentOne := LastOne;
               #79 : { end }
                     CurrentOne := LastOne;
               #72 : { up arrow }
                     IF CurrentOne > 1 THEN
                        Dec(CurrentOne);
               #15 : { shift tab }
                     Done := True;
               END; { Case ch = #0 }
           END; { Extended codes }
      #09 : { tab }
            Done := True;
      #13 : { enter }
            Done := True;
      #27 : { ESC }
            Done := True
      Else
            Begin
            i := 0;
            Ch := Upcase(Ch);
            While ( i <= LastOne) and (Ch <> ElementList[i,1]) Do
               Inc(i);
            If i <= LastOne Then CurrentOne:= i;
            End;
   END; { KeyPress }

   { Clear the highlight to make room for another }
   Inverse(13);

Until Done;

Key      := Ch;
Choice   := CurrentOne;
{ Clean things up }
WindMax     := OrgWinMax;                    { Restore window     }
WindMin     := OrgWinMin;
GotoXY(OrgWhereX, OrgWhereY);                { Replace cursor     }
End; { Picker }
