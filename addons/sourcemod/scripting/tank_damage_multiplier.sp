#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

public Plugin myinfo = {
    name        = "TankDamageMultiplier",
    description = "The plugin changes the damage of a bullet to a tank depending on the weapon",
    author      = "TouchMe",
    version     = "build0001",
    url         = "https://github.com/TouchMe-Inc/anyl4d_tank_damage_multiplier"
};


#define TEAM_SURVIVOR           2
#define TEAM_INFECTED           3


bool g_bLateLoad = false;

int g_iTankClass = 0;

Handle g_hTrie = null;


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    switch (GetEngineVersion())
    {
        case Engine_Left4Dead: g_iTankClass = 5;
        case Engine_Left4Dead2: g_iTankClass = 8;
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
    RegServerCmd("tank_damage_multiplier_set", Command_AddTrie, "tank_damage_multiplier_set <weapon> <value>");
    RegServerCmd("tank_damage_multiplier_remove", Command_RemoveTrie, "tank_damage_multiplier_set <weapon>");

    if (g_bLateLoad) {
        for (int iClient = 1; iClient <= MaxClients; iClient ++) {
            if (IsClientInGame(iClient)) {
                OnClientPutInServer(iClient);
            }
        }
    }
}

Action Command_AddTrie(int args) {
    if (args != 2) {
        PrintToServer("Usage: tank_damage_multiplier_set <weapon> <value>");
        return Plugin_Handled;
    }

    char key[32];
    char value[12];
    GetCmdArg(1, key, sizeof(key));
    GetCmdArg(2, value, sizeof(value));

    SetTrieValue(g_hTrie, key, StringToFloat(value));

    return Plugin_Handled;
}

Action Command_RemoveTrie(int args) {
    if (args != 1) {
        PrintToServer("Usage: tank_damage_multiplier_remove <weapon>");
        return Plugin_Handled;
    }

    char key[64];
    GetCmdArg(1, key, sizeof(key));

    RemoveFromTrie(g_hTrie, key);

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

    char sWeaponName[64];
    GetClientWeapon(iAttacker,sWeaponName, sizeof(sWeaponName));

    if (!GetTrieValue(g_hTrie, sWeaponName, fMultiplier)) {
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
