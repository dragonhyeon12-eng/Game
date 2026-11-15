#include "Dread/DPDreadComponent.h"
#include "DreamProtocol.h"
#include "GameFramework/Pawn.h"
#include "GameFramework/Controller.h"
#include "Engine/World.h"

#define LOCTEXT_NAMESPACE "DPDread"

FText DPDread::StageName(EDPDreadStage Stage)
{
	switch (Stage)
	{
	case EDPDreadStage::Uneasy:      return LOCTEXT("Uneasy", "UNEASY");
	case EDPDreadStage::Afraid:      return LOCTEXT("Afraid", "AFRAID");
	case EDPDreadStage::Terrified:   return LOCTEXT("Terrified", "TERRIFIED");
	case EDPDreadStage::Overwhelmed: return LOCTEXT("Overwhelmed", "OVERWHELMED");
	default:                         return LOCTEXT("Calm", "CALM");
	}
}

namespace
{
	// Tuning. Kept together so the feedback loop can be balanced in one place.
	constexpr float FearWeight = 0.65f;           // share of DREAD from fear
	constexpr float InstabilityWeight = 0.35f;    // share of DREAD from (100 - stability)
	constexpr float CalmDelayBeforeDecay = 5.f;   // seconds without new fear before it starts decaying
	constexpr float StabilityFallRate = 6.f;      // per second, toward (100 - fear)
	constexpr float StabilityPanicFallRate = 11.f;// when fear > 70
	constexpr float StabilityRecoverRate = 1.2f;  // per second, slow on purpose

	constexpr float TurnWindowSeconds = 0.45f;
	constexpr float TurnAroundDegrees = 135.f;
	constexpr float TurnCooldown = 1.0f;
	constexpr float CheckingBehindWindow = 12.f;  // turn-arounds counted inside this window
	constexpr int32 CheckingBehindCount = 3;      // ...this many before it is considered panic
	constexpr float SuspiciousWindow = 4.f;
}

UDPDreadComponent::UDPDreadComponent()
{
	PrimaryComponentTick.bCanEverTick = true;
}

float UDPDreadComponent::GetDread() const
{
	return FMath::Clamp(Fear * FearWeight + (100.f - Stability) * InstabilityWeight, 0.f, 100.f);
}

void UDPDreadComponent::AddFear(float Amount, FName Reason)
{
	if (Amount > 0.f)
	{
		Amount *= GainMultiplier;
		LastFearTime = GetWorld()->GetTimeSeconds();
	}
	Fear = FMath::Clamp(Fear + Amount, 0.f, 100.f);
	UE_LOG(LogDream, Verbose, TEXT("Fear %+.1f (%s) -> %.1f"), Amount, *Reason.ToString(), Fear);
}

void UDPDreadComponent::AddStability(float Delta)
{
	Stability = FMath::Clamp(Stability + Delta, 0.f, 100.f);
}

void UDPDreadComponent::SetValues(float InFear, float InStability)
{
	Fear = FMath::Clamp(InFear, 0.f, 100.f);
	Stability = FMath::Clamp(InStability, 0.f, 100.f);
	CurrentStage = DPDread::StageFromValue(GetDread());
	bOverwhelmedFired = false;
	TurnAroundTimes.Reset();
}

void UDPDreadComponent::SetZoneProfile(bool bInNightmare, float InGainMultiplier, float InFloor, float InDecayPerSecond)
{
	bNightmare = bInNightmare;
	GainMultiplier = InGainMultiplier;
	FearFloor = InFloor;
	DecayPerSecond = InDecayPerSecond;
}

void UDPDreadComponent::NotifySuspiciousEvent()
{
	LastSuspiciousTime = GetWorld()->GetTimeSeconds();
}

void UDPDreadComponent::TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction)
{
	Super::TickComponent(DeltaTime, TickType, ThisTickFunction);

	const double Now = GetWorld()->GetTimeSeconds();
	TrackLookBehind(Now);

	// Fear decays after a calm period, toward the zone's floor (the floor can also pull fear up slowly).
	if (Now - LastFearTime > CalmDelayBeforeDecay && Fear > FearFloor)
	{
		Fear = FMath::Max(FearFloor, Fear - DecayPerSecond * DeltaTime);
	}
	else if (Fear < FearFloor)
	{
		Fear = FMath::Min(FearFloor, Fear + 0.5f * DeltaTime);
	}

	// Stability chases (100 - fear): quickly downward, slowly upward.
	const float Target = 100.f - Fear;
	if (Stability > Target)
	{
		const float Rate = Fear > 70.f ? StabilityPanicFallRate : StabilityFallRate;
		Stability = FMath::Max(Target, Stability - Rate * DeltaTime);
	}
	else
	{
		Stability = FMath::Min(Target, Stability + StabilityRecoverRate * DeltaTime);
	}

	const float Dread = GetDread();
	const EDPDreadStage NewStage = DPDread::StageFromValue(Dread);
	if (NewStage != CurrentStage)
	{
		const EDPDreadStage Old = CurrentStage;
		CurrentStage = NewStage;
		OnStageChanged.Broadcast(Old, NewStage);
	}

	if (NewStage == EDPDreadStage::Overwhelmed && !bOverwhelmedFired && bNightmare)
	{
		bOverwhelmedFired = true;
		OnOverwhelmed.Broadcast();
	}
	else if (Dread < 80.f)
	{
		bOverwhelmedFired = false;
	}
}

void UDPDreadComponent::TrackLookBehind(double Now)
{
	const APawn* Pawn = Cast<APawn>(GetOwner());
	const AController* Controller = Pawn ? Pawn->GetController() : nullptr;
	if (!Controller)
	{
		return;
	}

	const float Yaw = Controller->GetControlRotation().Yaw;
	if (!bHasYaw)
	{
		bHasYaw = true;
		PrevYaw = Yaw;
	}
	UnwrappedYaw += FMath::FindDeltaAngleDegrees(PrevYaw, Yaw);
	PrevYaw = Yaw;

	YawHistory.Add(TPair<double, float>(Now, UnwrappedYaw));
	while (YawHistory.Num() > 1 && Now - YawHistory[0].Key > TurnWindowSeconds)
	{
		YawHistory.RemoveAt(0);
	}

	if (YawHistory.Num() < 2 || Now - LastTurnAroundTime < TurnCooldown)
	{
		return;
	}

	if (FMath::Abs(UnwrappedYaw - YawHistory[0].Value) < TurnAroundDegrees)
	{
		return;
	}

	// A sharp turn-around.
	LastTurnAroundTime = Now;
	YawHistory.Reset();
	OnTurnAround.Broadcast();

	if (!bNightmare)
	{
		return; // never punish looking around in safe spaces
	}

	// One quick look over the shoulder is normal. Only *repeatedly* checking behind feeds fear.
	TurnAroundTimes.Add(Now);
	TurnAroundTimes.RemoveAll([Now](double T) { return Now - T > CheckingBehindWindow; });

	if (TurnAroundTimes.Num() >= CheckingBehindCount)
	{
		AddFear(4.f + 2.f * (TurnAroundTimes.Num() - CheckingBehindCount), TEXT("CheckingBehind"));
	}
	else if (Now - LastSuspiciousTime < SuspiciousWindow)
	{
		AddFear(3.f, TEXT("StartledTurn"));
	}
}

#undef LOCTEXT_NAMESPACE
