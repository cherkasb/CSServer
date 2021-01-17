/* 
	Plugin by Doomsday
	ICQ: 692561
*/

#include <amxmodx>
#include <amxmisc>

#include <fakemeta_util>
#include <zombieplague>
#include <hamsandwich>
#include <fakemeta>
#include <fun>

#define PLUGIN "[ZP] Kill Rewards"
#define VERSION "1.0"
#define AUTHOR "Doomsday"

#define G_TYPENAME "info_target"

new const item_class_name[] = "ammo"

new const ZP_KILLREWARDBAGS_FILE[] = "zp_killrewardbags.ini"

/* Here you can change the model */
new g_model[] = "models/zombiehazard/justpro_omg.mdl"

new const g_minzmhp = 50;
new const g_maxzmhp = 200;

new const g_minhumanhp = 5;
new const g_maxhumanhp = 25;

new const g_minhumanarm = 5;
new const g_maxhumanarm = 25;

new const g_minmoney = 100;
new const g_maxmoney = 200;

new Array:g_rewarditemnamesh;
new Array:g_rewarditemschanceh;

new Array:g_rewarditemnamesz;
new Array:g_rewarditemschancez;

new g_EntBag;

new g_msgSayText;

enum
{
	SECTION_NONE = 0,
	SECTION_HUMAN = 1,
	SECTION_ZOMBIE = 2
}

public plugin_precache()
{
	
	g_rewarditemnamesh = ArrayCreate(32, 1);
	g_rewarditemschanceh = ArrayCreate(1, 1);
	g_rewarditemnamesz = ArrayCreate(32, 1);
	g_rewarditemschancez = ArrayCreate(1, 1);
	
	precache_model(g_model)
	
	load_customization_from_file()
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_forward(FM_Touch, "fwd_Touch")

	RegisterHam(Ham_Killed, "player", "fw_PlayerKilled")

 	register_event("HLTV", "EVENT_round_start", "a", "1=0", "2=0")
	
	// Регистируем файл языков
	register_dictionary("zp_rewardbags.txt")
	
	g_EntBag = engfunc(EngFunc_AllocString,G_TYPENAME);
	
	g_msgSayText = get_user_msgid("SayText")
}

public EVENT_round_start()
{	
	deleteAllItems()
}

public deleteAllItems()
{
	new ent = FM_NULLENT
	static string_class[] = "classname"
	while ((ent = engfunc(EngFunc_FindEntityByString, ent, string_class, item_class_name))) 
		set_pev(ent, pev_flags, FL_KILLME)
}

public addItem(origin[3])
{
	new ent = engfunc(EngFunc_CreateNamedEntity,g_EntBag);
	set_pev(ent, pev_classname, item_class_name)
	
	engfunc(EngFunc_SetModel,ent, g_model)
	
	new Float:MinBox[3] = {-5.0, -5.0, 0.0}
	new Float:MaxBox[3] = {5.0, 5.0, 5.0}
	new Float:Size[6] = {-5.0, -5.0, 0.0, 5.0, 5.0, 5.0}

	set_pev(ent, pev_mins, MinBox)
	set_pev(ent, pev_maxs, MaxBox)
	set_pev(ent, pev_size, Size)
	engfunc(EngFunc_SetSize, ent, MinBox, MaxBox)

	set_pev(ent, pev_solid, SOLID_BBOX )
	set_pev(ent, pev_movetype, MOVETYPE_TOSS)
	
	new Float:fOrigin[3]
	IVecFVec(origin, fOrigin)
	set_pev(ent, pev_origin, fOrigin)
	
	set_pev(ent,pev_renderfx,kRenderFxGlowShell)

	new Float:velocity[3];
	pev(ent,pev_velocity,velocity);
	velocity[2] = random_float(265.0,285.0);
	set_pev(ent,pev_velocity,velocity)

	switch(random_num(1,4))
	{
		case 1: set_pev(ent,pev_rendercolor,Float:{0.0,0.0,255.0})
		case 2: set_pev(ent,pev_rendercolor,Float:{0.0,255.0,0.0})
		case 3: set_pev(ent,pev_rendercolor,Float:{255.0,0.0,0.0})
		case 4: set_pev(ent,pev_rendercolor,Float:{255.0,255.0,255.0})
	}
}

