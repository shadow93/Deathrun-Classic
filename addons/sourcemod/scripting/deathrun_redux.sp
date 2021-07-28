// ---- Preprocessor -----------------------------------------------------------
#pragma semicolon 1 

// ---- Includes ---------------------------------------------------------------
#include <sourcemod>
#include <morecolors>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2items>
#include <steamtools>
#include <clientprefs>

#pragma newdecls required

// ---- Defines ----------------------------------------------------------------
#define DR_VERSION "0.3.1"
#define PLAYERCOND_SPYCLOAK (1<<4)
#define MAXGENERIC 25	//Used as a limit in the config file

#define RUNNERS 2
#define DEATH 3

#define DBD_UNDEF -1 //DBD = Don't Be Death
#define DBD_OFF 1
#define DBD_ON 2
#define DBD_THISMAP 3 // The cookie will never have this value
#define TIME_TO_ASK 30.0 //Delay between asking the client its preferences and it's connection/join.

#define INACTIVE 100000000.0

// ---- Variables --------------------------------------------------------------

// map-specific
bool isValidDrMap = false;

// for the command listener
bool commandHooked = false;
bool multicommandHooked = false;

// player-specific
bool blockDeathSuicide = true;
int g_timesplayed_asdeath[MAXPLAYERS+1];
int previousDeath = -1;

int gCheckStuckPlayers = 1;
float StuckCheckTimeout[MAXPLAYERS+1]=INACTIVE;
float gStuckCheckTimeout=5.0;

bool OnStartCountdown = false;
int g_dontBeDeath[MAXPLAYERS+1] = {DBD_UNDEF,...};
bool g_canEmitSoundToDeath = true;

//GenerealConfig
bool blockFallDamage;
float runnerSpeed;
float deathSpeed;
int g_runner_outline;
int g_death_outline;

//Weapon-config
bool g_MeleeOnly;
bool g_MeleeRestricted;
bool g_RestrictAll;
Handle g_RestrictedWeps;
bool g_UseDefault;
bool g_UseAllClass;
Handle g_AllClassWeps;

//Command-config
Handle g_CmdList;
Handle g_CmdTeamToBlock;
Handle g_CmdBlockOnlyOnPrep;

//Sound-config
Handle g_SndRoundStart;
Handle g_SndOnDeath;
Handle g_SndOnLastManDeath;
float  g_OnKillDelay;
Handle g_SndOnKill;
Handle g_SndLastAlive;


// ---- Handles ----------------------------------------------------------------
Handle g_DRCookie = INVALID_HANDLE;

// ---- Server's CVars Management ----------------------------------------------
Handle dr_queue;
Handle dr_unbalance;
Handle dr_autobalance;
Handle dr_firstblood;
Handle dr_scrambleauto;
Handle dr_airdash;
Handle dr_push;

int dr_queue_def = 0;
int dr_unbalance_def = 0;
int dr_autobalance_def = 0;
int dr_firstblood_def = 0;
int dr_scrambleauto_def = 0;
int dr_airdash_def = 0;
int dr_push_def = 0;

// ---- Plugin's Information ---------------------------------------------------
public Plugin myinfo =
{
	name = "[TF2] Deathrun Classic",
	author = "93SHADoW, Classic",
	description	= "A deathrun plugin for TF2",
	version = DR_VERSION,
	url = "http://www.clangs.com.ar"
};


/* OnPluginStart()
**
** When the plugin is loaded.
** -------------------------------------------------------------------------- */
public void OnPluginStart()
{
	//Cvars
	CreateConVar("sm_dr_version", DR_VERSION, "Death Run Redux Version.", FCVAR_REPLICATED | FCVAR_SPONLY | FCVAR_DONTRECORD | FCVAR_NOTIFY);
	//Creation of Tries
	g_RestrictedWeps = CreateTrie();
	g_AllClassWeps = CreateTrie();
	g_CmdList = CreateTrie();
	g_CmdTeamToBlock = CreateTrie();
	g_CmdBlockOnlyOnPrep = CreateTrie();
	g_SndRoundStart = CreateTrie();
	g_SndOnDeath = CreateTrie();
	g_SndOnKill = CreateTrie();
	g_SndLastAlive = CreateTrie();
	g_SndOnLastManDeath = CreateTrie();
	
	//Server's Cvars
	dr_queue = FindConVar("tf_arena_use_queue");
	dr_unbalance = FindConVar("mp_teams_unbalance_limit");
	dr_autobalance = FindConVar("mp_autoteambalance");
	dr_firstblood = FindConVar("tf_arena_first_blood");
	dr_scrambleauto = FindConVar("mp_scrambleteams_auto");
	dr_airdash = FindConVar("tf_scout_air_dash_count");
	dr_push = FindConVar("tf_avoidteammates_pushaway");

	//Hooks
	HookEvent("teamplay_round_start", OnPrepartionStart);
	HookEvent("arena_round_start", OnRoundStart); 
	HookEvent("post_inventory_application", OnPlayerInventory);
	HookEvent("player_spawn", OnPlayerSpawn);
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
	
	//Preferences
	g_DRCookie = RegClientCookie("DR_dontBeDeath", "Does the client want to be the Death?", CookieAccess_Private);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!AreClientCookiesCached(i))
			continue;
		OnClientCookiesCached(i);
	}
	RegConsoleCmd( "drtoggle",  BeDeathMenu);
	
	//Translations
	LoadTranslations("deathrun_redux.phrases");
	
	//Block administrator's end of round sounds
	HookEvent("teamplay_broadcast_audio", OnBroadcast, EventHookMode_Pre);
	
	//End of round events
	HookEvent("arena_win_panel", OnWinPanel, EventHookMode_Pre);
}

/* OnPluginEnd()
**
** When the plugin is unloaded. Here we reset all the cvars to their normal value.
** -------------------------------------------------------------------------- */
public void OnPluginEnd()
{
	ResetCvars();
}


