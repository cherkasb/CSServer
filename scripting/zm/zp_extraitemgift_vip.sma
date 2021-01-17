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

new const ZP_KILLREWARDBAGS_FILE[] = "zp_weapongift_vip.ini"

new Array:g_rewarditemnamesh;
new Array:g_rewarditemschanceh;

new g_playersgifts[33]

new g_msgSayText

public plugin_precache()
{
	g_rewarditemnamesh = ArrayCreate(128, 1);
	g_rewarditemschanceh = ArrayCreate(1, 1);
	
	load_customization_from_file()
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
 	register_event("HLTV", "EVENT_round_start", "a", "1=0", "2=0")
	
	// Регистируем файл языков
	register_dictionary("zp_rewardbags.txt")
	
	register_clcmd("zp_trygivevipgift_art", "clcmd_givevipgift")
	
	g_msgSayText = get_user_msgid("SayText")
}

public EVENT_round_start()
{
	arrayset(g_playersgifts, 0, 33)
}

public clcmd_givevipgift(id)
{
	if (!is_user_alive(id) || !pev_valid(id))
		return FMRES_IGNORED
	new i, chance;
	new buffer[256]
	
	if (!zp_get_user_zombie(id))
	{
		if (!zp_get_user_survivor(id) && !zp_get_user_sniper(id))
		{
			for (i = 0; i < ArraySize(g_rewarditemnamesh); ++i)
			{
				chance = ArrayGetCell(g_rewarditemschanceh, i);
				if (random_num(1, chance) == 1)
				{
					ArrayGetString(g_rewarditemnamesh, i, buffer, 64)
					reward_extraitem(id, buffer)
					break;
				}
			}
		}
	}
	return FMRES_IGNORED
	
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
	new path[64], linedata[64], key[32], value[32]
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

			ArrayPushString(g_rewarditemnamesh, key)
			ArrayPushCell(g_rewarditemschanceh, CurrentChance)
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

