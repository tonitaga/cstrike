#include <amxmodx>
#include <amxmisc>
#include <string>
#include <reapi>
#include <file>
#include <incom_print>
#include <sqlx>

#define SUPPORT_MOLOTOV    1
#define SUPPORT_HEALTHNADE 1

#if SUPPORT_MOLOTOV == 1
	#include <molotov>
#endif // SUPPORT_MOLOTOV

#if SUPPORT_HEALTHNADE == 1
	#include <healthnade>
#endif // SUPPORT_HEALTHNADE

new const PLUGIN[]		= "Incomsystem Kill Streak Reward";
new const VERSION[]		= "3.1";
new const AUTHOR[]		= "Tonitaga";

///> Название конфигурационного файла
new const CONFIG_FILE[] = "incom_kill_streak_reward.ini";

///> Название MOTD файла
new const MOTD_FILE[] = "incom_kill_streak_reward.txt";

///> Содержимое файла incom_kill_streak_reward.txt
new g_PrecachedMotdContent[2048];

///> CVAR переменные
new       amx_incom_kill_streak_enable;
new       amx_incom_kill_streak_reward_enable;
new Float:amx_incom_kill_streak_reward_max_health;
new       amx_incom_kill_streak_reward_block_health_on_knife_maps;

///> Серия убийств игроков
new g_Kills[33] = { 0, ... };
new g_MaxKills[33] = { 0, ... };

new Array:g_KillStreakAmounts;		 ///< Массив с серией убийств
new Array:g_KillStreakRewardItems;	 ///< Массив с наградой в виде "Item" за серию убийств
new Array:g_KillStreakRewardHealth;	 ///< Массив с наградой в виде "HP" за серию убийств
new Array:g_KillStreakRewardArmor;	 ///< Массив с наградой в виде "Брони" за серию убийств

new const MOLOTOV_GRENADE[] = "weapon_molotovgrenade"; ///< Фиктивное наименование для гранаты "Молотов"
new const HEALTH_GRENADE[]  = "weapon_healthgrenade";  ///< Фиктивное наименование для гранаты "Хилка"

new const minKillStreakForNotify = 2; ///< Минимальная серия для начала уведомления в чат

///> Handle на базу данных
new Handle:g_DbHandle = Empty_Handle;

///> Наименование базы данных и таблицы
new const KILL_STREAK_DB_NAME[]    = "incom_kill_streak"; 
new const KILL_STREAK_TABLE_NAME[] = "incom_kill_streak"; 

///> Текущее название карты
new g_CurrentMapName[128];

///> Текущая карта ножевая
new is_knife_map = false;

///> Команды, которые сервер обрабатывает от клиента
new const MAP_STREAK_COMMAND[]          = "/mapstreak";
new const MAP_STREAK_COMMAND_SAY[]      = "say /mapstreak";
new const MAP_STREAK_COMMAND_SAY_TEAM[] = "say_team /mapstreak";

new const TOP_STREAK_COMMAND[]          = "/topstreak";
new const TOP_STREAK_COMMAND_SAY[]      = "say /topstreak";
new const TOP_STREAK_COMMAND_SAY_TEAM[] = "say_team /topstreak";

///> Идентификаторы типа выбранной команды клиентом
new const TOP_STREAK = 1;
new const MAP_STREAK = 2;

///> ID таски для уведомления клиентов
new g_NotifyTaskId = 15382;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	register_event("DeathMsg", "HandleDeathEvent", "a", "1>0");

	register_clcmd(MAP_STREAK_COMMAND_SAY, "OnMapStreakCommand")
	register_clcmd(MAP_STREAK_COMMAND_SAY_TEAM, "OnMapStreakCommand")

	register_clcmd(TOP_STREAK_COMMAND_SAY, "OnTopStreakCommand")
	register_clcmd(TOP_STREAK_COMMAND_SAY_TEAM, "OnTopStreakCommand")

	///> Будет вызываться раз в 8 минут. Думаю не так часто... Пусть пока так
	set_task(480.0, "NotifyAboutKillStreakCommands", g_NotifyTaskId, .flags = "b");

	register_dictionary("incom_kill_streak_reward.txt")
}

