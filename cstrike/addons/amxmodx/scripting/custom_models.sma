// *************************************************************************************//
// Плагин загружен с  www.neugomon.ru                                                   //
// Автор: Neygomon  [ https://neugomon.ru/members/1/ ]                                  //
// Официальная тема поддержки: https://neugomon.ru/threads/2038/                        //
// При копировании материала ссылка на сайт www.neugomon.ru ОБЯЗАТЕЛЬНА!                //
// *************************************************************************************//

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <incom_print>

#define PLUGIN  "Incomsystem Custom Models"
#define VERSION "1.0"
#define AUTHOR  "smayl1ks and ... Neygomon"

#define ADMIN_FLAG ADMIN_IMMUNITY

#define RANDOM_MODELS_COMMAND_SAY           "say /random_models"
#define RANDOM_MODELS_COMMAND_SAY_TEAM      "say_team /random_models"

enum _:MDL { ACCESS[32], MDL_T[64], MDL_CT[64] }	// ip, steam, flag, #, *. # - steam; * - всем 

#define MAX_MDL 64
new g_iBlockMdl[MAX_MDL];
new g_szModels[MAX_MDL][MDL];

new g_szPlayerModel[33][3][64];
new g_iStandardModelId[33]; // ID стандартной модели из g_szModels

///> Название конфигурационного файла
// new const CONFIG_FILE[] = "random_models.ini";

///> CVAR переменные
new amx_random_models_enable; // Статус
new amx_random_models_max_players; // Максимальное количество игроков, которые получат случайные модели
new amx_random_models_chance; // Шанс выдачи случайной модели 

new g_RandomModelCnt = 0; // Текущее количество рандомных моделек на сервере

new const g_Dobby_t[] = "dobby_t";
new const g_Dobby_ct[] = "dobby_ct";

public plugin_precache()
{
	new fp = fopen("addons/amxmodx/configs/custom_models.ini", "rt");
	if(!fp) set_fail_state("File addons/amxmodx/configs/custom_models.ini not found!");
	
	new buff[190], x;
	while(!feof(fp))
	{
		fgets(fp, buff, charsmax(buff)); trim(buff);
		if(!buff[0] || buff[0] == ';')
			continue;
		if(parse(buff, 
			g_szModels[x][ACCESS], charsmax(g_szModels[][ACCESS]), 
			g_szModels[x][MDL_T], charsmax(g_szModels[][MDL_T]), 
			g_szModels[x][MDL_CT], charsmax(g_szModels[][MDL_CT])) == 3
		) x++;
	}
	fclose(fp);
	if(!x) set_fail_state("File addons/amxmodx/configs/custom_models.ini incorrect!");

	for(new i, t, ct, str[64]; i < sizeof g_szModels; i++)
	{
		formatex(str, charsmax(str), "models/player/%s/%s.mdl", g_szModels[i][MDL_T], g_szModels[i][MDL_T]);
		t = file_exists(str);
		if(t) precache_model(str);
		
		formatex(str, charsmax(str), "models/player/%s/%s.mdl", g_szModels[i][MDL_CT], g_szModels[i][MDL_CT]);
		ct = file_exists(str);
		if(ct) precache_model(str);
		
		g_iBlockMdl[i] = (!t && !ct);
	}

	new dobby_model[64];
	
	formatex(dobby_model, charsmax(dobby_model), "models/player/%s/%s.mdl", g_Dobby_t, g_Dobby_t);
	if(file_exists(dobby_model)) 
	{
		precache_model(dobby_model);
	}
	else
	{
		log_amx("Модель Добби для террористов не найдена: %s", dobby_model);
	}
	
	formatex(dobby_model, charsmax(dobby_model), "models/player/%s/%s.mdl", g_Dobby_ct, g_Dobby_ct);
	if(file_exists(dobby_model)) 
	{
		precache_model(dobby_model);
	}
	else 
	{
		log_amx("Модель Добби для контр-террористов не найдена: %s", dobby_model);
	}
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	RegisterHam(Ham_Spawn, "player", "fwd_HamSpawn_Post", true);
	register_forward(FM_SetClientKeyValue, "fwd_SetClientKeyValue_Pre", false);

	register_logevent("event_round_start", 2, "1=Round_Start");

	// register_clcmd(RANDOM_MODELS_COMMAND_SAY, "ShowRandomModelsMenu");
	// register_clcmd(RANDOM_MODELS_COMMAND_SAY_TEAM, "ShowRandomModelsMenu");

	// Команды для изменения настроек
	// register_clcmd("set_max_players", "cmdSetMaxPlayers");
	// register_clcmd("set_model_chance", "cmdSetModelChance");

	// register_dictionary("random_models.txt");
}

public plugin_cfg()
{
	bind_pcvar_num(
		create_cvar(
			"amx_random_models_enable", "0",
			.has_min = true, .min_val = 0.0,
			.has_max = true, .max_val = 1.0,
			.description = "Статус плагина случайных моделей^n\
							0 - Отключен^n\
							1 - Включен"
		),
		amx_random_models_enable
	);

	bind_pcvar_num(
		create_cvar(
			"amx_random_models_max_players", "1",
			.has_min = true, .min_val = 1.0,
			.has_max = true, .max_val = 32.0,
			.description = "Максимальное количество игроков, которые получат случайные модели за раунд"
		),
		amx_random_models_max_players
	);

	bind_pcvar_num(
		create_cvar(
			"amx_random_models_chance", "25",
			.has_min = true, .min_val = 1.0,
			.has_max = true, .max_val = 100.0,
			.description = "Шанс выдачи случайной модели игроку (1-100)%"
		),
		amx_random_models_chance
	);

	AutoExecConfig();
}

