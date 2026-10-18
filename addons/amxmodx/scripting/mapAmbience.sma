/*
*
*	Map Ambience by RedSMURF
*
*
*	Description:
*
*	Cvars:
*		None
*
*	Commands:
*       say /ma                         "Opens the Map Ambience menu."
*       say_team /ma                    "Opens the Map Ambience menu."
*       say /mapambience                "Opens the Map Ambience menu."
*       say_team /mapambience           "Opens the Map Ambience menu."
*       ma_reload                       "Reloads the configuration file."
*       mapambience_reload              "Reloads the configuration file."
*
*	Changelog:
*       v1.0: Initial release.
*
*/

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <xs>

#if !defined MAX_PLAYERS
    #define MAX_PLAYERS 32
#endif

#if !defined MAX_VALUE_LENGTH
    #define MAX_VALUE_LENGTH 64
#endif

#if !defined MAX_RESOURCE_PATH_LENGTH
    #define MAX_RESOURCE_PATH_LENGTH 128
#endif

#if !defined MAX_FILE_CELL_SIZE
    #define MAX_FILE_CELL_SIZE 192
#endif

#if !defined MAX_PLATFORM_PATH_LENGTH
    #define MAX_PLATFORM_PATH_LENGTH 256
#endif

#define MAX_ENT                     32
#define ADMIN_ACCESS                ADMIN_RCON
#define PDATA_NEXT_ATTACK           83
#define XO_CBASEPLAYER              5
#define XO_CBASEPLAYERWEAPON        4
#define AMBIENCE_KEY                712009
#define AMBIENCE_ARRAY_ITEM         pev_iuser1
#define SOUND_NAV                   "buttons/blip1.wav"
#define SOUND_REMOVE                "buttons/button10.wav"
#define SOUND_ALERT                 "buttons/bell1.wav"

new const PLUGIN_VERSION[]          = "1.0"
new const Float:DELAY_ON_LOAD       = 3.0
new const ERROR_FILE[]              = "MapAmbience_ERRORS.log"

enum
{
    SECTION_NONE,
    SECTION_MAIN_SETTINGS,
    SECTION_AMBIENCE
}

enum
{
    DTYPE_INT,
    DTYPE_FLOAT,
    DTYPE_FLAGS,
    DTYPE_ARRAY_STRING,
    DTYPE_ARRAY_SOUND,
    DTYPE_STRING_MODEL,
    DTYPE_STRING_SOUND,
    DTYPE_STRING_MODEL_ID
}

enum
{
    FLAG_DURATION           = (1 << 0),

    FLAG_ACTIVE             = (1 << 1),
    FLAG_GHOST              = (1 << 2),
    FLAG_PLAYING            = (1 << 3),
    FLAG_SOUND              = (1 << 4)
}

enum
{
    TARGET_GHOST,
    TARGET_SELECT,
    TARGET_HIDE,
    TARGET_CLEAR
}

enum _:MAIN_SETTINGS
{
    SETTING_DEFAULT_MODEL[MAX_RESOURCE_PATH_LENGTH],
    SETTING_DEFAULT_FLAGS,

    Float:SETTING_DEFAULT_FRAMERATE,
    Float:SETTING_DEFAULT_SPAWN_CHANCE,
    Array:SETTING_DEFAULT_SOUND,
    Float:SETTING_DEFAULT_SOUND_DURATION[2],
    Float:SETTING_DEFAULT_SOUND_VOL,
    Float:SETTING_DEFAULT_SOUND_ATTN,
    SETTING_DEFAULT_SOUND_PITCH,

    bool:SETTING_AMBIENCE_LOAD,
    Float:SETTING_AMBIENCE_CHECK,
    Float:SETTING_AMBIENCE_TASK,
    Float:SETTING_OFFSET_BASE,
    Float:SETTING_OFFSET[2],
    Float:SETTING_OFFSET_STEP,
    SETTING_GHOST_ALPHA,
    Float:SETTING_ROTATION_STEP[2],
}

enum _:AMBIENCE
{
    AMBIENCE_ID,
    AMBIENCE_ITEM,
    AMBIENCE_FLAGS,
    AMBIENCE_NAME[MAX_VALUE_LENGTH],

    Float:AMBIENCE_ORIGIN[3],
    Float:AMBIENCE_ANGLES[3],
    Array:AMBIENCE_SOUND,
    Float:AMBIENCE_SOUND_DURATION[2],
    AMBIENCE_SOUND_CURRENT[MAX_VALUE_LENGTH],
    Float:AMBIENCE_SOUND_VOL,
    Float:AMBIENCE_SOUND_ATTN,
    AMBIENCE_SOUND_PITCH,

    Float:AMBIENCE_NEXT_SOUND
}

enum _:PLAYER_DATA
{
    PDATA_AMBIENCE_GHOST,
    PDATA_AMBIENCE_MENU,
    bool:PDATA_AMBIENCE_ACTION,
    Float:PDATA_OFFSET,
    Float:PDATA_NEXT_OFFSET,

    PDATA_MENU_TYPE,
    bool:PDATA_MENU_TRACE
}

enum
{
    SOUND_MENU_NAV,
    SOUND_MENU_REMOVE,
    SOUND_MENU_ALERT
}

enum
{
    MENU_ROOT,
    MENU_CREATE,
    MENU_EDIT,
    MENU_REMOVE,
    MENU_STATUS,
    MENU_ROTATE
}

enum
{
    ROOT_CREATE,
    ROOT_EDIT,
    ROOT_REMOVE,
    ROOT_SAVE,

    ROOT_NOCLIP = 5,
    ROOT_GODMODE
}

enum
{
    EDIT_STATUS
}

enum
{
    REMOVE_NEXT,
    REMOVE_BACK,

    REMOVE_CURRENT = 3,
    REMOVE_ALL
}

enum
{
    STATUS_NEXT,
    STATUS_BACK,

    STATUS_CURRENT = 3,
    STATUS_ALL_ENABLE,
    STATUS_ALL_DISABLE
}

enum
{
    ROTATE_UP,
    ROTATE_DOWN,

    ROTATE_PLACE = 3
}

new g_szMenuHandler[][MAX_VALUE_LENGTH] =
{
    "menuHandlerRoot",
    "menuHandlerCreate",
    "menuHandlerEdit",
    "menuHandlerRemove",
    "menuHandlerStatus",
    "menuHandlerRotate"
}

new g_szCN[] = "mapambience"

new Array:g_aAmbience,
    Array:g_aAmbienceConfig,
    g_eSettings[MAIN_SETTINGS],
    g_ePlayerData[MAX_PLAYERS + 1][PLAYER_DATA],
    bool:g_bFileWasRead, g_iActivePlayers,
    g_iAmbience, g_iAmbienceConfig,
    HamHook:g_iFwdPreThink, HamHook:g_iFwdKilled

new const g_iColorActive[] = { 0, 255, 0 }
new const g_iColorInactive[] = { 255, 0, 0 }

public plugin_init()
{
    register_plugin("Map Ambience", PLUGIN_VERSION, "RedSMURF")
    register_cvar("RedSMURF_MapAmbience", PLUGIN_VERSION, ADMIN_ACCESS)

    register_clcmd("say /ma",               "cmdMenu", ADMIN_RCON, "-- Opens the Map Ambience menu.")
    register_clcmd("say_team /ma",          "cmdMenu", ADMIN_RCON, "-- Opens the Map Ambience menu.")
    register_clcmd("say /ambience",         "cmdMenu", ADMIN_RCON, "-- Opens the Map Ambience menu.")
    register_clcmd("say_team /ambience",    "cmdMenu", ADMIN_RCON, "-- Opens the Map Ambience menu.")
    register_concmd("ma_reload",            "cmdReload", ADMIN_RCON, "-- Reloads the configuration file")
    register_concmd("mapambience_reload",   "cmdReload", ADMIN_RCON, "-- Reloads the configuration file")
    register_dictionary("MapAmbience.txt")

    g_iFwdPreThink = RegisterHam(Ham_Player_PreThink, "player", "fwdPreThink")
    g_iFwdKilled = RegisterHam(Ham_Killed, "player", "fwdKilled", 1)
    register_logevent("eventRoundStart", 2, "1=Round_Start")
    DisableForward()

    ambienceInit()
}

