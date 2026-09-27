/**
    История изменений:
        1.0 (04.03.2022) by b0t.
            - Первый релиз;
        
        1.1 (05.03.2022) by b0t.
            - fix сброса анимации при движении;
            - Сброс анимации после респавна/после смерти;
        
        1.2 (07.03.2022) by b0t.
            - Доступ к меню только для живых игроков;
            - Сброс анимации в момент атаки/перезарядки;
            - Сброс анимации, если игрок по какой либо причине стал видимым;
            - Невозможность создать анимацию если недостаточно места для игрока;
            - Добавлена задержка перед использованием следующей аимации;
            - native;
            - Мультиязычность;
            - Мелкие правки кода;
        
        2.0 (16.03.2022) by b0t.
            - Изменён метод заполнения/чтения файла с настройками;
            - 'костыль' для микрофона в момент удаления анимации;
            - Поддержка мультименю;
            - Отказ от проверки 'Достаточно ли места';
        
        2.1 (22.03.2022) by b0t.
            - fix бага с флагом доступа;
            - Сохранение текущей страницы;
        
        2.3 (03.03.2023) by b0t.
            - Убран спам в консоль серера;
        
        0.2.4	(08.06.2023) by b0t.
            - fix бага с флагами доступа;
		        
		0.2.4f	(03.07.2026) by dreamxleo.
            - добавлен en (англ.) язык в мультиязычность плагина;

        0.2.5 (27.09.2026) by tonitaga
            - добавлена public ручка для бонусного меню anew
            - изменена работа с флагами доступа
                - для пользователей без флагов меню выбора будет закрывать после выбора танца
                - необходимо для реализации бонусного меню
*/

new const VERSION[] = "0.2.5";

#include <amxmodx>
#include <reapi>
#include <fakemeta>
#include <xs>

/**
    Файлы с настройками создаются автоматически:
    configs/plugins/dance_menu.cfg;
    configs/dance_menu.ini;
    amxmodx/data/lang/dance_menu.txt;
*/

#define var_ent_model       var_impulse

enum _:XYZ {
    Float:X,Float:Y,Float:Z
};

enum {
    SECTION_MENU = 0,
    MENU_NAME_,
    MODEL_PATH,
    MODEL_SEQUENCE,
    MODEL_FRAME_RATE,
    MODEL_FLAG_ACCESS,
    MAX_SECTIONS
};

enum _:ArrayData {
    MENU_INDEX[256],
    MENU_NAME[256],
    MODEL_WAY[256],
    SEQUENCE,
    Float:FRAMERATE,
    FLAG_ACCESS
};

stock const ATTACK_BTN = IN_ATTACK|IN_ATTACK2|IN_RELOAD;
stock const g_szCamPrecache[] = "models/rpgrocket.mdl";

new
    Array:g_Array__Dance,
    Array:g_Array__MenuIndex,
    iCamIndex;

new
    g_pCvarrString__FlagAccess[64],
    g_pCvarNum__CamDistance,
    Float:g_pCvarFloat__Flood;

new
    p_iEntityId[33],
    p_iCamId[33],
    Float:p_fFloodDanceMenu[33];

public plugin_precache() {
    ReadSettingsFile();

    if(!ArraySize(g_Array__Dance))
    {
        server_print("[NewDance] No models not");
        server_print("[NewDance] Plugin is state pause");
        
        pause("a");
        return;
    }

    new aData[ArrayData];
    for(new i; i < ArraySize(g_Array__Dance); i++)
    {
        ArrayGetArray(g_Array__Dance, i, aData);

        if(!file_exists(aData[MODEL_WAY]))
        {
            server_print("[NewDance] Bad load model: %s",aData[MODEL_WAY]);
            ArrayDeleteItem(g_Array__Dance, i);
        }
        else
        {
            precache_model(aData[MODEL_WAY]);
        }
    }

    iCamIndex = precache_model(g_szCamPrecache);
}

