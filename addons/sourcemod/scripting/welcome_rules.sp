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

#define LENGTH_MED_LINE	512
#define LENGTH_MIN_LINE	256
#define LENGTH_MAX_TEXT	128
#define LENGTH_MED_TEXT	64
#define LENGTH_MIN_TEXT	32

#define WELCOME_MAX_CMDS 5
#define WELCOME_MAX_LENGTH 16

#define PLUGIN_NAME           "Welcome & Rules"
#define PLUGIN_AUTHOR         "Anubis"
#define PLUGIN_DESCRIPTION    "Welcome menu with rules, commands and Observations for players."
#define PLUGIN_VERSION        "1.2"
#define PLUGIN_URL            "https://github.com/Stewart-Anubis"

ConVar g_cCvarWelcomeCmd = null,
	g_cCvarShowOnConnectTimeout = null,
	g_cCvarShowOnConnectDelay = null,
	g_cCvarShowAdminRules = null,
	g_cCvarCommandAfterClosing = null;

Handle g_hSpawng_hTimer[MAXPLAYERS + 1] = INVALID_HANDLE;

bool g_bCvarShowAdminRules = false,
	g_bRemember[MAXPLAYERS + 1] = {false, ...};

int g_iCvarShowOnConnectTimeout = 10,
	g_iItemMenu[MAXPLAYERS + 1] = {0, ...},
	g_iMenuBackKey[MAXPLAYERS + 1] = {0, ...},
	g_iLastSelection[MAXPLAYERS + 1] = {-1, ...};

float g_fCvarShowOnConnectDelay = 2.1;

char g_sMenuTriggers[WELCOME_MAX_CMDS * WELCOME_MAX_LENGTH],
	g_sCommandAfterClosing[LENGTH_MED_TEXT];

KeyValues g_hkvWelcome[MAXPLAYERS + 1];

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

	RegAdminCmd("sm_showrules", ShowMenu, ADMFLAG_GENERIC);
	RegAdminCmd("sm_showwelcome", ShowMenu, ADMFLAG_GENERIC);

	g_cCvarWelcomeCmd				= CreateConVar("sm_welcome_cmd", "help, rules, ajuda, regras", "Client commands start the Welcome menu.");
	g_cCvarShowOnConnectTimeout	= CreateConVar("sm_welcome_onconnect_timeout", "10", "Timeout delay in seconds, set to 0 If you dont want the menu to timeout on players connection.", _,true, 0.0);
	g_cCvarShowAdminRules			= CreateConVar("sm_welcome_admin_rules", "0", "Set to 0 if you do not want to show Admin rules upon connect, 1 if you do.", _, true, 0.0, true, 1.0);
	g_cCvarShowOnConnectDelay		= CreateConVar("sm_welcome_onconnect_delay", "2.1", "Delay in seconds, to start the welcome menu.Less than 1.0 disables.", _,true, 1.0);
	g_cCvarCommandAfterClosing		= CreateConVar("sm_welcome_after_closing", "guns", "Commando after closing the Welcome menu.Only on connection, leaving blank disables.");

	g_cCvarWelcomeCmd.GetString(g_sMenuTriggers ,sizeof(g_sMenuTriggers));
	g_iCvarShowOnConnectTimeout = g_cCvarShowOnConnectTimeout.IntValue;
	g_bCvarShowAdminRules = g_cCvarShowAdminRules.BoolValue;
	g_fCvarShowOnConnectDelay = g_cCvarShowOnConnectDelay.FloatValue;
	g_cCvarCommandAfterClosing.GetString(g_sCommandAfterClosing ,sizeof(g_sCommandAfterClosing));

	g_cCvarWelcomeCmd.AddChangeHook(OnConVarChanged);
	g_cCvarShowOnConnectTimeout.AddChangeHook(OnConVarChanged);
	g_cCvarShowAdminRules.AddChangeHook(OnConVarChanged);
	g_cCvarShowOnConnectDelay.AddChangeHook(OnConVarChanged);
	g_cCvarCommandAfterClosing.AddChangeHook(OnConVarChanged);

	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			OnClientPutInServer(i);
		}
	}

	AutoExecConfig(true, "Welcome_Rules");
	RegCmd();
}

public void OnConVarChanged(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	if (CVar == g_cCvarWelcomeCmd)
	{
		g_cCvarWelcomeCmd.GetString(g_sMenuTriggers ,sizeof(g_sMenuTriggers));
		RegCmd();
	}
	else if (CVar == g_cCvarShowOnConnectTimeout)
	{
		g_iCvarShowOnConnectTimeout = g_cCvarShowOnConnectTimeout.IntValue;
	}
	else if (CVar == g_cCvarShowAdminRules)
	{
		g_bCvarShowAdminRules = g_cCvarShowAdminRules.BoolValue;
	}
	else if (CVar == g_cCvarShowOnConnectDelay)
	{
		g_fCvarShowOnConnectDelay = g_cCvarShowOnConnectDelay.FloatValue;
	}
	else if (CVar == g_cCvarCommandAfterClosing)
	{
		g_cCvarCommandAfterClosing.GetString(g_sCommandAfterClosing ,sizeof(g_sCommandAfterClosing));
	}
}

