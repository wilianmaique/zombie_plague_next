#include <amxmodx>

#define PLUGIN "AMXX Immutable Cvars"
#define VERSION "1.1"
#define AUTHOR "Wilian M."

new const IMMUTABLE_FILE[] = "immutable_cvars.ini"

enum _:eCvars(+= 100)
{
	E_CVAR_NAME[64] = 1001,
	E_CVAR_VALUE[32],
}

new Array:aCvarsData, aGetData[eCvars], immutableCvars[128]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
}

public plugin_end()
{
	ArrayDestroy(aCvarsData)
}

public plugin_precache()
{
	aCvarsData = ArrayCreate(eCvars)
	load_file()
}

public OnConfigsExecuted()
{
	load_file()
}

public load_file()
{
	new fpath[128]; formatex(fpath, charsmax(fpath), "addons/amxmodx/configs/%s", IMMUTABLE_FILE)

	if(!file_exists(fpath))
		return

	new file = fopen(fpath, "rt")

	if(!file)
		return

	new line[256], cvarName[64], cvarValue[32]

	while(fgets(file, line, charsmax(line)))
	{
		trim(line)

		if(line[0] == EOS || !line[0] || line[0] == '#' || line[0] == ';' || line[0] == '/' && line[1] == '/')
			continue
		
		parse(line, cvarName, charsmax(cvarName), cvarValue, charsmax(cvarValue))

		copy(aGetData[E_CVAR_NAME], charsmax(aGetData[E_CVAR_NAME]), cvarName)
		copy(aGetData[E_CVAR_VALUE], charsmax(aGetData[E_CVAR_VALUE]), cvarValue)
		ArrayPushArray(aCvarsData, aGetData)
	}

	fclose(file)
	set_immutable()
}

public set_immutable()
{
	for(new i = 0; i < ArraySize(aCvarsData); i++)
	{
		ArrayGetArray(aCvarsData, i, aGetData)

		immutableCvars[i] = get_cvar_pointer(aGetData[E_CVAR_NAME])

		if(immutableCvars[i])
		{
			set_pcvar_string(immutableCvars[i], aGetData[E_CVAR_VALUE])
			hook_cvar_change(immutableCvars[i], "cvar_change")
		}
	}
}

public cvar_change(pcvar, old_value[], new_value[])
{
	for(new i = 0; i < ArraySize(aCvarsData); i++)
	{
		ArrayGetArray(aCvarsData, i, aGetData)

		if(immutableCvars[i] != pcvar)
			continue

		if(equal(new_value, aGetData[E_CVAR_VALUE]))
			continue

		set_pcvar_string(pcvar, aGetData[E_CVAR_VALUE])
		break
	}
}