#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "DPManifestationComponent.generated.h"

class ADPManifestedObject;
class ADPCharacter;

/**
 * Lucid-dream object manifestation. Hold Q to picture the selected object; it appears in the player's hand.
 * Only works where the current zone allows it - in nightmares, nothing comes.
 * Manifesting too much at once counts as "forcefully changing your surroundings" (notebook rule 5).
 */
UCLASS(ClassGroup = (Dream))
class DREAMPROTOCOL_API UDPManifestationComponent : public UActorComponent
{
	GENERATED_BODY()

public:
	UDPManifestationComponent();

	void ResetUnlocks();
	void SetUnlocked(const TArray<FString>& Ids);
	const TArray<FString>& GetUnlocked() const { return Unlocked; }
	void Unlock(const FString& Id);

	bool TryManifest();
	void UseHeld();
	void ThrowHeld();
	void CycleSelection(int32 Direction);
	void ClearAll();

	/** Give the held object away (it is attached to the receiver). Returns false if not holding anything. */
	bool GiveHeldTo(USceneComponent* Receiver, const FVector& RelativeOffset);

	bool IsHolding(const FString& Id) const;
	AActor* GetHeldActor() const;
	FText GetSelectedName() const;
	int32 GetUnlockedCount() const { return Unlocked.Num(); }

private:
	ADPCharacter* GetCharacter() const;

	UPROPERTY()
	TObjectPtr<ADPManifestedObject> Held;

	TArray<TWeakObjectPtr<ADPManifestedObject>> Spawned;
	TArray<double> RecentManifestTimes;
	TArray<FString> Unlocked;
	TSet<FString> ThoughtShown;
	int32 Selected = 0;
	int32 FailedAttempts = 0;
};
