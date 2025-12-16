/*
*	Menu System			     v. 0.1.2
*	by serfreeman1337	http://gf.hldm.org/
*/

#include <amxmodx>

#define PLUGIN "Menu System"
#define VERSION "0.1.2f"
#define AUTHOR "serfreeman1337"

new Trie:sayCall
new Trie:cmdCall

enum _:menuItemStruct {
	ISTRUCT_TITLE[128],
	ISTRUCT_CMD[20]
}

public plugin_init(){
	register_plugin(PLUGIN,VERSION,AUTHOR)
}

public plugin_cfg(){
	new cfgPath[512]
	get_localinfo("amxx_configsdir",cfgPath,charsmax(cfgPath))
	
	add(cfgPath,charsmax(cfgPath),"/player_menu.ini")
	
	new f = fopen(cfgPath,"r")
	
	if(!f){
		log_amx("confg file not found")
		
		return PLUGIN_CONTINUE
	}
	
	new buffer[512],menuTitle[128],menuId = -1
	
	while(!feof(f)){
		fgets(f,buffer,charsmax(buffer))
		trim(buffer)
		
		if(!buffer[0] || buffer[0] == ';') // skip comments
			continue

		replace_all(buffer,charsmax(buffer),"^^n","^n") // do new lines
			
		if(buffer[0] == '[' && buffer[strlen(buffer) - 1] == ']'){ // new menu entrie
			formatex(menuTitle,strlen(buffer) - 2,"%s",buffer[1]) // parse menu title
			menuId = menu_create(menuTitle,"GlobalMenu_Handler")  // create new menu
			
			new itemText[128]
			formatex(itemText,charsmax(itemText),"%L",LANG_SERVER,"BACK")
			menu_setprop(menuId,MPROP_BACKNAME,itemText)
			
			formatex(itemText,charsmax(itemText),"%L",LANG_SERVER,"MORE")
			menu_setprop(menuId,MPROP_NEXTNAME,itemText)
			
			formatex(itemText,charsmax(itemText),"%L",LANG_SERVER,"EXIT")
			menu_setprop(menuId,MPROP_EXITNAME,itemText)
			
			continue
		}
		
		if(menuId == -1)
			continue
			
		if(buffer[0] == '"'){ // read menu items
			new mItem[menuItemStruct]
			
			if(parse(buffer,mItem[ISTRUCT_TITLE],charsmax(mItem[ISTRUCT_TITLE]),
				mItem[ISTRUCT_CMD],charsmax(mItem[ISTRUCT_CMD])) < 2) // not engought parameters
					continue
					
			menu_additem(menuId,mItem[ISTRUCT_TITLE],mItem[ISTRUCT_CMD])
		}else{ // read menu keys
			new itemKey[10],itemValue[30]
			
			#if AMXX_VERSION_NUM >= 183
				strtok2(buffer,itemKey,charsmax(itemKey),itemValue,charsmax(itemValue),'=',TRIM_FULL)
			#else
				strtok(buffer,itemKey,charsmax(itemKey),itemValue,charsmax(itemValue),'=',1)
				formatex(itemValue,charsmax(itemValue),itemValue[2])
			#endif
			
			if(strcmp(itemKey,"cmd") == 0){ // register menu call command
				if(cmdCall == Invalid_Trie)
					cmdCall = TrieCreate()
				
				TrieSetCell(cmdCall,itemValue,menuId)
				register_clcmd(itemValue,"GlobalCmd_Handler")
			}else if(strcmp(itemKey,"say") == 0){ // register menu say call command
				if(sayCall == Invalid_Trie)
					sayCall = TrieCreate()
					
				new sayCmd[64]
				formatex(sayCmd,charsmax(sayCmd),"say %s",itemValue)
				
				TrieSetCell(sayCall,itemValue,menuId)
				register_clcmd(sayCmd,"GlobalCmd_Handler")
			}
		}
	}
	
	return PLUGIN_CONTINUE
}

// check item active
public GlobalMenu_Handler(id,m,item){
	if(item == MENU_EXIT)
		return PLUGIN_HANDLED
		
	new acc[1],itemData[20]
	menu_item_getinfo(m,item,acc[0],itemData,charsmax(itemData),acc,1,acc[0])
	
	if(itemData[0])
		client_cmd(id,itemData)
	
	return PLUGIN_HANDLED
}

// call menu by command
public GlobalCmd_Handler(id){
	if(!is_user_connected(id)) {
		return PLUGIN_HANDLED
	}

	new cmdArg[20],menuId = -1
	read_argv(0,cmdArg,charsmax(cmdArg))
	
	if(!TrieGetCell(cmdCall,cmdArg,menuId)){ // this is not command
		if(strcmp(cmdArg,"say") == 0){ // this is say command
			new sayArg[20]
			read_argv(1,sayArg,charsmax(sayArg))
			
			if(!TrieGetCell(sayCall,sayArg,menuId)) // no match found
				return PLUGIN_HANDLED
		}
	}
	
	if(menuId == -1)
		return PLUGIN_HANDLED
	
	// display menu
	menu_display(id,menuId)
	
	return PLUGIN_HANDLED
}

stock SendCmd_1( id , text[] ) {
      message_begin( MSG_ONE, 51, _, id )
      write_byte( strlen(text) + 2 )
      write_byte( 10 )
      write_string( text )
      message_end()
}