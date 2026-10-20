#include <amxmodx>
#include <reapi>
#include <regex>
#include <api_json_settings>
#include <zombie_plague_next>
#include <zombie_plague_next_const>

enum _:eClassSounds
{
	CLASS_SOUND_PAIN,
	CLASS_SOUND_DIE
}

new const CLASS_SOUND_KEYS[eClassSounds][] = { "pain", "die" }

new const DEFAULT_ZOMBIE_PAIN_SOUNDS[][] =
{
	"zpn/zombie_pain1.wav",
	"zpn/zombie_pain2.wav",
	"zpn/zombie_pain3.wav",
	"zpn/zombie_pain4.wav",
	"zpn/zombie_pain5.wav"
}

new const DEFAULT_ZOMBIE_DIE_SOUNDS[][] =
{
	"zpn/zombie_die1.wav",
	"zpn/zombie_die2.wav",
	"zpn/zombie_die3.wav",
	"zpn/zombie_die4.wav",
	"zpn/zombie_die5.wav"
}

enum _:ePropClasses
{
	eClassTypes:CLASS_PROP_TYPE,
	CLASS_PROP_NAME[64],
	CLASS_PROP_NAME_KEY[64],
	CLASS_PROP_INFO[64],
	CLASS_PROP_MODEL[64],
	CLASS_PROP_MODEL_VIEW[64],
	CLASS_PROP_BODY,
	CLASS_PROP_SKIN,
	Float:CLASS_PROP_HEALTH,
	Float:CLASS_PROP_ARMOR,
	Float:CLASS_PROP_SPEED,
	Float:CLASS_PROP_GRAVITY,
	Float:CLASS_PROP_KNOCKBACK,
	CLASS_PROP_CLAW_WEAPONLIST[64],
	CLASS_PROP_FIND_NAME[32],
	CLASS_PROP_NV_COLOR[9],
	CLASS_PROP_NV_COLOR_CONVERTED[3],
	bool:CLASS_PROP_HIDE_MENU,
	bool:CLASS_PROP_UPDATE_HITBOX,
	CLASS_PROP_BLOOD_COLOR,
	bool:CLASS_PROP_SILENT_FOOTSTEPS,
	CLASS_PROP_MODEL_INDEX,
	CLASS_PROP_LIMIT,
	CLASS_PROP_LEVEL,
	bool:CLASS_PROP_LEAP_ENABLED,
	Float:CLASS_PROP_LEAP_FORCE,
	Float:CLASS_PROP_LEAP_HEIGHT,
	Float:CLASS_PROP_LEAP_COOLDOWN,
	Float:CLASS_PROP_LEAP_MIN_SPEED,
	Array:CLASS_PROP_SOUNDS[eClassSounds]
}

new Array:aDataClass, Array:aIndexClassesZombies, Array:aIndexClassesHumans
new Array:aDefaultZombieSounds[eClassSounds]
new bool:gClassPrecache

public plugin_init()
{
	register_plugin("[ZPN] Core: Classes", "1.0", "Wilian M.")
	gClassPrecache = false

	if(!is_regamedll() || !is_rehlds())
	{
		set_fail_state("[ZPN] Class sounds require ReGameDLL_CS and ReHLDS")
		return
	}

	RegisterHookChain(RG_CBasePlayer_Pain, "CBasePlayer_Pain_Pre", false)
	RegisterHookChain(RG_CBasePlayer_DeathSound, "CBasePlayer_DeathSound_Pre", false)
	RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed_Post", true)

	save_class_sound_defaults()
	get_classes_index()

	// LOG
	new i, text[256]

	server_print("^n")
	server_print("Classes loaded: %d", ArraySize(aDataClass))
	
	new xDataGetClass[ePropClasses]
	for(i = 0; i < ArraySize(aDataClass); i++)
	{
		ArrayGetArray(aDataClass, i, xDataGetClass)

		text[0] = EOS
		
		add(text, charsmax(text), fmt("ClassIndex: %d | ", i))
		add(text, charsmax(text), fmt("Name: %s | ", xDataGetClass[CLASS_PROP_NAME]))
		add(text, charsmax(text), fmt("Type: %s | ", (xDataGetClass[CLASS_PROP_TYPE] == CLASS_TEAM_TYPE_ZOMBIE) ? "zombie" : "human"))
		add(text, charsmax(text), fmt("Model: %s | ", xDataGetClass[CLASS_PROP_MODEL]))
		add(text, charsmax(text), fmt("ModelView: %s | ", xDataGetClass[CLASS_PROP_MODEL_VIEW]))
		add(text, charsmax(text), fmt("BloodColor: %d | ", xDataGetClass[CLASS_PROP_BLOOD_COLOR]))
		server_print(text)
	}

	server_print("^n")
}

public plugin_natives()
{
	register_library("zombie_plague_next_classes")

	register_native("zpn_class_init", "_zpn_class_init")
	register_native("zpn_class_get_prop", "_zpn_class_get_prop")
	register_native("zpn_class_set_prop", "_zpn_class_set_prop")
	register_native("zpn_class_random_class_id", "_zpn_class_random_class_id")
	register_native("zpn_class_find", "_zpn_class_find")
	register_native("zpn_class_array_size", "_zpn_class_array_size")
}

public plugin_precache()
{
	gClassPrecache = true
	aDataClass = ArrayCreate(ePropClasses, 0)
	aIndexClassesZombies = ArrayCreate(1, 0)
	aIndexClassesHumans = ArrayCreate(1, 0)

	load_default_zombie_sounds()
}

