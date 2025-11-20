#if defined _incom_print_included
    #endinput
#endif
#define _incom_print_included

#include <amxmodx>
#include <cromchat>

#define MAX_INCOM_PRINT_BUFFER_SIZE 512

public IncomPrint_Client(id, const format[], any:...)
{
    static message[MAX_INCOM_PRINT_BUFFER_SIZE];

    vformat(message, charsmax(message), format, 3);
    CC_SendMessage(id, message);
}