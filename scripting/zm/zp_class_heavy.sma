
#include <amxmodx>
#include <fakemeta>
#include <engine>
#include <fun>
#include <zombieplague>

#define TASK_COOLDOWN 27015
#define TASK_REMOVE_TRAP 37015

new const zclass_name[] = "Большой "
new const zclass_info[] = "Trap [G]"
new const zclass_model[] = "heavy"
new const zclass_clawmodel[] = "v_big_zl.mdl"
const zclass_health = 5000
const zclass_speed = 230
const Float:zclass_gravity = 1.0
const Float:zclass_knockback = 1.0

// Main Trap Vars
new g_zheavy
new bool:can_make_trap[33]
new bool:player_trapped[33]

new const trap_string[] = "trap"
new const trap_model[] = "models/zombie_plague/zombie_trap.mdl"

new cvar_cooldown
new cvar_trap_hp
new cvar_trap_time

public plugin_init()
{
	register_plugin("[ZP] Zombie Class: Heavy", "1.2", "Dias")
	register_clcmd("drop", "use_skill")
	register_event("ResetHUD", "new_round", "be")
	register_touch(trap_string, "*", "fw_touch")
	register_forward(FM_PlayerPreThink, "fw_think", 0);

	cvar_register()
}

public cvar_register()
{
	cvar_cooldown = register_cvar("qz_cooldown", "30")
	cvar_trap_time = register_cvar("qz_trap_time", "15")
	cvar_trap_hp = register_cvar("qz_trap_hp", "500")
}

public plugin_precache()
{
	g_zheavy = zp_register_zombie_class(zclass_name, zclass_info, zclass_model, zclass_clawmodel, zclass_health, zclass_speed, zclass_gravity, zclass_knockback)	
	precache_model(trap_model)
}

public new_round(id)
{
	new trap = find_ent_by_class(0, trap_string)
	remove_entity(trap)
	
	can_make_trap[id] = false
	player_trapped[id] = false
	
	set_user_maxspeed(id, -1.0)
	set_user_gravity(id, 1.0)
	
	remove_task(id+TASK_COOLDOWN)
	remove_task(id+TASK_REMOVE_TRAP)
}

public zp_user_infected_post(id, attacker)
{
	if(zp_get_user_zombie(id) && zp_get_user_zombie_class(id) == g_zheavy)
	{
		remove_task(id+TASK_COOLDOWN)
		client_print(id, print_chat, "[ZP] You are Heavy Zombie. Press (G) to Make a Trap")
		can_make_trap[id] = true
	}
	
	if(player_trapped[id] == true)
	{
		player_trapped[id] = false
		
		new trap = find_ent_by_class(0, trap_string)
		remove_entity(trap)
		
		remove_task(id+TASK_REMOVE_TRAP)
	}
}

public use_skill(id)
{
	if(is_user_alive(id) && zp_get_user_zombie(id) && zp_get_user_zombie_class(id) == g_zheavy && !zp_get_user_nemesis(id) && !zp_get_user_nemesis(id))
	{
		if(can_make_trap[id])
		{
			create_trap(id)
			} else {
			client_print(id, print_chat, "[ZP]Способность перезадится через %i секунд", get_pcvar_num(cvar_cooldown))
		}
	}
}

public create_trap(id)
{
	new Float:Origin[3]
	entity_get_vector(id, EV_VEC_origin, Origin)
	
	Origin[2] -= 35.0
	
	new trap = create_entity("info_target")
	entity_set_vector(trap, EV_VEC_origin, Origin)
	
	entity_set_float(trap, EV_FL_takedamage, 1.0)
	entity_set_float(trap, EV_FL_health, get_pcvar_float(cvar_trap_hp))
	
	entity_set_string(trap, EV_SZ_classname, trap_string)
	entity_set_model(trap, trap_model)	
	entity_set_int(trap, EV_INT_solid, 1)
	
	entity_set_byte(trap,EV_BYTE_controller1,125);
	entity_set_byte(trap,EV_BYTE_controller2,125);
	entity_set_byte(trap,EV_BYTE_controller3,125);
	entity_set_byte(trap,EV_BYTE_controller4,125);
	
	new Float:size_max[3] = {5.0,5.0,5.0}
	new Float:size_min[3] = {-5.0,-5.0,-5.0}
	entity_set_size(trap, size_min, size_max)
	
	entity_set_float(trap, EV_FL_animtime, 2.0)
	entity_set_float(trap, EV_FL_framerate, 1.0)
	entity_set_int(trap, EV_INT_sequence, 0)
	
	drop_to_floor(trap)
	
	can_make_trap[id] = false
	set_task(get_pcvar_float(cvar_cooldown), "reset_cooldown", id+TASK_COOLDOWN)
}

public reset_cooldown(taskid)
{
	new id = taskid - TASK_COOLDOWN
	if(is_user_alive(id) && zp_get_user_zombie(id) && zp_get_user_zombie_class(id) == g_zheavy)
	{
		if(can_make_trap[id] == false)
		{
			can_make_trap[id] = true
			client_print(id, print_chat, "[ZP] Способность, перезарежена нажмите [G]")
		}
	}	
}

public fw_touch(trap, id)
{
	if(!pev_valid(trap))
		return	
	
	if(is_user_alive(id) && !zp_get_user_zombie(id))
	{
		new ent = find_ent_by_class(0, trap_string)
		entity_set_int(ent, EV_INT_sequence, 1)
		
		player_trapped[id] = true
		set_task(get_pcvar_float(cvar_trap_time), "remove_trap", id+TASK_REMOVE_TRAP)
	}
}

public remove_trap(taskid)
{
	new id = taskid - TASK_REMOVE_TRAP
	
	set_user_maxspeed(id, -1.0)
	set_user_gravity(id, 1.0)
	player_trapped[id] = false

	new trap = find_ent_by_class(0, trap_string)
	remove_entity(trap)
	
	remove_task(id+TASK_REMOVE_TRAP)
}

public spawn_post(id)
{
	if(is_user_alive(id))
	{
		player_trapped[id] = false 
	}
}  

public fw_think(id)
{
	if(is_user_alive(id) && player_trapped[id] == true)
	{
		set_user_maxspeed(id, 0.1)
		set_user_gravity(id, 10000.0)
	}
}
