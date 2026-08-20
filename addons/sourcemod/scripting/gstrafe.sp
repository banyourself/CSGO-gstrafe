#include <sourcemod>
#include <sdktools>
#include <kevac_movement>

native int kev_isFJActive();

ConVar g_cvMaxSpeed;
ConVar g_cvGain;

enum struct geeStrafe {
    float fDuckStart;
    float fDuckLast;
    float fDuckZLength;
	float fDuckMod;
	float fDuckVec[3];
	
	int iOldButtons;
	int ducks;
	bool jumped;
	
	void geeStrafe(){
		this.fDuckLast = GetGameTime();  //updateLastDuck()
		this.fDuckStart = GetGameTime(); //updateStartDuck()
	}

	float getLastDuck(){
		return GetGameTime()-this.fDuckLast;
	}
	float getStartDuck(){
		return GetGameTime()-this.fDuckStart;
	}
	void updateLastDuck(){
		this.fDuckLast = GetGameTime(); 
	}
	void updateStartDuck(){
		this.fDuckStart = GetGameTime();
	}
	float getDuckModifier(float fSpd){
		float fGain = g_cvGain.FloatValue;
		if(fSpd <= 0.0){
			this.fDuckMod = fGain;
			return this.fDuckMod;
		}

		// Continuous modifier: boosts land exactly on gstrafe_max_speed instead
		// of sawtoothing around it. At the cap the modifier is 1.0 (speed holds
		// steady); only genuinely over-cap speeds get trimmed, never harder
		// than 0.965 per duck so the trim stays gradual.
		float fTarget = fSpd * fGain;
		float fMax = g_cvMaxSpeed.FloatValue;
		if(fTarget > fMax){
			fTarget = fMax;
		}

		float fMod = fTarget / fSpd;
		if(fMod < 0.965){
			fMod = 0.965;
		}

		this.fDuckMod = fMod;
		return this.fDuckMod;
	}
	int getDuckCount() {
		return this.ducks;
	}
}

geeStrafe clientData[MAXPLAYERS+1];
int g_iDucks[MAXPLAYERS+1];

const float DUCKS_RESET_TIME = 2.5;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] szError, err_max)
{
	CreateNative("getDucks", _GS_GetDuckCount);
	CreateNative("getLastDuck", _GS_GetLastDuck);
	MarkNativeAsOptional("KevAC_IgnoreMovement");
	MarkNativeAsOptional("kev_isFJActive");

	return APLRes_Success;
}

// KevFJ turns off player collision entirely during funjump, so the trace filter
// has to stop blocking on enemies for that window or gstrafe boosts still die
// on contact. Optional, so gstrafe runs unchanged without KevFJ.
bool FJActive()
{
	return (GetFeatureStatus(FeatureType_Native, "kev_isFJActive") == FeatureStatus_Available && kev_isFJActive() != 0);
}

void SuppressKevACMovementChecks(int client)
{
	if (GetFeatureStatus(FeatureType_Native, "KevAC_IgnoreMovement") == FeatureStatus_Available)
		KevAC_IgnoreMovement(client, 4);
}

void ApplyDuckSettings()
{
	ConVar timeBetweenDucks = FindConVar("sv_timebetweenducks");
	if (timeBetweenDucks != null)
	{
		timeBetweenDucks.SetFloat(0.0, true);
	}
}

public int _GS_GetDuckCount(Handle plugin, int argc) {
	return g_iDucks[GetNativeCell(1)];
}

public any _GS_GetLastDuck(Handle plugin, int argc) {
	return view_as<any>(clientData[GetNativeCell(1)].getLastDuck());
}

public Plugin myinfo = {
	name = "gstrafe",
	author = "zwolof + diablix + Kevin",
	description = "",
	version = "1.1.1"
}

public OnPluginStart()
{
	g_cvMaxSpeed = CreateConVar("gstrafe_max_speed", "450.0", "Peak speed reachable by gstrafing. Above this, each duck trims speed back down.", FCVAR_NOTIFY, true, 250.0);
	g_cvGain = CreateConVar("gstrafe_gain", "1.025", "Speed multiplier applied per gstrafe duck below the max speed. (original build used 1.025)", FCVAR_NOTIFY, true, 1.0, true, 1.2);
	AutoExecConfig(true, "gstrafe");

	HookEvent("player_spawn", onPlayerSpawn);
	HookEvent("player_jump", onPlayerJump, EventHookMode_Post);
}

public OnMapStart()
{
	ApplyDuckSettings();
}

public void OnConfigsExecuted()
{
	ApplyDuckSettings();
}

public onPlayerSpawn(Handle hEvent, char[] sName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	g_iDucks[client] = 0;
	clientData[client].iOldButtons = 0;
	clientData[client].jumped = false;
	
	clientData[client].updateLastDuck();
	clientData[client].updateStartDuck();
}