public fwd_Touch(toucher, touched)
{
	if (!is_user_alive(toucher) || !pev_valid(touched))
		return FMRES_IGNORED
	
	new classname[32]	
	pev(touched, pev_classname, classname, 31)

	if (!equal(classname, item_class_name))
		return FMRES_IGNORED
	
	set_pev(touched, pev_effects, EF_NODRAW)
	set_pev(touched, pev_solid, SOLID_NOT)
	
	new i, chance;
	new buffer[64]
	
	if (zp_get_user_zombie(toucher))
	{
		if (!zp_get_user_nemesis(toucher) && !zp_get_user_assassin(toucher))
		{
			for (i = 0; i < ArraySize(g_rewarditemnamesz); ++i)
			{
				chance = ArrayGetCell(g_rewarditemschancez, i);
				ArrayGetString(g_rewarditemnamesz, i, buffer, 64)
				if (random_num(1, chance) == 1)
				{
					give_reward(toucher, buffer)
					break;
				}
			}
		}
		else
			reward_hp(toucher)
	}
	else
	{
		if (!zp_get_user_survivor(toucher) && !zp_get_user_sniper(toucher))
		{
			for (i = 0; i < ArraySize(g_rewarditemnamesh); ++i)
			{
				chance = ArrayGetCell(g_rewarditemschanceh, i);
				ArrayGetString(g_rewarditemnamesh, i, buffer, 64)
				if (random_num(1, chance) == 1)
				{
					give_reward(toucher, buffer)
					break;
				}
			}
		}
		else
			reward_hp(toucher)
	}
	
	return FMRES_IGNORED
	
}

public fw_PlayerKilled(victim, attacker, shouldgib)
{
	new origin[3];
	get_user_origin(victim , origin);
	addItem(origin);
}

public give_reward(id, name[])
{
	if (equal(name, "GiveHP"))
		reward_hp(id)
	else if (equal(name, "GiveMoney"))
		reward_ammo(id)
	else if (equal(name, "GiveArmor"))
		reward_armor(id)
	else
		reward_extraitem(id, name)
}

public reward_ammo(id)
{
	new amount = random_num(g_minmoney, g_maxmoney);
	zp_set_user_ammo_packs(id, zp_get_user_ammo_packs(id) + amount)
	colored_print(id, "^x04%L", id, "REWARDBAGS_REWARDMONEY", amount)
}

public reward_hp(id)
{
	new amount = 0;
	if (zp_get_user_zombie(id) || zp_get_user_survivor(id))
		amount = random_num(g_minzmhp, g_maxzmhp);
	else
		amount = random_num(g_minhumanhp, g_maxhumanhp)
	set_user_health(id, get_user_health(id) + amount);
	colored_print(id, "^x04%L", id, "REWARDBAGS_REWARDHP", amount)
}

public reward_armor(id)
{
	if (zp_get_user_zombie(id))
		return;
	new CurrentArmor = get_user_armor(id)
	new amount = random_num(g_minhumanarm, g_maxhumanarm)
	if (CurrentArmor < 200)
	{
		CurrentArmor += amount;
		set_pev(id, pev_armorvalue, float(min(CurrentArmor, 200)))
	}
	colored_print(id, "^x04%L", id, "REWARDBAGS_REWARDARMOR", amount)
}

public reward_extraitem(id, name[])
{
	new itemid = zp_get_extra_item_id(name)
	if (itemid == -1)
	{
		console_print(0, "[BC] Error: Invalid extraitem id for %s", name);
		return;
	}
	zp_force_buy_extra_item(id, itemid, 1);
	colored_print(id, "^x04%L", id, "REWARDBAGS_REWARDEXTRA", name)
}

