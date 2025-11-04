#include <amxmodx>
#include <fakemeta>
#include <reapi>
#include <xs>

#define fWidth          65.0    // Максимальная ширина спрея
#define fHeight         50.0    // Максимальная высота спрея
#define MAX_DISTANCE    128.0   // Максимальная дистанция
#define DECALFREQ       2.0     // Задержка перед следующим использованием

#define GraffityLive    30.0    // Время "жизни" графити

new const GraffityModels[] = "models/incom/graffiti/logo.mdl";
new const GraffityPaint[]  = "Graffity/spraycan_spray.wav";

#define GrafityClass    "Grafity"
new Float:fSize, iMdlIndex;

public plugin_init() {
    register_plugin
    (
        "[AMXX] Graffity",
        "1.0",
        "Flymic24"
    );
   
    RegisterHookChain(RG_CBasePlayer_ImpulseCommands, "HookPlayer_ImpulseCommands", false);
}

public plugin_precache(){
    precache_sound(GraffityPaint);
   
    fSize = (fHeight + fWidth) / 2.0;
    iMdlIndex = precache_model(GraffityModels);
}

public HookPlayer_ImpulseCommands(const iPlayer)
{
    if (!is_user_connected(iPlayer))
        return HC_CONTINUE;
   
    if(get_entvar(iPlayer, var_impulse) != 201)
        return HC_CONTINUE;
   
    set_entvar(iPlayer, var_impulse, 0);
   
    new Float:fNextDecalTime = get_member(iPlayer, m_flNextDecalTime);
    new Float:fGameTime = get_gametime();
   
    if (fGameTime < fNextDecalTime){
        client_print(iPlayer, print_center, "Ждите ещё: %0.2f сек", fNextDecalTime - fGameTime);
        return HC_SUPERCEDE;
    }
   
    new Float:fOrigin[3], Float:fAngles[3];
    if(!get_corrected_origin(iPlayer, fOrigin, fAngles)){
        client_print(iPlayer, print_center, "Не подходящее место");
        return HC_SUPERCEDE;
    }
   
    CreateGrafity(iPlayer, fOrigin, fAngles);
   
    set_member(iPlayer, m_flNextDecalTime, fGameTime + DECALFREQ);
   
    return HC_SUPERCEDE;
}
#if defined GraffityLive
public RemoveGrafity(const iGraffity){
    if (!pev_valid(iGraffity))
        return;
   
    set_entvar(iGraffity, var_flags, get_entvar(iGraffity, var_flags) | FL_KILLME);
}
#endif
public CreateGrafity(iPlayer, Float:fVecEnd[3], Float:fAngles[3]){
   
    new iGrafity;    iGrafity = rg_create_entity("info_target");
   
    if (!iGrafity)    return -1;
   
    set_entvar(iGrafity, var_classname, GrafityClass);
    set_entvar(iGrafity, var_model, GraffityModels);
    set_entvar(iGrafity, var_modelindex, iMdlIndex);
   
    set_entvar(iGrafity, var_movetype, MOVETYPE_FLY);
    set_entvar(iGrafity, var_solid, SOLID_NOT);
    set_entvar(iGrafity, var_owner, iPlayer);
   
    //    set_entvar(iGrafity, var_skin, random(62));
   
    // set origin and angles
    set_entvar(iGrafity, var_origin, fVecEnd);
    set_entvar(iGrafity, var_angles, fAngles);
#if defined GraffityLive
    set_entvar(iGrafity, var_nextthink, get_gametime() + GraffityLive);
   
    SetThink(iGrafity, "RemoveGrafity");
#endif  
    rh_emit_sound2(iPlayer, iPlayer, CHAN_VOICE, GraffityPaint);
   
    return iGrafity;
}

#define xs_1_neg(%1)    %1 = -%1
#define ADD_UNITS        2.0