public plugin_cfg()
{
	bind_pcvar_num(
		create_cvar(
			"amx_incom_kill_streak_enable", "1",
			.has_min = true, .min_val = 0.0,
			.has_max = true, .max_val = 1.0,
			.description = "Статус плагина^n\
							0 - Отключен^n\
							1 - Включен"
		),
		amx_incom_kill_streak_enable
	);

	bind_pcvar_num(
		create_cvar(
			"amx_incom_kill_streak_reward_enable", "0",
			.has_min = true, .min_val = 0.0,
			.has_max = true, .max_val = 1.0,
			.description = "Включить награды за серию убийств^n\
							0 - Отключен^n\
							1 - Включен"
		),
		amx_incom_kill_streak_reward_enable
	);

	bind_pcvar_float(
		create_cvar(
			"amx_incom_kill_streak_reward_max_health", "100.0",
			.has_min = true, .min_val = 100.0,
			.has_max = true, .max_val = 150.0,
			.description = "Максимальное количество HP, которое может быть после выдачи награды"
		),
		amx_incom_kill_streak_reward_max_health
	);

	bind_pcvar_num(
		create_cvar(
			"amx_incom_kill_streak_reward_block_health_on_knife_maps", "1",
			.has_min = true, .min_val = 0.0,
			.has_max = true, .max_val = 1.0,
			.description = "Блокировать выдачу HP на ножевых картах^n\
							0 - Отключен^n\
							1 - Включен"
		),
		amx_incom_kill_streak_reward_block_health_on_knife_maps
	);

	AutoExecConfig();
}

public plugin_precache()
{
	new configDir[256];
	get_configsdir(configDir, charsmax(configDir));

	CreateArrays();
	PrecacheKillStreakConfig(configDir);
	PrecacheKillStreakMotdFile(configDir);

	CreateKillStreakTable();
}

public plugin_end()
{
	if (g_DbHandle != Empty_Handle)
	{
		SQL_FreeHandle(g_DbHandle);
	}

	DestroyArrays();
}

public client_connect(playerId)
{
	ResetKillStreak(playerId);
	ResetMaxKillStreak(playerId);
}

public client_disconnected(playerId)
{
	if (!amx_incom_kill_streak_enable)
	{
		return;
	}

	SavePlayerKillStreak(playerId);
	ResetKillStreak(playerId);
	ResetMaxKillStreak(playerId);
}

public NotifyAboutKillStreakCommands()
{
	if (!amx_incom_kill_streak_enable)
	{
		return;
	}

	IncomPrint_Client(0, "[%L] %L", LANG_PLAYER, "INCOM_KILLSTREAK", LANG_PLAYER, "KILLSTREAK_NOTIFY", MAP_STREAK_COMMAND, TOP_STREAK_COMMAND);
}

public HandleDeathEvent()
{
	if (!amx_incom_kill_streak_enable)
	{
		return;
	}

	new killerId = read_data(1);
	new victimId = read_data(2);

	// Обрабатываем убийцу только если он жив и не самоубийство
	if (killerId != victimId && is_user_connected(killerId) && is_user_alive(killerId))
	{
		IncreaseKillStreak(killerId);

		// Выдаем награды только если они включены
		if (amx_incom_kill_streak_reward_enable)
		{
			// Используем небольшую задержку для выдачи награды
			set_task(0.25, "HandleKillStreak", killerId);
		}
	}

	SavePlayerKillStreak(victimId);
	ResetKillStreak(victimId);
}

public HandleKillStreak(playerId)
{
	if (!is_user_connected(playerId) || !is_user_alive(playerId))
	{
		return;
	}

	new currentKills = GetKillStreak(playerId);
	new rewardsCount = ArraySize(g_KillStreakAmounts);

	for (new i = 0; i < rewardsCount; ++i)
	{
		new requiredKills = ArrayGetCell(g_KillStreakAmounts, i);
		if (currentKills == requiredKills)
		{
			new rewardItem[32];
			ArrayGetString(g_KillStreakRewardItems, i, rewardItem, charsmax(rewardItem));

			if (!equal(rewardItem, ""))
			{
				GiveRewardItem(playerId, rewardItem);
			}

			new rewardHealth = ArrayGetCell(g_KillStreakRewardHealth, i);
			if (rewardHealth != 0)
			{
				GiveRewardHealth(playerId, rewardHealth);
			}

			new rewardArmor = ArrayGetCell(g_KillStreakRewardArmor, i);
			if (rewardArmor != 0)
			{
				GiveRewardArmor(playerId, rewardArmor);
			}
		}
	}
}

