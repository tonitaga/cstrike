#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <sqlx>

new const PLUGIN[]  = "Incomsystem Damage Control";
new const VERSION[] = "1.0";
new const AUTHOR[]  = "Tonitaga";

///> Наименование базы данных и таблицы
new const DAMAGE_CONTROL_DB_NAME[]    = "incom_damage_control"; 
new const DAMAGE_CONTROL_TABLE_NAME[] = "incom_damage_control";

///> Handle на базу данных
new Handle:g_DbHandle = Empty_Handle;

///> CVAR переменные
new amx_incom_damage_control_enable;
new amx_incom_damage_control_ignore_knife;
new Float:amx_incom_damage_control_awp_scale; ///< Для AWP
new Float:amx_incom_damage_control_all_scale; ///< Для Остального оружия

///> КЭШ состояния базы данных по статусу
new g_PlayerHasDamageControl[33] = { false, ... };

///> Длительности
#define DURATION_ENDMAP -1
#define DURATION_WEEK   (24 * 60 * 60 * 7)
#define DURATION_MONTH  (24 * 60 * 60 * 30)

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	RegisterHam(Ham_TakeDamage, "player", "OnPlayerTakeDamage");

	register_dictionary("incom_damage_control.txt");
}

public plugin_cfg()
{
	bind_pcvar_num(
		create_cvar(
			"amx_incom_damage_control_enable", "1",
			.has_min = true, .min_val = 0.0,
			.has_max = true, .max_val = 1.0,
			.description = "Статус плагина^n\
							0 - Отключен^n\
							1 - Включен"
		),
		amx_incom_damage_control_enable
	);

	bind_pcvar_float(
		create_cvar(
			"amx_incom_damage_control_awp_scale", "1.25",
			.has_min = true, .min_val = 0.5,
			.has_max = true, .max_val = 10.0,
			.description = "Коэффициент изменения урона для AWP"
		),
		amx_incom_damage_control_awp_scale
	);

	bind_pcvar_float(
		create_cvar(
			"amx_incom_damage_control_all_scale", "1.10",
			.has_min = true, .min_val = 0.5,
			.has_max = true, .max_val = 10.0,
			.description = "Коэффициент изменения урона для всего оружия кроме  AWP"
		),
		amx_incom_damage_control_all_scale
	);

	bind_pcvar_num(
		create_cvar(
			"amx_incom_damage_control_ignore_knife", "1",
			.has_min = true, .min_val = 0.0,
			.has_max = true, .max_val = 1.0,
			.description = "Игнорировать коэффициенты изменения урона для ножа^n\
							0 - Отключен^n\
							1 - Включен"
		),
		amx_incom_damage_control_ignore_knife
	);

	AutoExecConfig();
}

public plugin_precache()
{
	CreateIncomDamageControlTable();
}

public plugin_end()
{
	if (g_DbHandle != Empty_Handle)
	{
		SQL_FreeHandle(g_DbHandle);
	}
}

public client_putinserver(playerId)
{
	if (!is_user_connected(playerId) || is_user_bot(playerId))
	{
		return;
	}

	LoadIncomDamageControlStatus(playerId);
}

public OnPlayerTakeDamage(victim, inflictor, attacker, Float:damage, damageBits)
{
	if (!amx_incom_damage_control_enable)
	{
		return HAM_IGNORED;
	}

	if (victim == attacker)
	{
		return HAM_IGNORED;
	}

	if (!is_user_connected(victim) || !is_user_alive(victim) || !g_PlayerHasDamageControl[attacker])
	{
		return HAM_IGNORED;
	}

	new weapon = get_user_weapon(attacker);
	if (weapon == CSW_KNIFE && amx_incom_damage_control_ignore_knife)
	{
		return HAM_IGNORED;
	}

	new Float:multiplier = amx_incom_damage_control_all_scale;
	if (weapon == CSW_AWP)
	{
		multiplier = amx_incom_damage_control_awp_scale;
	}

	SetHamParamFloat(4, damage * multiplier);
	return HAM_HANDLED;
}

public public_IncreaseDamageUntilMapEnd(playerId, count, maximum)
{
	return IncreaseDamage(playerId, DURATION_ENDMAP);
}

public public_IncreaseDamageOneWeek(playerId, count, maximum)
{
	return IncreaseDamage(playerId, DURATION_WEEK);
}

public public_IncreaseDamageOneMonth(playerId, count, maximum)
{
	return IncreaseDamage(playerId, DURATION_MONTH);
}