public plugin_precache()
{
    g_aAmbience = ArrayCreate(AMBIENCE)
    g_aAmbienceConfig = ArrayCreate(AMBIENCE)
    g_eSettings[SETTING_DEFAULT_SOUND] = ArrayCreate(MAX_RESOURCE_PATH_LENGTH)

    ReadFile()
}

public plugin_end()
{
    new eAmbience[AMBIENCE]
    for ( new i = 0; i < g_iAmbience; i ++ )
    {
        ArrayGetArray(g_aAmbience, i, eAmbience)
        ArrayDestroy(eAmbience[AMBIENCE_SOUND])
    }

    for ( new i = 0; i < g_iAmbienceConfig; i ++ )
    {
        ArrayGetArray(g_aAmbienceConfig, i, eAmbience)
        ArrayDestroy(eAmbience[AMBIENCE_SOUND])
    }

    ArrayDestroy(g_aAmbience)
    ArrayDestroy(g_aAmbienceConfig)
    ArrayDestroy(g_eSettings[SETTING_DEFAULT_SOUND])
}

public cmdMenu(id, iLevel, iCmd)
{
    if ( !cmd_access(id, iLevel, iCmd, 1) )
        return PLUGIN_HANDLED

    ambienceSound(id, SOUND_MENU_NAV)
    ambienceMenu(id, MENU_ROOT)

    return PLUGIN_HANDLED
}

public cmdReload(id, iLevel, iCmd)
{
    if ( !cmd_access(id, iLevel, iCmd, 1) )
        return PLUGIN_HANDLED

    ReadFile()
    console_print(id, "The configuration file has been reloaded successfully !")

    return PLUGIN_HANDLED
}

public eventRoundStart()
{
    ambienceReset()
}

ReadFile()
{
    if ( g_bFileWasRead )
    {
        ArrayClear(g_eSettings[SETTING_DEFAULT_SOUND])
        ArrayClear(g_aAmbienceConfig)
        g_iAmbienceConfig = 0
    }

    new g_szFileName[MAX_FILE_CELL_SIZE]
    get_configsdir(g_szFileName, charsmax(g_szFileName))
    add(g_szFileName, charsmax(g_szFileName), "/MapAmbience.ini")

    new iFile
    iFile = fopen(g_szFileName, "rt")

    if ( !iFile )
    {
        set_fail_state("An error occured during the opening of the configuration file !")
    }

    new szData[MAX_FILE_CELL_SIZE],
        szKey[MAX_VALUE_LENGTH],
        szValue[MAX_RESOURCE_PATH_LENGTH],
        eAmbience[AMBIENCE], iSection = SECTION_NONE, iLine, iPos

    while( !feof(iFile) )
    {
        iLine ++
        fgets(iFile, szData, charsmax(szData))
        trim(szData)

        switch( szData[0] )
        {
            case EOS, ';', '#':
            {
                continue
            }
            case '[':
            {
                if ( szData[strlen(szData) - 1] == ']' )
                {
                    replace(szData, charsmax(szData), "[", "")
                    replace(szData, charsmax(szData), "]", "")
                    trim(szData)

                    if ( equali(szData, "Main Settings") )
                    {
                        iSection = SECTION_MAIN_SETTINGS
                    }
                    else
                    {
                        if ( g_iAmbienceConfig )
                            ArrayPushArray(g_aAmbienceConfig, eAmbience)

                        copy(eAmbience[AMBIENCE_NAME], charsmax(eAmbience[AMBIENCE_NAME]), szData)
                        eAmbience[AMBIENCE_FLAGS]               = g_eSettings[SETTING_DEFAULT_FLAGS]

                        eAmbience[AMBIENCE_SOUND]               = ArrayClone(g_eSettings[SETTING_DEFAULT_SOUND])
                        eAmbience[AMBIENCE_SOUND_DURATION][0]   = g_eSettings[SETTING_DEFAULT_SOUND_DURATION][0]
                        eAmbience[AMBIENCE_SOUND_DURATION][1]   = g_eSettings[SETTING_DEFAULT_SOUND_DURATION][1]
                        eAmbience[AMBIENCE_SOUND_VOL]           = g_eSettings[SETTING_DEFAULT_SOUND_VOL]
                        eAmbience[AMBIENCE_SOUND_ATTN]          = g_eSettings[SETTING_DEFAULT_SOUND_ATTN]
                        eAmbience[AMBIENCE_SOUND_PITCH]         = g_eSettings[SETTING_DEFAULT_SOUND_PITCH]

                        iSection = SECTION_AMBIENCE
                        g_iAmbienceConfig ++
                    }
                }
                else
                {
                    LogConfigError(iLine, "Unclosed section name: %s", szData)
                    iSection = SECTION_NONE
                }
            }
            default:
            {
                strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=')
                iPos = contain(szValue, "#")
                if ( iPos != -1 )
                    szValue[iPos] = EOS

                trim(szKey)
                trim(szValue)

                switch( iSection )
                {
                    case SECTION_NONE:
                    {
                        LogConfigError(iLine, "Data is not in any defined section: %s", szData)
                    }
                    case SECTION_MAIN_SETTINGS:
                    {
                        if ( equali(szKey, "SETTING_DEFAULT_MODEL") )
                            parseSetting(DTYPE_STRING_MODEL, szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_MODEL], charsmax(g_eSettings[SETTING_DEFAULT_MODEL]))
                        else if ( equali(szKey, "SETTING_DEFAULT_FLAGS") )
                            parseSetting(DTYPE_FLAGS, szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_FLAGS], charsmax(g_eSettings[SETTING_DEFAULT_FLAGS]))
                        else if ( equali(szKey, "SETTING_DEFAULT_FRAMERATE") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_FRAMERATE], charsmax(g_eSettings[SETTING_DEFAULT_FRAMERATE]))
                        else if ( equali(szKey, "SETTING_DEFAULT_SPAWN_CHANCE") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_SPAWN_CHANCE], charsmax(g_eSettings[SETTING_DEFAULT_SPAWN_CHANCE]))
                        else if ( equali(szKey, "SETTING_DEFAULT_SOUND") )
                            parseSetting(DTYPE_ARRAY_SOUND, szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_SOUND], charsmax(g_eSettings[SETTING_DEFAULT_SOUND]))
                        else if ( equali(szKey, "SETTING_DEFAULT_SOUND_DURATION") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_SOUND_DURATION], charsmax(g_eSettings[SETTING_DEFAULT_SOUND_DURATION]))
                        else if ( equali(szKey, "SETTING_DEFAULT_SOUND_VOL") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_SOUND_VOL], charsmax(g_eSettings[SETTING_DEFAULT_SOUND_VOL]))
                        else if ( equali(szKey, "SETTING_DEFAULT_SOUND_ATTN") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_SOUND_ATTN], charsmax(g_eSettings[SETTING_DEFAULT_SOUND_ATTN]))
                        else if ( equali(szKey, "SETTING_DEFAULT_SOUND_PITCH") )
                            parseSetting(DTYPE_INT, szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_SOUND_PITCH], charsmax(g_eSettings[SETTING_DEFAULT_SOUND_PITCH]))
                        else if ( equali(szKey, "SETTING_AMBIENCE_LOAD") )
                            parseSetting(DTYPE_INT, szValue, charsmax(szValue), g_eSettings[SETTING_AMBIENCE_LOAD], charsmax(g_eSettings[SETTING_AMBIENCE_LOAD]))
                        else if ( equali(szKey, "SETTING_OFFSET_BASE") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_OFFSET_BASE], charsmax(g_eSettings[SETTING_OFFSET_BASE]))
                        else if ( equali(szKey, "SETTING_AMBIENCE_CHECK") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_AMBIENCE_CHECK], charsmax(g_eSettings[SETTING_AMBIENCE_CHECK]))
                        else if ( equali(szKey, "SETTING_AMBIENCE_TASK") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_AMBIENCE_TASK], charsmax(g_eSettings[SETTING_AMBIENCE_TASK]))
                        else if ( equali(szKey, "SETTING_OFFSET") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_OFFSET], charsmax(g_eSettings[SETTING_OFFSET]))
                        else if ( equali(szKey, "SETTING_OFFSET_STEP") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_OFFSET_STEP], charsmax(g_eSettings[SETTING_OFFSET_STEP]))
                        else if ( equali(szKey, "SETTING_GHOST_ALPHA") )
                            parseSetting(DTYPE_INT, szValue, charsmax(szValue), g_eSettings[SETTING_GHOST_ALPHA], charsmax(g_eSettings[SETTING_GHOST_ALPHA]))
                        else if ( equali(szKey, "SETTING_ROTATION_STEP") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_ROTATION_STEP], charsmax(g_eSettings[SETTING_ROTATION_STEP]))
                    }
                    case SECTION_AMBIENCE:
                    {
                        if ( equali(szKey, "AMBIENCE_FLAGS") )
                            parseSetting(DTYPE_FLAGS, szValue, charsmax(szValue), eAmbience[AMBIENCE_FLAGS], charsmax(eAmbience[AMBIENCE_FLAGS]))
                        else if ( equali(szKey, "AMBIENCE_SOUND") )
                        {
                            if ( !(eAmbience[AMBIENCE_FLAGS] & FLAG_SOUND) )
                            {
                                ArrayClear(eAmbience[AMBIENCE_SOUND])
                                eAmbience[AMBIENCE_FLAGS] |= FLAG_SOUND
                            }

                            parseSetting(DTYPE_ARRAY_SOUND, szValue, charsmax(szValue), eAmbience[AMBIENCE_SOUND], charsmax(eAmbience[AMBIENCE_SOUND]))
                        }
                        else if ( equali(szKey, "AMBIENCE_SOUND_DURATION") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), eAmbience[AMBIENCE_SOUND_DURATION], charsmax(eAmbience[AMBIENCE_SOUND_DURATION]))
                        else if ( equali(szKey, "AMBIENCE_SOUND_VOL") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), eAmbience[AMBIENCE_SOUND_VOL], charsmax(eAmbience[AMBIENCE_SOUND_VOL]))
                        else if ( equali(szKey, "AMBIENCE_SOUND_ATTN") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), eAmbience[AMBIENCE_SOUND_ATTN], charsmax(eAmbience[AMBIENCE_SOUND_ATTN]))
                        else if ( equali(szKey, "AMBIENCE_SOUND_PITCH") )
                            parseSetting(DTYPE_INT, szValue, charsmax(szValue), eAmbience[AMBIENCE_SOUND_PITCH], charsmax(eAmbience[AMBIENCE_SOUND_PITCH]))
                    }
                }
            }
        }
    }

    if ( g_iAmbienceConfig )
        ArrayPushArray(g_aAmbienceConfig, eAmbience)
    else
        set_fail_state("No Ambiences were found in the configuration file.")

    g_bFileWasRead = true
    fclose(iFile)
}

