#include <sourcemod>
#include <colors_csgo>
#include <sdktools>
#include <basecomm>
#include <clientprefs>

#pragma semicolon 1
#pragma newdecls required

char Log[PLATFORM_MAX_PATH + 1];

bool g_bMessageChat[MAXPLAYERS + 1];
bool g_bBlockSound[MAXPLAYERS + 1];
bool g_bBlockMessages[MAXPLAYERS + 1];

Handle g_hBlockSound = INVALID_HANDLE;
Handle g_hBlockMessages = INVALID_HANDLE;

int g_iVictim[MAXPLAYERS + 1];

ConVar g_cLogMessage;

public Plugin myinfo = 
{
	name = "Private Messages", 
	author = "Nocky", 
	version = "1.0", 
	description = "Send a private messages to a players", 
	url = "https://steamcommunity.com/id/nockys"
};

public void OnPluginStart()
{
	g_cLogMessage = CreateConVar("sm_pm_logmessages", "1", "1 = Enabled / 0 = Disabled", 0, true, 0.0, true, 1.0);
	AutoExecConfig(true, "private_messages", "sourcemod");
	
	g_hBlockSound = RegClientCookie("pm_blocksound", "Players can disable/enable PM sound", CookieAccess_Private);
	g_hBlockMessages = RegClientCookie("pm_blockmessages", "Players can disable/enable private messages", CookieAccess_Private);
	
	BuildPath(Path_SM, Log, sizeof(Log), "logs/private_messages.log");
	LoadTranslations("privatemessages.phrases");
	
	RegConsoleCmd("sm_pm", PM_CMD);
	RegConsoleCmd("sm_posta", PM_CMD);
	RegConsoleCmd("sm_msg", PM_CMD);
	
	RegConsoleCmd("say_team", OnSayHook);
	RegConsoleCmd("say", OnSayHook);
	
	for (int i; ++i <= MaxClients; )
	{
		if (!IsClientInGame(i))
			continue;
		OnClientCookiesCached(i);
	}
}

public void OnMapStart()
{
	AddFileToDownloadsTable("sound/nocky/privatemessage.mp3");
	PrecacheSound("nocky/privatemessage.mp3", true);
}

public void OnClientPutInServer(int client)
{
	if (IsFakeClient(client))
		return;
	
	g_iVictim[client] = -1;
	g_bMessageChat[client] = false;
}

public void OnClientCookiesCached(int client)
{
	char Value[8];
	GetClientCookie(client, g_hBlockSound, Value, sizeof(Value));
	GetClientCookie(client, g_hBlockMessages, Value, sizeof(Value));
	
	g_bBlockSound[client] = view_as<bool>(StringToInt(Value));
	g_bBlockMessages[client] = view_as<bool>(StringToInt(Value));
}

public Action PM_CMD(int client, int args)
{
	if (IsValidClient(client))
	{
		PM_Menu(client);
	}
}

void PM_Menu(int client)
{
	static char Text[128];
	
	Menu menu = new Menu(PM_MenuHandler);
	
	FormatEx(Text, sizeof(Text), "%T\n ", "Menu Title", client);
	menu.SetTitle(Text);
	
	FormatEx(Text, sizeof(Text), "%T", "Send a message", client);
	menu.AddItem("0", Text);
	FormatEx(Text, sizeof(Text), "%T", "Settings", client);
	menu.AddItem("1", Text);
	
	menu.ExitBackButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int PM_MenuHandler(Menu menu, MenuAction action, int client, int clicked)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (clicked)
			{
				case 0:
				{
					if (!BaseComm_IsClientGagged(client))
					{
						if (!g_bBlockMessages[client])
						{
							ChoosePlayerMenu(client);
						}
						else
						{
							CPrintToChat(client, "%t %t", "Prefix", "You must have enabled private messages");
						}
					}
					else
					{
						CPrintToChat(client, "%t %t", "Prefix", "You have active gag");
					}
				}
				case 1 : PMSetting_Menu(client);
			}
		}
		case MenuAction_End:
		{
			menu.Close();
		}
	}
}

void PMSetting_Menu(int client)
{
	static char Text[128];
	
	Menu menu = new Menu(PMSetting_MenuHandler);
	
	FormatEx(Text, sizeof(Text), "%T\n ", "Settings Menu Title", client);
	menu.SetTitle(Text);
	
	if (!g_bBlockMessages[client])
	{
		FormatEx(Text, sizeof(Text), "%T", "Message blocking OFF", client);
		menu.AddItem("0", Text);
	}
	else
	{
		FormatEx(Text, sizeof(Text), "%T", "Message blocking ON", client);
		menu.AddItem("0", Text);
	}
	if (!g_bBlockSound[client])
	{
		FormatEx(Text, sizeof(Text), "%T", "Message sounds ON", client);
		menu.AddItem("1", Text);
	}
	else
	{
		FormatEx(Text, sizeof(Text), "%T", "Message sounds OFF", client);
		menu.AddItem("1", Text);
	}
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int PMSetting_MenuHandler(Menu menu, MenuAction action, int client, int clicked)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (clicked)
			{
				case 0:
				{
					if (g_bBlockMessages[client])
					{
						g_bBlockMessages[client] = false;
						PMSetting_Menu(client);
						CPrintToChat(client, "%t %t", "Prefix", "Settings blocking msg on");
						
						SetClientCookie(client, g_hBlockSound, "0");
					}
					else
					{
						g_bBlockMessages[client] = true;
						PMSetting_Menu(client);
						CPrintToChat(client, "%t %t", "Prefix", "Settings blocking msg off");
						
						SetClientCookie(client, g_hBlockSound, "1");
					}
				}
				case 1:
				{
					if (g_bBlockSound[client])
					{
						g_bBlockSound[client] = false;
						PMSetting_Menu(client);
						CPrintToChat(client, "%t %t", "Prefix", "Settings blocking sound on");
						
						SetClientCookie(client, g_hBlockSound, "0");
					}
					else
					{
						g_bBlockSound[client] = true;
						PMSetting_Menu(client);
						CPrintToChat(client, "%t %t", "Prefix", "Settings blocking sound off");
						
						SetClientCookie(client, g_hBlockSound, "1");
					}
				}
			}
		}
		case MenuAction_Cancel:
		{
			if (clicked == MenuCancel_ExitBack)
			{
				PM_Menu(client);
			}
		}
		case MenuAction_End:
		{
			menu.Close();
		}
	}
}