void RegCmd()
{
	char sArrayCmds[WELCOME_MAX_CMDS][WELCOME_MAX_LENGTH];
	int iCmdCount = ExplodeString(g_sMenuTriggers, ",", sArrayCmds, sizeof(sArrayCmds), sizeof(sArrayCmds[]));

	for (int x = 0; x <= iCmdCount - 1; x++)
	{
		TrimString(sArrayCmds[x]);
		
		RegConsoleCmd(sArrayCmds[x], Command_Welcome);
	}
}

public void OnClientPutInServer(int client)
{
	CreateTimer(1.0, OnClientPutInServerPost, client);
}

public Action OnClientPutInServerPost(Handle PutTimer, int client)
{
	if(IsValidClient(client))
	{
		char sClLang[3];
		char sWelcomePath[PLATFORM_MAX_PATH];
		GetLanguageInfo(GetClientLanguage(client), sClLang, sizeof(sClLang));

		BuildPath(Path_SM, sWelcomePath, sizeof(sWelcomePath), "configs/Welcome_Rules/Welcome_%s.cfg" ,sClLang);
		if(!FileExists(sWelcomePath))
		BuildPath(Path_SM, sWelcomePath, sizeof(sWelcomePath), "configs/Welcome_Rules/Welcome_us.cfg");

		delete g_hkvWelcome[client];
		g_hkvWelcome[client] = new KeyValues("Welcome");
		FileToKeyValues(g_hkvWelcome[client], sWelcomePath);

		if (g_fCvarShowOnConnectDelay > 1.0)
		{
			g_iItemMenu[client] = 0;
			g_iMenuBackKey[client] = 0;
			g_bRemember[client] = false;
			CloseTimer(client);
			g_hSpawng_hTimer[client] = CreateTimer(g_fCvarShowOnConnectDelay, WelcomeMenuSpawn, client);
		}
	}
}

