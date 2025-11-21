#include <amxmodx>
#include <cstrike>
#include <cromchat>
#include <incom_skins>
#include <incom_print>

new const PLUGIN[]       = "Incomsystem M4A1 Menu";
new const VERSION[]      = "2.3";
new const AUTHOR[]       = "Tonitaga"
new const SKIN_COMMAND[] = "say /skins-m4a1";

// Добавление в сборку скина XMas
#define XMAS_SKIN_ENABLE 0

new const Models_V[][] =
{
	"models/v_m4a1.mdl",

#if XMAS_SKIN_ENABLE == 1
	"models/incom/m4a1/xmas/v_m4a1.mdl",
#endif // XMAS_SKIN_ENABLE

    "models/incom/m4a1/incom/v_m4a1.mdl",
	"models/incom/m4a1/desolate_space/v_m4a1.mdl",
	"models/incom/m4a1/asiimov/v_m4a1.mdl",
	"models/incom/m4a1/chanticos_fire/v_m4a1.mdl",
	"models/incom/m4a1/dragon_king/v_m4a1.mdl",
	"models/incom/m4a1/golden_coil/v_m4a1.mdl",
	"models/incom/m4a1/hyper_beast/v_m4a1.mdl",
};

new const Models_P[][] =
{
	"models/p_m4a1.mdl",

#if XMAS_SKIN_ENABLE == 1
	"models/incom/m4a1/xmas/p_m4a1.mdl",
#endif // XMAS_SKIN_ENABLE

	"models/incom/m4a1/incom/p_m4a1.mdl",
	"models/incom/m4a1/desolate_space/p_m4a1.mdl",
	"models/incom/m4a1/asiimov/p_m4a1.mdl",
	"models/incom/m4a1/chanticos_fire/p_m4a1.mdl",
	"models/incom/m4a1/dragon_king/p_m4a1.mdl",
	"models/incom/m4a1/golden_coil/p_m4a1.mdl",
	"models/incom/m4a1/hyper_beast/p_m4a1.mdl",
};

new const ModelNames[][] =
{
    "M4A1 [DEFAULT]",

#if XMAS_SKIN_ENABLE == 1
	"M4A1 Christmas",
#endif // XMAS_SKIN_ENABLE

    "M4A1 INCOM",
    "M4A1 Desolate Space",
	"M4A1 Asiimov",
	"M4A1 Chanticos Fire",
	"M4A1 Dragon King",
	"M4A1 Golden Coil",
	"M4A1 Hyper Beast",
};

///> Handle базы данных
new Handle:g_DbHandle;

///> Название таблицы
new const TABLE_NAME[] = "m4a1";

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

public plugin_end()
{
	SQL_FreeHandle(g_DbHandle);
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
	new menu = menu_create("\y>>>>> \rM4A1 skin selection menu \y<<<<<^n \dby >>\rTonitaga\d<<", "IncomCase")
	
	menu_additem(menu, "M4A1 \r[DEFAULT]^n", "1", 0)

#if XMAS_SKIN_ENABLE == 1
    menu_additem(menu, "\yM4A1 \wChristmas", "100", 0);
#endif // XMAS_SKIN_ENABLE

    menu_additem(menu, "\yM4A1 \wIncom",          "2", 0)
    menu_additem(menu, "\yM4A1 \wDesolate Space", "3", 0)
    menu_additem(menu, "\yM4A1 \wAsiimov",        "4", 0)
    menu_additem(menu, "\yM4A1 \wChanticos Fire", "5", 0)
    menu_additem(menu, "\yM4A1 \wDragon King",    "6", 0)
    menu_additem(menu, "\yM4A1 \wGolden Coil",    "7", 0)
    menu_additem(menu, "\yM4A1 \wHyper Beast",    "8", 0)

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
	if(is_user_alive(id) && get_user_weapon(id) == CSW_M4A1) 
	{
		set_pev(id, pev_viewmodel2,   Models_V[SkinStorage[id]]);
		set_pev(id, pev_weaponmodel2, Models_P[SkinStorage[id]]);
	}
}

public LoadUserSkinHandle(failstate, Handle:query, error[], errcode, data[], size)
{
	if(failstate != TQUERY_SUCCESS)
	{
		log_amx("incom_skins_m4a1 error: %s", error);
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