stock GiveRewardItem(playerId, const rewardItem[])
{
	if (!is_user_alive(playerId))
	{
		return;
	}

	new GiveType:giveType = GT_REPLACE;
	if (IsGrenade(rewardItem))
	{
		giveType = GT_APPEND;
	}

#if SUPPORT_MOLOTOV == 1
	///> Если это "Молотов", то выдаем через API плагина <molotov>
	if (IsMolotovGrenade(rewardItem) && !IsUserHasMolotov(playerId))
	{
		GiveUserMolotov(playerId);
		return;
	}
#endif // SUPPORT_MOLOTOV

#if SUPPORT_HEALTHNADE == 1
	///> Если это "Хилка", то выдаем через API плагина <healthnade>
	if (IsHealthGrenade(rewardItem) && !HealthNade_HasNade(playerId))
	{
		HealthNade_GiveNade(playerId);
		return;
	}
#endif // SUPPORT_HEALTHNADE

	rg_give_item(playerId, rewardItem, giveType);
}

stock GiveRewardHealth(playerId, rewardHealth)
{
	// Выходим, так как текущая карта "Ножевая" и выдача HP заблокирована
	if (amx_incom_kill_streak_reward_block_health_on_knife_maps && is_knife_map)
	{
		return;
	}

	if (!is_user_alive(playerId))
	{
		return;
	}

	new Float:currentHealth;
	get_entvar(playerId, var_health, currentHealth);

	new Float:newHealth = currentHealth + float(rewardHealth);
	new Float:maxHealth = amx_incom_kill_streak_reward_max_health;
	if (newHealth > maxHealth)
	{
		newHealth = maxHealth;
	}

	set_entvar(playerId, var_health, newHealth);
}

stock GiveRewardArmor(playerId, rewardArmor)
{
	if (!is_user_alive(playerId))
	{
		return;
	}

	new currentArmor;
	currentArmor = rg_get_user_armor(playerId);

	new newArmor = currentArmor + rewardArmor;
	if (newArmor > 100)
	{
		newArmor = 100;
	}

	rg_set_user_armor(playerId, newArmor, ARMOR_VESTHELM);
}

stock PrecacheKillStreakConfig(configDir[])
{
	new configFile[256];
	format(configFile, charsmax(configFile), "%s/%s", configDir, CONFIG_FILE);

	if (!file_exists(configFile))
	{
		server_print("[IncomKillStreak] Configuration file doesn't exists: %s", configFile);
		return;
	}

	new file = fopen(configFile, "rt");
	if (!file)
	{
		server_print("[IncomKillStreak] Can't open configuration file: %s", configFile);
		return;
	}

	new line[256];
	new killstreak[16];
	new rewardItem[32];
	new rewardHealth[16];
	new rewardArmor[16];

	new lineNumber = 0;
	while (!feof(file))
	{
		++lineNumber;
		fgets(file, line, charsmax(line));

		if (!line[0] || line[0] == ';' || line[0] == '^n')
		{
			continue;
		}

		if (parse(line, killstreak, charsmax(killstreak), rewardItem, charsmax(rewardItem), rewardHealth, charsmax(rewardHealth), rewardArmor, charsmax(rewardArmor)) >= 1)
		{
			new kills  = str_to_num(killstreak);
			new health = str_to_num(rewardHealth);
			new armor  = str_to_num(rewardArmor);

			ArrayPushCell(g_KillStreakAmounts, kills);
			ArrayPushString(g_KillStreakRewardItems, rewardItem);
			ArrayPushCell(g_KillStreakRewardHealth, health);
			ArrayPushCell(g_KillStreakRewardArmor, armor);
		}
		else
		{
			server_print("[IncomKillStreak] Parsing line error %d: %s", lineNumber, line);
		}
	}

	fclose(file);
	server_print("[IncomKillStreak] Load %d rewards from configuration file", ArraySize(g_KillStreakAmounts));
}

