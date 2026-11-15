#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "DPObserver.generated.h"

/**
 * The black silhouette. No face, no detail, no interaction.
 *
 * Rules he follows (and never breaks):
 *  - he never moves while observed: no walking, no turning, no relocating;
 *  - when unobserved he may turn to face the player again, or be somewhere else entirely;
 *  - he has no collision and is never interactable.
 *
 * Zones decide *where* he should be via RequestRelocation(); this actor decides *when* it is allowed.
 */
UCLASS()
class DREAMPROTOCOL_API ADPObserver : public AActor
{
	GENERATED_BODY()

public:
	ADPObserver();

	virtual void BeginPlay() override;
	virtual void Tick(float DeltaSeconds) override;

	/** Move to Location the next time neither the current nor the target position is observed. */
	void RequestRelocation(const FVector& GroundLocation);
	/** Vanish the next time he is unobserved. */
	void RequestVanish();
	/** Appear at Location immediately, but only if that point is unobserved. Returns success. */
	bool TryAppearAt(const FVector& GroundLocation);
	void HideNow();

	bool IsPresent() const { return !IsHidden(); }
	bool IsObservedNow() const { return bObserved; }
	/** Seconds the player has been looking at him continuously. */
	float GetObservedTime() const { return ObservedTime; }
	float GetUnobservedTime() const { return UnobservedTime; }
	bool HasPendingMove() const { return bPendingMove || bPendingVanish; }

	/** Called once each time he has been looked at for at least SeenThreshold seconds. */
	TFunction<void(ADPObserver*)> OnSeen;
	float SeenThreshold = 0.6f;
	/** Only counts as seen within this distance (he is easy to overlook far away). */
	float SeenMaxDistance = 9000.f;

private:
	bool IsPointObserved(const FVector& Point) const;
	FVector BodyCenter(const FVector& Ground) const { return Ground + FVector(0.f, 0.f, 95.f); }

	UPROPERTY()
	TObjectPtr<USceneComponent> Root;

	bool bObserved = false;
	float ObservedTime = 0.f;
	float UnobservedTime = 0.f;
	bool bSeenReported = false;

	bool bPendingMove = false;
	bool bPendingVanish = false;
	FVector PendingLocation = FVector::ZeroVector;
	float CheckAccumulator = 0.f;
};
