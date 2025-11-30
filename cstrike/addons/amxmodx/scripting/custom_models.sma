// *************************************************************************************//
// Плагин загружен с  www.neugomon.ru                                                   //
// Автор: Neygomon  [ https://neugomon.ru/members/1/ ]                                  //
// Официальная тема поддержки: https://neugomon.ru/threads/2038/                        //
// При копировании материала ссылка на сайт www.neugomon.ru ОБЯЗАТЕЛЬНА!                //
// *************************************************************************************//

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <amxmisc>
#include <incom_print>

#define PLUGIN  "Incomsystem Custom Models"
#define VERSION "1.1"
#define AUTHOR  "smayl1ks and ... Neygomon"

#define ADMIN_FLAG ADMIN_IMMUNITY

enum _:MDL { ACCESS[32], MDL_T[64], MDL_CT[64] }	// ip, steam, flag, #, *. # - steam; * - всем 

#define MAX_MDL 64
new g_iBlockMdl[MAX_MDL];
new g_szModels[MAX_MDL][MDL];

new g_szPlayerModel[33][3][64];
new g_iStandardModelId[33]; // ID стандартной модели из g_szModels

///> Название конфигурационного файла
new const RANDOM_MODELS_CONFIG_FILE[] = "random_models.ini";

///> CVAR переменные
new amx_random_models_enable; // Статус
new amx_random_models_max_players; // Максимальное количество игроков, которые получат случайные модели
new amx_random_models_chance; // Шанс выдачи случайной модели 

enum _:RandomModelPair { MODEL_T[32], MODEL_CT[32] } // Структура для хранения пары моделей
new Array:g_PrecacheRandomModels; // Массив рандомных пар моделей
new g_PrecacheRandomModelsCount = 0

new g_CurrentRandomModelsCount = 0; // Текущее количество рандомных моделек на сервере

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
	
	new configDir[256];
	get_configsdir(configDir, charsmax(configDir));

	new configFile[256];
	format(configFile, charsmax(configFile), "%s/%s", configDir, RANDOM_MODELS_CONFIG_FILE);

	PrecacheRandomModels(configFile);
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	RegisterHam(Ham_Spawn, "player", "fwd_HamSpawn_Post", true);
	register_forward(FM_SetClientKeyValue, "fwd_SetClientKeyValue_Pre", false);

	register_logevent("event_round_start", 2, "1=Round_Start");

	register_dictionary("custom_models.txt");
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
	g_CurrentRandomModelsCount = 0;
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
		return;
	}

	if (amx_random_models_enable && g_CurrentRandomModelsCount < amx_random_models_max_players)
	{
		if (random_num(1, 100) <= amx_random_models_chance)
		{
			setRandomModel(id);
			new player_name[32];
			get_user_name(id, player_name, charsmax(player_name));
			IncomPrint_Client(0, "[%L] %L", LANG_PLAYER, "MODE_NAME", LANG_PLAYER, "PLAYER_GOT_MODEL", player_name);
			g_CurrentRandomModelsCount++;
		}
	}
}

public setRandomModel(id)
{
	if (g_PrecacheRandomModelsCount == 0)
		return;
	
	new random_index = random(g_PrecacheRandomModelsCount);
	new modelPair[RandomModelPair];
	ArrayGetArray(g_PrecacheRandomModels, random_index, modelPair);
	
	copy(g_szPlayerModel[id][1], charsmax(g_szPlayerModel[][]), modelPair[MODEL_T]);
	copy(g_szPlayerModel[id][2], charsmax(g_szPlayerModel[][]), modelPair[MODEL_CT]);
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
	if (!hasStandardModels(id) && g_CurrentRandomModelsCount > 0)
	{
		g_CurrentRandomModelsCount--;
	}

	g_szPlayerModel[id][1][0] = EOS;
	g_szPlayerModel[id][2][0] = EOS;
	g_iStandardModelId[id] = -1;
}

stock PrecacheRandomModels(configFile[])
{
	if (!file_exists(configFile))
	{
		server_print("[RandomModels] Configuration file doesn't exists: %s", configFile);
		return;
	}

	new file = fopen(configFile, "rt");
	if (!file)
	{
		server_print("[RandomModels] Can't open configuration file: %s", configFile);
		return;
	}

	g_PrecacheRandomModels = ArrayCreate(RandomModelPair);
	
	new lineNumber = 0;
	new line[256], model_t[32], model_ct[32];
	new modelPair[RandomModelPair];

	while (!feof(file))
	{
		++lineNumber;
		fgets(file, line, charsmax(line));

		// Пропускаем пустые строки и комментарии
		if (!line[0] || line[0] == ';' || line[0] == '^n')
		{
			continue;
		}

		// Парсим пару моделей
		if (parse(line, model_t, charsmax(model_t), model_ct, charsmax(model_ct)) == 2)
		{

			trim(model_t);
			trim(model_ct);

			copy(modelPair[MODEL_T], charsmax(modelPair[MODEL_T]), model_t);
			copy(modelPair[MODEL_CT], charsmax(modelPair[MODEL_CT]), model_ct);
			
			
			ArrayPushArray(g_PrecacheRandomModels, modelPair);
			g_PrecacheRandomModelsCount++;
			
			
			precache_model(fmt("models/player/%s/%s.mdl", model_t, model_t));
			precache_model(fmt("models/player/%s/%s.mdl", model_ct, model_ct));
			
			server_print("[RandomModels] Loaded model pair: %s (T) -> %s (CT)", model_t, model_ct);
		}
		else
		{
			server_print("[RandomModels] Parsing line error %d: %s", lineNumber, line);
		}
	}

	fclose(file);
	server_print("[RandomModels] Loaded %d model pairs from configuration file", g_PrecacheRandomModelsCount);
}