public plugin_init() {
    register_plugin("Dance Menu",VERSION,"b0t.");

    RegisterCommands("dance", "ShowDanceMenu");

    RegisterHookChain(RG_CBasePlayer_Killed, "OnPlayerKilledAndSpawned", .post = true);
    RegisterHookChain(RG_CBasePlayer_Spawn, "OnPlayerKilledAndSpawned", .post = true);

    register_dictionary("dance_menu.txt");
}

public OnPlayerKilledAndSpawned(const playerId)
{
    if(!is_user_connected(playerId))
    {
        return;
    }

    if(is_nullent(p_iEntityId[playerId]) || is_nullent(p_iCamId[playerId]))
    {
        RemoveModel(p_iEntityId[playerId]);
        RemoveCamera(p_iCamId[playerId]);
    }
}

public pointBonus_RequestDance(const playerId)
{
    if(!is_user_alive(playerId))
    {
        client_print(playerId, print_center, "%L", LANG_PLAYER, "CENTER_ONLY_ALIVE");
        return false;
    }

    ShowDanceMenuFreeAccess(playerId)
    return true;
}

public ShowDanceMenu(const playerId)
{
    if (!IsPlayerHasAccessFlags(playerId))
    {
        return PLUGIN_HANDLED;
    }

    return ShowDanceMenuFreeAccess(playerId)
}

/**
 * Функция показа меню танцев без обработки флагов доступа
 */
public ShowDanceMenuFreeAccess(const playerId)
{
    if(!is_user_alive(playerId))
    {
        client_print(playerId, print_center, "%L", LANG_PLAYER, "CENTER_ONLY_ALIVE");
        return PLUGIN_HANDLED;
    }

    new menu = menu_create(fmt("%L",LANG_PLAYER,"DANCE_MENU_NAME"),"DanceMenuHandler");

    ArrayClear(g_Array__MenuIndex);

    for(new i, aData[ArrayData]; i < ArraySize(g_Array__Dance); i++)
    {
        ArrayGetArray(g_Array__Dance, i, aData);

        if((ArrayFindString(g_Array__MenuIndex,aData[MENU_INDEX])) != -1)
        {
            continue;
        }
        
        if(contain(aData[MENU_INDEX],"_") != -1)
        {
            menu_additem(menu,fmt("%s",aData[MENU_NAME]),fmt("_%i", i), .paccess = aData[FLAG_ACCESS]);
        }
        else
        {
            ArrayPushString(g_Array__MenuIndex,aData[MENU_INDEX]);
            menu_additem(menu,fmt("%s",aData[MENU_INDEX]));
        }
    }

    DisplayMenuToPlayer(playerId, menu, .szExitName = "Выход");
    return PLUGIN_HANDLED;
}

public DanceMenuHandler(const playerId,const menu,const selectedItem) {
    if(selectedItem == MENU_EXIT)
    {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }

    new szData[64],szName[256];
    menu_item_getinfo(menu,selectedItem, .info = szData, .infolen = charsmax(szData), .name = szName, .namelen = charsmax(szName));
    menu_destroy(menu);

    new aData[ArrayData];

    if(contain(szData,"_") != -1)
    {
        if(!IsCreateDanceEntity(playerId))
        {
            ShowDanceMenuFreeAccess(playerId);
            return PLUGIN_HANDLED;
        }

        replace_all(szData,charsmax(szData),"_","");

        ArrayGetArray(g_Array__Dance,str_to_num(szData),aData);

        CreateModels(playerId,aData[MODEL_WAY],aData[SEQUENCE],aData[FRAMERATE],aData[MENU_NAME]);

        p_fFloodDanceMenu[playerId] = get_gametime()+g_pCvarFloat__Flood;
        
        // Продолжать выбор танца можно только если есть соответствующие флаги доступа
        if (IsPlayerHasAccessFlags(playerId))
        {
            ShowDanceMenu(playerId);
        }
    }
    else
    {
        ShowDanceMenuNext(playerId,szName,0);
    }

    return PLUGIN_HANDLED;
}

