#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "Core/DPTypes.h"
#include "DPDreadComponent.generated.h"

/**
 * DREAD = the player's FEAR combined with the dream's STABILITY.
 *
 *   fear rises  -> stability falls toward (100 - fear)  -> anomalies become more frequent  -> more fear
 *
 * Fear decays when nothing frightening happens for a while (down to the zone's floor). Stability recovers
 * much more slowly than it falls, so a frightened dream stays broken for a while after the scare.
 * Zones set a profile: the summer city multiplies fear gains down so the opening stays comforting.
 */
UCLASS(ClassGroup = (Dream), meta = (BlueprintSpawnableComponent))
class DREAMPROTOCOL_API UDPDreadComponent : public UActorComponent
{
	GENERATED_BODY()

public:
	UDPDreadComponent();

	virtual void TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction) override;

	/** Positive amounts are scaled by the zone's gain multiplier. */
	void AddFear(float Amount, FName Reason);
	void AddStability(float Delta);
	void SetValues(float InFear, float InStability);
	void SetZoneProfile(bool bInNightmare, float InGainMultiplier, float InFloor, float InDecayPerSecond);

	/** Something unnatural was just witnessed: sudden camera moves in the next few seconds count as panic. */
	void NotifySuspiciousEvent();

	float GetFear() const { return Fear; }
	float GetStability() const { return Stability; }
	/** 0..100, what the meter shows. */
	float GetDread() const;
	float GetDreadAlpha() const { return GetDread() / 100.f; }
	EDPDreadStage GetStage() const { return CurrentStage; }
	bool IsNightmare() const { return bNightmare; }
	double GetLastTurnAroundTime() const { return LastTurnAroundTime; }

	DECLARE_MULTICAST_DELEGATE_TwoParams(FDPStageChanged, EDPDreadStage /*Old*/, EDPDreadStage /*New*/);
	FDPStageChanged OnStageChanged;

	FSimpleMulticastDelegate OnOverwhelmed;

	/** Turn-around detection: a fast >=135 degree yaw swing. Broadcast for the director. */
	FSimpleMulticastDelegate OnTurnAround;

private:
	void TrackLookBehind(double Now);

	float Fear = 0.f;
	float Stability = 100.f;

	bool bNightmare = false;
	float GainMultiplier = 1.f;
	float FearFloor = 0.f;
	float DecayPerSecond = 1.5f;

	double LastFearTime = -1000.0;
	double LastSuspiciousTime = -1000.0;
	double LastTurnAroundTime = -1000.0;

	// Look-behind tracking
	bool bHasYaw = false;
	float PrevYaw = 0.f;
	float UnwrappedYaw = 0.f;
	TArray<TPair<double, float>> YawHistory;
	TArray<double> TurnAroundTimes;

	EDPDreadStage CurrentStage = EDPDreadStage::Calm;
	bool bOverwhelmedFired = false;
};
