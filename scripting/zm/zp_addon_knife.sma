#include <amxmodx>
#include <fun>
#include <fakemeta>
#include <hamsandwich>
#include <zombieplague>
#include <engine>

#define PLUGIN_NAME 		"[ZP]knife Menu"
#define PLUGIN_VERSION		"2.2"
#define PLUGIN_AUTHOR 	"Mr.H"

#define FALL_VELOCITY 350.0

new Ham:Ham_Player_ResetMaxSpeed = Ham_Item_PreFrame

new KNIFE1_V_MODEL[] = "models/zombiehazard/zpknife/razor/v_razor.mdl"
new KNIFE1_P_MODEL[] = "models/zombiehazard/zpknife/razor/p_razor.mdl"

new KNIFE2_V_MODEL[] = "models/zombiehazard/zpknife/combat/v_combat.mdl"
new KNIFE2_P_MODEL[] = "models/zombiehazard/zpknife/combat/p_combat.mdl"

new KNIFE3_V_MODEL[] = "models/zombiehazard/zpknife/strong/v_strong.mdl"
new KNIFE3_P_MODEL[] = "models/zombiehazard/zpknife/strong/p_strong.mdl"

new KNIFE4_V_MODEL[] = "models/zombiehazard/zpknife/katana/v_katana.mdl"
new KNIFE4_P_MODEL[] = "models/zombiehazard/zpknife/katana/p_katana.mdl"

new KNIFE5_V_MODEL[] = "models/zombiehazard/zpknife/hammer/v_hammer.mdl"
new KNIFE5_P_MODEL[] = "models/zombiehazard/zpknife/hammer/p_hammer.mdl"

const OneKnifeSoundsSize = 6;

new const knife_sounds[][][] =
{
	{
		"zombiehazard/knives/razor/knife_draw.wav",
		"zombiehazard/knives/razor/knife_slash1.wav",
		"zombiehazard/knives/razor/knife_slash2.wav",
		"zombiehazard/knives/razor/knife_wall.wav",
		"zombiehazard/knives/razor/knife_miss.wav",
		"zombiehazard/knives/razor/knife_hit.wav"
	},
	{
		"zombiehazard/knives/combat/knife_draw.wav",
		"zombiehazard/knives/combat/knife_slash1.wav",
		"zombiehazard/knives/combat/knife_slash1.wav",
		"zombiehazard/knives/combat/knife_wall.wav",
		"zombiehazard/knives/combat/knife_miss.wav",
		"zombiehazard/knives/combat/knife_hit.wav"
	},
	{
		"zombiehazard/knives/strong/knife_draw.wav",
		"zombiehazard/knives/strong/knife_slash1.wav",
		"zombiehazard/knives/strong/knife_slash1.wav",
		"zombiehazard/knives/strong/knife_wall.wav",
		"zombiehazard/knives/strong/knife_miss.wav",
		"zombiehazard/knives/strong/knife_hit2.wav"
	},
	{
		"zombiehazard/knives/katana/knife_draw.wav",
		"zombiehazard/knives/katana/knife_slash1.wav",
		"zombiehazard/knives/katana/knife_slash1.wav",
		"zombiehazard/knives/katana/knife_wall.wav",
		"zombiehazard/knives/katana/knife_miss.wav",
		"zombiehazard/knives/katana/knife_hit.wav"
	},
	{
		"zombiehazard/knives/kyvald/knife_draw.wav",
		"zombiehazard/knives/kyvald/knife_slash1.wav",
		"zombiehazard/knives/kyvald/knife_slash1.wav",
		"zombiehazard/knives/kyvald/knife_slash1.wav",
		"zombiehazard/knives/kyvald/knife_miss.wav",
		"zombiehazard/knives/kyvald/knife_hit.wav"
	}
}

enum _:eKnifeType
{
	KnifeRazor = 0,
	KnifeCombat = 1,
	KnifeStrong = 3,
	KnifeKatana = 2,
	KnifeHammer = 4,
	NOKnife = 5
}

new cvar_Razor_speed, cvar_Razor_grav, cvar_Razor_dmgmult,
cvar_Combat_speed, cvar_Combat_grav, cvar_Combat_dmgmult,
cvar_Katana_speed, cvar_Katana_grav, cvar_Katana_dmgmult,
cvar_Strong_speed, cvar_Strong_grav, cvar_Strong_dmgmult,
cvar_Hammer_speed, cvar_Hammer_grav, cvar_Hammer_dmgmult

new cvar_humangrav

new g_canchooseknife[33]

new g_knifetype[33]

new g_knivesspeed[5]
new Float:g_knivesgrav[5]
new Float:g_knivesdamage[5]