public load_customization_from_file()
{
	new path[256], linedata[256], key[128], value[128]
	new CurrentSection = SECTION_NONE;
	new CurrentChance = 0;
	get_configsdir(path, charsmax(path))
	format(path, charsmax(path), "%s/%s", path, ZP_KILLREWARDBAGS_FILE)
	
	// Parse if present
	if (file_exists(path))
	{
		// Open extra items file for reading
		new file = fopen(path, "rt")
		while (file && !feof(file))
		{
			// Read one line at a time
			fgets(file, linedata, charsmax(linedata))
			
			// Replace newlines with a null character to prevent headaches
			replace(linedata, charsmax(linedata), "^n", "")
			
			// Blank line or comment
			if (!linedata[0] || linedata[0] == ';')
				continue;
			
			trim(linedata)
			
			// New item starting
			if (linedata[0] == '[')
			{
				// Store its real name for future reference
				if (equali(linedata, "[ZOMBIE]", 8))
				{
					CurrentSection = SECTION_ZOMBIE;
				}
				else if (equali(linedata, "[HUMAN]", 7))
				{
					CurrentSection = SECTION_HUMAN;
				}
				continue;
			}
			else if (CurrentSection == SECTION_NONE)
				continue;
			
			// Get key and value(s)
			strtok(linedata, key, charsmax(key), value, charsmax(value), ',')
			
			// Trim spaces
			trim(key)
			trim(value)
			
			if (!key[0])
				continue;
			CurrentChance = str_to_num(value);
			if (CurrentChance == 0)
				continue;
			
			if (CurrentSection == SECTION_HUMAN)
			{
				ArrayPushString(g_rewarditemnamesh, key)
				ArrayPushCell(g_rewarditemschanceh, CurrentChance)
			}
			else if (CurrentSection == SECTION_ZOMBIE)
			{
				ArrayPushString(g_rewarditemnamesz, key)
				ArrayPushCell(g_rewarditemschancez, CurrentChance)
			}
		}
		if (file)
			fclose(file)
	}
	
}

colored_print(target, const message[], any:...)
{
	static buffer[512], i, argscount
	argscount = numargs()
	
	// Send to everyone
	if (!target)
	{
		static player
		for (player = 1; player <= 33; player++)
		{
			// Not connected
			if (is_user_connected(player))
				continue;
			
			// Remember changed arguments
			static changed[5], changedcount // [5] = max LANG_PLAYER occurencies
			changedcount = 0
			
			// Replace LANG_PLAYER with player id
			for (i = 2; i < argscount; i++)
			{
				if (getarg(i) == LANG_PLAYER)
				{
					setarg(i, 0, player)
					changed[changedcount] = i
					changedcount++
				}
			}
			
			// Format message for player
			vformat(buffer, charsmax(buffer), message, 3)
			
			// Send it
			message_begin(MSG_ONE_UNRELIABLE, g_msgSayText, _, player)
			write_byte(player)
			write_string(buffer)
			message_end()
			
			// Replace back player id's with LANG_PLAYER
			for (i = 0; i < changedcount; i++)
				setarg(changed[i], 0, LANG_PLAYER)
		}
	}
	// Send to specific target
	else
	{
		/*
		// Not needed since you should set the ML argument
		// to the player's id for a targeted print message
		
		// Replace LANG_PLAYER with player id
		for (i = 2; i < argscount; i++)
		{
			if (getarg(i) == LANG_PLAYER)
				setarg(i, 0, target)
		}
		*/
		
		// Format message for player
		vformat(buffer, charsmax(buffer), message, 3)
		
		// Send it
		message_begin(MSG_ONE, g_msgSayText, _, target)
		write_byte(target)
		write_string(buffer)
		message_end()
	}
}

