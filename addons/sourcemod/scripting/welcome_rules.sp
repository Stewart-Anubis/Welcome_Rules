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
#include <geoip>

#pragma newdecls required

#define VERSION "1.0-B"

ConVar g_CvarShowOnConnect;
ConVar g_CvarShowOnConnectTimeout;
ConVar g_CvarShowOnConnectDelay;
ConVar g_CvarShowAdminRules;

bool b_CvarShowOnConnect;
bool b_CvarShowAdminRules;
int i_CvarShowOnConnectTimeout;
float f_CvarShowOnConnectDelay;


Handle mp_maxmoney = INVALID_HANDLE;
Handle sv_disable_radar = INVALID_HANDLE;
Handle spawng_hTimer[MAXPLAYERS + 1] = INVALID_HANDLE;
bool ClienCommand[MAXPLAYERS+1];
bool g_bRemember[MAXPLAYERS + 1];
char value_mp_maxmoney[10];
char value_sv_disable_radar[10];

char welcomepath[PLATFORM_MAX_PATH];


public Plugin myinfo =
{
	name = "Welcome & Rules.sp",
	author = "Anubis",
	description = "Welcome menu with rules, commands and Observations for players.",
	version = VERSION,
	url = "stewartbh@live.com"
};

public void OnPluginStart()
{
	LoadTranslations("welcome_rules.phrases");
	LoadTranslations("common.phrases");
	LoadTranslations("core.phrases");

	BuildPath(Path_SM, welcomepath, sizeof(welcomepath), "configs/Welcome_rules.cfg");

	RegConsoleCmd("sm_rules", RulesMenu_Func);
	RegConsoleCmd("sm_welcome", RulesMenu_Func);
	RegConsoleCmd("sm_commands", RulesMenu_Func);

	RegAdminCmd("sm_showrules", ShowMenu, ADMFLAG_GENERIC);
	RegAdminCmd("sm_showwelcome", ShowMenu, ADMFLAG_GENERIC);

	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_PostNoCopy);

	g_CvarShowOnConnect = CreateConVar("sm_welcome_onconnect", "1", "Set to 0 If you dont want menu to show on players connection .");
	g_CvarShowOnConnectTimeout = CreateConVar("sm_welcome_onconnect_timeout", "10", "Timeout delay in seconds, set to 0 If you dont want the menu to timeout on players connection .");
	g_CvarShowAdminRules = CreateConVar("sm_welcome_admin_rules", "0", "Set to 0 if you do not want to show Admin rules upon connect, 1 if you do.");
	g_CvarShowOnConnectDelay = CreateConVar("sm_welcome_onconnect_delay", "2.1", "Delay in seconds, to start the welcome menu.");

	b_CvarShowOnConnect = g_CvarShowOnConnect.BoolValue;
	i_CvarShowOnConnectTimeout = g_CvarShowOnConnectTimeout.IntValue;
	b_CvarShowAdminRules = g_CvarShowAdminRules.BoolValue;
	f_CvarShowOnConnectDelay = g_CvarShowOnConnectDelay.FloatValue;

	mp_maxmoney = FindConVar("mp_maxmoney");
	GetConVarString(mp_maxmoney, value_mp_maxmoney, sizeof(value_mp_maxmoney));
	sv_disable_radar = FindConVar("sv_disable_radar");
	GetConVarString(sv_disable_radar, value_sv_disable_radar, sizeof(value_sv_disable_radar));

	AutoExecConfig(true, "Welcome_Rules");
}

public void OnConfigsExecuted()
{
	b_CvarShowOnConnect = g_CvarShowOnConnect.BoolValue;
	i_CvarShowOnConnectTimeout = g_CvarShowOnConnectTimeout.IntValue;
	b_CvarShowAdminRules = g_CvarShowAdminRules.BoolValue;
	f_CvarShowOnConnectDelay = g_CvarShowOnConnectDelay.FloatValue;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (b_CvarShowOnConnect && !IsFakeClient(client))
	{
		CloseTimer(client);
		spawng_hTimer[client] = CreateTimer(f_CvarShowOnConnectDelay, WelcomeMenuSpawn, client);
	}
}

