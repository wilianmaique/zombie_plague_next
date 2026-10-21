#include <amxmodx>
#include <amxmisc>
#include <reapi>

// GoldSrc MAX_QPATH includes the string terminator.
#define RESOURCE_PATH_LENGTH 64
// ReHLDS MAX_MODELS: 9-bit indices, including the reserved index 0.
#define MODEL_PRECACHE_LIMIT 512
#define BLOCKED_MODEL (1 << 0)
#define BLOCKED_GENERIC (1 << 1)
#define BLOCKED_SOUND (1 << 2)
#define PRECACHED_MODEL (1 << 3)

new const unprecache_file[] = "unprecache.ini"
new const sound_directory[] = "sound/"

new Trie:blocked_resources = Invalid_Trie
new blocked_model_count
new blocked_sound_count
new blocked_generic_count
new model_precache_count = 1
new saved_model_count

// Load before all other plugins that precache resources in plugins.ini.
public plugin_precache()
{
	register_dictionary("amx_unprecache.txt")

	if(!is_rehlds())
	{
		set_fail_state("%L", LANG_SERVER, "UNPRECACHE_REHLDS_REQUIRED")
		return
	}

	if(!load_blocked_resources())
		return

	// The resource list includes map/brush models registered before AMXX loaded.
	RegisterHookChain(RH_SV_AddResource, "resource_added_pre", false)

	if(!TrieGetSize(blocked_resources))
		return

	RegisterHookChain(RH_PF_precache_model_I, "precache_model_pre", false)
	RegisterHookChain(RH_PF_precache_sound_I, "precache_sound_pre", false)
	RegisterHookChain(RH_PF_precache_generic_I, "precache_generic_pre", false)
}

public plugin_init()
{
	register_plugin("AMXX Unprecache", "1.1", "Wilian M.")
	register_srvcmd("amx_unprecache_status", "command_unprecache_status", ADMIN_CFG, "UNPRECACHE_STATUS_HELP", true)

	log_amx("%L", LANG_SERVER, "UNPRECACHE_SUMMARY", TrieGetSize(blocked_resources), blocked_model_count, blocked_sound_count, blocked_generic_count)
}

public plugin_end()
{
	if(blocked_resources != Invalid_Trie)
		TrieDestroy(blocked_resources)
}

public precache_model_pre(const path[])
{
	// ReHLDS accepts ! as an optional-model marker, not part of its filename.
	return block_precache(path[path[0] == '!' ? 1 : 0], BLOCKED_MODEL)
}

public precache_generic_pre(const path[])
{
	return block_precache(path, BLOCKED_GENERIC)
}

public precache_sound_pre(const path[])
{
	return block_precache(path, BLOCKED_SOUND)
}

public resource_added_pre(ResourceType_t:type, const filename[], size, flags, index)
{
	if(type != t_model || index <= 0 || index >= MODEL_PRECACHE_LIMIT)
		return HC_CONTINUE

	// Precache slots are contiguous; the highest index also accounts for slot 0.
	if(index >= model_precache_count)
		model_precache_count = index + 1

	new path[RESOURCE_PATH_LENGTH], resource_flags
	if(!get_resource_path(filename, BLOCKED_MODEL, path, charsmax(path)))
		return HC_CONTINUE

	if(!TrieGetCell(blocked_resources, path, resource_flags) || (resource_flags & PRECACHED_MODEL))
		return HC_CONTINUE

	// A path registered before our hook cannot be counted as an avoided slot.
	if(resource_flags & BLOCKED_MODEL)
		saved_model_count--

	TrieSetCell(blocked_resources, path, resource_flags | PRECACHED_MODEL)
	return HC_CONTINUE
}

public command_unprecache_status()
{
	if(model_precache_count > 1)
	{
		server_print("[Unprecache] %L", LANG_SERVER, "UNPRECACHE_MODEL_TABLE",
			model_precache_count + saved_model_count, MODEL_PRECACHE_LIMIT,
			model_precache_count, MODEL_PRECACHE_LIMIT,
			MODEL_PRECACHE_LIMIT - model_precache_count, saved_model_count)
		server_print("[Unprecache] %L", LANG_SERVER, "UNPRECACHE_MODEL_TABLE_NOTE")
	}
	else
		server_print("[Unprecache] %L", LANG_SERVER, "UNPRECACHE_MODEL_TABLE_PENDING")

	server_print("[Unprecache] %L", LANG_SERVER, "UNPRECACHE_SUMMARY", TrieGetSize(blocked_resources), blocked_model_count, blocked_sound_count, blocked_generic_count)
	server_print("[Unprecache] %L", LANG_SERVER, "UNPRECACHE_STATUS_NOTE")

	new TrieIter:iterator = TrieIterCreate(blocked_resources)
	new path[RESOURCE_PATH_LENGTH], flags

	while(!TrieIterEnded(iterator))
	{
		TrieIterGetKey(iterator, path, charsmax(path))
		TrieIterGetCell(iterator, flags)

		server_print("[Unprecache] %L", LANG_SERVER, "UNPRECACHE_STATUS_ENTRY", path,
			LANG_SERVER, (flags & BLOCKED_MODEL) ? "UNPRECACHE_BLOCKED" : "UNPRECACHE_NOT_INTERCEPTED",
			LANG_SERVER, (flags & BLOCKED_SOUND) ? "UNPRECACHE_BLOCKED" : "UNPRECACHE_NOT_INTERCEPTED",
			LANG_SERVER, (flags & BLOCKED_GENERIC) ? "UNPRECACHE_BLOCKED" : "UNPRECACHE_NOT_INTERCEPTED")

		TrieIterNext(iterator)
	}

	TrieIterDestroy(iterator)
	return PLUGIN_HANDLED
}

