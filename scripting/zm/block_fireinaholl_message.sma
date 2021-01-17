#include <amxmodx>

public plugin_init() {
	register_message(get_user_msgid("TextMsg"), "msg_text")
	register_message(get_user_msgid("SendAudio"), "msg_audio")
}

public msg_text()
{
	static buffer[32]
	if(get_msg_args() != 5 || get_msg_argtype(3) != ARG_STRING || get_msg_argtype(5) != ARG_STRING)
	{
		return PLUGIN_CONTINUE
	}
	get_msg_arg_string(3, buffer, 15)
	if(!equal(buffer, "#Game_radio"))
	{
		return PLUGIN_CONTINUE
	}
	get_msg_arg_string(5, buffer, 19)
	if(equal(buffer, "#Fire_in_the_hole"))
	{
		return PLUGIN_HANDLED
	}
	return PLUGIN_CONTINUE
}

public msg_audio()
{
	static buffer[32]
	if(get_msg_args() != 3 || get_msg_argtype(2) != ARG_STRING)
	{
		return PLUGIN_CONTINUE
	}
	get_msg_arg_string(2, buffer, 19)
	if(equal(buffer[1], "!MRAD_FIREINHOLE"))
	{
		return PLUGIN_HANDLED
	}
	return PLUGIN_CONTINUE
}