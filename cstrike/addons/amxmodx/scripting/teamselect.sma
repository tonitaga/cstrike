/**
*
* Name: Team Menu
* Version: 1.6.0 (09.05.2020)
* Author: F@nt0M
* Description: The plugin show custom team select menu instead of default
*
* Thanks rian18 (https://dev-cs.ru/members/6256/) to add german translation
*
* Requirements: ReHLDS, ReGameDLL, AmxModX 1.9.0, ReAPI
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>
*
*/

#pragma semicolon 1

#include <amxmodx>
#include <reapi>

enum {
	MODE_NORMAL_TEAM,
	MODE_RANDOM_TEAM,
};

enum {
	SPEC_ALWAYS,
	SPEC_AFTER_JOIN,
};

new HookChain:HookShowMenuPre;
new Mode, Spectators, Appearance, Unlimited, Float:TimeLimit;
new AdminFlags = ADMIN_BAN, Autojoin, AutojoinImminity = ADMIN_BAN;
new Float:NextChooseTeamTime[MAX_PLAYERS + 1];
new bool:FreezePeriodChanged = false;

public plugin_init()  {
	register_plugin("Team Select", "1.6.0", "F@nt0M");
	register_dictionary("teamselect.txt");

	RegisterHookChain(RG_ShowVGUIMenu, "ShowVGUIMenu_Pre", false);
	RegisterHookChain(RG_HandleMenu_ChooseTeam, "HandleMenu_ChooseTeam_Pre", false);
	RegisterHookChain(RG_HandleMenu_ChooseTeam, "HandleMenu_ChooseTeam_Post", true);
	HookShowMenuPre = RegisterHookChain(RG_ShowMenu, "ShowMenu_Pre", false);
	DisableHookChain(HookShowMenuPre);

	bind_pcvar_num(create_cvar(
		"amx_ts_mode", "0", FCVAR_SERVER,
		fmt("%L", LANG_SERVER, "TS_MODE_DESC"),
		true, 0.0, true, 1.0
	), Mode);

	bind_pcvar_num(create_cvar(
		"amx_ts_spec", "0", FCVAR_SERVER,
		fmt("%L", LANG_SERVER, "TS_SPEC_DESC"),
		true, 0.0, true, 1.0
	), Spectators);

	bind_pcvar_num(create_cvar(
		"amx_ts_appearance", "0", FCVAR_SERVER,
		fmt("%L", LANG_SERVER, "TS_APPEARANCE_DESC"),
		true, 0.0, true, 1.0
	), Appearance);

	bind_pcvar_num(create_cvar(
		"amx_ts_unlimited", "0", FCVAR_SERVER,
		fmt("%L", LANG_SERVER, "TS_UNLIMITED_DESC"),
		true, 0.0, true, 1.0
	), Unlimited);

	bind_pcvar_float(create_cvar(
		"amx_ts_time_limit", "0.0", FCVAR_SERVER,
		fmt("%L", LANG_SERVER, "TS_TIME_LIMIT_DESC"),
		true, 0.0
	), TimeLimit);

	bind_pcvar_num(create_cvar(
		"amx_ts_autojoin", "0", FCVAR_SERVER,
		fmt("%L", LANG_SERVER, "TS_AUTOJOIN_DESC"),
		true, 0.0, true, 1.0
	), Autojoin);

	hook_cvar_change(create_cvar(
		"amx_ts_admin_flags", "d", FCVAR_SERVER,
		fmt("%L", LANG_SERVER, "TS_FLAGS_DESC")
	), "HookChangeFlag");

	hook_cvar_change(create_cvar(
		"amx_ts_autojoin_immunity", "d", FCVAR_SERVER,
		fmt("%L", LANG_SERVER, "TS_AUTOJOIN_IMMUNITY_DESC"),
		true, 0.0, true, 1.0
	), "HookChangeImmunity");

	AutoExecConfig(true, "teamselect");
}

public HookChangeFlag(const pcvar, const oldValue[], const newValue[]) {
	AdminFlags = read_flags(newValue);
}

public HookChangeImmunity(const pcvar, const oldValue[], const newValue[]) {
	AutojoinImminity = read_flags(newValue);
}

public client_putinserver(id) {
	NextChooseTeamTime[id] = 0.0;
	if (!Autojoin) {
		return PLUGIN_CONTINUE;
	}
	if (AutojoinImminity && (get_user_flags(id) & AutojoinImminity == AutojoinImminity)) {
		return PLUGIN_CONTINUE;
	}
	rg_join_team(id, rg_get_join_team_priority());
	return PLUGIN_CONTINUE;
}

