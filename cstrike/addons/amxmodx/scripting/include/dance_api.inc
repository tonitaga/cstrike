#if defined _dance_api_included
    #endinput
#endif
#define _dance_api_included

/**
 *  Проверяет есть ли у игрока действующая анимация
 *
 *  @param  pPlayer         Игрок
 *
 *  @return                 true если есть | false если нет
*/
native nd_get_active_dance(const pPlayer);

/**
 *  Сбросит анимацию игроку
 *
 *  @param  pPlayer         Игрок
 *
 *  @return                 -
*/
native nd_remove_dance(const pPlayer);