#include "Core/DPObservation.h"
#include "Engine/Engine.h"
#include "Engine/GameViewportClient.h"
#include "Engine/World.h"
#include "GameFramework/PlayerController.h"
#include "Camera/PlayerCameraManager.h"

bool DPObservation::GetPlayerView(const UWorld* World, FView& OutView)
{
	if (!World)
	{
		return false;
	}
	const APlayerController* PC = World->GetFirstPlayerController();
	if (!PC || !PC->PlayerCameraManager)
	{
		return false;
	}

	OutView.Location = PC->PlayerCameraManager->GetCameraLocation();
	OutView.Rotation = PC->PlayerCameraManager->GetCameraRotation();

	const float FovH = PC->PlayerCameraManager->GetFOVAngle();
	float Aspect = 16.f / 9.f;
	if (GEngine && GEngine->GameViewport)
	{
		FVector2D Size;
		GEngine->GameViewport->GetViewportSize(Size);
		if (Size.Y > 1.f)
		{
			Aspect = Size.X / Size.Y;
		}
	}
	OutView.HalfFovH = FovH * 0.5f;
	OutView.HalfFovV = FMath::RadiansToDegrees(FMath::Atan(FMath::Tan(FMath::DegreesToRadians(OutView.HalfFovH)) / Aspect));
	return true;
}

bool DPObservation::IsInView(const FView& View, const FVector& Point, float Radius, float MarginDegrees)
{
	const FVector ToPoint = Point - View.Location;
	const float Dist = ToPoint.Size();
	if (Dist <= Radius + 1.f)
	{
		return true; // we are inside it
	}

	const FRotationMatrix M(View.Rotation);
	const float Fwd = FVector::DotProduct(ToPoint, M.GetUnitAxis(EAxis::X));
	const float Right = FVector::DotProduct(ToPoint, M.GetUnitAxis(EAxis::Y));
	const float Up = FVector::DotProduct(ToPoint, M.GetUnitAxis(EAxis::Z));

	const float AngularRadius = FMath::RadiansToDegrees(FMath::Asin(FMath::Clamp(Radius / Dist, 0.f, 1.f)));
	if (Fwd <= 0.f)
	{
		// Behind the camera plane. Only visible if the sphere pokes into view.
		const float BehindAngle = FMath::RadiansToDegrees(FMath::Acos(FMath::Clamp(Fwd / Dist, -1.f, 1.f)));
		return BehindAngle - AngularRadius < View.HalfFovH + MarginDegrees;
	}

	const float AngH = FMath::Abs(FMath::RadiansToDegrees(FMath::Atan2(Right, Fwd)));
	const float AngV = FMath::Abs(FMath::RadiansToDegrees(FMath::Atan2(Up, Fwd)));
	return (AngH - AngularRadius) < (View.HalfFovH + MarginDegrees) && (AngV - AngularRadius) < (View.HalfFovV + MarginDegrees);
}

static bool TraceClear(const UWorld* World, const FVector& From, const FVector& To, const TArray<const AActor*>& IgnoreActors)
{
	FCollisionQueryParams Params(SCENE_QUERY_STAT(DPObservation), false);
	if (const APlayerController* PC = World->GetFirstPlayerController())
	{
		Params.AddIgnoredActor(PC->GetPawn());
	}
	for (const AActor* A : IgnoreActors)
	{
		Params.AddIgnoredActor(A);
	}
	FHitResult Hit;
	return !World->LineTraceSingleByChannel(Hit, From, To, ECC_Visibility, Params);
}

bool DPObservation::IsObserved(const UWorld* World, const FVector& Point, float Radius,
	const TArray<const AActor*>& IgnoreActors, float MarginDegrees)
{
	FView View;
	if (!GetPlayerView(World, View))
	{
		return false;
	}
	if (!IsInView(View, Point, Radius, MarginDegrees))
	{
		return false;
	}

	// Several sample points: if any is visible, the thing is observed.
	const FVector Samples[] =
	{
		Point,
		Point + FVector(0, 0, Radius * 0.8f),
		Point - FVector(0, 0, Radius * 0.6f),
	};
	for (const FVector& S : Samples)
	{
		if (TraceClear(World, View.Location, S, IgnoreActors))
		{
			return true;
		}
	}
	return false;
}

bool DPObservation::HasLineOfSight(const UWorld* World, const FVector& Point, const TArray<const AActor*>& IgnoreActors)
{
	FView View;
	if (!GetPlayerView(World, View))
	{
		return false;
	}
	return TraceClear(World, View.Location, Point, IgnoreActors);
}
