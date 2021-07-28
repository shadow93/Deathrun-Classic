# Deathrun-Classic
### A continuation of ClassicGuzzi's Deathrun Redux plugin

### Main features:
- Global configuration file (data/deathrun/deathrun/cfg) or map-specific configuration (data/deathrun/maps/<mapname>.cfg)
- Configurable speeds for the activator (Death) and the runners!
- Uses TF2 notification hud announcements, alongside chat announcements for events.
- Melee-only mode can be enabled
- Fall damage can be disabled (no TF2Attributes dependency!)
- Enable outlines on runners / death based on living runners globally
- Sounds! "RoundStart", "OnDeath", "OnKill", "LastAlive", "OnLastManDeath"
- Players won't be able to push others
- Death cannot be selected twice, unless everyone was death at least once.
- !drtoggle to toggle between wanting to be death, skip being death globally, or skip being death for a specific map
- Option to prevent death from suiciding
- Added translation file for multi-language support
- Auto-detects deathrun maps!

### Dependencies:
- TF2Items (for weapon restrictions)
- SteamTools (for game name change in server browser)
	
### Installation:
- deathrun_redux.smx > tf/addons/sourcemod/plugins
- deathrun.cfg > tf/addons/sourcemod/data/deathrun
- <map name>.cfg > tf/addons/sourcemod/data/deathrun/maps/

