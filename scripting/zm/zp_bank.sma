#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <sqlx>
#include <zombieplague>
#include <colorchat>

#pragma semicolon 1

#if !defined MAX_PLAYERS
	#define MAX_PLAYERS 32
#endif

new PLUGIN_NAME[] = "[ZP]Addons: Bank SQL";
new PLUGIN_VERSION[] = "0.9.2";
new PLUGIN_AUTHOR[] = "Epmak";
new PLUGIN_PREFIX[] = "[ZP][Bank]";

enum vars_struct { 
	mode=0,
	annonce,
	
	save_limit,
	save_days,
	save_type,
	
	block_cname,
	startedammo,
	allow_passwd,
	allow_donate,
	
	bool:round_end,
	
	_pw_str[32],
	table[32],
	config_dir[128]
};

enum bank_struct {
	bool:ingame,
	bool:async,
	bool:loggin,
	auth[36],
	passwd[32],
	amount
}

new g_vars[vars_struct];
new g_Bank[MAX_PLAYERS+1][bank_struct];
new Handle:g_Sql = Empty_Handle,Handle:g_SqlTuple = Empty_Handle;

public plugin_init()
{
	register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);
	register_cvar("zp_bank_sql", PLUGIN_VERSION, FCVAR_SERVER);
	
	register_dictionary("zp_bank.txt");
	register_dictionary("common.txt");
	
	register_clcmd("say", "handle_say");
	register_clcmd("say_team", "handle_say");
	
	register_concmd("zp_bank_show", "cmdBankShow", ADMIN_ADMIN);
	register_concmd("zp_bank_set", "cmdBankSet", ADMIN_RCON, "<name or #userid> <+ or ->amount");
	
	g_vars[startedammo] = get_cvar_pointer("zp_starting_ammo_packs");
	
	register_srvcmd("zp_bank_connect", "db_connect");
	
	register_forward(FM_ClientUserInfoChanged, "fwClientUserInfoChanged");
	
	server_cmd("zp_bank_connect");
}

public plugin_precache()
{
	get_configsdir(g_vars[config_dir], 127);
	
	g_vars[mode] = register_cvar("zp_bank", "1");
	g_vars[annonce] = register_cvar("zp_bank_annonce", "360.0");
	g_vars[save_limit] = register_cvar("zp_bank_save_limit", "1000");
	g_vars[save_days] = register_cvar("zp_bank_save_days", "24");
	g_vars[save_type] = register_cvar("zp_bank_save_type", "2");
	g_vars[block_cname] = register_cvar("zp_bank_block_name_change", "1");
	g_vars[allow_passwd] = register_cvar("zp_bank_allow_passwd", "1");
	g_vars[allow_donate] = register_cvar("zp_bank_allow_donate", "1");
	
	register_cvar("zp_bank_host", "127.0.0.1");
	register_cvar("zp_bank_user", "root");
	register_cvar("zp_bank_pass", "");
	register_cvar("zp_bank_db", "amxx");
	register_cvar("zp_bank_type", "mysql");
	register_cvar("zp_bank_table", "zp_bank");
	register_cvar("zp_bank_pw_str", "_bpw");
	
	server_cmd("exec %s/zp_bank.cfg", g_vars[config_dir]);
	server_exec();
}

public plugin_cfg()
{
	g_vars[mode] = get_pcvar_num(g_vars[mode]);
	g_vars[save_limit] = get_pcvar_num(g_vars[save_limit]);
	g_vars[save_days] = get_pcvar_num(g_vars[save_days]);
	g_vars[save_type] = get_pcvar_num(g_vars[save_type]);
	g_vars[block_cname] = get_pcvar_num(g_vars[block_cname]);
	g_vars[allow_passwd] = get_pcvar_num(g_vars[allow_passwd]);
	g_vars[allow_donate] = get_pcvar_num(g_vars[allow_donate]);
	
	if(g_vars[save_limit] < 0) g_vars[save_limit] = 0;
	
	if(get_pcvar_num(g_vars[annonce]))
		set_task(get_pcvar_float(g_vars[annonce]), "print_annonce",_,_,_,"b");
	
	get_cvar_string("zp_bank_pw_str", g_vars[_pw_str], 31);
} 

