#include <amxmodx>
#include <fakemeta>
#include <reapi>

new amx_e6a_knife_enable;
new amx_e6a_knife_blood_enable;
new amx_e6a_knife_red_screen_enable;
new g_msgScreenFade;
new g_BloodSprite;

const Float: ENTITY_LIFETIME = 3;
const Float: ENTITY_SPEED = 40.0;

new const ENTITY_CLASSNAME[] = "ghost";
new const KILL_SOUND[][] =
{
	"e6a_knife/kill_1.wav",
	"e6a_knife/kill_2.wav",
	"e6a_knife/kill_3.wav",
	"e6a_knife/kill_4.wav",
	"e6a_knife/kill_5.wav"
}

new const ENTITY_MODEL[][] =
{
	"models/e6a_knife/piglet.mdl",
	"models/e6a_knife/cutesheep.mdl",
	"models/e6a_knife/rxghost.mdl"
}

public plugin_precache() {
	for(new i = 0; i < sizeof(KILL_SOUND); i++) 
		precache_sound(KILL_SOUND[i]);
	
	for(new i = 0; i < sizeof(ENTITY_MODEL); i++) 
			precache_model(ENTITY_MODEL[i]);

	g_BloodSprite = precache_model("sprites/blood.spr");
}

public plugin_init()
{
	register_plugin("e6a_knife", "1.1.0", "e6aluga & MurLemur");
	RegisterHookChain(RG_CSGameRules_DeathNotice, "CSGameRules_DeathNotice", true);
	g_msgScreenFade = get_user_msgid("ScreenFade");
}	

public plugin_cfg()
{
    bind_pcvar_num(
        create_cvar(
            "amx_e6a_knife_enable", "1",
            .has_min = true, .min_val = 0.0,
            .has_max = true, .max_val = 1.0,
            .description = "0 - Плагин отключен^n\
                            1 - Плагин включен"
        ),
        amx_e6a_knife_enable
    );
	bind_pcvar_num(
		create_cvar(
			"amx_e6a_knife_blood_enable", "1",
			.has_min = true, .min_val = 0.0,
			.has_max = true, .max_val = 1.0,
			.description = "0 - Эффект крови отключен^n\
							1 - Эффект крови включен"
		),
		amx_e6a_knife_blood_enable
	);
	bind_pcvar_num(
		create_cvar(
			"amx_e6a_knife_red_screen_enable", "1",
			.has_min = true, .min_val = 0.0,
			.has_max = true, .max_val = 1.0,
			.description = "0 - Эффект покраснения экрана отключен^n\
							1 - Эффект покраснения экрана включен"
		),
		amx_e6a_knife_red_screen_enable
	);
    AutoExecConfig();
}

public CSGameRules_DeathNotice(const iVictim, const iKiller, pevInflictor){
	if (!amx_e6a_knife_enable)
		return HC_CONTINUE;

	if (pevInflictor<1)
		ghost_effect(2,iVictim,iVictim)
	
	if(iVictim == iKiller || !is_user_connected(iKiller))
		return HC_CONTINUE;

	if((iKiller == pevInflictor && FClassnameIs(get_member(iKiller, m_pActiveItem),"weapon_knife")) || 
	   FClassnameIs(pevInflictor, "weapon_knife")) {
		new sound_type = random_num(0, sizeof(KILL_SOUND) - 1);
		play_loud_sound_for_all(sound_type);
		new model_type = random_num(0, sizeof(ENTITY_MODEL) - 1);
		ghost_effect(model_type,pevInflictor,iVictim)
		more_blood_effect(iVictim);
		red_screen_effect(iKiller);
    } 
	return HC_CONTINUE;
}

red_screen_effect(killer)
{
	if (!amx_e6a_knife_red_screen_enable)
		return;

	if (!is_user_connected(killer))
		return;
	
	message_begin(MSG_ONE, g_msgScreenFade, {0,0,0}, killer);
	write_short(1<<12);
	write_short(1<<8);
	write_short(1<<9);
	write_byte(255);
	write_byte(0);
	write_byte(0);
	write_byte(100);
	message_end();
}