stock bool: get_corrected_origin(id, Float:fOriginEnd[3], Float:fAnglesNormal[3])
{
    new Float:fTemp[3];
    new Float:fWallNormal[3], Float:fAimOrigin[3];
    get_wall_normal(id, fWallNormal, fAimOrigin);
   
    xs_vec_copy(fWallNormal, fAnglesNormal);
    xs_vec_copy(fAimOrigin, fOriginEnd);
   
    xs_vec_mul_scalar(fAnglesNormal, ADD_UNITS, fTemp);
    xs_vec_add(fTemp, fAimOrigin, fAimOrigin);
   
    new Float:fWallAngles[3];
    vector_to_angle(fWallNormal, fWallAngles);
   
    new Float:fUpNormal[3], Float:fRightNormal[3];
    angle_vector(fWallAngles, ANGLEVECTOR_UP, fUpNormal);
    angle_vector(fWallAngles, ANGLEVECTOR_RIGHT, fRightNormal);
   
    xs_1_neg(fUpNormal[2]);
   
    new Float:fUpLeftPoint[3], Float:fUpRightPoint[3], Float:fDownLeftPoint[3], Float:fDownRightPoint[3];
    xs_vec_mul_scalar(fUpNormal, fHeight / 2, fUpNormal);
    xs_vec_mul_scalar(fRightNormal, fWidth / 2, fRightNormal);
   
    //1
    xs_vec_add(fUpNormal, fRightNormal, fUpRightPoint);
    xs_vec_add(fUpRightPoint, fAimOrigin, fUpRightPoint);
   
    //2
    xs_vec_neg(fRightNormal, fRightNormal);
    xs_vec_add(fUpNormal, fRightNormal, fUpLeftPoint);
    xs_vec_add(fUpLeftPoint, fAimOrigin, fUpLeftPoint);
   
    //3
    xs_vec_neg(fUpNormal, fUpNormal);
    xs_vec_add(fUpNormal, fRightNormal, fDownLeftPoint);
    xs_vec_add(fDownLeftPoint, fAimOrigin, fDownLeftPoint);
   
    //4
    xs_vec_neg(fRightNormal, fRightNormal);
    xs_vec_add(fUpNormal, fRightNormal, fDownRightPoint);
    xs_vec_add(fDownRightPoint, fAimOrigin, fDownRightPoint);
   
    xs_vec_neg(fWallNormal, fWallNormal);
   
    if
    (    !trace_to_wall(fUpRightPoint, fWallNormal) || !trace_to_wall(fUpLeftPoint, fWallNormal) ||
        !trace_to_wall(fDownLeftPoint, fWallNormal) || !trace_to_wall(fDownRightPoint, fWallNormal)
    )
        return false;
   
    angle_vector(fWallAngles, ANGLEVECTOR_UP, fUpNormal);
    angle_vector(fWallAngles, ANGLEVECTOR_RIGHT, fRightNormal);
   
    xs_1_neg(fUpNormal[2]);
   
    xs_vec_mul_scalar(fRightNormal, fWidth / 2, fRightNormal);
    xs_vec_mul_scalar(fUpNormal, fHeight / 2, fUpNormal);
   
    xs_vec_add(fDownLeftPoint, fRightNormal, fTemp);
    xs_vec_add(fTemp, fUpNormal, fOriginEnd);
   
    new iEnt = NULLENT;
    while((iEnt = engfunc(EngFunc_FindEntityInSphere, iEnt, fOriginEnd, fSize)))
    {
        if (is_nullent(iEnt))    continue;
        if (FClassnameIs(iEnt, GrafityClass)){
            return false;
        }
    }
   
    //    Ideal Angle to Entity
    vector_to_angle(fAnglesNormal, fAnglesNormal);
   
    if(fAnglesNormal[0] == 90.0 || fAnglesNormal[0] == 270.0){
        get_entvar(id, var_v_angle, fTemp);
        fAnglesNormal[1] = fTemp[1] - 180.0;
    }
   
    return true;
}

get_wall_normal(iPlayer, Float:fNormal[3], Float:fEndPos[3])
{
    get_entvar(iPlayer, var_origin, fNormal);
    get_entvar(iPlayer, var_v_angle, fEndPos);
   
    angle_vector(fEndPos, ANGLEVECTOR_FORWARD, fEndPos);
    xs_vec_mul_scalar(fEndPos, MAX_DISTANCE, fEndPos);
    xs_vec_add(fEndPos, fNormal, fEndPos);
   
    engfunc(EngFunc_TraceLine, fNormal, fEndPos, IGNORE_MISSILE | IGNORE_MONSTERS | IGNORE_GLASS, iPlayer, 0);
    get_tr2(0, TR_vecPlaneNormal, fNormal);
    get_tr2(0, TR_vecEndPos, fEndPos);
}

trace_to_wall(Float:fOrigin[3], Float:fVec[3])
{
    new Float:fOrigin2[3];
    xs_vec_mul_scalar(fVec, ADD_UNITS, fOrigin2);
    xs_vec_add(fOrigin2, fOrigin, fOrigin2);
    xs_vec_add(fOrigin2, fVec, fOrigin2);
   
    engfunc(EngFunc_TraceLine, fOrigin, fOrigin2, IGNORE_MISSILE | IGNORE_MONSTERS | IGNORE_GLASS, 0, 0);
   
    new Float:fFrac;    get_tr2(0, TR_flFraction, fFrac);
   
    return (fFrac == 1.0) ? 0 : 1;
}