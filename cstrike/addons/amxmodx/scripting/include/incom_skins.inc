#if defined _incom_skins_included
    #endinput
#endif
#define _incom_skins_included

#include <amxmodx>
#include <sqlx>

new const INCOM_SKINS_DB_ENGINE[] = "sqlite"
new const INCOM_SKINS_DB_NAME[] = "incom_skins";

public Handle:IncomSkins_GetHandle()
{
    SQL_SetAffinity(INCOM_SKINS_DB_ENGINE);
    new Handle:dbHandle = SQL_MakeDbTuple("", "", "", INCOM_SKINS_DB_NAME);

    return dbHandle;
}

public IncomSkins_CreateTable(Handle:dbHandle, const tableName[])
{
	new Query[512];
	formatex(Query, charsmax(Query),
        "CREATE TABLE IF NOT EXISTS `%s` (     \
            `steam_id` VARCHAR(32) PRIMARY KEY,\
            `skin_index` INTEGER               \
        );", tableName);

	SQL_ThreadQuery(dbHandle, "IncomSkins_IgnoreHandle", Query);
}

public IncomSkins_LoadUserSkin(Handle:dbHandle, const tableName[], playerId, const queryHandler[])
{
	new authid[32];
	get_user_authid(playerId, authid, charsmax(authid));

	if(equal(authid, "ID_PENDING"))
	{
		set_task(1.0, "IncomSkins_LoadUserSkin", playerId);
		return;
	}

	new Query[256];
	formatex(Query, charsmax(Query),
        "SELECT `skin_index` FROM `%s` WHERE `steam_id` = '%s';", tableName, authid);

	new data[2];
	data[0] = playerId;

	SQL_ThreadQuery(dbHandle, queryHandler, Query, data, sizeof(data));
}

public IncomSkins_SaveUserSkin(Handle:dbHandle, const tableName[], playerId, skinIndex)
{
	if(is_user_bot(playerId) || !is_user_connected(playerId))
		return;
	
	new authid[32];
	get_user_authid(playerId, authid, charsmax(authid));
	
	if(equal(authid, "ID_PENDING"))
		return;
	
	new Query[256];
	formatex(Query, charsmax(Query), "REPLACE INTO `%s` (`steam_id`, `skin_index`) VALUES ('%s', %d);", tableName, authid, skinIndex);
	
	SQL_ThreadQuery(dbHandle, "IncomSkins_IgnoreHandle", Query);
}

public IncomSkins_IgnoreHandle(failstate, Handle:query, error[], errcode, data[], size)
{
	if(failstate != TQUERY_SUCCESS)
	{
		log_amx("incom_skins error: %s", error);
	}
}