new Float:g_humangrav

public plugin_init()
{
	register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
	
	register_event("HLTV", "event_round_start", "a", "1=0", "2=0")
	register_event("CurWeapon", "Event_Curweapon", "be", "1=1")
	register_clcmd("zp_enterknivesmenu", "Knifes_Menu")
	
	register_forward(FM_EmitSound, "CEntity__EmitSound")
	
	cvar_Razor_speed = register_cvar("zp_Razorknife_speed", "255.0")
	cvar_Razor_grav = register_cvar("zp_Razorknife_grav", "0.95")
	cvar_Razor_dmgmult = register_cvar("zp_Razorknife_dmgmult", "2.0")
	
	cvar_Combat_speed = register_cvar("zp_Combatknife_speed", "250.0")
	cvar_Combat_grav = register_cvar("zp_Combatknife_grav", "0.90")
	cvar_Combat_dmgmult = register_cvar("zp_Combatknife_dmgmult", "2.0")
	
	cvar_Katana_speed = register_cvar("zp_Katanaknife_speed", "250.0")
	cvar_Katana_grav = register_cvar("zp_Katanaknife_grav", "0.95")
	cvar_Katana_dmgmult = register_cvar("zp_Katanaknife_dmgmult", "4.0")
	
	cvar_Strong_speed = register_cvar("zp_Strongknife_speed", "255.0")
	cvar_Strong_grav = register_cvar("zp_Strongknife_grav", "0.90")
	cvar_Strong_dmgmult = register_cvar("zp_Strongknife_dmgmult", "3.0")
	
	cvar_Hammer_speed = register_cvar("zp_Hammerknife_speed", "260.0")
	cvar_Hammer_grav = register_cvar("zp_Hammerknife_grav", "0.85")
	cvar_Hammer_dmgmult = register_cvar("zp_Hammerknife_dmgmult", "4.0")
	
	cvar_humangrav = get_cvar_pointer("zp_human_gravity");
	
	cache_cvars()
}

public plugin_precache()
{
	precache_model(KNIFE1_V_MODEL)
	precache_model(KNIFE1_P_MODEL)
	precache_model(KNIFE2_V_MODEL)
	precache_model(KNIFE2_P_MODEL)
	precache_model(KNIFE3_V_MODEL)
	precache_model(KNIFE3_P_MODEL)
	precache_model(KNIFE4_V_MODEL)
	precache_model(KNIFE4_P_MODEL)
	precache_model(KNIFE5_V_MODEL)
	precache_model(KNIFE5_P_MODEL)
	
	new i = 0, j = 0;
	for (i = 0; i < sizeof(knife_sounds); i++)
	{
		for (j = 0; j < OneKnifeSoundsSize; j++)
		{
			precache_sound(knife_sounds[i][j])
		}
	}
}

public plugin_cfg()
{
	// Execute config file (zombieplague.cfg)
	server_cmd("exec addons/amxmodx/configs/zombiehazard.cfg")
}

public cache_cvars()
{
	g_knivesspeed[0] = get_pcvar_num(cvar_Razor_speed);
	g_knivesspeed[1] = get_pcvar_num(cvar_Combat_speed);
	g_knivesspeed[2] = get_pcvar_num(cvar_Strong_speed);
	g_knivesspeed[3] = get_pcvar_num(cvar_Katana_speed);
	g_knivesspeed[4] = get_pcvar_num(cvar_Hammer_speed);
	
	g_knivesgrav[0] = get_pcvar_float(cvar_Razor_grav);
	g_knivesgrav[1] = get_pcvar_float(cvar_Combat_grav);
	g_knivesgrav[2] = get_pcvar_float(cvar_Strong_grav);
	g_knivesgrav[3] = get_pcvar_float(cvar_Katana_grav);
	g_knivesgrav[4] = get_pcvar_float(cvar_Hammer_grav);
	
	g_knivesdamage[0] = get_pcvar_float(cvar_Razor_dmgmult);
	g_knivesdamage[1] = get_pcvar_float(cvar_Combat_dmgmult);
	g_knivesdamage[2] = get_pcvar_float(cvar_Strong_dmgmult);
	g_knivesdamage[3] = get_pcvar_float(cvar_Katana_dmgmult);
	g_knivesdamage[4] = get_pcvar_float(cvar_Hammer_dmgmult);
	
	if (cvar_humangrav)
		g_humangrav = get_pcvar_float(cvar_humangrav);
	else
		g_humangrav = 1.0;
}

public event_round_start()
{
	arrayset(g_canchooseknife, true, 33);
}