/* OnMapStart()
**
** Here we reset every global variable, and we check if the current map is a deathrun map.
** If it is a dr map, we get the cvars def. values and the we set up our own values.
** -------------------------------------------------------------------------- */
public void OnMapStart()
{
	previousDeath = -1;
	for(int i = 1; i <= MaxClients; i++)
			g_timesplayed_asdeath[i]=-1;
			
	char mapname[128];
	GetCurrentMap(mapname, sizeof(mapname));
	if (strncmp(mapname, "dr_", 3, false) == 0 || strncmp(mapname, "deathrun_", 9, false) == 0 || strncmp(mapname, "vsh_dr_", 6, false) == 0 || strncmp(mapname, "vsh_deathrun_", 6, false) == 0)
	{
		LogMessage("Deathrun map detected. Enabling Deathrun Gamemode.");
		isValidDrMap = true;
		Steam_SetGameDescription("DeathRun Redux");
		AddServerTag("deathrun");
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!AreClientCookiesCached(i))
				continue;
			OnClientCookiesCached(i);
		}
		LoadConfigs();
		PrecacheFiles();
		ProcessListeners();
	}
 	else
	{
		LogMessage("Current map is not a deathrun map. Disabling Deathrun Gamemode.");
		isValidDrMap = false;
		Steam_SetGameDescription("Team Fortress");	
		RemoveServerTag("deathrun");
	}
}

/* OnMapEnd()
**
** Here we reset the server's cvars to their default values.
** -------------------------------------------------------------------------- */
public void OnMapEnd()
{
	ResetCvars();
	for (int i = 1; i <= MaxClients; i++)
	{
		g_dontBeDeath[i] = DBD_UNDEF;
	}
}

/* LoadConfigs()
**
** Here we parse the data/deathrun/deathrun.cfg
** -------------------------------------------------------------------------- */
void LoadConfigs()
{
	//--DEFAULT VALUES--
	//GenerealConfig
	blockFallDamage = false;
	runnerSpeed = 300.0;
	deathSpeed = 400.0;
	g_runner_outline = 0;
	g_death_outline = -1;

	//Weapon-config
	g_MeleeOnly = true;
	g_MeleeRestricted = true;
	g_RestrictAll = true;
	ClearTrie(g_RestrictedWeps);
	g_UseDefault = true;
	g_UseAllClass = false;
	ClearTrie(g_AllClassWeps);

	//Command-config
	ClearTrie(g_CmdList);
	ClearTrie(g_CmdTeamToBlock);
	ClearTrie(g_CmdBlockOnlyOnPrep);

	//Sound-config
	ClearTrie(g_SndRoundStart);
	ClearTrie(g_SndOnDeath);
	g_OnKillDelay = 5.0;
	ClearTrie(g_SndOnKill);
	ClearTrie(g_SndLastAlive);
	
	char mainfile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, mainfile, sizeof(mainfile), "data/deathrun/deathrun.cfg");
	
	if(!FileExists(mainfile))
	{
		SetFailState("Configuration file %s not found!", mainfile);
		return;
	}
	Handle hDR = CreateKeyValues("deathrun");
	if(!FileToKeyValues(hDR, mainfile))
	{
		SetFailState("Improper structure for configuration file %s!", mainfile);
		return;
	}
	if(KvJumpToKey(hDR,"default"))
	{
		blockFallDamage = view_as<bool>(KvGetNum(hDR, "DisableFallDamage", view_as<int>(blockFallDamage)));
		blockDeathSuicide = view_as<bool>(KvGetNum(hDR, "BlockDeathSuicide", view_as<int>(blockDeathSuicide)));
		
		gCheckStuckPlayers = KvGetNum(hDR, "HandleStuckPlayers", gCheckStuckPlayers);
		if(gCheckStuckPlayers)
		{
			gStuckCheckTimeout = KvGetFloat(hDR, "StuckPlayerTimeout", gStuckCheckTimeout);
		}
		
		if(KvJumpToKey(hDR,"speed"))
		{
			runnerSpeed = KvGetFloat(hDR,"runners",runnerSpeed);
			deathSpeed = KvGetFloat(hDR,"death",deathSpeed);
			KvGoBack(hDR);
		}
		
		if(KvJumpToKey(hDR,"outline"))
		{
			g_runner_outline = KvGetNum(hDR,"runners",g_runner_outline);
			g_death_outline = KvGetNum(hDR,"death",g_death_outline);
			KvGoBack(hDR);
		}
		KvGoBack(hDR);
	}
	
	
	KvRewind(hDR);
	if(KvJumpToKey(hDR,"weapons"))
	{
	
		g_MeleeOnly = view_as<bool>(KvGetNum(hDR, "MeleeOnly", view_as<int>(g_MeleeOnly)));
		if(g_MeleeOnly)
		{
			g_MeleeRestricted = view_as<bool>(KvGetNum(hDR, "RestrictedMelee",view_as<int>(g_MeleeRestricted)));
			if(g_MeleeRestricted)
			{
				KvJumpToKey(hDR,"MeleeRestriction");
				g_RestrictAll = view_as<bool>(KvGetNum(hDR, "RestrictAll", view_as<int>(g_RestrictAll)));
				if(!g_RestrictAll)
				{
					KvJumpToKey(hDR,"RestrictedWeapons");
					char key[4];
					int auxInt;
					for(int i=1; i<MAXGENERIC; i++)
					{
						IntToString(i, key, sizeof(key));
						auxInt = KvGetNum(hDR, key, -1);
						if(auxInt == -1)
						{
							break;
						}
						SetTrieValue(g_RestrictedWeps,key,auxInt);
					}
					KvGoBack(hDR);
				}
				g_UseDefault = view_as<bool>(KvGetNum(hDR, "UseDefault", view_as<int>(g_UseDefault)));
				g_UseAllClass = view_as<bool>(KvGetNum(hDR, "UseAllClass", view_as<int>(g_UseAllClass)));
				if(g_UseAllClass)
				{
					KvJumpToKey(hDR,"AllClassWeapons");
					char key[4];
					int auxInt;
					for(int i=1; i<MAXGENERIC; i++)
					{
						IntToString(i, key, sizeof(key));
						auxInt = KvGetNum(hDR, key, -1);
						if(auxInt == -1)
						{
							break;
						}
						SetTrieValue(g_AllClassWeps,key,auxInt);
					}
					KvGoBack(hDR);
				}
				KvGoBack(hDR);
			}
			
		}
	}
	
	KvRewind(hDR);
	KvJumpToKey(hDR,"blockcommands");
	do
	{
		char SectionName[128], CommandName[128];
		int onprep;
		bool onrunners, ondeath;
		int teamToBlock;
		KvGotoFirstSubKey(hDR);
		KvGetSectionName(hDR, SectionName, sizeof(SectionName));
		
		KvGetString(hDR, "command", CommandName, sizeof(CommandName));
		onprep = KvGetNum(hDR, "OnlyOnPreparation", 0);
		onrunners = !!KvGetNum(hDR,"runners",1);
		ondeath = !!KvGetNum(hDR,"death",1);
		
		teamToBlock = 0;
		if((onrunners && ondeath))
			teamToBlock = 1;
		else if(onrunners && !ondeath)
			teamToBlock = RUNNERS;
		else if(!onrunners && ondeath)
			teamToBlock = DEATH;
		
		if(!StrEqual(CommandName, "") || teamToBlock == 0)
		{
			SetTrieString(g_CmdList,SectionName,CommandName);
			SetTrieValue(g_CmdBlockOnlyOnPrep,CommandName,onprep);
			SetTrieValue(g_CmdTeamToBlock,CommandName,teamToBlock);
		}
	}
	while(KvGotoNextKey(hDR));
	
	KvRewind(hDR);
	if(KvJumpToKey(hDR,"sounds"))
	{
		char key[4], sndFile[PLATFORM_MAX_PATH];
		if(KvJumpToKey(hDR,"RoundStart"))
		{
			for(int i=1; i<MAXGENERIC; i++)
			{
				IntToString(i, key, sizeof(key));
				KvGetString(hDR, key, sndFile, sizeof(sndFile),"");
				if(StrEqual(sndFile, ""))
					break;			
				SetTrieString(g_SndRoundStart,key,sndFile);
			}
			KvGoBack(hDR);
		}
		
		if(KvJumpToKey(hDR,"OnDeath"))
		{
			for(int i=1; i<MAXGENERIC; i++)
			{
				IntToString(i, key, sizeof(key));
				KvGetString(hDR, key, sndFile, sizeof(sndFile),"");
				if(StrEqual(sndFile, ""))
					break;			
				SetTrieString(g_SndOnDeath,key,sndFile);
			}
			KvGoBack(hDR);
		}
		
		if(KvJumpToKey(hDR,"OnLastManDeath"))
		{
			for(int i=1; i<MAXGENERIC; i++)
			{
				IntToString(i, key, sizeof(key));
				KvGetString(hDR, key, sndFile, sizeof(sndFile),"");
				if(StrEqual(sndFile, ""))
					break;			
				SetTrieString(g_SndOnLastManDeath,key,sndFile);
			}
			KvGoBack(hDR);
		}
		
		if(KvJumpToKey(hDR,"OnKill"))
		{
			
			g_OnKillDelay = KvGetFloat(hDR,"delay",g_OnKillDelay);
			for(int i=1; i<MAXGENERIC; i++)
			{
				IntToString(i, key, sizeof(key));
				KvGetString(hDR, key, sndFile, sizeof(sndFile),"");
				if(StrEqual(sndFile, ""))
					break;			
				SetTrieString(g_SndOnKill,key,sndFile);
			}
			KvGoBack(hDR);
		}
		
		if(KvJumpToKey(hDR,"LastAlive"))
		{
			for(int i=1; i<MAXGENERIC; i++)
			{
				IntToString(i, key, sizeof(key));
				KvGetString(hDR, key, sndFile, sizeof(sndFile),"");
				if(StrEqual(sndFile, ""))
					break;			
				SetTrieString(g_SndLastAlive,key,sndFile);
			}
			KvGoBack(hDR);
		}
		KvGoBack(hDR);
	}
	
	KvRewind(hDR);
	CloseHandle(hDR);
	
	char mapfile[PLATFORM_MAX_PATH], mapname[128];
	GetCurrentMap(mapname, sizeof(mapname));
	BuildPath(Path_SM, mapfile, sizeof(mapfile), "data/deathrun/maps/%s.cfg",mapname);
	if(FileExists(mapfile))
	{
		hDR = CreateKeyValues("drmap");
		if(!FileToKeyValues(hDR, mapfile))
		{
			SetFailState("Improper structure for configuration file %s!", mapfile);
			return;
		}
		blockFallDamage = view_as<bool>(KvGetNum(hDR, "DisableFallDamage", view_as<int>(blockFallDamage)));

		if(KvJumpToKey(hDR,"speed"))
		{
			runnerSpeed = KvGetFloat(hDR,"runners",runnerSpeed);
			deathSpeed = KvGetFloat(hDR,"death",deathSpeed);
			
			KvGoBack(hDR);
		}
		if(KvJumpToKey(hDR,"outline"))
		{
			g_runner_outline = KvGetNum(hDR,"runners",g_runner_outline);
			g_death_outline = KvGetNum(hDR,"death",g_death_outline);
		}
		KvRewind(hDR);
		CloseHandle(hDR);
	}

}

