/*
	Shidla [SGC] | 2013 год
	ICQ: 312-298-513

	2.8.2 [Final Version] | 21.05.2013
*/

#include <amxmodx>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <xs>
#include <zombieplague>

#if AMXX_VERSION_NUM < 180
	#assert AMX Mod X v1.8.0 or greater library required!
#endif

#define PLUGIN "[ZP] LaserMine"
#define VERSION "2.8.2"
#define AUTHOR "SandStriker / Shidla / QuZ / DJ_WEST"

#define RemoveEntity(%1)	engfunc(EngFunc_RemoveEntity,%1)
#define TASK_PLANT			15100
#define TASK_RESET			15500
#define TASK_RELEASE		15900

#define LASERMINE_TEAM		pev_iuser1 //EV_INT_iuser1
#define LASERMINE_OWNER		pev_iuser2 //EV_INT_iuser3
#define LASERMINE_STEP		pev_iuser3
#define LASERMINE_HITING	pev_iuser4
#define LASERMINE_COUNT		pev_fuser1

#define LASERMINE_POWERUP	pev_fuser2
#define LASERMINE_BEAMTHINK	pev_fuser3

#define LASERMINE_CHANGECOLOR pev_fuser4

#define LASERMINE_BEAMENDPOINT	pev_vuser1
#define MAX_MINES			10
#define MODE_LASERMINE		0
#define OFFSET_TEAM			114
#define OFFSET_MONEY		115
#define OFFSET_DEATH		444

#define cs_get_user_team(%1)	CsTeams:get_offset_value(%1,OFFSET_TEAM)
#define cs_get_user_deaths(%1)	get_offset_value(%1,OFFSET_DEATH)
#define is_valid_player(%1)	(1 <= %1 <= 32)

#define STUCKTASK 11530
#define STUCKTASKSTOP 12530


/*########### Цвета Мин и лазерных лучей ###########*/

// дефолтный цвет мины и лазера людей
new const
	Red_HumD	= 0,
	Green_HumD 	= 0,
	Blue_HumD	= 255;
	
// Дефолтный цвет мины людей при атаке
new const
	Red_A	= 255,
	Green_A = 0,
	Blue_A	= 0;

// Цвет мины и лазера зомби
new const
	Red_Zomb	= 0,
	Green_Zomb 	= 255,
	Blue_Zomb	= 0;
/*####### Цвета Мин и лазерных лучей (конец) #######*/

new Float:g_vTraceHitPoints[33][3];
new Float:g_vTraceHitNormal[33][3];
new g_deploying_lasermines[33];
new bool:g_removing_mine[33] = { false, ... }

enum CsTeams {
CS_TEAM_UNASSIGNED = 0,
CS_TEAM_T = 1,
CS_TEAM_CT = 2,
CS_TEAM_SPECTATOR = 3
};

enum tripmine_e {
	TRIPMINE_IDLE1 = 0,
	TRIPMINE_IDLE2,
	TRIPMINE_ARM1,
	TRIPMINE_ARM2,
	TRIPMINE_FIDGET,
	TRIPMINE_HOLSTER,
	TRIPMINE_DRAW,
	TRIPMINE_WORLD,
	TRIPMINE_GROUND,
};

enum
{
	PLANT_THINK,
	POWERUP_THINK,
	BEAMBREAK_THINK,
	EXPLOSE_THINK
};

enum
{
	POWERUP_SOUND,
	ACTIVATE_SOUND,
	STOP_SOUND
};

new const
	ENT_MODELS[]	= "models/zombie_plague/LaserMines/v_laser_mine.mdl",
	ENT_GREEN_MODELS[] = "models/zombie_plague/LaserMines/v_laser_mine_green.mdl",
	ENT_RED_MODELS[] = "models/zombie_plague/LaserMines/v_laser_mine_red.mdl",
	ENT_SOUND1[]	= "weapons/mine_deploy.wav",
	ENT_SOUND2[]	= "weapons/mine_charge.wav",
	ENT_SOUND3[]	= "weapons/mine_activate.wav",
	ENT_SOUND4[]	= "items/suitchargeok1.wav",
	ENT_SOUND5[]	= "items/gunpickup2.wav",
	ENT_SOUND6[]	= "debris/bustglass1.wav",
	ENT_SOUND7[]	= "debris/bustglass2.wav",
	ENT_SPRITE1[]	= "sprites/laserbeam.spr",
	ENT_SPRITE2[]	= "sprites/lm_explode.spr";

new const
	ENT_CLASS_NAME[]	=	"lasermine",
	ENT_CLASS_NAME3[]	=	"func_breakable",
	gSnarkClassName[]	=	"wpn_snark",	// Для совместимости с плагином "Snark"
	barnacle_class[]	=	"barnacle",		// Для совместимости с плагином "Barnacle"
	weapon_box[]		=	"weaponbox";

new g_EntMine, beam, boom
new g_LENABLE, g_LDMG, g_LBEO, g_LHEALTH, g_LMODE, g_LRADIUS, g_NOROUND, g_NEMROUND, g_SURVROUND
new g_LRDMG,g_LFF,g_LCBT, g_LDELAY, g_LVISIBLE, g_LACCESS, g_LGLOW, g_LDMGMODE, g_LCLMODE
new g_LCBRIGHT, g_LDSEC, g_LCMDMODE, g_LBUYMODE, g_LME;
new g_dcount[33],g_nowtime,g_MaxPL
new bool:g_settinglaser[33]
new Float:plspeed[33], plsetting[33], g_havemine[33], g_deployed[33];

