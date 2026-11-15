#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameModeBase.h"
#include "Core/DPTypes.h"
#include "DPGameMode.generated.h"

class ADPZone;
class ADPCharacter;
class ADPPlayerController;
class ADPHUD;
class UDPSaveGame;

/**
 * Story flow for the vertical slice:
 *
 *   Title (over the bedroom) -> Bedroom: watch tutorial, take notebook, sleep
 *   -> Summer city: manifest, talk, notice (or not) the Observer, hold T to wake
 *   -> fall through the floor -> Yellow maze: find the exit -> end of slice
 *   DREAD 100 in a nightmare -> "You woke up. / Didn't you?" -> back to the last checkpoint
 *
 * Holds story flags, builds/destroys zones, writes checkpoints and runs short scripted sequences.
 * Everything resets in place (no level reloads), so the game works in a single empty map.
 */
UCLASS()
class DREAMPROTOCOL_API ADPGameMode : public AGameModeBase
{
	GENERATED_BODY()

public:
	ADPGameMode();

	static ADPGameMode* Get(const UObject* WorldContext);

	virtual void BeginPlay() override;
	virtual void RestartPlayer(AController* NewPlayer) override;

	// ---- Flow
	void ShowTitle();
	void StartNewGame();
	void ContinueGame();
	void ReturnToTitle();
	bool HasCheckpoint() const;
	void SaveCheckpoint();

	// ---- Story events
	void RequestTutorial();
	void OnTutorialFinished();
	void RequestSleep();
	void RequestWake();
	void OnMazeExitReached();

	// ---- State
	bool HasFlag(FName Flag) const { return Flags.Contains(Flag); }
	void SetFlag(FName Flag) { Flags.Add(Flag); }
	void ClearFlag(FName Flag) { Flags.Remove(Flag); }

	ADPZone* GetZone() const { return CurrentZone; }
	EDPZone GetZoneType() const { return CurrentZoneType; }
	bool IsInSequence() const { return bInSequence; }

	void ApplySettingsEverywhere();

	ADPHUD* GetDPHUD() const;
	ADPPlayerController* GetDPController() const;
	ADPCharacter* GetDPCharacter() const;

private:
	void EnterZone(EDPZone Zone, bool bFromSave, bool bWakingVariant = false);
	void PlacePlayer();
	void ResetWorldState();
	bool RestoreCheckpoint(float FearOverride = -1.f, float StabilityOverride = -1.f);
	void BindPlayer();
	void OnOverwhelmed();
	void PlayDeathSequence();

	/** Schedule part of a scripted sequence. Cleared on reset. */
	void After(float Seconds, TFunction<void()> Fn);
	void ClearSequence();

	UPROPERTY()
	TObjectPtr<ADPZone> CurrentZone;

	EDPZone CurrentZoneType = EDPZone::None;
	TSet<FName> Flags;
	int32 MazeSeed = 1;
	bool bInSequence = false;
	TArray<FTimerHandle> SequenceTimers;
	TWeakObjectPtr<ADPCharacter> BoundCharacter;
};