public ShowDanceMenuNext(const playerId,const szName[],const iPage) {
    new menu = menu_create(szName,"DanceMenuNextHandler");

    for(new i,aData[ArrayData];i<ArraySize(g_Array__Dance);i++)
    {
        ArrayGetArray(g_Array__Dance,i,aData);

        if(contain(aData[MENU_INDEX],"_") != -1)
        {
            continue;
        }
        
        if(!equal(aData[MENU_INDEX],szName))
        {
            continue;
        }    
        
        menu_additem(menu,fmt("%s",aData[MENU_NAME]),fmt("%i|%s",i,szName),aData[FLAG_ACCESS]);
    }

    DisplayMenuToPlayer(playerId,menu,iPage,"В меню");
    return PLUGIN_HANDLED;
}

public DanceMenuNextHandler(const playerId,const menu,const selectedItem)
{
    if(selectedItem == MENU_EXIT)
    {
        menu_destroy(menu);

        ShowDanceMenuFreeAccess(playerId);
        return PLUGIN_HANDLED;
    }

    new menuNew = menu;
    new iPage;
    player_menu_info(playerId,menuNew,menuNew,iPage);

    new szData[64];
    menu_item_getinfo(menu,selectedItem, .info = szData, .infolen = charsmax(szData));
    menu_destroy(menu);

    new szItem[64],szName[256];
    strtok(szData,szItem,charsmax(szItem),szName,charsmax(szName),'|');
    trim(szItem);
    trim(szName);

    // Проверка на спам, если игрок спамит, меню показывается снова
    if(!IsCreateDanceEntity(playerId))
    {
        ShowDanceMenuNext(playerId,szName,iPage);
        return PLUGIN_HANDLED;
    }

    new aData[ArrayData];
    ArrayGetArray(g_Array__Dance,str_to_num(szItem),aData);

    CreateModels(playerId,aData[MODEL_WAY],aData[SEQUENCE],aData[FRAMERATE],aData[MENU_NAME]);

    p_fFloodDanceMenu[playerId] = get_gametime()+g_pCvarFloat__Flood;

    // Продолжать выбор танца можно только если есть соответствующие флаги доступа
    if (IsPlayerHasAccessFlags(playerId))
    {
        ShowDanceMenuNext(playerId,szName,iPage);
    }

    return PLUGIN_HANDLED;
}

public CreateModels(const playerId,const szModel[],const iSequence,const Float:fFrameRate, const danceName[])
{
    RemoveModel(p_iEntityId[playerId]);
    RemoveCamera(p_iCamId[playerId]);

    new iEnt = rg_create_entity("info_target");
    if(is_nullent(iEnt))
    {
        return;
    }

    new iEntModel = rg_create_entity("info_target");
    if(is_nullent(iEntModel))
    {
        return;
    }

    new Float:fOrigin[XYZ],Float:fMins[XYZ],Float:fAngles[XYZ];
    get_entvar(playerId,var_origin,fOrigin);
    get_entvar(playerId,var_mins,fMins);

    fMins[X] = fOrigin[X];
    fMins[Y] = fOrigin[Y];
    fMins[Z] += fOrigin[Z];

    engfunc(EngFunc_SetModel,iEnt,szModel);
    set_entvar(iEnt,var_movetype,MOVETYPE_FLY);
    set_entvar(iEnt,var_ent_model,iEntModel);
    set_entvar(iEnt,var_owner,playerId);

    p_iEntityId[playerId] = iEnt;

    set_entvar(iEntModel,var_movetype,MOVETYPE_FOLLOW);
    set_entvar(iEntModel,var_aiment,iEnt);

    set_entvar(iEnt,var_framerate,fFrameRate);
    set_entvar(iEnt,var_sequence,iSequence);

    get_entvar(playerId,var_angles,fAngles);
    fAngles[X] = 0.0;

    set_entvar(iEnt,var_angles,fAngles);

    engfunc(EngFunc_SetOrigin,iEnt,fMins);
    engfunc(EngFunc_SetOrigin,iEntModel,fMins);

    new szModelNew[256];
    get_user_info(playerId,"model",szModelNew,charsmax(szModelNew));
    format(szModelNew,charsmax(szModelNew),"models/player/%s/%s.mdl",szModelNew,szModelNew);
    engfunc(EngFunc_SetModel,iEntModel,szModelNew);

    set_entvar(iEntModel,var_body,get_entvar(playerId,var_body));
    set_entvar(iEntModel,var_skin,get_entvar(playerId,var_skin));

    set_entvar(iEnt,var_nextthink,get_gametime());
    SetThink(iEnt,"CBaseModel_Think_Post");

    rg_set_user_invisibility(playerId,true);

    new iEntCam = rg_create_entity("trigger_camera");
    if(is_nullent(iEntCam))
    {
        return;
    }
    
    set_entvar(iEntCam,var_modelindex,iCamIndex);
    set_entvar(iEntCam,var_owner,playerId);
    set_entvar(iEntCam,var_movetype,MOVETYPE_NOCLIP);
    set_entvar(iEntCam,var_rendermode,kRenderTransColor);

    engset_view(playerId,iEntCam);

    set_entvar(iEntCam,var_nextthink,get_gametime()+0.01);
    SetThink(iEntCam,"CBaseCam_Think_Post");

    p_iCamId[playerId] = iEntCam;

    //Костыль для микро;
    client_cmd(playerId,"stopsound");

    new name[64];
    get_user_name(playerId, name, charsmax(name));

    client_print_color(0, print_team_default, "[%L] %L", LANG_PLAYER, "DANCE_MENU", LANG_PLAYER, "DANCE_REQUESTED", name, danceName);
}