new cvar_setlaser_distance
new cvar_between_lasermine_distance

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	// Вызываем функцию Laser_TakeDamage при получении урона объектом ENT_CLASS_NAME3 (func_breakable)
	RegisterHam(Ham_TakeDamage, ENT_CLASS_NAME3, "Laser_TakeDamage")
	// Add your code here...
	register_clcmd("+setlaser","CreateLaserMine_Progress_b");
	register_clcmd("-setlaser","StopCreateLaserMine");
	register_clcmd("+dellaser","ReturnLaserMine_Progress");
	register_clcmd("-dellaser","StopReturnLaserMine");
	register_clcmd("say","say_lasermine");
	register_clcmd("buy_lasermine","BuyLasermineChat");

	g_LENABLE	= register_cvar("zp_ltm","1")
	g_LACCESS	= register_cvar("zp_ltm_acs","0") //0 all, 1 admin
	g_LMODE		= register_cvar("zp_ltm_mode","0") //0 lasermine, 1 tripmine
	g_LDMG		= register_cvar("zp_ltm_dmg","250") //laser hit dmg
	g_LHEALTH	= register_cvar("zp_ltm_health","10")
	g_LRADIUS	= register_cvar("zp_ltm_radius","25.0")
	g_LRDMG		= register_cvar("zp_ltm_rdmg","300") //radius damage
	g_LFF		= register_cvar("zp_ltm_ff","0")
	g_LCBT		= register_cvar("zp_ltm_cbt","ALL")
	g_LDELAY	= register_cvar("zp_ltm_delay","0.1")
	g_LVISIBLE	= register_cvar("zp_ltm_line","1")
	g_LGLOW		= register_cvar("zp_ltm_glow","1")
	g_LCBRIGHT	= register_cvar("zp_ltm_bright","255")//laser line brightness.
	g_LCLMODE	= register_cvar("zp_ltm_color","0") //0 is team color,1 is green
	g_LDMGMODE	= register_cvar("zp_ltm_ldmgmode","2") //0 - frame dmg, 1 - once dmg, 2 - 1 second dmg
	g_LDSEC		= register_cvar("zp_ltm_ldmgseconds","3") //mode 2 only, damage / seconds. default 1 (sec)s
	g_LBUYMODE	= register_cvar("zp_ltm_buymode","1");
	g_LCMDMODE	= register_cvar("zp_ltm_cmdmode","1");		//0 is +USE key, 1 is bind, 2 is each.
	g_LBEO		= register_cvar("zp_ltm_brokeenemy","1");
	g_NOROUND	= register_cvar("zp_ltm_noround","1");
	g_NEMROUND	= register_cvar("zp_ltm_nemround","1");
	g_SURVROUND	= register_cvar("zp_ltm_survround","1");
	cvar_setlaser_distance = register_cvar("zp_setlaser_distance", "80");
	cvar_between_lasermine_distance = register_cvar("zp_between_lasermine_distance", "12.0");

	register_event("DeathMsg", "DeathEvent", "a");
	register_event("CurWeapon", "standing", "be", "1=1");
	register_event("ResetHUD", "delaycount", "a");
	register_event("ResetHUD", "newround", "b");
	register_logevent("endround", 2, "0=World triggered", "1=Round_End");	// Регистрируем конец раунда
	register_event("Damage","CutDeploy_onDamage","b");

	// Forward.
	register_forward(FM_Think, "ltm_Think");
	register_forward(FM_PlayerPostThink, "ltm_PostThink");

	// Регистируем файл языков
	register_dictionary("LaserMines.txt")
	register_cvar("Shidla", "[ZP] LaserMines v.2.8.1 Final", FCVAR_SERVER|FCVAR_SPONLY)

	// Регистрируем ExtraItem
	g_LME = zp_register_extra_item("Laser Mine", 2000, ZP_TEAM_HUMAN)
}

public plugin_precache() 
{
	precache_sound(ENT_SOUND1);
	precache_sound(ENT_SOUND2);
	precache_sound(ENT_SOUND3);
	precache_sound(ENT_SOUND4);
	precache_sound(ENT_SOUND5);
	precache_sound(ENT_SOUND6);
	precache_sound(ENT_SOUND7);
	precache_model(ENT_MODELS);
	precache_model(ENT_GREEN_MODELS);
	precache_model(ENT_RED_MODELS);
	beam = precache_model(ENT_SPRITE1);
	boom = precache_model(ENT_SPRITE2);
	return PLUGIN_CONTINUE;
}

public plugin_modules() 
{
	require_module("fakemeta");
	require_module("cstrike");
}

public plugin_cfg()
{
	g_EntMine = engfunc(EngFunc_AllocString,ENT_CLASS_NAME3);
	arrayset(g_havemine,0,sizeof(g_havemine));
	arrayset(g_deployed,0,sizeof(g_deployed));
	g_MaxPL = get_maxplayers();

	new file[64]; get_localinfo("amxx_configsdir",file,63);
	format(file, 63, "%s/zp_ltm_cvars_ap.cfg", file);
	if(file_exists(file))
		server_cmd("exec %s", file), server_exec();
}

public Laser_TakeDamage(victim, inflictor, attacker, Float:f_Damage, bit_Damage)
{
	if(get_pcvar_num(g_LBEO))
	{
		new i_Owner

		// Получаем ID игрока, который поставил мину
		i_Owner = pev(victim, LASERMINE_OWNER)

		// Если урон нанасит владелец, а так же проверка игрока.
		if(i_Owner == attacker || !is_valid_player(i_Owner) || !is_valid_player(attacker))
			return PLUGIN_CONTINUE

		// Если мина установлена человеком, то урон ей наносят только зомби
		if((CsTeams:pev(victim, LASERMINE_TEAM) == CS_TEAM_CT) && (cs_get_user_team(attacker) != CS_TEAM_CT))
			return PLUGIN_CONTINUE

		// Если мина установлена зомби, а владелец мины и атакующий в разных командах - урон мине могун наносить все
		if((CsTeams:pev(victim, LASERMINE_TEAM) == CS_TEAM_T) && ((cs_get_user_team(i_Owner) != CS_TEAM_T) || (CsTeams:pev(victim, LASERMINE_TEAM) != cs_get_user_team(attacker))))
			return PLUGIN_CONTINUE

		return HAM_SUPERCEDE
	}
	return PLUGIN_CONTINUE
}

public delaycount(id)
{
	g_dcount[id] = floatround(get_gametime());
}

bool:CheckTime(id)
{
	g_nowtime = floatround(get_gametime()) - g_dcount[id];
	if(g_nowtime >= get_pcvar_num(g_LDELAY))
		return true;
	return false;
}

public CreateLaserMine_Progress_b(id)
{
	if(get_pcvar_num(g_LCMDMODE) != 0)
		CreateLaserMine_Progress(id);
	return PLUGIN_HANDLED;
}

public CreateLaserMine_Progress(id)
{

	if(!CreateCheck(id))
		return PLUGIN_HANDLED;
	g_settinglaser[id] = true;

	message_begin(MSG_ONE, 108, {0,0,0}, id);
	write_byte(1);
	write_byte(0);
	message_end();
	
	TempMineSpawn(id)

	set_task(1.2, "Spawn", (TASK_PLANT + id));

	return PLUGIN_HANDLED;
}

public ReturnLaserMine_Progress(id)
{

	if(!ReturnCheck(id))
		return PLUGIN_HANDLED;
	g_settinglaser[id] = true;
	g_removing_mine[id] = true;

	message_begin(MSG_ONE, 108, {0,0,0}, id);
	write_byte(1);
	write_byte(0);
	message_end();

	set_task(1.2, "ReturnMine", (TASK_RELEASE + id));

	return PLUGIN_HANDLED;
}

public StopCreateLaserMine(id)
{
	DeleteTask(id);
	if (pev_valid(g_deploying_lasermines[id]))
		set_pev(g_deploying_lasermines[id], pev_flags, FL_KILLME);
	message_begin(MSG_ONE, 108, {0,0,0}, id);
	write_byte(0);
	write_byte(0);
	message_end();

	return PLUGIN_HANDLED;
}

public StopReturnLaserMine(id)
{
	g_removing_mine[id] = false;
	DeleteTask(id);
	message_begin(MSG_ONE, 108, {0,0,0}, id);
	write_byte(0);
	write_byte(0);
	message_end();

	return PLUGIN_HANDLED;
}