stock PrecacheKillStreakMotdFile(configDir[])
{
	new motdFile[256];
	format(motdFile, charsmax(motdFile), "%s/%s", configDir, MOTD_FILE);

	if (!file_exists(motdFile))
	{
		server_print("[IncomKillStreak] Motd file doesn't exists: %s", motdFile);
		return;
	}

	new file = fopen(motdFile, "rt");
	if (!file)
	{
		server_print("[IncomKillStreak] Can't open motd file: %s", motdFile);
		return;
	}

	new line[256];
	new len = 0;
	while (!feof(file))
	{
		fgets(file, line, charsmax(line));
		
		trim(line);

		len += format(g_PrecachedMotdContent[len], charsmax(g_PrecachedMotdContent) - len, "%s", line);

		if (len >= charsmax(g_PrecachedMotdContent) - 100)
		{
			server_print("[IncomKillStreak] MOTD content too long, truncating");
			break;
		}
	}

	fclose(file);
	
	server_print("[IncomKillStreak] MOTD file loaded successfully: %s", motdFile);
	server_print("[IncomKillStreak] Content length: %d characters", len);
}

stock CreateArrays()
{
	g_KillStreakAmounts		 = ArrayCreate();
	g_KillStreakRewardItems	 = ArrayCreate(32);
	g_KillStreakRewardHealth = ArrayCreate();
	g_KillStreakRewardArmor	 = ArrayCreate();
}

stock DestroyArrays()
{
	if (g_KillStreakAmounts != Invalid_Array)
		ArrayDestroy(g_KillStreakAmounts);

	if (g_KillStreakRewardItems != Invalid_Array)
		ArrayDestroy(g_KillStreakRewardItems);

	if (g_KillStreakRewardHealth != Invalid_Array)
		ArrayDestroy(g_KillStreakRewardHealth);

	if (g_KillStreakRewardArmor != Invalid_Array)
		ArrayDestroy(g_KillStreakRewardArmor);
}

stock GetKillStreak(playerId)
{
	return g_Kills[playerId];
}

stock IncreaseKillStreak(playerId)
{
	g_Kills[playerId]++;
}

stock ResetKillStreak(playerId)
{
	g_Kills[playerId] = 0;
}

stock GetMaxKillStreak(playerId)
{
	return g_MaxKills[playerId];
}

stock UpdateMaxKillStreak(playerId, killstreak)
{
	g_MaxKills[playerId] = killstreak;
	if (killstreak >= minKillStreakForNotify)
	{
		IncomPrint_Client(playerId, "[%L] %L", LANG_PLAYER, "INCOM_KILLSTREAK", LANG_PLAYER, "YOUR_BEST_STREAK", killstreak);
	}
}

stock ResetMaxKillStreak(playerId)
{
	g_MaxKills[playerId] = 0;
}

stock IsGrenade(const item[])
{
	return (
		equal(item, "weapon_hegrenade") ||
		equal(item, "weapon_flashbang") ||
		equal(item, "weapon_smokegrenade") ||
		equal(item, MOLOTOV_GRENADE) ||
		equal(item, HEALTH_GRENADE)
	);
}

stock IsMolotovGrenade(const item[])
{
	return equal(item, MOLOTOV_GRENADE);
}

stock IsHealthGrenade(const item[])
{
	return equal(item, HEALTH_GRENADE);
}

stock SavePlayerKillStreak(playerId)
{
	if(is_user_bot(playerId) || !is_user_connected(playerId))
	{
		return;
	}

	new killstreak = GetKillStreak(playerId);
	if (killstreak <= GetMaxKillStreak(playerId))
	{
		return;
	}

	UpdateMaxKillStreak(playerId, killstreak);
	
	new authid[32];
	get_user_authid(playerId, authid, charsmax(authid));
	
	if(equal(authid, "ID_PENDING"))
	{
		return;
	}

	new playerName[128];
	get_user_name(playerId, playerName, charsmax(playerName));

	new escapedName[128];
	SQL_QuoteString(Empty_Handle, escapedName, charsmax(escapedName), playerName);

	new query[512];
	formatex(query, charsmax(query),
		"INSERT INTO `%s` (`steam_id`, `player_name`, `mapname`, `killstreak`) VALUES ('%s', '%s', '%s', %d) \
		ON CONFLICT(`steam_id`) DO UPDATE SET \
			`player_name` = excluded.`player_name`, \
			`mapname` = excluded.`mapname`, \
			`killstreak` = CASE WHEN excluded.`killstreak` > `killstreak` THEN excluded.`killstreak` ELSE `killstreak` END;",
		KILL_STREAK_TABLE_NAME,
		authid,
		escapedName,
		g_CurrentMapName,
		killstreak
	);

	SQL_ThreadQuery(g_DbHandle, "KillStreakIgnoreHandle", query);
}

