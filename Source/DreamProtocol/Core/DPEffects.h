#pragma once

#include "CoreMinimal.h"

class ADPNPC;

/**
 * Data-driven effect strings, used by dialogue, notebook rules and story scripts.
 *
 *   fear:+10 | fear:-5              add fear (zone multiplier applies to positive values)
 *   stability:-10                   change dream stability
 *   flag:name | unflag:name         story flags
 *   rule:break:<rule id>            break a notebook rule (runs that rule's OnBreak effects)
 *   notebook:write:<id>             player writes a rule (visible now)
 *   notebook:reveal:<id>            rule appears the next time the notebook is opened
 *   notebook:hide:<id>              rule disappears
 *   notebook:rewrite:<id>:<variant> rule text changes
 *   observer:closer                 the Observer relocates nearer (only while unobserved)
 *   thought:<text>                  inner-monologue subtitle
 *   hint:<text>                     control hint
 *   unlock:<manifest id>            unlock a manifestable object
 *   manifest:give                   hand the held object to the current speaker
 *   sound:page|knock|thud|chime     foley
 */
namespace DPEffects
{
	struct FContext
	{
		ADPNPC* Speaker = nullptr;
	};

	DREAMPROTOCOL_API void Apply(UWorld* World, const FString& Effect, const FContext& Context = FContext());
	DREAMPROTOCOL_API void ApplyAll(UWorld* World, const TArray<FString>& Effects, const FContext& Context = FContext());

	/** Evaluates a dialogue condition: a story flag, or "holding:<manifest id>". Empty = true. */
	DREAMPROTOCOL_API bool CheckCondition(UWorld* World, const FString& Condition);
}
