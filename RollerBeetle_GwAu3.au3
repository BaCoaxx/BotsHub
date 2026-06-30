; ============================================================================
; Rollerbeetle Bot - GwAu3 Version
; Original by n0futur3, ported to GwAu3 API
; ============================================================================

#RequireAdmin
#include "..\..\API\_GwAu3.au3"

Opt("GUIOnEventMode", 1)
Opt("GUICloseOnESC", False)

; ---- Globale Variablen -------------------------------------------------------
Global $g_bAutoStart = False
Global $g_s_MainCharName = ""
Global $g_b_BotRunning = False
Global $g_b_Initialized = False

Global $g_i_Runs    = 0
Global $g_i_1st     = 0
Global $g_i_2nd     = 0
Global $g_i_3rd     = 0
Global $g_i_4th     = 0
Global $g_i_Medals  = 0

; Stuck-Erkennung
Global $g_f_StuckX1 = 0, $g_f_StuckY1 = 0
Global $g_f_StuckX2 = 0, $g_f_StuckY2 = 0

; ---- Befehlszeilen-Argumente ------------------------------------------------
For $i = 1 To $CmdLine[0]
    If $CmdLine[$i] = "-character" And $i < $CmdLine[0] Then
        $g_s_MainCharName = $CmdLine[$i + 1]
        $g_bAutoStart = True
        ExitLoop
    EndIf
Next

; ---- GUI erstellen ----------------------------------------------------------
$g_hForm = GUICreate("Rollerbeetle Bot (GwAu3)", 310, 270, 252, 164, -1, BitOR($WS_EX_TOPMOST, $WS_EX_WINDOWEDGE))
GUISetBkColor(0xEAEAEA)

GUICtrlCreateLabel("Hi, I'm a rollerbeetle bot.", 0, 12, 310, 20, $SS_CENTER)

