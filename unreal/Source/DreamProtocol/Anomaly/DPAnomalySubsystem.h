#pragma once

#include "CoreMinimal.h"
#include "Subsystems/WorldSubsystem.h"
#include "Core/DPTypes.h"
#include "DPAnomalySubsystem.generated.h"

/**
 * A reusable environmental event: "something here may change while nobody is looking".
 *
 * Zones register anomalies with a location, conditions and an Apply function. The subsystem decides
 * *when* any of them fire, based on dream stability, so individual zones never need a giant script.
 * When the player later sees a changed anomaly, it counts as a discovered inconsistency (fear).
 */
struct FDPAnomaly
{
	FName Id;
	FVector Location = FVector::ZeroVector;
	float Radius = 150.f;

	EDPDreadStage MinStage = EDPDreadStage::Calm;
	/** Must have been out of view this long before it may change. */
	float MinUnobservedSeconds = 2.f;
	float Weight = 1.f;
	/** -1 = unlimited. */
	int32 MaxChanges = -1;
	/** Player must be within this distance for the change to matter. */
	float MaxPlayerDistance = 4000.f;
	/** Fear applied when the player notices the change. */
	float DiscoveryFear = 3.f;

	TFunction<bool()> CanApply;
	TFunction<void()> Apply;
	/** Optional: location may move (e.g. a relocated prop). */
	TFunction<FVector()> GetLocation;

	TWeakObjectPtr<UObject> Owner;

	// Runtime
	float UnobservedFor = 0.f;
	bool bAwaitingDiscovery = false;
	int32 Changes = 0;
};

UCLASS()
class DREAMPROTOCOL_API UDPAnomalySubsystem : public UTickableWorldSubsystem
{
	GENERATED_BODY()

public:
	virtual bool DoesSupportWorldType(const EWorldType::Type WorldType) const override;
	virtual void Tick(float DeltaTime) override;
	virtual TStatId GetStatId() const override { RETURN_QUICK_DECLARE_CYCLE_STAT(UDPAnomalySubsystem, STATGROUP_Tickables); }

	void Register(FDPAnomaly&& Anomaly);
	void UnregisterOwner(const UObject* Owner);
	void Clear();

	/**
	 * Base seconds between changes at full stability, and at zero stability.
	 * Zones set these (the summer city sets "never").
	 */
	void SetPacing(float SecondsWhenStable, float SecondsWhenUnstable);

	int32 GetTotalChanges() const { return TotalChanges; }

private:
	void ScheduleNext(float Stability);

	TArray<FDPAnomaly> Anomalies;
	float Accumulator = 0.f;
	double NextChangeTime = 0.0;
	float StablePacing = -1.f;
	float UnstablePacing = 6.f;
	int32 TotalChanges = 0;
};
