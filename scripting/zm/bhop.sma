#include <amxmodx>
#include <engine>

#define	FL_WATERJUMP	(1<<11)	
#define	FL_ONGROUND	(1<<9)	

public plugin_init() {
	register_plugin("Super Bunny Hopper", "1.2", "Cheesy Peteza")
	register_cvar("sbhopper_version", "1.2", FCVAR_SERVER)

	register_cvar("bh_enabled", "1")
	register_cvar("bh_autojump", "1")
	register_cvar("bh_showusage", "1")
}

public client_PreThink(id) {
	if (!get_cvar_num("bh_enabled"))
		return PLUGIN_CONTINUE

	entity_set_float(id, EV_FL_fuser2, 0.0)		

	if (!get_cvar_num("bh_autojump"))
		return PLUGIN_CONTINUE

// Code from CBasePlayer::Jump (player.cpp)		Make a player jump automatically
	if (entity_get_int(id, EV_INT_button) & 2) {	
		new flags = entity_get_int(id, EV_INT_flags)

		if (flags & FL_WATERJUMP)
			return PLUGIN_CONTINUE
		if ( entity_get_int(id, EV_INT_waterlevel) >= 2 )
			return PLUGIN_CONTINUE
		if ( !(flags & FL_ONGROUND) )
			return PLUGIN_CONTINUE

		new Float:velocity[3]
		entity_get_vector(id, EV_VEC_velocity, velocity)
		velocity[2] += 250.0
		entity_set_vector(id, EV_VEC_velocity, velocity)

		entity_set_int(id, EV_INT_gaitsequence, 6)	
	}
	return PLUGIN_CONTINUE
}

public client_authorized(id)
	set_task(30.0, "showUsage", id)

public showUsage(id) {
	if ( !get_cvar_num("bh_enabled") || !get_cvar_num("bh_showusage") )
		return PLUGIN_HANDLED

	if ( !get_cvar_num("bh_autojump") ) {
		client_print(id, print_chat, "[AMX] Bunny hopping is enabled on this server. You will not slow down after jumping.")
	} else {
		client_print(id, print_chat, "[AMX] Auto bunny hopping is enabled on this server. Just hold down jump to bunny hop.")
	}
	return PLUGIN_HANDLED
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1049\\ f0\\ fs16 \n\\ par }
*/
