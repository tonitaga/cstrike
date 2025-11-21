#include <amxmodx>
#include <cstrike>
#include <cromchat>
#include <incom_skins>
#include <incom_print>

new const PLUGIN[]       = "Incomsystem AK47 Menu";
new const VERSION[]      = "2.3";
new const AUTHOR[]       = "Tonitaga"
new const SKIN_COMMAND[] = "say /skins-ak47";

// Добавление в сборку скина XMas
#define XMAS_SKIN_ENABLE 0

new const Models_V[][] =
{
	"models/v_ak47.mdl",

#if XMAS_SKIN_ENABLE == 1
	"models/incom/ak47/xmas/v_ak47.mdl",
#endif // XMAS_SKIN_ENABLE

    "models/incom/ak47/incom/v_ak47.mdl",
	"models/incom/ak47/fire_serpent/v_ak47.mdl",
	"models/incom/ak47/bloodsport/v_ak47.mdl",
	"models/incom/ak47/the_empress/v_ak47.mdl",
	"models/incom/ak47/fuel_injector/v_ak47.mdl",
	"models/incom/ak47/vulcan/v_ak47.mdl",
	"models/incom/ak47/elite_build/v_ak47.mdl"
};

new const Models_P[][] =
{
	"models/p_ak47.mdl",

#if XMAS_SKIN_ENABLE == 1
	"models/incom/ak47/xmas/p_ak47.mdl",
#endif // XMAS_SKIN_ENABLE

    "models/incom/ak47/incom/p_ak47.mdl",
	"models/incom/ak47/fire_serpent/p_ak47.mdl",
	"models/incom/ak47/bloodsport/p_ak47.mdl",
	"models/incom/ak47/the_empress/p_ak47.mdl",
	"models/incom/ak47/fuel_injector/p_ak47.mdl",
	"models/incom/ak47/vulcan/p_ak47.mdl",
	"models/incom/ak47/elite_build/p_ak47.mdl"
};

new const ModelNames[][] =
{
    "AK47 [DEFAULT]",

#if XMAS_SKIN_ENABLE == 1
	"AK47 Christmas",
#endif // XMAS_SKIN_ENABLE

    "AK47 INCOM",
	"AK47 Fire Serpent",
	"AK47 Bloodsport",
	"AK47 The Empress",
	"AK47 Fuel Injector",
	"AK47 Vulcan",
	"AK47 Elite Build",
};

///> Handle базы данных
new Handle:g_DbHandle;

///> Название таблицы
new const TABLE_NAME[] = "ak47";

///> Индекс скина по умолчанию
new const DEFAULT_SKIN = 1;

new SkinStorage[33];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	register_clcmd(SKIN_COMMAND,"IncomMenu");
	register_event("CurWeapon", "IncomChangeCurrentWeapon", "be", "1=1");
	
	g_DbHandle = IncomSkins_GetHandle();

	IncomSkins_CreateTable(g_DbHandle, TABLE_NAME);

	register_dictionary("incom_skins.txt");
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
	new menu = menu_create("\y>>>>> \rAK47 skin selection menu \y<<<<<^n \dby >>\rTonitaga\d<<", "IncomCase")

	menu_additem(menu, "AK47 \r[DEFAULT]^n", "1", 0)

#if XMAS_SKIN_ENABLE == 1
    menu_additem(menu, "\yAK47 \wChristmas", "100", 0);
#endif // XMAS_SKIN_ENABLE
	
	menu_additem(menu, "\yAK47 \wIncom",         "2", 0)
	menu_additem(menu, "\yAK47 \wFire Serpent",  "3", 0)
	menu_additem(menu, "\yAK47 \wBloodsport",    "4", 0)
	menu_additem(menu, "\yAK47 \wThe Empress",   "5", 0)
	menu_additem(menu, "\yAK47 \wFuel Injector", "6", 0)
	menu_additem(menu, "\yAK47 \wVulcan",        "7", 0)
	menu_additem(menu, "\yAK47 \wElite Build",   "8", 0)

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

	SkinStorage[id] = item;
	IncomPrint_Client(id, "[%L] %L", id, "INCOM_SKINS", id, "SKIN_SELECTED", ModelNames[item]);

	IncomSkins_SaveUserSkin(g_DbHandle, TABLE_NAME, id, SkinStorage[id]);
	IncomChangeCurrentWeapon(id);
	
	menu_destroy(menu);
	return 1;
}

public IncomChangeCurrentWeapon(id) 
{
	if(is_user_alive(id) && get_user_weapon(id) == CSW_AK47) 
	{
		set_pev(id, pev_viewmodel2,   Models_V[SkinStorage[id]]);
		set_pev(id, pev_weaponmodel2, Models_P[SkinStorage[id]]);
	}
}

public LoadUserSkinHandle(failstate, Handle:query, error[], errcode, data[], size)
{
	if(failstate != TQUERY_SUCCESS)
	{
		log_amx("incom_skins_ak47 error: %s", error);
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