public plugin_end()
{
	new xDataGetClass[ePropClasses]
	for(new i = 0; i < ArraySize(aDataClass); i++)
	{
		ArrayGetArray(aDataClass, i, xDataGetClass)
		for(new sound_type = 0; sound_type < eClassSounds; sound_type++)
			ArrayDestroy(xDataGetClass[CLASS_PROP_SOUNDS][sound_type])
	}

	for(new sound_type = 0; sound_type < eClassSounds; sound_type++)
		ArrayDestroy(aDefaultZombieSounds[sound_type])

	ArrayDestroy(aDataClass)
	ArrayDestroy(aIndexClassesZombies)
	ArrayDestroy(aIndexClassesHumans)
}

public CBasePlayer_Pain_Pre(const this, HitBoxGroup:lastHitGroup, bool:hasArmour)
{
	return emit_zombie_class_sound(this, CLASS_SOUND_PAIN) ? HC_SUPERCEDE : HC_CONTINUE
}

public CBasePlayer_DeathSound_Pre(const this)
{
	return get_zombie_class_id(this) != -1 ? HC_SUPERCEDE : HC_CONTINUE
}

public CBasePlayer_Killed_Post(const this, pevAttacker, iGib)
{
	if(!IsReapiHookOriginalWasCalled(RG_CBasePlayer_Killed) || is_user_alive(this))
		return

	// Gib deaths skip DeathSound, so emit once after the actual death instead.
	emit_zombie_class_sound(this, CLASS_SOUND_DIE)
}

load_default_zombie_sounds()
{
	for(new sound_type = 0; sound_type < eClassSounds; sound_type++)
		aDefaultZombieSounds[sound_type] = ArrayCreate(MAX_RESOURCE_PATH_LENGTH, 0)

	for(new i = 0; i < sizeof(DEFAULT_ZOMBIE_PAIN_SOUNDS); i++)
		ArrayPushString(aDefaultZombieSounds[CLASS_SOUND_PAIN], DEFAULT_ZOMBIE_PAIN_SOUNDS[i])

	for(new i = 0; i < sizeof(DEFAULT_ZOMBIE_DIE_SOUNDS); i++)
		ArrayPushString(aDefaultZombieSounds[CLASS_SOUND_DIE], DEFAULT_ZOMBIE_DIE_SOUNDS[i])

	for(new sound_type = 0; sound_type < eClassSounds; sound_type++)
	{
		// Save missing defaults, then reload to honor existing arrays, including [].
		json_setting_set_string_arr(PATH_SETTINGS_CLASSES, SETTINGS_SECTION_CLASSES_ZOMBIE_SOUNDS, CLASS_SOUND_KEYS[sound_type], aDefaultZombieSounds[sound_type])
		ArrayClear(aDefaultZombieSounds[sound_type])
		json_setting_get_string_arr(PATH_SETTINGS_CLASSES, SETTINGS_SECTION_CLASSES_ZOMBIE_SOUNDS, CLASS_SOUND_KEYS[sound_type], aDefaultZombieSounds[sound_type])
		precache_class_sounds(aDefaultZombieSounds[sound_type], SETTINGS_SECTION_CLASSES_ZOMBIE_SOUNDS, CLASS_SOUND_KEYS[sound_type])
	}
}

save_class_sound_defaults()
{
	// All classes have finished plugin_precache and supplied their defaults now.
	new xDataGetClass[ePropClasses], class_section[128], sounds_section[128]
	for(new i = 0; i < ArraySize(aDataClass); i++)
	{
		ArrayGetArray(aDataClass, i, xDataGetClass)
		get_class_settings_section(xDataGetClass, class_section, charsmax(class_section))
		formatex(sounds_section, charsmax(sounds_section), "%s.sounds", class_section)

		for(new sound_type = 0; sound_type < eClassSounds; sound_type++)
		{
			new Array:sounds = xDataGetClass[CLASS_PROP_SOUNDS][sound_type]
			if(sounds != Invalid_Array)
				json_setting_set_string_arr(PATH_SETTINGS_CLASSES, sounds_section, CLASS_SOUND_KEYS[sound_type], sounds)
		}
	}
}

load_class_sound_setting(xDataGetClass[ePropClasses], const sound_type, const class_section[], bool:save_default)
{
	new Array:sounds = xDataGetClass[CLASS_PROP_SOUNDS][sound_type]
	if(sounds == Invalid_Array)
		return

	new sounds_section[128]
	formatex(sounds_section, charsmax(sounds_section), "%s.sounds", class_section)
	if(save_default)
		json_setting_set_string_arr(PATH_SETTINGS_CLASSES, sounds_section, CLASS_SOUND_KEYS[sound_type], sounds)

	// The getter appends and returns false for []; clear first so JSON still wins.
	ArrayClear(sounds)
	json_setting_get_string_arr(PATH_SETTINGS_CLASSES, sounds_section, CLASS_SOUND_KEYS[sound_type], sounds)
	precache_class_sounds(sounds, sounds_section, CLASS_SOUND_KEYS[sound_type])
}

copy_class_sounds(Array:source, Array:destination)
{
	new sound[MAX_RESOURCE_PATH_LENGTH]
	new count = ArraySize(source)
	ArrayClear(destination)
	for(new i = 0; i < count; i++)
	{
		ArrayGetString(source, i, sound, charsmax(sound))
		ArrayPushString(destination, sound)
	}
}

precache_class_sounds(Array:sounds, const section[], const key[])
{
	new sound[MAX_RESOURCE_PATH_LENGTH], path[MAX_RESOURCE_PATH_LENGTH + 6]
	for(new i = ArraySize(sounds) - 1; i >= 0; i--)
	{
		ArrayGetString(sounds, i, sound, charsmax(sound))
		formatex(path, charsmax(path), "sound/%s", sound)
		new len = strlen(sound)
		if(len < 5 || !equali(sound[len - 4], ".wav") || !file_exists(path, true))
		{
			log_amx("[ZPN] Ignoring invalid sound in %s / %s: ^"%s^"", section, key, sound)
			ArrayDeleteItem(sounds, i)
			continue
		}

		precache_sound(sound)
	}
}

