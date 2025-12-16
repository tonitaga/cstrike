/**
    История изменений:
        0.0.1 (04.02.2024) by b0t.
            - Релиз;
        
        0.0.2 (11.05.2024) by b0t.
            - Оптимизация кода;
            - Поддержка создания нескольких ботов;
        
        0.1.0b (13.05.2024) by b0t.
            - Отказ от реапи за ненадобностью;
            - Настройка имён ботов занесена в файл;
            - Добавлена механика отключения ботов при забитом сервере;
        
        0.1.1b (14.05.2024) by b0t.
            - Исправлена опечатка;
            - Добавлена опция режима отображения ботов;
        
        0.1.2 (21.05.2024) by b0t.
            - Добавлена задержка перед подключением ботов;
        
        1.2.2(bata) (14.10.2024) by b0t.
            - fix несовместимость с другими видами БОТов / Падения сервера;
                *Спасибо за найденный недостаток: https://dev-cs.ru/threads/39752/post-184905
            
            - Переработка метода создания/коннекта ботов;
            - Обновлён метод чтения файла с настройками;
            - Изменено оформление файла с настройками;
*/
new const VERSION[] = "1.2.2(bata)";

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <reapi>

#define CONFIG_NAME         "spectator_bot.ini"

enum _:eFileSection {
    SECTION_NONE,
    SECTION_SETTINGS,
    SECTION_BOT_NAME
};

new
    g_iSectionFile = SECTION_NONE;

new
    g_iMaxEmptySlots,
    g_iMaxSlots;

new
    Array:g_a_BotName,
    Array:g_a_BotNameConnected,
    Array:g_a_BotId,
    g_iMaxBotNum,
    g_iBotNum;

public plugin_init() {
    register_plugin("Spectator Bot",VERSION,"b0t.");

    new szConfigsDir[64];
    get_configsdir(szConfigsDir,charsmax(szConfigsDir));

    add(szConfigsDir,charsmax(szConfigsDir),"/");
    add(szConfigsDir,charsmax(szConfigsDir),CONFIG_NAME);

    Func__CreateFile(szConfigsDir);

    g_a_BotName = ArrayCreate(32);
    g_a_BotNameConnected = ArrayCreate(32);
    g_a_BotId = ArrayCreate();

    new INIParser:iParser = INI_CreateParser();

    INI_SetReaders(iParser,"OnKeyValue","OnNewSection");
    INI_ParseFile(iParser,szConfigsDir);
    INI_DestroyParser(iParser);

    g_iMaxBotNum = ArraySize(g_a_BotName);

    g_iMaxSlots = get_maxplayers();
}

public plugin_cfg() {
    set_task_ex(3.0,"TaskFunc__BotConnected", .flags = SetTask_Repeat);
}

public TaskFunc__BotConnected() {
    if(g_iBotNum == g_iMaxBotNum) {
        return;
    }

    new szReason[128];
    for(new i,pBot,szName[64];i<g_iMaxBotNum;++i) {
        if(!CanConnect()) {
            break;
        }

        ArrayGetString(g_a_BotName,i,szName,charsmax(szName));

        if(ArrayFindString(g_a_BotNameConnected,szName) != -1) {
            continue;
        }

        pBot = engfunc(EngFunc_CreateFakeClient,szName);

        if(!pBot || !pev_valid(pBot)) {
            break;
        }

        engfunc(EngFunc_FreeEntPrivateData,pBot);
        dllfunc(MetaFunc_CallGameEntity,"player",pBot);
        
        set_user_info(pBot,"model","gordon");
        set_user_info(pBot,"*bot","1");

        set_pev(pBot,pev_spawnflags,pev(pBot,pev_spawnflags) | FL_FAKECLIENT);
        set_pev(pBot,pev_flags,pev(pBot,pev_flags) | FL_FAKECLIENT);

        dllfunc(DLLFunc_ClientConnect,pBot,"bot","127.0.0.1",szReason);

        if(!is_user_connected(pBot)) {
            break;
        }

        dllfunc(DLLFunc_ClientPutInServer,pBot);
        
        if(pev_valid(pBot) != 2) {
            break;
        }

        ArrayPushCell(g_a_BotId,pBot);
        // Только ради очередности захода БОТов;
        ArrayPushString(g_a_BotNameConnected,szName);

        RequestFrame("RequestFrame_ChangeNameAndTeam",pBot);
    }

    g_iBotNum = ArraySize(g_a_BotId);
}

public RequestFrame_ChangeNameAndTeam(eEnt) {
    rh_update_user_info(eEnt);
    rg_set_user_team(eEnt,TEAM_SPECTATOR);
}

public client_connect(id) {
    if(is_user_bot(id)) {
        return;
    }

    if(!CanConnect()) {
        if(!g_iBotNum) {
            return;
        }

        new pBot = ArrayGetCell(g_a_BotId,--g_iBotNum);

        ArrayDeleteItem(g_a_BotId,g_iBotNum);
        ArrayDeleteItem(g_a_BotNameConnected,g_iBotNum);

        server_cmd("kick #%i",get_user_userid(pBot));
    }
}

public client_disconnected(id) {
    if(!is_user_bot(id)) {
        return;
    }

    new iItem = ArrayFindValue(g_a_BotId,id);

    if(iItem == -1) {
        return;
    }

    g_iBotNum--;

    ArrayDeleteItem(g_a_BotId,iItem);
    ArrayDeleteItem(g_a_BotNameConnected,iItem);
}

public Func__CreateFile(const szFile[]) {
    if(file_exists(szFile)) {
        return;
    }
    
    write_file(szFile,"[SETTINGS]");
    write_file(szFile,";Кол-во зарезервированных слотов");
    write_file(szFile,"empty_slot = 2");
    write_file(szFile,"");
    write_file(szFile,"[BOT_NAME]");
    write_file(szFile,";Имя бота");
    write_file(szFile,"^"vk.com^"");
    write_file(szFile,"^"server.ru^"");
}

public bool:OnNewSection(INIParser:handle, const section[], bool:invalid_tokens, bool:close_bracket, bool:extra_tokens, curtok, any:data) {
    if(!close_bracket) {
        set_fail_state("[LiteBot] Проверьте правильность заполнения секции [%s]",section);
    }

    if(strcmp(section,"SETTINGS") == 0) {
        g_iSectionFile = SECTION_SETTINGS;

        return true;
    }

    if(strcmp(section,"BOT_NAME") == 0) {
        g_iSectionFile = SECTION_BOT_NAME;

        return true;
    }

    return false;
}

public bool:OnKeyValue(INIParser:handle, const key[], const value[]) {
    switch(g_iSectionFile) {
        case SECTION_NONE: {
            return false;
        }
        case SECTION_SETTINGS: {
            switch(key[0]) {
                case 'e': {
                    g_iMaxEmptySlots = str_to_num(value);
                }
            }
        }
        case SECTION_BOT_NAME: {
            switch(key[0]) {
                case '"': {
                    static szName[32];
                    parse(key,szName,charsmax(szName));

                    ArrayPushString(g_a_BotName,szName);
                }
            }
        }
    }

    return true;
}

stock bool:CanConnect() {
    new iPlayers[32],iAccount;
    get_players_ex(iPlayers,iAccount,GetPlayers_IncludeConnecting);

    return bool:((g_iMaxSlots-iAccount) > g_iMaxEmptySlots);
}