public client_connect(id)
{
	if (get_user_flags(id) & ADMIN_LEVEL_H)
		g_knifetype[id] = KnifeHammer;
	else
		g_knifetype[id] = KnifeRazor;
	g_canchooseknife[id] = true;
}

public client_disconnect(id)
{
	g_knifetype[id] = NOKnife;
	g_canchooseknife[id] = false;
}

public Knifes_Menu(id)
{
	if (g_canchooseknife[id])
	{
		new menu = menu_create("Меню ножей: ", "menu_keys")
		
		menu_additem(menu, "\wРазор  \yСкорость+", "1", 0);
		menu_additem(menu, "\wКомбат \yГравитация-", "2", 0);
		menu_additem(menu, "\wСтронг  \yУрон+", "3", 0);
		if (zp_get_user_vip(id))
			menu_additem(menu, "\r[VIP] \wКатана  \rВсе статы+", "4", 0);
		else
			menu_additem(menu, "\d[VIP] Катана  Все статы+", "4", 0);
		if (get_user_flags(id) & ADMIN_LEVEL_C)
			menu_additem(menu, "\r[ADM] \wКувалда  \rВсе статы++", "5", 0);
		else
			menu_additem(menu, "\d[ADM] Кувалда  Все статы++", "5", 0);
		
		menu_display( id, menu, 0 );
	}
	else
	{
		new menu = menu_create("Вы уже выбрали нож: ", "menu_keys")
		
		menu_additem(menu, "\dРазор  \yСкорость+", "1", 0);
		menu_additem(menu, "\dКомбат  \yГравитация-", "2", 0);
		menu_additem(menu, "\dСтронг  \yУрон+", "3", 0);
		if (zp_get_user_vip(id))
			menu_additem(menu, "\y[VIP] \dwКатана  \yВсе статы+", "4", 0);
		else
			menu_additem(menu, "\d[VIP] Катана  Все статы+", "4", 0);
		if (get_user_flags(id) & ADMIN_LEVEL_C)
			menu_additem(menu, "\y[ADM] \dКувалда  \yВсе статы++", "5", 0);
		else
			menu_additem(menu, "\d[ADM] Кувалда  Все статы++", "5", 0);
		
		menu_display( id, menu, 0 );
	}
	return PLUGIN_HANDLED 
}

public zp_user_humanized_post(id, survivor)
{
	g_canchooseknife[id] = true;
}

public menu_keys(id, menu, item)
{
	if(item < 0 || !g_canchooseknife[id]) 
		return PLUGIN_CONTINUE
	
	new cmd[2];
	new access, callback;
	menu_item_getinfo(menu, item, access, cmd,2,_,_, callback);
	new choice = str_to_num(cmd)
	
	if (zp_get_user_zombie(id))
		return PLUGIN_HANDLED;
	switch (choice)
	{
		case 1:  buy_knife(id, KnifeRazor);
		case 2:  buy_knife(id, KnifeCombat);
		case 3:  buy_knife(id, KnifeKatana);
		case 4: 
		{
			if (zp_get_user_vip(id))
				buy_knife(id, KnifeStrong);
		}
		case 5: 
		{
			if (get_user_flags(id) & ADMIN_LEVEL_C)
				buy_knife(id, KnifeHammer);
		}
	}
	
	return PLUGIN_HANDLED;
} 