get_zombie_class_id(const id)
{
	// Death callbacks also need the current class after the player has died.
	if(!zpn_is_valid_player_connected(id))
		return -1

	new class_id = zpn_get_user_current_class(id)
	if(!(0 <= class_id < ArraySize(aDataClass)))
		return -1

	new eClassTypes:type = eClassTypes:ArrayGetCell(aDataClass, class_id, CLASS_PROP_TYPE)
	if(type != CLASS_TEAM_TYPE_ZOMBIE && type != CLASS_TEAM_TYPE_ZOMBIE_SPECIAL)
		return -1

	return class_id
}

bool:emit_zombie_class_sound(const id, const sound_type)
{
	new class_id = get_zombie_class_id(id)
	if(class_id == -1)
		return false

	new Array:sounds = Array:ArrayGetCell(aDataClass, class_id, CLASS_PROP_SOUNDS + sound_type)
	if(ArraySize(sounds) == 0)
		sounds = aDefaultZombieSounds[sound_type]

	new count = ArraySize(sounds)
	if(count > 0)
	{
		new sound[MAX_RESOURCE_PATH_LENGTH]
		ArrayGetString(sounds, random_num(0, count - 1), sound, charsmax(sound))
		rh_emit_sound2(id, 0, CHAN_VOICE, sound)
	}

	// An empty shared array silences the event instead of restoring human voices.
	return true
}

public _zpn_class_array_size(plugin_id, param_nums)
{
	return ArraySize(aDataClass)
}

public _zpn_class_init(plugin_id, param_nums)
{
	if(param_nums != 2)
		return -1

	new xDataGetClass[ePropClasses]

	get_string(1, xDataGetClass[CLASS_PROP_NAME], charsmax(xDataGetClass[CLASS_PROP_NAME]))
	xDataGetClass[CLASS_PROP_TYPE] = eClassTypes:get_param(2)

	xDataGetClass[CLASS_PROP_NAME_KEY] = EOS
	xDataGetClass[CLASS_PROP_INFO] = EOS
	xDataGetClass[CLASS_PROP_MODEL] = EOS
	xDataGetClass[CLASS_PROP_MODEL_VIEW] = EOS
	xDataGetClass[CLASS_PROP_BODY] = -1
	xDataGetClass[CLASS_PROP_HEALTH] = 100.0
	xDataGetClass[CLASS_PROP_ARMOR] = 0.0
	xDataGetClass[CLASS_PROP_SPEED] = 240.0
	xDataGetClass[CLASS_PROP_GRAVITY] = 1.0
	xDataGetClass[CLASS_PROP_KNOCKBACK] = 1.0
	xDataGetClass[CLASS_PROP_CLAW_WEAPONLIST] = EOS
	xDataGetClass[CLASS_PROP_FIND_NAME] = EOS
	xDataGetClass[CLASS_PROP_NV_COLOR] = EOS
	xDataGetClass[CLASS_PROP_NV_COLOR_CONVERTED] = { 255, 255, 255 }
	xDataGetClass[CLASS_PROP_HIDE_MENU] = false
	xDataGetClass[CLASS_PROP_UPDATE_HITBOX] = false
	xDataGetClass[CLASS_PROP_BLOOD_COLOR] = -1
	xDataGetClass[CLASS_PROP_LIMIT] = 0
	xDataGetClass[CLASS_PROP_LEVEL] = 0
	xDataGetClass[CLASS_PROP_MODEL_INDEX] = -1
	xDataGetClass[CLASS_PROP_LEAP_ENABLED] = false
	xDataGetClass[CLASS_PROP_LEAP_FORCE] = 500.0
	xDataGetClass[CLASS_PROP_LEAP_HEIGHT] = 300.0
	xDataGetClass[CLASS_PROP_LEAP_COOLDOWN] = 5.0
	xDataGetClass[CLASS_PROP_LEAP_MIN_SPEED] = 80.0

	new class_section[128]
	get_class_settings_section(xDataGetClass, class_section, charsmax(class_section))

	if(xDataGetClass[CLASS_PROP_TYPE] == CLASS_TEAM_TYPE_ZOMBIE
	|| xDataGetClass[CLASS_PROP_TYPE] == CLASS_TEAM_TYPE_ZOMBIE_SPECIAL)
	{
		for(new sound_type = 0; sound_type < eClassSounds; sound_type++)
			xDataGetClass[CLASS_PROP_SOUNDS][sound_type] = ArrayCreate(MAX_RESOURCE_PATH_LENGTH, 0)
	}

	for(new prop = 0; prop < _:ePropClassRegisters; prop++)
		load_class_setting(xDataGetClass, ePropClassRegisters:prop, class_section)

	return ArrayPushArray(aDataClass, xDataGetClass)
}