stock IncreaseDamage(playerId, duration)
{
	if (!amx_incom_damage_control_enable)
		return false;


	if (g_PlayerHasDamageControl[playerId])
	{
		client_print_color(playerId, print_team_default, "[%L] %L",
			LANG_PLAYER, "DAMAGE_CONTROL",
			LANG_PLAYER, "DAMAGE_CONTROL_ALREADY_ACTIVE"
		);
		return false;
	}

	g_PlayerHasDamageControl[playerId] = true;

	// Для DURATION_ENDMAP информация хранится только в кеше, в базу не попадает	
	if (duration != DURATION_ENDMAP)
	{
		EnableDamageControlStatus(playerId, duration);
	}

	client_print_color(playerId, print_team_default, "[%L] %L",
		LANG_PLAYER, "DAMAGE_CONTROL",
		LANG_PLAYER, "DAMAGE_CONTROL_INFO",
		/* Параметры */
		amx_incom_damage_control_awp_scale,
		amx_incom_damage_control_all_scale
	);

	return true;
}

stock EnableDamageControlStatus(playerId, duration)
{
	new steamId[32];
	get_user_authid(playerId, steamId, charsmax(steamId));

	new systime = get_systime();
	new expiresIn = systime + duration;

	new query[512];
	formatex(query, charsmax(query),
		"INSERT OR REPLACE INTO `%s` (steam_id, expires_in) VALUES ('%s', %d);",
		DAMAGE_CONTROL_TABLE_NAME, steamId, expiresIn
	);

	SQL_ThreadQuery(g_DbHandle, "Callback_IncomDamageControlIgnoreHandle", query);
}

stock CreateIncomDamageControlTable()
{
	SQL_SetAffinity("sqlite");

	g_DbHandle = SQL_MakeDbTuple("", "", "", DAMAGE_CONTROL_DB_NAME);
	if (g_DbHandle == Empty_Handle)
	{
		server_print("[IncomDamageControl] Error on making db tuple");
		return;
	}

	new query[512];
	formatex(query, charsmax(query),
		"CREATE TABLE IF NOT EXISTS `%s` (		\
			`steam_id` VARCHAR(32) PRIMARY KEY,	\
			`expires_in` INTEGER NOT NULL		\
		);",
		DAMAGE_CONTROL_TABLE_NAME
	);

	SQL_ThreadQuery(g_DbHandle, "Callback_IncomDamageControlIgnoreHandle", query);
}

stock LoadIncomDamageControlStatus(playerId)
{
	new steamId[32];
	get_user_authid(playerId, steamId, charsmax(steamId));

	new query[256];
	formatex(query, charsmax(query),
		"SELECT expires_in FROM `%s` WHERE steam_id = '%s';",
		DAMAGE_CONTROL_TABLE_NAME, steamId
	);

	new data[2];
	data[0] = playerId;
	
	SQL_ThreadQuery(g_DbHandle, "Callback_LoadIncomDamageControlStatusHandle", query, data, sizeof(data));
}

stock RemoveExpiredDamageControl(playerId)
{
	if (!is_user_connected(playerId))
	{
		return;
	}

	new steamId[32];
	get_user_authid(playerId, steamId, charsmax(steamId));

	new query[256];
	formatex(query, charsmax(query),
		"DELETE FROM `%s` WHERE steam_id = '%s'",
		DAMAGE_CONTROL_TABLE_NAME, steamId
	);

	SQL_ThreadQuery(g_DbHandle, "Callback_IncomDamageControlIgnoreHandle", query);
}

public Callback_LoadIncomDamageControlStatusHandle(failstate, Handle:query, error[], errcode, data[], size)
{
	if (failstate != TQUERY_SUCCESS)
	{
		server_print("[IncomDamageControl] Failed to load status: %s", error);
		return;
	}

	new playerId = data[0];
	if (SQL_NumResults(query) > 0)
	{
		new expiresIn = SQL_ReadResult(query, 0);
		new currentTime = get_systime();

		if (expiresIn > currentTime)
		{
			g_PlayerHasDamageControl[playerId] = true;

			new data[2];
			data[0] = playerId;
			data[1] = expiresIn - currentTime;

			set_task(12.0, "NotifyAboutSubscription", playerId, data, sizeof(data))
		}
		else
		{
			RemoveExpiredDamageControl(playerId);
			g_PlayerHasDamageControl[playerId] = false;
		}
	}
	else
	{
		g_PlayerHasDamageControl[playerId] = false;
	}
}

public Callback_IncomDamageControlIgnoreHandle(failstate, Handle:query, error[], errcode, data[], size)
{
	if(failstate != TQUERY_SUCCESS)
	{
		server_print("[IncomDamageControl] Failed to execute query: %s", error);
	}
}

public NotifyAboutSubscription(data[])
{
	new playerId = data[0];
	if (!amx_incom_damage_control_enable || !is_user_connected(playerId))
	{
		return;
	}

	new timeleft = data[1];
	new hours = timeleft / 60 / 60;

	client_print_color(playerId, print_team_default, "[%L] %L",
		LANG_PLAYER, "DAMAGE_CONTROL",
		LANG_PLAYER, "DAMAGE_CONTROL_ACTIVE",
		hours
	);
}