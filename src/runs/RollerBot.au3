#CS ===========================================================================
; Rollerbeetle Racing farm for BotsHub
; Based on RollerBeetle.au3 (by n0futur3, DeeperBlue) and
; RollerBeetle_GwAu3.au3 (GwAu3 port)
; Farms Racing Medals by repeatedly running the Rollerbeetle Racing challenge.
#CE ===========================================================================

#include-once
#RequireAdmin
#NoTrayIcon

#include '../../lib/GWA2.au3'
#include '../../lib/GWA2_ID.au3'
#include '../../lib/Utils.au3'

Opt('MustDeclareVars', True)

; ==== Constants ====
Global Const $ROLLERBEETLE_FARM_INFORMATIONS = 'Rollerbeetle Racing farm - earns Racing Medals by completing the challenge loop.' & @CRLF _
	& 'Solo - no party required.' & @CRLF _
	& 'The bot navigates the full race track, uses beetle skills, and tallies medals per run.'
; Average duration ~5 minutes per race (start to outpost return)
Global Const $ROLLERBEETLE_FARM_DURATION = 5 * 60 * 1000

; Rollerbeetle Racing skill slots (fixed by the game for all racers)
Global Const $ROLLERBEETLE_SKILL_BASIC_1   = 1
Global Const $ROLLERBEETLE_SKILL_BASIC_2   = 2
Global Const $ROLLERBEETLE_SKILL_BASIC_3   = 3
Global Const $ROLLERBEETLE_SKILL_HOSTILE_1 = 4
Global Const $ROLLERBEETLE_SKILL_HOSTILE_2 = 5
Global Const $ROLLERBEETLE_SKILL_SELF_1    = 6
Global Const $ROLLERBEETLE_SKILL_HOSTILE_3 = 7
Global Const $ROLLERBEETLE_SKILL_SELF_2    = 8

; Racing Medal model ID
Global Const $ROLLERBEETLE_MODEL_ID_RACING_MEDAL = 37793

; Skill effect ID that represents the post-race cooldown (prevents re-entry)
Global Const $ROLLERBEETLE_RACING_COOLDOWN_SKILL_ID = 2546

; Waypoint arrival tolerance (in game units)
Global Const $ROLLERBEETLE_WAYPOINT_RANGE = 600

; Maximum time to wait for the cooldown to expire before aborting (ms)
Global Const $ROLLERBEETLE_COOLDOWN_TIMEOUT = 120000

; Maximum time to wait for race start position after entering challenge (ms)
Global Const $ROLLERBEETLE_ENTER_TIMEOUT = 30000

Global $rollerbeetle_farm_setup = False


; ==== Main farm function ====

;~ Entry point registered in the BotsHub farm map.
Func RollerBeetleFarm()
	If Not $rollerbeetle_farm_setup And SetupRollerBeetleFarm() == $FAIL Then Return $PAUSE

	TravelToOutpost($ID_ROLLERBEETLE_RACING, $district_name)
	Local $medalsBefore = RollerBeetleCountMedals()

	If RollerBeetleEnterRace() == $FAIL Then Return $FAIL

	Local $result = RollerBeetleRunRace()

	Local $medalsGained = RollerBeetleCountMedals() - $medalsBefore
	If $medalsGained > 0 Then Info('Racing medals gained this run: ' & $medalsGained)

	Return $result
EndFunc


;~ First-run setup: travel to outpost, leave any party, mark as done.
Func SetupRollerBeetleFarm()
	Info('Setting up Rollerbeetle Racing farm')
	TravelToOutpost($ID_ROLLERBEETLE_RACING, $district_name)
	LeaveParty()
	$rollerbeetle_farm_setup = True
	Info('Rollerbeetle Racing setup complete')
	Return $SUCCESS
EndFunc


; ==== Race entry ====

