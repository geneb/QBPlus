{-------------------------------------------------------------------------

                                    PDACFGO  

            Unit to gather other configuration settings for QB Plus

                  Written for Borland Turbo Pascal V 6.0

                     Copyright 1991, by John H. Eckert
                           All Rights Reserved


                                                   ... a component of the
                                                   QuickBasic Programmer
                                                   Desk Accessories ...
-------------------------------------------------------------------------}
{ History:           
01/15/91   0.30   Unit created out of the standalone QBMacro utility and
                  other various programs.
02/10/91   0.70   Unit separated from PDACFGO to increase granularity.
04/08/91   0.85   Real time clock option added
05/15/91   0.93   Preserve original options on user ESC.
06/10/91   0.94   Name change support of PDA to QB Plus.
10/10/91   1.10   Fix <R> toggle (didn't toggle), DirectView to Linear
                  instead of conventional
}
{-------------------------------------------------------------------------}
{$F+}                               { Far calls needed for overlays }
{$O+}                               { Unit may be overlaid          }
UNIT PDACFGO;

{ This unit takes care of gathering input on miscellaneous configuration
   settings.  Called by PDACFG unit main menu when <o> option is chosen.
   Makes calls to PDAEDLN.
 }

{==========================================================================}
{================================= Interface ==============================}
{==========================================================================}
INTERFACE


USES Crt, Dos, pdaSubs, pdartc, PDAEDLN;

PROCEDURE OtherSettings;                  

{==========================================================================}
{============================ Implementation ==============================}
{==========================================================================}

IMPLEMENTATION

{=========================== OtherSettings =================================
 Gathers user input on miscellaneous configuration settings.
 }
PROCEDURE OtherSettings;

Var
Title                         : String13;
Prompt, Dots                  : String70;
i                             : Byte;
On, Off                       : String4;
InBoxes, ThisInBox            : Byte;
TgRow,TgCol                   : Byte;     {Toggle switch name positions }
{ Temporary variables in case user cancels }
tQBSwapName                   : String13;
tRealTime                     : Boolean;
tPortViewEnabled              : Boolean;
tDirectView                   : Boolean;
tswDiskOnly                   : Boolean;
tNoClrScrn                    : Boolean;
tUse_Rtc                      : Boolean;
tCheckSnow                    : Boolean;


Begin
Title := ' Settings ';
Prompt   := ' Tab=Next box  Shift-tab=Prev box  Enter=Accept  Esc=Quit ';
BorderTitlePrompt(Title, Prompt);
Dots := '. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . ';
On := 'On '; Off := 'Off';
TgCol := 4; TgRow := 7;


{ Copy the permanent to the temporaries }
tQBSwapName                   := QBSwapName;
tRealTime                     := RealTime;
tPortViewEnabled              := PortViewEnabled;
tDirectView                   := DirectView;
tswDiskOnly                   := swDiskOnly;
tNoClrScrn                    := NoClrScrn;
tUse_Rtc                      := Use_Rtc;
tCheckSnow                    := CheckSnow;


ClrScr;
InBoxes := 3;                     { 3 input boxes incl. OK        }
ThisInBox := 2;                   { Begin with toggle box         }

{ Draw a backgound for center togglebox }
GotoXY(TgCol, TgRow);
For i := 1 to 9 do
   Begin
   GotoXY(TgCol, WhereY);
   Writeln(Dots);
   End;

Repeat

   { QBSwapname input area setup }
   GotoXY(16,2);
   Write('File name for QB image during swap:');
   GotoXY(54, 2);
   Write(tQBSwapName);
   Box(53, 1, 17, 3);

   { Toggle switch box }
   TgCol := 4; TgRow := 7;                     { Re-init box start }
   Box(TgCol - 1, TgRow - 3, 67, 13);
   GotoXY(TgCol, TgRow - 2);
   Write('Press letter of On/Off switch to change:');
   GotoXY(TgCol, TgRow -1);
   For i := 1 to 65 Do
      Write('Ä');

   GotoXY(TgCol, TgRow); 
   Write('<R>eal time memory display');
   GotoXY(65, TgRow); If tRealTime then Write(On) else Write(Off);
	Inc(TgRow);

   GotoXY(4, TgRow); 
   Write('<P>ort viewing - CAUTION: read manual before enabling');
   GotoXY(65,TgRow); If tPortViewEnabled then Write(On) else Write(Off);
   Inc(TgRow);

   GotoXY(4, TgRow); 
   Write('<X>tended memory direct viewing suppressed');
   GotoXY(65,TgRow); If tDirectView then Write(On) else Write(Off);
   Inc(TgRow);

   GotoXY(4, TgRow); 
   Write('<D>isk-only swaps - no XMS or EMS during program switches');
   GotoXY(65,TgRow); If tswDiskOnly then Write(On) else Write(Off);
   Inc(TgRow);

   GotoXY(4, TgRow); 
   Write('<L>eave QB Plus on screen during program switching');
   GotoXY(65,TgRow); If tNoClrScrn then Write(On) else Write(Off);
   Inc(TgRow);

   GotoXY(TgCol, TgRow);
   If TotalSampleTicks > 0 then
      Write(' Real time clock for profiling (discard samples to change)')
   Else
      Write('<C>ollect profiler samples using installed real time clock');
   GotoXY(65, TgRow); If tUse_Rtc then Write(On) else Write(Off);
   Inc(TgRow);

   GotoXY(4, TgRow);
   Write('<S>now suppression for CGA screens');
   GotoXY(65,TgRow); If tCheckSnow then Write(On) else Write(Off);


   { OK button }
   GotoXY(33, 18);
   Write('< OK >');

   Cursor_on;
   Case ThisInBox of
   1  :  Begin  { QBSwapName box }
         Window(  ULCol + 53, ULRow + 1,
                  ULCol + 53 + SizeOf(tQBSwapName), ULRow + 1);
         GetEditLine(tQBSwapName, SizeOf(tQbSwapName), Ch);
         Window(ULCol, ULRow, LLCol, LLRow);
         End;
   2  :  Begin  { Toggle switch box }
         GotoXY(45, 5);
         Repeat
            Ch := GetUpKey;
         Until Ch in ['R','P','X','L','D','C','S', Tab, Sh_tab, #27, #13];
         cursor_off;
         Case Ch of
            'R'   : tRealTime := Not tRealTime;
            'P'   : tPortViewEnabled := not tPortViewEnabled;
            'X'   : tDirectView := not tDirectView;
            'L'   : tNoClrScrn := not tNoClrScrn;
            'D'   : tswDiskOnly := not tswDiskOnly;
            'S'   : tCheckSnow := not tCheckSnow;
            'C'   : tUse_Rtc := not tUse_Rtc;

            End; { Case }
         End;
   3  :  Begin
         GotoXY(35, 18);
         cursor_on;
         Repeat
            Ch := GetUpKey;
         Until Ch in [Tab, Sh_tab, #27, #13];
         cursor_off;
         End;
   End; {Case }

   If (Ch = Tab) or (Ch = #13) then Inc(ThisInBox);
   If ThisInBox > InBoxes then ThisInBox := 1;
   If Ch = Sh_tab Then Dec(ThisInBox);
   If ThisInBox < 1 then ThisInBox := InBoxes;


Until (Ch = #27) or ((ThisInBox = 1) and (Ch = #13 ));

{ If Enter pressed, then copy the temporaries to permanent }
If Ch = #13 Then
   Begin
   QBSwapName            := tQBSwapName;
   RealTime              := tRealTime;
   PortViewEnabled       := tPortViewEnabled;
   DirectView            := tDirectView;
   { Update memory view mode, if needed }
   If XMThere Then       { Only valid if extended memory }
      Begin
      If DirectView Then
			AddrMode := Conventional
      Else
         AddrMode := Conventional;
      End;
   swDiskOnly            := tswDiskOnly;
   NoClrScrn             := tNoClrScrn;
   CheckSnow             := tCheckSnow;
   { Use_Rtc requires special treatment }
   If Use_Rtc <> tUse_Rtc Then
      Begin
      If TotalSampleTicks = 0 then
         Begin
         If Use_Rtc Then           { If going from use of RTC }
            Begin                  { we need to disable any   }
            If Rtc_PI Then         { periodic interrupts,     }
               Begin               { and the special high     }
               Disable_RTC;        { speed rates in use.      }
               Rtc_PI := False;
               End;
            IF SampleRIndex > 1 then
               Begin
               SampleRIndex := 1;  { set rate to SysTick     }
               SampleRate := SampleRates[SampleRIndex];
               StoredSampleRate := SampleRate;
               End;
            SampleTSource := SysTick;
            End
         Else
            { Set up to use RTC }
            If not Int70Hooked Then
               Begin
               GetIntVec( $70, old_70);
               SetIntVec( $70, our_70);
               Int70Hooked := True;
               End;
         Use_Rtc := not Use_Rtc;
         End;
      End;
   End;

Ch := #0;                              { Stay with parent menu       }
End; { OtherSettings }



END. { PDACFGO Unit }
