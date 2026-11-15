#pragma once

#include "CoreMinimal.h"
#include "DPTypes.generated.h"

/** The playable spaces of the vertical slice. Only one zone exists in the world at a time. */
UENUM(BlueprintType)
enum class EDPZone : uint8
{
	None,
	Bedroom,
	SummerCity,
	Maze
};

/** Displayed DREAD stages. Thresholds live in DPDread::StageFromValue. */
UENUM(BlueprintType)
enum class EDPDreadStage : uint8
{
	Calm,
	Uneasy,
	Afraid,
	Terrified,
	Overwhelmed
};

/** Whose handwriting a notebook line appears in. */
UENUM()
enum class EDPInkStyle : uint8
{
	Player,   // the player's own handwriting
	Pressed,  // the player's handwriting, pressed hard into the page (they don't remember writing it)
	Unknown,  // somebody else's handwriting
	Smudged   // faded / scratched out
};

/** Persistent state of one notebook rule. Saved in checkpoints. */
USTRUCT()
struct FDPRuleState
{
	GENERATED_BODY()

	UPROPERTY() FString Id;
	UPROPERTY() bool bWritten = false;
	UPROPERTY() bool bHidden = false;
	UPROPERTY() bool bPendingReveal = false;
	UPROPERTY() FString VariantId;
	UPROPERTY() int32 BreakCount = 0;
	UPROPERTY() int32 ReadsWhileVisible = 0;
};

namespace DPDread
{
	inline EDPDreadStage StageFromValue(float Dread)
	{
		if (Dread >= 99.5f) return EDPDreadStage::Overwhelmed;
		if (Dread >= 75.f)  return EDPDreadStage::Terrified;
		if (Dread >= 50.f)  return EDPDreadStage::Afraid;
		if (Dread >= 25.f)  return EDPDreadStage::Uneasy;
		return EDPDreadStage::Calm;
	}

	DREAMPROTOCOL_API FText StageName(EDPDreadStage Stage);
}