/* PrecacheFiles()
**
** We precache and add to the download table every sound file found on the config file.
** -------------------------------------------------------------------------- */
void PrecacheFiles()
{
	PrecacheSoundFromTrie(g_SndRoundStart);
	PrecacheSoundFromTrie(g_SndOnDeath);
	PrecacheSoundFromTrie(g_SndOnLastManDeath);
	PrecacheSoundFromTrie(g_SndOnKill);
	PrecacheSoundFromTrie(g_SndLastAlive);
}

/* PrecacheFiles()
**
** We precache and add to the download table, reading every value of a Trie.
** -------------------------------------------------------------------------- */
void PrecacheSoundFromTrie(Handle sndTrie)
{
	int trieSize = GetTrieSize(sndTrie);
	char soundString[PLATFORM_MAX_PATH], downloadString[PLATFORM_MAX_PATH], key[4];
	for(int i = 1; i <= trieSize; i++)
	{
		IntToString(i,key,sizeof(key));
		if(GetTrieString(sndTrie,key,soundString, sizeof(soundString)))
		{
			if(PrecacheSound(soundString))
			{
				Format(downloadString, sizeof(downloadString), "sound/%s", soundString);
				AddFileToDownloadsTable(downloadString);
			}
		}
	}
}


/* ProcessListeners()
**
** Here we add the listeners to block the commands defined on the config file.
** -------------------------------------------------------------------------- */
void ProcessListeners(bool removeListeners=false)
{
	int trieSize = GetTrieSize(g_CmdList);
	char command[PLATFORM_MAX_PATH], key[4];
	for(int i = 1; i <= trieSize; i++)
	{
		IntToString(i,key,sizeof(key));
		if(GetTrieString(g_CmdList,key,command, sizeof(command)))
		{
			if(StrEqual(command, ""))
					break;		
					
			if(removeListeners && multicommandHooked)
			{
				RemoveCommandListener(Command_Block,command);
				multicommandHooked=false;
			}
			else 
			{
				AddCommandListener(Command_Block,command);
				multicommandHooked=true;
			}	
		}
	}
	// fix for death suiciding
	if(blockDeathSuicide)
	{
		if(removeListeners && commandHooked)
		{
			CheckSuicideCommand(Command_Block, false);
			commandHooked=false;
		}
		else
		{
			CheckSuicideCommand(Command_Block, true);
			commandHooked=true;
		}
	}
}

