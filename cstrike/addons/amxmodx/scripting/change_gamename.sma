#include <amxmodx>
#include <amxmisc>
#include <fakemeta>

new const PLUGIN[]  = "Change gamename";
new const VERSION[] = "1.0";
new const AUTHOR[]  = "Tonitaga"

new GameName[64] = "Counter-Strike";

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	register_forward(FM_GetGameDescription, "OnGetGameDescription");
}

public plugin_precache()
{
	PrecacheGamename();
}

public OnGetGameDescription()
{
	forward_return(FMV_STRING, GameName);
	return FMRES_SUPERCEDE;
}

stock PrecacheGamename()
{
	new configDir[256];
	get_configsdir(configDir, charsmax(configDir));

	new configFile[256];
	format(configFile, charsmax(configFile), "%s/change_gamename.ini", configDir);

	if (!file_exists(configFile))
	{
		server_print("[ChangeGamename] Configuration file doesn't exists: %s", configFile);
		return;
	}

	new file = fopen(configFile, "rt");
	if (!file)
	{
		server_print("[ChangeGamename] Can't open configuration file: %s", configFile);
		return;
	}

	new line[256];
	new option[64], value[128];
	while (!feof(file))
	{
		fgets(file, line, charsmax(line));

		if (!line[0] || line[0] == ';' || line[0] == '^n')
		{
			continue;
		}

		if (parse(line, option, charsmax(option), value, charsmax(value)) >= 1)
		{
			if (containi(option, "gamename") != -1)
			{
				server_print("[ChangeGamename] Gamename: %s", value);

				copy(GameName, charsmax(GameName), value);
				break;
			}
		}
	}

	fclose(file);
}