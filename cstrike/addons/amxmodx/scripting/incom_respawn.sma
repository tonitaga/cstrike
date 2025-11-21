#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <hamsandwich>
#include <fakemeta>
#include <engine>
#include <fun>
#include <parse_color>
#include <incom_print>
#include <reapi>

#define PLUGIN  "Incomsystem Respawn"
#define VERSION "1.5.0"
#define AUTHOR  "Tonitaga"

#define WEAPONS_COMMAND          "/weapons"
#define WEAPONS_COMMAND_SAY      "say /weapons"
#define WEAPONS_COMMAND_SAY_TEAM "say_team /weapons"

#define KEY_ENABLED                "amx_incom_respawn_enable"
#define KEY_GODMODE_TIME           "amx_incom_respawn_godmode"
#define KEY_RESPAWN_TIME           "amx_incom_respawn_time"
#define KEY_WEAPONS_CHOOSE_ENABLED "amx_incom_respawn_weapons_choose_enable"
#define KEY_GLOW_COLOR             "amx_incom_respawn_glow_color"
#define KEY_HUD_COLOR              "amx_incom_respawn_hud_color"
#define KEY_ENABLE_HUD             "amx_incom_respawn_enable_hud"
#define KEY_RANDOM_WEAPONS_ENABLED "amx_incom_respawn_random_weapons_enable"


#define UNDEFINED_SET   0
#define AK47_DEAGLE_SET 1
#define M4A1_DEAGLE_SET 2
#define AWP_DEAGLE_SET  3
#define RANDOM_SET      4

new const SET_STRINGS[][] =
{
	"0", // UNDEFINED_SET
	"1", // AK47_DEAGLE_SET
	"2", // M4A1_DEAGLE_SET
	"3", // AWP_DEAGLE_SET
	"4"  // RANDOM_SET
};

///> Количество патронов
new const AMMO_COUNT = 210

#define DEFAULT_ENABLED                "0"
#define DEFAULT_GODMODE_TIME           "3.0"
#define DEFAULT_RESPAWN_TIME           "1.0"
#define DEFAULT_WEAPONS_CHOOSE_ENABLED "1"
#define DEFAULT_GLOW_COLOR             "255215000"
#define DEFAULT_HUD_COLOR              "000255255"
#define DEFAULT_ENABLE_HUD             "1"
#define DEFAULT_RANDOM_WEAPONS_ENABLED "0"

new g_RespawnEnabled;
new g_GodmodeTime;
new g_RespawnTime;
new g_WeaponsChooseEnabled;
new g_GlowColor;
new g_HUDColor;
new g_HUDEnabled;
new g_RandomWeaponsEnabled;

new g_GodmodeTaskOffset = 1000; // Базовый оффсет для задач неуязвимости
new g_NotifyAboutWeaponSelectTaskId = 12472;

new g_SelectedWeaponsStorage[33];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	register_event("DeathMsg", "OnPlayerDeath", "a");
	register_clcmd("joinclass", "OnAgentChoose");

	register_clcmd(WEAPONS_COMMAND_SAY,      "MakeShowWeaponsMenuTask");
	register_clcmd(WEAPONS_COMMAND_SAY_TEAM, "MakeShowWeaponsMenuTask");

	set_task(120.0, "NotifyAboutWeaponSelect", g_NotifyAboutWeaponSelectTaskId, .flags = "b");

	RegisterHam(Ham_TakeDamage, "player", "OnPlayerTakeDamage");
	RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn");

	register_dictionary("incom_respawn.txt");
}

