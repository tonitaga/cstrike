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
*/

new const VERSION[] = "0.2.4f";

#include <amxmodx>
#include <reapi>
#include <fakemeta>
#include <xs>

/**
    Файлы с настройками создаются автоматически:
    configs/plugins/Dance.cfg;
    configs/Dance.ini;
    amxmodx/data/lang/Dance.txt;
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
    Func__ReadSettingsFile();

    if(!ArraySize(g_Array__Dance)) {
        server_print("[NewDance] No models not");
        server_print("[NewDance] Plugin is state pause");
        
        pause("a");

        return;
    }

    new aData[ArrayData];
    for(new iItem;iItem<ArraySize(g_Array__Dance);iItem++) {
        ArrayGetArray(g_Array__Dance,iItem,aData);

        if(!file_exists(aData[MODEL_WAY])) {
            server_print("[NewDance] Bad load model: %s",aData[MODEL_WAY]);
            ArrayDeleteItem(g_Array__Dance,iItem);
        }
        else {
            precache_model(aData[MODEL_WAY]);
        }
    }

    iCamIndex = precache_model(g_szCamPrecache);
}

public plugin_init() {
    register_plugin("New Dance Menu",VERSION,"b0t.");

    UTIL__RegisterClCmd("dance","Show__DanceMenu");

    RegisterHookChain(RG_CBasePlayer_Killed,"RG_CBasePlayerKilledAndSpawn_Post", .post = true);
    RegisterHookChain(RG_CBasePlayer_Spawn,"RG_CBasePlayerKilledAndSpawn_Post", .post = true);

    register_dictionary("Dance.txt");
}

public RG_CBasePlayerKilledAndSpawn_Post(const id) {
    if(!is_user_connected(id)) {
        return;
    }

    if(is_nullent(p_iEntityId[id]) || is_nullent(p_iCamId[id])) {
        Func__RemoveModel(p_iEntityId[id]);
        Func__RemoveCam(p_iCamId[id]);
    }
}

public Show__DanceMenu(const id) {
    if(!(get_user_flags(id) & read_flags(g_pCvarrString__FlagAccess)) && g_pCvarrString__FlagAccess[0]) {
        client_print(id,print_center,"%L",LANG_PLAYER,"CENTER_ONLY_ADMINS");
        
        return PLUGIN_HANDLED;
    }

    if(!is_user_alive(id)) {
        client_print(id,print_center,"%L",LANG_PLAYER,"CENTER_ONLY_ALIVE");

        return PLUGIN_HANDLED;
    }

    new iMenu = menu_create(fmt("%L",LANG_PLAYER,"DANCE_MENU_NAME"),"DanceMenu__Handler");

    ArrayClear(g_Array__MenuIndex);

    for(new iItem,aData[ArrayData];iItem<ArraySize(g_Array__Dance);iItem++) {
        ArrayGetArray(g_Array__Dance,iItem,aData);

        if((ArrayFindString(g_Array__MenuIndex,aData[MENU_INDEX])) != -1) {
            continue;
        }
        
        if(contain(aData[MENU_INDEX],"_") != -1) {
            menu_additem(iMenu,fmt("%s",aData[MENU_NAME]),fmt("_%i",iItem), .paccess = aData[FLAG_ACCESS]);
        }
        else {
            ArrayPushString(g_Array__MenuIndex,aData[MENU_INDEX]);
            menu_additem(iMenu,fmt("%s",aData[MENU_INDEX]));
        }
    }

    UTIL__DisplayMenu(id,iMenu, .szExitName = "Выход");
    
    return PLUGIN_HANDLED;
}

public DanceMenu__Handler(const id,const iMenu,const iItem) {
    if(iItem == MENU_EXIT) {
        menu_destroy(iMenu);

        return PLUGIN_HANDLED;
    }
    
    new szData[64],szName[256];
    menu_item_getinfo(iMenu,iItem, .info = szData, .infolen = charsmax(szData), .name = szName, .namelen = charsmax(szName));
    menu_destroy(iMenu);

    new aData[ArrayData];

    if(contain(szData,"_") != -1) {
        if(!UTIL__IsCreateDanceEntity(id)) {
            Show__DanceMenu(id);

            return PLUGIN_HANDLED;
        }

        replace_all(szData,charsmax(szData),"_","");

        ArrayGetArray(g_Array__Dance,str_to_num(szData),aData);

        Func__CreateModels(id,aData[MODEL_WAY],aData[SEQUENCE],aData[FRAMERATE]);

        p_fFloodDanceMenu[id] = get_gametime()+g_pCvarFloat__Flood;
        Show__DanceMenu(id);
    }
    else {
        Show__DanceMenuNext(id,szName,0);
    }

    return PLUGIN_HANDLED;
}

public Show__DanceMenuNext(const id,const szName[],const iPage) {
    new iMenu = menu_create(szName,"DanceMenuNew__Handler");

    for(new i,aData[ArrayData];i<ArraySize(g_Array__Dance);i++) {
        ArrayGetArray(g_Array__Dance,i,aData);

        if(contain(aData[MENU_INDEX],"_") != -1) {
            continue;
        }
        
        if(!equal(aData[MENU_INDEX],szName)) {
            continue;
        }    
        
        menu_additem(iMenu,fmt("%s",aData[MENU_NAME]),fmt("%i|%s",i,szName),aData[FLAG_ACCESS]);
    }

    UTIL__DisplayMenu(id,iMenu,iPage,"В меню");

    return PLUGIN_HANDLED;
}

public DanceMenuNew__Handler(const id,const iMenu,const iItem) {
    if(iItem == MENU_EXIT) {
        menu_destroy(iMenu);

        Show__DanceMenu(id);

        return PLUGIN_HANDLED;
    }

    new iMenuNew = iMenu;
    new iPage;
    player_menu_info(id,iMenuNew,iMenuNew,iPage);

    new szData[64];
    menu_item_getinfo(iMenu,iItem, .info = szData, .infolen = charsmax(szData));
    menu_destroy(iMenu);

    new szItem[64],szName[256];
    strtok(szData,szItem,charsmax(szItem),szName,charsmax(szName),'|');
    trim(szItem);
    trim(szName);

    if(!UTIL__IsCreateDanceEntity(id)) {
        Show__DanceMenuNext(id,szName,iPage);

        return PLUGIN_HANDLED;
    }

    new aData[ArrayData];
    ArrayGetArray(g_Array__Dance,str_to_num(szItem),aData);

    Func__CreateModels(id,aData[MODEL_WAY],aData[SEQUENCE],aData[FRAMERATE]);

    p_fFloodDanceMenu[id] = get_gametime()+g_pCvarFloat__Flood;
    Show__DanceMenuNext(id,szName,iPage);

    return PLUGIN_HANDLED;
}

public Func__CreateModels(const id,const szModel[],const iSequence,const Float:fFrameRate) {
    Func__RemoveModel(p_iEntityId[id]);
    Func__RemoveCam(p_iCamId[id]);

    new iEnt = rg_create_entity("info_target");

    if(is_nullent(iEnt)) {
        return;
    }

    new iEntModel = rg_create_entity("info_target");

    if(is_nullent(iEntModel)) {
        return;
    }

    new Float:fOrigin[XYZ],Float:fMins[XYZ],Float:fAngles[XYZ];
    get_entvar(id,var_origin,fOrigin);
    get_entvar(id,var_mins,fMins);

    fMins[X] = fOrigin[X];
    fMins[Y] = fOrigin[Y];
    fMins[Z] += fOrigin[Z];

    engfunc(EngFunc_SetModel,iEnt,szModel);
    set_entvar(iEnt,var_movetype,MOVETYPE_FLY);
    set_entvar(iEnt,var_ent_model,iEntModel);
    set_entvar(iEnt,var_owner,id);

    p_iEntityId[id] = iEnt;

    set_entvar(iEntModel,var_movetype,MOVETYPE_FOLLOW);
    set_entvar(iEntModel,var_aiment,iEnt);

    set_entvar(iEnt,var_framerate,fFrameRate);
    set_entvar(iEnt,var_sequence,iSequence);

    get_entvar(id,var_angles,fAngles);
    fAngles[X] = 0.0;

    set_entvar(iEnt,var_angles,fAngles);

    engfunc(EngFunc_SetOrigin,iEnt,fMins);
    engfunc(EngFunc_SetOrigin,iEntModel,fMins);

    new szModelNew[256];
    get_user_info(id,"model",szModelNew,charsmax(szModelNew));
    format(szModelNew,charsmax(szModelNew),"models/player/%s/%s.mdl",szModelNew,szModelNew);
    engfunc(EngFunc_SetModel,iEntModel,szModelNew);

    set_entvar(iEntModel,var_body,get_entvar(id,var_body));
    set_entvar(iEntModel,var_skin,get_entvar(id,var_skin));

    set_entvar(iEnt,var_nextthink,get_gametime());
    SetThink(iEnt,"CBaseModel_Think_Post");

    rg_set_user_invisibility(id,true);

    new iEntCam = rg_create_entity("trigger_camera");

    if(is_nullent(iEntCam)) {
        return;
    }
    
    set_entvar(iEntCam,var_modelindex,iCamIndex);
    set_entvar(iEntCam,var_owner,id);
    set_entvar(iEntCam,var_movetype,MOVETYPE_NOCLIP);
    set_entvar(iEntCam,var_rendermode,kRenderTransColor);

    engset_view(id,iEntCam);

    set_entvar(iEntCam,var_nextthink,get_gametime()+0.01);
    SetThink(iEntCam,"CBaseCam_Think_Post");

    p_iCamId[id] = iEntCam;

    //Костыль для микро;
    client_cmd(id,"stopsound");
}

public Func__RemoveModel(const iEnt) {
    if(!is_nullent(iEnt)) {
        new id = get_entvar(iEnt,var_owner);

        if(is_user_connected(id)) {
            p_iEntityId[id] = 0;
            rg_set_user_invisibility(id,false);
        }

        if(get_entvar(iEnt,var_ent_model) != 0) {
            set_entvar(get_entvar(iEnt,var_ent_model),var_flags,FL_KILLME);
        }

        set_entvar(iEnt,var_flags,FL_KILLME);
    }
}

public Func__RemoveCam(const iEnt) {
    if(!is_nullent(iEnt)) {
        new id = get_entvar(iEnt,var_owner);

        if(is_user_connected(id)) {
            p_iCamId[id] = 0;
            engset_view(id,id);
            
            //Костыль для микро;
            client_cmd(id,"stopsound");
        }

        set_entvar(iEnt,var_flags,FL_KILLME);
    }
}

public CBaseModel_Think_Post(const iEnt) {
    if(is_nullent(iEnt)) {
        return;
    }

    static id;
    id = get_entvar(iEnt,var_owner);

    if(!is_user_connected(id) || get_entvar(id,var_button) & ATTACK_BTN || !rg_get_user_invisibility(id) || is_nullent(p_iCamId[id])) {
        Func__RemoveModel(iEnt);
        return;
    }

    static Float:fOriginId[XYZ],Float:fMins[XYZ],Float:fOriginEnt[XYZ];
    get_entvar(id,var_origin,fOriginId);
    get_entvar(iEnt,var_origin,fOriginEnt);

    get_entvar(id,var_mins,fMins);
    fMins[X] = fOriginId[X];
    fMins[Y] = fOriginId[Y];
    fMins[Z] += fOriginId[Z];

    if(!xs_vec_equal(fMins,fOriginEnt)) {
        Func__RemoveModel(iEnt);

        client_print(id,print_center,"%L",LANG_PLAYER,"CENTER_DONT_MOVE");
        return;
    }

    set_entvar(iEnt,var_nextthink,get_gametime());
}

public CBaseCam_Think_Post(const iEnt) {
    if(is_nullent(iEnt)) {
        return;
    }

    static id;
    id = get_entvar(iEnt,var_owner);

    if(!is_user_connected(id) || is_nullent(p_iEntityId[id])) {
        Func__RemoveCam(iEnt);
        return;
    }

    new Float:flPlayerOrigin[XYZ],Float:flCamOrigin[XYZ],Float:flVecPlayerAngles[XYZ],Float:flVecCamAngles[XYZ];

    get_entvar(id,var_origin,flPlayerOrigin);
    get_entvar(id,var_view_ofs,flVecPlayerAngles);

    flPlayerOrigin[Z] += flVecPlayerAngles[Z];

    get_entvar(id,var_v_angle,flVecPlayerAngles);

    angle_vector(flVecPlayerAngles,ANGLEVECTOR_FORWARD,flVecCamAngles);

    xs_vec_sub_scaled(flPlayerOrigin,flVecCamAngles,float(g_pCvarNum__CamDistance), flCamOrigin);

    engfunc(EngFunc_TraceLine,flPlayerOrigin,flCamOrigin,IGNORE_MONSTERS,id,0);

    new Float:flFraction;
    get_tr2(0,TR_flFraction,flFraction);

    xs_vec_sub_scaled(flPlayerOrigin,flVecCamAngles,flFraction * float(g_pCvarNum__CamDistance),flCamOrigin);

    set_entvar(iEnt,var_origin,flCamOrigin);
    set_entvar(iEnt,var_angles,flVecPlayerAngles);

    set_entvar(iEnt,var_nextthink,get_gametime()+0.01);
}

public client_putinserver(id) {
    p_iEntityId[id] = p_iCamId[id] = 0;
}

public Func__ReadSettingsFile() {
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

    AutoExecConfig(true,"Dance");

    new szData[256];
    formatex(szData,charsmax(szData),"addons/amxmodx/data/lang/Dance.txt");
    
    if(!file_exists(szData)) {
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

    formatex(szData,charsmax(szData),"addons/amxmodx/configs/Dance.ini");

    if(!file_exists(szData)) {
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
    while(!feof(f)) {
        fgets(f,szData,charsmax(szData));
        trim(szData);

        iLine++;

        if(szData[0] == ';' || szData[0] == EOS) {
            continue;
        }

        if(explode_string(szData,"|",szFileData,sizeof(szFileData),charsmax(szFileData[])) == MAX_SECTIONS) {
            remove_quotes_and_trim(szFileData[SECTION_MENU]);
            remove_quotes_and_trim(szFileData[MENU_NAME_]);
            remove_quotes_and_trim(szFileData[MODEL_PATH]);
            remove_quotes_and_trim(szFileData[MODEL_SEQUENCE]);
            remove_quotes_and_trim(szFileData[MODEL_FRAME_RATE]);
            remove_quotes_and_trim(szFileData[MODEL_FLAG_ACCESS]);

            copy(aData[MENU_INDEX],charsmax(aData),szFileData[SECTION_MENU]);
            copy(aData[MENU_NAME],charsmax(aData),szFileData[MENU_NAME_]);
            copy(aData[MODEL_WAY],charsmax(aData),szFileData[MODEL_PATH]);

            aData[SEQUENCE] = str_to_num(szFileData[MODEL_SEQUENCE]);
            aData[FRAMERATE] = str_to_float(szFileData[MODEL_FRAME_RATE]);
            
            aData[FLAG_ACCESS] = strcmp(szFileData[MODEL_FLAG_ACCESS],"_") != 0 ? read_flags(szFileData[MODEL_FLAG_ACCESS]) : ADMIN_ALL;

            ArrayPushArray(g_Array__Dance,aData);
        }
        else {
            log_amx("[DanceMenu] Файл [Dance.ini] заполнен не верно! Строка: %i",iLine);
        }
    }
    fclose(f);
}

public plugin_natives() {
    register_native("nd_get_active_dance","native_nd_get_active_dance");
    register_native("nd_remove_dance","native_nd_remove_dance");
}

public bool:native_nd_get_active_dance(iPlugin,iParam) {
    return bool:(p_iEntityId[get_param(1)] != 0);
}

public native_nd_remove_dance(iPlugin,iParam) {
    new id = get_param(1);

    if(p_iEntityId[id]) {
        Func__RemoveModel(p_iEntityId[id]);
        Func__RemoveCam(p_iCamId[id]);
    }
}

stock bool:UTIL__IsCreateDanceEntity(const id) {
    if(!is_user_alive(id)) {
        client_print(id,print_center,"%L",LANG_PLAYER,"CENTER_ONLY_ALIVE");
        return false;
    }

    if(!(get_entvar(id,var_flags) & FL_ONGROUND) || get_entvar(id,var_waterlevel) != 0) {
        client_print(id,print_center,"%L",LANG_PLAYER,"CENTER_OFF_GROUND");
        return false;
    }

    if((p_fFloodDanceMenu[id]-get_gametime()) > 0) {
        client_print(id,print_center,"%L",LANG_PLAYER,"CENTER_DONT_FLOOD");
        p_fFloodDanceMenu[id] = get_gametime()+g_pCvarFloat__Flood;

        return false;
    }

    return true;
}

stock rg_set_user_invisibility(const id, bool:bToggle = true) {
    new iEffects = get_entvar(id,var_effects);
    set_entvar(id,var_effects,bToggle ? (iEffects |= EF_NODRAW) : (iEffects &= ~EF_NODRAW))
}

stock bool:rg_get_user_invisibility(const id) {
    return bool:(get_entvar(id, var_effects) & EF_NODRAW);
}

stock UTIL__RegisterClCmd(const szCmd[],const szFunc[]) {
    register_clcmd(fmt("%s",szCmd),szFunc);
    register_clcmd(fmt("say /%s",szCmd),szFunc);
    register_clcmd(fmt("say_team /%s",szCmd),szFunc);
}

stock UTIL__DisplayMenu(const id,const iMenu,const iPage = 0,const szExitName[] = "Выход") {
    menu_setprop(iMenu,MPROP_NEXTNAME,"Далее");
    menu_setprop(iMenu,MPROP_BACKNAME,"Назад");
    menu_setprop(iMenu,MPROP_EXITNAME,szExitName);

    menu_setprop(iMenu,MPROP_NUMBER_COLOR,"\y");

    if(is_user_connected(id))
        menu_display(id,iMenu,iPage);
    else
        menu_destroy(iMenu);
}

stock remove_quotes_and_trim(szSource[]) {
    trim(szSource);
    remove_quotes(szSource);
}