## Global configuration
```
"deathrun"
{
	//Configs used if the map doesn't have it's own value.
	"default"
	{
		"DisableFallDamage" "1"	//If 1 there won't be fall damage.
		"BlockDeathSuicide"	"1"	//This prevents death from suiciding
		
		//Speed of every team (for reference, pyro's base speed is 300).
		"speed"
		{
			"runners"	"300.0"	//On the runners team
			"death"		"400.0"	//On the death
		}
		
		//How many players on the "runners" team must be alive to activate the outline (-1 = never|0 = always|>0 alive runners needed).
		"outline"	
		{
			"runners"	"0"		//On the runners team
			"death"		"-1"	//On the death
		}
	
	}
		
	//Sounds used in this game-mode, the plugin will pre-cache them and add them to the download table.
	//The plugin will use all of them randomly.
	"sounds"
	{
		//When the round starts (NOT when the preparation period ends).
		"RoundStart"		
		{
			"1"		"vo/announcer_dec_missionbegins10s01.mp3"
			"2"		"vo/announcer_begins_10sec.mp3"
			"3"		"vo/mvm_mann_up_mode05.mp3"
			"4"		"vo/mvm_mann_up_mode01.mp3"
		}
		//Played to a runner that just died.
		"OnDeath"	
		{
			"1"		"vo/announcer_dec_failure01.mp3"
			"2"		"vo/announcer_dec_failure02.mp3"
			"3"		"vo/announcer_am_lastmanforfeit01.mp3"
			"4"		"vo/announcer_am_lastmanforfeit02.mp3"
			"5"		"vo/announcer_am_lastmanforfeit03.mp3"
			"6"		"vo/announcer_am_lastmanforfeit04.mp3"
			"7"		"vo/mvm_mann_up_mode04.mp3"
		}
		//Played to the death after a kill (You should use many different sounds since he will be hearing this a lot).
		"OnKill"
		{
			"delay"	"5.0" //Time after a kill that the plugin won't reproduce any "OnKill" sound.
			"1"		"vo/announcer_dec_kill01.mp3"
			"2"		"vo/announcer_dec_kill02.mp3"
			"3"		"vo/announcer_dec_kill03.mp3"
			"4"		"vo/announcer_dec_kill04.mp3"
			"5"		"vo/announcer_dec_kill05.mp3"
			"6"		"vo/announcer_dec_kill06.mp3"
			"7"		"vo/announcer_dec_kill07.mp3"
			"8"		"vo/announcer_dec_kill08.mp3"
			"9"		"vo/announcer_dec_kill09.mp3"
			"10"	"vo/announcer_dec_kill10.mp3"
			"11"	"vo/announcer_dec_kill11.mp3"
			"12"	"vo/announcer_dec_kill12.mp3"
			"13"	"vo/announcer_dec_kill13.mp3"
			"14"	"vo/announcer_dec_kill14.mp3"
			"15"	"vo/announcer_dec_kill15.mp3"
		}
		//Played to the last client alive on the runners team.
		"LastAlive"
		{
			"1"		"vo/announcer_am_lastmanalive01.mp3"
			"2"		"vo/announcer_am_lastmanalive02.mp3"
			"3"		"vo/announcer_am_lastmanalive03.mp3"
			"4"		"vo/announcer_am_lastmanalive04.mp3"
		}
		// When the last runner dies
		"OnLastManDeath"
		{
			"1"		"vo/mvm_all_dead01.mp3"
			"2"		"vo/mvm_all_dead02.mp3"
			"3"		"vo/mvm_all_dead03.mp3"
			"4"		"vo/compmode/cm_admin_misc_01.mp3"
			"5"		"vo/compmode/cm_admin_misc_02.mp3"
			"6"		"vo/compmode/cm_admin_misc_07.mp3"
			"7"		"vo/compmode/cm_admin_misc_09.mp3"
			"8"		"vo/announcer_do_not_fail_again.mp3"
			"9"		"vo/announcer_do_not_fail_again.mp3"
			"10"	"vo/announcer_you_failed.mp3"
			"11"	"vo/announcer_you_must_not_fail_again.mp3"
		}		
	}
	
	//Here we manage the weapon restriction (mostly melee-related)
	"weapons"
	{
		//If true (1) will restrict every other slot than melee. If False (0) the plugin wont use the rest of this config section.
		"MeleeOnly"			"1"		
		//If true (1) will follow the "MeleeRestriction"'s rules. 
		"RestrictedMelee"	"1"		
		//Here we define the melee restriction rules.
		"MeleeRestriction"
		{
			"RestrictAll"	"0"	//If 1 "RestrictedWeapons" will be ignored
			"RestrictedWeapons"
			{
				"1"	"589"	//The Eureka Effect (teleportation)
				"2"	"450"	//The Atomizer	(extra jump)
				"3"	"307"	//Ullapool Caber (explosive jump)
				"4"	"325"	//The Boston Basher (bloody jump)
				"5"	"452"	//Three-Rune Blade (bloody jump)
				"6"	"304"	//Amputator (Lags everybody)
				"7" "264"	//Frying Pan (Noise Spam)
				"8"	"1071"	//Golden Frying Pan (Noise Spam)
			}
			
			"UseDefault"	"1"	//Use the default melee for every class
			"UseAllClass"	"1"	//Use the AllClassWeapons
			//If both UseDefault and UseAllClass are on, the default weapon will be treated like another weapon in the list.
			//If both are off the plugin will just use Default Weapons for each class
			"AllClassWeapons"
			{
				"2"	"423"	//Saxxy
				"3"	"474"	//The Conscientious Objector
				"4"	"880"	//The Freedom Staff
				"5"	"939"	//The Bat Outta Hell
				"6"	"954"	//The Memory Maker
				"7"	"1013"	//The Ham Shank
				"8"	"1123"	//The Necro Smasher
				"9"	"1127"	//The Crossing Guard
			}
		}
	}
	
	//Here we define commands to block
	"blockcommands"
	{
		//You must respect the order of this numbers
		"1"
		{
			//command to block
			"command"	"build"		
			//If 1 it will only block the command on the preparation time.
			"OnlyOnPreparation"	"0"	
			//If 1 it will block the command for runners.
			"runners"	"1"		
			//If 1 it will block the command for the death.			
			"death"		"1"			
		}
	}
}
```

## Map-Specific Config
```
"drmap"
{
	"DisableFallDamage" "1"	//If 1 there won't be fall damage.
	
	//Speed of every team (for example, pyro's base speed is 300).
	"speed"
	{
		"runners"	"300.0"	//On the runners team
		"death"		"400.0"	//On the death
	}
	
	//How many players on the "runners" team must be alive to activate the outline (-1 = never|0 = always|>0 alive runners needed).
	"outline"	
	{
		"runners"	"0"		//On the runners team
		"death"		"-1"	//On the death
	}
}
```
