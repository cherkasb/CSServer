/*================================================================================
	
	-------------------------------------------------
	-*- [ZP] Extra Item: Anti-Infection Armor 1.0 -*-
	-------------------------------------------------
	
	~~~~~~~~~~~~~~~
	- Description -
	~~~~~~~~~~~~~~~
	
	This item gives humans some armor that offers protection
	against zombie injuries.
	
================================================================================*/

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <zombieplague>
#include <Hamsandwich>
#include <cstrike>

/*================================================================================
 [Plugin Customization]
=================================================================================*/

new const g_item_name[] = { "Anti-Infection armor" }
const g_item_cost = 1000

new const g_sound_buyarmor[] = { "items/tr_kevlar.wav" }

new cvar_maxarmor, cvar_armor_buyamount

/*============================================================================*/

// Item IDs
new g_itemid_humanarmor

public plugin_precache()
{
	precache_sound(g_sound_buyarmor)
}

public plugin_init()
{
	register_plugin("[ZP] Extra: Anti-Infection Armor", "1.0", "artlex")
	
	register_clcmd("say /arm", "clcmd_buyarmor")
	register_clcmd("zp_buy_armor", "clcmd_buyarmor")
	
	cvar_maxarmor = register_cvar("zp_armor_maxarmor", "200") //Max armor player can have
	cvar_armor_buyamount = register_cvar("zp_armor_buyamount", "100") //How many armor player gets when he buys it
	
	g_itemid_humanarmor = zp_register_extra_item( g_item_name, g_item_cost, ZP_TEAM_HUMAN)
}

public clcmd_buyarmor(id)
{
	if (!is_user_connected(id) || !is_user_alive(id) || zp_get_user_zombie(id))
		return ;
	if (zp_get_user_survivor(id) || zp_get_user_sniper(id))
		return;
	zp_force_buy_extra_item(id, g_itemid_humanarmor, 0);
}

// Human buys our upgrade, give him some armor
public zp_extra_item_selected(player, itemid)
{
	if (itemid == g_itemid_humanarmor)
	{
		new CurrentArmor = get_user_armor(player)
		
		if (CurrentArmor >= get_pcvar_num(cvar_maxarmor))
		{
			return;
		}
		
		CurrentArmor += get_pcvar_num(cvar_armor_buyamount);
		set_pev(player, pev_armorvalue, float(min(CurrentArmor, get_pcvar_num(cvar_maxarmor))))
		engfunc(EngFunc_EmitSound, player, CHAN_BODY, g_sound_buyarmor, 1.0, ATTN_NORM, 0, PITCH_NORM)
	}
}

public fw_TouchWeapon(weapon, id)
{
	if (!is_user_connected(id))
	{
		return HAM_IGNORED;
	}
	if (cs_get_armoury_type(weapon) != CSW_VEST)
	{
		return HAM_IGNORED;
	}
	new CsArmorType:ArmorType, iArmor;
	iArmor = cs_get_user_armor(id, ArmorType);
	if (iArmor > 100)
	{
		return HAM_SUPERCEDE;
	}
	return HAM_IGNORED;
}

public zp_extraitem_available(id, itemid)
{
	if (get_user_armor(id) >= get_pcvar_num(cvar_maxarmor))
	{
		zp_setextraitemavailable(id, g_itemid_humanarmor, false)
		if (itemid == g_itemid_humanarmor)
			client_print(id, print_chat, "У тебя уже максимум брони!")
		return (PLUGIN_HANDLED);
	}
	zp_setextraitemavailable(id, g_itemid_humanarmor, true)
	return (PLUGIN_CONTINUE);
}
