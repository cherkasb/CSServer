//**********************************************
//* VkGroup vk.com/paxanzm                     *
//**********************************************

#include <amxmodx>
#include <fakemeta_util>
#include <hamsandwich>
#include <zombieplague>

#define PLUGIN 					"[ZP] Addons: LandMines"
#define VERSION 				"1.0"
#define AUTHOR 					"PaXaN-ZOMBIE"

#pragma ctrlchar 				'\'
#pragma compress 				1

#define MINE_RADIUS_EXPLODE			150.0
#define MINE_DAMAGE_EXPLODE			random_float(800.0, 1000.0)

#define MODEL_MINE				"models/PaXaN/landmine_pack.mdl"

#define MODEL_EXPLODE				"sprites/PaXaN/MineExplode.spr"

#define SOUND_EXPLODE				"weapons/MineExplode.wav"
#define SOUND_ACTIVE				"weapons/MineActive.wav"

#define MINE_CLASSNAME				"GroundMiNe"

#define SET_SIZE(%0,%1,%2)			engfunc(EngFunc_SetSize, %0, %1, %2)

#define MDLL_Spawn(%0)				dllfunc(DLLFunc_Spawn, %0)
#define MDLL_Touch(%0,%1)			dllfunc(DLLFunc_Touch, %0, %1)
#define MDLL_USE(%0,%1)				dllfunc(DLLFunc_Use, %0, %1)

#define SET_MODEL(%0,%1)			engfunc(EngFunc_SetModel, %0, %1)
#define SET_ORIGIN(%0,%1)			engfunc(EngFunc_SetOrigin, %0, %1)

new iBlood[3];

new g_itemid_landmine;

public plugin_init() 
{
	register_logevent("EndRound", 		2, 				"1=Round_End");
	
	register_clcmd("CreateMine",						"Spawn");
	
	RegisterHam(Ham_Think, 			"info_target",			"HamHook_Think", false);
	RegisterHam(Ham_Touch, 			"info_target",			"HamHook_Touch", false);
	
	g_itemid_landmine = zp_register_extra_item("Landmine", 2500, ZP_TEAM_HUMAN)
}

public plugin_precache()
{
	engfunc(EngFunc_PrecacheModel, MODEL_MINE);
	engfunc(EngFunc_PrecacheSound, SOUND_EXPLODE);
	engfunc(EngFunc_PrecacheSound, SOUND_ACTIVE);
	
	iBlood[0] =  engfunc(EngFunc_PrecacheModel, "sprites/bloodspray.spr");
	iBlood[1] =  engfunc(EngFunc_PrecacheModel, "sprites/blood.spr");
	iBlood[2] =  engfunc(EngFunc_PrecacheModel, MODEL_EXPLODE);
}

public zp_extra_item_selected(player, itemid)
{
	if (itemid == g_itemid_landmine)
	{
		Spawn(player)
	}
}

public Spawn(iPlayer)
{
	if (zp_get_user_zombie(iPlayer) || !is_user_alive(iPlayer))
	{
		client_print(iPlayer, print_chat, "You can not set mine !");
		return;
	}
	
	new Float:vecSrc[3];pev(iPlayer, pev_origin, vecSrc);

	static iszAllocStringCached;
	static pEntity;

	if (iszAllocStringCached || (iszAllocStringCached = engfunc(EngFunc_AllocString, "info_target")))
	{
		pEntity = engfunc(EngFunc_CreateNamedEntity, iszAllocStringCached);
	}
		
	if (pev_valid(pEntity))
	{
		set_pev(pEntity, pev_movetype, MOVETYPE_TOSS);
		set_pev(pEntity, pev_owner, iPlayer);
			
		SET_MODEL(pEntity, MODEL_MINE);
		SET_ORIGIN(pEntity, vecSrc);
		//SET_SIZE(pEntity, {-5.0, -5.0, -5.0 }, { 5.0, 5.0, 5.0})
	
		set_pev(pEntity, pev_classname, MINE_CLASSNAME);
		set_pev(pEntity, pev_solid, SOLID_TRIGGER);
		set_pev(pEntity, pev_gravity, 0.01);
		
		set_pev(pEntity, pev_body, 2);
		set_pev(pEntity, pev_sequence, random_num(0,1));
		set_pev(pEntity, pev_framerate, 1.0);
		set_pev(pEntity, pev_animtime, get_gametime());
		set_pev(pEntity, pev_skin, random_num(0,9));

		set_pev(pEntity, pev_nextthink, get_gametime() + 0.3);
		
		engfunc(EngFunc_EmitSound, pEntity, CHAN_AUTO, SOUND_ACTIVE, 1.0, ATTN_NORM, 0, PITCH_NORM);
	
		engfunc(EngFunc_DropToFloor, pEntity);
	}
	
	return;
}

