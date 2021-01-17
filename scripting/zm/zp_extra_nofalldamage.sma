#include <amxmodx>
#include <engine>
#include <zombieplague>

#define FALL_VELOCITY 350.0

new const g_item_name[] = { "No Fall Damage" }
const g_item_cost = 2000

new g_item_nofall

new g_havenofall[33] = 0
new bool:falling[33];

public plugin_init()
{
	register_plugin("[ZP] No fall damage", "4.3 Fix6", "artlex")
	register_event("HLTV", "event_round_start", "a", "1=0", "2=0")
	
	g_item_nofall = zp_register_extra_item( g_item_name, g_item_cost, ZP_TEAM_HUMAN)
}

public event_round_start()
{
	arrayset(g_havenofall, 0, 33)
}

public zp_extra_item_selected(player, itemid)
{
	if (itemid == g_item_nofall)
	{
		g_havenofall[player] = true;
	}
}

public zp_extraitem_available(id, itemid)
{
	if (g_havenofall[id] || zp_get_user_vip(id))
	{
		zp_setextraitemavailable(id, g_item_nofall, false)
		if (itemid == g_item_nofall)
			client_print(id, print_chat, "У тебя уже есть защита от падения!")
		return (PLUGIN_HANDLED);
	}
	zp_setextraitemavailable(id, g_item_nofall, true)
	return (PLUGIN_CONTINUE);
}

public client_putinserver(id)
{
	g_havenofall[id] = 0
}

public client_disconnect(id)
{
	g_havenofall[id] = 0
}

public client_PreThink(id)
{
	if(is_user_alive(id) && is_user_connected(id) && (g_havenofall[id] || zp_get_user_vip(id)))
	{
		if(entity_get_float(id, EV_FL_flFallVelocity) >= FALL_VELOCITY)
		{
			falling[id] = true;
		}
		else
		{
			falling[id] = false;
		}
	}
}

public client_PostThink(id)
{
	if(is_user_alive(id) && is_user_connected(id) && (g_havenofall[id] || zp_get_user_vip(id)))
	{
		if(falling[id])
		{
			entity_set_int(id, EV_INT_watertype, -3);
		}
	}
}