stock void CheckSuicideCommand(CommandListener callback, bool load)
{
	if(load)
	{
		AddCommandListener(callback, "kill");
		AddCommandListener(callback, "explode");
		AddCommandListener(callback, "spectate");
		AddCommandListener(callback, "jointeam");
		AddCommandListener(callback, "joinclass");
	}
	else
	{
		RemoveCommandListener(callback, "kill");
		RemoveCommandListener(callback, "explode");
		RemoveCommandListener(callback, "spectate");
		RemoveCommandListener(callback, "jointeam");
		RemoveCommandListener(callback, "joinclass");
	}	
}

// needed to block activator suicide
public bool IsSuicide(int client, const char[] command)
{
	return (IsValidClient(client, true) && GetClientTeam(client)==DEATH && (StrEqual(command, "kill", false) || StrEqual(command, "explode", false) || StrEqual(command, "spectate", false) || StrEqual(command, "jointeam", false) || (StrEqual(command, "joinclass", false) && !OnStartCountdown)));
}


/* OnClientPutInServer()
**
** We set on zero the time played as death when the client enters the server.
** -------------------------------------------------------------------------- */
public void OnClientPutInServer(int client)
{
	g_timesplayed_asdeath[client] = 0;
}

/* OnClientDisconnect()
**
** We set as minus one the time played as death when the client leaves.
** When searching for a Death we ignore every client with the -1 value.
** We also set as undef the preference value
** -------------------------------------------------------------------------- */
public void OnClientDisconnect(int client)
{
	g_timesplayed_asdeath[client] =-1;
	g_dontBeDeath[client] = DBD_UNDEF;
}

/* OnClientCookiesCached()
**
** We look if the client have a saved value
** -------------------------------------------------------------------------- */
public void OnClientCookiesCached(int client)
{
	char sValue[8];
	GetClientCookie(client, g_DRCookie, sValue, sizeof(sValue));
	int nValue = StringToInt(sValue);

	if( nValue != DBD_OFF && nValue != DBD_ON) //If cookie is not valid we ask for a preference.
		CreateTimer(TIME_TO_ASK, AskMenuTimer, client);
	else //client has a valid cookie
		g_dontBeDeath[client] = nValue;
}

public Action AskMenuTimer(Handle timer, any client)
{
	BeDeathMenu(client,0);
}

public Action BeDeathMenu(int client,int args)
{
	if (client == 0 || (!IsClientInGame(client)))
	{
		return Plugin_Handled;
	}
	Handle menu = CreateMenu(BeDeathMenuHandler);
	SetMenuTitle(menu, "Be the Death toggle");
	AddMenuItem(menu, "0", "Select me as Death");
	AddMenuItem(menu, "1", "Don't select me as Death");
	AddMenuItem(menu, "2", "Don't be Death in this map");
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 30);
	
	return Plugin_Handled;
}

