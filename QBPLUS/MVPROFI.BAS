'---- QuickBasic Memory Viewer
'---- Copyright 1991 John Eckert

' See the SUB ProfilingInfo

DEFLNG A-Z
SUB ProfilingInfo

' This SUB contains an example profiling session that provides instructions
' for using the Profiler.  This progam is used as the target program to be
' profiled.  With the Desk Accessories, this program and the default QB.LIB
' (or QBX.LIB) quicklibrary loaded into QB, follow the steps outlined below.
'
'
' 1. In QB Plus, go to the profiling menu and enable profiling at the default
'    18 samples per second.  Press "P" such that profile sampling is shown
'    as "-ENABLED-"; press "R" until 18 samples per second appears.  If there
'    are existing samples in the sampling buffer, then press "D" to discard
'    them.  Finally, press "Enter" to accept the setup.  Then leave QB Plus
'    and come back here.


'2.  Next, you will start up the program and browse through memory.  Try a
'    variety of options -- byte, word, etc, and scroll back and forth.
'    Spend about a minute doing this, so you will have plenty of sample data
'    to analyze.  Then press ESC to end the memory viewer program which will
'    return you to this screen once more.  Go ahead.  Run the program now.
'  
'
'3.  Next you will want to analyze the results.  To do that, pop up QB Plus,
'    then select the Profiler.  The Analyze option will now be available and
'    the number of samples taken will be shown.  Note the number.  This is
'    the count of timed interval samples which were taken -- in this case at
'    18.2 times per second. You can then press "A" to view the results.
'  
'    On the first display are the horizontal bar graphs that show the
'    relative percentage the program spent in each routine.  Use the Up and
'    Down arrow keys to look at all the routines.  Those routines with
'    the longest graphs took up the most time, while the routines with the
'    shortest graphs took up the smallest percentage of the program execution
'    time.  Generally, to speed up the execution time of this program, the
'    amount of time consumed by the longest routines will have to be reduced
'    -- either by speeding them up, or by calling them less often.
'  
'    To see whether those routines that took the most time did so because they
'    were called often, press the "C" key.  This display shows the relative
'    percentage the routines were called.  Routines with long bars on both
'    displays will have to have their call frequency reduced.  Routines with
'    long time bars and short call bars will have to be sped up.
'  
'    To get some idea of the time each routine took to execute on average,
'    press the "D" key.  Each routine's call count and average duration in
'    microseconds (millionths of a second) are shown.
'  
'    If you want a written record of the results, press "P" for a printout.
'
'    Go ahead, take a look at the analysis, then come back here.
'
'
'4.  What routines took the most time?  Did this surprise you?  What was the
'    reason for the high time percentages?  Was it because they were called
'    often?  Or because they consumed a high relative amount of time to
'    execute?  Or both?

'    Odds are that one of the longest routines in your sample was the
'    HandleCommand routine.  Why?  If you reasoned that HandleCommand takes
'    a lot of time because it waits for a keypress, you would be correct.

'    Programs that contain routines like HandleCommand which wait for a
'    keypress, or routines that poll a hardware device for an event to
'    occur, can produce misleading profile time percentages.  If, based on
'    the profile results, you were to try and speed up HandleCommand, you
'    might only succeed in polling the keyboard more often, but not producing
'    any visible speed improvement from the standpoint of the program user
'    who judges the program's responsiveness by how quickly it shows the
'    memory data on screen.
'
'
'5.  QB Plus's macro key player allows keystrokes to be automatically fed to
'    the HandleCommand routine, thus eliminating the misleading time delays.
'    This feature is easy to use.  Simply set up the recorder before
'    running the program, and the keys pressed while the program runs will be
'    captured.  Then, with Profiling enabled, re-run the program using QB
'    Plus to replay your keystrokes.  The analysis from the second run will
'    have all the delay from the keyboard input process removed.

