#include <amxmodx>
#include <engine>
#include <cstrike>
#include <hamsandwich>

new const SantaHats_T[]  = "models/santa_hats/santa_hats_t.mdl";
new const SantaHats_CT[] = "models/santa_hats/santa_hats_ct.mdl";

new g_HatsStorage[33];

public plugin_init()
{
	register_plugin("Santa Hat", "1.3", "xPaw + Tonitaga");
	register_event("TeamInfo", "EventTeamInfo", "a");

	RegisterHam(Ham_Spawn, "player", "FwdHamPlayerSpawn", 1);
}

public plugin_precache()
{
	precache_model(SantaHats_T);
	precache_model(SantaHats_CT);
}

public client_disconnected(id)
{
	if(is_valid_ent(g_HatsStorage[id]))
	{
		remove_entity(g_HatsStorage[id]);
	}
}

public FwdHamPlayerSpawn(const id)
{
	if(is_user_alive(id))
	{
		new entity = g_HatsStorage[id];
		
		if(!is_valid_ent(entity))
		{
			if(!(entity = g_HatsStorage[id] = create_entity( "info_target")))
			{
				return;
			}
			
			new CsTeams:team = cs_get_user_team( id );
			if (team == CS_TEAM_T)
			{
				entity_set_model(entity, SantaHats_T);
			}
			else if (team == CS_TEAM_CT)
			{
				entity_set_model(entity, SantaHats_CT);
			}

			entity_set_int(entity, EV_INT_movetype, MOVETYPE_FOLLOW);
			entity_set_edict(entity, EV_ENT_aiment, id);
		}
	}
}

public EventTeamInfo()
{
	new id = read_data(1), entity = g_HatsStorage[id];
	
	if(!is_valid_ent( entity ))
	{
		if(entity > 0)
		{
			g_HatsStorage[id] = 0;
		}

		return;
	}
	
	new szTeam[2];
	read_data(2, szTeam, 1);
	
	if( szTeam[0] == 'C')
	{
		entity_set_model(entity, SantaHats_CT);
	}
	else
	{
		entity_set_model(entity, SantaHats_T);
	}
}

