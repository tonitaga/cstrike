#include <amxmodx>
#include <cstrike>
#include <cromchat>
#include <incom_skins>

new const PLUGIN[]       = "Incomsystem USP Menu";
new const VERSION[]      = "2.1";
new const AUTHOR[]       = "Tonitaga"
new const SKIN_COMMAND[] = "say /skins-usp";

new const Models_V[][] =
{
	"models/v_usp.mdl",
	"models/incom/usp/kill_confirmed/v_usp.mdl",
	"models/incom/usp/neo_noir/v_usp.mdl",
	"models/incom/usp/fade/v_usp.mdl"
};

new const Models_P[][] =
{
	"models/p_usp.mdl",
	"models/incom/usp/kill_confirmed/p_usp.mdl",
	"models/incom/usp/neo_noir/p_usp.mdl",
	"models/incom/usp/fade/p_usp.mdl"
};

new const ModelNames[][] =
{
    "USP [DEFAULT]",
	"USP Kill Confirmed",
	"USP Neo Noir",
	"USP Fade",
};
///> Handle базы данных
new Handle:g_DbHandle;

///> Название таблицы
new const TABLE_NAME[] = "usp";

///> Индекс скина по умолчанию
new const DEFAULT_SKIN = 1; // "USP Kill Confirmed"

new SkinStorage[33];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	register_clcmd(SKIN_COMMAND,"IncomMenu");
	register_event("CurWeapon", "IncomChangeCurrentWeapon", "be", "1=1");
	
	g_DbHandle = IncomSkins_GetHandle();

	IncomSkins_CreateTable(g_DbHandle, TABLE_NAME);
}

public plugin_end()
{
	SQL_FreeHandle(g_DbHandle);
}

public plugin_precache() 
{
	for(new i; i < sizeof Models_V; i++) 
	{
		precache_model(Models_V[i]);
	}

	for(new i; i < sizeof Models_P; i++) 
	{
		precache_model(Models_P[i]);
	}
}

public client_putinserver(id)
{
	if(is_user_bot(id) || !is_user_connected(id))
		return;

	IncomSkins_LoadUserSkin(g_DbHandle, TABLE_NAME, id, "LoadUserSkinHandle");
}

public client_disconnected(id)
{
	if(is_user_bot(id))
		return;

	IncomSkins_SaveUserSkin(g_DbHandle, TABLE_NAME, id, SkinStorage[id]);
}

public IncomMenu(id)
{
	new menu = menu_create("\y>>>>> \rUSP skin selection menu \y<<<<<^n \dby >>\rTonitaga\d<<", "IncomCase")
	
	menu_additem(menu, "USP \r[DEFAULT]^n",      "1", 0)
	menu_additem(menu, "\yUSP \wKill Confirmed", "2", 0)
	menu_additem(menu, "\yUSP \wNeo Noir",       "3", 0)
	menu_additem(menu, "\yUSP \wFade",           "4", 0)

	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
	menu_display(id, menu, 0);
	
	return 1;
}

public IncomCase(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		return 1;
	}

	new nick[33];
	get_user_name(id, nick, 32);

	SkinStorage[id] = item;
	CC_SendMessage(id, "&x03%s &x01You Chouse &x04%s&x01", nick, ModelNames[item]);

	IncomSkins_SaveUserSkin(g_DbHandle, TABLE_NAME, id, SkinStorage[id]);
	
	menu_destroy(menu);
	return 1;
}

public IncomChangeCurrentWeapon(id) 
{
	if(get_user_weapon(id) == CSW_USP) 
	{
		set_pev(id, pev_viewmodel2,   Models_V[SkinStorage[id]]);
		set_pev(id, pev_weaponmodel2, Models_P[SkinStorage[id]]);
	}
}

public LoadUserSkinHandle(failstate, Handle:query, error[], errcode, data[], size)
{
	if(failstate != TQUERY_SUCCESS)
	{
		log_amx("incom_usp_skins error: %s", error);
		return;
	}
	
	new id = data[0];
	
	if(!is_user_connected(id))
		return;
	
	if(SQL_NumRows(query) > 0)
	{
		SkinStorage[id] = SQL_ReadResult(query, 0);
		
		if(SkinStorage[id] < 0 || SkinStorage[id] >= sizeof Models_V)
		{
			SkinStorage[id] = DEFAULT_SKIN;
		}
	}
	else
	{
		SkinStorage[id] = DEFAULT_SKIN;
		IncomSkins_SaveUserSkin(g_DbHandle, TABLE_NAME, id, SkinStorage[id]);
	}
}
