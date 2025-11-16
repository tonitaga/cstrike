#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <reapi>

public plugin_precache()
{
	register_plugin("Snow", "1.0.0", "fl0wer");

	rg_create_entity("env_snow", true);

	new fog = rg_create_entity("env_fog", false);

	if (!is_nullent(fog))
	{
		fm_set_kvd(fog, "density", "0.00040", "env_fog");
		fm_set_kvd(fog, "rendercolor", "100 100 100", "env_fog");
	}
}

fm_set_kvd(entity, const key[], const value[], const classname[])
{
	set_kvd(0, KV_ClassName, classname);
	set_kvd(0, KV_KeyName, key);
	set_kvd(0, KV_Value, value);
	set_kvd(0, KV_fHandled, 0);

	dllfunc(DLLFunc_KeyValue, entity, 0);
}
