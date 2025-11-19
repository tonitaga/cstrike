#include <amxmodx>
#include <fakemeta>
#include <reapi>

// #define EnableAfterFirstRound   // Если у вас нету разминки на ножах то можно закоментить
#define MODELS // Закомментировать если модели не нужны
#define SOUNS  // Закомментировать если звуки не нужны

#if defined SOUNS
new const KILL_SOUND[][] =
{
	"ks/kill_1.wav",
	"ks/kill_2.wav",
	"ks/kill_3.wav",
	"ks/kill_4.wav",
	"ks/kill_5.wav"
}
#endif
#if defined MODELS
new const ENTITY_MODEL[][] =
{
	"models/item_relaxcs/piglet.mdl",
	"models/item_relaxcs/cutesheep.mdl",
	"models/item_relaxcs/rxghost.mdl"
}

new const ENTITY_CLASSNAME[] = "ghost";
const Float: ENTITY_LIFETIME = 1.7;
const Float: ENTITY_SPEED = 40.0;
#endif

public plugin_precache() {
	#if defined SOUNS
	for(new i = 0; i < sizeof(KILL_SOUND); i++) 
		precache_sound(KILL_SOUND[i]);
	#endif
	
	#if defined MODELS
	for(new i = 0; i < sizeof(ENTITY_MODEL); i++) 
			precache_model(ENTITY_MODEL[i]);
	#endif	
}

public plugin_init()
{
	register_plugin("Knife kill", "1.0.1", "MurLemur");
	RegisterHookChain(RG_CSGameRules_DeathNotice, "CSGameRules_DeathNotice", true);
}	

public CSGameRules_DeathNotice(const iVictim, const iKiller, pevInflictor){
	#if defined MODELS
	if (pevInflictor<1)
		ghost_effect(2,iVictim,iVictim)
	#endif

	#if defined EnableAfterFirstRound
	if (get_member_game(m_iTotalRoundsPlayed) == 0) 
		return HC_CONTINUE
	#endif
	
	if(iVictim == iKiller || !is_user_connected(iKiller))
		return HC_CONTINUE

	if(iKiller == pevInflictor && FClassnameIs(get_member(iKiller, m_pActiveItem),"weapon_knife") || FClassnameIs(pevInflictor, "weapon_knife") ) {
		
		new cur_type = random_num(0,1); 
		#if defined SOUNS
		rg_send_audio(0, KILL_SOUND[cur_type], PITCH_NORM);
		#endif
		#if defined MODELS
		ghost_effect(cur_type,pevInflictor,iVictim)
		#endif

    } 

	return HC_CONTINUE;
}

#if defined MODELS
public ghost_effect(cur_type,pevInflictor,iVictim)
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
		
		engfunc(EngFunc_SetModel, iEntity, ENTITY_MODEL[cur_type]);
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
#endif