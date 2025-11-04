#include <amxmodx>
#include <cstrike>
#include <cromchat>
#include <incom_skins>

new const PLUGIN[]       = "Incomsystem Knife Menu";
new const VERSION[]      = "2.1";
new const AUTHOR[]       = "Tonitaga"
new const SKIN_COMMAND[] = "say /skins-knife";

new const Models_V[][] =
{
	"models/v_knife.mdl",

	// Ножи Karambit
	"models/incom/knife/karambit/lore/v_knife.mdl",
	"models/incom/knife/karambit/doppler_emerald/v_knife.mdl",
	"models/incom/knife/karambit/fade/v_knife.mdl",

	// Ножи Butterfly
	"models/incom/knife/butterfly/fade/v_knife.mdl",
	"models/incom/knife/butterfly/crimson_web/v_knife.mdl",

	// Ножи Bayonet
	"models/incom/knife/bayonet/lore/v_knife.mdl",
	"models/incom/knife/bayonet/chang_specialist/v_knife.mdl",

	// Ножи Skeleton
	"models/incom/knife/skeleton/fade/v_knife.mdl",
	"models/incom/knife/skeleton/crimson_web/v_knife.mdl",
	"models/incom/knife/skeleton/case_hardened/v_knife.mdl",
}

new const ModelNames[][] =
{
    "Knife [DEFAULT]",

	// Ножи Karambit
	"Knife Karambit Lore",
	"Knife Karambit Doppler Emerald",
	"Knife Karambit Fade",

	// Ножи Butterfly
	"Knife Butterfly Fade",
	"Knife Butterfly Crimson Web",

	// Ножи Bayonet
	"Knife Bayonet Lore",
	"Knife Bayonet Chang Specialist",

	// Ножи Skeleton
	"Knife Skeleton Fade",
	"Knife Skeleton Crimson Web",
	"Knife Skeleton Case Hardened"
};

///> Handle базы данных
new Handle:g_DbHandle;

///> Название таблицы
new const TABLE_NAME[] = "knife";

///> Индекс скина по умолчанию
new const DEFAULT_SKIN = 8; // "Knife Bayonet Chang Specialist"

new SkinStorage[33];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	register_clcmd(SKIN_COMMAND,"IncomMenu");
	register_event("CurWeapon", "IncomChangeCurrentWeapon", "be", "1=1");

	g_DbHandle = IncomSkins_GetHandle();

	IncomSkins_CreateTable(g_DbHandle, TABLE_NAME);
}

public plugin_precache() 
{
	for(new i; i < sizeof Models_V; i++) 
	{
		precache_model(Models_V[i]);
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
	new menu = menu_create("\y>>>>> \rKnife skin selection menu \y<<<<<^n \dby >>\rTonitaga\d<<", "IncomCase")
	
	menu_additem(menu, "Knife \r[DEFAULT]^n",                "1", 0)

	// Ножи Karambit
	menu_additem(menu, "\yKnife \wKarambit Lore",            "2", 0)
	menu_additem(menu, "\yKnife \wKarambit Doppler Emerald", "3", 0)
	menu_additem(menu, "\yKnife \wKarambit Fade",            "4", 0)

	// Ножи Butterfly
	menu_additem(menu, "\yKnife \wButterfly Fade",        "100", 0)
	menu_additem(menu, "\yKnife \wButterfly Crimson Web", "101", 0)

	// Ножи Bayonet
	menu_additem(menu, "\yKnife \wBayonet Lore",             "200", 0)
	menu_additem(menu, "\yKnife \wBayonet Chang Specialist", "201", 0)

	// Ножи Skeleton
	menu_additem(menu, "\yKnife \wSkeleton Fade",          "300", 0)
	menu_additem(menu, "\yKnife \wSkeleton Crimson Web",   "301", 0)
	menu_additem(menu, "\yKnife \wSkeleton Case Hardened", "302", 0)

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
	if(get_user_weapon(id) == CSW_KNIFE) 
	{
		set_pev(id, pev_viewmodel2, Models_V[SkinStorage[id]]);
	}
}

public LoadUserSkinHandle(failstate, Handle:query, error[], errcode, data[], size)
{
	if(failstate != TQUERY_SUCCESS)
	{
		log_amx("incom_skins_knife error: %s", error);
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