public any:_zpn_class_get_prop(plugin_id, param_nums)
{
	if(zpn_is_invalid_array(aDataClass))
		return false

	enum { arg_class_id = 1, arg_prop, arg_value, arg_len }

	new class_id = get_param(arg_class_id)
	new prop = get_param(arg_prop)

	new xDataGetClass[ePropClasses]
	ArrayGetArray(aDataClass, class_id, xDataGetClass)

	switch(ePropClassRegisters:prop)
	{
		case PROP_CLASS_REGISTER_TYPE: return xDataGetClass[CLASS_PROP_TYPE]
		case PROP_CLASS_REGISTER_NAME: set_string(arg_value, xDataGetClass[CLASS_PROP_NAME_KEY], get_param_byref(arg_len))
		case PROP_CLASS_REGISTER_INFO: set_string(arg_value, xDataGetClass[CLASS_PROP_INFO], get_param_byref(arg_len))
		case PROP_CLASS_REGISTER_MODEL: set_string(arg_value, xDataGetClass[CLASS_PROP_MODEL], get_param_byref(arg_len))
		case PROP_CLASS_REGISTER_MODEL_VIEW: set_string(arg_value, xDataGetClass[CLASS_PROP_MODEL_VIEW], get_param_byref(arg_len))
		case PROP_CLASS_REGISTER_BODY: return xDataGetClass[CLASS_PROP_BODY]
		case PROP_CLASS_REGISTER_HEALTH: return xDataGetClass[CLASS_PROP_HEALTH]
		case PROP_CLASS_REGISTER_ARMOR: return xDataGetClass[CLASS_PROP_ARMOR]
		case PROP_CLASS_REGISTER_SPEED: return xDataGetClass[CLASS_PROP_SPEED]
		case PROP_CLASS_REGISTER_GRAVITY: return xDataGetClass[CLASS_PROP_GRAVITY]
		case PROP_CLASS_REGISTER_KNOCKBACK: return xDataGetClass[CLASS_PROP_KNOCKBACK]
		case PROP_CLASS_REGISTER_CLAW_WEAPONLIST: set_string(arg_value, xDataGetClass[CLASS_PROP_CLAW_WEAPONLIST], get_param_byref(arg_len))
		case PROP_CLASS_REGISTER_SKIN: return xDataGetClass[CLASS_PROP_SKIN]
		case PROP_CLASS_REGISTER_FIND_NAME: set_string(arg_value, xDataGetClass[CLASS_PROP_FIND_NAME], get_param_byref(arg_len))
		case PROP_CLASS_REGISTER_NV_COLOR: set_string(arg_value, xDataGetClass[CLASS_PROP_NV_COLOR], get_param_byref(arg_len))
		case PROP_CLASS_REGISTER_NV_COLOR_CONVERTED: set_array(arg_value, xDataGetClass[CLASS_PROP_NV_COLOR_CONVERTED], get_param_byref(arg_len))
		case PROP_CLASS_REGISTER_HIDE_MENU: return bool:xDataGetClass[CLASS_PROP_HIDE_MENU]
		case PROP_CLASS_REGISTER_UPDATE_HITBOX: return bool:xDataGetClass[CLASS_PROP_UPDATE_HITBOX]
		case PROP_CLASS_REGISTER_BLOOD_COLOR: return xDataGetClass[CLASS_PROP_BLOOD_COLOR]
		case PROP_CLASS_REGISTER_SILENT_FOOTSTEPS: return bool:xDataGetClass[CLASS_PROP_SILENT_FOOTSTEPS]
		case PROP_CLASS_REGISTER_MODEL_INDEX: return xDataGetClass[CLASS_PROP_MODEL_INDEX]
		case PROP_CLASS_REGISTER_LIMIT: return xDataGetClass[CLASS_PROP_LIMIT]
		case PROP_CLASS_REGISTER_LEVEL: return xDataGetClass[CLASS_PROP_LEVEL]
		case PROP_CLASS_REGISTER_LEAP_ENABLED: return xDataGetClass[CLASS_PROP_LEAP_ENABLED]
		case PROP_CLASS_REGISTER_LEAP_FORCE: return xDataGetClass[CLASS_PROP_LEAP_FORCE]
		case PROP_CLASS_REGISTER_LEAP_HEIGHT: return xDataGetClass[CLASS_PROP_LEAP_HEIGHT]
		case PROP_CLASS_REGISTER_LEAP_COOLDOWN: return xDataGetClass[CLASS_PROP_LEAP_COOLDOWN]
		case PROP_CLASS_REGISTER_LEAP_MIN_SPEED: return xDataGetClass[CLASS_PROP_LEAP_MIN_SPEED]
		case PROP_CLASS_REGISTER_PAIN_SOUNDS, PROP_CLASS_REGISTER_DIE_SOUNDS:
		{
			if(param_nums != 3)
				return false

			new sound_type = prop == _:PROP_CLASS_REGISTER_PAIN_SOUNDS ? CLASS_SOUND_PAIN : CLASS_SOUND_DIE
			new Array:sounds = xDataGetClass[CLASS_PROP_SOUNDS][sound_type]
			new Array:output = Array:get_param_byref(arg_value)
			if(sounds == Invalid_Array || output == Invalid_Array)
				return false

			copy_class_sounds(sounds, output)
		}
	}

	return true
}