public Action ChoosePlayerMenu(int client)
{
	static char Text[128];
	Handle hMenu = CreateMenu(SelectPlayerHandler);
	
	for (int i; ++i <= MaxClients; )
	{
		if (i == client || !IsClientInGame(i) || IsFakeClient(i))
			continue;
		
		char UID[13];
		char Username[MAX_TARGET_LENGTH];
		
		GetClientName(i, Username, sizeof(Username));
		IntToString(GetClientUserId(i), UID, sizeof(UID));
		
		AddMenuItem(hMenu, UID, Username);
	}
	
	if (GetMenuItemCount(hMenu) > 0)
	{
		SetMenuExitBackButton(hMenu, false);
		SetMenuExitButton(hMenu, true);
		FormatEx(Text, sizeof(Text), "%T\n ", "Choose a player", client);
		SetMenuTitle(hMenu, Text);
		
		DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
		return Plugin_Handled;
	}
	
	CloseHandle(hMenu);
	CPrintToChat(client, "%t %t", "Prefix", "No available players");
	return Plugin_Handled;
}

public int SelectPlayerHandler(Handle hMenu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:CloseHandle(hMenu);
		case MenuAction_Select:
		{
			char UID[13];
			GetMenuItem(hMenu, param2, UID, sizeof(UID));
			
			int iUID = GetClientOfUserId(StringToInt(UID));
			if (!iUID)
			{
				CPrintToChat(param1, "%t %t", "Prefix", "Player no longer available");
				return;
			}
			
			g_iVictim[param1] = GetClientUserId(iUID);
			HookChatMessage(param1);
		}
	}
}

void SendMessage(int client, int victim, const char[] Message)
{
	char VictimSID[30], ClientSID[30];
	GetClientAuthId(client, AuthId_Steam2, ClientSID, sizeof(ClientSID));
	GetClientAuthId(victim, AuthId_Steam2, VictimSID, sizeof(VictimSID));
	
	if (!g_bBlockMessages[victim])
	{
		CPrintToChat(client, "%t %t", "Prefix", "PM Format client", victim, Message);
		if (!g_bBlockSound[client])
		{
			ClientCommand(client, "play nocky/privatemessage.mp3");
		}
		
		CPrintToChat(victim, "%t %t", "Prefix", "PM Format victim", client, Message);
		if (!g_bBlockSound[victim])
		{
			ClientCommand(victim, "play nocky/privatemessage.mp3");
		}
		
		g_bMessageChat[client] = false;
		g_iVictim[client] = -1;
		
		if (g_cLogMessage.BoolValue)
		{
			LogToFile(Log, "[%N (%s)] -> [%N (%s)]: %s", client, ClientSID, victim, VictimSID, Message);
		}
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (i == victim || i == client)
			{  }
			else
			{
				if (CheckCommandAccess(i, "", ADMFLAG_KICK))
				{
					CPrintToChat(i, "%t {red}%N {blue}-> {yellow}%N{default}: %s", "Admin Spy", client, victim, Message);
				}
			}
		}
	}
	else
	{
		CPrintToChat(client, "%t %t", "Prefix", "Player have disable disabled PM", victim);
		g_bMessageChat[client] = false;
		g_iVictim[client] = -1;
	}
}

public Action OnSayHook(int client, int args)
{
	if (!client || !g_bMessageChat[client])
	{
		return Plugin_Continue;
	}
	
	if (!(g_iVictim[client] = GetClientOfUserId(g_iVictim[client])))
	{
		CPrintToChat(client, "%t %t", "Prefix", "Player no longer available");
		
		g_bMessageChat[client] = false;
		g_iVictim[client] = -1;
		return Plugin_Handled;
	}
	
	char Message[256];
	
	if (args == 1)
	{
		GetCmdArg(1, Message, sizeof(Message));
	}
	else
	{
		GetCmdArgString(Message, sizeof(Message));
	}
	
	if (!strcmp(Message, "!cancel"))
	{
		CPrintToChat(client, "%t %t", "Prefix", "Message cancled");
		g_bMessageChat[client] = false;
		g_iVictim[client] = -1;
		return Plugin_Handled;
	}
	
	SendMessage(client, g_iVictim[client], Message);
	return Plugin_Handled;
}

void HookChatMessage(int client)
{
	g_bMessageChat[client] = true;
	CPrintToChat(client, "%t %t", "Prefix", "Chat message");
}

bool IsValidClient(int client, bool botz = true)
{
	if (!(1 <= client <= MaxClients) || !IsClientInGame(client) || !IsClientConnected(client) || botz && IsFakeClient(client) || IsClientSourceTV(client))
		return false;
	
	return true;
}
