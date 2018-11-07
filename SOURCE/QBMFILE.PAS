{-------------------------------------------------------------------------

                                 QBMFile

               Unit to handle macro disk file operations

                  Written for Borland Turbo Pascal V 6.0

                     Copyright 1991, by John H. Eckert
                           All Rights Reserved


                                                   ... a component of the
                                                   QuickBasic Programmer
                                                   Desk Accessories ...
-------------------------------------------------------------------------}
{ History:           
01/11/91   0.30   Unit created out of the standalone QBMacro utility.
}
{-------------------------------------------------------------------------}
{$F+}                               { Far calls needed for overlays }
{$O+}                               { Unit may be overlaid          }
UNIT QBMFile;
{ Unit contains the routines to load and save keystrokes.  Called by PDAInit
 on startup to load any keystroke file specified on the command line.  Also,
 called by the QBM unit when the load or file save option is invoked from
 the menu. Finally, called by the main PDA module at exit, if the flag
 indicating macros have changed but not been saved is set.  Uses GetEditLine
 procedure in the PDAEDLN overlay unit for filename input in SaveMacros.}
{==========================================================================}
{================================= Interface ==============================}
{==========================================================================}
Interface

USES Dos, Crt, PDASubs, PDAEDLN;

PROCEDURE LoadKeyFile(var TmpStr:PathStr);
PROCEDURE SaveMacros;

{==========================================================================}
{============================ Implementation ==============================}
{==========================================================================}
Implementation


{=============================== LoadKeyFile ===========================}
PROCEDURE LoadKeyFile(var TmpStr:PathStr);
Begin
Assign(Macrofile, TmpStr);
{$I-}Reset(Macrofile);{$I+}
IOResultCode := IOResult;
If IOResultCode <> 0 Then
   Begin
   Writeln;
   Write('     (Code ',IOResultCode,')  Cannot read file: ',TmpStr);
   Ch := GetKey;
   End  { Resultcode <> 0}
Else
   Begin
   i:= 1; {$I-}
   Repeat
      Read(Macrofile, MacroLine[i]);
      IOResultCode := IOResult;
      If IOResultCode <> 0 then Write(IOResultCode);
      Inc(i);
   Until (i > MacroLines) or (eof(Macrofile));
   Close(Macrofile); {$I+}
   MacrosChanged := False;
   End;  { Resultcode = 0}
End; { LoadKeyFile }





{===============================  SaveMacros  ===========================}
Procedure SaveMacros;
VAR
SaveResult     : Byte;           { I/O save return code  }
TmpStr         : PathStr;        { Temp filename space   }
FoundName      : SearchRec;      { Results of FSearch    }
Key            : Char;           { Last input key code   }

Begin
Repeat 
Repeat
   Ch := #27;
   TmpStr := '';
   Write('Enter the file name for saving: ');
   GetEditLine(TmpStr, 40, Key);
   If Length(TmpStr) > 0 then
      Begin
      Ch := 'Y';
      FSplit(TmpStr, MacDir, MacName, MacExt);
      If MacExt = '' then MacExt := '.KQF';
      TmpStr := MacDir + MacName + MacExt;
      FindFirst( TmpStr, Archive, FoundName );

      IF DosError = 0 Then
         Begin
         SaveResult := DosError;
         Writeln;Write('File already exists, replace (Y/N)? ');
         Ch := GetUpKey;
         Writeln;
         End;

      End
   Else Ch := #27;

Until (Ch IN ['Y',#27]);

IF Ch = 'Y' then
   Begin
   SaveResult := 0;
   DosError := 0;
   {Write('Writing ',TmpStr);}
   Assign(Macrofile, TmpStr);
   {$I-}Rewrite(Macrofile);{$I+}
   IOResultCode := IOResult;
   SaveResult := IOResultCode;

   If IOResultCode <> 0 Then
      Begin
      Writeln;
      Write('(Code ',IOResultCode,') ','Cannot write file: ',TmpStr);
      Ch := GetKey;
      Writeln;
      End
   Else
      Begin
      i:= 1;
  {$I-}Repeat
         Write(Macrofile, MacroLine[i]);
         IOResultCode := IOResult;
         If IOResultCode <> 0 then SaveResult := IOResultCode;
         Inc(i);
      Until (i > MacroLines);
      Close(Macrofile);  {$I+}
      IOResultCode := IOResult;
      If IOResultCode <> 0 then SaveResult := IOResultCode;
      End;
   End;
Until(Ch = #27) or (SaveResult = 0);

If SaveResult <> 0 then
   begin
   Writeln('Error ',SaveResult,' writing file ',TmpStr);
   end
else
   MacrosChanged := False;

End; { SaveMacros }

END. { QBMFile }
