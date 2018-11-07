{-------------------------------------------------------------------------

                                  QBPBUILD

              Stand alone program to build an executable file

                  Written for Borland Turbo Pascal V 6.0

                     Copyright 1991, by John H. Eckert
                           All Rights Reserved


                                                   ... a component of the
                                                   QB Plus Desk Accessories
-------------------------------------------------------------------------}
PROGRAM qbpBuild;

{ This is the companion program to the built-in "BUILD .EXE" feature of the
QuickBasic Programmer Desk Accessories that does the compile/link operation
when called by QB Plus. QB Plus expects this to be in the current directory,
along the dos path, or in the directory containing QB Plus.

This program loads the file passed on the command line, then based on the
contents, calls BC and LINK to compile and link according to the data in the
file.  The file includes the arguments to BC to compile each module; and link
switches, object file, map, exe and library file names needed by LINK.

The special character "$" with BC or LINK data denotes the associated BC or
LINK operation is to be performed incrementally; that is, only where the
source file is later than the target executable file.  This can save a lot
of time in the Edit-Compile-Link-Test-Edit cycle.

It should be noted, however, that this is not as sophisticated as some MAKE
utilities in that exe-object date comparisons are not made, thus leaving the
possibility open for out of date object files in the resulting executable.
This could happen if, after the executable has been made, a component source
file is simply recompiled without being changed. The last recompilation
settings in such a case will not get into the final .exe if the LINK $ option
is present. Remove all $ options to force full compilation and linking when
changes to source files have not been made.

BC and LINK must be in the current directory, unless the file contains their
full path specifications.
}

{--------------------------------------------------------------------------
Copyright 1989-91 by John H. Eckert  All rights reserved.

History:
12/06/90    1.6   Part of single funtion QBBC.EXE program.
01/11/91    1.8   Extracted the compile portions of QBBC.EXE and placed them
                  into this stand alone companion program to the Programmer
                  Desk Accessories written for Turbo Pascal. This program
                  contains no product specific code and should compile in
                  Turbo Pascal Version 4.0 and later, and also in QuickPascal.
04/15/91    1.9   Implement path search for BC and LINK.
05/06/91    1.91  Show extensions for BC and LINK on output screen, but strip
                  them out of source file, so if user put the extensions in
                  the file, we'll compile/link successfully anyway.
06/10/91    1.92  Name change from PDABUILD to QBPBUILD.
06/24/91    1.93  Check for null commmand line file argument and exit.
10/25/91    1.94  Fix error causing "'" (skip line) option to fail, also
						build of non-mqk files and remove message saying we're
						going to build anyway.

----------------------------------------------------------------------------}

{$M 2500, 0, 0 }                 { Leave balance of 640K for Link & BC     }        

USES
    Dos, Crt;

TYPE
   String80 = String[80];        { Length of a bc/link option line         }


CONST
    { Reserve space for the bc/link option data from the .MQK file }
    TextLines  = 40;
    TextLine         : ARRAY [ 1..TextLines ] of String80 =
				('QuickBasic EXE Building Utility, Version 1.94 25-Oct-91',
            'Copyright 1989-91, by John H. Eckert  All rights reserved.',
            '','','','','','',
            '','','','',
            '','','','','','','','',
            '','','','','','','','',
            '','','','','','','','',
            '','','','');