public RemoveModel(const iEnt)
{
    if(!is_nullent(iEnt)) {
        new playerId = get_entvar(iEnt,var_owner);

        if(is_user_connected(playerId))
        {
            p_iEntityId[playerId] = 0;
            rg_set_user_invisibility(playerId,false);
        }

        if(get_entvar(iEnt,var_ent_model) != 0)
        {
            set_entvar(get_entvar(iEnt,var_ent_model),var_flags,FL_KILLME);
        }

        set_entvar(iEnt,var_flags,FL_KILLME);
    }
}

public RemoveCamera(const iEnt) {
    if(!is_nullent(iEnt))
    {
        new playerId = get_entvar(iEnt,var_owner);

        if(is_user_connected(playerId))
        {
            p_iCamId[playerId] = 0;
            engset_view(playerId,playerId);
            
            //Костыль для микро;
            client_cmd(playerId,"stopsound");
        }

        set_entvar(iEnt,var_flags,FL_KILLME);
    }
}

public CBaseModel_Think_Post(const iEnt) {
    if(is_nullent(iEnt))
    {
        return;
    }

    static playerId;
    playerId = get_entvar(iEnt,var_owner);

    if(!is_user_connected(playerId) || get_entvar(playerId,var_button) & ATTACK_BTN || !rg_get_user_invisibility(playerId) || is_nullent(p_iCamId[playerId]))
    {
        RemoveModel(iEnt);
        return;
    }

    static Float:fOriginId[XYZ],Float:fMins[XYZ],Float:fOriginEnt[XYZ];
    get_entvar(playerId,var_origin,fOriginId);
    get_entvar(iEnt,var_origin,fOriginEnt);

    get_entvar(playerId,var_mins,fMins);
    fMins[X] = fOriginId[X];
    fMins[Y] = fOriginId[Y];
    fMins[Z] += fOriginId[Z];

    if(!xs_vec_equal(fMins,fOriginEnt))
    {
        RemoveModel(iEnt);

        client_print(playerId,print_center,"%L",LANG_PLAYER,"CENTER_DONT_MOVE");
        return;
    }

    set_entvar(iEnt,var_nextthink,get_gametime());
}