; Charakter-Auswahl
$g_cmbCharname = GUICtrlCreateCombo($g_s_MainCharName, 30, 38, 250, 25, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
GUICtrlSetData(-1, Scanner_GetLoggedCharNames())

; Platzierungs-Labels
$g_lblFirst  = GUICtrlCreateLabel("1st: 0",  10,  75, 65, 16)
$g_lblSecond = GUICtrlCreateLabel("2nd: 0",  80,  75, 65, 16)
$g_lblThird  = GUICtrlCreateLabel("3rd: 0", 150,  75, 65, 16)
$g_lblFourth = GUICtrlCreateLabel("4th: 0", 220,  75, 65, 16)

; Statistik-Labels
$g_cbFriendly = GUICtrlCreateCheckbox("Friendly", 10, 100, 80, 20)
$g_lblRuns    = GUICtrlCreateLabel("Runs: 0",          100, 102, 80, 16)
$g_lblMedals  = GUICtrlCreateLabel("Racing Medals: 0", 185, 102, 120, 16)

; Log-Fenster
$g_h_EditText = _GUICtrlRichEdit_Create($g_hForm, "", 8, 128, 294, 100, BitOR($ES_AUTOVSCROLL, $ES_MULTILINE, $WS_VSCROLL, $ES_READONLY))
_GUICtrlRichEdit_SetBkColor($g_h_EditText, $COLOR_WHITE)

; Start/Stop-Button
$g_btnStartStop = GUICtrlCreateButton("Start / Stop", 55, 235, 200, 28)

; Signatur
$g_lblAuthor = GUICtrlCreateLabel("by n0futur3 | ported to GwAu3", 0, 250, 310, 16, $SS_CENTER)
GUICtrlSetColor(-1, $COLOR_RED)

GUISetOnEvent($GUI_EVENT_CLOSE, "_Exit")
GUICtrlSetOnEvent($g_btnStartStop, "_ToggleBot")
GUISetState(@SW_SHOW)

; ---- Auto-Start -------------------------------------------------------------
Core_AutoStart()

; ---- Haupt-Loop -------------------------------------------------------------
While True
    Sleep(100)

    If $g_b_BotRunning Then
        $g_i_Medals = _CountRacingMedals()
        GUICtrlSetData($g_lblMedals, "Racing Medals: " & $g_i_Medals)

        _CheckOutpost()
        _Race()

        $g_i_Runs += 1
        GUICtrlSetData($g_lblRuns, "Runs: " & $g_i_Runs)

        ; Platzierung auswerten
        Local $i_MedalDiff = _CountRacingMedals() - $g_i_Medals
        Switch $i_MedalDiff
            Case 10
                $g_i_1st += 1
                GUICtrlSetData($g_lblFirst,  "1st: " & $g_i_1st)
            Case 7
                $g_i_2nd += 1
                GUICtrlSetData($g_lblSecond, "2nd: " & $g_i_2nd)
            Case 5
                $g_i_3rd += 1
                GUICtrlSetData($g_lblThird,  "3rd: " & $g_i_3rd)
            Case 3
                $g_i_4th += 1
                GUICtrlSetData($g_lblFourth, "4th: " & $g_i_4th)
        EndSwitch
    EndIf
Wend

; =============================================================================
; GUI-Funktionen
; =============================================================================

Func _ToggleBot()
    If Not $g_b_Initialized Then
        Local $s_CharName = GUICtrlRead($g_cmbCharname)
        If Core_Initialize($s_CharName, True) = 0 Then
            MsgBox(16, "Fehler", "Kein Guild Wars Client mit dem Charakter '" & $s_CharName & "' gefunden.")
            Return
        EndIf
        $g_b_Initialized = True
        GUICtrlSetState($g_cmbCharname, $GUI_DISABLE)
        _Out("Initialisierung erfolgreich: " & $s_CharName)
    EndIf

    $g_b_BotRunning = Not $g_b_BotRunning
    If $g_b_BotRunning Then
        GUICtrlSetData($g_btnStartStop, "Stop (läuft...)")
        _Out("Bot gestartet.")
    Else
        GUICtrlSetData($g_btnStartStop, "Start")
        _Out("Bot gestoppt.")
    EndIf
EndFunc

Func _Exit()
    Exit
EndFunc

; =============================================================================
; Bot-Logik
; =============================================================================

; --- Stuck-Prüfung (per AdlibRegister aufgerufen) ---
Func _Stuck()
    $g_f_StuckX1 = $g_f_StuckX2
    $g_f_StuckY1 = $g_f_StuckY2
    $g_f_StuckX2 = Agent_GetAgentInfo(-2, "X")
    $g_f_StuckY2 = Agent_GetAgentInfo(-2, "Y")

    If $g_f_StuckX1 = $g_f_StuckX2 And $g_f_StuckY1 = $g_f_StuckY2 Then
        ; Links ausweichen
        Core_ControlAction($GC_I_CONTROL_MOVEMENT_STRAFE_LEFT, $GC_I_CONTROL_TYPE_ACTIVATE)
        Sleep(200)
        Core_ControlAction($GC_I_CONTROL_MOVEMENT_STRAFE_LEFT, $GC_I_CONTROL_TYPE_DEACTIVATE)

        $g_f_StuckX2 = Agent_GetAgentInfo(-2, "X")
        $g_f_StuckY2 = Agent_GetAgentInfo(-2, "Y")

        If $g_f_StuckX1 = $g_f_StuckX2 And $g_f_StuckY1 = $g_f_StuckY2 Then
            ; Rechts ausweichen
            Core_ControlAction($GC_I_CONTROL_MOVEMENT_STRAFE_RIGHT, $GC_I_CONTROL_TYPE_ACTIVATE)
            Sleep(200)
            Core_ControlAction($GC_I_CONTROL_MOVEMENT_STRAFE_RIGHT, $GC_I_CONTROL_TYPE_DEACTIVATE)
        EndIf
    EndIf
EndFunc

; --- Racing Medals zählen ---
Func _CountRacingMedals()
    Local $i_Total = 0
    For $i_Bag = 1 To 4
        Local $i_Slots = Item_GetBagInfo($i_Bag, "Slots")
        For $j = 1 To $i_Slots
            Local $p_Item = Item_GetItemBySlot($i_Bag, $j)
            If $p_Item = 0 Then ContinueLoop
            If Item_GetItemInfoByPtr($p_Item, "ModelID") = 37793 Then
                $i_Total += Item_GetItemInfoByPtr($p_Item, "Quantity")
            EndIf
        Next
    Next
    Return $i_Total
EndFunc

; --- Outpost prüfen / Challenge betreten ---
Func _CheckOutpost()
    ; Map-ID 467 = Rollerbeetle Racing outpost
    If Map_GetMapID() <> 467 Then
        Map_TravelTo(467)
    EndIf

    ; Startbereich prüfen (Wartezone vor dem Rennen)
    If Agent_GetDistanceToXY(-6416, -6901) < 600 Then
        ; Warten bis Abklingzeit (Skill 2546 = Racing-Cooldown) vorbei
        While Agent_GetAgentEffectInfo(-2, 2546, "TimeRemaining") > 0
            Sleep(2000)
        Wend

        Map_EnterChallenge(False)

        ; Warten bis einer der Startpunkte erreicht ist
        Do
            Sleep(2000)
        Until ( _
            Agent_GetDistanceToXY(-6367, -4438) < 600 Or _
            Agent_GetDistanceToXY(-6625, -4435) < 600 Or _
            Agent_GetDistanceToXY(-6151, -4489) < 600 Or _
            Agent_GetDistanceToXY(-5936, -4485) < 600 Or _
            Agent_GetDistanceToXY(-5720, -4483) < 600 Or _
            Agent_GetDistanceToXY(-5495, -4436) < 600 _
        ) And Agent_GetAgentPtr(-2) <> 0
    EndIf
EndFunc

; --- Skill-Nutzung (Adlib, alle 2 Sek.) ---
Func _RunningBasic()
    If BitAND(GUICtrlRead($g_cbFriendly), $GUI_CHECKED) = $GUI_CHECKED Then
        ; Friendly-Modus: nur Skills 1-2
        Local $i_Rnd = Random(1, 2, 1)
        If Skill_GetSkillbarInfo($i_Rnd, "Recharge") = 0 Then
            Skill_UseSkill($i_Rnd, 0)
        EndIf
    Else
        ; Normal: Skills 1-3
        Local $i_Rnd = Random(1, 3, 1)
        If Skill_GetSkillbarInfo($i_Rnd, "Recharge") = 0 Then
            Skill_UseSkill($i_Rnd, 0)
        EndIf
    EndIf
EndFunc

; --- Spezial-Skills (Adlib, alle 4 Sek.) ---
Func _RunningSpecial()
    If BitAND(GUICtrlRead($g_cbFriendly), $GUI_CHECKED) = $GUI_CHECKED Then
        ; Friendly: Skills 6 und 8 auf sich selbst
        For $i = 4 To 8
            If $i = 6 Or $i = 8 Then
                If Skill_GetSkillbarInfo($i, "Recharge") = 0 Then
                    Skill_UseSkill($i, 0)
                EndIf
            EndIf
        Next
    Else
        ; Feindlich: Skills 4, 5, 7 auf Gegner; 6, 8 auf sich selbst
        For $i = 4 To 8
            If $i = 4 Or $i = 5 Or $i = 7 Then
                If Skill_GetSkillbarInfo($i, "Recharge") = 0 Then
                    Agent_TargetNearestEnemy()
                    Skill_UseSkill($i, Agent_GetCurrentTarget())
                EndIf
            Else
                If Skill_GetSkillbarInfo($i, "Recharge") = 0 Then
                    Skill_UseSkill($i, 0)
                EndIf
            EndIf
        Next
    EndIf
EndFunc

; --- Rennen fahren ---
Func _Race()
    ; Zum ersten Wegpunkt bewegen (mit Stuck-Check)
    AdlibRegister("_Stuck", 3000)
    Do
        Map_Move(-5752, -2587)
    Until Agent_GetDistanceToXY(-5752, -2587) < 600

    ; Skill-Adlibs starten
    AdlibRegister("_RunningBasic",   2000)
    AdlibRegister("_RunningSpecial", 4000)

    ; Streckenpunkte abfahren
    Map_Move(-5328,  -1669)
    Map_Move(-4702,   -856)
    Map_Move(-4003,   -125)
    Map_Move(-3911,    880)
    Map_Move(-4766,   1430)
    Map_Move(-4965,   2412)
    Map_Move(-5059,   3432)
    Map_Move(-5070,   4449)
    Map_Move(-4843,   5431)
    Map_Move(-4358,   6317)
    Map_Move(-3761,   7139)
    Map_Move(-3403,   8091)
    Map_Move(-3070,   9039)
    Map_Move(-2695,   9988)
    Map_Move(-1940,  10645)
    Map_Move(-1034,  11095)
    Map_Move(-1661,  11875)
    Map_Move(-1095,  12713)
    Map_Move( -287,  13360)
    Map_Move(  576,  13871)
    Map_Move( 1510,  14243)
    Map_Move( 2316,  13640)
    Map_Move( 2871,  12786)
    Map_Move( 3377,  11913)
    Map_Move( 3300,  10908)
    Map_Move( 3405,   9892)
    Map_Move( 3758,   8943)
    Map_Move( 4095,   7998)
    Map_Move( 3978,   7000)
    Map_Move( 2977,   6761)
    Map_Move( 2032,   6395)
    Map_Move( 1172,   5868)
    Map_Move(  434,   5167)
    Map_Move( -257,   4398)
    Map_Move( -797,   3553)
    Map_Move(-1173,   2609)
    Map_Move( -973,   1611)
    Map_Move( -158,   1019)
    Map_Move(  683,    404)
    Map_Move( 1525,   -138)
    Map_Move( 2532,   -121)
    Map_Move( 3510,   -372)
    Map_Move( 4481,   -652)
    Map_Move( 5476,   -866)
    Map_Move( 6454,  -1092)
    Map_Move( 7396,  -1438)
    Map_Move( 6809,  -2257)
    Map_Move( 5997,  -2849)
    Map_Move( 5695,  -3826)
    Map_Move( 5908,  -4812)
    Map_Move( 6808,  -5263)
    Map_Move( 7812,  -5304)
    Map_Move( 7559,  -4336)
    Map_Move( 8566,  -4335)
    Map_Move( 9371,  -4933)
    Map_Move( 9097,  -5897)
    Map_Move( 8860,  -6890)
    Map_Move( 8686,  -7891)
    Map_Move( 8487,  -8899)
    Map_Move( 8378,  -9936)
    Map_Move( 7450, -10348)
    Map_Move( 6477, -10053)
    Map_Move( 5667,  -9461)
    Map_Move( 4851,  -8830)
    Map_Move( 4181,  -8057)
    Map_Move( 3310,  -7557)
    Map_Move( 2355,  -7252)
    Map_Move( 1461,  -6791)
    Map_Move(  531,  -6353)
    Map_Move( -249,  -5703)
    Map_Move(-1248,  -4503)

    ; Adlibs stoppen
    AdlibUnRegister("_RunningBasic")
    AdlibUnRegister("_RunningSpecial")
    AdlibUnRegister("_Stuck")

    ; Auf Map-Wechsel warten
    Map_WaitMapIsLoaded()
    Sleep(5000)
EndFunc

; =============================================================================
; Hilfsfunktionen
; =============================================================================

Func _Out($s_Text)
    Local $i_TextLen    = StringLen($s_Text)
    Local $i_ConsoleLen = _GUICtrlEdit_GetTextLen($g_h_EditText)
    If $i_TextLen + $i_ConsoleLen > 30000 Then
        GUICtrlSetData($g_h_EditText, StringRight(_GUICtrlEdit_GetText($g_h_EditText), 30000 - $i_TextLen - 1000))
    EndIf
    _GUICtrlRichEdit_SetCharColor($g_h_EditText, $COLOR_BLACK)
    _GUICtrlEdit_AppendText($g_h_EditText, @CRLF & $s_Text)
    _GUICtrlEdit_Scroll($g_h_EditText, 1)
EndFunc