public client_disconnected(id)
{
    new eAmbience[AMBIENCE], iItem
    if ( g_ePlayerData[id][PDATA_AMBIENCE_GHOST]
    && (iItem = ambienceGet(eAmbience, g_ePlayerData[id][PDATA_AMBIENCE_GHOST])) != -1 )
    {
        ambienceKill(eAmbience[AMBIENCE_ID])
        ambienceRemove(iItem)
    }

    DisableAction(id)
    g_ePlayerData[id][PDATA_AMBIENCE_GHOST]  = 0
    g_ePlayerData[id][PDATA_AMBIENCE_MENU]   = 0
}

public ambienceInit()
{
    if ( g_eSettings[SETTING_AMBIENCE_LOAD] )
        set_task(DELAY_ON_LOAD, "loadData")
}

stock ambienceTerminate()
{
    new eAmbience[AMBIENCE]
    for ( new i = 0; i < g_iAmbience; i ++ )
    {
        ArrayGetArray(g_aAmbience, i, eAmbience)
        eAmbience[AMBIENCE_FLAGS] &= ~FLAG_PLAYING
        ArraySetArray(g_aAmbience, i, eAmbience)
    }
}

stock ambienceMenu(id, iType)
{
    if ( !is_user_connected(id) )
        return PLUGIN_HANDLED

    new szData[256], iMenu
    formatex(szData, charsmax(szData), "%L", id, "AMBIENCE_MENU_TITLE", PLUGIN_VERSION)
    iMenu = menu_create(szData, g_szMenuHandler[iType])
    switch( iType )
    {
        case MENU_ROOT:     { menuRoot(id, iMenu); }
        case MENU_CREATE:   { menuCreate(iMenu);            format(szData, charsmax(szData), "%s^n%L", szData, id, "AMBIENCE_ROOT_CREATE"); }
        case MENU_EDIT:     { menuEdit(id, iMenu);          format(szData, charsmax(szData), "%s^n%L", szData, id, "AMBIENCE_ROOT_EDIT"); }
        case MENU_REMOVE:   { menuRemove(id, iMenu);        format(szData, charsmax(szData), "%s^n%L", szData, id, "AMBIENCE_ROOT_REMOVE"); }
        case MENU_STATUS:   { menuStatus(id, iMenu);        format(szData, charsmax(szData), "%s^n%L", szData, id, "AMBIENCE_ROOT_STATUS"); }
        case MENU_ROTATE:   { menuRotate(id, iMenu);        format(szData, charsmax(szData), "%s^n%L", szData, id, "AMBIENCE_ROOT_ROTATE"); }
    }

    if ( menu_pages(iMenu) > 1 )
        format(szData, charsmax(szData), "%s^n%L", szData, id, "AMBIENCE_MENU_TITLE_PAGE")

    menu_setprop(iMenu, MPROP_TITLE, szData)
    menu_setprop(iMenu, MPROP_EXIT, MEXIT_ALL)
    menu_setprop(iMenu, MPROP_NUMBER_COLOR, "\r")

    menu_display(id, iMenu)
    return PLUGIN_HANDLED
}

stock menuNav(id, iMenu)
{
    new szItem[64]
    formatex(szItem, charsmax(szItem), "%L", id, "AMBIENCE_NAV_NEXT")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "AMBIENCE_NAV_BACK")
    menu_additem(iMenu, szItem)

    menu_addblank2(iMenu)
}

public menuRoot(id, iMenu)
{
    new szItem[64]
    formatex(szItem, charsmax(szItem), "%L", id, "AMBIENCE_ROOT_CREATE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "AMBIENCE_ROOT_EDIT")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "AMBIENCE_ROOT_REMOVE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "AMBIENCE_ROOT_SAVE")
    menu_additem(iMenu, szItem)

    menu_addblank2(iMenu)

    formatex(szItem, charsmax(szItem), "%L", id, "AMBIENCE_ROOT_NOCLIP", id, get_user_noclip(id) ? "AMBIENCE_ON" : "AMBIENCE_OFF")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "AMBIENCE_ROOT_GODMODE", id, get_user_godmode(id) ? "AMBIENCE_ON" : "AMBIENCE_OFF")
    menu_additem(iMenu, szItem)
}