public ShowVGUIMenu_Pre(const id, VGUIMenu:menuType) {
	if (is_user_bot(id) || menuType != VGUI_Menu_Team) {
		return HC_CONTINUE;
	}

	if (TimeLimit && NextChooseTeamTime[id] >= get_gametime()) {
		client_printex(id, print_center, "#Only_1_Team_Change");
		set_member(id, m_iMenu, Menu_ChooseTeam);
		return HC_SUPERCEDE;
	}

	new bool:newPlayer = bool:(TeamName:get_member(id, m_iTeam) == TEAM_UNASSIGNED);
	SetGlobalTransTarget(id);

	new menu[MAX_MENU_LENGTH], keys;
	new len = formatex(menu, charsmax(menu), "\w%l^n^n", "TS_SELECT_TEAM");
	if (Mode == MODE_NORMAL_TEAM) {
		len += formatex(menu[len], charsmax(menu) - len, "\d[\r1\d] \r%l \d[\y%d\d]^n", "TS_TEAM_T", get_member_game(m_iNumTerrorist));
		len += formatex(menu[len], charsmax(menu) - len, "\d[\r2\d] \r%l \d[\y%d\d]^n", "TS_TEAM_CT", get_member_game(m_iNumCT));
		keys |= MENU_KEY_1 | MENU_KEY_2;
	} else {
		len += formatex(menu[len], charsmax(menu) - len, "\d[\r1\d] \r%l^n", newPlayer ? "TS_ENTER_GAME" : "TS_CHANGE_TEAM");
		keys |= MENU_KEY_1;
	}

	if (
		Spectators == SPEC_ALWAYS
		|| (Spectators == SPEC_AFTER_JOIN && !newPlayer)
		|| (AdminFlags && (get_user_flags(id) & AdminFlags) == AdminFlags)
	) {
		len += formatex(menu[len], charsmax(menu) - len, "^n\d[\r6\d] \w%l^n", "TS_SPECTATOR");
		keys |= MENU_KEY_6;
	}

	if (!newPlayer) {
		len += formatex(menu[len], charsmax(menu) - len, "^n^n\d[\r0\d] \w%l^n", "TS_CLOSE");
		keys |= MENU_KEY_0;
	}

	set_member(id, m_bForceShowMenu, true);
	SetHookChainArg(3, ATYPE_INTEGER, keys);
	SetHookChainArg(4, ATYPE_STRING, menu);

	// https://wiki.alliedmods.net/Half-Life_1_Game_Events#ShowMenu
	// https://github.com/alliedmodders/amxmodx/blob/c86813697acf3a3b577ca35426053db8dd7f8902/amxmodx/util.cpp#L48
	if (strlen(menu) > 175) {
		EnableHookChain(HookShowMenuPre);
	}
	return HC_CONTINUE;
}

// Fix menu limit in ReGameDLL (https://github.com/s1lentq/ReGameDLL_CS/blob/9d89a347fa22662b716697c97150ddea2bd00d99/regamedll/dlls/client.cpp#L394)
public ShowMenu_Pre(const id, const keys, const time, const needMore, const menu[]) {
	DisableHookChain(HookShowMenuPre);
	show_menu(id, keys, menu, time);
	set_member(id, m_iMenu, Menu_ChooseTeam); // AMXX overide m_iMenu after show_menu
	return HC_SUPERCEDE;
}

public HandleMenu_ChooseTeam_Pre(const id, const MenuChooseTeam:slot) {
	if (is_user_bot(id)) {
		return HC_CONTINUE;
	}

	if (slot == MenuChoose_Spec) {
		if (is_user_alive(id) && !get_member_game(m_bFreezePeriod)) {
			set_member_game(m_bFreezePeriod, true);
			FreezePeriodChanged = true;
		}
	} else {
		if (Mode == MODE_RANDOM_TEAM) {
			new MenuChooseTeam:team;
			switch (TeamName:get_member(id, m_iTeam)) {
				case TEAM_TERRORIST: team = MenuChoose_CT;
				case TEAM_CT: team = MenuChoose_T;
				default: team = MenuChoose_AutoSelect;
			}
			SetHookChainArg(2, ATYPE_INTEGER, team);
		}

		if (!Appearance) {
			set_member_game(m_bSkipShowMenu, true);
		}
	}
	return HC_CONTINUE;
}

public HandleMenu_ChooseTeam_Post(const id, const MenuChooseTeam:slot) {
	if (FreezePeriodChanged) {
		set_member_game(m_bFreezePeriod, false);
	}
	if (!GetHookChainReturn(ATYPE_INTEGER)) {
		return;
	}
	if (Unlimited) {
		set_member(id, m_bTeamChanged, false);
	}
	
	NextChooseTeamTime[id] = get_gametime() + TimeLimit;
	if (slot == MenuChoose_Spec || Appearance) {
		return;
	}

	set_member_game(m_bSkipShowMenu, false);
	if (get_member(id, m_bJustConnected)) {
		set_member(id, m_iJoiningState, GETINTOGAME);
		set_member(id, m_bJustConnected, false);
	} else if (slot != MenuChoose_Spec && !Appearance && is_user_alive(id)) {
		user_kill(id);
	}

	set_member(id, m_iMenu, Menu_ChooseAppearance);
	client_cmd(id, "joinclass 5");
}
