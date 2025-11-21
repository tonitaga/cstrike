#include <amxmodx>
#include <amxmisc>
#include <string>
#include <reapi>
#include <file>
#include <molotov>

new const PLUGIN[]		= "Incomsystem Kill Streak Reward";
new const VERSION[]		= "1.0";
new const AUTHOR[]		= "Tonitaga";

///> Название конфигурационного файла
new const CONFIG_FILE[] = "incom_kill_streak_reward.ini";

///> CVAR переменные
new amx_incom_kill_streak_reward_enable;

///> Серия убийств игроков
new g_Kills[33] = { 0, ... };

new Array:g_KillStreakAmounts;		 ///< Массив с серией убийств
new Array:g_KillStreakRewardItems;	 ///< Массив с наградой в виде "Item" за серию убийств
new Array:g_KillStreakRewardHealth;	 ///< Массив с наградой в виде "HP" за серию убийств
new Array:g_KillStreakRewardArmor;	 ///< Массив с наградой в виде "Брони" за серию убийств

///> Фиктивное наименование для гранаты "Молотов"
new const MOLOTOV_GRENADE[] = "weapon_molotovgrenade";

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	register_event("DeathMsg", "HandleDeathEvent", "a", "1>0");
}

public plugin_cfg()
{
	bind_pcvar_num(
		create_cvar(
			"amx_incom_kill_streak_reward_enable", "0",
			.has_min = true, .min_val = 0.0,
			.has_max = true, .max_val = 1.0,
			.description = "Статус плагина^n\
                            0 - Отключен^n\
                            1 - Включен"),
		amx_incom_kill_streak_reward_enable);

	AutoExecConfig();
}

public plugin_precache()
{
	new configDir[256];
	get_configsdir(configDir, charsmax(configDir));

	new configFile[256];
	format(configFile, charsmax(configFile), "%s/%s", configDir, CONFIG_FILE);

	CreateArrays();
	PrecacheKillStreakConfig(configFile);
}

public plugin_end()
{
	DestroyArrays();
}

public client_connect(playerId)
{
	ResetKillStreak(playerId);
}

public client_disconnected(playerId)
{
	ResetKillStreak(playerId);
}

public HandleDeathEvent()
{
	if (!amx_incom_kill_streak_reward_enable)
	{
		return;
	}

	new killerId = read_data(1);
	new victimId = read_data(2);

	// Обрабатываем убийцу только если он жив и не самоубийство
	if (killerId != victimId && is_user_connected(killerId) && is_user_alive(killerId))
	{
		IncreaseKillStreak(killerId);

		// Используем небольшую задержку для выдачи награды
		set_task(0.25, "HandleKillStreakDelayed", killerId);
	}

	ResetKillStreak(victimId);
}

public HandleKillStreakDelayed(playerId)
{
	if (is_user_connected(playerId) && is_user_alive(playerId))
	{
		HandleKillStreak(playerId);
	}
}

stock HandleKillStreak(playerId)
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
				GiveRewardArmor(playerId, rewardHealth);
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

	///> Если это молотов, то выдаем через API плагина молотова
	if (IsMolotovGrenade(rewardItem) && !IsUserHasMolotov(playerId))
	{
		GiveUserMolotov(playerId);
		return;
	}

	rg_give_item(playerId, rewardItem, giveType);
}

stock GiveRewardHealth(playerId, rewardHealth)
{
	if (!is_user_alive(playerId))
	{
		return;
	}

	new Float:currentHealth;
	get_entvar(playerId, var_health, currentHealth);

	new Float:newHealth = currentHealth + float(rewardHealth);
	if (newHealth > 100.0)
	{
		newHealth = 100.0;
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

stock PrecacheKillStreakConfig(configFile[])
{
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

stock IsGrenade(const item[])
{
	return (
		equal(item, "weapon_hegrenade") || equal(item, "weapon_flashbang") || equal(item, "weapon_smokegrenade") || equal(item, MOLOTOV_GRENADE));
}

stock IsMolotovGrenade(const item[])
{
	return equal(item, MOLOTOV_GRENADE);
}