public any:_zpn_class_set_prop(plugin_id, param_nums)
{
	if(zpn_is_invalid_array(aDataClass))
		return false

	enum { arg_class_id = 1, arg_prop, arg_value }

	new class_id = get_param(arg_class_id)
	new prop = get_param(arg_prop)

	new xDataGetClass[ePropClasses]
	ArrayGetArray(aDataClass, class_id, xDataGetClass)

	switch(ePropClassRegisters:prop)
	{
		case PROP_CLASS_REGISTER_NAME: get_string(arg_value, xDataGetClass[CLASS_PROP_NAME_KEY], charsmax(xDataGetClass[CLASS_PROP_NAME_KEY]))
		case PROP_CLASS_REGISTER_INFO: get_string(arg_value, xDataGetClass[CLASS_PROP_INFO], charsmax(xDataGetClass[CLASS_PROP_INFO]))
		case PROP_CLASS_REGISTER_MODEL: get_string(arg_value, xDataGetClass[CLASS_PROP_MODEL], charsmax(xDataGetClass[CLASS_PROP_MODEL]))
		case PROP_CLASS_REGISTER_MODEL_VIEW: get_string(arg_value, xDataGetClass[CLASS_PROP_MODEL_VIEW], charsmax(xDataGetClass[CLASS_PROP_MODEL_VIEW]))
		case PROP_CLASS_REGISTER_BODY: xDataGetClass[CLASS_PROP_BODY] = get_param_byref(arg_value)
		case PROP_CLASS_REGISTER_SKIN: xDataGetClass[CLASS_PROP_SKIN] = get_param_byref(arg_value)
		case PROP_CLASS_REGISTER_HEALTH: xDataGetClass[CLASS_PROP_HEALTH] = get_float_byref(arg_value)
		case PROP_CLASS_REGISTER_SPEED: xDataGetClass[CLASS_PROP_SPEED] = get_float_byref(arg_value)
		case PROP_CLASS_REGISTER_ARMOR: xDataGetClass[CLASS_PROP_ARMOR] = get_float_byref(arg_value)
		case PROP_CLASS_REGISTER_GRAVITY: xDataGetClass[CLASS_PROP_GRAVITY] = get_float_byref(arg_value)
		case PROP_CLASS_REGISTER_KNOCKBACK: xDataGetClass[CLASS_PROP_KNOCKBACK] = get_float_byref(arg_value)
		case PROP_CLASS_REGISTER_CLAW_WEAPONLIST: get_string(arg_value, xDataGetClass[CLASS_PROP_CLAW_WEAPONLIST], charsmax(xDataGetClass[CLASS_PROP_CLAW_WEAPONLIST]))
		case PROP_CLASS_REGISTER_FIND_NAME: get_string(arg_value, xDataGetClass[CLASS_PROP_FIND_NAME], charsmax(xDataGetClass[CLASS_PROP_FIND_NAME]))
		case PROP_CLASS_REGISTER_NV_COLOR: get_string(arg_value, xDataGetClass[CLASS_PROP_NV_COLOR], charsmax(xDataGetClass[CLASS_PROP_NV_COLOR]))
		case PROP_CLASS_REGISTER_HIDE_MENU: xDataGetClass[CLASS_PROP_HIDE_MENU] = bool:get_param_byref(arg_value)
		case PROP_CLASS_REGISTER_UPDATE_HITBOX: xDataGetClass[CLASS_PROP_UPDATE_HITBOX] = bool:get_param_byref(arg_value)
		case PROP_CLASS_REGISTER_BLOOD_COLOR: xDataGetClass[CLASS_PROP_BLOOD_COLOR] = get_param_byref(arg_value)
		case PROP_CLASS_REGISTER_SILENT_FOOTSTEPS: xDataGetClass[CLASS_PROP_SILENT_FOOTSTEPS] = bool:get_param_byref(arg_value)
		case PROP_CLASS_REGISTER_LIMIT: xDataGetClass[CLASS_PROP_LIMIT] = clamp(get_param_byref(arg_value), 0, 32)
		case PROP_CLASS_REGISTER_LEVEL: xDataGetClass[CLASS_PROP_LEVEL] = clamp(get_param_byref(arg_value), 0, MAX_LEVEL)
		case PROP_CLASS_REGISTER_LEAP_ENABLED: xDataGetClass[CLASS_PROP_LEAP_ENABLED] = bool:get_param_byref(arg_value)
		case PROP_CLASS_REGISTER_LEAP_FORCE: xDataGetClass[CLASS_PROP_LEAP_FORCE] = floatmax(0.0, get_float_byref(arg_value))
		case PROP_CLASS_REGISTER_LEAP_HEIGHT: xDataGetClass[CLASS_PROP_LEAP_HEIGHT] = floatmax(0.0, get_float_byref(arg_value))
		case PROP_CLASS_REGISTER_LEAP_COOLDOWN: xDataGetClass[CLASS_PROP_LEAP_COOLDOWN] = floatmax(0.0, get_float_byref(arg_value))
		case PROP_CLASS_REGISTER_LEAP_MIN_SPEED: xDataGetClass[CLASS_PROP_LEAP_MIN_SPEED] = floatmax(0.0, get_float_byref(arg_value))
		case PROP_CLASS_REGISTER_PAIN_SOUNDS, PROP_CLASS_REGISTER_DIE_SOUNDS:
		{
			if(param_nums != 3)
				return false

			if(!gClassPrecache)
			{
				log_error(AMX_ERR_NATIVE, "[ZPN] Class sound properties must be set during plugin_precache")
				return false
			}

			new sound_type = prop == _:PROP_CLASS_REGISTER_PAIN_SOUNDS ? CLASS_SOUND_PAIN : CLASS_SOUND_DIE
			new Array:sounds = xDataGetClass[CLASS_PROP_SOUNDS][sound_type]
			if(sounds == Invalid_Array)
			{
				log_error(AMX_ERR_NATIVE, "[ZPN] Class sound properties require a zombie or special-zombie class")
				return false
			}

			new Array:input = Array:get_param_byref(arg_value)
			if(input == Invalid_Array)
			{
				log_error(AMX_ERR_NATIVE, "[ZPN] Class sound properties require a valid string array")
				return false
			}

			copy_class_sounds(input, sounds)
		}
	}

	new class_section[128]
	get_class_settings_section(xDataGetClass, class_section, charsmax(class_section))

	// Registered values are defaults: an existing JSON value always takes priority.
	load_class_setting(xDataGetClass, PROP_CLASS_REGISTER_NAME, class_section, true)
	if(prop != _:PROP_CLASS_REGISTER_NAME)
		load_class_setting(xDataGetClass, ePropClassRegisters:prop, class_section, true)
	ArraySetArray(aDataClass, class_id, xDataGetClass)

	return true
}

