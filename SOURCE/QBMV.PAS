{-------------------------------------------------------------------------

                                   QBMV

                  Unit to display contents of a macro key

                  Written for Borland Turbo Pascal V 6.0

                     Copyright 1991, by John H. Eckert
                           All Rights Reserved


                                                   ... a component of the
                                                   QuickBasic Programmer
                                                   Desk Accessories ...
-------------------------------------------------------------------------}
{ History:           
01/11/91   0.30   Unit created out of the standalone QBMacro utility.
02/01/91   0.50   Macro key view split out for increased granularity
}
{-------------------------------------------------------------------------}
{$F+}                               { Far calls needed for overlays }
{$O+}                               { Unit may be overlaid          }
UNIT QBMV;

{ This unit displays the contents of a macro key, both the key and scan codes,
in both ASCII and hex formats. }

{==========================================================================}
{================================= Interface ==============================}
{==========================================================================}
INTERFACE


USES Crt, Dos, pdaSubs, PDAEDLN, QBMHelp, QBMFile;

PROCEDURE ViewMacroKey(var Choice:Byte);


{==========================================================================}
{============================ Implementation ==============================}
{==========================================================================}

IMPLEMENTATION



{ =============================  Display Macro Key  ========================
}
PROCEDURE ViewMacroKey(var Choice:Byte);

TYPE
String128= String[128];
String82 = String[82];
String80 = String[80];
String40 = String[40];
String13 = String[13];
String11 = String[11];
String4  = String[4];
MacroFile_t = File of String82;


VAR
CurrentMacroLine, TopMacroLine: Byte;
LastMacroLine, TextChr        : Byte;
OldMacro                      : Byte;
Key                           : Char;       { Last input key code }
TmpStr                        : PathStr;
ModeName                      : String11;
Title                         : String13;
Prompt                        : String70;


VAR
i,j,V1Key,V2Key   : Byte;
Row,Col           : Byte;

Begin
ClrScr;
MacroKey := Chr(Choice);      { Valid macro key          }
Macro := MacroNum(MacroKey);
If Macro = 0 Then
   Writeln('Ascii ',Choice,' is not a valid macro key.')
Else
   Begin
   GotoXY(10,1);
   Write('Macro Key: ',Chr(Choice));
   Write(' contains ',(Length(MacroLine[Macro])-2) DIV 2,' keystrokes');
   {Write(Length(MacroLine[Macro])); }
   If MacroLine[Macro,2] = #127 then
      Writeln('.')
   Else
      Writeln(', joined to ',MacroLine[Macro,2]);
   Row := 3; Col := 2;
   Writeln;
   Writeln('Char ');
   Write('Hex  ');
   Inc(Col,6);
   i := 3;
   While i < Length(MacroLine[Macro]) do
      Begin
      { First byte }
      GotoXY(Col, Row);
      V1Key := Ord(MacroLine[Macro,i]);
      V2Key := Ord(MacroLine[Macro,i+1]);
      Inc(i, 2);
      If V1Key <> 0 then
         If (V1Key <> 224) and (V2Key <> 0) then
            IF V1Key in [13,10,7] then
               Write(' ')
            Else
               Write(Chr(V1Key))
         Else
            Write('E0-')
      Else
         Write(' 0-');
      {Second byte}
      GotoXY(Col + 3,Row);
      If V2key < 240 Then
         IF V2Key in [13,10,7] then
            Write(' ')
         Else
            Write(Chr(V2Key))
      Else
         Begin
         GotoXY(Col,Row);
         If V2Key = 255 then Write('AltDn');
         If V2Key = 254 then Write('AltUp');
         If V2Key = 253 then Write('CtlDn');
         If V2Key = 252 then Write('CtlUp');
         If V2Key = 251 then Write('LSfDn');
         If V2Key = 250 then Write('LSfUp');
         If V2Key = 249 then Write('RSfDn');
         If V2Key = 248 then Write('RSfUp');
         If V2Key < 248 then Write('---',chr(V2Key));
         End;
      GotoXY(Col,Row+1);
      WriteHexByte(V1key); Write(':');
      WriteHexByte(V2Key);
      Inc(Col,6);
      IF Col > 60 Then
         Begin
         Inc(Row,3);
         Col := 2;
         End;
      End;
   End;
GotoXY(28,17); Write('<OK>'); GotoXY(29,17);
Ch := GetKey;
End; { ViewMacroKey }


END. { QBMV Unit }