VAR
   MainModDir                    : DirStr;           { Components of main  }
   MainModName                   : NameStr;          {  module path, name  }
   MainModExt                    : ExtStr;           {  and extension.     }
   OptFile                       : Text;             { Used in Assign.     }
   tempstr                       : String80;         { For shuffling strs. }
   BCPathStr, LinkPathStr        : PathStr;          { Alternate paths     }
   FoundName                     : SearchRec;        { FSearch results     }
   BC, LINK                      : Byte;             { Variables used to   }
   BCLine, LinkOK, LINKLine      : Boolean;          { parse the options   }
   CompileIt, LinkNotNeeded      : Boolean;          { file data.          }
   ExeFTime, SourceFTime         : LongInt;          {Incremental link date}
   IOResultCode                  : Byte;             { Dos I/O call results}
   ExitSave                      : Pointer;        { for old ExitProc      }
   DErrCode, DXCode              : Byte;             {for DosError, DOsExit}
   Parm                          : PathStr;          { Concat'ed Cmd line  }
   i,j                           : Byte;             { Generic counters    }

{ Procedure to tidy things up before leaving. We come here at the end of the
program, or whenever a run time error is encountered. }
{$F+} PROCEDURE ExitProgram;{$F-}
   BEGIN
   DErrCode := DosError;                  { Store any error info  }
   DXCode   := DosExitCode;

   ExitProc := exitsave;                  { Restore exit vector   }

   Writeln;
   IF DErrCode + DxCode = 0 then
      Write('Build Utility terminated normally.')
   else
      begin
      write('Build Utility exit code: ',DxCode,', Dos error code: ',DErrCode);
      Case DErrCode of
         2: writeln(' Program not found.');
         8: writeln(' Insufficient memory.')
      else Writeln;
      End; { case }
      End;
   End; {Exit Program}


{                 ----====<<<< MAIN ROUTINE >>>>====----                }
BEGIN
{Set up ExitProc routine }
ExitSave := ExitProc;                           { Preserve prior value  }
ExitProc := @ExitProgram;                       { Register routine      }

{ Initialize our command argument work area }
Parm := '';

{ Tell them who we are }
Writeln;
Writeln(TextLine[1]);
Writeln(TextLine[2]);

{ Combine command line options into a single string.
This is in case a space, treated as a delimiter by
Turbo Pascal, got embedded somehow. }
FOR I := 1 TO ParamCount DO
   Parm := Parm + ParamStr(I);

{ Convert to all uppercase. }
FOR I := 1 TO Length( Parm ) DO
      Parm[ I ] := UpCase( Parm[I] );


{ We have to have a filename on the command line, else quit. }
If Length(Parm) = 0 Then
   Begin
   Writeln('Cannot continue -- no compile/link filename specified.');
   Delay(3000);
   Halt(1);
   End;


{ Look for location of BC, in case not in .MQK }
tempstr := FExpand('BC.EXE');
{Look in current directory}
FindFirst(tempstr, Archive, FoundName);
If DosError = 0 Then
   BCPathStr := tempstr
Else
   BCPathStr := FSearch('BC.EXE', GetEnv('PATH'));



{ Look for location of LINK, in case not in .MQK }
tempstr := FExpand('LINK.EXE');
{Look in current directory}
FindFirst(tempstr, Archive, FoundName);
If DosError = 0 Then
   LinkPathStr := tempstr
Else
   LinkPathStr := FSearch('LINK.EXE', GetEnv('PATH'));


{ Get the components of the filespec}
FSplit(Parm, MainModDir, MainModName, MainModExt);
If MainModExt <> '.MQK' Then
   Writeln('File does not have an ".MQK" extension.');

{ Get .MQK data ... }
Assign(OptFile, MainModDir + MainModName + MainModExt);
{$I-} Reset(OptFile); {$I+}   {Suspend error trap during reset }
IF IOResult <> 0 then
   Writeln('Could not open file ',Parm)
Else
   BEGIN
   I := 0;
   While not EOF(OptFile) do
      begin
      Inc(I);
      Readln(OptFile, TextLine[I]);
      End;
   Close(OptFile);  { done getting .MQK }

      { Get time of Exe file, if it exists.  Assumes the target .EXE file
      is in the same directory and has same base name as this .MQK file. }
      Assign(OptFile, MainModDir + MainModName + '.EXE');
      {$I-} Reset(OptFile); {$I+}   {Suspend error trap during reset }
      IF IOResult = 0 then
         BEGIN
         GetFTime(OptFile, ExeFTime);
         Close(OptFile);
         END
      ELSE
         { Date stamp non-existent .EXE
         with "beginning of time" }
         ExeFTime := 0;

      { Make sure all the lines are left-justified }
      For I := 1 to TextLines Do
         While (Pos(' ', TextLine[I]) = 1) do Delete(TextLine[I], 1, 1);

      { OK, here goes.  Tear apart the data and send it to BC and LINK.  We
      do that one line at a time for BC.  For LINK, we build a response file.}
      LinkOK := True;                  { Assume BC success                 }
      LinkNotNeeded := True;           { Assume incremental link, for now.
                                         If we compile anything, we set to
                                         False so the new .obj gets linked. }


      For I := 1 to TextLines Do
         Begin
         BCLine :=  False;             { Assume not a BC line     }
         LINKLine :=  False;           { Assume not a LINK line   }

         { Skip over empty lines, and lines beginning with the ' char }
         IF (TextLine[I] <> '') and (TextLine[i,1] <> #39) Then   
            Begin                      { Convert to all uppercase }
            For J := 1 to Length(TextLine[I]) Do
               TextLine[I,J] := UpCase(TextLine[I,J]);

            { Delete any .EXE from any BC.EXE }
            BC := Pos('BC.EXE', TextLine[I]);
            If BC > 0 Then
               Delete(TextLine[I], BC+2, 4);

            { Point at "BC", if it is there. }
            BC := Pos('BC ', TextLine[I]);

            If BC > 0 Then             { need BC in line to go on }
               Begin
               BCLine := True;
               IF BCLine Then
                  Begin                 { Got BC line, so compile }

                  { See if we need to execute the BC operation -- the source
                  may not have changed since last time the .exe was built. }
                  CompileIt :=  True;   { Assume we'll compile, for now }
                  If TextLine[I,1] = '$' Then  { Test if source later than exe   }
                     Begin
                     If ExeFTime > 0  Then     { exe must exist to bother w/this }
                        Begin

                        { make copy of BC argument containing source filename }
                        TempStr := Copy(TextLine[I], BC+3, Length(TextLine[I]) - (BC + 3));
                        { drop the switch settings and semi-colon }
                        J := Pos('/', TempStr);
                        Delete(TempStr, J, Length(TempStr)-(J-1));

                        { Get the source file date }
                        IF Length(TempStr) > 0 Then
                           Begin

                           { Use current directory if full path not specified. FExpand
                           returns the full filespec (Drive:\path\name) based
                           on current drive and directory for the specified
                           filename. }
                           Assign(OptFile, FExpand(TempStr));

                           {$I-} Reset(OptFile); {$I+}   {Suspend error trap during reset }
                           IF IOResult = 0 then
                              BEGIN
                              GetFTime(OptFile, SourceFTime);
                              Close(OptFile);

                              { Compare it to the .exe date stamp }
                              IF ExeFTime > SourceFTime then
                                 Begin
                                 { The .exe is newer than the source, so
                                 we'll assume the latest version of the
                                 source was incorporated in it. We'll set
                                 the flag to skip this compilation. }
                                 CompileIt := False;
                                 End; { Comparing dates }

                              END; { Successful source date read }
                           End;  {Attempting source date read }
                        End; { Comparing source if exe exists }
                     End; {If $ in effect }

                  If CompileIt then
                     Begin { Compiling }

                     { Since we are going to compile, we are
                     going to have to link, so clear flag that would
                     have allowed us to skip linking in event all
                     source compilation was up to date. }
                     LinkNotNeeded := False;

                     { Point at the BC part of line, skipping over any "$". }
                     j := 0; If TextLine[I,1] = '$' Then j := 1;

                     { Show them what we are doing; ie, BC and the arguments. }
                     Writeln;
                     Writeln(Copy(TextLine[I], 1+j, BC+1-j) + '.EXE',
                          Copy(TextLine[I], BC+2, Length(TextLine[I]) - (BC+1)));

                     { Here goes. Launch BC. }
                     SwapVectors;
                     Exec(Copy(TextLine[I], 1+j, BC+1-j) + '.EXE',
                          Copy(TextLine[I], BC+2, Length(TextLine[I]) - (BC+1)));
                     { .MQK's BC not found, use path from startup, if avail.} 
                     If (DosError = 2) and (BCPathStr <> '') Then
                           Exec(BCPathStr,
                           Copy(TextLine[I], BC+2, Length(TextLine[I]) - (BC+1)));
                     SwapVectors;

                     { If BC failed, there is no point  in linking. }
                     IF (DosError + DosExitCode) > 0 then LinkOK := False;

                     { Let them know how things came out }
                     Writeln('Dos error code: ',DosError,', BC exit code: ',DosExitCode);
                     End;
                  End; { Compiling line }
               End  { line containing BC }

            Else    { check for a link line }
            { We come here if the line was not identified as a BCLine. }
            IF LinkOK Then  { but only if BC's were all successful }
               Begin

               { Delete any .EXE from any LINK.EXE }
               LINK := Pos('LINK.EXE', TextLine[I]);
               If LINK > 0 Then
                  Delete(TextLine[I], LINK+4, 4);

               { Find the word "LINK" }
               LINK := Pos('LINK ', TextLine[I]);
               If LINK= 0 THEN LINK := Pos('LINK/', TextLine[I]);

               If LINK > 0 Then             { need LINK in line to go on   }
                  Begin
                  LINKLine := True;

                  { We skip the link step if both the $ link option is
                  specified, and no source files were compiled. }
                  If ((TextLine[I, 1] = '$')) and LinkNotNeeded then
                     Begin
                     LINKline := False;    { This causes link to be skipped}
                     { Tell 'em we're done already. }
                     Writeln;
                     Writeln('All files up to date, rebuilding not needed.');
                     End;

                  IF LINKLine Then
                     Begin                 { Got LINK line, so link  }
                     { Write response file from remaining lines }
                     { "Rewrite" overwrites any existing file of this name. }
                     Assign(OptFile, '~QBLINK.TMP');
                     {$I-} Rewrite(OptFile); {$I+}   {Suspend error trap during reset }
                     IF IOResult <> 0 then
                        Writeln('Could not write response file. Link canceled, code ',
                        IOResult)
                        Else
                        BEGIN
                        { We'll make the response file verbatim from the
                        non-empty lines following the LINK line. }
                        For J := I + 1 to TextLines Do
                           begin
                           IF TextLine[J] <> '' then
                              Writeln(OptFile, TextLine[J]);
                           End;
                        Close(OptFile);

                        { Point at LINK }
                        j :=0; If TextLine[I,1] = '$' Then j := 1;

                        { Tell them what's coming down. }
                        Writeln;
                        Write(Copy(TextLine[I], 1+j, LINK+3-j) + '.EXE',
                             Copy(TextLine[I], LINK+4, Length(TextLine[I]) - (LINK+3)) +
                             ' @~QBLINK.TMP;');

                        { Launch LINK, with response file as argument. }
                        SwapVectors;
                        Exec(Copy(TextLine[I], 1+j, LINK+3-j) + '.EXE',
                             Copy(TextLine[I], LINK+4, Length(TextLine[I]) - (LINK+3)) +
                             ' @~QBLINK.TMP;');
                        If (DosError = 2) and (LinkPathStr <> '') Then
                           { Try alternate path if .MQK's no good }
                           Exec(LinkPathStr,
                             Copy(TextLine[I], LINK+4, Length(TextLine[I]) - (LINK+3)) +
                             ' @~QBLINK.TMP;');
                        SwapVectors;

                        { Tell 'em how it came out }
                        Writeln('Dos error code: ',DosError,', Link exit code: ',DosExitCode);

                        { Wipe out response file. }
                        Erase(OptFile);

                        END;  { writing response file, linking and erasing }
                     End;  { Linking }
                  End;  { line containing LINK }
               End;  { Link OK }
            End;  { Checking non-blank lines }
         End;  { Looping through each line }
      End;  { Compile/Linking }

ExitProgram;

END.