get_class_settings_section(const xDataGetClass[ePropClasses], section[], len)
{
	new class_slug[64]
	create_slug(xDataGetClass[CLASS_PROP_NAME], class_slug, charsmax(class_slug))
	formatex(section, len, "%s.%s", get_section_class(xDataGetClass[CLASS_PROP_TYPE]), class_slug)
}

load_class_setting(xDataGetClass[ePropClasses], ePropClassRegisters:prop, const class_section_final[], bool:save_default = false)
{
	switch(prop)
	{
		case PROP_CLASS_REGISTER_NAME:
		{
			if(!json_setting_get_string(PATH_SETTINGS_CLASSES, class_section_final, "name_key", xDataGetClass[CLASS_PROP_NAME_KEY], charsmax(xDataGetClass[CLASS_PROP_NAME_KEY])) && save_default)
				json_setting_set_string(PATH_SETTINGS_CLASSES, class_section_final, "name_key", xDataGetClass[CLASS_PROP_NAME_KEY])
		}
		case PROP_CLASS_REGISTER_INFO:
		{
			if(!json_setting_get_string(PATH_SETTINGS_CLASSES, class_section_final, "description_key", xDataGetClass[CLASS_PROP_INFO], charsmax(xDataGetClass[CLASS_PROP_INFO])) && save_default)
				json_setting_set_string(PATH_SETTINGS_CLASSES, class_section_final, "description_key", xDataGetClass[CLASS_PROP_INFO])
		}
		case PROP_CLASS_REGISTER_MODEL:
		{
			if(!json_setting_get_string(PATH_SETTINGS_CLASSES, class_section_final, "model", xDataGetClass[CLASS_PROP_MODEL], charsmax(xDataGetClass[CLASS_PROP_MODEL])) && save_default)
				json_setting_set_string(PATH_SETTINGS_CLASSES, class_section_final, "model", xDataGetClass[CLASS_PROP_MODEL])

			if(!zpn_is_null_string(xDataGetClass[CLASS_PROP_MODEL]))
				xDataGetClass[CLASS_PROP_MODEL_INDEX] = precache_player_model(xDataGetClass[CLASS_PROP_MODEL])
		}
		case PROP_CLASS_REGISTER_MODEL_VIEW:
		{
			if(!json_setting_get_string(PATH_SETTINGS_CLASSES, class_section_final, "model_view", xDataGetClass[CLASS_PROP_MODEL_VIEW], charsmax(xDataGetClass[CLASS_PROP_MODEL_VIEW])) && save_default)
				json_setting_set_string(PATH_SETTINGS_CLASSES, class_section_final, "model_view", xDataGetClass[CLASS_PROP_MODEL_VIEW])

			if(!zpn_is_null_string(xDataGetClass[CLASS_PROP_MODEL_VIEW]))
				precache_model(xDataGetClass[CLASS_PROP_MODEL_VIEW])
		}
		case PROP_CLASS_REGISTER_BODY:
		{
			if(!json_setting_get_int(PATH_SETTINGS_CLASSES, class_section_final, "body", xDataGetClass[CLASS_PROP_BODY]) && save_default)
				json_setting_set_int(PATH_SETTINGS_CLASSES, class_section_final, "body", xDataGetClass[CLASS_PROP_BODY], false)
		}
		case PROP_CLASS_REGISTER_SKIN:
		{
			if(!json_setting_get_int(PATH_SETTINGS_CLASSES, class_section_final, "skin", xDataGetClass[CLASS_PROP_SKIN]) && save_default)
				json_setting_set_int(PATH_SETTINGS_CLASSES, class_section_final, "skin", xDataGetClass[CLASS_PROP_SKIN], false)
		}
		case PROP_CLASS_REGISTER_HEALTH:
		{
			if(!json_setting_get_float(PATH_SETTINGS_CLASSES, class_section_final, "health", xDataGetClass[CLASS_PROP_HEALTH]) && save_default)
				json_setting_set_float(PATH_SETTINGS_CLASSES, class_section_final, "health", xDataGetClass[CLASS_PROP_HEALTH])
		}
		case PROP_CLASS_REGISTER_SPEED:
		{
			if(!json_setting_get_float(PATH_SETTINGS_CLASSES, class_section_final, "speed", xDataGetClass[CLASS_PROP_SPEED]) && save_default)
				json_setting_set_float(PATH_SETTINGS_CLASSES, class_section_final, "speed", xDataGetClass[CLASS_PROP_SPEED])
		}
		case PROP_CLASS_REGISTER_ARMOR:
		{
			if(!json_setting_get_float(PATH_SETTINGS_CLASSES, class_section_final, "armor", xDataGetClass[CLASS_PROP_ARMOR]) && save_default)
				json_setting_set_float(PATH_SETTINGS_CLASSES, class_section_final, "armor", xDataGetClass[CLASS_PROP_ARMOR])
		}
		case PROP_CLASS_REGISTER_GRAVITY:
		{
			if(!json_setting_get_float(PATH_SETTINGS_CLASSES, class_section_final, "gravity", xDataGetClass[CLASS_PROP_GRAVITY]) && save_default)
				json_setting_set_float(PATH_SETTINGS_CLASSES, class_section_final, "gravity", xDataGetClass[CLASS_PROP_GRAVITY])
		}
		case PROP_CLASS_REGISTER_KNOCKBACK:
		{
			if(!json_setting_get_float(PATH_SETTINGS_CLASSES, class_section_final, "knockback", xDataGetClass[CLASS_PROP_KNOCKBACK]) && save_default)
				json_setting_set_float(PATH_SETTINGS_CLASSES, class_section_final, "knockback", xDataGetClass[CLASS_PROP_KNOCKBACK])
		}
		case PROP_CLASS_REGISTER_CLAW_WEAPONLIST:
		{
			if(!json_setting_get_string(PATH_SETTINGS_CLASSES, class_section_final, "claw_weapon_list", xDataGetClass[CLASS_PROP_CLAW_WEAPONLIST], charsmax(xDataGetClass[CLASS_PROP_CLAW_WEAPONLIST])) && save_default)
				json_setting_set_string(PATH_SETTINGS_CLASSES, class_section_final, "claw_weapon_list", xDataGetClass[CLASS_PROP_CLAW_WEAPONLIST])
		}
		case PROP_CLASS_REGISTER_FIND_NAME:
		{
			if(!json_setting_get_string(PATH_SETTINGS_CLASSES, class_section_final, "find_name", xDataGetClass[CLASS_PROP_FIND_NAME], charsmax(xDataGetClass[CLASS_PROP_FIND_NAME])) && save_default)
				json_setting_set_string(PATH_SETTINGS_CLASSES, class_section_final, "find_name", xDataGetClass[CLASS_PROP_FIND_NAME])
		}
		case PROP_CLASS_REGISTER_NV_COLOR:
		{
			if(!json_setting_get_string(PATH_SETTINGS_CLASSES, class_section_final, "nv_color", xDataGetClass[CLASS_PROP_NV_COLOR], charsmax(xDataGetClass[CLASS_PROP_NV_COLOR])) && save_default)
				json_setting_set_string(PATH_SETTINGS_CLASSES, class_section_final, "nv_color", xDataGetClass[CLASS_PROP_NV_COLOR])

			if(!zpn_is_null_string(xDataGetClass[CLASS_PROP_NV_COLOR]))
			{
				if(!parse_hex_color(xDataGetClass[CLASS_PROP_NV_COLOR], xDataGetClass[CLASS_PROP_NV_COLOR_CONVERTED]))
				{
					server_print("^n")
					server_print("Falha ao converter HEX COLOR: %s - %s", xDataGetClass[CLASS_PROP_NAME], xDataGetClass[CLASS_PROP_NV_COLOR])
					server_print("^n")
				}
			}
		}
		case PROP_CLASS_REGISTER_HIDE_MENU:
		{
			if(!json_setting_get_bool(PATH_SETTINGS_CLASSES, class_section_final, "hide_class_in_menu", xDataGetClass[CLASS_PROP_HIDE_MENU]) && save_default)
				json_setting_set_bool(PATH_SETTINGS_CLASSES, class_section_final, "hide_class_in_menu", xDataGetClass[CLASS_PROP_HIDE_MENU])
		}
		case PROP_CLASS_REGISTER_UPDATE_HITBOX:
		{
			if(!json_setting_get_bool(PATH_SETTINGS_CLASSES, class_section_final, "update_hitbox", xDataGetClass[CLASS_PROP_UPDATE_HITBOX]) && save_default)
				json_setting_set_bool(PATH_SETTINGS_CLASSES, class_section_final, "update_hitbox", xDataGetClass[CLASS_PROP_UPDATE_HITBOX])
		}
		case PROP_CLASS_REGISTER_BLOOD_COLOR:
		{
			if(!json_setting_get_int(PATH_SETTINGS_CLASSES, class_section_final, "blood_color", xDataGetClass[CLASS_PROP_BLOOD_COLOR]) && save_default)
				json_setting_set_int(PATH_SETTINGS_CLASSES, class_section_final, "blood_color", xDataGetClass[CLASS_PROP_BLOOD_COLOR], false)
		}
		case PROP_CLASS_REGISTER_SILENT_FOOTSTEPS:
		{
			if(!json_setting_get_bool(PATH_SETTINGS_CLASSES, class_section_final, "silent_footsteps", xDataGetClass[CLASS_PROP_SILENT_FOOTSTEPS]) && save_default)
				json_setting_set_bool(PATH_SETTINGS_CLASSES, class_section_final, "silent_footsteps", xDataGetClass[CLASS_PROP_SILENT_FOOTSTEPS])
		}
		case PROP_CLASS_REGISTER_LIMIT:
		{
			if(!json_setting_get_int(PATH_SETTINGS_CLASSES, class_section_final, "limit", xDataGetClass[CLASS_PROP_LIMIT]) && save_default)
				json_setting_set_int(PATH_SETTINGS_CLASSES, class_section_final, "limit", xDataGetClass[CLASS_PROP_LIMIT], false)

			xDataGetClass[CLASS_PROP_LIMIT] = clamp(xDataGetClass[CLASS_PROP_LIMIT], 0, 32)
		}
		case PROP_CLASS_REGISTER_LEVEL:
		{
			if(!json_setting_get_int(PATH_SETTINGS_CLASSES, class_section_final, "level", xDataGetClass[CLASS_PROP_LEVEL]) && save_default)
				json_setting_set_int(PATH_SETTINGS_CLASSES, class_section_final, "level", xDataGetClass[CLASS_PROP_LEVEL], false)

			xDataGetClass[CLASS_PROP_LEVEL] = clamp(xDataGetClass[CLASS_PROP_LEVEL], 0, MAX_LEVEL)
		}
		case PROP_CLASS_REGISTER_LEAP_ENABLED:
		{
			if(!json_setting_get_bool(PATH_SETTINGS_CLASSES, class_section_final, "leap_enabled", xDataGetClass[CLASS_PROP_LEAP_ENABLED]) && save_default)
				json_setting_set_bool(PATH_SETTINGS_CLASSES, class_section_final, "leap_enabled", xDataGetClass[CLASS_PROP_LEAP_ENABLED])
		}
		case PROP_CLASS_REGISTER_LEAP_FORCE:
		{
			if(!json_setting_get_float(PATH_SETTINGS_CLASSES, class_section_final, "leap_force", xDataGetClass[CLASS_PROP_LEAP_FORCE]) && save_default)
				json_setting_set_float(PATH_SETTINGS_CLASSES, class_section_final, "leap_force", xDataGetClass[CLASS_PROP_LEAP_FORCE])

			xDataGetClass[CLASS_PROP_LEAP_FORCE] = floatmax(0.0, xDataGetClass[CLASS_PROP_LEAP_FORCE])
		}
		case PROP_CLASS_REGISTER_LEAP_HEIGHT:
		{
			if(!json_setting_get_float(PATH_SETTINGS_CLASSES, class_section_final, "leap_height", xDataGetClass[CLASS_PROP_LEAP_HEIGHT]) && save_default)
				json_setting_set_float(PATH_SETTINGS_CLASSES, class_section_final, "leap_height", xDataGetClass[CLASS_PROP_LEAP_HEIGHT])

			xDataGetClass[CLASS_PROP_LEAP_HEIGHT] = floatmax(0.0, xDataGetClass[CLASS_PROP_LEAP_HEIGHT])
		}
		case PROP_CLASS_REGISTER_LEAP_COOLDOWN:
		{
			if(!json_setting_get_float(PATH_SETTINGS_CLASSES, class_section_final, "leap_cooldown", xDataGetClass[CLASS_PROP_LEAP_COOLDOWN]) && save_default)
				json_setting_set_float(PATH_SETTINGS_CLASSES, class_section_final, "leap_cooldown", xDataGetClass[CLASS_PROP_LEAP_COOLDOWN])

			xDataGetClass[CLASS_PROP_LEAP_COOLDOWN] = floatmax(0.0, xDataGetClass[CLASS_PROP_LEAP_COOLDOWN])
		}
		case PROP_CLASS_REGISTER_LEAP_MIN_SPEED:
		{
			if(!json_setting_get_float(PATH_SETTINGS_CLASSES, class_section_final, "leap_min_speed", xDataGetClass[CLASS_PROP_LEAP_MIN_SPEED]) && save_default)
				json_setting_set_float(PATH_SETTINGS_CLASSES, class_section_final, "leap_min_speed", xDataGetClass[CLASS_PROP_LEAP_MIN_SPEED])

			xDataGetClass[CLASS_PROP_LEAP_MIN_SPEED] = floatmax(0.0, xDataGetClass[CLASS_PROP_LEAP_MIN_SPEED])
		}
		case PROP_CLASS_REGISTER_PAIN_SOUNDS, PROP_CLASS_REGISTER_DIE_SOUNDS:
		{
			new sound_type = prop == PROP_CLASS_REGISTER_PAIN_SOUNDS ? CLASS_SOUND_PAIN : CLASS_SOUND_DIE
			load_class_sound_setting(xDataGetClass, sound_type, class_section_final, save_default)
		}
	}
}