public plugin_cfg()
{
	g_RespawnEnabled       = create_cvar(KEY_ENABLED, DEFAULT_ENABLED, _, "Статус плагина^n0 - Отключен^n1 - Включен", true, 0.0, true, 1.0);
	g_GodmodeTime          = create_cvar(KEY_GODMODE_TIME, DEFAULT_GODMODE_TIME, _, "Длительность режима бога после возрождения", true, 0.0, true, 10.0);
	g_RespawnTime          = create_cvar(KEY_RESPAWN_TIME, DEFAULT_RESPAWN_TIME, _, "Задержка респавна после смерти", true, 0.0, true, 10.0);
	g_WeaponsChooseEnabled = create_cvar(KEY_WEAPONS_CHOOSE_ENABLED, DEFAULT_WEAPONS_CHOOSE_ENABLED, _, "Включить возможность выбора оружия^n0 - Отключен^n1 - Включен", true, 0.0, true, 1.0);
	g_GlowColor            = create_cvar(KEY_GLOW_COLOR, DEFAULT_GLOW_COLOR, _, "Цвет свечения игрока в режиме бога");
	g_HUDColor             = create_cvar(KEY_HUD_COLOR, DEFAULT_HUD_COLOR, _, "Цвет HUD сообщений");
	g_HUDEnabled           = create_cvar(KEY_ENABLE_HUD, DEFAULT_ENABLE_HUD, _, "Отображение информации на HUD^n0 - Отключен^n1 - Включен", true, 0.0, true, 1.0);
	g_RandomWeaponsEnabled = create_cvar(KEY_RANDOM_WEAPONS_ENABLED, DEFAULT_RANDOM_WEAPONS_ENABLED, _, "Включить случайную выдачу оружия^n0 - Отключен^n1 - Включен", true, 0.0, true, 1.0);

	hook_cvar_change(g_RespawnEnabled,       "OnRespawnEnabledChanged");
	hook_cvar_change(g_RandomWeaponsEnabled, "OnRandomWeaponsEnabledChanged");

	AutoExecConfig();
}

public client_connect(playerId)
{
	g_SelectedWeaponsStorage[playerId] = UNDEFINED_SET;
}

public OnAgentChoose(playerId)
{
	if (get_pcvar_num(g_RespawnEnabled))
	{
		new playerData[1];
		playerData[0] = playerId;

		new Float:respawnAfter = get_pcvar_float(g_RespawnTime);
		set_task(respawnAfter, "RespawnPlayerTask", playerId, playerData, sizeof(playerData))
	}
}

public OnRespawnEnabledChanged(cvar, const old_value[], const new_value[])
{
	new oldVal = str_to_num(old_value);
	new newVal = str_to_num(new_value);

	if (oldVal == 0 && newVal == 1)
	{
		set_cvar_num("amx_incom_weapons_delete_enable", 1);
		set_cvar_num("amx_incom_kill_streak_reward_enable", 1);
		set_cvar_float("amx_incom_weapons_delete_time", 5.0);
		set_cvar_float("amx_incom_respawn_time", 1.0);

		IncomPrint_Client(0, "[%L] %L", 0, "INCOM_RESPAWN", 0, "TEAM_DM_ENABLE");
		server_cmd("sv_restart 1");
	}
	else if (oldVal == 1 && newVal == 0)
	{
		set_cvar_num("amx_incom_weapons_delete_enable", 0);
		set_cvar_num("amx_incom_kill_streak_reward_enable", 0);
		
		// Останавливаем все задачи и выключаем godmode
		new players[32], count;
		get_players(players, count);
		
		for (new i = 0; i < count; i++)
		{
			new playerId = players[i];

			if (task_exists(g_GodmodeTaskOffset + playerId))
			{
				remove_task(g_GodmodeTaskOffset + playerId);
			}

			if (is_user_connected(playerId))
			{
				StopGodmodeEffects(playerId);
				SetGodmode(playerId, false);
			}
		}

		IncomPrint_Client(0, "[%L] %L", 0, "INCOM_RESPAWN", 0, "TEAM_DM_DISABLE");
		server_cmd("sv_restart 1");
	}
}

public OnRandomWeaponsEnabledChanged(cvar, const old_value[], const new_value[])
{
	if (get_pcvar_num(g_RespawnEnabled))
	{
		new oldVal = str_to_num(old_value);
		new newVal = str_to_num(new_value);

		if (newVal == oldVal)
		{
			return;
		}

		if (oldVal == 0 && newVal == 1)
		{
			IncomPrint_Client(0, "[%L] %L", 0, "INCOM_RESPAWN", 0, "RANDOM_WEAPONS_ENABLE");
		}
		else if (oldVal == 1 && newVal == 0)
		{
			IncomPrint_Client(0, "[%L] %L", 0, "INCOM_RESPAWN", 0, "RANDOM_WEAPONS_DISABLE");
		}

		GiveWeaponsToAllPlayers();
	}
}

