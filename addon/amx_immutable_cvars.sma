#include <amxmodx>

#define PLUGIN "AMXX Immutable Cvars"
#define VERSION "1.1"
#define AUTHOR "Wilian M."

new const IMMUTABLE_FILE[] = "immutable_cvars.ini"

enum _:eCvars
{
	E_CVAR_NAME[64],
	E_CVAR_VALUE[128],
	E_CVAR_POINTER,
	E_CVAR_HOOK,
	bool:E_CVAR_HOOKED
}

new Array:aCvarsData = Invalid_Array

public plugin_natives()
{
	register_library("amx_immutable_cvars")
	register_native("amx_immutable_cvar_set", "native_cvar_set")
}

public bool:native_cvar_set(plugin_id, param_nums)
{
	if(param_nums != 2 || aCvarsData == Invalid_Array)
		return false

	new cvarName[64], cvarValue[128]
	get_string(1, cvarName, charsmax(cvarName))
	get_string(2, cvarValue, charsmax(cvarValue))
	trim(cvarName)
	if(!cvarName[0])
		return false

	new pcvar = get_cvar_pointer(cvarName)
	if(!pcvar)
		return false

	new data[eCvars], index = find_cvar(cvarName)
	if(index == -1)
	{
		copy(data[E_CVAR_NAME], charsmax(data[E_CVAR_NAME]), cvarName)
		index = ArrayPushArray(aCvarsData, data)
	}
	else
		ArrayGetArray(aCvarsData, index, data)

	copy(data[E_CVAR_VALUE], charsmax(data[E_CVAR_VALUE]), cvarValue)
	data[E_CVAR_POINTER] = pcvar
	ArraySetArray(aCvarsData, index, data)
	return apply_immutable(index)
}

public plugin_precache()
{
	aCvarsData = ArrayCreate(eCvars)
	load_file()
	set_immutable()
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
}

public OnConfigsExecuted()
{
	set_immutable()
}

public plugin_end()
{
	if(aCvarsData != Invalid_Array)
		ArrayDestroy(aCvarsData)
}

load_file()
{
	new fpath[128]
	formatex(fpath, charsmax(fpath), "addons/amxmodx/configs/%s", IMMUTABLE_FILE)
	if(!file_exists(fpath))
		return

	new file = fopen(fpath, "rt")
	if(!file)
		return

	new line[256], cvarName[64], cvarValue[128], data[eCvars], index
	while(fgets(file, line, charsmax(line)))
	{
		trim(line)
		if(!line[0] || line[0] == '#' || line[0] == ';' || (line[0] == '/' && line[1] == '/'))
			continue

		cvarName[0] = cvarValue[0] = EOS
		parse(line, cvarName, charsmax(cvarName), cvarValue, charsmax(cvarValue))
		if(!cvarName[0])
			continue

		index = find_cvar(cvarName)
		if(index == -1)
		{
			copy(data[E_CVAR_NAME], charsmax(data[E_CVAR_NAME]), cvarName)
			data[E_CVAR_POINTER] = 0
			data[E_CVAR_HOOK] = 0
			data[E_CVAR_HOOKED] = false
			index = ArrayPushArray(aCvarsData, data)
		}
		else
			ArrayGetArray(aCvarsData, index, data)

		copy(data[E_CVAR_VALUE], charsmax(data[E_CVAR_VALUE]), cvarValue)
		ArraySetArray(aCvarsData, index, data)
	}
	fclose(file)
}

find_cvar(const cvarName[])
{
	new data[eCvars]
	for(new i = 0; i < ArraySize(aCvarsData); i++)
	{
		ArrayGetArray(aCvarsData, i, data)
		if(equali(data[E_CVAR_NAME], cvarName))
			return i
	}
	return -1
}

set_immutable()
{
	for(new i = 0; i < ArraySize(aCvarsData); i++)
		apply_immutable(i)
}

bool:apply_immutable(const index)
{
	new data[eCvars]
	ArrayGetArray(aCvarsData, index, data)
	if(!data[E_CVAR_POINTER])
		data[E_CVAR_POINTER] = get_cvar_pointer(data[E_CVAR_NAME])
	if(!data[E_CVAR_POINTER])
		return false

	if(data[E_CVAR_HOOKED])
		disable_cvar_hook(cvarhook:data[E_CVAR_HOOK])
	set_pcvar_string(data[E_CVAR_POINTER], data[E_CVAR_VALUE])
	if(data[E_CVAR_HOOKED])
		enable_cvar_hook(cvarhook:data[E_CVAR_HOOK])
	else
	{
		data[E_CVAR_HOOK] = _:hook_cvar_change(data[E_CVAR_POINTER], "cvar_change")
		data[E_CVAR_HOOKED] = true
	}
	ArraySetArray(aCvarsData, index, data)
	return true
}

public cvar_change(pcvar, const old_value[], const new_value[])
{
	new data[eCvars]
	for(new i = 0; i < ArraySize(aCvarsData); i++)
	{
		ArrayGetArray(aCvarsData, i, data)
		if(data[E_CVAR_POINTER] != pcvar)
			continue
		if(equal(new_value, data[E_CVAR_VALUE]))
			return

		disable_cvar_hook(cvarhook:data[E_CVAR_HOOK])
		set_pcvar_string(pcvar, data[E_CVAR_VALUE])
		enable_cvar_hook(cvarhook:data[E_CVAR_HOOK])
		return
	}
}