public menuHandlerRoot(id, menu, item)
{
    if ( item == MENU_EXIT )
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    switch( item )
    {
        case ROOT_CREATE:
        {
            if ( g_iAmbience >= MAX_ENT )
            {
                client_print_color(id, id, "%L %L", id, "AMBIENCE_CHAT_TAG", id, "AMBIENCE_CHAT_LIMIT", MAX_ENT)

                ambienceSound(id, SOUND_MENU_REMOVE)
                ambienceMenu(id, MENU_ROOT)
            }
            else
            {
                ambienceSound(id, SOUND_MENU_NAV)
                ambienceMenu(id, MENU_CREATE)
            }
        }
        case ROOT_EDIT:
        {
            if ( !g_iAmbience )
            {
                client_print_color(id, id, "%L %L", id, "AMBIENCE_CHAT_TAG", id, "AMBIENCE_CHAT_NO_ambience")

                ambienceSound(id, SOUND_MENU_REMOVE)
                ambienceMenu(id, MENU_ROOT)
            }
            else
            {
                ambienceSound(id, SOUND_MENU_NAV)
                ambienceMenu(id, MENU_EDIT)
            }
        }
        case ROOT_REMOVE:
        {
            if ( !g_iAmbience )
            {
                client_print_color(id, id, "%L %L", id, "AMBIENCE_CHAT_TAG", id, "AMBIENCE_CHAT_NO_ambience")

                ambienceSound(id, SOUND_MENU_REMOVE)
                ambienceMenu(id, MENU_ROOT)
            }
            else
            {
                ambienceSound(id, SOUND_MENU_REMOVE)
                ambienceMenu(id, MENU_REMOVE)
            }
        }
        case ROOT_SAVE:
        {
            saveData(id)
        }
        case ROOT_NOCLIP:
        {
            ambienceNoClip(id)
        }
        case ROOT_GODMODE:
        {
            ambienceGodMode(id)
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuCreate(iMenu)
{
    new eAmbience[AMBIENCE], szItem[64]
    for ( new i = 0; i < g_iAmbienceConfig; i ++ )
    {
        ArrayGetArray(g_aAmbienceConfig, i, eAmbience)

        copy(szItem, charsmax(szItem), eAmbience[AMBIENCE_NAME])
        menu_additem(iMenu, szItem)
    }
}

public menuHandlerCreate(id, menu, item)
{
    if ( !is_user_alive(id) )
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }
    else if ( item == MENU_EXIT )
    {
        ambienceSound(id, SOUND_MENU_NAV)
        ambienceMenu(id, MENU_ROOT)

        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    ambienceCreate(id, item)
    ambienceSound(id, SOUND_MENU_NAV)
    ambienceMenu(id, MENU_ROTATE)

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuEdit(id, iMenu)
{
    new szItem[64]
    formatex(szItem, charsmax(szItem), "%L", id, "AMBIENCE_EDIT_STATUS")
    menu_additem(iMenu, szItem)
}

public menuHandlerEdit(id, menu, item)
{
    switch( item )
    {
        case EDIT_STATUS:
        {
            ambienceSound(id, SOUND_MENU_NAV)
            ambienceMenu(id, MENU_STATUS)
        }
        case MENU_EXIT:
        {
            ambienceSound(id, SOUND_MENU_NAV)
            ambienceMenu(id, MENU_ROOT)
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuRemove(id, iMenu)
{
    new szItem[64], eAmbience[AMBIENCE]
    menuNav(id, iMenu)
    ArrayGetArray(g_aAmbience, g_ePlayerData[id][PDATA_AMBIENCE_MENU], eAmbience)

    formatex(szItem, charsmax(szItem), "%L", id, "AMBIENCE_REMOVE_CURRENT", eAmbience[AMBIENCE_NAME])
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "AMBIENCE_REMOVE_ALL")
    menu_additem(iMenu, szItem)

    EnableAction(id)
    ambienceSelect(eAmbience, TARGET_SELECT)
    g_ePlayerData[id][PDATA_MENU_TYPE] = MENU_REMOVE
    ArraySetArray(g_aAmbience, g_ePlayerData[id][PDATA_AMBIENCE_MENU], eAmbience)
}

public menuHandlerRemove(id, menu, item)
{
    new eAmbience[AMBIENCE]
    ArrayGetArray(g_aAmbience, g_ePlayerData[id][PDATA_AMBIENCE_MENU], eAmbience)
    if ( !g_ePlayerData[id][PDATA_MENU_TRACE] )
        ambienceSelect(eAmbience, TARGET_GHOST)

    switch( item )
    {
        case REMOVE_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_AMBIENCE_MENU] >= g_iAmbience - 1 )
                g_ePlayerData[id][PDATA_AMBIENCE_MENU] = 0
            else
                g_ePlayerData[id][PDATA_AMBIENCE_MENU] ++

            ambienceSound(id, SOUND_MENU_NAV)
            ambienceMenu(id, MENU_REMOVE)
        }
        case REMOVE_BACK:
        {
            if ( g_ePlayerData[id][PDATA_AMBIENCE_MENU] <= 0 )
                g_ePlayerData[id][PDATA_AMBIENCE_MENU] = g_iAmbience - 1
            else
                g_ePlayerData[id][PDATA_AMBIENCE_MENU] --

            ambienceSound(id, SOUND_MENU_NAV)
            ambienceMenu(id, MENU_REMOVE)
        }
        case REMOVE_CURRENT:
        {
            eAmbience[AMBIENCE_FLAGS] &= ~FLAG_ACTIVE
            ambienceSetState(eAmbience)
            ambienceKill(eAmbience[AMBIENCE_ID])
            ambienceRemove(g_ePlayerData[id][PDATA_AMBIENCE_MENU])

            client_print_color(id, id, "%L %L", id, "AMBIENCE_CHAT_TAG", id, "AMBIENCE_CHAT_REMOVE_CURRENT", eAmbience[AMBIENCE_NAME])
            g_ePlayerData[id][PDATA_AMBIENCE_MENU] = 0

            ambienceSound(id, g_iAmbience > 0 ? SOUND_MENU_REMOVE : SOUND_MENU_NAV)
            ambienceMenu(id, g_iAmbience > 0 ? MENU_REMOVE : MENU_ROOT)
        }
        case REMOVE_ALL:
        {
            while( g_iAmbience )
            {
                ArrayGetArray(g_aAmbience, 0, eAmbience)
                eAmbience[AMBIENCE_FLAGS] &= ~FLAG_ACTIVE

                ambienceSetState(eAmbience)
                ambienceKill(eAmbience[AMBIENCE_ID])
                ambienceRemove(0)
            }

            client_print_color(id, id, "%L %L", id, "AMBIENCE_CHAT_TAG", id, "AMBIENCE_CHAT_REMOVE_ALL")
            g_ePlayerData[id][PDATA_AMBIENCE_MENU] = 0

            ambienceSound(id, SOUND_MENU_ALERT)
            ambienceMenu(id, MENU_ROOT)
        }
        case MENU_EXIT:
        {
            if ( !g_ePlayerData[id][PDATA_MENU_TRACE] )
            {
                ambienceSound(id, SOUND_MENU_NAV)
                ambienceMenu(id, MENU_ROOT)

                DisableAction(id)
                g_ePlayerData[id][PDATA_AMBIENCE_MENU] = 0
            }

            g_ePlayerData[id][PDATA_MENU_TRACE] = false
        }
        default:
        {
            DisableAction(id)
            g_ePlayerData[id][PDATA_AMBIENCE_MENU] = 0
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuStatus(id, iMenu)
{
    new szItem[64], eAmbience[AMBIENCE]
    menuNav(id, iMenu)
    ArrayGetArray(g_aAmbience, g_ePlayerData[id][PDATA_AMBIENCE_MENU], eAmbience)

    formatex(szItem, charsmax(szItem), "%L", id, "AMBIENCE_STATUS_CURRENT",
    eAmbience[AMBIENCE_FLAGS] & FLAG_ACTIVE ? "\y" : "\r", eAmbience[AMBIENCE_NAME], id, eAmbience[AMBIENCE_FLAGS] & FLAG_ACTIVE ? "AMBIENCE_ENABLED" : "AMBIENCE_DISABLED")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "AMBIENCE_STATUS_ALL_ENABLE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "AMBIENCE_STATUS_ALL_DISABLE")
    menu_additem(iMenu, szItem)

    EnableAction(id)
    ambienceSelect(eAmbience, TARGET_SELECT)
    g_ePlayerData[id][PDATA_MENU_TYPE] = MENU_STATUS
    ArraySetArray(g_aAmbience, g_ePlayerData[id][PDATA_AMBIENCE_MENU], eAmbience)
}

public menuHandlerStatus(id, menu, item)
{
    new eAmbience[AMBIENCE]
    ArrayGetArray(g_aAmbience, g_ePlayerData[id][PDATA_AMBIENCE_MENU], eAmbience)
    if ( !g_ePlayerData[id][PDATA_MENU_TRACE] )
        ambienceSelect(eAmbience, TARGET_GHOST)

    switch( item )
    {
        case STATUS_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_AMBIENCE_MENU] >= g_iAmbience - 1 )
                g_ePlayerData[id][PDATA_AMBIENCE_MENU] = 0
            else
                g_ePlayerData[id][PDATA_AMBIENCE_MENU] ++

            ambienceSound(id, SOUND_MENU_NAV)
            ambienceMenu(id, MENU_STATUS)
        }
        case STATUS_BACK:
        {
            if ( g_ePlayerData[id][PDATA_AMBIENCE_MENU] <= 0 )
                g_ePlayerData[id][PDATA_AMBIENCE_MENU] = g_iAmbience - 1
            else
                g_ePlayerData[id][PDATA_AMBIENCE_MENU] --

            ambienceSound(id, SOUND_MENU_NAV)
            ambienceMenu(id, MENU_STATUS)
        }
        case STATUS_CURRENT:
        {
            eAmbience[AMBIENCE_FLAGS] ^= FLAG_ACTIVE
            ambienceSetState(eAmbience)

            client_print_color(id, id, "%L %L", id, "AMBIENCE_CHAT_TAG", id, "AMBIENCE_CHAT_STATUS_CURRENT",
            eAmbience[AMBIENCE_NAME], id, eAmbience[AMBIENCE_FLAGS] & FLAG_ACTIVE ? "AMBIENCE_CHAT_ENABLED" : "AMBIENCE_CHAT_DISABLED")
            ArraySetArray(g_aAmbience, g_ePlayerData[id][PDATA_AMBIENCE_MENU], eAmbience)

            ambienceSound(id, SOUND_MENU_NAV)
            ambienceMenu(id, MENU_STATUS)
        }
        case STATUS_ALL_ENABLE:
        {
            for ( new i = 0; i < g_iAmbience; i ++ )
            {
                ArrayGetArray(g_aAmbience, i, eAmbience)
                eAmbience[AMBIENCE_FLAGS] |= FLAG_ACTIVE
                ambienceSetState(eAmbience)

                ArraySetArray(g_aAmbience, i, eAmbience)
            }

            client_print_color(id, id, "%L %L", id, "AMBIENCE_CHAT_TAG", id, "AMBIENCE_CHAT_STATUS_ALL_ENABLED")
            ambienceSound(id, SOUND_MENU_ALERT)
            ambienceMenu(id, MENU_STATUS)
        }
        case STATUS_ALL_DISABLE:
        {
            for ( new i = 0; i < g_iAmbience; i ++ )
            {
                ArrayGetArray(g_aAmbience, i, eAmbience)
                eAmbience[AMBIENCE_FLAGS] &= ~FLAG_ACTIVE
                ambienceSetState(eAmbience)

                ArraySetArray(g_aAmbience, i, eAmbience)
            }

            client_print_color(id, id, "%L %L", id, "AMBIENCE_CHAT_TAG", id, "AMBIENCE_CHAT_STATUS_ALL_DISABLED")
            ambienceSound(id, SOUND_MENU_ALERT)
            ambienceMenu(id, MENU_STATUS)
        }
        case MENU_EXIT:
        {
            if ( !g_ePlayerData[id][PDATA_MENU_TRACE] )
            {
                ambienceSound(id, SOUND_MENU_NAV)
                ambienceMenu(id, MENU_ROOT)

                DisableAction(id)
                g_ePlayerData[id][PDATA_AMBIENCE_MENU] = 0
            }

            g_ePlayerData[id][PDATA_MENU_TRACE] = false
        }
        default:
        {
            DisableAction(id)
            g_ePlayerData[id][PDATA_AMBIENCE_MENU] = 0
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuRotate(id, iMenu)
{
    new szItem[64], eAmbience[AMBIENCE]
    if ( ambienceGet(eAmbience, g_ePlayerData[id][PDATA_AMBIENCE_GHOST]) == -1 )
    {
        menu_destroy(iMenu)
        return
    }

    formatex(szItem, charsmax(szItem), "%L", id, "AMBIENCE_ROTATE_UP")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "AMBIENCE_ROTATE_DOWN")
    menu_additem(iMenu, szItem)

    menu_addblank2(iMenu)

    formatex(szItem, charsmax(szItem), "%L", id, "AMBIENCE_ROTATE_PLACE")
    menu_additem(iMenu, szItem)
}

public menuHandlerRotate(id, menu, item)
{
    new eAmbience[AMBIENCE], iItem
    if ( (iItem = ambienceGet(eAmbience, g_ePlayerData[id][PDATA_AMBIENCE_GHOST])) == -1 )
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    switch( item )
    {
        case ROTATE_UP:
        {
            pev(eAmbience[AMBIENCE_ID], pev_angles, eAmbience[AMBIENCE_ANGLES])
            eAmbience[AMBIENCE_ANGLES][1] -= g_eSettings[SETTING_ROTATION_STEP]
            if ( eAmbience[AMBIENCE_ANGLES][1] < -180.0 ) eAmbience[AMBIENCE_ANGLES][1] += 360.0

            set_pev(eAmbience[AMBIENCE_ID], pev_angles, eAmbience[AMBIENCE_ANGLES])
            ArraySetArray(g_aAmbience, iItem, eAmbience)

            ambienceSound(id, SOUND_MENU_NAV)
            ambienceMenu(id, MENU_ROTATE)
        }
        case ROTATE_DOWN:
        {
            pev(eAmbience[AMBIENCE_ID], pev_angles, eAmbience[AMBIENCE_ANGLES])
            eAmbience[AMBIENCE_ANGLES][1] += g_eSettings[SETTING_ROTATION_STEP]
            if ( eAmbience[AMBIENCE_ANGLES][1] > 180.0 ) eAmbience[AMBIENCE_ANGLES][1] -= 360.0

            set_pev(eAmbience[AMBIENCE_ID], pev_angles, eAmbience[AMBIENCE_ANGLES])
            ArraySetArray(g_aAmbience, iItem, eAmbience)

            ambienceSound(id, SOUND_MENU_NAV)
            ambienceMenu(id, MENU_ROTATE)
        }
        case ROTATE_PLACE:
        {
            ambienceTrace(eAmbience, id)
            DisableAction(id)
            set_pdata_float(id, PDATA_NEXT_ATTACK, 0.0, XO_CBASEPLAYER, XO_CBASEPLAYER)
            g_ePlayerData[id][PDATA_AMBIENCE_GHOST] = 0

            eAmbience[AMBIENCE_FLAGS] &= ~FLAG_GHOST
            eAmbience[AMBIENCE_FLAGS] |= FLAG_ACTIVE
            ambienceSetSeq(eAmbience[AMBIENCE_ID])
            ambienceSetSize(eAmbience)
            client_print_color(id, id, "%L %L", id, "AMBIENCE_CHAT_TAG", id, "AMBIENCE_CHAT_CREATE_NEW", eAmbience[AMBIENCE_NAME])

            ArraySetArray(g_aAmbience, iItem, eAmbience)
            ambienceSound(id, SOUND_MENU_NAV)
            ambienceMenu(id, MENU_CREATE)
        }
        case MENU_EXIT:
        {
            ambienceKill(eAmbience[AMBIENCE_ID])
            ambienceRemove(iItem)
            DisableAction(id)
            set_pdata_float(id, PDATA_NEXT_ATTACK, 0.0, XO_CBASEPLAYER, XO_CBASEPLAYER)
            g_ePlayerData[id][PDATA_AMBIENCE_GHOST] = 0

            ambienceSound(id, SOUND_MENU_NAV)
            ambienceMenu(id, MENU_CREATE)
        }
        default:
        {
            ambienceKill(eAmbience[AMBIENCE_ID])
            ambienceRemove(iItem)
            DisableAction(id)
            set_pdata_float(id, PDATA_NEXT_ATTACK, 0.0, XO_CBASEPLAYER, XO_CBASEPLAYER)
            g_ePlayerData[id][PDATA_AMBIENCE_GHOST] = 0
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public ambienceTask()
{
    new eAmbience[AMBIENCE], Float:fCurrentTime
    fCurrentTime = get_gametime()

    for ( new i = 0; i < g_iAmbience; i ++ )
    {
        ArrayGetArray(g_aAmbience, i, eAmbience)
        if ( !(eAmbience[AMBIENCE_FLAGS] & FLAG_ACTIVE)
        || (!(eAmbience[AMBIENCE_FLAGS] & FLAG_DURATION) && eAmbience[AMBIENCE_FLAGS] & FLAG_PLAYING) )
            continue

        if ( fCurrentTime >= eAmbience[AMBIENCE_NEXT_SOUND] )
        {
            if ( eAmbience[AMBIENCE_FLAGS] & FLAG_PLAYING )
                engfunc(EngFunc_EmitAmbientSound, eAmbience[AMBIENCE_ID], eAmbience[AMBIENCE_ORIGIN], eAmbience[AMBIENCE_SOUND_CURRENT], eAmbience[AMBIENCE_SOUND_VOL], eAmbience[AMBIENCE_SOUND_ATTN], SND_STOP, eAmbience[AMBIENCE_SOUND_PITCH])

            ArrayGetString(eAmbience[AMBIENCE_SOUND], random(ArraySize(eAmbience[AMBIENCE_SOUND])), eAmbience[AMBIENCE_SOUND_CURRENT], charsmax(eAmbience[AMBIENCE_SOUND_CURRENT]))
            engfunc(EngFunc_EmitAmbientSound, eAmbience[AMBIENCE_ID], eAmbience[AMBIENCE_ORIGIN], eAmbience[AMBIENCE_SOUND_CURRENT], eAmbience[AMBIENCE_SOUND_VOL], eAmbience[AMBIENCE_SOUND_ATTN], 0, eAmbience[AMBIENCE_SOUND_PITCH])
            eAmbience[AMBIENCE_NEXT_SOUND] = fCurrentTime + random_float(eAmbience[AMBIENCE_SOUND_DURATION][0], eAmbience[AMBIENCE_SOUND_DURATION][1])
            eAmbience[AMBIENCE_FLAGS] |= FLAG_PLAYING

            ArraySetArray(g_aAmbience, i, eAmbience)
        }
    }
}

stock ambienceCreate(id, iItem)
{
    new iEnt = cs_create_entity("info_target")
    if ( !pev_valid(iEnt) )
        return

    new eAmbience[AMBIENCE]
    ArrayGetArray(g_aAmbienceConfig, iItem, eAmbience)
    eAmbience[AMBIENCE_ID] = iEnt
    eAmbience[AMBIENCE_ITEM] = iItem
    if ( id )
    {
        EnableAction(id)
        g_ePlayerData[id][PDATA_AMBIENCE_GHOST] = eAmbience[AMBIENCE_ID]
        g_ePlayerData[id][PDATA_OFFSET] = g_eSettings[SETTING_OFFSET_BASE]

        eAmbience[AMBIENCE_FLAGS] |= FLAG_GHOST
    }

    ambienceSelect(eAmbience, TARGET_GHOST)
    set_pev(iEnt, pev_classname, g_szCN)
    set_pev(iEnt, pev_impulse, AMBIENCE_KEY)
    set_pev(iEnt, AMBIENCE_ARRAY_ITEM, g_iAmbience)
    dllfunc(DLLFunc_Spawn, iEnt)
    set_pev(iEnt, pev_solid, SOLID_NOT)
    set_pev(iEnt, pev_movetype, MOVETYPE_FLY)
    engfunc(EngFunc_SetModel, iEnt, g_eSettings[SETTING_DEFAULT_MODEL])

    ArrayPushArray(g_aAmbience, eAmbience)
    if ( ++ g_iAmbience == 1 )
        set_task(g_eSettings[SETTING_AMBIENCE_TASK], "ambienceTask", AMBIENCE_KEY, .flags = "b")
}

public ambienceRemove(iItem)
{
    new eAmbience[AMBIENCE]
    ArrayDeleteItem(g_aAmbience, iItem)

    if ( -- g_iAmbience == 0 )
        remove_task(AMBIENCE_KEY)

    for ( new i = iItem; i < g_iAmbience; i ++ )
    {
        ArrayGetArray(g_aAmbience, i, eAmbience)
        set_pev(eAmbience[AMBIENCE_ID], AMBIENCE_ARRAY_ITEM, i)
    }
}

public saveData(id)
{
    new eAmbience[AMBIENCE],
        szFile[128], iFile,
        szData[64]

    get_mapname(szFile, charsmax(szFile))
    format(szFile, charsmax(szFile), "maps/%s_MapAmbience.ini", szFile)

    iFile = fopen(szFile, "wt")
    if ( !iFile )
        return PLUGIN_HANDLED

    ambienceTerminate()
    for ( new i = 0; i < g_iAmbience; i ++ )
    {
        ArrayGetArray(g_aAmbience, i, eAmbience)

        formatex(szData, charsmax(szData), "[%d]^n", i)
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "item = %d^n", eAmbience[AMBIENCE_ITEM])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "origin = %.2f %.2f %.2f^n",
        eAmbience[AMBIENCE_ORIGIN][0], eAmbience[AMBIENCE_ORIGIN][1], eAmbience[AMBIENCE_ORIGIN][2])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "angles = %.2f %.2f %.2f^n",
        eAmbience[AMBIENCE_ANGLES][0], eAmbience[AMBIENCE_ANGLES][1], eAmbience[AMBIENCE_ANGLES][2])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "flags = %d^n", eAmbience[AMBIENCE_FLAGS])
        fputs(iFile, szData)
    }

    client_print_color(id, id, "%L %L", id, "AMBIENCE_CHAT_TAG", id, "AMBIENCE_CHAT_SAVE", szFile)
    fclose(iFile)

    ambienceSound(id, SOUND_MENU_NAV)
    ambienceMenu(id, MENU_ROOT)
    return PLUGIN_HANDLED
}

public loadData()
{
    new szFile[128], iFile,
        szData[64], szKey[32], szValue[32],
        Float:fOrigin[3], Float:fAngles[3], iItem, iFlags, iCount = -1

    get_mapname(szFile, charsmax(szFile))
    format(szFile, charsmax(szFile), "maps/%s_MapAmbience.ini", szFile)

    iFile = fopen(szFile, "rt")
    if ( !iFile )
        return PLUGIN_HANDLED

    while( !feof(iFile) )
    {
        fgets(iFile, szData, charsmax(szData))

        if ( szData[0] == '[' )
        {
            if ( iCount != -1 )
                loadDataAmbience(fOrigin, fAngles, iFlags, iItem, iCount)

            iCount ++
        }
        else
        {
            strtok(szData, szKey, charsmax( szKey ), szValue, charsmax( szValue ), '=')
            trim(szKey)
            trim(szValue)

            if ( equal(szKey, "item") )
            {
                iItem = str_to_num(szValue)
            }
            else if ( equal(szKey, "origin") )
            {
                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fOrigin[0] = str_to_float(szKey)

                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fOrigin[1] = str_to_float(szKey)
                fOrigin[2] = str_to_float(szValue)
            }
            else if ( equal(szKey, "angles") )
            {
                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fAngles[0] = str_to_float(szKey)

                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fAngles[1] = str_to_float(szKey)
                fAngles[2] = str_to_float(szValue)
            }
            else if ( equal(szKey, "flags") )
            {
                iFlags = str_to_num(szValue)
            }
        }
    }

    if ( iCount != -1 )
        loadDataAmbience(fOrigin, fAngles, iFlags, iItem, iCount)

    fclose(iFile)
    return PLUGIN_HANDLED
}

stock loadDataAmbience(Float:fOrigin[3], Float:fAngles[3], iFlags, iItem, iCount)
{
    new eAmbience[AMBIENCE]
    ambienceCreate(0, iItem)
    ArrayGetArray(g_aAmbience, iCount, eAmbience)

    xs_vec_copy(fOrigin, eAmbience[AMBIENCE_ORIGIN])
    xs_vec_copy(fAngles, eAmbience[AMBIENCE_ANGLES])
    eAmbience[AMBIENCE_FLAGS] = iFlags

    ambienceSetSeq(eAmbience[AMBIENCE_ID])
    ambienceSetSize(eAmbience)
    ArraySetArray(g_aAmbience, iCount, eAmbience)
}

public ambienceNoClip(id)
{
    set_user_noclip(id, !get_user_noclip(id))

    ambienceSound(id, SOUND_MENU_NAV)
    ambienceMenu(id, MENU_ROOT)
}

public ambienceGodMode(id)
{
    set_user_godmode(id, !get_user_godmode(id))

    ambienceSound(id, SOUND_MENU_NAV)
    ambienceMenu(id, MENU_ROOT)
}

public fwdUpdateClientData(id, iSendWeapons, iHandle)
{
    if ( g_ePlayerData[id][PDATA_AMBIENCE_GHOST] )
    {
        set_cd(iHandle, CD_WeaponAnim, 0)
        set_cd(iHandle, CD_flNextAttack, get_gametime() + 0.1)
    }

    return FMRES_IGNORED
}

public fwdPreThink(id)
{
    if ( !is_user_alive(id) )
        return HAM_IGNORED

    static eAmbience[AMBIENCE], iButton, Float:fCurrentTime
    iButton = pev(id, pev_button)
    fCurrentTime = get_gametime()

    if ( ambienceGet(eAmbience, g_ePlayerData[id][PDATA_AMBIENCE_GHOST]) != -1 )
    {
        if ( fCurrentTime > g_ePlayerData[id][PDATA_NEXT_OFFSET] )
        {
            if ( iButton & IN_ATTACK )
            {
                g_ePlayerData[id][PDATA_OFFSET]      += g_eSettings[SETTING_OFFSET_STEP]
                g_ePlayerData[id][PDATA_OFFSET]      = floatclamp(g_ePlayerData[id][PDATA_OFFSET], g_eSettings[SETTING_OFFSET][0], g_eSettings[SETTING_OFFSET][1])
                g_ePlayerData[id][PDATA_NEXT_OFFSET] = fCurrentTime + 0.1
            }
            else if ( iButton & IN_ATTACK2 )
            {
                g_ePlayerData[id][PDATA_OFFSET]      -= g_eSettings[SETTING_OFFSET_STEP]
                g_ePlayerData[id][PDATA_OFFSET]      = floatclamp(g_ePlayerData[id][PDATA_OFFSET], g_eSettings[SETTING_OFFSET][0], g_eSettings[SETTING_OFFSET][1])
                g_ePlayerData[id][PDATA_NEXT_OFFSET] = fCurrentTime + 0.1
            }
        }

        set_pdata_float(id, PDATA_NEXT_ATTACK, fCurrentTime + 0.1, XO_CBASEPLAYER, XO_CBASEPLAYER)
        iButton &= ~(IN_ATTACK | IN_ATTACK2)
        set_pev(id, pev_button, iButton)

        ambienceTrace(eAmbience, id)
    }
    else if ( g_ePlayerData[id][PDATA_AMBIENCE_ACTION] )
    {
        ambienceCheck(id)
    }

    return HAM_IGNORED
}

public fwdKilled(id, iAttacker, bGib)
{
    DisableAction(id)
    g_ePlayerData[id][PDATA_AMBIENCE_MENU]   = 0
    if ( g_ePlayerData[id][PDATA_AMBIENCE_GHOST] )
    {
        new eAmbience[AMBIENCE], iItem
        if ( (iItem = ambienceGet(eAmbience, g_ePlayerData[id][PDATA_AMBIENCE_GHOST])) != -1 )
        {
            ambienceKill(g_ePlayerData[id][PDATA_AMBIENCE_GHOST])
            ambienceRemove(iItem)
        }

        g_ePlayerData[id][PDATA_AMBIENCE_GHOST] = 0
    }
}

stock ambienceTrace(eAmbience[AMBIENCE], id)
{
    new Float:fVec1[3]
    pev(id, pev_origin, eAmbience[AMBIENCE_ORIGIN])
    pev(id, pev_view_ofs, fVec1)
    xs_vec_add(eAmbience[AMBIENCE_ORIGIN], fVec1, eAmbience[AMBIENCE_ORIGIN])
    pev(id, pev_v_angle, fVec1)
    engfunc(EngFunc_MakeVectors, fVec1)
    global_get(glb_v_forward, fVec1)

    xs_vec_mul_scalar(fVec1, g_ePlayerData[id][PDATA_OFFSET], fVec1)
    xs_vec_add(fVec1, eAmbience[AMBIENCE_ORIGIN], fVec1)

    engfunc(EngFunc_TraceLine, eAmbience[AMBIENCE_ORIGIN], fVec1, DONT_IGNORE_MONSTERS, id, 0)
    get_tr2(0, TR_vecEndPos, eAmbience[AMBIENCE_ORIGIN])
    set_pev(eAmbience[AMBIENCE_ID], pev_origin, eAmbience[AMBIENCE_ORIGIN])
}

stock ambienceCheck(id)
{
    new eAmbience[AMBIENCE], Float:fVec1[3], Float:fVec2[3], Float:fVec3[3]
    new iBest, Float:fBestDist, Float:fDot, Float:fDist

    pev(id, pev_origin, fVec1)
    pev(id, pev_view_ofs, fVec2)
    xs_vec_add(fVec1, fVec2, fVec1)

    pev(id, pev_v_angle, fVec2)
    engfunc(EngFunc_MakeVectors, fVec2)
    global_get(glb_v_forward, fVec2)

    iBest = -1
    fBestDist = g_eSettings[SETTING_AMBIENCE_CHECK]
    for ( new i = 0; i < g_iAmbience; i ++ )
    {
        ArrayGetArray(g_aAmbience, i, eAmbience)
        xs_vec_sub(eAmbience[AMBIENCE_ORIGIN], fVec1, fVec3)
        fDot = xs_vec_dot(fVec2, fVec3)

        if ( fDot < 0.0 )
            continue

        xs_vec_mul_scalar(fVec2, fDot, fVec3)
        xs_vec_add(fVec3, fVec1, fVec3)
        fDist = get_distance_f(fVec3, eAmbience[AMBIENCE_ORIGIN])
        if ( fDist < fBestDist )
        {
            fBestDist = fDist
            iBest = i
        }
    }

    if ( iBest != -1
    && g_ePlayerData[id][PDATA_AMBIENCE_MENU] != iBest )
    {
        ArrayGetArray(g_aAmbience, g_ePlayerData[id][PDATA_AMBIENCE_MENU], eAmbience)
        ambienceSelect(eAmbience, TARGET_GHOST)

        g_ePlayerData[id][PDATA_MENU_TRACE] = true
        g_ePlayerData[id][PDATA_AMBIENCE_MENU] = iBest
        ambienceMenu(id, g_ePlayerData[id][PDATA_MENU_TYPE])
    }
}

stock ambienceSetSeq(iEnt)
{
    set_pev(iEnt, pev_sequence, 0)
    set_pev(iEnt, pev_frame, 0.0)
    set_pev(iEnt, pev_framerate, 1.0)
    set_pev(iEnt, pev_animtime, get_gametime())
}

stock ambienceSetSize(eAmbience[AMBIENCE])
{
    ambienceSelect(eAmbience, TARGET_HIDE)
    engfunc(EngFunc_SetOrigin, eAmbience[AMBIENCE_ID], eAmbience[AMBIENCE_ORIGIN])
    set_pev(eAmbience[AMBIENCE_ID], pev_angles, eAmbience[AMBIENCE_ANGLES])
    set_pev(eAmbience[AMBIENCE_ID], pev_solid, SOLID_NOT)
    set_pev(eAmbience[AMBIENCE_ID], pev_movetype, MOVETYPE_NONE)
}

stock ambienceSetState(eAmbience[AMBIENCE])
{
    if ( eAmbience[AMBIENCE_FLAGS] & FLAG_ACTIVE )
    {
        eAmbience[AMBIENCE_NEXT_SOUND] = 0.0
    }
    else
    {
        if ( eAmbience[AMBIENCE_FLAGS] & FLAG_PLAYING )
        {
            eAmbience[AMBIENCE_FLAGS] &= ~FLAG_PLAYING
            engfunc(EngFunc_EmitAmbientSound, eAmbience[AMBIENCE_ID], CHAN_ITEM, eAmbience[AMBIENCE_SOUND_CURRENT], VOL_NORM, ATTN_NORM, SND_STOP, PITCH_NORM)
        }
    }
}

stock ambienceSelect(eAmbience[AMBIENCE], iAction)
{
    new iRenderColor[3]
    if ( iAction == TARGET_SELECT )
    {
        if ( eAmbience[AMBIENCE_FLAGS] & FLAG_ACTIVE )  { iRenderColor[0] = g_iColorActive[0];    iRenderColor[1] = g_iColorActive[1];    iRenderColor[2] = g_iColorActive[2]; }
        else                                            { iRenderColor[0] = g_iColorInactive[0];  iRenderColor[1] = g_iColorInactive[1];  iRenderColor[2] = g_iColorInactive[2]; }

        set_ent_rendering(eAmbience[AMBIENCE_ID], kRenderFxGlowShell, iRenderColor[0], iRenderColor[1], iRenderColor[2], kRenderTransAlpha, 16)
    }
    else if ( iAction == TARGET_GHOST )
    {
        set_ent_rendering(eAmbience[AMBIENCE_ID], kRenderFxNone, 255, 255, 255, kRenderTransAlpha, g_eSettings[SETTING_GHOST_ALPHA])
    }
    else if ( iAction == TARGET_HIDE )
    {
        set_ent_rendering(eAmbience[AMBIENCE_ID], kRenderFxNone, 255, 255, 255, kRenderTransAlpha, 0)
    }
    else if ( iAction == TARGET_CLEAR )
    {
        set_ent_rendering(eAmbience[AMBIENCE_ID], kRenderFxNone, 255, 255, 255, kRenderNormal, 255)
    }
}

stock ambienceSound(iEnt, iSound, bool:bPlayer = true)
{
    new szSample[64]
    switch( iSound )
    {
        case SOUND_MENU_NAV:    copy(szSample, charsmax(szSample), SOUND_NAV)
        case SOUND_MENU_REMOVE: copy(szSample, charsmax(szSample), SOUND_REMOVE)
        case SOUND_MENU_ALERT:  copy(szSample, charsmax(szSample), SOUND_ALERT)
    }

    if ( bPlayer )
        client_cmd(iEnt, "spk %s", szSample)
    else
        engfunc(EngFunc_EmitSound, iEnt, CHAN_ITEM, szSample, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
}

stock ambienceReset()
{
    new eAmbience[AMBIENCE]
    for ( new i = 0; i < g_iAmbience; i ++ )
    {
        ArrayGetArray(g_aAmbience, i, eAmbience)
        eAmbience[AMBIENCE_NEXT_SOUND] = 0.0
        ArraySetArray(g_aAmbience, i, eAmbience)
    }
}

stock ambienceGet(eAmbience[AMBIENCE], iEnt)
{
    if ( !isAmbience(iEnt) )
        return -1

    new iItem
    iItem = pev(iEnt, AMBIENCE_ARRAY_ITEM)
    if ( iItem < 0 || iItem >= g_iAmbience )
        return -1

    ArrayGetArray(g_aAmbience, iItem, eAmbience)
    return iItem
}

stock bool:isAmbience(iEnt)
{
    return pev_valid(iEnt) && pev(iEnt, pev_impulse) == AMBIENCE_KEY
}

stock ambienceKill(iEnt)
{
    if ( pev_valid(iEnt) )
        set_pev(iEnt, pev_flags, pev(iEnt, pev_flags) | FL_KILLME)
}

stock parseSetting(iType, szValue[], iValueLen, any:aOutput[], iOutputLength)
{
    switch ( iType )
    {
        case DTYPE_INT:
        {
            new szTok[MAX_VALUE_LENGTH], szTmp[MAX_VALUE_LENGTH], iCounter
            copy(szTmp, charsmax(szTmp), szValue)

            strtok(szTmp, szTok, charsmax(szTok), szTmp, charsmax(szTmp), ' ')
            trim(szTok)
            while ( szTok[0] )
            {
                aOutput[iCounter ++] = str_to_num(szTok)

                strtok(szTmp, szTok, charsmax(szTok), szTmp, charsmax(szTmp), ' ')
                trim(szTok)
            }
        }
        case DTYPE_FLOAT:
        {
            new szTok[MAX_VALUE_LENGTH], szTmp[MAX_VALUE_LENGTH], iCounter
            copy(szTmp, charsmax(szTmp), szValue)

            strtok(szTmp, szTok, charsmax(szTok), szTmp, charsmax(szTmp), ' ')
            trim(szTok)
            while ( szTok[0] )
            {
                aOutput[iCounter ++] = str_to_float(szTok)

                strtok(szTmp, szTok, charsmax(szTok), szTmp, charsmax(szTmp), ' ')
                trim(szTok)
            }
        }
        case DTYPE_FLAGS:
        {
            aOutput[0] = read_flags(szValue)
        }
        case DTYPE_ARRAY_STRING:
        {
            replace_all(szValue, iValueLen, "^"", " ")
            replace_all(szValue, iValueLen, "^^n", "^n")
            ArrayPushString(aOutput[0], szValue)
        }
        case DTYPE_ARRAY_SOUND:
        {
            ArrayPushString(aOutput[0], szValue)
            if ( !g_bFileWasRead ) precache_sound(szValue)
        }
        case DTYPE_STRING_MODEL:
        {
            copy(aOutput, iOutputLength, szValue)
            if ( !g_bFileWasRead ) precache_model(szValue)
        }
        case DTYPE_STRING_SOUND:
        {
            copy(aOutput, iOutputLength, szValue)
            if ( !g_bFileWasRead ) precache_sound(szValue)
        }
        case DTYPE_STRING_MODEL_ID:
        {
            if ( !g_bFileWasRead )
                aOutput[0] = precache_model(szValue)
        }
    }
}

stock EnableAction(id)
{
    if ( !g_ePlayerData[id][PDATA_AMBIENCE_ACTION] )
    {
        new eAmbience[AMBIENCE]
        for ( new i = 0; i < g_iAmbience; i ++ )
        {
            ArrayGetArray(g_aAmbience, i, eAmbience)
            ambienceSelect(eAmbience, TARGET_GHOST)
        }

        g_ePlayerData[id][PDATA_AMBIENCE_ACTION] = true
        if ( ++ g_iActivePlayers == 1 )
            EnableForward()
    }
}

stock DisableAction(id)
{
    if ( g_ePlayerData[id][PDATA_AMBIENCE_ACTION] )
    {
        new eAmbience[AMBIENCE]
        for ( new i = 0; i < g_iAmbience; i ++ )
        {
            ArrayGetArray(g_aAmbience, i, eAmbience)
            ambienceSelect(eAmbience, TARGET_HIDE)
        }

        g_ePlayerData[id][PDATA_AMBIENCE_ACTION] = false
        if ( -- g_iActivePlayers == 0 )
            DisableForward()
    }
}

stock EnableForward()
{
    EnableHamForward(g_iFwdPreThink)
    EnableHamForward(g_iFwdKilled)
}

stock DisableForward()
{
    DisableHamForward(g_iFwdPreThink)
    DisableHamForward(g_iFwdKilled)
}

stock LogConfigError(const iLine, const szText[], any:...)
{
    new szError[MAX_PLATFORM_PATH_LENGTH]
    vformat(szError, charsmax(szError), szText, 3)

    log_to_file(ERROR_FILE, "^nLine %d: %s", iLine, szError)
}


