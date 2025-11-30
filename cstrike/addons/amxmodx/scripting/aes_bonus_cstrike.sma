/*
	Advanced Experience System
	by serfreeman1337		http://gf.hldm.org/
*/

/*
	Random CSTRIKE Bonuses
*/

#include <amxmodx>
#include <aes_v>
#include <engine>
#include <reapi>

#define PLUGIN "AES: Bonus CSTRIKE"
#define VERSION "0.6.0.0 [REAPI]"
#define AUTHOR "serfreeman1337/sonyx + Tonitaga"
#define LASTUPDATE "30, November (11), 2025"

#if AMXX_VERSION_NUM < 183
	#include <colorchat>

	#define print_team_default DontChange
	#define print_team_grey Grey
	#define print_team_red Red
	#define print_team_blue Blue

	#define MAX_NAME_LENGTH	32
	#define MAX_PLAYERS 32

	#define client_disconnected client_disconnect
#endif

enum _:
{
	SUPER_NICHEGO,
	SUPER_NADE,
	SUPER_DEAGLE
};

enum DamagerModes
{
	Disable,
	ModeAll,
	ModeIfVisible
};

new g_PlayerPos[MAX_PLAYERS + 1], g_iSyncMsg, g_iSyncMsg2, DamagerModes:g_ModeDam[MAX_PLAYERS + 1];
new const Float:g_flCoords[][] = { {0.55, 0.55}, {0.5, 0.55}, {0.55, 0.5}, {0.45, 0.5}, {0.45, 0.45}, {0.5, 0.45}, {0.55, 0.45}, {0.45, 0.55} };
new g_players[MAX_PLAYERS + 1];
new bool: g_PointDam[MAX_PLAYERS + 1] = false;

new aes_block_round_bonus_on_knife_maps;

new is_knife_map = false;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	RegisterHookChain(RG_CBasePlayer_TakeDamage, "CBasePlayer_TakeDamage", false);
	RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed_Post", true);
	register_event ("Damage", "EventDamage", "b", "2!0");

	g_iSyncMsg = CreateHudSyncObj();
	g_iSyncMsg2 = CreateHudSyncObj();
}

public plugin_cfg()
{
	bind_pcvar_num(
		create_cvar(
			"aes_block_round_bonus_on_knife_maps", "1",
			.has_min = true, .min_val = 0.0,
			.has_max = true, .max_val = 1.0,
			.description = "Блокировать бонусы в начале раунда на ножевых картах"
		),
		aes_block_round_bonus_on_knife_maps
	);
}

public plugin_precache()
{
	CheckCurrentMap();
}

public client_disconnected(id)
	g_players[id] = SUPER_NICHEGO; // сбрасываем возможности на дисконнекте

public CBasePlayer_Killed_Post(const victim, const killer)
	g_players[victim] = SUPER_NICHEGO; // сбрасываем возможности при смерти

public CBasePlayer_TakeDamage(const id, idinflictor, idattacker, Float:damage)
{
	if(!is_user_connected(idattacker))
		return HC_CONTINUE;

	if(g_players[idattacker])
	{
		if(idattacker == idinflictor && get_member(get_member(idattacker, m_pActiveItem), m_iId) == WEAPON_DEAGLE && (g_players[idattacker] & (1 << SUPER_DEAGLE)))
		{
			damage *= 2.0;
		}
		else if(FClassnameIs(idinflictor, "grenade") && (g_players[idattacker] & (1 << SUPER_NADE)))
		{
			set_task(0.5,"deSetNade",idattacker);
			damage *= 3.0;
		}

		SetHookChainArg(4, ATYPE_FLOAT, damage);
	}
	return HC_CONTINUE;
}

public EventDamage(iVictim)
{
	static iKiller;
	iKiller = get_user_attacker(iVictim);

	if(!iKiller || iKiller > MAX_PLAYERS) return;

	new iPos = ++g_PlayerPos[iKiller];

	if(iPos == sizeof(g_flCoords))
		iPos = g_PlayerPos[iKiller] = 0;

	if (g_PointDam[iKiller] && iVictim != iKiller)
	{
		if (g_ModeDam[iKiller] == ModeAll || (g_ModeDam[iKiller] == ModeIfVisible && is_visible(iVictim, iKiller)))
		{
			set_hudmessage(0, 100, 200, Float:g_flCoords[iPos][0], Float:g_flCoords[iPos][1], 0, 0.0, 1.0, 0.0, 0.0);
			ShowSyncHudMsg(iKiller, g_iSyncMsg, "%i^n", read_data(2));
		}
	}
	if (g_PointDam[iVictim])
	{
		set_hudmessage(200, 100, 0, Float:g_flCoords[iPos][0], Float:g_flCoords[iPos][1], 0, 0.0, 1.0, 0.0, 0.0);
		ShowSyncHudMsg(iVictim, g_iSyncMsg2, "%i^n", read_data(2));
	}
}

