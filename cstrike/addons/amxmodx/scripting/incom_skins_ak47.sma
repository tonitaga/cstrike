#include <amxmodx>
#include <cstrike>
#include <cromchat>

new const PLUGIN[]       = "Incomsystem AK47 Menu";
new const VERSION[]      = "2.0";
new const AUTHOR[]       = "Tonitaga"
new const SKIN_COMMAND[] = "say /skins-ak47";

new const Models_V[][] =
{
	"models/v_ak47.mdl",
	"models/incom/ak47/fire_serpent/v_ak47.mdl",
	"models/incom/ak47/bloodsport/v_ak47.mdl",
	"models/incom/ak47/the_empress/v_ak47.mdl",
	"models/incom/ak47/fuel_injector/v_ak47.mdl",
	"models/incom/ak47/vulcan/v_ak47.mdl",
	"models/incom/ak47/elite_build/v_ak47.mdl",
    "models/incom/ak47/incom/v_ak47.mdl"
};

new const Models_P[][] =
{
	"models/p_ak47.mdl",
	"models/incom/ak47/fire_serpent/p_ak47.mdl",
	"models/incom/ak47/bloodsport/p_ak47.mdl",
	"models/incom/ak47/the_empress/p_ak47.mdl",
	"models/incom/ak47/fuel_injector/p_ak47.mdl",
	"models/incom/ak47/vulcan/p_ak47.mdl",
	"models/incom/ak47/elite_build/p_ak47.mdl",
    "models/incom/ak47/incom/p_ak47.mdl"
};

new const ModelNames[][] =
{
    "AK47 [DEFAULT]",
	"AK47 Fire Serpent",
	"AK47 Bloodsport",
	"AK47 The Empress",
	"AK47 Fuel Injector",
	"AK47 Vulcan",
	"AK47 Elite Build",
    "AK47 INCOM"
};

new SkinStorage[33];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	register_clcmd(SKIN_COMMAND,"IncomMenu");
	register_event("CurWeapon", "IncomChangeCurrentWeapon", "be", "1=1");
}

public client_putinserver(id)
{
	SkinStorage[id] = 1; // "AK47 Fire Serpent"
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

public IncomMenu(id)
{
	new menu = menu_create("\y>>>>> \rAK47 skin selection menu \y<<<<<^n \dby >>\rTonitaga\d<<", "IncomCase")
	
	menu_additem(menu, "AK47 \r[DEFAULT]^n",     "1", 0)
	menu_additem(menu, "\yAK47 \wFire Serpent",  "2", 0)
	menu_additem(menu, "\yAK47 \wBloodsport",    "3", 0)
	menu_additem(menu, "\yAK47 \wThe Empress",   "4", 0)
	menu_additem(menu, "\yAK47 \wFuel Injector", "5", 0)
	menu_additem(menu, "\yAK47 \wVulcan",        "6", 0)
	menu_additem(menu, "\yAK47 \wElite Build",   "7", 0)
    menu_additem(menu, "\yAK47 \wIncom",   "8", 0)

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
	
	menu_destroy(menu);
	return 1;
}

public IncomChangeCurrentWeapon(id) 
{
	if(get_user_weapon(id) == CSW_AK47) 
	{
		set_pev(id, pev_viewmodel2,   Models_V[SkinStorage[id]]);
		set_pev(id, pev_weaponmodel2, Models_P[SkinStorage[id]]);
	}
}