public ReturnMine(id)
{
	id -= TASK_RELEASE;
	new tgt,body,Float:vo[3],Float:to[3];
	get_user_aiming(id,tgt,body);
	if(!pev_valid(tgt)) return;
	pev(id,pev_origin,vo);
	pev(tgt,pev_origin,to);
	if(get_distance_f(vo,to) > 90.0)
		return;
	new EntityName[32];
	pev(tgt, pev_classname, EntityName, 31);
	if(!equal(EntityName, ENT_CLASS_NAME))
		return;
	if(pev(tgt,LASERMINE_OWNER) != id)
		return;
	RemoveEntity(tgt);

	g_havemine[id] ++;
	g_deployed[id] --;
	emit_sound(id, CHAN_ITEM, ENT_SOUND5, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	StopReturnLaserMine(id)

	return;
}

public bool:TempMineMove(id)
{
	if (!g_settinglaser[id] || g_removing_mine[id])
		return false;
	if(!g_deploying_lasermines[id] || !g_deploying_lasermines[id])
	{
		client_print(id, print_chat,"[Lasermine Debug] Can't move mine");
		return false;
	}
	
	if (!TraceCheck(id))
		return false;
	
	new	Float:vNewOrigin[3];
	new Float:vNormal[3];
	new Float:vEntAngles[3]
	// -- We hit something!

	xs_vec_mul_scalar(g_vTraceHitNormal[id], 8.0, vNormal);
	xs_vec_add(g_vTraceHitPoints[id], vNormal, vNewOrigin);

	engfunc(EngFunc_SetSize, g_deploying_lasermines[id], Float:{ -4.0, -4.0, -4.0 }, Float:{ 4.0, 4.0, 4.0 });
	engfunc(EngFunc_SetOrigin, g_deploying_lasermines[id], vNewOrigin);

	// -- Rotate tripmine.
	vector_to_angle(vNormal,vEntAngles);
	set_pev(g_deploying_lasermines[id],pev_angles,vEntAngles);
	
	if (CollisionCheck(g_deploying_lasermines[id], g_vTraceHitPoints[id], get_pcvar_float(cvar_between_lasermine_distance), false))
	{
		engfunc(EngFunc_SetModel,g_deploying_lasermines[id],ENT_GREEN_MODELS);
	}
	else
	{
		engfunc(EngFunc_SetModel,g_deploying_lasermines[id],ENT_RED_MODELS);
	}
	
	return true
}

public TempMineSpawn(id)
{
	if (!g_settinglaser[id])
		return PLUGIN_HANDLED;
	g_deploying_lasermines[id] = engfunc(EngFunc_CreateNamedEntity,g_EntMine);
	if(!g_deploying_lasermines[id])
	{
		client_print(id, print_chat,"[Lasermine Debug] Can't Create Entity");
		return PLUGIN_HANDLED_MAIN;
	}
	set_pev(g_deploying_lasermines[id],pev_classname,ENT_CLASS_NAME);

	engfunc(EngFunc_SetModel,g_deploying_lasermines[id],ENT_MODELS);

	set_pev(g_deploying_lasermines[id],pev_solid,SOLID_NOT);
	set_pev(g_deploying_lasermines[id],pev_movetype,MOVETYPE_FLY);

	set_pev(g_deploying_lasermines[id],pev_frame,0);
	set_pev(g_deploying_lasermines[id],pev_body,3);
	set_pev(g_deploying_lasermines[id],pev_sequence,TRIPMINE_WORLD);
	set_pev(g_deploying_lasermines[id],pev_framerate,0);
	set_pev(g_deploying_lasermines[id],pev_takedamage,DAMAGE_NO);
	
	set_pev(g_deploying_lasermines[id],LASERMINE_STEP,PLANT_THINK);
	set_pev(g_deploying_lasermines[id],LASERMINE_CHANGECOLOR, 0);
	
	return PLUGIN_HANDLED
}

public Spawn(id)
{
	id -= TASK_PLANT
	// motor
	if (!TraceCheck(id))
	{
		StopCreateLaserMine(id)
		return PLUGIN_HANDLED;
	}
	new i_Ent = g_deploying_lasermines[id];
	if(!i_Ent)
	{
		client_print(id, print_chat,"[Lasermine Debug] Can't Create Entity");
		return PLUGIN_HANDLED_MAIN;
	}
	
	if (!CollisionCheck(g_deploying_lasermines[id], g_vTraceHitPoints[id], get_pcvar_float(cvar_between_lasermine_distance), true))
	{
		StopCreateLaserMine(id)
		return PLUGIN_HANDLED;
	}
	g_deploying_lasermines[id] = 0;
	set_pev(i_Ent,pev_classname,ENT_CLASS_NAME);

	engfunc(EngFunc_SetModel,i_Ent,ENT_MODELS);

	set_pev(i_Ent,pev_solid,SOLID_NOT);
	set_pev(i_Ent,pev_movetype,MOVETYPE_FLY);

	set_pev(i_Ent,pev_frame,0);
	set_pev(i_Ent,pev_body,3);
	set_pev(i_Ent,pev_sequence,TRIPMINE_WORLD);
	set_pev(i_Ent,pev_framerate,0);
	set_pev(i_Ent,pev_takedamage,DAMAGE_YES);
	set_pev(i_Ent,pev_dmg,100.0);
	set_user_health(i_Ent,get_pcvar_num(g_LHEALTH));
	new	Float:vNewOrigin[3], Float:vNormal[3], Float:vEntAngles[3];

	xs_vec_mul_scalar(g_vTraceHitNormal[id], 8.0, vNormal);
	xs_vec_add(g_vTraceHitPoints[id], vNormal, vNewOrigin);

	engfunc(EngFunc_SetSize, i_Ent, Float:{ -4.0, -4.0, -4.0 }, Float:{ 4.0, 4.0, 4.0 });
	engfunc(EngFunc_SetOrigin, i_Ent, vNewOrigin);

	// -- Rotate tripmine.
	vector_to_angle(vNormal,vEntAngles);
	set_pev(i_Ent,pev_angles,vEntAngles);

	// -- Calculate laser end origin.
	new Float:vBeamEnd[3], Float:vTracedBeamEnd[3];
		 
	xs_vec_mul_scalar(vNormal, 8192.0, vNormal);
	xs_vec_add(vNewOrigin, vNormal, vBeamEnd);

	engfunc(EngFunc_TraceLine, vNewOrigin, vBeamEnd, IGNORE_MONSTERS, -1, 0);

	get_tr2(0, TR_vecPlaneNormal, vNormal);
	get_tr2(0, TR_vecEndPos, vTracedBeamEnd);

	// -- Save results to be used later.
	set_pev(i_Ent, LASERMINE_OWNER, id);
	set_pev(i_Ent,LASERMINE_BEAMENDPOINT,vTracedBeamEnd);
	set_pev(i_Ent,LASERMINE_TEAM,int:cs_get_user_team(id));
	new Float:fCurrTime = get_gametime();

	set_pev(i_Ent,LASERMINE_POWERUP, fCurrTime + 2.5);
	set_pev(i_Ent,LASERMINE_STEP,POWERUP_THINK);
	set_pev(i_Ent,pev_nextthink, fCurrTime + 0.2);

	PlaySound(i_Ent,POWERUP_SOUND);
	g_deployed[id]++;
	g_havemine[id]--;
	DeleteTask(id);
	
	set_pev(i_Ent,LASERMINE_COUNT,get_gametime())
	return 1;
}

stock TeamDeployedCount(id)
{
	static i;
	static CsTeams:t;t = cs_get_user_team(id);
	static cnt;cnt=0;

	for(i = 1;i <= g_MaxPL;i++)
	{
		if(is_user_connected(i))
			if(t == cs_get_user_team(i))
				cnt += g_deployed[i];
	}

	return cnt;
}

bool:CheckCanTeam(id)
{
	new arg[5],CsTeam:num;
	get_pcvar_string(g_LCBT,arg,3);
	if(equali(arg,"Z"))
	{
		num = CsTeam:CS_TEAM_T;
	}
	else if(equali(arg,"H"))
	{
		num = CsTeam:CS_TEAM_CT;
	}
	else if(equali(arg,"ALL") || equali(arg,"HZ") || equali(arg,"ZH"))
	{
		num = CsTeam:CS_TEAM_UNASSIGNED;
	}
	else
	{
		num = CsTeam:CS_TEAM_UNASSIGNED;
	}
	if(num != CsTeam:CS_TEAM_UNASSIGNED && num != CsTeam:cs_get_user_team(id))
		return false;
	return true;
}

bool:CanCheck(id,mode)	// Проверки: когда можно ставить мины
{
	if(!get_pcvar_num(g_LENABLE))
	{
		client_print(id, print_chat, "%L %L", id, "CHATTAG",id, "STR_NOTACTIVE")

		return false;
	}
	if(get_pcvar_num(g_LACCESS) != 0)
	{
		if(!(get_user_flags(id) & ADMIN_IMMUNITY))
		{
			client_print(id, print_chat, "%L %L", id, "CHATTAG",id, "STR_NOACCESS")
			return false;
		}
	}
	if(!pev_user_alive(id))
		return false;
	if(!CheckCanTeam(id))
	{
		client_print(id, print_chat, "%L %L", id, "CHATTAG",id, "STR_CBT")
		return false;
	}
	if(!zp_has_round_started() && get_pcvar_num(g_NOROUND))
	{
		client_print(id, print_chat, "%L %L", id, "CHATTAG",id, "STR_NOROUND")
		return false;
	}
	if(mode == 0)
	{
		if(g_havemine[id] <= 0)
		{
			client_print(id, print_chat, "%L %L", id, "CHATTAG",id, "STR_DONTHAVEMINE")
			return false;
		}
	}
	else if(mode == 1)
	{
		if(get_pcvar_num(g_LBUYMODE) == 0)
		{
			client_print(id, print_chat, "%L %L", id, "CHATTAG",id, "STR_CANTBUY")
			return false;
		}
	}
	if(!CheckTime(id))
	{
		client_print(id, print_chat, "%L %L %d %L", id, "CHATTAG",id, "STR_DELAY",get_pcvar_num(g_LDELAY)-g_nowtime,id, "STR_SECONDS")
		return false;
	}

	return true;
}

bool:CanCheckNoOutput(id, mode)
{
	if(!get_pcvar_num(g_LENABLE))
	{
		return false;
	}
	if(get_pcvar_num(g_LACCESS) != 0)
	{
		if(!(get_user_flags(id) & ADMIN_IMMUNITY))
		{
			return false;
		}
	}
	if(!pev_user_alive(id))
		return false;
	if(!CheckCanTeam(id))
	{
		return false;
	}
	if(!zp_has_round_started() && get_pcvar_num(g_NOROUND))
	{
		return false;
	}
	if(mode == 0)
	{
		if(g_havemine[id] <= 0)
		{
			return false;
		}
	}
	else if(mode == 1)
	{
		if(get_pcvar_num(g_LBUYMODE) == 0)
		{
			return false;
		}
	}
	if(!CheckTime(id))
	{
		return false;
	}

	return true;
}

bool:ReturnCheck(id)
{
	if(!CanCheck(id,-1))
		return false;

	new tgt,body,Float:vo[3],Float:to[3];
	get_user_aiming(id,tgt,body);
	if(!pev_valid(tgt))
		return false;
	pev(id,pev_origin,vo);
	pev(tgt,pev_origin,to);
	if(get_distance_f(vo,to) > 70.0)
		return false;
	new EntityName[32];
	pev(tgt, pev_classname, EntityName, 31);
	if(!equal(EntityName, ENT_CLASS_NAME))
		return false;
	if(pev(tgt,LASERMINE_OWNER) != id)
		return false;
	return true;
}

bool:CreateCheck(id)
{
	if(!CanCheck(id,0))
		return false;

	// Проверка на разрешение
	if(!zp_has_round_started() && get_pcvar_num(g_NOROUND))
	{
		client_print(id, print_chat, "%L %L", id, "CHATTAG",id, "STR_NOROUND")
		return false;
	}

	if(zp_is_nemesis_round() && get_pcvar_num(g_NEMROUND))
	{
		client_print(id, print_chat, "%L %L", id, "CHATTAG",id, "STR_NEMROUND")
		return false;
	}
	if(zp_is_survivor_round() && get_pcvar_num(g_SURVROUND))
	{
		client_print(id, print_chat, "%L %L", id, "CHATTAG",id, "STR_SURVROUND")
		return false;
	}
	if(zp_is_assassin_round() && get_pcvar_num(g_NEMROUND))
	{
		client_print(id, print_chat, "%L %L", id, "CHATTAG",id, "STR_ASSASSINROUND")
		return false;
	}
	if(zp_is_sniper_round() && get_pcvar_num(g_SURVROUND))
	{
		client_print(id, print_chat, "%L %L", id, "CHATTAG",id, "STR_SNIPERROUND")
		return false;
	}

	if (TraceCheck(id))
		return true;

	client_print(id, print_chat, "%L %L", id, "CHATTAG",id, "STR_PLANTWALL")
	DeleteTask(id);
	// -- Did not touched something. (not solid)
	return false;
}

public bool:TraceCheck(id)
{
	new Float:vTraceDirection[3], Float:vTraceEnd[3],Float:vOrigin[3];
	//Get player position
	pev(id, pev_origin, vOrigin);
	//Get lookup vector * cvar_setlaser_distance
	velocity_by_aim(id, get_pcvar_num(cvar_setlaser_distance), vTraceDirection);
	//Get point where mine should be playec
	xs_vec_add(vTraceDirection, vOrigin, vTraceEnd);
	//Trace to find if we can put laser
	engfunc(EngFunc_TraceLine, vOrigin, vTraceEnd, DONT_IGNORE_MONSTERS, id, 0);
	new Float:fFraction;
	//Get hit result
	get_tr2(0, TR_flFraction, fFraction);
	// -- We hit something!
	if(fFraction < 1.0)
	{
		// -- Save results to be used later.
		//Get hit point
		get_tr2(0, TR_vecEndPos, g_vTraceHitPoints[id]);
		//Get hitpoint normal
		get_tr2(0, TR_vecPlaneNormal, g_vTraceHitNormal[id]);

		return true;
	}
	return (false);
}

public bool:CollisionCheck(ent, Float:origin[3], Float:radius, bool:ignoreplantingmines)
{
	static iOther;
	iOther = FM_NULLENT;
	new EntityName[32]
	while(((iOther = fm_find_ent_in_sphere(iOther, origin, get_pcvar_float(cvar_between_lasermine_distance))) != 0))
	{
		if (!pev_valid(iOther) || iOther == ent)
		{
			continue;
		}
		pev(iOther, pev_classname, EntityName, 31);
		if (equal(EntityName, ENT_CLASS_NAME))
		{
			if (ignoreplantingmines)
			{
				if (pev(iOther,LASERMINE_STEP) != PLANT_THINK)
					return (false);
				else
					return (true);
			}
			else
				return (false);
		}
		
		if(is_user_connected(iOther) && is_user_alive(iOther) && zp_get_user_zombie(iOther))
		{
			return (false);
		}
	}
	return (true);
}

public bool:ChecForStuck(ent, Float:origin[3], Float:radius)
{
	static iOther;
	iOther = FM_NULLENT;
	while(((iOther = fm_find_ent_in_sphere(iOther, origin, get_pcvar_float(cvar_between_lasermine_distance))) != 0))
	{
		if (!pev_valid(iOther) || iOther == ent)
		{
			continue;
		}
		
		if( is_user_connected(iOther) && is_user_alive(iOther))
		{
			if (task_exists(iOther + STUCKTASK))
				remove_task(iOther + STUCKTASK)
			if (task_exists(iOther + STUCKTASKSTOP))
				remove_task(iOther + STUCKTASKSTOP)
			set_task(0.2,"checkstuck",STUCKTASK + iOther,"",0,"b")
			set_task(1.0,"stopcheckstuck",STUCKTASKSTOP + iOther)
		}
	}
	return (true);
}

/*
**
*/

new stuck[33]

new const Float:size[][3] = {
	{0.0, 0.0, 1.0}, {0.0, 0.0, -1.0}, {0.0, 1.0, 0.0}, {0.0, -1.0, 0.0}, {1.0, 0.0, 0.0}, {-1.0, 0.0, 0.0}, {-1.0, 1.0, 1.0}, {1.0, 1.0, 1.0}, {1.0, -1.0, 1.0}, {1.0, 1.0, -1.0}, {-1.0, -1.0, 1.0}, {1.0, -1.0, -1.0}, {-1.0, 1.0, -1.0}, {-1.0, -1.0, -1.0},
	{0.0, 0.0, 2.0}, {0.0, 0.0, -2.0}, {0.0, 2.0, 0.0}, {0.0, -2.0, 0.0}, {2.0, 0.0, 0.0}, {-2.0, 0.0, 0.0}, {-2.0, 2.0, 2.0}, {2.0, 2.0, 2.0}, {2.0, -2.0, 2.0}, {2.0, 2.0, -2.0}, {-2.0, -2.0, 2.0}, {2.0, -2.0, -2.0}, {-2.0, 2.0, -2.0}, {-2.0, -2.0, -2.0},
	{0.0, 0.0, 3.0}, {0.0, 0.0, -3.0}, {0.0, 3.0, 0.0}, {0.0, -3.0, 0.0}, {3.0, 0.0, 0.0}, {-3.0, 0.0, 0.0}, {-3.0, 3.0, 3.0}, {3.0, 3.0, 3.0}, {3.0, -3.0, 3.0}, {3.0, 3.0, -3.0}, {-3.0, -3.0, 3.0}, {3.0, -3.0, -3.0}, {-3.0, 3.0, -3.0}, {-3.0, -3.0, -3.0},
	{0.0, 0.0, 4.0}, {0.0, 0.0, -4.0}, {0.0, 4.0, 0.0}, {0.0, -4.0, 0.0}, {4.0, 0.0, 0.0}, {-4.0, 0.0, 0.0}, {-4.0, 4.0, 4.0}, {4.0, 4.0, 4.0}, {4.0, -4.0, 4.0}, {4.0, 4.0, -4.0}, {-4.0, -4.0, 4.0}, {4.0, -4.0, -4.0}, {-4.0, 4.0, -4.0}, {-4.0, -4.0, -4.0},
	{0.0, 0.0, 5.0}, {0.0, 0.0, -5.0}, {0.0, 5.0, 0.0}, {0.0, -5.0, 0.0}, {5.0, 0.0, 0.0}, {-5.0, 0.0, 0.0}, {-5.0, 5.0, 5.0}, {5.0, 5.0, 5.0}, {5.0, -5.0, 5.0}, {5.0, 5.0, -5.0}, {-5.0, -5.0, 5.0}, {5.0, -5.0, -5.0}, {-5.0, 5.0, -5.0}, {-5.0, -5.0, -5.0}
}

public checkstuck(taskid)
{
	static Float:origin[3]
	static Float:mins[3], hull
	static Float:vec[3]
	static o,id

	id = taskid - STUCKTASK
	if (is_user_connected(id) && is_user_alive(id))
	{
		pev(id, pev_origin, origin)
		hull = pev(id, pev_flags) & FL_DUCKING ? HULL_HEAD : HULL_HUMAN
		if (!is_hull_vacant(origin, hull,id) && !(pev(id,pev_solid) & SOLID_NOT))
		{
			++stuck[id]
			if(stuck[id] >= 2)
			{
				pev(id, pev_mins, mins)
				vec[2] = origin[2]
				for (o=0; o < sizeof size; ++o)
				{
					vec[0] = origin[0] - mins[0] * size[o][0]
					vec[1] = origin[1] - mins[1] * size[o][1]
					vec[2] = origin[2] - mins[2] * size[o][2]
					if (is_hull_vacant(vec, hull,id))
					{
						engfunc(EngFunc_SetOrigin, id, vec)
						set_pev(id,pev_velocity,{0.0,0.0,0.0})
						o = sizeof size
					}
				}
			}
		}
		else
		{
			stuck[id] = 0
		}
	}
}

stock bool:is_hull_vacant(const Float:origin[3], hull,id) {
	static tr
	engfunc(EngFunc_TraceHull, origin, origin, 0, hull, id, tr)
	if (!get_tr2(tr, TR_StartSolid) || !get_tr2(tr, TR_AllSolid)) //get_tr2(tr, TR_InOpen))
		return true
	
	return false
}

public stopcheckstuck(taskid)
{
	static id;
	id = taskid - STUCKTASKSTOP
	DeleteTask(id)
}

/*
**
*/

public ltm_Think(i_Ent)
{
	if(!pev_valid(i_Ent))
		return FMRES_IGNORED;
	new EntityName[32];
	pev(i_Ent, pev_classname, EntityName, 31);
	if(!get_pcvar_num(g_LENABLE))
		return FMRES_IGNORED;
	// -- Entity is not a tripmine, ignoring the next...
	if(!equal(EntityName, ENT_CLASS_NAME))
		return FMRES_IGNORED;
	
	new owner = pev(i_Ent, LASERMINE_OWNER);
	if (zp_get_user_zombie(owner))
	{
		PlaySound(i_Ent, STOP_SOUND);
		RemoveEntity(i_Ent);
	}

	static Float:fCurrTime;
	fCurrTime = get_gametime();

	switch(pev(i_Ent, LASERMINE_STEP))
	{
		case POWERUP_THINK :
		{
			new Float:fPowerupTime;
			pev(i_Ent, LASERMINE_POWERUP, fPowerupTime);

			if(fCurrTime > fPowerupTime)
			{
				static Float:vOrigin[3];
				pev(i_Ent, pev_origin, vOrigin);
				set_pev(i_Ent, pev_solid, SOLID_BBOX);
				set_pev(i_Ent, LASERMINE_STEP, BEAMBREAK_THINK);

				PlaySound(i_Ent, ACTIVATE_SOUND);
				
				ChecForStuck(i_Ent, vOrigin, get_pcvar_float(cvar_between_lasermine_distance))
			}
			if(get_pcvar_num(g_LGLOW)!=0)
			{
				if(get_pcvar_num(g_LCLMODE)==0)
				{
					switch (pev(i_Ent,LASERMINE_TEAM))
					{
						// цвет лазера Зомби
						case CS_TEAM_T: set_rendering(i_Ent,kRenderFxGlowShell,Red_Zomb,Green_Zomb,Blue_Zomb,kRenderNormal,5);
						// цвет лазера Человека
						case CS_TEAM_CT:set_rendering(i_Ent,kRenderFxGlowShell,Red_HumD,Green_HumD,Blue_HumD,kRenderNormal,5);
					}
				}
				else
				{
					// цвет лазера, если стоит "одинаковый для всех" цвет
					set_rendering(i_Ent,kRenderFxGlowShell,random_num(50 , 200),random_num(50 , 200),random_num(50 , 200),kRenderNormal,5);
				}
			}
			set_pev(i_Ent, pev_nextthink, fCurrTime + 0.1);
		}
		case BEAMBREAK_THINK :
		{
			static Float:vEnd[3],Float:vOrigin[3];
			pev(i_Ent, pev_origin, vOrigin);
			pev(i_Ent, LASERMINE_BEAMENDPOINT, vEnd);

			static iHit, Float:fFraction;
			engfunc(EngFunc_TraceLine, vOrigin, vEnd, DONT_IGNORE_MONSTERS, i_Ent, 0);

			get_tr2(0, TR_flFraction, fFraction);
			iHit = get_tr2(0, TR_pHit);

			// -- Something has passed the laser.
			if(fFraction < 1.0)
			{
				// -- Ignoring others tripmines entity.
				if(pev_valid(iHit))
				{
					pev(iHit, pev_classname, EntityName, 31);
					// Игнорим всякую хрень
					if(!equal(EntityName, ENT_CLASS_NAME) && !equal(EntityName, gSnarkClassName) && !equal(EntityName, barnacle_class) && !equal(EntityName, weapon_box))
					{
						set_pev(i_Ent, pev_enemy, iHit);

						if(get_pcvar_num(g_LMODE) == MODE_LASERMINE)
							CreateLaserDamage(i_Ent,iHit);
						else
							if(get_pcvar_num(g_LFF) || CsTeams:pev(i_Ent,LASERMINE_TEAM) != cs_get_user_team(iHit))
								set_pev(i_Ent, LASERMINE_STEP, EXPLOSE_THINK);

						if (!pev_valid(i_Ent))	// если не верный объект - ничего не делаем. Спасибо DJ_WEST
							return FMRES_IGNORED;

						set_pev(i_Ent, pev_nextthink, fCurrTime + random_float(0.1, 0.3));
					}
				}
			}
			if(get_pcvar_num(g_LDMGMODE)!=0)
			{
				if(pev(i_Ent,LASERMINE_HITING) != iHit)
					set_pev(i_Ent,LASERMINE_HITING,iHit);
			}
 
			// -- Tripmine is still there.
			if(pev_valid(i_Ent))
			{
				static Float:fHealth;
				pev(i_Ent, pev_health, fHealth);

				if(fHealth <= 0.0 || (pev(i_Ent,pev_flags) & FL_KILLME))
				{
					set_pev(i_Ent, LASERMINE_STEP, EXPLOSE_THINK);
					set_pev(i_Ent, pev_nextthink, fCurrTime + random_float(0.1, 0.3));
				}
										 
				static Float:fBeamthink;
				pev(i_Ent, LASERMINE_BEAMTHINK, fBeamthink);
						 
				if(fBeamthink < fCurrTime && get_pcvar_num(g_LVISIBLE))
				{
					DrawLaser(i_Ent, vOrigin, vEnd);
					set_pev(i_Ent, LASERMINE_BEAMTHINK, fCurrTime + 0.1);
				}
				set_pev(i_Ent, pev_nextthink, fCurrTime + 0.01);
			}
		}
		case EXPLOSE_THINK :
		{
			// -- Stopping entity to think
			set_pev(i_Ent, pev_nextthink, 0.0);
			PlaySound(i_Ent, STOP_SOUND);
			g_deployed[pev(i_Ent,LASERMINE_OWNER)]--;
			CreateExplosion(i_Ent);
			CreateDamage(i_Ent,get_pcvar_float(g_LRDMG),get_pcvar_float(g_LRADIUS))
			RemoveEntity	(i_Ent);
		}
	}

	return FMRES_IGNORED;
}

PlaySound(i_Ent, i_SoundType)
{
	switch (i_SoundType)
	{
		case POWERUP_SOUND :
		{
			emit_sound(i_Ent, CHAN_VOICE, ENT_SOUND1, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
			emit_sound(i_Ent, CHAN_BODY , ENT_SOUND2, 0.2, ATTN_NORM, 0, PITCH_NORM);
		}
		case ACTIVATE_SOUND :
		{
			emit_sound(i_Ent, CHAN_VOICE, ENT_SOUND3, 0.5, ATTN_NORM, 1, 75);
		}
		case STOP_SOUND :
		{
			emit_sound(i_Ent, CHAN_BODY , ENT_SOUND2, 0.2, ATTN_NORM, SND_STOP, PITCH_NORM);
			emit_sound(i_Ent, CHAN_VOICE, ENT_SOUND3, 0.5, ATTN_NORM, SND_STOP, 75);
		}
	}
}

DrawLaser(i_Ent, const Float:v_Origin[3], const Float:v_EndOrigin[3])
{
	new tcolor[3];
	new teamid = pev(i_Ent, LASERMINE_TEAM);
	if(get_pcvar_num(g_LCLMODE) == 0)
	{
		switch(teamid)
		{
			case 1:
			{
				// Цвет луча для Зомби
				tcolor[0] = Red_Zomb;
				tcolor[1] = Green_Zomb;
				tcolor[2] = Blue_Zomb;
			}
			case 2:
			{
				if (pev(i_Ent,LASERMINE_CHANGECOLOR) == 0)
				{
					// Цвет луча для Человека
					tcolor[0] = Red_HumD;
					tcolor[1] = Green_HumD;
					tcolor[2] = Blue_HumD;
				}
				else
				{
					tcolor[0] = Red_A;
					tcolor[1] = Green_A;
					tcolor[2] = Blue_A;
				}
			}
		}
	}
	else
	{
		// Цвет луча для всез при режиме 1-н луч для всех
		tcolor[0] = random_num(50 , 200);
		tcolor[1] = random_num(50 , 200);
		tcolor[2] = random_num(50 , 200);
	}
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY);
	write_byte(TE_BEAMPOINTS);
	engfunc(EngFunc_WriteCoord,v_Origin[0]);
	engfunc(EngFunc_WriteCoord,v_Origin[1]);
	engfunc(EngFunc_WriteCoord,v_Origin[2]);
	engfunc(EngFunc_WriteCoord,v_EndOrigin[0]); //Random
	engfunc(EngFunc_WriteCoord,v_EndOrigin[1]); //Random
	engfunc(EngFunc_WriteCoord,v_EndOrigin[2]); //Random
	write_short(beam);
	write_byte(0);
	write_byte(0);
	write_byte(1);	//Life
	write_byte(5);	//Width
	write_byte(0);	//wave
	write_byte(tcolor[0]); // r
	write_byte(tcolor[1]); // g
	write_byte(tcolor[2]); // b
	write_byte(get_pcvar_num(g_LCBRIGHT));
	write_byte(255);
	message_end();
}

CreateDamage(iCurrent,Float:DmgMAX,Float:Radius)
{
	// Get given parameters
	new Float:vecSrc[3];
	pev(iCurrent, pev_origin, vecSrc);
	
	new AtkID =pev(iCurrent,LASERMINE_OWNER);
	new TeamID=pev(iCurrent,LASERMINE_TEAM);

	new ent = -1;
	new Float:tmpdmg = DmgMAX;

	new Float:kickback = 0.0;
	// Needed for doing some nice calculations :P
	new Float:Tabsmin[3], Float:Tabsmax[3];
	new Float:vecSpot[3];
	new Float:Aabsmin[3], Float:Aabsmax[3];
	new Float:vecSee[3];
	new trRes;
	new Float:flFraction;
	new Float:vecEndPos[3];
	new Float:distance;
	new Float:origin[3], Float:vecPush[3];
	new Float:invlen;
	new Float:velocity[3];
	new iHitTeam;
	// Calculate falloff
	new Float:falloff;
	if(Radius > 0.0)
	{
		falloff = DmgMAX / Radius;
	}
	else
	{
		falloff = 1.0;
	}
	// Find monsters and players inside a specifiec radius
	while((ent = engfunc(EngFunc_FindEntityInSphere, ent, vecSrc, Radius)) != 0)
	{
		if(!pev_valid(ent))
			continue;
		if(!(pev(ent, pev_flags) & (FL_CLIENT | FL_FAKECLIENT | FL_MONSTER)))
		{
			// Entity is not a player or monster, ignore it
			continue;
		}
		if(!pev_user_alive(ent)) continue;
		// Reset data
		kickback = 1.0;
		tmpdmg = DmgMAX;
		// The following calculations are provided by Orangutanz, THANKS!
		// We use absmin and absmax for the most accurate information
		pev(ent, pev_absmin, Tabsmin);
		pev(ent, pev_absmax, Tabsmax);
		xs_vec_add(Tabsmin,Tabsmax,Tabsmin);
		xs_vec_mul_scalar(Tabsmin,0.5,vecSpot);
		pev(iCurrent, pev_absmin, Aabsmin);
		pev(iCurrent, pev_absmax, Aabsmax);
		xs_vec_add(Aabsmin,Aabsmax,Aabsmin);
		xs_vec_mul_scalar(Aabsmin,0.5,vecSee);
		engfunc(EngFunc_TraceLine, vecSee, vecSpot, 0, iCurrent, trRes);
		get_tr2(trRes, TR_flFraction, flFraction);
		// Explosion can 'see' this entity, so hurt them! (or impact through objects has been enabled xD)
		if(flFraction >= 0.9 || get_tr2(trRes, TR_pHit) == ent)
		{
			// Work out the distance between impact and entity
			get_tr2(trRes, TR_vecEndPos, vecEndPos);
			distance = get_distance_f(vecSrc, vecEndPos) * falloff;
			tmpdmg -= distance;
			if(tmpdmg < 0.0)
				tmpdmg = 0.0;
			// Kickback Effect
			if(kickback != 0.0)
			{
				xs_vec_sub(vecSpot,vecSee,origin);
				invlen = 1.0/get_distance_f(vecSpot, vecSee);

				xs_vec_mul_scalar(origin,invlen,vecPush);
				pev(ent, pev_velocity, velocity)
				xs_vec_mul_scalar(vecPush,tmpdmg,vecPush);
				xs_vec_mul_scalar(vecPush,kickback,vecPush);
				xs_vec_add(velocity,vecPush,velocity);
				if(tmpdmg < 60.0)
				{
					xs_vec_mul_scalar(velocity,12.0,velocity);
				}
				else
				{
					xs_vec_mul_scalar(velocity,4.0,velocity);
				}
				if(velocity[0] != 0.0 || velocity[1] != 0.0 || velocity[2] != 0.0)
				{
					// There's some movement todo :)
					set_pev(ent, pev_velocity, velocity)
				}
			}

			iHitTeam = int:cs_get_user_team(ent)
			if(iHitTeam != TeamID || get_pcvar_num(g_LFF))
			{
				ExecuteHamB(Ham_TakeDamage, ent, iCurrent, AtkID, tmpdmg, DMG_BLAST);
			}
		}
	}
	return
}

bool:pev_user_alive(ent)
{
	new deadflag = pev(ent,pev_deadflag);
	if(deadflag != DEAD_NO)
		return false;
	return true;
}

CreateExplosion(iCurrent)
{
	new Float:vOrigin[3];
	pev(iCurrent,pev_origin,vOrigin);

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(99); //99 = KillBeam
	write_short(iCurrent);
	message_end();

	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vOrigin, 0);
	write_byte(TE_EXPLOSION);
	engfunc(EngFunc_WriteCoord,vOrigin[0]);
	engfunc(EngFunc_WriteCoord,vOrigin[1]);
	engfunc(EngFunc_WriteCoord,vOrigin[2]);
	write_short(boom);
	write_byte(30);
	write_byte(15);
	write_byte(0);
	message_end();
}