;~ Travel to the outpost, wait for the post-race cooldown, enter the challenge,
;~ and wait until the player is placed at a start lane.
Func RollerBeetleEnterRace()
	TravelToOutpost($ID_ROLLERBEETLE_RACING, $district_name)

	Local $cooldownTimer = TimerInit()
	While GetEffectTimeRemaining($ROLLERBEETLE_RACING_COOLDOWN_SKILL_ID) > 0
		Info('Waiting for racing cooldown to expire')
		RandomSleep(2000)
		If TimerDiff($cooldownTimer) > $ROLLERBEETLE_COOLDOWN_TIMEOUT Then
			Warn('Racing cooldown wait timed out')
			Return $FAIL
		EndIf
	Wend

	Info('Entering Rollerbeetle Racing challenge')
	EnterChallenge()

	Local $enterTimer = TimerInit()
	While Not RollerBeetleIsAtStartPosition()
		RandomSleep(2000)
		If TimerDiff($enterTimer) > $ROLLERBEETLE_ENTER_TIMEOUT Then
			Warn('Did not reach a race start position in time')
			Return $FAIL
		EndIf
	Wend

	Return $SUCCESS
EndFunc


;~ Returns True if the player is within range of any known race start lane.
Func RollerBeetleIsAtStartPosition()
	Local $me = GetMyAgent()
	Local Static $startX[] = [-6367, -6625, -6151, -5936, -5720, -5495]
	Local Static $startY[] = [-4438, -4435, -4489, -4485, -4483, -4436]
	Local $laneIndex
	For $laneIndex = 0 To UBound($startX) - 1
		If GetDistanceToPoint($me, $startX[$laneIndex], $startY[$laneIndex]) < $ROLLERBEETLE_WAYPOINT_RANGE Then Return True
	Next
	Return False
EndFunc


; ==== Medal counting ====

;~ Returns the total quantity of Racing Medals in the player's inventory.
Func RollerBeetleCountMedals()
	Local $item = GetItemByModelID($ROLLERBEETLE_MODEL_ID_RACING_MEDAL)
	If $item == Null Then Return 0
	Return DllStructGetData($item, 'Quantity')
EndFunc


; ==== Adlib skill handlers ====

;~ Called every 3 s via AdlibRegister during the race.
;~ Uses one of the basic movement/speed skills (slots 1-3) if recharged.
Func RollerBeetleRunBasic()
	Local $slot = Random($ROLLERBEETLE_SKILL_BASIC_1, $ROLLERBEETLE_SKILL_BASIC_3, 1)
	If IsRecharged($slot) Then UseSkill($slot)
EndFunc


;~ Called every 5 s via AdlibRegister during the race.
;~ Uses offensive skills on the nearest opponent and utility skills on self.
Func RollerBeetleRunSpecial()
	If IsRecharged($ROLLERBEETLE_SKILL_SELF_1) Then UseSkill($ROLLERBEETLE_SKILL_SELF_1)
	If IsRecharged($ROLLERBEETLE_SKILL_SELF_2) Then UseSkill($ROLLERBEETLE_SKILL_SELF_2)

	Local $target = GetNearestEnemyToAgent(GetMyAgent())
	If $target == Null Then Return
	If IsRecharged($ROLLERBEETLE_SKILL_HOSTILE_1) Then UseSkill($ROLLERBEETLE_SKILL_HOSTILE_1, $target)
	If IsRecharged($ROLLERBEETLE_SKILL_HOSTILE_2) Then UseSkill($ROLLERBEETLE_SKILL_HOSTILE_2, $target)
	If IsRecharged($ROLLERBEETLE_SKILL_HOSTILE_3) Then UseSkill($ROLLERBEETLE_SKILL_HOSTILE_3, $target)
EndFunc


; ==== Race navigation ====

;~ Navigate the full Rollerbeetle Racing loop.
;~ Waypoints are sourced from RollerBeetle_GwAu3.au3 and RollerBeetle.au3.
;~ Skills are fired asynchronously via AdlibRegister throughout the run.
Func RollerBeetleRunRace()
	If GetMapID() <> $ID_ROLLERBEETLE_RACING Then Return $FAIL

	; Move to the first corner before activating skill adlibs so the
	; bot is already rolling when skill timers begin.
	Info('Racing - moving to initial position')
	MoveTo(-5752, -2587, $ROLLERBEETLE_WAYPOINT_RANGE)

	AdlibRegister('RollerBeetleRunBasic',   3000)
	AdlibRegister('RollerBeetleRunSpecial', 5000)

	Info('Racing - navigating track')
	RollerBeetleNavigateTrack()

	AdlibUnRegister('RollerBeetleRunBasic')
	AdlibUnRegister('RollerBeetleRunSpecial')

	WaitMapLoading($ID_ROLLERBEETLE_RACING, 10000, 5000)
	Return $SUCCESS