public int BeDeathMenuHandler(Handle menu, MenuAction action, int client, int buttonnum)
{
	if (action == MenuAction_Select)
	{
		if (buttonnum == 0)
		{
			g_dontBeDeath[client] = DBD_OFF;
			char sPref[2];
			IntToString(DBD_OFF, sPref, sizeof(sPref));
			SetClientCookie(client, g_DRCookie, sPref);
			CPrintToChat(client,"{black}[DR]{green} %t", "Death Enabled");
			ShowGameText(client, "ico_notify_flag_moving_alt", _, "%t", "Death Enabled");
		}
		else if (buttonnum == 1)
		{
			g_dontBeDeath[client] = DBD_ON;
			char sPref[2];
			IntToString(DBD_ON, sPref, sizeof(sPref));
			SetClientCookie(client, g_DRCookie, sPref);
			CPrintToChat(client,"{black}[DR]{red} %t", "Death Disabled");
			ShowGameText(client, "ico_notify_flag_moving_alt", _, "%t", "Death Disabled");
		}
		else if (buttonnum == 2)
		{
			g_dontBeDeath[client] = DBD_THISMAP;
			CPrintToChat(client,"{black}[DR]{yellow} %t", "Death Disabled For Map");
			ShowGameText(client, "ico_notify_flag_moving_alt", _, "%t", "Death Disabled For Map");
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

/* OnPrepartionStart()
**
** We setup the cvars again, balance the teams and we freeze the players.
** -------------------------------------------------------------------------- */
public Action OnPrepartionStart(Handle event, const char[] name, bool dontBroadcast)
{
	if(isValidDrMap)
	{
		OnStartCountdown = true;
		
		//We force the cvars values needed every round (to override if any cvar was changed).
		SetupCvars();
		
		//We move the players to the corresponding team.
		BalanceTeams();
		
		//Players shouldn't move until the round starts
		for(int i = 1; i <= MaxClients; i++)
			if(IsValidClient(i, true))
				SetEntityMoveType(i, MOVETYPE_NONE);	

		EmitRandomSound(g_SndRoundStart);
	}
}

/* OnRoundStart()
**
** We unfreeze every player.
** -------------------------------------------------------------------------- */
public Action OnRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	if(isValidDrMap)
	{
		for(int i = 1; i <= MaxClients; i++)
			if(IsValidClient(i, true))
			{
					SetEntityMoveType(i, MOVETYPE_WALK);
					if((GetClientTeam(i) == RUNNERS && g_runner_outline == 0)||(GetClientTeam(i) == DEATH && g_death_outline == 0))
						SetEntProp(i, Prop_Send, "m_bGlowEnabled", 1);	
			}
		OnStartCountdown = false;
	}
}

public Action OnBroadcast(Event event, const char[] name, bool dontBroadcast)
{
	if(!isValidDrMap)
		return Plugin_Continue;

	static char sound[PLATFORM_MAX_PATH];
	event.GetString("sound", sound, sizeof(sound));
	if(!StrContains(sound, "Game.Your", false) || StrEqual(sound, "Game.Stalemate", false) || !StrContains(sound, "Announcer.AM_RoundStartRandom", false))
		return Plugin_Handled;

	return Plugin_Continue;
}

public Action OnWinPanel(Event event, const char[] name, bool dontBroadcast)
{
	//if(isValidDrMap)
		//return Plugin_Handled;
	return Plugin_Continue;
}


/* TF2Items_OnGiveNamedItem_Post()
**
** Here we check for the demoshield and the sapper.
** -------------------------------------------------------------------------- */
public int TF2Items_OnGiveNamedItem_Post(int client, char[] classname, int index, int level, int quality, int ent)
{
	if(isValidDrMap && g_MeleeOnly)
	{
		if(StrEqual(classname,"tf_weapon_builder", false) || StrEqual(classname,"tf_wearable_demoshield", false))
			CreateTimer(0.1, Timer_RemoveWep, EntIndexToEntRef(ent));  
	}
}

/* Timer_RemoveWep()
**
** We kill the demoshield/sapper
** -------------------------------------------------------------------------- */
public Action Timer_RemoveWep(Handle timer, any ref)
{
	int ent = EntRefToEntIndex(ref);
	if( IsValidEntity(ent) && ent > MaxClients)
		AcceptEntityInput(ent, "Kill");
}  

/* OnPlayerInventory()
**
** Here we strip players weapons (if we have to).
** Also we give special melee weapons (again, if we have to).
** -------------------------------------------------------------------------- */
public Action OnPlayerInventory(Handle event, const char[] name, bool dontBroadcast)
{
	if(isValidDrMap)
	{
		if(g_MeleeOnly)
		{
			// we check their melee weapons first!
			int client = GetClientOfUserId(GetEventInt(event, "userid"));			
			if(g_MeleeRestricted)
			{
				bool replacewep = false;
				if(g_RestrictAll)
					replacewep=true;
				else
				{
					int wepEnt = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
					int wepIndex = GetEntProp(wepEnt, Prop_Send, "m_iItemDefinitionIndex"); 
					int rwSize = GetTrieSize(g_RestrictedWeps);
					char key[4];
					int auxIndex;
					for(int i = 1; i <= rwSize; i++)
					{
						IntToString(i,key,sizeof(key));
						if(GetTrieValue(g_RestrictedWeps,key,auxIndex))
							if(wepIndex == auxIndex)
								replacewep=true;
					}
				
				}
				if(replacewep)
				{
					TF2_RemoveWeaponSlot(client, TFWeaponSlot_Melee);
					int weaponToUse = -1;
					if(g_UseAllClass)
					{
						int acwSize = GetTrieSize(g_AllClassWeps);
						int rndNum;
						if(g_UseDefault)
							rndNum = GetRandomInt(1,acwSize+1);
						else
							rndNum = GetRandomInt(1,acwSize);
						
						if(rndNum <= acwSize)
						{
							char key[4];
							IntToString(rndNum,key,sizeof(key));
							GetTrieValue(g_AllClassWeps,key,weaponToUse);
						}
						
					}
					Handle hItem = TF2Items_CreateItem(FORCE_GENERATION | OVERRIDE_CLASSNAME | OVERRIDE_ITEM_DEF | OVERRIDE_ITEM_LEVEL | OVERRIDE_ITEM_QUALITY | OVERRIDE_ATTRIBUTES);
					
					//Here we give a melee to every class
					TFClassType iClass = TF2_GetPlayerClass(client);
					switch(iClass)
					{
						case TFClass_Scout:{
							TF2Items_SetClassname(hItem, "tf_weapon_bat");
							if(weaponToUse == -1)
								weaponToUse = 190;
							TF2Items_SetItemIndex(hItem, weaponToUse);
							}
						case TFClass_Sniper:{
							TF2Items_SetClassname(hItem, "tf_weapon_club");
							if(weaponToUse == -1)
								weaponToUse = 190;
							TF2Items_SetItemIndex(hItem, weaponToUse);
							TF2Items_SetItemIndex(hItem, 193);
							}
						case TFClass_Soldier:{
							TF2Items_SetClassname(hItem, "tf_weapon_shovel");
							if(weaponToUse == -1)
								weaponToUse = 196;
							TF2Items_SetItemIndex(hItem, weaponToUse);
							}
						case TFClass_DemoMan:{
							TF2Items_SetClassname(hItem, "tf_weapon_bottle");
							if(weaponToUse == -1)
								weaponToUse = 191;
							TF2Items_SetItemIndex(hItem, weaponToUse);
							}
						case TFClass_Medic:{
							TF2Items_SetClassname(hItem, "tf_weapon_bonesaw");
							if(weaponToUse == -1)
								weaponToUse = 198;
							TF2Items_SetItemIndex(hItem, weaponToUse);
							}
						case TFClass_Heavy:{
							TF2Items_SetClassname(hItem, "tf_weapon_fists");
							if(weaponToUse == -1)
								weaponToUse = 195;
							TF2Items_SetItemIndex(hItem, weaponToUse);
							}
						case TFClass_Pyro:{
							TF2Items_SetClassname(hItem, "tf_weapon_fireaxe");
							if(weaponToUse == -1)
								weaponToUse = 192;
							TF2Items_SetItemIndex(hItem, weaponToUse);
							}
						case TFClass_Spy:{
							TF2Items_SetClassname(hItem, "tf_weapon_knife");
							if(weaponToUse == -1)
								weaponToUse = 194;
							TF2Items_SetItemIndex(hItem, weaponToUse);
							}
						case TFClass_Engineer:{
							TF2Items_SetClassname(hItem, "tf_weapon_wrench");
							if(weaponToUse == -1)
								weaponToUse = 197;
							TF2Items_SetItemIndex(hItem, weaponToUse);
							}
						}
							
					TF2Items_SetLevel(hItem, 69);
					TF2Items_SetQuality(hItem, 6);
					TF2Items_SetAttribute(hItem, 0, 150, 1.0); //Turn to gold on kill
					TF2Items_SetNumAttributes(hItem, 1);
					int iWeapon = TF2Items_GiveNamedItem(client, hItem);
					CloseHandle(hItem);
					
					EquipPlayerWeapon(client, iWeapon);
				}
			}
			TF2_SwitchtoSlot(client, TFWeaponSlot_Melee);
			
			// now we strip players of non-melee weapons
			TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
			TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
			TF2_RemoveWeaponSlot(client, TFWeaponSlot_Grenade);
			TF2_RemoveWeaponSlot(client, TFWeaponSlot_Building);
			TF2_RemoveWeaponSlot(client, TFWeaponSlot_PDA);
		}
	}
}

/* OnPlayerSpawn()
**
** Here we enable the glow (if we need to), we set the spy cloak and we move the death player.
** -------------------------------------------------------------------------- */
public Action OnPlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	if(isValidDrMap)
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		if(!IsValidClient(client, true))
			return Plugin_Continue;
		if(g_MeleeOnly)
		{
			int cond = GetEntProp(client, Prop_Send, "m_nPlayerCond");
			
			if (cond & PLAYERCOND_SPYCLOAK)
			{
				SetEntProp(client, Prop_Send, "m_nPlayerCond", cond | ~PLAYERCOND_SPYCLOAK);
			}
		}
		
		if(GetClientTeam(client) == DEATH && client != previousDeath)
		{
			ChangeAliveClientTeam(client, RUNNERS);
			CreateTimer(0.2, RespawnRebalanced,  GetClientUserId(client));
		}
		
		SDKHook(client, SDKHook_PreThink, GameLogic_Prethink);
		
		if(OnStartCountdown)
		{
			SetEntityMoveType(client, MOVETYPE_NONE);
		}
		if(gCheckStuckPlayers)
		{
			StuckCheckTimeout[client]=GetEngineTime()+gStuckCheckTimeout; // start the stuck player timeout!
		}
	}
	return Plugin_Continue;
}


