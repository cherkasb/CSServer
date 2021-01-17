#include <amxmodx>
#include <fun>
#include <zombieplague>

new const human_item_name[] = "Human Buy HP!"
new const zombie_item_name[] = "Zombie Buy HP!"

new g_humanitemid_buyhp
new g_zombieitemid_buyhp

new cvar_humanbuyhpamount, cvar_zombiebuyhpamount

public plugin_init() 
{
	register_plugin("[ZP] Buy Health Points", "1.0", "T[h]E Dis[as]teR")
	cvar_humanbuyhpamount = register_cvar("zp_humanbuyhpamount", "100")
	cvar_zombiebuyhpamount = register_cvar("zp_zombiebuyhpamount", "1000")
	g_humanitemid_buyhp = zp_register_extra_item(human_item_name, 1500, ZP_TEAM_HUMAN)
	g_zombieitemid_buyhp = zp_register_extra_item(zombie_item_name, 1200, ZP_TEAM_ZOMBIE)
}

public zp_extra_item_selected(id,itemid)
{
	if (!is_user_alive(id))
		return PLUGIN_HANDLED;
	
	if (itemid == g_humanitemid_buyhp)
	{
		set_user_health(id, get_user_health(id) + get_pcvar_num(cvar_humanbuyhpamount));
	}
	else if (itemid == g_zombieitemid_buyhp)
	{
		set_user_health(id, get_user_health(id) + get_pcvar_num(cvar_zombiebuyhpamount));
	}
	return PLUGIN_CONTINUE;
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang3082\\ f0\\ fs16 \n\\ par }
*/
