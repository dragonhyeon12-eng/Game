#pragma once

#include "CoreMinimal.h"
#include "GameFramework/SaveGame.h"
#include "Core/DPTypes.h"
#include "DPSaveGame.generated.h"

/**
 * Checkpoint save. Written whenever the player enters a zone; Continue restores the zone start
 * with the story flags, notebook, DREAD values and unlocked manifestations intact.
 */
UCLASS()
class DREAMPROTOCOL_API UDPSaveGame : public USaveGame
{
	GENERATED_BODY()

public:
	UPROPERTY() int32 Version = 1;
	UPROPERTY() EDPZone Zone = EDPZone::Bedroom;
	UPROPERTY() TArray<FName> Flags;
	UPROPERTY() TArray<FDPRuleState> Rules;
	UPROPERTY() float Fear = 0.f;
	UPROPERTY() float Stability = 100.f;
	UPROPERTY() int32 MazeSeed = 0;
	UPROPERTY() TArray<FString> UnlockedManifests;

	static FString SlotName() { return TEXT("DreamProtocol_Checkpoint"); }
};