/* OnPlayerDeath()
**
** Here we reproduce sounds if needed and activate the glow effect if needed
** -------------------------------------------------------------------------- */
public Action OnPlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	if(isValidDrMap && !OnStartCountdown)
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		int aliveRunners = GetAlivePlayersCount(RUNNERS,client);
		
		if(IsValidClient(client,false)) // we want to make sure this is a valid client
		{
			SetEntProp(client, Prop_Send, "m_bGlowEnabled", 0);
			StuckCheckTimeout[client]=INACTIVE;
			SDKUnhook(client, SDKHook_PreThink, GameLogic_Prethink);
			StuckCheckTimeout[client]=INACTIVE;
			if(GetClientTeam(client) == RUNNERS && aliveRunners > 1)
				EmitRandomSound(g_SndOnDeath,client);
			if(GetClientTeam(client) == RUNNERS && aliveRunners <= 1)
			{
				for(int i=1 ; i<=MaxClients ; i++)
				{
					if(IsValidClient(i,false) && GetClientTeam(i) == RUNNERS)
					{
						EmitRandomSound(g_SndOnLastManDeath,i);
					}
				}
			}
			if(aliveRunners == 1)
			{
				EmitRandomSound(g_SndLastAlive,GetLastPlayer(RUNNERS,client));
				ShowGameText(GetLastPlayer(RUNNERS,client), "ico_notify_flag_moving_alt", _, "%t", "Last Survivor");
			}	
			int currentDeath = GetLastPlayer(DEATH);
			if(currentDeath > 0 && currentDeath <= MaxClients && IsValidClient(client, false))
				SetEventInt(event,"attacker",GetClientUserId(currentDeath));
				
			if(g_canEmitSoundToDeath)
			{
				if(currentDeath > 0 && currentDeath <= MaxClients)
					EmitRandomSound(g_SndOnKill,currentDeath);
				g_canEmitSoundToDeath = false;
				CreateTimer(g_OnKillDelay, ReenableDeathSound);
			}
			
			if(aliveRunners>0) // check if glow is enabled for x amount of players
			{
				for(int i=1 ; i<=MaxClients ; i++)
				{
					if(!IsValidClient(i, true))
					return Plugin_Continue;
					if(!GetEntProp(i, Prop_Send, "m_bGlowEnabled") && (GetClientTeam(i)== RUNNERS && aliveRunners == g_runner_outline || GetClientTeam(i)== DEATH && aliveRunners == g_death_outline))
					{
						SetEntProp(i, Prop_Send, "m_bGlowEnabled", 1);
					}
				}
			}		
		}
	}
	return Plugin_Continue;
}


public Action ReenableDeathSound(Handle timer, any data)
{
	g_canEmitSoundToDeath = true;
}


/* BalanceTeams()
**
** Moves players to their new team in this round.
** -------------------------------------------------------------------------- */
stock void BalanceTeams()
{
	if(GetClientCount(true) > 1)
	{
		int new_death = GetRandomValid();
		if(new_death == -1)
		{
			CPrintToChatAll("{black}[DR]{red} %t", "Invalid Death");
			return;
		}
		previousDeath  = new_death;
		int team;
		for(int i = 1; i <= MaxClients; i++)
		{
			if(!IsValidClient(i, false))
				continue;
			team = GetClientTeam(i);
			if(team != DEATH && team != RUNNERS)
				continue;
				
			if(i == new_death)
			{
				if(team != DEATH)
				ChangeAliveClientTeam(i, DEATH);
				
				TFClassType iClass = TF2_GetPlayerClass(i);
				if (iClass == TFClass_Unknown)
				{
					TF2_SetPlayerClass(i, TFClass_Scout, false, true);
				}
			}
			else if(team != RUNNERS )
			{
				ChangeAliveClientTeam(i, RUNNERS);
			}
			CreateTimer(0.2, RespawnRebalanced,  GetClientUserId(i));
			
			if(i!=new_death && IsValidClient(new_death, true) && (!IsClientSourceTV(i) || !IsFakeClient(i)))
			{
				ShowGameText(i, "ico_notify_flag_moving_alt", _, "%t", "Deathrun Start", new_death);
				CPrintToChat(i, "{black}[DR]{default} %t", "Deathrun Start", new_death);
			}
			else
			{
				ShowGameText(i, "ico_notify_flag_moving_alt", _, "%t", "Become Death");
				CPrintToChat(i, "{black}[DR]{default} %t", "Become Death");
			}
		}
		if(!IsClientConnected(new_death) || !IsClientInGame(new_death)) 
		{
			CPrintToChatAll("{black}[DR]{red} %t","Death Not Connected");
			return;
		}
		g_timesplayed_asdeath[previousDeath]++;

	}
	else
	{
		CPrintToChatAll("{black}[DR]{red} %t", "Not Enough Players");
	}
}

/* GetRandomValid()
**
** Gets a random player that didn't play as death recently.
** -------------------------------------------------------------------------- */
public int GetRandomValid()
{
	int possiblePlayers[MAXPLAYERS+1], possibleNumber = 0;
	int min = GetMinTimesPlayed(false);
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsValidClient(i, false))
			continue;
		if(!CanClientBeDeath(i))
			continue;
		if(g_timesplayed_asdeath[i] != min)
			continue;
		if(g_dontBeDeath[i] == DBD_ON || g_dontBeDeath[i] == DBD_THISMAP)
			continue;
		
		possiblePlayers[possibleNumber] = i;
		possibleNumber++;
		
	}
	
	//If there are zero people available we ignore the preferences.
	if(!possibleNumber)
	{
		min = GetMinTimesPlayed(true);
		for(int i = 1; i <= MaxClients; i++)
		{
			if(!IsClientConnected(i) || !IsClientInGame(i) )
				continue;
			if(!CanClientBeDeath(i))
				continue;
			if(g_timesplayed_asdeath[i] != min)
				continue;			
			possiblePlayers[possibleNumber] = i;
			possibleNumber++;
		}
		if(!possibleNumber)
			return -1;
	}
	
	return possiblePlayers[ GetRandomInt(0,possibleNumber-1)];

}