public plugin_end()
{
	if(g_Sql != Empty_Handle) SQL_FreeHandle(g_Sql);
	if(g_SqlTuple != Empty_Handle) SQL_FreeHandle(g_SqlTuple);
}

public zp_round_started(gamemode, id)
{
	g_vars[round_end] = false;
}

public zp_round_ended(winteam)
{
	if (!g_vars[mode] || g_Sql == Empty_Handle)
		return ;
	
	static i;
	for(i=1;i<=MAX_PLAYERS;i++)
	{
		if(!g_Bank[i][ingame] || !g_Bank[i][loggin] || !g_Bank[i][async])
			continue;
		
		SaveClientBank(i);
	}
	
	g_vars[round_end] = true;
}

public client_connect(id)
{
	if (!g_vars[mode])
		return ;
	
	GetAuthId(id, g_Bank[id][auth],35);
	
	g_Bank[id][amount] = 0;
	g_Bank[id][async] = false;
	g_Bank[id][loggin] = false;
	
	if(g_vars[mode] == 2)
		zp_set_user_ammo_packs(id, get_pcvar_num(g_vars[startedammo]));
	
	LoadClientBank(id);
}

public client_putinserver(id)
{
	g_Bank[id][ingame] = true;
	
	if(g_Bank[id][async] == true && g_Bank[id][loggin] == true)
		SetAmmoBank(id, g_Bank[id][amount]);
}

public client_disconnect(id)
{
	if (!g_vars[mode] || g_Sql == Empty_Handle)
		return ;
	
	if(g_vars[round_end] == false && g_Bank[id][async] == true && g_Bank[id][loggin] == true)
		SaveClientBank(id);
	
	g_Bank[id][ingame] = false;
	g_Bank[id][auth][0] = '^0';
	g_Bank[id][passwd][0] = '^0';
}

public cmdBankShow(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;
	
	static pl_name[32], pl_amount[11], i;
	console_print(id, "%33s amount","name");
	for(i=1;i<=MAX_PLAYERS;i++)
	{
		if(!g_Bank[i][ingame]) continue;
		
		get_user_name(i,pl_name,31);
		
		if(!g_Bank[i][async])
			pl_amount = "not loaded";
		else if(!g_Bank[i][loggin])
			pl_amount = "not loggin";
		else
			num_to_str(GetAmmoBank(i),pl_amount,10);
		
		console_print(id, "%33s %s", pl_name, pl_amount);
	}
	
	return PLUGIN_HANDLED;
}

public cmdBankSet(id, level, cid)
{
	if (!cmd_access(id, level, cid, 3))
		return PLUGIN_HANDLED;
	
	static s_player[32], player, s_amount[12], i_amount;
	read_argv(1, s_player, 31);
	player = cmd_target(id, s_player, CMDTARGET_ALLOW_SELF);
	
	if (!player)
		return PLUGIN_HANDLED;
	
	get_user_name(player,s_player,31);
	if(!g_Bank[player][async])
	{
		console_print(id,"The player '%s' has not loaded bank", s_player);
		return PLUGIN_HANDLED;
	}
	else if(!g_Bank[player][loggin])
	{
		console_print(id,"The player '%s' has not loggin bank", s_player);
		return PLUGIN_HANDLED;
	}
	
	read_argv(2, s_amount, 11);
	remove_quotes(s_amount);
	i_amount = str_to_num(s_amount);
	
	switch(s_amount[0])
	{
		case '+':
			SetAmmoBank(player, GetAmmoBank(player)+i_amount);
		case '-':
			SetAmmoBank(player, GetAmmoBank(player)-(0-i_amount));
		default:
			SetAmmoBank(player,i_amount);
	}
	
	return PLUGIN_HANDLED;
}

public print_annonce()
{
	if (!g_vars[mode] || g_Sql == Empty_Handle)
		return ;
	
	ColorChat(0, CHATCOLOR_GREY, "%L", LANG_PLAYER, "BANK_ANNOUNCE1");
	if(g_vars[mode] == 1)
	{
		ColorChat(0, CHATCOLOR_GREY, "%L", LANG_PLAYER, "BANK_ANNOUNCE2");
		ColorChat(0, CHATCOLOR_GREY, "%L", LANG_PLAYER, "BANK_ANNOUNCE3");
	}
	else
	{
		ColorChat(0, CHATCOLOR_GREY, "%L", LANG_PLAYER, "BANK_ANNOUNCE4");
	}
}