public event_round_start()
{
	g_RandomModelCnt = 0;
}

public client_putinserver(id)
{
	new szIP[16]; get_user_ip(id, szIP, charsmax(szIP), 1);
	new szAuthid[25]; get_user_authid(id, szAuthid, charsmax(szAuthid));
	new flags = get_user_flags(id);

	g_szPlayerModel[id][1][0] = EOS;
	g_szPlayerModel[id][2][0] = EOS;
	g_iStandardModelId[id] = -1;
	
	for(new i; i < sizeof g_szModels; i++)
	{
		if(g_iBlockMdl[i] == 1)
			continue;

		switch(g_szModels[i][ACCESS][0])
		{
			case '#':
				if(is_user_steam(id)) 
				{ 
					CopyModel(id, i);
					g_iStandardModelId[id] = i;
					break;
				}	
			case '*':
				{ 
					CopyModel(id, i);
					g_iStandardModelId[id] = i;
					break;
				}
			case 'S':
				if(strcmp(g_szModels[i][ACCESS], szAuthid) == 0)
				{ 
					CopyModel(id, i);
					g_iStandardModelId[id] = i;
					break;
				}
			default:
				if(isdigit(g_szModels[i][ACCESS][0]))
				{
					if(strcmp(g_szModels[i][ACCESS], szIP) == 0)
					{ 
						CopyModel(id, i);
						g_iStandardModelId[id] = i;
						break;
					}
				}
				else if(flags & read_flags(g_szModels[i][ACCESS]))
				{ 
					CopyModel(id, i);
					g_iStandardModelId[id] = i;
					break;
				}
		}
	}
}

public fwd_HamSpawn_Post(id)
{
	if(!is_user_alive(id))
		return;
	
	changePlayerModel(id);
	applyPlayerModel(id);
}

public setDefaultModel(id)
{
	if (g_iStandardModelId[id] != -1)
	{
		CopyModel(id, g_iStandardModelId[id]);
	}
}

public changePlayerModel(id)
{
	if (!hasStandardModels(id))
	{
		setDefaultModel(id);
	}

	if (amx_random_models_enable && g_RandomModelCnt < amx_random_models_max_players)
	{
		if (random_num(1, 100) <= amx_random_models_chance)
		{
			new player_name[32];
			get_user_name(id, player_name, charsmax(player_name));
			//IncomPrint_Client(0, "[%L] %L", 0, "RANDOM_MODELS", 0, "YOU_GOT_MODEL", player_name, model_name);
			client_print(0, print_chat, "[RandomModels] Игроку ^"%s^" выпала модель Добби!", player_name);
			setDobbyModel(id);
			g_RandomModelCnt++;
		}
	}
}

public setDobbyModel(id)
{
	copy(g_szPlayerModel[id][1], charsmax(g_szPlayerModel[][]), g_Dobby_t);
	copy(g_szPlayerModel[id][2], charsmax(g_szPlayerModel[][]), g_Dobby_ct);
}

public applyPlayerModel(id)
{
	switch(get_pdata_int(id, 114))
	{
		case 1: 
		{
			if(g_szPlayerModel[id][1][0]) 
				fmSetModel(id, g_szPlayerModel[id][1]);
		}
		case 2: 
		{
			if(g_szPlayerModel[id][2][0]) 
				fmSetModel(id, g_szPlayerModel[id][2]);
		}
	}
}

bool:hasStandardModels(id)
{
	if (g_iStandardModelId[id] == -1)
		return false;
	
	return (equal(g_szPlayerModel[id][1], g_szModels[g_iStandardModelId[id]][MDL_T]) && 
			equal(g_szPlayerModel[id][2], g_szModels[g_iStandardModelId[id]][MDL_CT]));
}

public fwd_SetClientKeyValue_Pre(id, const szInfobuffer[], const szKey[], const szValue[])
{	
	if(strcmp(szKey, "model") != 0)
		return FMRES_IGNORED;
	static iTeam; iTeam = get_pdata_int(id, 114);
	if(iTeam != 1 && iTeam != 2)
		return FMRES_IGNORED;
	if(g_szPlayerModel[id][iTeam][0] && strcmp(szValue, g_szPlayerModel[id][iTeam]) != 0)
	{
		fmSetModel(id, g_szPlayerModel[id][iTeam]);
		return FMRES_SUPERCEDE;
	}
	return FMRES_IGNORED;	
}

stock CopyModel(index, sId)
{
	copy(g_szPlayerModel[index][1], charsmax(g_szPlayerModel[][]), g_szModels[sId][MDL_T]);
	copy(g_szPlayerModel[index][2], charsmax(g_szPlayerModel[][]), g_szModels[sId][MDL_CT]);
}

stock fmSetModel(id, const model[])
	engfunc(EngFunc_SetClientKeyValue, id, engfunc(EngFunc_GetInfoKeyBuffer, id), "model", model);
	
bool:is_user_steam(id)
{
	new dp_pointer = get_cvar_pointer("dp_r_id_provider");
	if(!dp_pointer) 
		return false;
	
	server_cmd("dp_clientinfo %d", id);
	server_exec();
	return (get_pcvar_num(dp_pointer) == 2);
}

public client_disconnected(id)
{
	// Очищаем данные игрока
	g_szPlayerModel[id][1][0] = EOS;
	g_szPlayerModel[id][2][0] = EOS;
	g_iStandardModelId[id] = -1;
}