EndFunc


;~ Step through every race waypoint.  MoveTo exits early when the map changes
;~ (race ends) so all remaining steps complete immediately without side effects.
Func RollerBeetleNavigateTrack()
	Local $r = $ROLLERBEETLE_WAYPOINT_RANGE

	MoveTo(-5328,  -1669, $r)
	MoveTo(-4702,   -856, $r)
	MoveTo(-4003,   -125, $r)
	MoveTo(-3911,    880, $r)
	MoveTo(-4766,   1430, $r)
	MoveTo(-4965,   2412, $r)
	MoveTo(-5059,   3432, $r)
	MoveTo(-5070,   4449, $r)
	MoveTo(-4843,   5431, $r)
	MoveTo(-4358,   6317, $r)
	MoveTo(-3761,   7139, $r)
	MoveTo(-3403,   8091, $r)
	MoveTo(-3070,   9039, $r)
	MoveTo(-2695,   9988, $r)
	MoveTo(-1940,  10645, $r)
	MoveTo(-1034,  11095, $r)
	MoveTo(-1661,  11875, $r)
	MoveTo(-1095,  12713, $r)
	MoveTo( -287,  13360, $r)
	MoveTo(  576,  13871, $r)
	MoveTo( 1510,  14243, $r)
	MoveTo( 2316,  13640, $r)
	MoveTo( 2871,  12786, $r)
	MoveTo( 3377,  11913, $r)
	MoveTo( 3300,  10908, $r)
	MoveTo( 3405,   9892, $r)
	MoveTo( 3758,   8943, $r)
	MoveTo( 4095,   7998, $r)
	MoveTo( 3978,   7000, $r)
	MoveTo( 2977,   6761, $r)
	MoveTo( 2032,   6395, $r)
	MoveTo( 1172,   5868, $r)
	MoveTo(  434,   5167, $r)
	MoveTo( -257,   4398, $r)
	MoveTo( -797,   3553, $r)
	MoveTo(-1173,   2609, $r)
	MoveTo( -973,   1611, $r)
	MoveTo( -158,   1019, $r)
	MoveTo(  683,    404, $r)
	MoveTo( 1525,   -138, $r)
	MoveTo( 2532,   -121, $r)
	MoveTo( 3510,   -372, $r)
	MoveTo( 4481,   -652, $r)
	MoveTo( 5476,   -866, $r)
	MoveTo( 6454,  -1092, $r)
	MoveTo( 7396,  -1438, $r)
	MoveTo( 6809,  -2257, $r)
	MoveTo( 5997,  -2849, $r)
	MoveTo( 5695,  -3826, $r)
	MoveTo( 5908,  -4812, $r)
	MoveTo( 6808,  -5263, $r)
	MoveTo( 7812,  -5304, $r)
	MoveTo( 7559,  -4336, $r)
	MoveTo( 8566,  -4335, $r)
	MoveTo( 9371,  -4933, $r)
	MoveTo( 9097,  -5897, $r)
	MoveTo( 8860,  -6890, $r)
	MoveTo( 8686,  -7891, $r)
	MoveTo( 8487,  -8899, $r)
	MoveTo( 8378,  -9936, $r)
	MoveTo( 7450, -10348, $r)
	MoveTo( 6477, -10053, $r)
	MoveTo( 5667,  -9461, $r)
	MoveTo( 4851,  -8830, $r)
	MoveTo( 4181,  -8057, $r)
	MoveTo( 3310,  -7557, $r)
	MoveTo( 2355,  -7252, $r)
	MoveTo( 1461,  -6791, $r)
	MoveTo(  531,  -6353, $r)
	MoveTo( -249,  -5703, $r)
	MoveTo(-1248,  -4503, $r)
EndFunc