public NotifyAboutWeaponSelect()
{
	if (get_pcvar_num(g_RespawnEnabled) && get_pcvar_num(g_WeaponsChooseEnabled) && !get_pcvar_num(g_RandomWeaponsEnabled))
	{
		IncomPrint_Client(0, "[%L] %L", 0, "INCOM_RESPAWN", 0, "WEAPONS_NOTIFY", WEAPONS_COMMAND);
	}
}

public OnPlayerDeath()
{
	if (get_pcvar_num(g_RespawnEnabled))
	{
		new deadPlayerId = read_data(2);

		new playerData[1];
		playerData[0] = deadPlayerId;

		new Float:respawnAfter = get_pcvar_float(g_RespawnTime);
		set_task(respawnAfter, "RespawnPlayerTask", deadPlayerId, playerData, sizeof(playerData));
	}
}

public RespawnPlayerTask(playerData[])
{
	new playerId = playerData[0];

	if (!is_user_connected(playerId))
		return;
	
	if (is_user_alive(playerId) || cs_get_user_team(playerId) == CS_TEAM_SPECTATOR)
		return;
	
	ExecuteHamB(Ham_CS_RoundRespawn, playerId);

	if (is_user_alive(playerId))
	{
		SetGodmode(playerId, true);

		new Float:godmodeDuration = get_pcvar_float(g_GodmodeTime);
		
		new godmodeData[1];
		godmodeData[0] = playerId;
		set_task(godmodeDuration, "RemoveGodmodeTask", g_GodmodeTaskOffset + playerId, godmodeData, sizeof(godmodeData));
		
		StartGodmodeEffects(playerId);

		if (get_pcvar_num(g_HUDEnabled))
		{
			ShowHudMessage(playerId, "Вы неуязвимы", godmodeDuration)
		}

		GiveWeapons(playerId);
	}
	else
	{
		new authId[35];
		get_user_authid(playerId, authId, charsmax(authId));

		server_print("[incom_respawn][warning] Failed to restart player with authID '%s'! Trying again", authId);
		set_task(0.5, "RespawnPlayerTask", playerId, playerData, 1);
	}
}

public OnPlayerSpawn(playerId)
{
	if (get_pcvar_num(g_RespawnEnabled) && is_user_alive(playerId))
	{
		if (!get_pcvar_num(g_RandomWeaponsEnabled) && !g_SelectedWeaponsStorage[playerId] == RANDOM_SET)
		{
			GiveWeapons(playerId);
		}
	}
}

public RemoveGodmodeTask(godmodeData[])
{
	new playerId = godmodeData[0];
	
	if (is_user_connected(playerId) && is_user_alive(playerId))
	{
		SetGodmode(playerId, false);
		StopGodmodeEffects(playerId);
	}
}

public OnPlayerTakeDamage(victim, inflictor, attacker, Float:damage, damageBits)
{
	if (!is_user_connected(victim) || !is_user_alive(victim))
		return HAM_IGNORED;

	if (task_exists(g_GodmodeTaskOffset + victim))
	{
		// Блокируем урон
		SetHamParamFloat(4, 0.0); // Устанавливаем урон в 0
		return HAM_SUPERCEDE;
	}
	
	return HAM_IGNORED;
}

stock ShowHudMessage(id, const message[], Float:durationOnScreen)
{
	if (!is_user_connected(id))
		return;

	new hudColorStr[32], Float:hudColor[3];
	get_pcvar_string(g_HUDColor, hudColorStr, charsmax(hudColorStr));
	ParseColor_RGB(hudColorStr, hudColor);

	set_hudmessage(
		floatround(hudColor[0]),
		floatround(hudColor[1]),
		floatround(hudColor[2]),
		-1.0, 0.3, 0, 6.0, durationOnScreen
	);

	show_hudmessage(id, message);
}

stock ClearHudMessages(id)
{
	if (!is_user_connected(id))
		return;
	
	// Показываем пустое сообщение на всех каналах
	for (new i = 1; i <= 4; i++)
	{
		set_hudmessage(0, 0, 0, 0.0, 0.0, 0, 0.0, 0.0, 0.0, 0.0, i);
		show_hudmessage(id, "");
	}
}