public db_loadcurrent()
{
	for(new i=1;i<=MAX_PLAYERS;i++)
	{
		if(g_Bank[i][async] || !g_Bank[i][ingame]) continue;
		
		LoadClientBank(i);
	}
}

public db_connect(count)
{
	if(!g_vars[mode])
		return ;
	
	new host[64], user[32], pass[32], db[128];
	new get_type[13], set_type[12];
	new error[128], errno;
	
	get_cvar_string("zp_bank_host", host, 63);
	get_cvar_string("zp_bank_user", user, 31);
	get_cvar_string("zp_bank_pass", pass, 31);
	get_cvar_string("zp_bank_type", set_type, 11);
	get_cvar_string("zp_bank_db", db, 127);
	get_cvar_string("zp_bank_table", g_vars[table], 31);
	
	if(is_module_loaded(set_type) == -1)
	{
		server_print("^r^n%s error: module '%s' not loaded.^r^n%s Add line %s to %s/modules.ini and restart server^r^n", PLUGIN_PREFIX, set_type, PLUGIN_PREFIX, set_type, g_vars[config_dir]);
		return ;
	}
	
	SQL_GetAffinity(get_type, 12);
	
	if (!equali(get_type, set_type))
		if (!SQL_SetAffinity(set_type))
			log_amx("Failed to set affinity from %s to %s.", get_type, set_type);
	
	g_SqlTuple = SQL_MakeDbTuple(host, user, pass, db);
	
	g_Sql = SQL_Connect(g_SqlTuple, errno, error, 127);
	
	if (g_Sql == Empty_Handle)
	{
		server_print("%s SQL Error #%d - %s", PLUGIN_PREFIX, errno, error);
		
		count += 1;
		set_task(10.0, "db_connect", count);
		
		return ;
	}
	
	SQL_QueryAndIgnore(g_Sql, "SET NAMES utf8");
	
	if (equali(set_type, "sqlite") && !sqlite_TableExists(g_Sql, g_vars[table]))
		SQL_QueryAndIgnore(g_Sql, "CREATE TABLE %s (auth VARCHAR(36) PRIMARY KEY, password VARCHAR(32) NOT NULL DEFAULT '', amount INTEGER DEFAULT 0, timestamp INTEGER NOT NULL DEFAULT 0)",g_vars[table]);
	else if (equali(set_type, "mysql"))
		SQL_QueryAndIgnore(g_Sql,"CREATE TABLE IF NOT EXISTS `%s` (`auth` VARCHAR(36) NOT NULL, `password` VARCHAR(32) NOT NULL DEFAULT '', `amount` INT(10) NOT NULL DEFAULT 0, `timestamp` INT(10) NOT NULL DEFAULT 0, PRIMARY KEY (`auth`) ) ENGINE=MyISAM DEFAULT CHARSET=utf8;", g_vars[table]);
	
//	CleanDataBase();
	if(count > 1)
		db_loadcurrent();
	
	server_print("%s connected to: '%s://%s:****@%s/%s/%s'",PLUGIN_PREFIX, set_type, user, host, db, g_vars[table]);
}

public CleanDataBase()
{
	if (!g_vars[save_days]) return ;
	
	new curTime = get_systime();
	curTime -= ((g_vars[save_days] * 24) * 3600);
	
	SQL_QueryAndIgnore(g_Sql,"DELETE FROM %s WHERE timestamp < '%d';", g_vars[table], curTime);
}

public fwClientUserInfoChanged(id, buffer)
{
	if (!g_vars[mode] || !is_user_connected(id))
		return FMRES_IGNORED;
	
	new name[32], val[32], name_1[] = "name";
	get_user_name(id, name, 31);
	engfunc(EngFunc_InfoKeyValue, buffer, name_1, val, 31);
	if (equal(val, name))
		return FMRES_IGNORED;
	
	if(g_vars[block_cname])
	{
		engfunc(EngFunc_SetClientKeyValue, id, buffer, name_1, name);
		client_cmd(id, "name ^"%s^"; setinfo name ^"%s^"", name, name);
		console_print(id, "%L", id ,"NO_NAME_CHANGE");
	}
	else
	{
		GetAuthId(id,g_Bank[id][auth],35);
		return FMRES_IGNORED;
	}
 
	return FMRES_SUPERCEDE;
}