public onPlayerJump(Handle hEvent, char[] sName, bool bDontBroadcast){
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(IsValidClient(client)) {
		clientData[client].jumped = true;
	}
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if (IsValidClient(client) && IsPlayerAlive(client))
	{
		if(GetEntPropFloat(client, Prop_Data, "m_flDuckSpeed") < 13.0) {
			SetEntPropFloat(client, Prop_Send, "m_flDuckSpeed", 13.0, 0);
		}
		
		if ((buttons & IN_DUCK))
		{
			if (!(clientData[client].iOldButtons & IN_DUCK)) {
				clientData[client].updateStartDuck();
			}
		}
		else if ((clientData[client].iOldButtons & IN_DUCK))
		{
			if(clientData[client].getStartDuck() < 0.135)
			{
				clientData[client].fDuckZLength = GetClientDistanceToGround(client);
				bool bUnits[2];
				bool modified = false;
				bUnits[0] = clientData[client].fDuckZLength < 1.0;
				bUnits[1] = clientData[client].fDuckZLength <= 1.0;
				
				if(bUnits[0] || bUnits[1])
				{
					if(clientData[client].getLastDuck() >= 0.250)
					{
						clientData[client].updateLastDuck();
						if(bUnits[0])
						{
							GetClientAbsOrigin(client, clientData[client].fDuckVec);
							clientData[client].fDuckVec[2] += 36.0;//22.0; 
							
							if(IsValidPlayerPos(client, clientData[client].fDuckVec))
							{
								TeleportEntity(client, clientData[client].fDuckVec, NULL_VECTOR, NULL_VECTOR);
								modified = true;
							}
						}
						if(bUnits[1])
						{
							GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", clientData[client].fDuckVec);
							float fSpeed = GetVectorLength(clientData[client].fDuckVec);
							if(fSpeed >= 140.0)
								{
									for(int i = 0 ; i < 2 ; i++) {
										clientData[client].fDuckVec[i] *= clientData[client].getDuckModifier(fSpeed);
									}
									TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, clientData[client].fDuckVec);
									modified = true;
								}
						}
						if(bUnits[0] || bUnits[1]) {
							//PrintToChat(client, "ducks: %d", g_iDucks[client]);
							g_iDucks[client]++;
							
							//if(clientData[client].jumped) {
							//	if(GetEntityFlags(client) & FL_ONGROUND) {
							//		clientData[client].jumped = false;
							//		g_iDucks[client] = 0;
							//	}
							//}
						}
					}
				}

				if (modified)
				{
					// Only my own teleports get the grace window. KevAC still sees the
					// raw command cadence either way.
					SuppressKevACMovementChecks(client);
				}
			}
			if(clientData[client].jumped) {
				if(GetEntityFlags(client) & FL_ONGROUND) {
					clientData[client].jumped = false;
					g_iDucks[client] = 0;
				}
			}
		}
		clientData[client].iOldButtons = buttons;
	}
	return Plugin_Continue;
}

//helpful
stock bool IsValidPlayerPos(int client, float fVec[3]){
	static const float fVecTr[][] = {{-16.0, -16.0, 0.0}, {16.0, 16.0, 72.0}};
	
	TR_TraceHullFilter(fVec, fVec, fVecTr[0], fVecTr[1], MASK_SOLID, TraceRayNoPlayers, client);
	
	return (!TR_DidHit(null));
}

stock float GetClientDistanceToGround(int client){
    if(GetEntityFlags(client) & FL_ONGROUND || GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") == 0) {
         return 0.0;
    }
    
    float fOrigin[3], fGround[3];
    GetClientAbsOrigin(client, fOrigin);
    
    fOrigin[2] += 10.0;
    
    TR_TraceRayFilter(fOrigin, Float:{90.0,0.0,0.0}, MASK_PLAYERSOLID, RayType_Infinite, TraceRayNoPlayers, client);
    if (TR_DidHit()){
        TR_GetEndPosition(fGround);
        fOrigin[2] -= 10.0;
        return GetVectorDistance(fOrigin, fGround);
    }
    return 0.0;
}

stock bool TraceRayNoPlayers(int entity, int mask, any data){
	// Ignore ourselves and TEAMMATES so gstrafing through your own team keeps
	// the boost, but enemies still block, so you can't gstrafe through them.
	// (Matches the original build's TraceRayTeammates filter.)
	if(entity == data) {
		return false;
	}

	if(0 < entity && entity <= MaxClients) {
		if(IsClientInGame(entity) && IsClientInGame(data) && GetClientTeam(entity) == GetClientTeam(data)) {
			return false; // teammate, ignore
		}
		return !FJActive(); // enemy blocks, except during FJ where nobody collides
	}

	return true; // world and other entities block as normal
}

stock bool IsValidClient(int client) {
	return (client >= 1 && client <= MaxClients && IsClientConnected(client) && !IsFakeClient(client) && IsValidEntity(client) && IsClientInGame(client));
}
