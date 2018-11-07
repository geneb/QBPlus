{-------------------------------------------------------------------------
                                 FILESORT

                An "Include" routine for sorting filenames

                  Written for Borland Turbo Pascal V 6.0

                     Copyright 1991, by John H. Eckert
                           All Rights Reserved


                                                   ... a component of the
                                                   QB Plus Desk Accessories
-------------------------------------------------------------------------}
{ Procedure to sort an array of Dos file names. Include this into the Pascal
program which predefines the array element length in "ElementSize".  Array
subscripts must fall between 1 and 2000.
}

PROCEDURE FileNameSort(Var SortList; { Generic variable parameter }
                           First, Last : Word);

Type
FileNameT   = String[ElementSize];         { Definition of our data array}
FileListT   = array[1..2000] of FileNameT;

VAR
FileList    : FileListT absolute SortList; { Overlay our array onto parm }
Element, Element1, Element2, Offset      : Integer;  {I,J,L,Spread}


{ Local procedure to swap array elements }
Procedure FNameSwap(Var FName1, FName2 : FileNameT);

Var
TempName : FileNameT;

Begin
     TempName    := FName1;
     FName1      := FName2;
     FName2      := TempName;
End;

Begin

{ Set comparison to half the number of records}
Offset := (Last - First) div 2;

While Offset > 0 Do
   Begin
   For Element := Offset + 1 To Last Do
      Begin
      Element1 := Element - Offset;
      While Element1 > 0 Do
         Begin
         Element2 := Element1 + Offset;
         If FileList[Element1] <= FileList[Element2] Then Element1 := 0 Else
            FNameSwap(FileList[Element1], FileList[Element2]);
         Element1 := Element1 - Offset;
         End;
      End;
      Offset := Offset Div 2;
   End;
End;
