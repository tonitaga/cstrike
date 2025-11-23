#include <amxmodx>
#include <amxmisc>

#define PLUGIN  "Incomsystem Commands"
#define VERSION "1.0" 
#define AUTHOR  "Tonitaga"

new g_CommandsHtmlFile[64]

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR)
    
    register_clcmd("say /commands", "ShowCommands")
    register_clcmd("say_team /commands", "ShowCommands")
    
    get_configsdir(g_CommandsHtmlFile, charsmax(g_CommandsHtmlFile))
    format(g_CommandsHtmlFile, charsmax(g_CommandsHtmlFile), "%s/incom_commands.txt", g_CommandsHtmlFile)
}

public ShowCommands(playerId) {
    show_motd(playerId, g_CommandsHtmlFile, "INCOMSYSTEM [XMAS ZONE]")
    return PLUGIN_HANDLED
}