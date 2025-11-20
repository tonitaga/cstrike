#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <incom_print>

#define PLUGIN  "Incomsystem Camera Changer"
#define VERSION "1.1" 
#define AUTHOR  "Tonitaga"

#define CAMERA_COMMAND          "/camera"
#define CAMERA_COMMAND_SAY      "say /camera"
#define CAMERA_COMMAND_SAY_TEAM "say_team /camera"

#define FIRST_PERSON_VIEW 0
#define THIRD_PERSON_VIEW 1
#define UPLEFT_VIEW       2
#define TOPDOWN_VIEW      3

new amx_incom_camera_changer_enable;
new amx_incom_camera_changer_connect_camera;
new amx_incom_camera_changer_message_enable;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)

	register_clcmd(CAMERA_COMMAND_SAY,      "CameraMenu")
	register_clcmd(CAMERA_COMMAND_SAY_TEAM, "CameraMenu")

	register_dictionary("incom_camera_changer.txt")
}

public plugin_cfg()
{
	bind_pcvar_num(
		create_cvar(
			"amx_incom_camera_changer_enable", "1",
            .has_min = true, .min_val = 0.0,
            .has_max = true, .max_val = 1.0,
            .description = "0 - Плагин отключен^n\
                            1 - Плагин включен"
		),
		amx_incom_camera_changer_enable
	);

	bind_pcvar_num(
		create_cvar(
			"amx_incom_camera_changer_connect_camera", "0",
            .has_min = true, .min_val = 0.0,
            .has_max = true, .max_val = 3.0,
            .description = "Состояние камеры при подключении^n\
							0 - От первого лица^n\
							1 - От третьего лица^n\
							2 - Сверху слева^n\
							3 - Сверху вниз"
		),
		amx_incom_camera_changer_connect_camera
	);

	bind_pcvar_num(
		create_cvar(
			"amx_incom_camera_changer_message_enable", "1",
            .has_min = true, .min_val = 0.0,
            .has_max = true, .max_val = 1.0,
            .description = "Включить информационное сообщение^n\
							0 - Отключен^n\
							1 - Включен"
		),
		amx_incom_camera_changer_message_enable
	);

	AutoExecConfig();
}

public plugin_precache()
{
	// Без этого клиенты будут сегаться
	precache_model("models/rpgrocket.mdl")
}

public client_putinserver(playerId)
{
	if (amx_incom_camera_changer_enable)
	{
		switch (amx_incom_camera_changer_connect_camera) 
		{
			case FIRST_PERSON_VIEW:	set_view(playerId, FIRST_PERSON_VIEW)
			case THIRD_PERSON_VIEW:	set_view(playerId, THIRD_PERSON_VIEW)
			case UPLEFT_VIEW:	    set_view(playerId, UPLEFT_VIEW)
			case TOPDOWN_VIEW:	    set_view(playerId, TOPDOWN_VIEW)
		}
		
		if (amx_incom_camera_changer_message_enable)
		{
			set_task(25.0, "ShowCameraMessage", playerId)
		}
	}
}

public ShowCameraMessage(playerId)
{
	if (get_user_flags(playerId) & ADMIN_IMMUNITY)
	{
		IncomPrint_Client(playerId, "[%L] %L", playerId, "CAMERA_NAME", playerId, "CAMERA_USAGE_MESSAGE", CAMERA_COMMAND);
	}
}

public CameraMenu(playerId)
{	
	if (!amx_incom_camera_changer_enable)
	{
		return;
	}

	if (get_user_flags(playerId) & ADMIN_IMMUNITY)
	{
		new textStorage[256]
		formatex(textStorage, charsmax(textStorage), "\y%L", playerId, "CAMERA_MENU")
		
		new menu = menu_create(textStorage, "CameraMenuHandler")
		
		formatex(textStorage, charsmax(textStorage), "%L", playerId, "CAMERA_3RD")
		menu_additem(menu, textStorage, "1", 0)
		
		formatex(textStorage, charsmax( textStorage ), "%L", playerId, "CAMERA_UPLEFT")
		menu_additem(menu, textStorage, "2", 0)

		formatex(textStorage, charsmax( textStorage ), "%L", playerId, "CAMERA_TOPDOWN")
		menu_additem(menu, textStorage, "3", 0)
		
		formatex(textStorage, charsmax( textStorage ), "%L", playerId, "CAMERA_1ST")
		menu_additem(menu, textStorage, "4", 0)
		
		menu_setprop(menu, MPROP_EXIT, MEXIT_ALL)
		menu_display(playerId, menu, 0)
	}
}

public CameraMenuHandler(playerId, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	new data[6], iName[64], access, callback
	menu_item_getinfo(menu, item, access, data, 5, iName, 63, callback)

	new key = str_to_num(data)
	switch (key)
	{
		case 1:	set_view(playerId, THIRD_PERSON_VIEW)
		case 2:	set_view(playerId, UPLEFT_VIEW)
		case 3:	set_view(playerId, TOPDOWN_VIEW)
		case 4:	set_view(playerId, FIRST_PERSON_VIEW)
	}
	
	menu_destroy(menu)
	return PLUGIN_HANDLED;
}