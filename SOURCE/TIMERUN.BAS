'--- TIMERUN.BAS
'--- External companion program to Quickbasic Programmer's Desk Accessories
'
' Pauses for a key press (to permit invocation of a key macro from QB Plus, if
' desired), then shells to the program passed in the command line argument.
' On return from the child program, prints the elapsed time of the child
' process on screen.
'
' This program is useful for measuring the execution time of an executable
' version of a Quickbasic program via the QB Plus Switch Program feature to
' complement the QB Plus built-in profiler.

' Copyright 1991, by John H. Eckert.  All rights reserved.


DEFINT A-Z

'Identify ourselves
PRINT
PRINT "Quickbasic Programmer's Desk Accessories --  Program Timer"
PRINT "Copyright 1991, by John H. Eckert.  All rights reserved."
PRINT


'Make sure we are being sent something to do, quit if not
IF COMMAND$ = "" THEN
   PRINT "No program specified.  Provide a program name on the command line."
   END
ELSE
   'Preserve the name
   ProgramName$ = COMMAND$
   PRINT "Timing "; ProgramName$
END IF


'Prompt and wait for a key press -- this gives them chance to call a macro,
'or back out
PRINT "Press a key when ready to start, or ESC to cancel . . .";
A$ = INPUT$(1)

'Remember where the cursor is now
CursorRow = CSRLIN

'See if we got a cancellation and if so quit; or
'tell them we're going on
LOCATE CursorRow, 1
PRINT SPACE$(80);
LOCATE CursorRow, 1
IF A$ = CHR$(27) THEN
   PRINT "Timing canceled"
   END
ELSE
   PRINT "Timing started...";
END IF

'Set up error handler for SHELL to cover any
'dos or basic errors not reported by comand.com
ON ERROR GOTO CouldNotRunIt

'Get the starting tick count
'We won't use TIMER. That avoids floating point.
'We only  need the lowest three tick bytes
DEF SEG = &H40
StartTicks& = PEEK(&H6C) + PEEK(&H6D) * 256 + PEEK(&H6E) * 65536

'Here we go
SHELL ProgramName$

'Get the ending tick count
StopTicks& = PEEK(&H6C) + PEEK(&H6D) * 256 + PEEK(&H6E) * 65536

'Adjust for midnight
IF StopTicks& < StartTicks& THEN          'Add a day's ticks
   StopTicks& = StopTicks& + 1572480      '(That's 86400 secs * 18.2)
END IF

'Give 'em the score
LOCATE CursorRow, 1
PRINT SPACE$(80);
LOCATE CursorRow, 1
PRINT "Elapsed time = "; CLNG(StopTicks& - StartTicks&); "timer ticks."
END

CouldNotRunIt:
LOCATE CursorRow, 1
PRINT SPACE$(80);
LOCATE CursorRow, 1
PRINT "Error "; ERR; "in shelling to "; ProgramName$
END