public EndRound()
{
	new iEntity = -1;
	while ((iEntity = fm_find_ent_by_class(iEntity,  MINE_CLASSNAME)))
	{
		set_pev(iEntity, pev_flags, pev(iEntity, pev_flags) | FL_KILLME);
	}
}

public HamHook_Think(const iEntity)
{
	if(!pev_valid(iEntity))
	{
		return HAM_IGNORED;
	}
	
	static Classname[32];pev(iEntity, pev_classname, Classname, sizeof(Classname));
	
	static iAttacker;iAttacker=pev(iEntity, pev_owner);
	
	static Float:OriginEnt[3];pev(iEntity, pev_origin, OriginEnt);
	
	static Float:iTime;pev(iEntity, pev_fuser1, iTime);
	
	if (equal(Classname, MINE_CLASSNAME))
	{
		if (iTime  && iTime <= get_gametime() || !is_user_connected(iAttacker) || zp_get_user_zombie(iAttacker))
		{
			CreateExplosion(OriginEnt, 0.0, iBlood[2], 3, 15, TE_EXPLFLAG_NOSOUND|TE_EXPLFLAG_NODLIGHTS|TE_EXPLFLAG_NOPARTICLES)
			
			engfunc(EngFunc_EmitSound, iEntity, CHAN_AUTO, SOUND_EXPLODE, 1.0, ATTN_NORM, 0, PITCH_NORM);
			
			static iVictim;iVictim = FM_NULLENT;

			while(((iVictim = fm_find_ent_in_sphere(iVictim, OriginEnt, MINE_RADIUS_EXPLODE)) != 0))
			{
				if (iVictim == iAttacker)
				{
					continue;
				}
				
				if(is_user_connected(iVictim) && is_user_alive(iVictim) && zp_get_user_zombie(iVictim))
				{
					new Float:vOrigin[3];pev(iVictim, pev_origin, vOrigin);Create_Blood(vOrigin, iBlood[0], iBlood[1], 76, 13); 
					set_pev(iVictim, pev_velocity, {0.0,0.0,-100.0});
					ExecuteHamB(Ham_TakeDamage, iVictim, iAttacker, iAttacker, MINE_DAMAGE_EXPLODE, DMG_BULLET);
				}
			}
			
			set_pev(iEntity, pev_iuser1, 0);
			
			set_pev(iEntity, pev_flags, pev(iEntity, pev_flags) | FL_KILLME);
			
			return HAM_SUPERCEDE;
		}
	}
	
	set_pev(iEntity, pev_nextthink, get_gametime() + 0.1);
	
	return HAM_IGNORED;
}

public HamHook_Touch(const iEntity, const iOther)
{
	if(!pev_valid(iEntity))
	{
		return HAM_IGNORED;
	}
	
	static Classname[32];pev(iEntity, pev_classname, Classname, sizeof(Classname));
	static iAttacker;iAttacker=pev(iEntity, pev_owner);
	
	if (equal(Classname, MINE_CLASSNAME))
	{
		if (is_user_alive(iOther) && zp_get_user_zombie(iOther))
		{
			if (iOther == iAttacker || pev(iEntity, pev_iuser1))
			{
				return HAM_IGNORED;
			}
			
			static Float:iVelocity[3];iVelocity[1] = random_float(220.0, -220.0);
			iVelocity[2] =160.0;
			set_pev(iEntity, pev_velocity, iVelocity);
			
			set_pev(iEntity, pev_fuser1, get_gametime() + 0.3);
			set_pev(iEntity, pev_iuser1, 1);
		}
	}
	
	return HAM_IGNORED;
}

stock CreateExplosion(const Float:Origin[3], const Float:CordZ = 0.0, const iModel, const iScale, const iFramerate, const iFlag)
{
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY); 
	write_byte(TE_EXPLOSION); 
	engfunc(EngFunc_WriteCoord, Origin[0]); 
	engfunc(EngFunc_WriteCoord, Origin[1]); 
	engfunc(EngFunc_WriteCoord, Origin[2]  + CordZ); 
	write_short(iModel);
	write_byte(iScale); 
	write_byte(iFramerate); 
	write_byte(iFlag); 
	message_end();
}

stock Create_Blood(const Float:vStart[3], const iModel, const iModel2, const iColor, const iScale)
{
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY, {0.0,0.0,0.0}, 0);
	write_byte(TE_BLOODSPRITE);
	engfunc(EngFunc_WriteCoord, vStart[0])
	engfunc(EngFunc_WriteCoord, vStart[1])
	engfunc(EngFunc_WriteCoord, vStart[2])
	write_short(iModel);
	write_short(iModel2);
	write_byte(iColor);
	write_byte(iScale);
	message_end();
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1049\\ f0\\ fs16 \n\\ par }
*/
