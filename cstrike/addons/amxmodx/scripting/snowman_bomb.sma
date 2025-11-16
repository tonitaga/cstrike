#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <engine>

#define PLUGIN "Snowman Bomb"
#define VERSION "1.6"
#define AUTHOR "s0h"

#pragma tabsize 0

#define ANIMATION_DEFUSE 1 // Если вам не нужна анимация во время разминирования бомбы, закоментируйте эту строку
#define BLINK_BOMB       1 // Если хотите чтобы бомба внизу снеговика мигала, закоментируйте эту строку

new iEntity;

#if defined BLINK_BOMB
new g_iLedSprite;
#endif

new const gClassname_bomb[] = "bomb_snow"

new const g_szBombModels[][] = {
	"models/bomb_snowman.mdl"
};

public plugin_init() 
{
	register_event("HLTV", "eventHLTV", "a", "1=0", "2=0");
	
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	register_forward(FM_SetModel, "fwd_SetModel", 1);
	
	register_logevent("logevent_BombDefused", 3, "2=Defused_The_Bomb"); 
	
	#if defined ANIMATION_DEFUSE
	register_event("BarTime", "_cansel", "b", "1=0") //Событие отмены минирования/разминирования бомбы
	#endif
	
	register_think(gClassname_bomb, "EntityThink")
	
	#if defined BLINK_BOMB
	register_message(SVC_TEMPENTITY, "message_TempEntity");
	#endif
}

public plugin_precache()
{
	precache_model("models/hairt.mdl"); 
	new i;
	for(i = 0; i < sizeof g_szBombModels; i++)
		precache_model(g_szBombModels[i]);
	
	for(i = 0 ; i < sizeof g_szBombModels ; i++)
		precache_model(g_szBombModels[i]);
	
	#if defined BLINK_BOMB
	g_iLedSprite = precache_model("sprites/ledglow.spr");
	#endif
}

#if defined BLINK_BOMB
public message_TempEntity(msg_id, msg_dest, msg_ent)
{
	if(get_msg_arg_int(1) == TE_GLOWSPRITE)
	{
		if(get_msg_arg_int(5) == g_iLedSprite)
			return PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;
}
#endif

public eventHLTV()
{
	clean()
}

public EntityThink(iEntity)
{
	if(!pev_valid(iEntity))
		return PLUGIN_CONTINUE
	
	set_pev(iEntity, pev_nextthink, get_gametime() + 0.1)
	
	return PLUGIN_CONTINUE
}

public fwd_SetModel(ent, const szModel[])
{
	if(!pev_valid(ent))
		return FMRES_IGNORED;
	
	if(equal(szModel, "models/w_c4.mdl"))
	{
		engfunc(EngFunc_SetModel, ent, "models/hairt.mdl");
		
		return FMRES_SUPERCEDE;
	}
	return FMRES_IGNORED;
}

public clean()
{
	new entity = -1;
	
	while((entity = find_ent_by_class(entity, gClassname_bomb)))
	{
		remove_entity(entity);
	}
}

public bomb_planted(id)
{
	new iOrigin[3] // Создаем массив для хранение координат
	get_user_origin(id, iOrigin, 0) //Получаем координаты куда смотрит игрок
	
	new Float:fOrigin[3] //Создаем массив для float коодинат
	IVecFVec(iOrigin, fOrigin) //Конвертируем координаты в дробные
	
	if( (pev(id, pev_flags) & FL_ONGROUND) && (pev(id, pev_button) & IN_DUCK ) )
		fOrigin[2] += 18.0;
	
	iEntity = create_entity("info_target") //Создаем объект info_target
	
	if(!pev_valid(iEntity)) //Проверяем сущетсвует ли, если нет
		return PLUGIN_HANDLED //Заканчиваем. Дальше нам делать нечего
	
	set_pev(iEntity, pev_origin, fOrigin) //Присваиваем координаты
	
	set_pev(iEntity, pev_classname, gClassname_bomb) //Присваиваем Classname
	set_pev(iEntity, pev_solid, SOLID_NOT) //Делаем его непроходимым
	set_pev(iEntity, pev_movetype, MOVETYPE_NONE) //Не задаем тип движения, во всяком случаи пока
	set_pev(iEntity, pev_sequence, 1) //Выставляем № анимации при создании
	set_pev(iEntity, pev_framerate, 1.0) //Выставляем скорость анимации
	set_pev(iEntity, pev_nextthink, get_gametime() + 1.0) //Создаем запуск think
	
	engfunc(EngFunc_SetModel, iEntity, g_szBombModels[0]) //Присваиваем модель
	
	return PLUGIN_HANDLED //Заканчиваем. Дальше нам делать нечего
}

public bomb_explode()
{
	clean()
}

public bomb_defusing() // Момент когда бомбу начали разминировать
{
	#if defined ANIMATION_DEFUSE
	if(pev_valid(iEntity)) __Anim(iEntity, 3, 1.0); //run
	#endif
}

#if defined ANIMATION_DEFUSE
public _cansel()
{
	if(pev_valid(iEntity)) __Anim(iEntity, 1, 1.0); //not run
}
#endif

public logevent_BombDefused()
{
	if(pev_valid(iEntity)) __Anim(iEntity, 104, 1.0); //dead
}

stock __Anim(index, sequence, Float: framerate = 1.0) 
{ 
	static className[32]; 
	entity_get_string(iEntity, EV_SZ_classname, className, charsmax(className)) 
	if(equali(className, gClassname_bomb) && pev_valid(index))
	{
		entity_set_float(index, EV_FL_animtime, get_gametime()); 
		entity_set_float(index, EV_FL_framerate, framerate); 
		entity_set_float(index, EV_FL_frame, 0.0); 
		entity_set_int(index, EV_INT_sequence, sequence); 
	}
	
	if(sequence == 104)
	{
		set_task(1.0, "clean")
	}
}