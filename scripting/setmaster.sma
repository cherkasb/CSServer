#include <amxmodx>
#include <amxmisc>

#define TASK_UPDATE		4096
//Задержка между командами
#define DELAY			10.0

new bool:enabled = false, Masters[128][64], Count = 0, pcvar_repeat
new counter_add, counter_remove

public plugin_init()
{
	register_plugin("Automatic master servers register", "2.2", "Puma")
	pcvar_repeat = register_cvar("sm_repeat", "1")
	set_task(10.0, "delay_load")
}

public plugin_end()
	if(enabled)
		setmaster_removeall()

public delay_load()
{
	new configsdir[200], SetMasterFile[200], Result
	new fSize, temp
	
	get_configsdir(configsdir,199)
	format(SetMasterFile,199,"%s/setmaster.ini",configsdir)
	if(!file_exists(SetMasterFile)) 
	{
		server_print("Error: Coudn't find %s", SetMasterFile)
		return PLUGIN_HANDLED
	}
	fSize = file_size(SetMasterFile,1);
	if(!fSize)
	{
		server_print("Error: %s is empty", SetMasterFile)
		return PLUGIN_HANDLED
	}
	for(new i=0; i < fSize; i++)
	{
		Result = read_file(SetMasterFile, i, Masters[i], 63, temp) 
		if(!Result)
			continue
		
		replace_all(Masters[i], 190, "setmaster add", "")
		replace_all(Masters[i], 190, "setmaster remove", "")
		Count++
	}
	server_print("setmaster.ini loaded (%d)", Count)
	enabled = true
	if(enabled)
	{
		counter_add = 0
		set_task(0.1, "update", TASK_UPDATE+1)
	}
	
	set_task(300.0, "heartbeat", TASK_UPDATE, "", 0, "b")
	return PLUGIN_CONTINUE
}

public heartbeat()
{
	if(get_pcvar_num(pcvar_repeat) == 1)
	{
		counter_add = 0
		counter_remove = 0
		set_task(0.1, "update", TASK_UPDATE)
	}
	server_cmd("heartbeat")
}

public cmd_update(id)
{
	set_task(0.1, "update", TASK_UPDATE)
}

public update(taskid)
{
	//update part
	if(taskid == TASK_UPDATE)
	{
		if(Count > counter_remove)
		{
			server_cmd("setmaster remove %s", Masters[counter_remove])
			counter_remove++
			
			set_task(DELAY, "update", TASK_UPDATE)
		}
		else
		{
			counter_add = 0
			counter_remove = 0
			set_task(0.1, "update", TASK_UPDATE+1)
		}
	}
	//add part
	else if(taskid == TASK_UPDATE+1)
	{
		if(Count > counter_add)
		{
			server_cmd("setmaster add %s", Masters[counter_add])
			counter_add++
			
			set_task(DELAY, "update", TASK_UPDATE+1)
		}
		else
		{
			counter_add = 0
			counter_remove = 0
		}
	}
}

stock setmaster_removeall()
	for(new i=0; i < Count; i++)
		server_cmd("setmaster remove %s", Masters[i])