public _zpn_class_random_class_id(plugin_id, param_nums)
{
	if(param_nums != 1)
		return 0

	new eClassTypes:type = eClassTypes:get_param(1)
	new random_index

	switch(type)
	{
		case CLASS_TEAM_TYPE_ZOMBIE: random_index = ArrayGetCell(aIndexClassesZombies, random_num(0, ArraySize(aIndexClassesZombies) -1))
		case CLASS_TEAM_TYPE_HUMAN: random_index = ArrayGetCell(aIndexClassesHumans, random_num(0, ArraySize(aIndexClassesHumans) -1))
		default: random_index = ArrayGetCell(aIndexClassesZombies, 0)
	}

	return random_index
}

public _zpn_class_find(plugin_id, param_nums)
{
	if(param_nums != 1)
		return -1

	static findName[32]; findName[0] = EOS;
	get_string(1, findName, charsmax(findName))

	new find = -1
	new xDataGetClass[ePropClasses]

	for(new i = 0; i < ArraySize(aDataClass); i++)
	{
		ArrayGetArray(aDataClass, i, xDataGetClass)
		
		if(zpn_is_null_string(xDataGetClass[CLASS_PROP_FIND_NAME]))
			continue

		if(equal(xDataGetClass[CLASS_PROP_FIND_NAME], findName))
			find = i

		if(find != -1)
			break
	}

	return find
}

