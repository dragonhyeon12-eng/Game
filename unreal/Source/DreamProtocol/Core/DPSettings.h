#pragma once

#include "CoreMinimal.h"
#include "GameFramework/SaveGame.h"
#include "DPSettings.generated.h"

/**
 * Player-facing options, including the accessibility controls for horror intensity.
 * Stored in its own save slot so it survives New Game.
 */
UCLASS()
class DREAMPROTOCOL_API UDPSettingsSave : public USaveGame
{
	GENERATED_BODY()

public:
	UPROPERTY() float MouseSensitivity = 1.f;
	UPROPERTY() bool bInvertY = false;
	UPROPERTY() float FieldOfView = 90.f;

	/** Walking head bob. */
	UPROPERTY() bool bHeadBob = true;
	/** Camera jolts / kicks during scripted moments. */
	UPROPERTY() bool bCameraEffects = true;

	/** 0..1. Scales DREAD post-processing (vignette, grain, desaturation, fringe) and light flicker depth. */
	UPROPERTY() float VisualIntensity = 1.f;
	/** 0..1. Scales horror audio (drone, distant knocks, hum intensity). */
	UPROPERTY() float AudioIntensity = 1.f;
	UPROPERTY() float MasterVolume = 1.f;

	UPROPERTY() float TextScale = 1.f;
	UPROPERTY() bool bShowDreadMeter = true;

	/** Allow the pause menu to become corrupted during high DREAD. */
	UPROPERTY() bool bMenuCorruption = true;
	/** Allow the game to (rarely) unpause itself during high DREAD. */
	UPROPERTY() bool bSelfUnpause = true;

	static FString SlotName() { return TEXT("DreamProtocol_Settings"); }
};

namespace DPSettings
{
	/** Current settings (never null; falls back to defaults). */
	DREAMPROTOCOL_API const UDPSettingsSave& Get(const UObject* WorldContext);
}
