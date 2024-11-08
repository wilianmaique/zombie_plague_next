#include <amxmodx>
#include <reapi>

public plugin_init()
{
	register_plugin("[ZPN] Addon: Block Hint", "1.0", "Wilian M.")

	RegisterHookChain(RG_CBasePlayer_HintMessageEx, "@CBasePlayer_HintMessageEx_Pre")
}

@CBasePlayer_HintMessageEx_Pre()
{
	SetHookChainReturn(ATYPE_BOOL, false)

	return HC_SUPERCEDE
}