public buy_knife(id, type)
{
	if (type == KnifeStrong && !zp_get_user_vip(id))
		return;
	if (type == KnifeHammer && !(get_user_flags(id) & ADMIN_LEVEL_C))
		return;
	if(!is_user_connected(id) || !is_user_alive(id) || zp_get_user_zombie(id) || g_knifetype[id] == NOKnife)
		return;

	g_knifetype[id] = type;
	g_canchooseknife[id] = false;
	emit_sound(id, CHAN_BODY, "items/gunpickup2.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
	
	if (get_user_weapon(id) != CSW_KNIFE)
		return;
	
	switch (g_knifetype[id])
	{
		case KnifeRazor:
		{
			set_pev(id, pev_viewmodel2, KNIFE1_V_MODEL)
			set_pev(id, pev_weaponmodel2, KNIFE1_P_MODEL)
		}
		case KnifeCombat:
		{
			set_pev(id, pev_viewmodel2, KNIFE2_V_MODEL)
			set_pev(id, pev_weaponmodel2, KNIFE2_P_MODEL)
		}
		case KnifeKatana:
		{
			set_pev(id, pev_viewmodel2, KNIFE3_V_MODEL)
			set_pev(id, pev_weaponmodel2, KNIFE3_P_MODEL)
		}
		case KnifeStrong:
		{
			set_pev(id, pev_viewmodel2, KNIFE4_V_MODEL)
			set_pev(id, pev_weaponmodel2, KNIFE4_P_MODEL)
		}
		case KnifeHammer:
		{
			set_pev(id, pev_viewmodel2, KNIFE5_V_MODEL)
			set_pev(id, pev_weaponmodel2, KNIFE5_P_MODEL)
		}
	}
	Event_Curweapon(id)
}

public Event_Curweapon(id)
{
	if (!is_user_connected(id)) 
		return;
	if(!is_user_alive(id) || zp_get_user_zombie(id) || get_user_weapon(id) != CSW_KNIFE || g_knifetype[id] == NOKnife)
	{
		zp_set_player_speed(id, -1);
		if (is_user_alive(id) && !zp_get_user_zombie(id) && get_user_weapon(id) != CSW_KNIFE)
			set_pev(id, pev_gravity, g_humangrav);
		ExecuteHamB(Ham_Player_ResetMaxSpeed, id)
		return;
	}
	cache_cvars()
	switch (g_knifetype[id])
	{
		case KnifeRazor:
		{
			set_pev(id, pev_viewmodel2, KNIFE1_V_MODEL)
			set_pev(id, pev_weaponmodel2, KNIFE1_P_MODEL)
		}
		case KnifeCombat:
		{
			set_pev(id, pev_viewmodel2, KNIFE2_V_MODEL)
			set_pev(id, pev_weaponmodel2, KNIFE2_P_MODEL)
		}
		case KnifeKatana:
		{
			set_pev(id, pev_viewmodel2, KNIFE3_V_MODEL)
			set_pev(id, pev_weaponmodel2, KNIFE3_P_MODEL)
		}
		case KnifeStrong:
		{
			set_pev(id, pev_viewmodel2, KNIFE4_V_MODEL)
			set_pev(id, pev_weaponmodel2, KNIFE4_P_MODEL)
		}
		case KnifeHammer:
		{
			set_pev(id, pev_viewmodel2, KNIFE5_V_MODEL)
			set_pev(id, pev_weaponmodel2, KNIFE5_P_MODEL)
		}
	}
	zp_set_player_speed(id, g_knivesspeed[g_knifetype[id]]);
	set_pev(id, pev_gravity, g_knivesgrav[g_knifetype[id]]);
	ExecuteHamB(Ham_Player_ResetMaxSpeed, id)
	return;
}

public CEntity__EmitSound(id, channel, const sample[], Float:volume, Float:attn, flags, pitch)
{
	if (!is_user_connected(id)) 
		return HAM_IGNORED
	
	if(!is_user_alive(id) || zp_get_user_zombie(id))
		return HAM_IGNORED
	
	new knifetype = g_knifetype[id];
	if (knifetype == NOKnife)
		return HAM_IGNORED
	if (sample[8] == 'k' && sample[9] == 'n' && sample[10] == 'i')
	{	
		if (sample[14] == 'd') 
		{
			emit_sound(id, channel, knife_sounds[knifetype][0], volume, attn, flags, pitch)
		}
		else if (sample[14] == 'h')
		{
			if (sample[17] == 'w') 
			{
				emit_sound(id, channel, knife_sounds[knifetype][3], volume, attn, flags, pitch)
			}
			else
			{
				emit_sound(id, channel, knife_sounds[knifetype][random_num(1,2)], volume, attn, flags, pitch)
			}
		}
		else
		{
			if (sample[15] == 'l') 
			{
				emit_sound(id, channel, knife_sounds[knifetype][4], volume, attn, flags, pitch)
			}
			else 
			{
				emit_sound(id, channel, knife_sounds[knifetype][5], volume, attn, flags, pitch)
			}
		}
		return HAM_SUPERCEDE
	}
	return HAM_IGNORED
}

public zp_ondamagemade(victim, inflictor, attacker, damage_type)
{
	if(!is_user_connected(attacker))
		return HAM_IGNORED
	if(!is_user_alive(attacker) || zp_get_user_zombie(attacker))
		return HAM_IGNORED
	
	new temp[2]
	new knifetype = g_knifetype[attacker];
	if (knifetype == NOKnife)
		return HAM_IGNORED
	new weapon = get_user_weapon(attacker, temp[0], temp[1])
	if(weapon == CSW_KNIFE && (damage_type & DMG_NEVERGIB || damage_type & DMG_SLASH || damage_type & DMG_CLUB || damage_type & DMG_ALWAYSGIB))
	{
		new Float:damage = zp_get_upcoming_damage(attacker) * g_knivesdamage[knifetype];
		zp_set_upcoming_damage(attacker, damage)
		SetHamParamFloat(4, damage)
	}
	return HAM_IGNORED
}
