/*
*	---------------------------------------------------------------------------------------------------------
*	------------------------------------[ZP] Zombie Class: Hunter--------------------------------------------
*	---------------------------------------------------------------------------------------------------------
*	--------------------------------Author: SNAKER_BEATTER + ORIGINALLY BY DJHD!-----------------------------
*	---------------------------------------------------------------------------------------------------------
*				About:
*		Well this is not by me, this is originally by DJHD!.
*		When i tested hes original hunter if you're a human you can do super jump and if nemesis and 
*		survivor too and thats is i  fixed at this plugin...
*	---------------------------------------------------------------------------------------------------------
*				Description:
*		This zombie has long jumps as well as the popular game L4D2
*		Well, this time the skill is good and better,
*		to jump you have to press Ctrl + E and look where you want to jump...
*	---------------------------------------------------------------------------------------------------------
*				Credits:
*		DJHD! - Originally post by him
*	---------------------------------------------------------------------------------------------------------
*				Cvars:
*		zp_hunter_jump_cooldown // After used cooldown starts. default=1.0 or 1
*		zp_hunter_jump_force // How high hunter's jump do?. default=890 (higher than nemesis's leap)
*		zp_zclass_hunterl4d2 // Show hunter's version and author at console
*	----------------------------------------------------------------------------------------------------------
*				Modules:
*		fakemeta
*	-----------------------------------------------------------------------------------------------------------
*				Change log:
*		0.2a (Oct 1, 2011)
*		{
*			0.2 originally posted by DJHD!
*			Fix hunter is not zombie he can do super jump
*		}
*		0.2b (Oct 5, 2011)
*		{
*			Fix run time errors
&			Fix another zombie class(not hunter) can do super jump
*			FIx after infected do super jump auto
*		}
*/

/******************************************************
		[Include files]
******************************************************/

#include <amxmodx>
#include <fakemeta>
#include <zombieplague>

/******************************************************
		[Plugin infos]
******************************************************/

#define PLUGIN_NAME "[ZP] ZCLASS: Hunter zombie"
#define PLUGIN_VERSION "0.2b"
#define PLUGIN_AUTHOR "DJHD!+snaker beatter"

/******************************************************
		[Id(s)]
******************************************************/

// Zombie Attributes
new const zclass_name[] = "Hunter L4D2"
new const zclass_info[] = "You can do super jumps"
new const zclass_model[] = { "hunterv2_zp" }
new const zclass_clawmodel[] = { "v_knife_zombie_hunter.mdl" }
const zclass_speed = 250
const zclass_health = 3800
const Float:zclass_gravity = 0.9
const Float:zclass_knockback = 0.0
// Sounds
new const leap_sound[2][] = { "zombiehazard/zombiehunter/hunter_jump1.wav", "zombiehazard/zombiehunter/hunter_jump2.wav" }
// Variables
new g_hunter
// Arrays
new Float:g_lastleaptime[33]
// Cvar pointers
new cvar_force, cvar_cooldown

/******************************************************
		[Main events] + [Precache event]
******************************************************/

public plugin_precache()
{
	// Register the new class and store ID for reference
	g_hunter = zp_register_zombie_class(zclass_name, zclass_info, zclass_model, zclass_clawmodel, zclass_health, zclass_speed, zclass_gravity, zclass_knockback)
	// Sound
	static i
	for(i = 0; i < sizeof leap_sound; i++)
		precache_sound(leap_sound[i])
}

public plugin_init() 
{
	// Plugin Info
	register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)

	register_clcmd("drop", "use_skill")
	
	// Cvars
	cvar_force = register_cvar("zp_hunter_jump_force", "700") 
	cvar_cooldown = register_cvar("zp_hunter_jump_cooldown", "15.0")
	
	static szCvar[30]
	formatex(szCvar, charsmax(szCvar), "v%s by %s", PLUGIN_VERSION, PLUGIN_AUTHOR)
	register_cvar("zp_zclass_hunterl4d2", szCvar, FCVAR_SERVER|FCVAR_SPONLY)
}

public plugin_cfg()
{
	// Execute config file (zombieplague.cfg)
	server_cmd("exec addons/amxmodx/configs/zombiehazard.cfg")
}

/******************************************************
		[Events]
******************************************************/

public zp_user_infected_post(id, infector) // Infected post
{
	// It's the selected zombie class
	if(zp_get_user_zombie_class(id) == g_hunter)
	{
		if(zp_get_user_nemesis(id))
			return
		
		// Message
		client_print(id, print_chat, "[ZP] Нажмите [G] что бы сделать суперпрыжок")
	}
}

public use_skill(id)
{
	if(!is_user_connected(id) || !is_user_alive(id) || !zp_get_user_zombie(id) || zp_get_user_zombie_class(id) != g_hunter)
		return;

	if (zp_get_user_nemesis(id) || zp_get_user_assassin(id))
		return;
	
	if (!(pev(id, pev_flags) & FL_ONGROUND))
		return;
	
	static Float:cooldown
	cooldown = get_pcvar_float(cvar_cooldown)
	
	if (get_gametime() - g_lastleaptime[id] >= cooldown)
	{
		static Float:velocity[3]
		velocity_by_aim(id, get_pcvar_num(cvar_force), velocity)
		set_pev(id, pev_velocity, velocity)
		
		emit_sound(id, CHAN_STREAM, leap_sound[random_num(0, sizeof leap_sound -1)], 1.0, ATTN_NORM, 0, PITCH_HIGH)

		// Set the current super jump time
		g_lastleaptime[id] = get_gametime()
	}
}

/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/