more_blood_effect(victim)
{
	if (!amx_e6a_knife_blood_enable)
		return;

	new Float:pos[3];
	get_entvar(victim, var_origin, pos);
	pos[2] += 35.0;
	
	// Фонтаны (1)
	for(new i = 0; i < 1; i++)
	{
		new Float:fpos[3];
		fpos[0] = pos[0] + random_float(-20.0, 20.0);
		fpos[1] = pos[1] + random_float(-20.0, 20.0);
		fpos[2] = pos[2] + random_float(-5.0, 10.0);
		
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
		write_byte(TE_BLOODSTREAM);
		engfunc(EngFunc_WriteCoord, fpos[0]);
		engfunc(EngFunc_WriteCoord, fpos[1]);
		engfunc(EngFunc_WriteCoord, fpos[2]);
		engfunc(EngFunc_WriteCoord, random_float(-80.0, 80.0));
		engfunc(EngFunc_WriteCoord, random_float(-80.0, 80.0));
		engfunc(EngFunc_WriteCoord, random_float(200.0, 350.0));
		write_byte(70);
		write_byte(random_num(400, 600));
		message_end();
	}
	
	// Частицы (5)
	for(new i = 0; i < 5; i++)
	{
		new Float:ppos[3];
		ppos[0] = pos[0] + random_float(-45.0, 45.0);
		ppos[1] = pos[1] + random_float(-45.0, 45.0);
		ppos[2] = pos[2] + random_float(-10.0, 25.0);
		
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
		write_byte(TE_BLOODSPRITE);
		engfunc(EngFunc_WriteCoord, ppos[0]);
		engfunc(EngFunc_WriteCoord, ppos[1]);
		engfunc(EngFunc_WriteCoord, ppos[2]);
		write_short(g_BloodSprite);
		write_short(g_BloodSprite);
		write_byte(248);
		write_byte(random_num(20, 40));
		message_end();
	}
}

public play_loud_sound_for_all(sound_index)
{
    rg_send_audio(0, KILL_SOUND[sound_index], PITCH_NORM);
}

public ghost_effect(model_type,pevInflictor,iVictim)
{
		new Float: vecOrigin[3];
		new Float: vecVelocity[3];

		vecVelocity[2] = ENTITY_SPEED;
		get_entvar(iVictim, var_origin, vecOrigin);
		new Float: vecAngles[ 3 ]; 
		get_entvar( pevInflictor, var_angles, vecAngles );

		new iEntity = rg_create_entity("info_target", false);

		if(is_nullent(iEntity))
			return 
		
		vecOrigin[2] = vecOrigin[2]-30.0;
		if (pevInflictor!=iVictim)
		{
			vecAngles[0] *= -1;
			vecAngles[1] += 180;
		}

		engfunc(EngFunc_SetModel, iEntity, ENTITY_MODEL[model_type]);
		engfunc(EngFunc_SetSize, iEntity, {-10.0, -10.0, -10.0}, {10.0, 10.0, 10.0});

		set_entvar(iEntity, var_origin, vecOrigin);
		set_entvar(iEntity, var_classname, ENTITY_CLASSNAME);
		set_entvar(iEntity, var_movetype, MOVETYPE_NOCLIP);
		set_entvar(iEntity, var_solid, SOLID_NOT);
		set_entvar(iEntity, var_velocity, vecVelocity);
		set_entvar(iEntity, var_angles, vecAngles);
		
		new Float: vecAVelocity[3];
		vecAVelocity[1] = random_float(-50.0, 50.0);
		set_entvar(iEntity, var_avelocity, vecAVelocity);
		
		set_entvar(iEntity, var_nextthink, get_gametime() + ENTITY_LIFETIME);

		SetThink(iEntity, "@EGhost_Think");
}

@EGhost_Think(iEntity)
{
	set_entvar(iEntity, var_flags, FL_KILLME);
}