public Action WelcomeMenuSpawn(Handle timer, any client)
{
	spawng_hTimer[client] = INVALID_HANDLE;

	if (b_CvarShowAdminRules)
	{
		if (!g_bRemember[client] && IsClientInGame(client) && GetClientTeam(client) != 0 && IsPlayerAlive(client) && !IsFakeClient(client))
		{
			CreateWelcomeMenu(client);
		}
	}
	else
	{
		AdminId admin = GetUserAdmin(client);
		if (!GetAdminFlag(admin, Admin_Kick))
		{
			if (!g_bRemember[client] && IsClientInGame(client) && GetClientTeam(client) != 0 && IsPlayerAlive(client) && !IsFakeClient(client))
			{
				CreateWelcomeMenu(client);
			}
		}
	}
	return Plugin_Handled;
}

public void OnClientCookiesCached(int client)
{
	g_bRemember[client] = false;
}

public Action RulesMenu_Func(int client, int args)
{
	CreateWelcomeMenu(client);
	return Plugin_Handled;
}

public void CloseTimer(int client)
{
	if (spawng_hTimer[client] != INVALID_HANDLE)
	{
		KillTimer(spawng_hTimer[client]);
		spawng_hTimer[client] = INVALID_HANDLE;
	}
}

public Action CreateWelcomeMenu(int client)
{
	Menu WelcomeMenu = new Menu(WelcomeMenuHandler);

	SetGlobalTransTarget(client);
	ClienCommand[client] = true;

	if (IsClientInGame(client) && IsPlayerAlive(client))
	{
		SendConVarValue(client, mp_maxmoney, "0");
		SendConVarValue(client, sv_disable_radar, "1");
	}

	char m_title[255], ItemNumber[64], ItemName[255];
	char sCountryTag[3], sIP[26], name[26];

	Format(m_title, sizeof(m_title), "%t", "Welcome menu title", client);

	WelcomeMenu.SetTitle(m_title);
	WelcomeMenu.ExitButton = true;

	GetClientIP(client, sIP, sizeof(sIP));
	GeoipCode2(sIP, sCountryTag);
	Format(name, sizeof(name), "name_%s", sCountryTag);

	Handle kv = CreateKeyValues("Welcome");
	FileToKeyValues(kv, welcomepath);

	if (!KvGotoFirstSubKey(kv))
	{
		return Plugin_Continue;
	}

	do
	{
		KvGetSectionName(kv, ItemNumber, sizeof(ItemNumber));
		KvGetString(kv, name, ItemName, sizeof(ItemName), "LANGMISSING");
		if (StrEqual(ItemName, "LANGMISSING")) KvGetString(kv, "name_US", ItemName, sizeof(ItemName));
		WelcomeMenu.AddItem(ItemNumber, ItemName);
	}while (KvGotoNextKey(kv));
	CloseHandle(kv);

	WelcomeMenu.Display(client, i_CvarShowOnConnectTimeout);
	return Plugin_Handled;
}

public int WelcomeMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Cancel)
	{
		if (ClienCommand[param1])
		{
			if (IsClientInGame(param1) && IsPlayerAlive(param1))
			{
				SendConVarValue(param1, mp_maxmoney, value_mp_maxmoney);
				SendConVarValue(param1, sv_disable_radar, value_sv_disable_radar);
				FakeClientCommand(param1, "say !guns");
				//g_bRemember[param1] = true;
				MenuOut(param1);
			}
		}
	}
	else if (action == MenuAction_Select)
	{
		if(param2 < 0)
		{
			delete menu;
		}
		else
		{
			ClienCommand[param1] = false;

			Handle kv = CreateKeyValues("Welcome");
			FileToKeyValues(kv, welcomepath);

			if (!KvGotoFirstSubKey(kv))
			{
				delete(menu);
			}
			KvRewind(kv);

			char choice[255];
			GetMenuItem(menu, param2, choice, sizeof(choice));
			CreateItemMenu(param1, choice);

			CloseHandle(kv);
		}
	}
}

public Action ShowMenu(int client,int args)
{
	Menu PlayersMenu = new Menu(ShowMenuHandler);

	SetGlobalTransTarget(client);

	char m_title[255];
	Format(m_title, sizeof(m_title), "%t", "ShowMenu menu title", client);

	PlayersMenu.SetTitle(m_title);
	PlayersMenu.ExitButton = true;

	AddTargetsToMenu2(PlayersMenu, client, COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_CONNECTED);
	PlayersMenu.Display(client, i_CvarShowOnConnectTimeout);
	return Plugin_Handled;
}