CreateLaserDamage(iCurrent,isHit)
{
	if(isHit < 0)
		return PLUGIN_CONTINUE
	switch(get_pcvar_num(g_LDMGMODE))
	{
		case 1:
		{
			if(pev(iCurrent,LASERMINE_HITING) == isHit)
				return PLUGIN_CONTINUE
		}
		case 2:
		{
			if(pev(iCurrent,LASERMINE_HITING) == isHit)
			{
				static Float:cnt
				static Float:htime;

				pev(iCurrent,LASERMINE_COUNT,cnt)
				htime = get_gametime() - cnt;
				if(floatround(htime) < get_pcvar_num(g_LDSEC))
				{
					set_pev(iCurrent,LASERMINE_CHANGECOLOR, 1);
					return PLUGIN_CONTINUE;
				}
				else
				{
					set_pev(iCurrent,LASERMINE_COUNT,get_gametime())
					set_pev(iCurrent,LASERMINE_CHANGECOLOR, 0);
				}
			}
			else
			{
//				set_pev(iCurrent,LASERMINE_COUNT,get_gametime())
				return PLUGIN_CONTINUE;
			}
		}
	}

	new Float:vOrigin[3],Float:vEnd[3]
	pev(iCurrent,pev_origin,vOrigin)
	pev(iCurrent,pev_vuser1,vEnd)

	new teamid = pev(iCurrent, LASERMINE_TEAM)

	new szClassName[32]
	new Alive,God
	new iHitTeam, id

	static Float:dmg;
	dmg = float(get_pcvar_num(g_LDMG)); 
	szClassName[0] = '^0'
	pev(isHit,pev_classname,szClassName,32)
	if((pev(isHit, pev_flags) & (FL_CLIENT | FL_FAKECLIENT | FL_MONSTER)))
	{
		
		Alive = pev_user_alive(isHit)
		God = get_user_godmode(isHit)
		if(!Alive || God)
			return PLUGIN_CONTINUE
		iHitTeam = int:cs_get_user_team(isHit)
		if(iHitTeam != teamid || get_pcvar_num(g_LFF))
		{
			id = pev(iCurrent,LASERMINE_OWNER)//, szNetName[32]
			ExecuteHamB(Ham_TakeDamage, isHit, iCurrent, id, dmg, DMG_ENERGYBEAM);
			emit_sound(isHit, CHAN_WEAPON, ENT_SOUND4, 1.0, ATTN_NORM, 0, PITCH_NORM)
			if(pev_valid(iCurrent))
				set_pev(iCurrent,LASERMINE_HITING,isHit);
		}
	}
	else if(equal(szClassName, ENT_CLASS_NAME3))
	{
		id = pev(iCurrent,LASERMINE_OWNER)//, szNetName[32]
		ExecuteHamB(Ham_TakeDamage, isHit, iCurrent, id, dmg, DMG_ENERGYBEAM);
	}
	return PLUGIN_CONTINUE
}