bool:load_blocked_resources()
{
	new configs_dir[PLATFORM_MAX_PATH], file_path[PLATFORM_MAX_PATH]
	get_configsdir(configs_dir, charsmax(configs_dir))
	formatex(file_path, charsmax(file_path), "%s/%s", configs_dir, unprecache_file)

	new file = fopen(file_path, "rt")
	if(!file)
	{
		set_fail_state("%L", LANG_SERVER, "UNPRECACHE_OPEN_FAILED", file_path)
		return false
	}

	blocked_resources = TrieCreate()

	new line[512], path[512], line_number, length, position
	while((length = fgets(file, line, charsmax(line))) > 0)
	{
		line_number++

		if(line[length - 1] != '^n' && !feof(file))
		{
			// Discard the entire oversized line so its tail cannot become a rule.
			while(fgets(file, line, charsmax(line)))
			{
				if(contain(line, "^n") != -1)
					break
			}

			log_amx("%L", LANG_SERVER, "UNPRECACHE_LINE_TOO_LONG", line_number, file_path)
			continue
		}

		if(line_number == 1 && line[0] == 0xEF && line[1] == 0xBB && line[2] == 0xBF)
			copy(line, charsmax(line), line[3])

		trim(line)
		if(!line[0] || is_config_comment(line))
			continue

		position = argparse(line, 0, path, charsmax(path))
		if(position == -1)
			continue

		trim(line[position])
		replace_string(path, charsmax(path), "\", "/")

		if((line[position] && !is_config_comment(line[position])) || !is_resource_path_valid(path))
		{
			log_amx("%L", LANG_SERVER, "UNPRECACHE_INVALID_PATH", line_number, file_path)
			continue
		}

		// Exact, case-sensitive keys; duplicate paths are stored once.
		TrieSetCell(blocked_resources, path, 0, false)
	}

	fclose(file)
	return true
}

bool:is_config_comment(const text[])
{
	return text[0] == ';' || text[0] == '#' || (text[0] == '/' && text[1] == '/')
}

bool:is_resource_path_valid(const path[])
{
	new length = strlen(path)
	if(length <= 4 || length >= RESOURCE_PATH_LENGTH)
		return false

	if(equal(path, sound_directory, charsmax(sound_directory)))
	{
		if(!equali(path[length - 4], ".wav") && !equali(path[length - 4], ".mp3"))
			return false
	}
	else
	{
		if(!equal(path, "models/", 7) && !equal(path, "sprites/", 8))
			return false

		if(!equali(path[length - 4], ".mdl") && !equali(path[length - 4], ".spr"))
			return false
	}

	if(contain(path, "..") != -1 || contain(path, "//") != -1)
		return false

	for(new i = 0; i < length; i++)
	{
		if(path[i] < ' ' || path[i] == '"' || path[i] == '*' || path[i] == '?' || path[i] == ':' || path[i] == '<' || path[i] == '>' || path[i] == '|')
			return false
	}

	return true
}

bool:get_resource_path(const resource[], const type, path[], const maxlen)
{
	new prefix_length = (type == BLOCKED_SOUND) ? charsmax(sound_directory) : 0
	if(!resource[0] || strlen(resource) + prefix_length > maxlen)
		return false

	// precache_sound paths are relative to sound/, unlike the INI/generic paths.
	if(type == BLOCKED_SOUND)
		formatex(path, maxlen, "%s%s", sound_directory, resource)
	else
		copy(path, maxlen, resource)

	replace_string(path, maxlen, "\", "/")
	return true
}

block_precache(const resource[], const type)
{
	new path[RESOURCE_PATH_LENGTH], flags
	if(!get_resource_path(resource, type, path, charsmax(path)))
		return HC_CONTINUE

	if(!TrieGetCell(blocked_resources, path, flags))
		return HC_CONTINUE

	if(!(flags & type))
	{
		TrieSetCell(blocked_resources, path, flags | type)
		if(type == BLOCKED_MODEL)
		{
			blocked_model_count++
			if(!(flags & PRECACHED_MODEL))
				saved_model_count++
		}
		else if(type == BLOCKED_SOUND)
			blocked_sound_count++
		else
			blocked_generic_count++
	}

	// Suppress insertion without precaching a replacement resource.
	SetHookChainReturn(ATYPE_INTEGER, 0)
	return HC_SUPERCEDE
}