public OnMapStreakCommand(playerId)
{
	if (!amx_incom_kill_streak_enable)
	{
		return;
	}

	new query[512];
	formatex(query, charsmax(query),
		"SELECT `player_name`, `killstreak`   \
		 FROM `%s`                            \
		 WHERE `mapname`='%s'                 \
		 ORDER BY `killstreak` DESC LIMIT 10;",
		KILL_STREAK_TABLE_NAME,
		g_CurrentMapName
	);

	new data[2];
	data[0] = playerId;
	data[1] = MAP_STREAK;

	SQL_ThreadQuery(g_DbHandle, "KillStreakTopHandle", query, data, sizeof(data));
}

public OnTopStreakCommand(playerId)
{
	if (!amx_incom_kill_streak_enable)
	{
		return;
	}

	new query[512];
	formatex(query, charsmax(query),
		"SELECT `player_name`, `killstreak`   \
		 FROM `%s`                            \
		 ORDER BY `killstreak` DESC LIMIT 10;",
		KILL_STREAK_TABLE_NAME
	);

	new data[2];
	data[0] = playerId;
	data[1] = TOP_STREAK;

	SQL_ThreadQuery(g_DbHandle, "KillStreakTopHandle", query, data, sizeof(data));
}

public KillStreakTopHandle(failstate, Handle:query, error[], errcode, data[], size)
{
	if(failstate != TQUERY_SUCCESS)
	{
		server_print("[IncomKillStreak] Failed to execute top query: %s", error);
		return;
	}

	new playerId   = data[0];
	new streakType = data[1]; 
	
	if (!is_user_connected(playerId))
	{
		return;
	}

	new tableContent[1024];
	new tableLen = 0;
	
	new row = 0;
	new playerName[128], killstreak;

	while (SQL_MoreResults(query))
	{
		SQL_ReadResult(query, 0, playerName, charsmax(playerName));
		killstreak = SQL_ReadResult(query, 1);
		
		row++;

		new color[4];
		if (row == 1)
		{
			copy(color, charsmax(color), "t1");
		}
		else if (row == 2)
		{
			copy(color, charsmax(color), "t2");
		}
		else if (row == 3)
		{
			copy(color, charsmax(color), "t3");
		}
		else
		{
			copy(color, charsmax(color), "g");
		}

		tableLen += format(tableContent[tableLen], charsmax(tableContent) - tableLen,
			"<tr class=%s><td>[%d]<td>%s</td><td>%2d</td></tr>",
			color,
			row,
			playerName,
			killstreak
		);

		SQL_NextRow(query);
	}

	new motd[2048];
	copy(motd, charsmax(motd), g_PrecachedMotdContent);

	if (streakType == TOP_STREAK)
	{
		replace(motd, charsmax(motd), "%DESCRIPTION%", "ABSOLUTE TOP-10 KILLSTREAK");
	}
	else // MAP_STREAK
	{
		replace(motd, charsmax(motd), "%DESCRIPTION%", "MAP TOP-10 KILLSTREAK");
	}

	replace(motd, charsmax(motd), "%CONTENT%", tableContent);

	show_motd(playerId, motd, "KILLSTREAK");
}

stock CreateKillStreakTable()
{
	SQL_SetAffinity("sqlite");

	g_DbHandle = SQL_MakeDbTuple("", "", "", KILL_STREAK_DB_NAME);
	if (g_DbHandle == Empty_Handle)
	{
		server_print("[IncomKillStreak] Error on making db tuple");
		return;
	}

	get_mapname(g_CurrentMapName, charsmax(g_CurrentMapName));

	is_knife_map = false;
	if (containi(g_CurrentMapName, "35hp") != -1)
	{
		is_knife_map = true;
	}

	new query[512];
	formatex(query, charsmax(query),
		"CREATE TABLE IF NOT EXISTS `%s` (		\
			`steam_id` VARCHAR(32) PRIMARY KEY,	\
			`player_name` VARCHAR(128),			\
			`mapname` VARCHAR(128),			    \
			`killstreak` INTEGER				\
		);",
		KILL_STREAK_TABLE_NAME
	);

	SQL_ThreadQuery(g_DbHandle, "KillStreakIgnoreHandle", query);
}

public KillStreakIgnoreHandle(failstate, Handle:query, error[], errcode, data[], size)
{
	if(failstate != TQUERY_SUCCESS)
	{
		server_print("[IncomKillStreak] Failed to execute query: %s", error);
	}
}