public CBaseCam_Think_Post(const iEnt)
{
    if(is_nullent(iEnt))
    {
        return;
    }

    static playerId;
    playerId = get_entvar(iEnt,var_owner);

    if(!is_user_connected(playerId) || is_nullent(p_iEntityId[playerId]))
    {
        RemoveCamera(iEnt);
        return;
    }

    new Float:flPlayerOrigin[XYZ],Float:flCamOrigin[XYZ],Float:flVecPlayerAngles[XYZ],Float:flVecCamAngles[XYZ];

    get_entvar(playerId,var_origin,flPlayerOrigin);
    get_entvar(playerId,var_view_ofs,flVecPlayerAngles);

    flPlayerOrigin[Z] += flVecPlayerAngles[Z];

    get_entvar(playerId,var_v_angle,flVecPlayerAngles);

    angle_vector(flVecPlayerAngles,ANGLEVECTOR_FORWARD,flVecCamAngles);

    xs_vec_sub_scaled(flPlayerOrigin,flVecCamAngles,float(g_pCvarNum__CamDistance), flCamOrigin);

    engfunc(EngFunc_TraceLine,flPlayerOrigin,flCamOrigin,IGNORE_MONSTERS,playerId,0);

    new Float:flFraction;
    get_tr2(0,TR_flFraction,flFraction);

    xs_vec_sub_scaled(flPlayerOrigin,flVecCamAngles,flFraction * float(g_pCvarNum__CamDistance),flCamOrigin);

    set_entvar(iEnt,var_origin,flCamOrigin);
    set_entvar(iEnt,var_angles,flVecPlayerAngles);

    set_entvar(iEnt,var_nextthink,get_gametime()+0.01);
}

public client_putinserver(playerId)
{
    p_iEntityId[playerId] = p_iCamId[playerId] = 0;
}

public ReadSettingsFile() {
    bind_pcvar_string(
        create_cvar(
            .name = "dance_flag_access",
            .string = "a",
            .description = "Флаг доступа к меню"
        ),
        g_pCvarrString__FlagAccess,charsmax(g_pCvarrString__FlagAccess)
    );

    bind_pcvar_num(
        create_cvar(
            .name = "dance_cam_distance",
            .string = "150",
            .description = "Расстояние камеры от игрока"
        ),
        g_pCvarNum__CamDistance
    );

    bind_pcvar_float(
        create_cvar(
            .name = "dance_flood",
            .string = "1.0",
            .description = "Через сколько секунд можно выбрать новый танец"
        ),
        g_pCvarFloat__Flood
    );

    AutoExecConfig(true,"dance_menu");

    new szData[256];
    formatex(szData,charsmax(szData),"addons/amxmodx/data/lang/dance_menu.txt");
    
    if(!file_exists(szData))
    {
        write_file(szData,
            "[ru]^n^n\
            DANCE_MENU_NAME = Выбор движения^n^n\
            CENTER_ONLY_ADMINS = Только для админов!^n\
            CENTER_ONLY_ALIVE = Только для живых игроков!^n\
            CENTER_OFF_GROUND = Вы должны быть на земле!^n\
            CENTER_DONT_FLOOD = Не спамь!^n\
            CENTER_DONT_MOVE = Не двигайся!"
        );
    }

    formatex(szData,charsmax(szData),"addons/amxmodx/configs/dance_menu.ini");

    if(!file_exists(szData))
    {
        write_file(szData,
            ";Название секции где будет пункт | имя в меню | путь до модели | анимация | скорость анимации | флаг доступа^n\
            ;Если требуется добавить в основное меню, в названии секции указать '_'^n\
            ;Если флаг доступа не требуется указать '_'"
        );
    }
    
    g_Array__Dance = ArrayCreate(ArrayData);
    g_Array__MenuIndex = ArrayCreate(256);

    new f = fopen(szData,"r");

    new aData[ArrayData];
    new szFileData[6][256];
    new iLine;
    while(!feof(f))
    {
        fgets(f,szData,charsmax(szData));
        trim(szData);

        iLine++;

        if(szData[0] == ';' || szData[0] == EOS)
        {
            continue;
        }

        if(explode_string(szData,"|",szFileData,sizeof(szFileData),charsmax(szFileData[])) == MAX_SECTIONS)
        {
            RemoveQuotesAndTrim(szFileData[SECTION_MENU]);
            RemoveQuotesAndTrim(szFileData[MENU_NAME_]);
            RemoveQuotesAndTrim(szFileData[MODEL_PATH]);
            RemoveQuotesAndTrim(szFileData[MODEL_SEQUENCE]);
            RemoveQuotesAndTrim(szFileData[MODEL_FRAME_RATE]);
            RemoveQuotesAndTrim(szFileData[MODEL_FLAG_ACCESS]);

            copy(aData[MENU_INDEX],charsmax(aData),szFileData[SECTION_MENU]);
            copy(aData[MENU_NAME],charsmax(aData),szFileData[MENU_NAME_]);
            copy(aData[MODEL_WAY],charsmax(aData),szFileData[MODEL_PATH]);

            aData[SEQUENCE] = str_to_num(szFileData[MODEL_SEQUENCE]);
            aData[FRAMERATE] = str_to_float(szFileData[MODEL_FRAME_RATE]);
            
            aData[FLAG_ACCESS] = strcmp(szFileData[MODEL_FLAG_ACCESS],"_") != 0 ? read_flags(szFileData[MODEL_FLAG_ACCESS]) : ADMIN_ALL;

            ArrayPushArray(g_Array__Dance,aData);
        }
        else
        {
            log_amx("[DanceMenu] Файл [dance_menu.ini] заполнен не верно! Строка: %i",iLine);
        }
    }
    fclose(f);
}

