#include "Dread/DPDreadDirector.h"
#include "Dread/DPDreadComponent.h"
#include "Core/DPCharacter.h"
#include "Core/DPGameMode.h"
#include "Core/DPObservation.h"
#include "Core/DPSettings.h"
#include "World/DPZone.h"
#include "Camera/CameraComponent.h"
#include "Kismet/GameplayStatics.h"
#include "Engine/World.h"

bool UDPDreadDirector::DoesSupportWorldType(const EWorldType::Type WorldType) const
{
	return WorldType == EWorldType::Game || WorldType == EWorldType::PIE;
}

void UDPDreadDirector::ResetDirector()
{
	SmoothedDread = 0.f;
	NextDistantEventTime = GetWorld()->GetTimeSeconds() + 40.0;
}

void UDPDreadDirector::Tick(float DeltaTime)
{
	ADPCharacter* Player = Cast<ADPCharacter>(UGameplayStatics::GetPlayerPawn(GetWorld(), 0));
	if (!Player)
	{
		return;
	}
	const UDPDreadComponent* Dread = Player->GetDread();
	SmoothedDread = FMath::FInterpTo(SmoothedDread, Dread->GetDreadAlpha(), DeltaTime, 1.5f);

	UpdatePostProcess(Player, SmoothedDread, DeltaTime);

	const float DroneLevel = FMath::SmoothStep(0.2f, 1.f, SmoothedDread) * 1.2f;
	Player->SetDroneIntensity(Dread->IsNightmare() ? DroneLevel : 0.f);

	if (ADPGameMode* GM = ADPGameMode::Get(this))
	{
		if (ADPZone* Zone = GM->GetZone())
		{
			Zone->OnDreadUpdate(SmoothedDread * 100.f, Dread->GetStage(), DeltaTime);
		}
		if (!GM->IsInSequence())
		{
			UpdateDistantEvents(Player, SmoothedDread);
		}
	}
}

void UDPDreadDirector::UpdatePostProcess(ADPCharacter* Player, float D, float DeltaTime)
{
	const UDPSettingsSave& S = DPSettings::Get(this);
	const float V = FMath::Clamp(S.VisualIntensity, 0.f, 1.f);
	const float A = D * V;

	FPostProcessSettings& PP = Player->GetCamera()->PostProcessSettings;

	PP.bOverride_VignetteIntensity = true;
	PP.VignetteIntensity = 0.35f + 0.75f * A;

	PP.bOverride_FilmGrainIntensity = true;
	PP.FilmGrainIntensity = FMath::Max(0.f, (D - 0.25f)) * 0.55f * V;

	PP.bOverride_SceneFringeIntensity = true;
	PP.SceneFringeIntensity = FMath::Max(0.f, D - 0.5f) * 3.f * V;

	PP.bOverride_ColorSaturation = true;
	const float Sat = 1.f - 0.45f * A;
	PP.ColorSaturation = FVector4(Sat, Sat, Sat, 1.f);

	PP.bOverride_AutoExposureBias = true;
	PP.AutoExposureBias = -0.7f * A;
}

void UDPDreadDirector::UpdateDistantEvents(ADPCharacter* Player, float D)
{
	const UDPDreadComponent* Dread = Player->GetDread();
	if (!Dread->IsNightmare() || Dread->GetStage() == EDPDreadStage::Calm)
	{
		return;
	}
	const double Now = GetWorld()->GetTimeSeconds();
	if (NextDistantEventTime == 0.0)
	{
		NextDistantEventTime = Now + 30.0;
	}
	if (Now < NextDistantEventTime)
	{
		return;
	}

	// Something knocks, somewhere you are not looking.
	DPObservation::FView View;
	if (!DPObservation::GetPlayerView(GetWorld(), View))
	{
		return;
	}
	const float Yaw = View.Rotation.Yaw + 180.f + FMath::FRandRange(-60.f, 60.f);
	const FVector Dir = FRotator(0.f, Yaw, 0.f).Vector();
	const FVector Where = Player->GetActorLocation() + Dir * FMath::FRandRange(1200.f, 2400.f);

	Player->PlayEventAt(FMath::FRand() < 0.7f ? EDPSynthEvent::Knock : EDPSynthEvent::Thud, Where, 0.6f + 0.6f * D);
	Player->GetDread()->NotifySuspiciousEvent();

	NextDistantEventTime = Now + FMath::Lerp(70.0, 20.0, static_cast<double>(D)) * FMath::FRandRange(0.8f, 1.3f);
}