public deSetNade(id)
	g_players[id] &= ~(1<<SUPER_NADE);

public roundBonus_GiveDefuser(id,cnt)
{
	if (IsRoundBonusDisabled() || !cnt)
	{
		return false;
	}

	if(get_member(id, m_iTeam) != TEAM_CT)
		return false;

	rg_give_item(id, "item_thighpack");

	return true;
}

public roundBonus_GiveNV(id,cnt)
{
	if (IsRoundBonusDisabled() || !cnt)
	{
		return false;
	}

	set_member(id, m_bHasNightVision, 1);

	return true;
}

public roundBonus_Dmgr(id,DamagerModes:cnt)
{
	if (IsRoundBonusDisabled() || cnt <= Disable)
	{
		return false;
	}

	g_PointDam[id] = true;
	g_ModeDam[id] = (ModeAll < cnt <= ModeIfVisible) ? cnt : ModeAll;

	return true;
}

public GiveArmor(id,cnt)
{
	if(!is_user_alive(id))
	{
		client_print_color(id,0,"%L %L",id,"AES_TAG",id,"AES_ANEW_ALIVE");
		return false;
	}

	if(!cnt)
		return false;

	new iArmor = rg_get_user_armor(id);

	switch(cnt)
	{
		case 1:rg_set_user_armor(id, max(100, iArmor), ARMOR_KEVLAR);
		case 2:rg_set_user_armor(id, max(100, iArmor), ARMOR_VESTHELM);
		default:rg_set_user_armor(id, max(cnt, iArmor), ARMOR_VESTHELM);
	}

	return true;
}

public GiveHP(id,cnt)
{
	if(!is_user_alive(id))
	{
		client_print_color(id,0,"%L %L",id,"AES_TAG",id,"AES_ANEW_ALIVE");
		return false;
	}

	if(!cnt)
		return false;

	set_entvar(id, var_health, (Float:get_entvar(id, var_health) + float(cnt)));
	return true;
}

public GiveMoney(id,cnt)
{
	if(!cnt)
		return false;

	rg_add_account(id, cnt);

	return true;
}


public pointBonus_Dmgr(id)
{
	g_PointDam[id] = true;

	return true;
}


public pointBonus_GiveMegaGrenade(id)
{
	if(!is_user_alive(id))
	{
		client_print_color(id,0,"%L %L",id,"AES_TAG",id,"AES_ANEW_ALIVE");
		return false;
	}

	if(!user_has_weapon(id,CSW_HEGRENADE))
	{
		rg_give_item(id, "weapon_hegrenade");
	}

	g_players[id] |= (1<<SUPER_NADE);

	client_print_color(id,0,"%L %L",id,"AES_TAG",id,"AES_BONUS_GET_MEGAGRENADE");

	return true;
}

public pointBonus_GiveMegaDeagle(id){
	if(!is_user_alive(id))
	{
		client_print_color(id,0,"%L %L",id,"AES_TAG",id,"AES_ANEW_ALIVE");
		return false;
	}

	rg_give_item(id, "weapon_deagle", GT_REPLACE);
	rg_set_user_bpammo(id, WEAPON_DEAGLE, 35);

	g_players[id] |= (1<<SUPER_DEAGLE);
	client_print_color(id,0,"%L %L",id,"AES_TAG",id,"AES_BONUS_GET_MEGADEAGLE");

	return true;
}


/**
* Совместимость со старым bonus.ini
*/
public pointBonus_Give10000M(id)
	GiveMoney(id, 10000);

public pointBonus_Set200HP(id)
	GiveHP(id, 200);

public pointBonus_Set200CP(id)
	GiveArmor(id, 200);

public roundBonus_GiveArmor(id,cnt)
{
	if (!IsRoundBonusDisabled())
	{
		GiveArmor(id,cnt);
	}
}

public roundBonus_GiveHP(id,cnt)
{
	if (!IsRoundBonusDisabled())
	{
		GiveHP(id,cnt);
	}
}

stock IsRoundBonusDisabled()
{
	return (aes_block_round_bonus_on_knife_maps && is_knife_map);
}

stock CheckCurrentMap()
{
	new mapname[128];
	get_mapname(mapname, charsmax(mapname));

	strtolower(mapname);

	new const blocked_maps[][] = {
		"35hp"
	};

	for (new i = 0; i < sizeof(blocked_maps); i++)
	{
		if (containi(mapname, blocked_maps[i]) != -1)
		{
			is_knife_map = true;
			server_print("[AesBonusCstrike] Detected knife map");
			return;
		}
	}

	is_knife_map = false;
}