stock SetGodmode(playerId, bool:godmodeEnabled)
{
	if (godmodeEnabled)
	{
		set_pev(playerId, pev_takedamage, DAMAGE_NO);
	}
	else
	{
		set_pev(playerId, pev_takedamage, DAMAGE_AIM);
	}
}

stock StartGodmodeEffects(playerId)
{
	// Получаем цвет из параметра
	new glowColorStr[32], Float:glowColor[3];
	get_pcvar_string(g_GlowColor, glowColorStr, charsmax(glowColorStr));
	ParseColor_RGB(glowColorStr, glowColor);
	
	// Подсветка игрока
	set_pev(playerId, pev_renderfx, kRenderFxGlowShell);
	set_pev(playerId, pev_rendercolor, glowColor);
	set_pev(playerId, pev_renderamt, 25.0);
	
	// Подсветка оружия
	new weaponEnt = get_pdata_cbase(playerId, 373, 5); // m_pActiveItem
	if (pev_valid(weaponEnt))
	{
		set_pev(weaponEnt, pev_renderfx, kRenderFxGlowShell);
		set_pev(weaponEnt, pev_rendercolor, glowColor);
		set_pev(weaponEnt, pev_renderamt, 15.0);
	}
}

stock StopGodmodeEffects(playerId)
{
	// Убираем подсветку игрока
	set_pev(playerId, pev_renderfx, kRenderFxNone);
	set_pev(playerId, pev_rendercolor, {0.0, 0.0, 0.0});
	set_pev(playerId, pev_renderamt, 0.0);
	
	// Убираем подсветку с оружия
	new weaponEnt = get_pdata_cbase(playerId, 373, 5);
	if (pev_valid(weaponEnt))
	{
		set_pev(weaponEnt, pev_renderfx, kRenderFxNone);
		set_pev(weaponEnt, pev_rendercolor, {0.0, 0.0, 0.0});
		set_pev(weaponEnt, pev_renderamt, 0.0);
	}
}

public MakeShowWeaponsMenuTask(playerId)
{
	if (get_pcvar_num(g_RespawnEnabled) && get_pcvar_num(g_WeaponsChooseEnabled))
	{
		if (is_user_connected(playerId) && is_user_alive(playerId))
		{
			set_task(0.1, "ShowWeaponsMenu", playerId);
		}
	}
}

public ShowWeaponsMenu(playerId)
{
	if (get_pcvar_num(g_RespawnEnabled) && !get_pcvar_num(g_RandomWeaponsEnabled))
	{
		new menu = menu_create("\y>>>>> \rWeapon selection menu \y<<<<<^n \dby >>\rTonitaga\d<<", "WeaponCase")

		menu_additem(menu, "\yAK47 & Deagle", SET_STRINGS[AK47_DEAGLE_SET], 0);
		menu_additem(menu, "\yM4A1 & Deagle", SET_STRINGS[M4A1_DEAGLE_SET], 0);
		menu_additem(menu, "\yAWP  & Deagle", SET_STRINGS[AWP_DEAGLE_SET], 0);
		menu_additem(menu, "\yRandom",        SET_STRINGS[RANDOM_SET], 0);
		
		menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
		menu_display(playerId, menu, 0);
	}

	return PLUGIN_HANDLED;
}

public WeaponCase(playerId, menu, item)
{
	if (item == MENU_EXIT)
	{
		return PLUGIN_HANDLED;
	}
	
	if (!is_user_alive(playerId) || cs_get_user_team(playerId) == CS_TEAM_SPECTATOR)
	{
		client_print(playerId, print_chat, "[Weapon Menu] Вы должны быть живы для получения оружия!");
		return PLUGIN_HANDLED;
	}
	
	new data[6], name[64], access, callback;
	menu_item_getinfo(menu, item, access, data, charsmax(data), name, charsmax(name), callback);
	
	g_SelectedWeaponsStorage[playerId] = str_to_num(data)

	GiveWeapons(playerId);
	return PLUGIN_HANDLED;
}

