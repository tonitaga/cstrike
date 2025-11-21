#include <amxmodx>
#include <reapi>
#include <incom_print>

#define PLUGIN  "Incomsystem Reset Score"
#define VERSION "1.0"
#define AUTHOR  "Tonitaga"

#define RS_COMMAND_SAY      "say /rs"
#define RS_COMMAND_SAY_TEAM "say_team /rs"

new const reset_score_sound[] = "rs/incom_reset_score.wav";

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	register_clcmd(RS_COMMAND_SAY,      "OnResetScore");
	register_clcmd(RS_COMMAND_SAY_TEAM, "OnResetScore");

	register_dictionary("incom_reset_score.txt");
}

public plugin_precache()
{
	precache_sound(reset_score_sound);
}

public OnResetScore(playerId)
{
	if (!is_user_connected(playerId))
	{
		return;
	}

	set_entvar(playerId, var_frags, 0.0);
	set_member(playerId, m_iDeaths, 0);

	// Проигрываем звук
	rg_send_audio(playerId, reset_score_sound);

	IncomPrint_Client(playerId, "[%L] %L", playerId, "INCOM_RESET_SCORE", playerId, "RESET_SCORE_DONE");
}