get_section_class(eClassTypes:type)
{
	static section[64]; section[0] = EOS

	switch(type)
	{
		case CLASS_TEAM_TYPE_ZOMBIE: copy(section, charsmax(section), SETTINGS_SECTION_CLASSES_ZOMBIE)
		case CLASS_TEAM_TYPE_ZOMBIE_SPECIAL: copy(section, charsmax(section), SETTINGS_SECTION_CLASSES_ZOMBIE_SP)
		case CLASS_TEAM_TYPE_HUMAN: copy(section, charsmax(section), SETTINGS_SECTION_CLASSES_HUMAN)
		case CLASS_TEAM_TYPE_HUMAN_SPECIAL: copy(section, charsmax(section), SETTINGS_SECTION_CLASSES_HUMAN_SP)
		default:
		{
			copy(section, charsmax(section), SETTINGS_SECTION_CLASSES_ZOMBIE)
		}
	}

	return section
}

get_classes_index()
{
	new xDataGetClass[ePropClasses]
	
	for(new i = 0; i < ArraySize(aDataClass); i++)
	{
		ArrayGetArray(aDataClass, i, xDataGetClass)

		if(xDataGetClass[CLASS_PROP_TYPE] == CLASS_TEAM_TYPE_ZOMBIE)
			ArrayPushCell(aIndexClassesZombies, i)
		else if(xDataGetClass[CLASS_PROP_TYPE] == CLASS_TEAM_TYPE_HUMAN)
			ArrayPushCell(aIndexClassesHumans, i)
	}
}