stock GiveWeapons(playerId)
{
	if (g_SelectedWeaponsStorage[playerId] == UNDEFINED_SET)
	{
		SetDefaultWeapons(playerId);
	}

	new selectedType = g_SelectedWeaponsStorage[playerId];
	if (get_pcvar_num(g_RandomWeaponsEnabled) || selectedType == RANDOM_SET)
	{
		GiveRandomWeapons(playerId);
		return PLUGIN_HANDLED;
	}

	switch (selectedType)
	{
		case AK47_DEAGLE_SET:
		{
			rg_give_item(playerId, "weapon_ak47", GT_REPLACE);
			cs_set_user_bpammo(playerId, WEAPON_AK47, AMMO_COUNT);
		}
		case M4A1_DEAGLE_SET:
		{
			rg_give_item(playerId, "weapon_m4a1", GT_REPLACE);
			rg_set_user_bpammo(playerId, WEAPON_M4A1, AMMO_COUNT);
		}
		case AWP_DEAGLE_SET:
		{
			rg_give_item(playerId, "weapon_awp", GT_REPLACE);
			rg_set_user_bpammo(playerId, WEAPON_AWP, AMMO_COUNT);
		}
	}

	rg_give_item(playerId, "weapon_deagle", GT_REPLACE);
	rg_set_user_bpammo(playerId, WEAPON_DEAGLE, AMMO_COUNT);

	return PLUGIN_HANDLED;
}

stock GiveWeaponsToAllPlayers()
{
	new players[MAX_PLAYERS],playersCount;

	get_players(players, playersCount);
	for (new i = 0; i < playersCount; ++i)
	{
		new playerId = players[i];
		GiveWeapons(playerId);
	}
}

stock SetDefaultWeapons(playerId)
{
	switch (get_user_team(playerId))
	{
		case CS_TEAM_T:
		{
			g_SelectedWeaponsStorage[playerId] = AK47_DEAGLE_SET
		}
		case CS_TEAM_CT:
		{
			g_SelectedWeaponsStorage[playerId] = M4A1_DEAGLE_SET
		}
	}
}

new const WeaponIdType:g_SecondaryWeaponEnum[] =
{
	WEAPON_ELITE, WEAPON_DEAGLE, WEAPON_FIVESEVEN,
	WEAPON_USP,   WEAPON_GLOCK18
};

new const g_SecondaryWeaponName[][] =
{
	"weapon_elite", "weapon_deagle", "weapon_fiveseven",
	"weapon_usp",   "weapon_glock18"
};

new const WeaponIdType:g_PrimaryWeaponEnum[] =
{
	WEAPON_M249,   WEAPON_MP5N,  WEAPON_P90,
	WEAPON_G3SG1,  WEAPON_MAC10, WEAPON_M4A1,
	WEAPON_FAMAS,  WEAPON_AUG,   WEAPON_AK47,
	WEAPON_SG552,  WEAPON_UMP45, WEAPON_GALIL,
	WEAPON_XM1014, WEAPON_AWP
};

new const g_PrimaryWeaponName[][] =
{
	"weapon_m249",   "weapon_mp5navy", "weapon_p90",
	"weapon_g3sg1",  "weapon_mac10",   "weapon_m4a1",
	"weapon_famas",  "weapon_aug",     "weapon_ak47",
	"weapon_sg552",  "weapon_ump45",   "weapon_galil",
	"weapon_xm1014", "weapon_awp"
};

stock GiveRandomWeapons(playerId)
{
	new lhs = 0, rhs = (sizeof g_PrimaryWeaponEnum) - 1;

	new rand = random_num(lhs, rhs);

	rg_give_item(playerId, g_PrimaryWeaponName[rand], GT_REPLACE);
	rg_set_user_bpammo(playerId, g_PrimaryWeaponEnum[rand], AMMO_COUNT);

	rhs = (sizeof g_SecondaryWeaponEnum) - 1;

	rand = random_num(lhs, rhs);

	rg_give_item(playerId, g_SecondaryWeaponName[rand], GT_REPLACE);
	rg_set_user_bpammo(playerId, g_SecondaryWeaponEnum[rand], AMMO_COUNT);
}