'    Let's try a simple one to start.  After you have popped up QB Plus and
'    selected an empty key to record into, you will want to start the program
'    with the key sequence: "F5", "Shift Down", "Shift Release".  F5, of
'    course executes the program.  The Shift sequence is a throwaway
'    keystroke while QB is getting the program up and running.  With it
'    running, press the down arrow 10 times.  Then stop the program with the
'    Esc key, followed by the shift press and release (again, a "throwaway"
'    while QB stops the program), and finally the Enter key.  When you're
'    back in QB, hit your End Recording key combination (Control-Shift or
'    Both -Shifts.)
'
'              To summarize: - Pop up QB Plus
'                            - Macro/Record/[Your Key]
'                            - F5
'                            - tap the shift key
'                            - Down arrow 5 times
'                            - Esc
'                            - tap the shift key
'                            - Enter
'                            - QB Plus End Recording key combination
'
'
'   Now, prepare for profiling.  Pop up QB Plus, make sure profiling is
'   enabled at 18 per second, and be sure to discard all samples now in the
'   sample buffer (press the "D" key.)  Press Enter, then Esc to return here
'   in QB.

'   This time we'll profile from your recorded keystrokes.  Double tap your
'   macro Play key, then the key you recorded your macro into, and let QB Plus
'   run your program.

'   If all goes well, you will find yourself right back here.  Pop up QB Plus
'   Profiler and note how HandleCommand has become a much smaller percentage
'   of the total execution time.
'
'
'6. A single macro key does not have enough capacity for an extensive
'   profile run in this program, given its level of keyboard input.  For
'   such programs, you can load the macro key file ALLJOIN.KQF.  All 36
'   macro keys are linked together beginning with "A", thus allowing up to
'   1440 keystrokes to be recorded as one long sequence.  Once recorded,
'   save the macro with another name, so as to preserve the ALLJOIN file for
'   reuse.


'7. Supplied with this program is the macro file TESTPROF.KQF, which contains
'   a long macro keystroke that exercises most of this program, yielding a
'   nice cross section of the routines.  Pop up QB Plus's Load Macro file
'   feature and load the macro file TESTPROF.  Then set up profiling at 18
'   per second, discarding previous samples.  Return here.  Now invoke macro
'   key "A" to run the profile. It will take a couple of minutes.


'8. Now familiarize youself with the results.  What is time consuming?
'   Where are the heavy calls?  What routines are slow?  Which are fast?
'   Do you have a good idea of where to start in optimizing the program?
'   Print the results if you have a printer.  Otherwise jot down the total
'   execution times, the number of samples, and the call, time and duration
'   values for the longer and time consuming routines.


'9. Before undertaking some optimizing, let's make a comparison of analysis
'   results at different sampling rates.  You will need a PC that has an IBM
'   AT-compatible real-time clock that can be configured to produce a
'   periodic interrupt in order to change rates.  QB Plus uses it automatically.
'   Pop up QB Plus Profiler, discard previous samples, and press "R" until the
'   rate of 1024 appears.  If the rate of 18 does not change when you press
'   "R", then QB Plus was unable to find an appropriate real-time clock, or QB
'   Plus was started with the /NORTC switch, or use of the real time clock was
'   disabled in your QB Plus configuration file.  Try resetting this switch in
'   the Change-Other Settings screen.

'   If you've succesfully set the new rate, leave QB Plus, come back here, and
'   run the program with the macro "A" key like you did before.


'10.Now take a look at the Analysis.  If there are no samples, then the real-
'   time clock interrupts are not working on your PC.  Otherwise, you should
'   see a sample count close to 60 times higher than the last run you did.
'   If you can print, it is useful to print the full report for comparison.
'   If not, compare the results you recorded from last time.  You should note
'   that the time percentages are fairly close, and that the call percentages
'   and counts are identical at both sampling rates.  However, the execution
'   time and the average duration values for each routine are higher in the
'   samples taken at the hgher rate.  This is because sampling imposes its
'   own overhead on the program, thus increasing its elapsed time and those
'   of its routines.  Remember this whenever you compare results at
'   different sample rates.

'   Also, be aware that the average duration values are not based on actual
'   measurement, but statistical timing.  Like any sampling, the fewer the
'   samples, the less precise the results.  Routines called infrequently, or
'   which are particularly short, may exhibit significant variation in
'   duration from one sampling run to another.



END SUB