public int ShowMenuHandler(Menu showmenu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete showmenu;
	}  
	else if (action == MenuAction_Select)
	{
		char UserId[64];
		GetMenuItem(showmenu, param2, UserId, sizeof(UserId));
		int i_UserId = StringToInt(UserId);
		int client = GetClientOfUserId(i_UserId);
		CreateWelcomeMenu(client);
	}
}

public Action CreateItemMenu(int client, char intem[255])
{
	Handle kv = CreateKeyValues("Welcome");
	Handle kv2 = CreateKeyValues("Description");

	Menu ItemMenu = new Menu(ItemMenuHandler);

	FileToKeyValues(kv, welcomepath);

	if (!KvGotoFirstSubKey(kv))
	{
		delete(ItemMenu);
	}
	KvRewind(kv);

	char sCountryTag[3], sIP[26], name[26], ItemDescription[26];

	GetClientIP(client, sIP, sizeof(sIP));
	GeoipCode2(sIP, sCountryTag);
	Format(name, sizeof(name), "name_%s", sCountryTag);
	Format(ItemDescription, sizeof(ItemDescription), "description_%s", sCountryTag);

	if(KvJumpToKey(kv, intem))
	{
		char Line[1000], ItemTitle[255], ItemNumber[64];
		KvGetString(kv, name, ItemTitle, sizeof(ItemTitle), "LANGMISSING");
		if (StrEqual(ItemTitle, "LANGMISSING"))
		{
			KvGetString(kv, "name_US", ItemTitle, sizeof(ItemTitle));
			Format(ItemDescription, sizeof(ItemDescription), "description_US");
		}

		ItemMenu.SetTitle("%s\n ", ItemTitle);
		ItemMenu.ExitButton = false;
		ItemMenu.ExitBackButton = true;

		if(KvJumpToKey(kv, ItemDescription))
		{
			KvCopySubkeys(kv, kv2);
			KvGotoFirstSubKey(kv2);
			CloseHandle(kv);

			do
			{
				KvGetSectionName(kv2, ItemNumber, sizeof(ItemNumber));
				KvGetString(kv2, "line", Line, sizeof(Line));
				ItemMenu.AddItem(ItemNumber, Line, ITEMDRAW_DISABLED);
			} while (KvGotoNextKey(kv2));
			CloseHandle(kv2);				
		}
		ItemMenu.Display(client, MENU_TIME_FOREVER);
	}
	return Plugin_Handled;
}

public int ItemMenuHandler(Menu menuitem, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menuitem;
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		CreateWelcomeMenu(param1);
	}
	if (action == MenuAction_Select)
	{
		delete menuitem;
	}
}

public Action MenuOut(int client)
{
	if (IsClientInGame(client) && IsPlayerAlive(client))
	{
		SendConVarValue(client, mp_maxmoney, "0");
		SendConVarValue(client, sv_disable_radar, "1");
	}

	Menu mMenuOut = new Menu(MenuOutHandler);

	SetGlobalTransTarget(client);

	char MenuOutTitle[255],MenuOutExit[32];

	Format(MenuOutTitle, sizeof(MenuOutTitle), "%t", "Menu out message title", client);
	Format(MenuOutExit, sizeof(MenuOutExit), "%t", "Exit");

	mMenuOut.SetTitle(MenuOutTitle);
	mMenuOut.ExitButton = false;
	mMenuOut.ExitBackButton = false;

	mMenuOut.AddItem(" ", MenuOutExit);
	mMenuOut.Display(client, i_CvarShowOnConnectTimeout);
	return Plugin_Handled;
}

public int MenuOutHandler(Menu menuout, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		//delete menuout;
	}
	else if (action == MenuAction_Cancel)
	{
		if (IsClientInGame(param1) && IsPlayerAlive(param1))
		{
			SendConVarValue(param1, mp_maxmoney, value_mp_maxmoney);
			SendConVarValue(param1, sv_disable_radar, value_sv_disable_radar);
			FakeClientCommand(param1, "say !guns");
			//delete menuout;
		}
	}
	else if (action == MenuAction_Select)
	{
		if (IsClientInGame(param1) && IsPlayerAlive(param1))
		{
			SendConVarValue(param1, mp_maxmoney, value_mp_maxmoney);
			SendConVarValue(param1, sv_disable_radar, value_sv_disable_radar);
			FakeClientCommand(param1, "say !guns");
			g_bRemember[param1] = true;
			//delete menuout;
		}
	}
}