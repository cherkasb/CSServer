
#include <amxmodx>
#include <fakemeta>
#include <engine>
#include <fun>
#include <zombieplague>
#include <fakemeta_util>

#define TASK_COOLDOWN 27015
#define TASK_REMOVE_TRAP 37015

new const zclass_name[] = "Trapper "
new const zclass_info[] = "Trap [G]"
new const zclass_model[] = "zombie_source"
new const zclass_clawmodel[] = "v_knife_zombie.mdl"
const zclass_health = 5000
const zclass_speed = 230
const Float:zclass_gravity = 1.0
const Float:zclass_knockback = 1.0

// Main Trap Vars
new g_zheavy
new bool:can_make_trap[33]
new g_associated_trap[33]

new const trap_string[] = "trap"
new const trap_model[] = "models/zombie_plague/zombie_trap.mdl"

new cvar_cooldown
new cvar_trap_hp
new cvar_trap_time

new const g_item_name[] = { "AntiTrapper" }
const g_item_cost = 4000

new g_itemid_antitrapper;
new g_hasantitrapper[33] = { false , ... }

public plugin_init()
{
	register_plugin("[ZP] Zombie Class: Heavy", "1.2", "Dias")
	register_logevent("EndRound", 		2, 				"1=Round_End");
	register_clcmd("drop", "use_skill")
	register_touch(trap_string, "*", "fw_touch")
	register_forward(FM_PlayerPreThink, "fw_think", 0);

	cvar_register()
	
	g_itemid_antitrapper = zp_register_extra_item( g_item_name, g_item_cost, ZP_TEAM_HUMAN)
}

public cvar_register()
{
	cvar_cooldown = register_cvar("qz_cooldown", "15")
	cvar_trap_time = register_cvar("qz_trap_time", "4")
	cvar_trap_hp = register_cvar("qz_trap_hp", "500")
}

public plugin_cfg()
{
	// Execute config file (zombieplague.cfg)
	server_cmd("exec addons/amxmodx/configs/zombiehazard.cfg")
}

public plugin_precache()
{
	g_zheavy = zp_register_zombie_class(zclass_name, zclass_info, zclass_model, zclass_clawmodel, zclass_health, zclass_speed, zclass_gravity, zclass_knockback)	
	precache_model(trap_model)
}

public EndRound()
{
	new iEntity = -1;
	while ((iEntity = fm_find_ent_by_class(iEntity,  trap_string)))
	{
		set_pev(iEntity, pev_flags, pev(iEntity, pev_flags) | FL_KILLME);
	}
	new i = 0;
	arrayset(can_make_trap, false, 33)
	arrayset(g_hasantitrapper, false, 33)
	
	for (i = 0; i < 33; ++i)
	{
		if (task_exists(i+TASK_COOLDOWN))
			remove_task(i+TASK_COOLDOWN)
		if (task_exists(i+TASK_REMOVE_TRAP))
			remove_task(i+TASK_REMOVE_TRAP)
	}
}

public zp_user_infected_post(id, attacker)
{
	if(zp_get_user_zombie(id) && zp_get_user_zombie_class(id) == g_zheavy)
	{
		remove_task(id+TASK_COOLDOWN)
		client_print(id, print_chat, "[ZP] Нажмите [G] что бы поставить ловушку")
		can_make_trap[id] = true
	}
	zp_set_user_frozen(id, false);
	if (pev_valid(g_associated_trap[id]))
		remove_entity(g_associated_trap[id])
	remove_task(id+TASK_REMOVE_TRAP)
	
	g_hasantitrapper[id] = false;
}

public use_skill(id)
{
	if(is_user_alive(id) && zp_get_user_zombie(id) && zp_get_user_zombie_class(id) == g_zheavy && !zp_get_user_nemesis(id) && !zp_get_user_nemesis(id))
	{
		if(can_make_trap[id])
		{
			create_trap(id)
		}
		else
		{
			client_print(id, print_chat, "[ZP] Способность перезаряжается!")
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
			client_print(id, print_chat, "[ZP] Способность перезаряжена")
		}
	}	
}

public fw_touch(trap, id)
{
	if(!pev_valid(trap))
		return	
	
	if(is_user_alive(id) && !zp_get_user_zombie(id) && !g_hasantitrapper[id])
	{
		g_associated_trap[id] = trap;
		entity_set_int(trap, EV_INT_sequence, 1)
		
		zp_set_user_frozen(id, true);
		set_task(get_pcvar_float(cvar_trap_time), "remove_trap", id+TASK_REMOVE_TRAP)
	}
}

public remove_trap(taskid)
{
	new id = taskid - TASK_REMOVE_TRAP
	zp_set_user_frozen(id, false);
	remove_entity(g_associated_trap[id])
	remove_task(id+TASK_REMOVE_TRAP)
}

/*
** Antitrapper
*/

public zp_extra_item_selected(player, itemid)
{
	if (itemid == g_itemid_antitrapper)
	{
		g_hasantitrapper[player] = true;
	}
}