public handle_say(id)
{
	if(!g_vars[mode])
	{
		ColorChat(id, CHATCOLOR_GREY, "$g%s$t %L", PLUGIN_PREFIX, LANG_PLAYER, "BANK_DISABLED");
		
		return PLUGIN_CONTINUE;
	}
	else if(g_Sql == Empty_Handle)
	{
		ColorChat(id, CHATCOLOR_GREY, "$g%s$t %L", PLUGIN_PREFIX, LANG_PLAYER, "BANK_ERR");
		
		return PLUGIN_CONTINUE;
	}
	else if (!g_Bank[id][async])
		return PLUGIN_CONTINUE;
	
	new text[60], command[16], command2[32], password[32], set_packs;
	read_args(text, 59);
	remove_quotes(text);
	
	command[0] = '^0';
	command2[0] = '^0';
	password[0] = '^0';
	parse(text, command, 15, command2, 31, password, 31);
	
	if (equali(command, "/", 1))
		format(command, 15, command[1]);
	
	if (g_vars[allow_donate] && equali(command, "donate", 6))
	{
		donate(id, command2, str_to_num(password));
	}
	else if (equali(command, "mybank", 6) || equali(command, "bank", 4))
	{
		if(g_vars[save_type] == 2 && g_vars[allow_passwd])
		{
			if(equali(command2, "login", 5))
			{
				if(g_Bank[id][loggin]) {
					ColorChat(id, CHATCOLOR_GREY, "$g%s$t %L", PLUGIN_PREFIX, LANG_PLAYER, "BANK_LOGIN_ALREADY");
					return PLUGIN_HANDLED;
				}
				
				if(g_Bank[id][passwd][0] && equal(password, g_Bank[id][passwd]))
				{
					g_Bank[id][loggin] = true;
					SetAmmoBank(id, g_Bank[id][amount]);
					client_cmd(id, "setinfo %s ^"%s^"", g_vars[_pw_str], password);
					ColorChat(id, CHATCOLOR_GREY, "$g%s$t %L", PLUGIN_PREFIX, LANG_PLAYER, "BANK_LOGIN_SUCCESS");
				}
				else
				{
					ColorChat(id, CHATCOLOR_GREY, "$g%s$t %L", PLUGIN_PREFIX, LANG_PLAYER, "BANK_LOGIN_BAD");
				}
				
				return PLUGIN_HANDLED;
			}
			else if(!g_Bank[id][loggin])
			{
				ColorChat(id, CHATCOLOR_GREY, "$g%s$t %L", PLUGIN_PREFIX, LANG_PLAYER, "BANK_LOGIN");
				return PLUGIN_HANDLED;
			}
			else if(equali(command2, "password", 8))
			{
				if(password[0])
				{
					g_Bank[id][passwd] = password;
					client_cmd(id, "setinfo %s ^"%s^"", g_vars[_pw_str], password);
					ColorChat(id, CHATCOLOR_GREY, "$g%s$t %L", PLUGIN_PREFIX, LANG_PLAYER, "BANK_LOGIN_PASSWORD_SET", g_Bank[id][passwd]);
				}
				else
				{
					ColorChat(id, CHATCOLOR_GREY, "$g%s$t %L", PLUGIN_PREFIX, LANG_PLAYER, "BANK_LOGIN_PASSWORD", g_Bank[id][passwd]);
				}
				return PLUGIN_HANDLED;
			}
			else if(!g_Bank[id][passwd][0])
				ColorChat(id, CHATCOLOR_GREY, "$g%s$t %L", PLUGIN_PREFIX, LANG_PLAYER, "BANK_LOGIN_PASSWORD_SETHELP");
		}
		
		if(g_vars[mode] == 2)
		{
			ColorChat(id, CHATCOLOR_GREY, "%L", LANG_PLAYER, "BANK_ANNOUNCE4");
			return PLUGIN_CONTINUE;
		}
		
		ColorChat(id, CHATCOLOR_GREY, "$g%s$t %L", PLUGIN_PREFIX, LANG_PLAYER, "BANK", g_Bank[id][amount]);	
		ColorChat(id, CHATCOLOR_GREY, "$g%s$t %L", PLUGIN_PREFIX, LANG_PLAYER, "BANK_ANNOUNCE2");
		ColorChat(id, CHATCOLOR_GREY, "$g%s$t %L", PLUGIN_PREFIX, LANG_PLAYER, "BANK_ANNOUNCE3");
	}
	else if (g_vars[mode] == 2)
		return PLUGIN_CONTINUE;
	else if (equali(command, "deposit", 7) || equali(command, "send", 4) || equali(command, "store", 5))
	{
		new user_ammo_packs = zp_get_user_ammo_packs(id);
		
		if (equali(command2, "all")) set_packs = user_ammo_packs;
		else set_packs = str_to_num(command2);
		
		new limit_exceeded=false;
		
		if (g_vars[save_limit] && set_packs > 0 && g_Bank[id][amount] + set_packs > g_vars[save_limit])
		{
			new overflow = g_Bank[id][amount] + set_packs - g_vars[save_limit];
			set_packs -= overflow;
			
			ColorChat(id, CHATCOLOR_GREY, "$g%s$t %L", PLUGIN_PREFIX, LANG_PLAYER, "DEPOSIT_MAX", g_vars[save_limit]);
			
			limit_exceeded = true;
		}
		
		if (set_packs > 0)
		{
			if (user_ammo_packs >= set_packs)
			{
				g_Bank[id][amount] += set_packs;
				zp_set_user_ammo_packs(id, user_ammo_packs - set_packs);
				ColorChat(id, CHATCOLOR_GREY, "$g%s$t %L", PLUGIN_PREFIX, LANG_PLAYER, "DEPOSIT", set_packs, g_Bank[id][amount]);
			}
			else
				ColorChat(id, CHATCOLOR_GREY, "$g%s$t %L", PLUGIN_PREFIX, LANG_PLAYER, "DEPOSIT_ERR", set_packs, user_ammo_packs);
			
			return PLUGIN_HANDLED;
		}
		else if(!limit_exceeded)
			ColorChat(id, CHATCOLOR_GREY, "$g%s$t %L", PLUGIN_PREFIX, LANG_PLAYER, "BANK_ANNOUNCE2");
	}
	else if (equali(command, "withdraw", 8) || equali(command, "take", 4) || equali(command, "retrieve", 8) || equali(command, "wd", 2))
	{
		new user_ammo_packs = zp_get_user_ammo_packs(id);
		
		if (equali(command2, "all")) set_packs = g_Bank[id][amount];
		else set_packs = str_to_num(command2);
		
		if (set_packs > 0)
		{
			if (g_Bank[id][amount] >= set_packs)
			{
				zp_set_user_ammo_packs(id, user_ammo_packs + set_packs);
				g_Bank[id][amount] -= set_packs;
				ColorChat(id, CHATCOLOR_GREY, "$g%s$t %L", PLUGIN_PREFIX, LANG_PLAYER, "WITHDRAW", set_packs, g_Bank[id][amount]);
			}
			else
				ColorChat(id, CHATCOLOR_GREY, "$g%s$t %L", PLUGIN_PREFIX, LANG_PLAYER, "WITHDRAW_ERR", set_packs, g_Bank[id][amount]);
			
			return PLUGIN_HANDLED;
		}
		else
			ColorChat(id, CHATCOLOR_GREY, "$g%s$t %L", PLUGIN_PREFIX, LANG_PLAYER, "BANK_ANNOUNCE3");
	}
	
	return PLUGIN_CONTINUE;
}