stock pev_user_health(id)
{
	new Float:health
	pev(id,pev_health,health)
	return floatround(health)
}

stock set_user_health(id,health)
{
	health > 0 ? set_pev(id, pev_health, float(health)) : dllfunc(DLLFunc_ClientKill, id);
}

stock get_user_godmode(index) {
	new Float:val
	pev(index, pev_takedamage, val)

	return (val == DAMAGE_NO)
}

stock set_user_frags(index, frags)
{
	set_pev(index, pev_frags, float(frags))

	return 1
}

stock pev_user_frags(index)
{
	new Float:frags;
	pev(index,pev_frags,frags);
	return floatround(frags);
}

public BuyLasermine(id)
{
	if(!CanCheck(id,1))
		return PLUGIN_CONTINUE

	g_havemine[id]++;

	client_print(id, print_chat, "%L %L", id, "CHATTAG",id, "STR_BOUGHT")

	emit_sound(id, CHAN_ITEM, ENT_SOUND5, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	return PLUGIN_HANDLED
}

public BuyLasermineChat(id)
{
	if(!CanCheck(id,1))
		return;
	zp_force_buy_extra_item(id, g_LME, 0);
}

public zp_extra_item_selected(id, itemid)
{
	if(itemid == g_LME)
		BuyLasermine(id)

	return PLUGIN_CONTINUE
}

public zp_extraitem_available(id, itemid)
{
	if(!CanCheckNoOutput(id, 1))
	{
		zp_setextraitemavailable(id, g_LME, false)
		if (itemid == g_LME)
		{
			CanCheck(id, 1)
		}
		return PLUGIN_HANDLED
	}
	zp_setextraitemavailable(id, g_LME, true)
	return (PLUGIN_CONTINUE);
}

public showInfo(id)
{
	client_print(id, print_chat, "%L", id, "STR_REF")
}

public say_lasermine(id){
	new said[32]
	read_argv(1,said,31);
	if(!get_pcvar_num(g_LENABLE))
	{
		return PLUGIN_CONTINUE
	}
	if(equali(said,"/buy lasermine")||equali(said,"/lm")||equali(said,"buy_lasermine"))
	{
		BuyLasermineChat(id)
	}
	return PLUGIN_CONTINUE
}

public standing(id) 
{
	if(!g_settinglaser[id])
		return PLUGIN_CONTINUE

	set_pev(id, pev_maxspeed, 1.0)

	return PLUGIN_CONTINUE
}

public ltm_PostThink(id) 
{
	if(!g_settinglaser[id] && plsetting[id])
	{
		resetspeed(id)
	}
	else if(g_settinglaser[id] && !plsetting[id])
	{
		pev(id, pev_maxspeed,plspeed[id])
		set_pev(id, pev_maxspeed, 1.0)
	}
	plsetting[id] = g_settinglaser[id]
	if (plsetting[id])
	{
		if (!TempMineMove(id) && !g_removing_mine[id])
		{
			StopCreateLaserMine(id)
		}
	}
	return FMRES_IGNORED
}

resetspeed(id)
{
	set_pev(id, pev_maxspeed, plspeed[id])
}

public client_putinserver(id){
	g_deployed[id] = 0;
	g_havemine[id] = 0;
	DeleteTask(id);
	return PLUGIN_CONTINUE
}

public client_disconnect(id){
	if(!get_pcvar_num(g_LENABLE))
		return PLUGIN_CONTINUE
	DeleteTask(id);
	RemoveAllTripmines(id);
	return PLUGIN_CONTINUE
}


public newround(id){
	if(!get_pcvar_num(g_LENABLE))
		return PLUGIN_CONTINUE
	pev(id, pev_maxspeed,plspeed[id])
	DeleteTask(id);
	RemoveAllTripmines(id);
	//client_print(id, print_chat, "[ZP][LM][DeBug] All Mines removied!");
	delaycount(id);
	return PLUGIN_CONTINUE
}

public endround(id)
{
	if(!get_pcvar_num(g_LENABLE))
		return PLUGIN_CONTINUE

	// Удаление мин после конца раунда
	DeleteTask(id);
	RemoveAllTripmines(id);

	return PLUGIN_CONTINUE
}

public zp_round_ended(winteam)
{
	if(!get_pcvar_num(g_LENABLE))
		return PLUGIN_CONTINUE

	// Удаление мин после конца раунда
	static id;
	for (id = 0; id < 33; ++id)
	{
		if (!is_user_connected(id))
			continue;
		
		DeleteTask(id);
		RemoveAllTripmines(id);
	}

	return PLUGIN_CONTINUE
}

public zp_user_infected_post(id, infector, nemesis)
{
	if(!get_pcvar_num(g_LENABLE))
		return PLUGIN_CONTINUE;
	
	if (!is_user_connected(id) || !is_user_alive(id))
		return PLUGIN_CONTINUE;
	
	DeleteTask(id);
	RemoveAllTripmines(id);
	return PLUGIN_CONTINUE;
}

public DeathEvent(){
	if(!get_pcvar_num(g_LENABLE))
		return PLUGIN_CONTINUE

	new id = read_data(2)
	if(!is_user_connected(id))
		return PLUGIN_CONTINUE
		
	DeleteTask(id);
	RemoveAllTripmines(id);
	return PLUGIN_CONTINUE
}

public RemoveAllTripmines(i_Owner)
{
	new iEnt = g_MaxPL + 1;
	new clsname[32];
	while((iEnt = engfunc(EngFunc_FindEntityByString, iEnt, "classname", ENT_CLASS_NAME)))
	{
		if(i_Owner)
		{
			if(pev(iEnt, LASERMINE_OWNER) != i_Owner)
				continue;
			clsname[0] = '^0'
			pev(iEnt, pev_classname, clsname, sizeof(clsname)-1);
			if(equali(clsname, ENT_CLASS_NAME))
			{
				PlaySound(iEnt, STOP_SOUND);
				RemoveEntity(iEnt);
			}
		}
		else
			set_pev(iEnt, pev_flags, FL_KILLME);
	}
	g_deployed[i_Owner]=0;
}

public CutDeploy_onDamage(id)
{
	if(get_user_health(id) < 1)
		DeleteTask(id);
}

DeleteTask(id)
{
	if(task_exists((TASK_PLANT + id)))
	{
		remove_task((TASK_PLANT + id))
	}
	if(task_exists((TASK_RELEASE + id)))
	{
		remove_task((TASK_RELEASE + id))
	}
	g_settinglaser[id] = false
	return PLUGIN_CONTINUE;
}

stock set_rendering(entity, fx = kRenderFxNone, r = 255, g = 255, b = 255, render = kRenderNormal, amount = 16)
{
	static Float:RenderColor[3];
	RenderColor[0] = float(r);
	RenderColor[1] = float(g);
	RenderColor[2] = float(b);

	set_pev(entity, pev_renderfx, fx);
	set_pev(entity, pev_rendercolor, RenderColor);
	set_pev(entity, pev_rendermode, render);
	set_pev(entity, pev_renderamt, float(amount));

	return 1
}

// Gets offset data
get_offset_value(id, type)
{
	new key = -1;
	switch(type)
	{
		case OFFSET_TEAM: key = OFFSET_TEAM;
		case OFFSET_MONEY:
		key = OFFSET_MONEY;
		case OFFSET_DEATH: key = OFFSET_DEATH;
	}
	if(key != -1)
	{
		if(is_amd64_server()) key += 25;
		return get_pdata_int(id, key);
	}
	return -1;
}