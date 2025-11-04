#include <amxmodx>
#include <amxmisc>
#include <engine>

#define PLUGIN  "Incomsystem Camera Changer"
#define VERSION "1.0" 
#define AUTHOR  "Tonitaga"

#define KEY_ENABLE         "incom_camera_changer_enable"
#define KEY_CONNECT_CAMERA "incom_camera_changer_connect_camera"
#define KEY_ENABLE_MESSAGE "incom_camera_changer_message_enable"

#define DEFAULT_ENABLE         "1"
#define DEFAULT_CONNECT_CAMERA "0"
#define DEFAULT_ENABLE_MESSAGE "1"

new g_Enable;
new g_ConnectCamera;
new g_MessageEnable;

#define FIRST_PERSON_VIEW 0
#define THIRD_PERSON_VIEW 1
#define UPLEFT_VIEW       2
#define TOPDOWN_VIEW      3

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	register_dictionary("incom_camera_changer.txt")
}

public plugin_cfg()
{
	g_Enable        = create_cvar(KEY_ENABLE, DEFAULT_ENABLE, _, "Статус плагина^n0 - Отключен^n1 - Включен", true, 0.0, true, 1.0);
	g_ConnectCamera = create_cvar(KEY_CONNECT_CAMERA, DEFAULT_CONNECT_CAMERA, _, "Состояние камеры при подключении^n0 - От первого лица^n1 - От третьего лица^n2 - Сверху слева^n3 - Сверху вниз", true, 0.0, true, 3.0);
	g_MessageEnable = create_cvar(KEY_ENABLE_MESSAGE, DEFAULT_ENABLE_MESSAGE, _, "Включить информационное сообщение^n0 - Отключен^n1 - Включен", true, 0.0, true, 1.0);

	if (get_pcvar_num(g_Enable))
	{
		register_clcmd("say /camera",      "CameraMenu")
		register_clcmd("say_team /camera", "CameraMenu")
	}

	AutoExecConfig(true, "incom_camera_changer");
}

public plugin_precache()
{
	// Без этого клиенты будут сегаться
	precache_model("models/rpgrocket.mdl")
}

public client_putinserver(playerId)
{
	if (get_pcvar_num(g_Enable))
	{
		new connectCamera = get_pcvar_num(g_ConnectCamera)
		switch (connectCamera) 
		{
			case FIRST_PERSON_VIEW:	set_view(playerId, FIRST_PERSON_VIEW)
			case THIRD_PERSON_VIEW:	set_view(playerId, THIRD_PERSON_VIEW)
			case UPLEFT_VIEW:	    set_view(playerId, UPLEFT_VIEW)
			case TOPDOWN_VIEW:	    set_view(playerId, TOPDOWN_VIEW)
		}
		
		if (get_pcvar_num(g_MessageEnable))
		{
			set_task(25.0, "ShowCameraMessage", playerId)
		}
	}
}

public ShowCameraMessage(playerId)
{
	if (get_user_flags(playerId) & ADMIN_IMMUNITY)
	{
		client_print(playerId, print_chat, "[CAMERA] %L", playerId, "CAMERA_MESSAGE")
	}
}

public CameraMenu(playerId)
{	
	if (get_user_flags(playerId) & ADMIN_IMMUNITY)
	{
		new textStorage[256 char]
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