public donate(donater, const reciever_name[], ammo)
{
	if(!reciever_name[0] || ammo <= 0 || zp_get_user_ammo_packs(donater) < ammo)
	{
		ColorChat(donater, CHATCOLOR_GREY, "$g%s$t %L", PLUGIN_PREFIX, LANG_PLAYER, "BANK_DONATE_USAGE");
		return ;
	}
	
	new reciever = cmd_target(donater, reciever_name, CMDTARGET_ALLOW_SELF);
	if (!reciever || reciever == donater)
	{
		ColorChat(donater, CHATCOLOR_GREY, "$g%s$t %L", PLUGIN_PREFIX, LANG_PLAYER, "CL_NOT_FOUND");	
		return ;
	}
	
	zp_set_user_ammo_packs(donater, zp_get_user_ammo_packs(donater)-ammo);
	zp_set_user_ammo_packs(reciever, zp_get_user_ammo_packs(reciever)+ammo);
}

public LoadClientBank(id)
{
	if (g_SqlTuple == Empty_Handle || g_Sql == Empty_Handle || g_Bank[id][async] == true)
		return ;
	
	new szQuery[120];
	format(szQuery, 119,"SELECT amount,password FROM %s WHERE auth='%s';", g_vars[table], g_Bank[id][auth]);
	
	new szData[2];
	szData[0] = id;
	szData[1] = get_user_userid(id);
	
	SQL_ThreadQuery(g_SqlTuple, "LoadClient_QueryHandler", szQuery, szData, 2);
}