/*
**
** spectator glitch fix by abrandnewday
**
*/
bool CanClientBeDeath(int client)
{
    // yo dawg what you reppin'
    TFTeam clientteam = TF2_GetClientTeam(client);
    if(clientteam == TFTeam_Red)
    {
        // yea mothafucka you can be death
        return true;
    }
    else if(clientteam == TFTeam_Blue)
    {
        // yea mothafucka you can also be death
        return true;
    }
    else
    {
        // nah dawg, get the fuck out of here
        return false;
    }
} 

/* GetMinTimesPlayed()
**
** Get the minimum "times played", if ignorePref is true, we ignore the don't be death preference
** -------------------------------------------------------------------------- */
stock int GetMinTimesPlayed(bool ignorePref)
{
	int min = -1;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientConnected(i) || !IsClientInGame(i) || g_timesplayed_asdeath[i] == -1) 
			continue;
		if(i == previousDeath) 
			continue;
		if(!ignorePref)
			if(g_dontBeDeath[i] == DBD_ON || g_dontBeDeath[i] == DBD_THISMAP)
				continue;
		if(min == -1)
			min = g_timesplayed_asdeath[i];
		else
			if(min > g_timesplayed_asdeath[i])
				min = g_timesplayed_asdeath[i];
		
	}
	return min;

}

/* PreThink()
**
** Use PreThink for setting movement speed & spy cloak, as well as  handling AFK events
**
*/

public void GameLogic_Prethink(int client)
{
	if(isValidDrMap && IsValidClient(client, true))
	{
		SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", GetClientTeam(client) == DEATH ? deathSpeed : runnerSpeed);
		if(g_MeleeOnly && TF2_GetPlayerClass(client) == TFClass_Spy)
		{
			SetCloak(client, 1.0);
		}
		// here we check if a player is stuck or not
		if(gCheckStuckPlayers) // only enable stuck player checking if cfg enables this!
		{
			CheckForStuckPlayer(client, GetEngineTime(), gCheckStuckPlayers);
		}
	}
	else
	{
		SDKUnhook(client, SDKHook_PreThink, GameLogic_Prethink);
	}
}

/* OnTakeDamage
**
** We are using OnTakeDamage to handle fall damage to fully remove the dependency on TF2Attributes
**
*/

public Action OnTakeDamage(int client, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if(isValidDrMap && blockFallDamage && (attacker<1 || client==attacker) && damagetype & DMG_FALL) // cancel fall damage
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

/* TF2_SwitchtoSlot()
**
** Changes the client's slot to the desired one.
** -------------------------------------------------------------------------- */
stock void TF2_SwitchtoSlot(int client,int slot)
{
	if (slot >= 0 && slot <= 5 && IsValidClient(client, true))
	{
		char classname[64];
		int wep = GetPlayerWeaponSlot(client, slot);
		if (wep > MaxClients && IsValidEdict(wep) && GetEdictClassname(wep, classname, sizeof(classname)))
		{
			FakeClientCommandEx(client, "use %s", classname);
			SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", wep);
		}
	}
}

/* SetCloak()
**
** Function used to set the spy's cloak meter.
** -------------------------------------------------------------------------- */
stock void SetCloak(int client, float value)
{
	SetEntPropFloat(client, Prop_Send, "m_flCloakMeter", value);
}

/* RespawnRebalanced()
**
** Timer used to spawn a client if he/she is in game and if it isn't alive.
** -------------------------------------------------------------------------- */
public Action RespawnRebalanced(Handle timer, any data)
{
	int client = GetClientOfUserId(data);
	if(IsValidClient(client, false))
	{
		if(!IsPlayerAlive(client))
		{
			TF2_RespawnPlayer(client);
		}
	}
}

/* OnConfigsExecuted()
**
** Here we get the default values of the CVars that the plugin is going to modify.
** -------------------------------------------------------------------------- */
public void OnConfigsExecuted()
{
	dr_queue_def= GetConVarInt(dr_queue);
	dr_unbalance_def = GetConVarInt(dr_unbalance);
	dr_autobalance_def = GetConVarInt(dr_autobalance);
	dr_firstblood_def = GetConVarInt(dr_firstblood);
	dr_scrambleauto_def = GetConVarInt(dr_scrambleauto);
	dr_airdash_def = GetConVarInt(dr_airdash);
	dr_push_def = GetConVarInt(dr_push);
}

/* SetupCvars()
**
** Modify several values of the CVars that the plugin needs to work properly.
** -------------------------------------------------------------------------- */
public void SetupCvars()
{
	SetConVarInt(dr_queue, 0);
	SetConVarInt(dr_unbalance, 0);
	SetConVarInt(dr_autobalance, 0);
	SetConVarInt(dr_firstblood, 0);
	SetConVarInt(dr_scrambleauto, 0);
	SetConVarInt(dr_airdash, 0);
	SetConVarInt(dr_push, 0);
}

/* ResetCvars()
**
** Reset the values of the CVars that the plugin used to their default values.
** -------------------------------------------------------------------------- */
public void ResetCvars()
{
	SetConVarInt(dr_queue, dr_queue_def);
	SetConVarInt(dr_unbalance, dr_unbalance_def);
	SetConVarInt(dr_autobalance, dr_autobalance_def);
	SetConVarInt(dr_firstblood, dr_firstblood_def);
	SetConVarInt(dr_scrambleauto, dr_scrambleauto_def);
	SetConVarInt(dr_airdash, dr_airdash_def);
	SetConVarInt(dr_push, dr_push_def);
	
	//We clear the tries
	ProcessListeners(true);
	ClearTrie(g_RestrictedWeps);
	ClearTrie(g_AllClassWeps);
	ClearTrie(g_CmdList);
	ClearTrie(g_CmdTeamToBlock);
	ClearTrie(g_CmdBlockOnlyOnPrep);
	ClearTrie(g_SndRoundStart);
	ClearTrie(g_SndOnDeath);
	ClearTrie(g_SndOnKill);
	ClearTrie(g_SndLastAlive);
	ClearTrie(g_SndOnLastManDeath);
}

// needed to determine if player is valid
stock bool IsValidClient(int client, bool isPlayerAlive=false)
{
	if (client <= 0 || client > MaxClients) return false;
	if(isPlayerAlive) return IsClientInGame(client) && IsPlayerAlive(client);
	return IsClientInGame(client);
}

/* Command_Block()
**
** Blocks a command, check teams and if it's on preparation.
** -------------------------------------------------------------------------- */
public Action Command_Block(int client, const char[] command, int argc)
{
	if(isValidDrMap)
	{
		int PreparationOnly, blockteam;
		GetTrieValue(g_CmdBlockOnlyOnPrep,command,PreparationOnly);
		
		// this is to fix activators suiciding via any means. Activated by default
		if(IsSuicide(client, command) && GetClientTeam(client)==DEATH)
		{	
			CPrintToChat(client, "{black}[DR]{red}%t", "Suicide Blocked");
			return Plugin_Stop;
		}
		
		//If the command must be blocked only on preparation 
		//and we aren't on preparation time, we let the client run the command.
		if(!OnStartCountdown && !PreparationOnly)
			return Plugin_Continue;
		
		GetTrieValue(g_CmdTeamToBlock,command,blockteam);
		//If the client has the same team as "g_CmdTeamToBlock" 
		//or it's for both teams, we block the command.
		if(GetClientTeam(client) == blockteam  || blockteam == 1)			return Plugin_Stop;
	}
	return Plugin_Continue;
}


/* EmitRandomSound()
**
** Emits a random sound from a trie, it will be emitted for everyone is a client isn't passed.
** -------------------------------------------------------------------------- */
stock void EmitRandomSound(Handle sndTrie,int client = -1)
{
	int trieSize = GetTrieSize(sndTrie);
	
	char key[4], sndFile[PLATFORM_MAX_PATH];
	IntToString(GetRandomInt(1,trieSize),key,sizeof(key));

	if(GetTrieString(sndTrie,key,sndFile,sizeof(sndFile)))
	{
		if(StrEqual(sndFile, ""))
			return;
			
		if(client != -1)
		{
			if(client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client))
				EmitSoundToClient(client,sndFile,_,_, SNDLEVEL_TRAIN);
			else
				return;
		}
		else	
			EmitSoundToAll(sndFile, _, _, SNDLEVEL_TRAIN);
	}
}

