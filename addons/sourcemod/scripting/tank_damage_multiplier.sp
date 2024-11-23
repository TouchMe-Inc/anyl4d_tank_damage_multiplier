#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>


public Plugin myinfo = {
    name        = "TankDamageMultiplier",
    description = "The plugin changes the damage of a bullet to a tank depending on the weapon",
    author      = "TouchMe",
    version     = "build0001",
    url         = "https://github.com/TouchMe-Inc/anyl4d_tank_damage_multiplier"
};


#define TEAM_SURVIVOR           2
#define TEAM_INFECTED           3

#define TANK_L4D                5
#define TANK_L4D2               8

bool g_bLateLoad = false;

int g_iTankClass = 0;

Handle g_hTrie = null;


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    switch (GetEngineVersion())
    {
        case Engine_Left4Dead: g_iTankClass = TANK_L4D;
        case Engine_Left4Dead2: g_iTankClass = TANK_L4D2;
        default: {
            strcopy(error, err_max, "Plugin only supports Left 4 Dead & Left 4 Dead 2.");
            return APLRes_SilentFailure;
        }
    }

    g_bLateLoad = late;

    return APLRes_Success;
}

public void OnPluginStart()
{
    g_hTrie = CreateTrie();
    RegServerCmd("tank_damage_multiplier_set", Cmd_Set, "tank_damage_multiplier_set <weapon> <value>");
    RegServerCmd("tank_damage_multiplier_remove", Cmd_Remove, "tank_damage_multiplier_set <weapon>");

    if (g_bLateLoad)
    {
        for (int iClient = 1; iClient <= MaxClients; iClient ++) {
            if (IsClientInGame(iClient)) {
                OnClientPutInServer(iClient);
            }
        }
    }
}

Action Cmd_Set(int iArgs)
{
    if (iArgs != 2)
    {
        PrintToServer("Usage: tank_damage_multiplier_set <weapon> <value>");
        return Plugin_Handled;
    }

    char szKey[32];
    char szValue[12];
    GetCmdArg(1, szKey, sizeof(szKey));
    GetCmdArg(2, szValue, sizeof(szValue));

    SetTrieValue(g_hTrie, szKey, StringToFloat(szValue));

    return Plugin_Handled;
}

Action Cmd_Remove(int iArgs)
{
    if (iArgs != 1)
    {
        PrintToServer("Usage: tank_damage_multiplier_remove <weapon>");
        return Plugin_Handled;
    }

    char szKey[32];
    GetCmdArg(1, szKey, sizeof(szKey));

    RemoveFromTrie(g_hTrie, szKey);

    return Plugin_Handled;
}

public void OnClientPutInServer(int iClient) {
    SDKHook(iClient, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
}

public void OnClientDisconnect(int iClient) {
    SDKUnhook(iClient, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
}

Action Hook_OnTakeDamage(int iVictim, int &iAttacker, int &iInflictor, float &fDamage, int &iDamagetype) {

    if (fDamage <= 0.0) {
        return Plugin_Continue;
    }

    if (!IsValidClient(iAttacker) || !IsClientInGame(iAttacker) || !IsClientSurvivor(iAttacker)) {
        return Plugin_Continue;
    }

    if (!IsValidClient(iVictim) || !IsClientInGame(iVictim) || !IsClientInfected(iVictim) || !IsClientTank(iVictim)) {
        return Plugin_Continue;
    }

    float fMultiplier = 0.0;

    char szWeaponName[32];
    GetClientWeapon(iAttacker,szWeaponName, sizeof(szWeaponName));

    if (!GetTrieValue(g_hTrie, szWeaponName, fMultiplier)) {
        return Plugin_Continue;
    }

    fDamage = (fDamage * (100.0 + fMultiplier)) / 100.0;
    return Plugin_Changed;
}

bool IsClientTank(int iClient) {
    return GetClientClass(iClient) == g_iTankClass;
}

/**
 * Validates if is a valid client.
 *
 * @param iClient   Client index.
 * @return          True if client is valid, false otherwise.
 */
bool IsValidClient(int iClient) {
    return (1 <= iClient <= MaxClients);
}

/**
 * Gets the client L4D1/L4D2 zombie class id.
 *
 * @param client     Client index.
 * @return L4D1      1=SMOKER, 2=BOOMER, 3=HUNTER, 4=WITCH, 5=TANK, 6=NOT INFECTED
 * @return L4D2      1=SMOKER, 2=BOOMER, 3=HUNTER, 4=SPITTER, 5=JOCKEY, 6=CHARGER, 7=WITCH, 8=TANK, 9=NOT INFECTED
 */
int GetClientClass(int iClient) {
    return GetEntProp(iClient, Prop_Send, "m_zombieClass");
}

/**
 * Returns whether the player is infected.
 */
bool IsClientInfected(int iClient) {
    return (GetClientTeam(iClient) == TEAM_INFECTED);
}

/**
 * Returns whether the player is survivor.
 */
bool IsClientSurvivor(int iClient) {
    return (GetClientTeam(iClient) == TEAM_SURVIVOR);
}