public LoadClient_QueryHandler(iFailState, Handle:hQuery, szError[], iErrnum, szData[], iSize, Float:fQueueTime)
{
	if(iFailState != TQUERY_SUCCESS)
	{
		log_amx("%s SQL Error #%d - %s", PLUGIN_PREFIX, iErrnum, szError);
		return ;
	}
	
	new id = szData[0];
	
	if (szData[1] != get_user_userid(id))
		return ;
	
	new packs=0,info_pw[32];
	
	if(g_vars[mode] == 2)
		packs = get_pcvar_num(g_vars[startedammo]);
	
	if(SQL_NumResults(hQuery))
	{
		packs = SQL_ReadResult(hQuery, SQL_FieldNameToNum(hQuery, "amount"));
		SQL_ReadResult(hQuery, SQL_FieldNameToNum(hQuery, "password"), g_Bank[id][passwd], 31);
	}
	
	g_Bank[id][amount] = CheckLimit(packs);
	if(g_vars[allow_passwd] && g_Bank[id][passwd][0])
	{
		get_user_info(id,g_vars[_pw_str],info_pw,31);
		if(equal(info_pw, g_Bank[id][passwd]))
		{
			g_Bank[id][loggin] = true;
		}
	}
	else
		g_Bank[id][loggin] = true;
	
	if(g_Bank[id][ingame] == true && g_Bank[id][loggin] == true)
	{
		SetAmmoBank(id, g_Bank[id][amount]);
	}
	g_Bank[id][async] = true;
}

public SaveClientBank(id)
{
	if (g_Sql == Empty_Handle)
		return ;
	
	new packs = GetAmmoBank(id);
	packs = CheckLimit(packs);
	
	SQL_QuoteString(g_Sql, g_Bank[id][passwd], 31, g_Bank[id][passwd]);
	SQL_QueryAndIgnore(g_Sql, "REPLACE INTO %s (auth,password,amount,timestamp) VALUES('%s', '%s', %d, %d);", g_vars[table], g_Bank[id][auth], g_Bank[id][passwd], packs, get_systime());
}

stock GetAuthId(id, Buffer[]="", BufferSize=0)
{
	switch(g_vars[save_type])
	{
		case 1: get_user_authid(id,Buffer,BufferSize);
		case 2:
		{
			new name[32];
			get_user_name(id,name,31);
			SQL_QuoteString(g_Sql, Buffer, BufferSize, name);
		}
		case 3: get_user_ip(id,Buffer,BufferSize,true);
	}
}

public CheckLimit(packs)
{
	if(g_vars[save_limit] && packs > g_vars[save_limit])
	{
		packs = g_vars[save_limit];
	}
	return packs;
}

public SetAmmoBank(id, packs)
{
	if(g_vars[mode] == 2)
		zp_set_user_ammo_packs(id,packs);
	else
		g_Bank[id][amount] = packs;
}

public GetAmmoBank(id)
{
	if(g_vars[mode] == 2)
		return zp_get_user_ammo_packs(id);
	
	return g_Bank[id][amount];
}