public void OnClientDisconnect(int client)
{
	if (client >= 1 && client < MaxClients && !IsFakeClient(client) && !IsClientSourceTV(client) && !IsClientReplay(client))
	{
		PrintToServer("Disconect");
		delete g_hkvWelcome[client];
		g_iItemMenu[client] = 0;
		g_iMenuBackKey[client] = 0;
		g_bRemember[client] = false;
		CloseTimer(client);
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

public Action Command_Welcome(int client, int arg)
{
	if (IsValidClient(client))
	{
		g_iItemMenu[client] = 0;
		g_iMenuBackKey[client] = 0;
		g_iLastSelection[client] = -1;
		CreateWelcomeMenu(client);
	}
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

void CreateWelcomeMenu(int client, char[] s_Intem = "", bool b_MenuItem = false, bool b_MenuSubItem = false, int i_Last = -1)
{
	if(!IsValidClient(client))
	{
		return;
	}

	char s_Wtitle[LENGTH_MIN_LINE];
	char s_ItemNumber[LENGTH_MIN_TEXT];
	char s_ItemName[LENGTH_MIN_LINE];
	char s_Line[LENGTH_MED_LINE];
	char s_Exec[LENGTH_MED_TEXT];
	char s_ExecButon[LENGTH_MIN_TEXT];

	Menu WelcomeMenu = new Menu(WelcomeMenuHandler);
	KvRewind(g_hkvWelcome[client]);

	if (b_MenuSubItem && !StrEqual(s_Intem, ""))
	{
		SetGlobalTransTarget(client);
		Format(s_ExecButon, sizeof(s_ExecButon), "%t", "To execute");
		IntToString(g_iMenuBackKey[client], s_ItemNumber, sizeof(s_ItemNumber));
		g_iItemMenu[client] = 2;
		if(KvJumpToKey(g_hkvWelcome[client], s_ItemNumber))
		{
			if(KvJumpToKey(g_hkvWelcome[client], "description"))
			{
				if(KvJumpToKey(g_hkvWelcome[client], s_Intem))
				{
					if(KvJumpToKey(g_hkvWelcome[client], "exec"))
					{
						KvGetString(g_hkvWelcome[client], "name", s_Wtitle, sizeof(s_Wtitle));
						KvGetString(g_hkvWelcome[client], "description", s_Line, sizeof(s_Line));
						KvGetString(g_hkvWelcome[client], "exec", s_Exec, sizeof(s_Exec), "LINEMISSING");

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
		if(KvJumpToKey(g_hkvWelcome[client], s_Intem))
		{
			KvGetSectionName(g_hkvWelcome[client], s_ItemNumber, sizeof(s_ItemNumber));
			KvGetString(g_hkvWelcome[client], "name", s_Wtitle, sizeof(s_Wtitle));
			g_iItemMenu[client] = 1;
			g_iMenuBackKey[client] = StringToInt(s_ItemNumber);

			WelcomeMenu.SetTitle("%s\n ", s_Wtitle);
			WelcomeMenu.ExitBackButton = true;

			if(KvJumpToKey(g_hkvWelcome[client], "description"))
			{
				if(KvGotoFirstSubKey(g_hkvWelcome[client]))
				{
					do
					{
						KvGetString(g_hkvWelcome[client], "line", s_Line, sizeof(s_Line), "LINEMISSING");
						if(StrEqual(s_Line, "LINEMISSING"))
						{
							KvGetSectionName(g_hkvWelcome[client], s_ItemNumber, sizeof(s_ItemNumber));
							KvJumpToKey(g_hkvWelcome[client], "exec");
							KvGetString(g_hkvWelcome[client], "name", s_Line, sizeof(s_Line), "LINEMISSING");
							WelcomeMenu.AddItem(s_ItemNumber, s_Line);
							KvGoBack(g_hkvWelcome[client]);
						}
						else
						{
							WelcomeMenu.AddItem("", s_Line, ITEMDRAW_DISABLED);
						}

					} while (KvGotoNextKey(g_hkvWelcome[client]));

					if(i_Last == -1) WelcomeMenu.Display(client, MENU_TIME_FOREVER);
					else WelcomeMenu.DisplayAt(client, (i_Last/GetMenuPagination(WelcomeMenu))*GetMenuPagination(WelcomeMenu), MENU_TIME_FOREVER);
				}
			}
		}
	}
	else
	{
		if (KvGotoFirstSubKey(g_hkvWelcome[client]))
		{
			g_iItemMenu[client] = 0;
			g_iMenuBackKey[client] = 0;
			Format(s_Wtitle, sizeof(s_Wtitle), "%t\n ", "Welcome menu title", client);
			WelcomeMenu.SetTitle(s_Wtitle);
			WelcomeMenu.ExitButton = true;

			do
			{
				KvGetSectionName(g_hkvWelcome[client], s_ItemNumber, sizeof(s_ItemNumber));
				KvGetString(g_hkvWelcome[client], "name", s_ItemName, sizeof(s_ItemName));
				WelcomeMenu.AddItem(s_ItemNumber, s_ItemName);
			}while (KvGotoNextKey(g_hkvWelcome[client]));

			if(i_Last == -1) WelcomeMenu.Display(client, g_iCvarShowOnConnectTimeout);
			else WelcomeMenu.DisplayAt(client, (i_Last/GetMenuPagination(WelcomeMenu))*GetMenuPagination(WelcomeMenu), MENU_TIME_FOREVER);
		}
	}
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
			g_iLastSelection[client] = itemNum;
			CreateWelcomeMenu(client, s_itemNum, true);
		}
		else if (g_iItemMenu[client] == 1)
		{
			g_iLastSelection[client] = itemNum;
			CreateWelcomeMenu(client, s_itemNum, false, true);
		}
		else if (g_iItemMenu[client] == 2)
		{
			if (IsValidClient(client))
			{
				FakeClientCommand(client, s_itemNum);
				g_iItemMenu[client] = 0;
				g_iMenuBackKey[client] = 0;
				g_iLastSelection[client] = -1;
				g_bRemember[client] = true;
				KvRewind(g_hkvWelcome[client]);
			}
		}
	}

	if (itemNum == MenuCancel_ExitBack)
	{
		if (g_iItemMenu[client] == 1)
		{
			CreateWelcomeMenu(client, _, _, _,g_iLastSelection[client]);
		}
		if (g_iItemMenu[client] == 2)
		{
			char s_temp[LENGTH_MIN_TEXT];
			IntToString(g_iMenuBackKey[client], s_temp, sizeof(s_temp));
			action = MenuAction_Select;
			CreateWelcomeMenu(client, s_temp, true, _,g_iLastSelection[client]);
		}
	}

	if (action == MenuAction_Cancel && itemNum != MenuCancel_ExitBack)
	{
		if (IsValidClient(client))
		{
			if(strlen(g_sCommandAfterClosing) != 0 && !g_bRemember[client])
			{
				FakeClientCommand(client, "say %s", g_sCommandAfterClosing);
				CPrintToChat(client, "%t", "WelcomeMenu End", client);
			}
			g_iItemMenu[client] = 0;
			g_iMenuBackKey[client] = 0;
			g_iLastSelection[client] = -1;
			KvRewind(g_hkvWelcome[client]);
		}
	}

	if (itemNum == MenuCancel_Exit)
	{
		g_bRemember[client] = true;
	}

	return 0 ;
}

public Action ShowMenu(int client,int args)
{
	Menu PlayersMenu = new Menu(ShowMenuHandler);

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
	}

	return 0 ;
}

stock bool IsValidClient(int client, bool bzrAllowBots = false, bool bzrAllowDead = true)
{
	if (!(1 <= client <= MaxClients) || !IsClientInGame(client) || (IsFakeClient(client) && !bzrAllowBots) || IsClientSourceTV(client) || IsClientReplay(client) || (!bzrAllowDead && !IsPlayerAlive(client)))
		return false;
	return true;
}