public plugin_natives()
{
    register_native("nd_get_active_dance","native_nd_get_active_dance");
    register_native("nd_remove_dance","native_nd_remove_dance");
}

public bool:native_nd_get_active_dance(iPlugin,iParam)
{
    return bool:(p_iEntityId[get_param(1)] != 0);
}

public native_nd_remove_dance(iPlugin,iParam)
{
    new playerId = get_param(1);

    if(p_iEntityId[playerId]) {
        RemoveModel(p_iEntityId[playerId]);
        RemoveCamera(p_iCamId[playerId]);
    }
}

stock bool:IsCreateDanceEntity(const playerId)
{
    if(!is_user_alive(playerId)) {
        client_print(playerId,print_center,"%L",LANG_PLAYER,"CENTER_ONLY_ALIVE");
        return false;
    }

    if(!(get_entvar(playerId,var_flags) & FL_ONGROUND) || get_entvar(playerId,var_waterlevel) != 0) {
        client_print(playerId,print_center,"%L",LANG_PLAYER,"CENTER_OFF_GROUND");
        return false;
    }

    if((p_fFloodDanceMenu[playerId]-get_gametime()) > 0) {
        client_print(playerId,print_center,"%L",LANG_PLAYER,"CENTER_DONT_FLOOD");
        p_fFloodDanceMenu[playerId] = get_gametime()+g_pCvarFloat__Flood;

        return false;
    }

    return true;
}

stock rg_set_user_invisibility(const playerId, bool:bToggle = true)
{
    new iEffects = get_entvar(playerId,var_effects);
    set_entvar(playerId,var_effects,bToggle ? (iEffects |= EF_NODRAW) : (iEffects &= ~EF_NODRAW))
}

stock bool:rg_get_user_invisibility(const playerId)
{
    return bool:(get_entvar(playerId, var_effects) & EF_NODRAW);
}

stock RegisterCommands(const command[],const funcName[])
{
    register_clcmd(fmt("%s",command),funcName);
    register_clcmd(fmt("say /%s",command),funcName);
    register_clcmd(fmt("say_team /%s",command),funcName);
}

stock DisplayMenuToPlayer(const playerId, const menu, const iPage = 0, const szExitName[] = "Выход")
{
    menu_setprop(menu,MPROP_NEXTNAME,"Далее");
    menu_setprop(menu,MPROP_BACKNAME,"Назад");
    menu_setprop(menu,MPROP_EXITNAME,szExitName);

    menu_setprop(menu,MPROP_NUMBER_COLOR,"\y");

    if(is_user_connected(playerId))
    {
        menu_display(playerId,menu,iPage);
    }
    else
    {
        menu_destroy(menu);
    }
}

stock RemoveQuotesAndTrim(content[])
{
    trim(content);
    remove_quotes(content);
}

stock bool:IsPlayerHasAccessFlags(const playerId)
{
    new accessFlags = read_flags(g_pCvarrString__FlagAccess);
    if(!(get_user_flags(playerId) & accessFlags) && g_pCvarrString__FlagAccess[0])
    {
        return false;
    }
    
    return true;
}