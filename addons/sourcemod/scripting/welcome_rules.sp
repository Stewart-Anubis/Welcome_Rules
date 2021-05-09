/*
 * =============================================================================
 * File:		  welcome_rules.sp
 * Type:		  Base
 * Description:   Plugin's base file.
 *
 * Copyright (C)   Anubis Edition. All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <adminmenu>
#include <admin>
#include <csgocolors_fix>

#pragma newdecls required

#define LENGTH_MAX_LINE	1024
#define LENGTH_MED_LINE	512
#define LENGTH_MIN_LINE	256
#define LENGTH_MAX_TEXT	128
#define LENGTH_MED_TEXT	64
#define LENGTH_MIN_TEXT	32

#define PLUGIN_NAME           "Welcome & Rules"
#define PLUGIN_AUTHOR         "Anubis"
#define PLUGIN_DESCRIPTION    "Welcome menu with rules, commands and Observations for players."
#define PLUGIN_VERSION        "1.1"
#define PLUGIN_URL            "https://github.com/Stewart-Anubis"

ConVar g_cCvarShowOnConnect;
ConVar g_cCvarShowOnConnectTimeout;
ConVar g_cCvarShowOnConnectDelay;
ConVar g_cCvarShowAdminRules;

Handle g_hMp_Maxmoney = INVALID_HANDLE;
Handle g_hSv_Disable_Radar = INVALID_HANDLE;
Handle g_hSpawng_hTimer[MAXPLAYERS + 1] = INVALID_HANDLE;

bool g_bCvarShowOnConnect;
bool g_bCvarShowAdminRules;
bool g_bRemember[MAXPLAYERS + 1];

int g_iCvarShowOnConnectTimeout;
int g_iItemMenu[MAXPLAYERS + 1];
int g_iMenuBackKey[MAXPLAYERS + 1];

float g_fCvarShowOnConnectDelay;

char g_sValue_Mp_Maxmoney[10];
char g_sValue_Sv_Disable_Radar[10];
char g_sWelcomePath[MAXPLAYERS + 1][PLATFORM_MAX_PATH];

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart()
{
	LoadTranslations("welcome_rules.phrases");
	LoadTranslations("common.phrases");
	LoadTranslations("core.phrases");

	RegConsoleCmd("sm_rules", RulesMenu_Func);
	RegConsoleCmd("sm_welcome", RulesMenu_Func);
	RegConsoleCmd("sm_commands", RulesMenu_Func);

	RegAdminCmd("sm_showrules", ShowMenu, ADMFLAG_GENERIC);
	RegAdminCmd("sm_showwelcome", ShowMenu, ADMFLAG_GENERIC);

	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_PostNoCopy);

	g_cCvarShowOnConnect = CreateConVar("sm_welcome_onconnect", "1", "Set to 0 If you dont want menu to show on players connection .");
	g_cCvarShowOnConnectTimeout = CreateConVar("sm_welcome_onconnect_timeout", "10", "Timeout delay in seconds, set to 0 If you dont want the menu to timeout on players connection .");
	g_cCvarShowAdminRules = CreateConVar("sm_welcome_admin_rules", "0", "Set to 0 if you do not want to show Admin rules upon connect, 1 if you do.");
	g_cCvarShowOnConnectDelay = CreateConVar("sm_welcome_onconnect_delay", "2.1", "Delay in seconds, to start the welcome menu.");

	g_bCvarShowOnConnect = g_cCvarShowOnConnect.BoolValue;
	g_iCvarShowOnConnectTimeout = g_cCvarShowOnConnectTimeout.IntValue;
	g_bCvarShowAdminRules = g_cCvarShowAdminRules.BoolValue;
	g_fCvarShowOnConnectDelay = g_cCvarShowOnConnectDelay.FloatValue;

	g_hMp_Maxmoney = FindConVar("mp_maxmoney");
	GetConVarString(g_hMp_Maxmoney, g_sValue_Mp_Maxmoney, sizeof(g_sValue_Mp_Maxmoney));
	g_hSv_Disable_Radar = FindConVar("sv_disable_radar");
	GetConVarString(g_hSv_Disable_Radar, g_sValue_Sv_Disable_Radar, sizeof(g_sValue_Sv_Disable_Radar));

	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			OnClientPutInServer(i);
		}
	}

	AutoExecConfig(true, "Welcome_Rules");
}

public void OnConfigsExecuted()
{
	g_bCvarShowOnConnect = g_cCvarShowOnConnect.BoolValue;
	g_iCvarShowOnConnectTimeout = g_cCvarShowOnConnectTimeout.IntValue;
	g_bCvarShowAdminRules = g_cCvarShowAdminRules.BoolValue;
	g_fCvarShowOnConnectDelay = g_cCvarShowOnConnectDelay.FloatValue;
}

public void OnClientPutInServer(int client)
{
	CreateTimer(1.0, OnClientPutInServerPost, client);
}

public Action OnClientPutInServerPost(Handle PutTimer, int client)
{
	if(IsValidClient(client))
	{
		char g_sClLang[3];
		GetLanguageInfo(GetClientLanguage(client), g_sClLang, sizeof(g_sClLang));

		BuildPath(Path_SM, g_sWelcomePath[client], sizeof(g_sWelcomePath[]), "configs/Welcome_Rules/Welcome_%s.cfg" ,g_sClLang);
		if(!FileExists(g_sWelcomePath[client]))
		BuildPath(Path_SM, g_sWelcomePath[client], sizeof(g_sWelcomePath[]), "configs/Welcome_Rules/Welcome_us.cfg");
		g_iItemMenu[client] = 0;
		g_iMenuBackKey[client] = 0;
		g_bRemember[client] = false;
	}
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (g_bCvarShowOnConnect && IsValidClient(client))
	{
		CloseTimer(client);
		g_hSpawng_hTimer[client] = CreateTimer(g_fCvarShowOnConnectDelay, WelcomeMenuSpawn, client);
	}
}

public Action WelcomeMenuSpawn(Handle timer, any client)
{
	g_hSpawng_hTimer[client] = INVALID_HANDLE;

	if (g_bCvarShowAdminRules)
	{
		if (!g_bRemember[client] && IsValidClient(client))
		{
			CreateWelcomeMenu(client);
			CPrintToChat(client, "%t", "Welcome Menu", client);
		}
	}
	else
	{
		AdminId admin = GetUserAdmin(client);
		if (!GetAdminFlag(admin, Admin_Kick))
		{
			if (!g_bRemember[client] && IsValidClient(client))
			{
				CreateWelcomeMenu(client);
				CPrintToChat(client, "%t", "Welcome Menu", client);
			}
		}
	}
	return Plugin_Handled;
}

public Action RulesMenu_Func(int client, int args)
{
	CreateWelcomeMenu(client);
	CPrintToChat(client, "%t", "Welcome Menu", client);
	return Plugin_Handled;
}

public void CloseTimer(int client)
{
	if (g_hSpawng_hTimer[client] != INVALID_HANDLE)
	{
		KillTimer(g_hSpawng_hTimer[client]);
		g_hSpawng_hTimer[client] = INVALID_HANDLE;
	}
}

void CreateWelcomeMenu(int client, char[] s_Intem = "", bool b_MenuItem = false, bool b_MenuSubItem = false)
{
	if(!IsValidClient(client))
	{
		return;
	}

	SendConVarValue(client, g_hMp_Maxmoney, "0");
	SendConVarValue(client, g_hSv_Disable_Radar, "1");

	char s_Wtitle[LENGTH_MIN_LINE];
	char s_ItemNumber[LENGTH_MIN_TEXT];
	char s_ItemName[LENGTH_MIN_LINE];
	char s_Line[LENGTH_MED_LINE];
	char s_Exec[LENGTH_MED_TEXT];
	char s_ExecButon[LENGTH_MIN_TEXT];

	Menu WelcomeMenu = new Menu(WelcomeMenuHandler);
	Handle h_kvWelcome = CreateKeyValues("Welcome");

	FileToKeyValues(h_kvWelcome, g_sWelcomePath[client]);

	if (b_MenuSubItem && !StrEqual(s_Intem, ""))
	{
		SetGlobalTransTarget(client);
		Format(s_ExecButon, sizeof(s_ExecButon), "%t", "To execute");
		IntToString(g_iMenuBackKey[client], s_ItemNumber, sizeof(s_ItemNumber));
		g_iItemMenu[client] = 2;
		if(KvJumpToKey(h_kvWelcome, s_ItemNumber))
		{
			if(KvJumpToKey(h_kvWelcome, "description"))
			{
				if(KvJumpToKey(h_kvWelcome, s_Intem))
				{
					if(KvJumpToKey(h_kvWelcome, "exec"))
					{
						KvGetString(h_kvWelcome, "name", s_Wtitle, sizeof(s_Wtitle));
						KvGetString(h_kvWelcome, "description", s_Line, sizeof(s_Line));
						KvGetString(h_kvWelcome, "exec", s_Exec, sizeof(s_Exec), "LINEMISSING");

						WelcomeMenu.SetTitle("%s\n \n%s\n ", s_Wtitle, s_Line);
						WelcomeMenu.ExitBackButton = true;
						if(StrEqual(s_Exec, "LINEMISSING")) WelcomeMenu.AddItem(s_Exec, s_ExecButon, ITEMDRAW_NOTEXT);
						else WelcomeMenu.AddItem(s_Exec, s_ExecButon);
						WelcomeMenu.Display(client, MENU_TIME_FOREVER);
					}
				}
			}
		}
	}
	else if (b_MenuItem && !StrEqual(s_Intem, ""))
	{
		if(KvJumpToKey(h_kvWelcome, s_Intem))
		{
			KvGetSectionName(h_kvWelcome, s_ItemNumber, sizeof(s_ItemNumber));
			KvGetString(h_kvWelcome, "name", s_Wtitle, sizeof(s_Wtitle));
			g_iItemMenu[client] = 1;
			g_iMenuBackKey[client] = StringToInt(s_ItemNumber);

			WelcomeMenu.SetTitle("%s\n ", s_Wtitle);
			WelcomeMenu.ExitBackButton = true;

			if(KvJumpToKey(h_kvWelcome, "description"))
			{
				if(KvGotoFirstSubKey(h_kvWelcome))
				{
					do
					{
						KvGetString(h_kvWelcome, "line", s_Line, sizeof(s_Line), "LINEMISSING");
						if(StrEqual(s_Line, "LINEMISSING"))
						{
							KvGetSectionName(h_kvWelcome, s_ItemNumber, sizeof(s_ItemNumber));
							KvJumpToKey(h_kvWelcome, "exec");
							KvGetString(h_kvWelcome, "name", s_Line, sizeof(s_Line), "LINEMISSING");
							WelcomeMenu.AddItem(s_ItemNumber, s_Line);
							KvGoBack(h_kvWelcome);
						}
						else
						{
							WelcomeMenu.AddItem("", s_Line, ITEMDRAW_DISABLED);
						}

					} while (KvGotoNextKey(h_kvWelcome));
					WelcomeMenu.Display(client, MENU_TIME_FOREVER);
				}
			}
		}
	}
	else
	{
		if (KvGotoFirstSubKey(h_kvWelcome))
		{
			g_iItemMenu[client] = 0;
			g_iMenuBackKey[client] = 0;
			Format(s_Wtitle, sizeof(s_Wtitle), "%t\n ", "Welcome menu title", client);
			WelcomeMenu.SetTitle(s_Wtitle);
			WelcomeMenu.ExitButton = true;

			do
			{
				KvGetSectionName(h_kvWelcome, s_ItemNumber, sizeof(s_ItemNumber));
				KvGetString(h_kvWelcome, "name", s_ItemName, sizeof(s_ItemName));
				WelcomeMenu.AddItem(s_ItemNumber, s_ItemName);
			}while (KvGotoNextKey(h_kvWelcome));
			WelcomeMenu.Display(client, g_iCvarShowOnConnectTimeout);
		}
	}
	CloseHandle(h_kvWelcome);
}

public int WelcomeMenuHandler(Menu WelcomeMenu, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_End)
	{
		delete WelcomeMenu;
	}

	if (action == MenuAction_Select)
	{
		char s_itemNum[LENGTH_MIN_TEXT];
		GetMenuItem(WelcomeMenu, itemNum, s_itemNum, sizeof(s_itemNum));
		
		if (g_iItemMenu[client] == 0)
		{
			CreateWelcomeMenu(client, s_itemNum, true);
		}
		else if (g_iItemMenu[client] == 1)
		{
			CreateWelcomeMenu(client, s_itemNum, false, true);
		}
		else if (g_iItemMenu[client] == 2)
		{
			if (IsValidClient(client))
			{
				SendConVarValue(client, g_hMp_Maxmoney, g_sValue_Mp_Maxmoney);
				SendConVarValue(client, g_hSv_Disable_Radar, g_sValue_Sv_Disable_Radar);
				FakeClientCommand(client, s_itemNum);
				g_iItemMenu[client] = 0;
				g_iMenuBackKey[client] = 0;
				g_bRemember[client] = true;
			}
		}
	}

	if (itemNum == MenuCancel_ExitBack)
	{
		if (g_iItemMenu[client] == 1)
		{
			CreateWelcomeMenu(client);
		}
		if (g_iItemMenu[client] == 2)
		{
			char s_temp[LENGTH_MIN_TEXT];
			IntToString(g_iMenuBackKey[client], s_temp, sizeof(s_temp));
			action = MenuAction_Select;
			CreateWelcomeMenu(client, s_temp, true);
			CPrintToChat(client, "%t", "WelcomeMenu End", client);
		}
	}

	if (itemNum == MenuCancel_Exit)
	{
		g_bRemember[client] = true;
	}

	if (action == MenuAction_Cancel && itemNum != MenuCancel_ExitBack)
	{
		if (IsValidClient(client))
		{
			SendConVarValue(client, g_hMp_Maxmoney, g_sValue_Mp_Maxmoney);
			SendConVarValue(client, g_hSv_Disable_Radar, g_sValue_Sv_Disable_Radar);
			FakeClientCommand(client, "say !guns");
			g_iItemMenu[client] = 0;
			g_iMenuBackKey[client] = 0;
			CPrintToChat(client, "%t", "WelcomeMenu End", client);
		}
	}

	return 0 ;
}

public Action ShowMenu(int client,int args)
{
	Menu PlayersMenu = new Menu(ShowMenuHandler);
	SendConVarValue(client, g_hMp_Maxmoney, "0");
	SendConVarValue(client, g_hSv_Disable_Radar, "1");
	SetGlobalTransTarget(client);

	char m_title[LENGTH_MAX_TEXT];
	Format(m_title, sizeof(m_title), "%t", "ShowMenu menu title", client);

	PlayersMenu.SetTitle(m_title);
	PlayersMenu.ExitButton = true;

	AddTargetsToMenu2(PlayersMenu, client, COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_CONNECTED);
	PlayersMenu.Display(client, MENU_TIME_FOREVER);
}

public int ShowMenuHandler(Menu showmenu, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_End)
	{
		delete showmenu;
	}

	if (action == MenuAction_Select)
	{
		char UserId[LENGTH_MED_TEXT];
		GetMenuItem(showmenu, itemNum, UserId, sizeof(UserId));
		int i_UserId = StringToInt(UserId);
		int target = GetClientOfUserId(i_UserId);
		CreateWelcomeMenu(target);
		CPrintToChat(target, "%t", "ShowMenu target", client);
		if (IsValidClient(client))
		{
			SendConVarValue(client, g_hMp_Maxmoney, g_sValue_Mp_Maxmoney);
			SendConVarValue(client, g_hSv_Disable_Radar, g_sValue_Sv_Disable_Radar);
		}
	}

	if (action == MenuAction_Cancel && itemNum != MenuCancel_ExitBack)
	{
		if (IsValidClient(client))
		{
			SendConVarValue(client, g_hMp_Maxmoney, g_sValue_Mp_Maxmoney);
			SendConVarValue(client, g_hSv_Disable_Radar, g_sValue_Sv_Disable_Radar);
		}
	}

	return 0 ;
}

stock bool IsValidClient(int client, bool bzrAllowBots = false, bool bzrAllowDead = true)
{
	if (!(1 <= client <= MaxClients) || !IsClientInGame(client) || (IsFakeClient(client) && !bzrAllowBots) || IsClientSourceTV(client) || IsClientReplay(client) || (!bzrAllowDead && !IsPlayerAlive(client)))
		return false;
	return true;
}