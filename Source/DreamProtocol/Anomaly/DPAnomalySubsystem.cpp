#include "Anomaly/DPAnomalySubsystem.h"
#include "Core/DPCharacter.h"
#include "Core/DPObservation.h"
#include "Dread/DPDreadComponent.h"
#include "DreamProtocol.h"
#include "Kismet/GameplayStatics.h"
#include "Engine/World.h"

namespace
{
	constexpr float CheckInterval = 0.25f;
	constexpr float DiscoveryDistance = 2500.f;
}

bool UDPAnomalySubsystem::DoesSupportWorldType(const EWorldType::Type WorldType) const
{
	return WorldType == EWorldType::Game || WorldType == EWorldType::PIE;
}

void UDPAnomalySubsystem::Register(FDPAnomaly&& Anomaly)
{
	Anomalies.Add(MoveTemp(Anomaly));
}

void UDPAnomalySubsystem::UnregisterOwner(const UObject* Owner)
{
	Anomalies.RemoveAll([Owner](const FDPAnomaly& A) { return !A.Owner.IsValid() || A.Owner.Get() == Owner; });
}

void UDPAnomalySubsystem::Clear()
{
	Anomalies.Reset();
	TotalChanges = 0;
	StablePacing = -1.f;
}

void UDPAnomalySubsystem::SetPacing(float SecondsWhenStable, float SecondsWhenUnstable)
{
	StablePacing = SecondsWhenStable;
	UnstablePacing = SecondsWhenUnstable;
	NextChangeTime = GetWorld()->GetTimeSeconds() + FMath::Max(8.f, SecondsWhenStable * 0.5f);
}

void UDPAnomalySubsystem::ScheduleNext(float Stability)
{
	if (StablePacing < 0.f)
	{
		NextChangeTime = TNumericLimits<double>::Max();
		return;
	}
	const float Instability = 1.f - FMath::Clamp(Stability / 100.f, 0.f, 1.f);
	// Quadratic: stays calm-ish until stability is really slipping.
	const float Seconds = FMath::Lerp(StablePacing, UnstablePacing, Instability * Instability);
	NextChangeTime = GetWorld()->GetTimeSeconds() + Seconds * FMath::FRandRange(0.7f, 1.3f);
}

void UDPAnomalySubsystem::Tick(float DeltaTime)
{
	Accumulator += DeltaTime;
	if (Accumulator < CheckInterval || Anomalies.Num() == 0)
	{
		return;
	}
	const float Dt = Accumulator;
	Accumulator = 0.f;

	ADPCharacter* Player = Cast<ADPCharacter>(UGameplayStatics::GetPlayerPawn(GetWorld(), 0));
	if (!Player || Player->AreControlsLocked())
	{
		return;
	}
	UDPDreadComponent* Dread = Player->GetDread();
	const FVector PlayerLoc = Player->GetActorLocation();
	const EDPDreadStage Stage = Dread->GetStage();

	// 1) Observation bookkeeping + discovery of earlier changes.
	for (FDPAnomaly& A : Anomalies)
	{
		if (A.GetLocation)
		{
			A.Location = A.GetLocation();
		}
		const bool bObserved = DPObservation::IsObserved(GetWorld(), A.Location, A.Radius);
		if (bObserved)
		{
			A.UnobservedFor = 0.f;
			if (A.bAwaitingDiscovery && FVector::Dist(PlayerLoc, A.Location) < DiscoveryDistance)
			{
				A.bAwaitingDiscovery = false;
				Dread->AddFear(A.DiscoveryFear, TEXT("AnomalyDiscovered"));
				Dread->NotifySuspiciousEvent();
			}
		}
		else
		{
			A.UnobservedFor += Dt;
		}
	}

	// 2) Maybe change something.
	const double Now = GetWorld()->GetTimeSeconds();
	if (NextChangeTime == 0.0)
	{
		ScheduleNext(Dread->GetStability());
	}
	if (Now < NextChangeTime)
	{
		return;
	}

	float TotalWeight = 0.f;
	TArray<int32> Candidates;
	for (int32 i = 0; i < Anomalies.Num(); ++i)
	{
		const FDPAnomaly& A = Anomalies[i];
		if (static_cast<uint8>(Stage) < static_cast<uint8>(A.MinStage)) continue;
		if (A.MaxChanges >= 0 && A.Changes >= A.MaxChanges) continue;
		if (A.UnobservedFor < A.MinUnobservedSeconds) continue;
		const float Dist = FVector::Dist(PlayerLoc, A.Location);
		if (Dist > A.MaxPlayerDistance || Dist < A.Radius + 120.f) continue;
		if (A.CanApply && !A.CanApply()) continue;
		Candidates.Add(i);
		TotalWeight += A.Weight;
	}

	if (Candidates.Num() > 0 && TotalWeight > 0.f)
	{
		float Pick = FMath::FRand() * TotalWeight;
		for (int32 Index : Candidates)
		{
			FDPAnomaly& A = Anomalies[Index];
			Pick -= A.Weight;
			if (Pick <= 0.f)
			{
				if (A.Apply)
				{
					A.Apply();
				}
				++A.Changes;
				++TotalChanges;
				A.bAwaitingDiscovery = A.DiscoveryFear > 0.f;
				UE_LOG(LogDream, Verbose, TEXT("Anomaly '%s' changed (unobserved)"), *A.Id.ToString());
				break;
			}
		}
	}

	ScheduleNext(Dread->GetStability());
}
