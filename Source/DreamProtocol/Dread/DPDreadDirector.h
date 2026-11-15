#pragma once

#include "CoreMinimal.h"
#include "Subsystems/WorldSubsystem.h"
#include "DPDreadDirector.generated.h"

/**
 * Turns the DREAD value into presentation: camera post-processing, the dread drone, distant sounds in
 * unobserved places, and a per-frame hook into the current zone (lighting flicker, entity behaviour).
 * Everything is scaled by the accessibility intensity settings.
 */
UCLASS()
class DREAMPROTOCOL_API UDPDreadDirector : public UTickableWorldSubsystem
{
	GENERATED_BODY()

public:
	virtual bool DoesSupportWorldType(const EWorldType::Type WorldType) const override;
	virtual void Tick(float DeltaTime) override;
	virtual TStatId GetStatId() const override { RETURN_QUICK_DECLARE_CYCLE_STAT(UDPDreadDirector, STATGROUP_Tickables); }

	void ResetDirector();

private:
	void UpdatePostProcess(class ADPCharacter* Player, float Dread, float DeltaTime);
	void UpdateDistantEvents(class ADPCharacter* Player, float Dread);

	float SmoothedDread = 0.f;
	double NextDistantEventTime = 0.0;
};