stock int GetAlivePlayersCount(int team,int ignore=-1) 
{ 
	int count = 0, i;

	for(i = 1; i <= MaxClients; i++ ) 
		if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == team && i != ignore) 
			count++; 

	return count; 
}  

stock int GetLastPlayer(int team,int ignore=-1) 
{ 
	for(int i = 1; i <= MaxClients; i++ ) 
		if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == team && i != ignore) 
			return i;
	return -1;
}  

stock void ChangeAliveClientTeam(int client, int newTeam)
{
	int oldTeam = GetClientTeam(client);

	if (oldTeam != newTeam)
	{
		SetEntProp(client, Prop_Send, "m_lifeState", 2);
		ChangeClientTeam(client, newTeam);
		SetEntProp(client, Prop_Send, "m_lifeState", 0);
		TF2_RespawnPlayer(client);
	}
}

/* in-game HUD messages */
stock bool ShowGameText(int client, const char[] icon="leaderboard_streak", int color=0, const char[] buffer, any ...)
{
	BfWrite bf;
	if(!client)
	{
		bf = view_as<BfWrite>(StartMessageAll("HudNotifyCustom"));
	}
	else
	{
		bf = view_as<BfWrite>(StartMessageOne("HudNotifyCustom", client));
	}

	if(bf == null)
		return false;

	static char message[512];
	SetGlobalTransTarget(client);
	VFormat(message, sizeof(message), buffer, 5);
	ReplaceString(message, sizeof(message), "\n", "");

	bf.WriteString(message);
	bf.WriteString(icon);
	bf.WriteByte(color);
	EndMessage();
	return true;
}

/*
** Here we check if a player got stuck and determine what action to do
** 0 - disabled
** 1 - slay player
** 2 - teleport to last location
** 3 - teleport to nearest player
** 4 - respawn player (if a map doesn't have a motivator)
*/
stock void CheckForStuckPlayer(int client, float gameTime, int action)
{
	if(gameTime>=StuckCheckTimeout[client])
	{
		static float pLoc[3];
		StuckCheckTimeout[client]+=gStuckCheckTimeout;
		if (!IsPlayerStuck(client) && (GetEntityFlags(client) & FL_ONGROUND)) // capture previous location if target is on ground and not stuck!
		{
			GetEntPropVector(client, Prop_Send, "m_vecOrigin", pLoc);
			return;
		}
		HandleStuckPlayer(client, action, pLoc);
	}
}

stock void HandleStuckPlayer(int client, int action, float location[3])
{
	switch(action)
	{
		case 1: ForcePlayerSuicide(client); // slay player
		case 2:	TeleportEntity(client, location, NULL_VECTOR, NULL_VECTOR); // teleport to previous location
		case 3:	// teleport to random runner
		{
			int target=GetRandomInt(1, MaxClients);
			while(!IsValidClient(target) || client==target || GetClientTeam(target)==DEATH || !(GetEntityFlags(client) & FL_ONGROUND))
			{
				target=GetRandomInt(1, MaxClients);
			}
			float tLoc[3];
			GetEntPropVector(target, Prop_Send, "m_vecOrigin", tLoc);
			TeleportEntity(client, tLoc, NULL_VECTOR, NULL_VECTOR);
		
		}
		case 4: TF2_RespawnPlayer(client); // respawn if no motivator
	}
}

stock bool IsPlayerStuck(int client)
{
	if(GetEntityMoveType(client) == MOVETYPE_NONE) // if a trap sets this or is preround, do not mark as stuck!
		return false;
	
	float location[3], min[3], max[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", location);
	GetEntPropVector(client, Prop_Send, "m_vecMins", min);
	GetEntPropVector(client, Prop_Send, "m_vecMaxs", max);
	
	TR_TraceHullFilter(location, location, min, max, MASK_SOLID, IsTracedFilterNotSelf, client);
	return TR_DidHit(); // if a player is stuck, it will return true
}

public bool IsTracedFilterNotSelf(int entity, int contentsMask, any client)
{
	if(entity == client)
	{
		return false;
	}
	return true;
}
