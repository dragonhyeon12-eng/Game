#include "NPC/DPObserver.h"
#include "Core/DPObservation.h"
#include "Core/DPShapes.h"
#include "Components/StaticMeshComponent.h"
#include "Kismet/GameplayStatics.h"
#include "Engine/World.h"

ADPObserver::ADPObserver()
{
	PrimaryActorTick.bCanEverTick = true;
	SetActorEnableCollision(false);

	Root = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
	RootComponent = Root;
}

static void BuildSilhouette(ADPObserver* Self, USceneComponent* Root)
{
	// "As though lighting failed to render his model." An artist can override with an unlit black
	// material at /Game/DreamProtocol/Materials/M_ObserverVoid.
	UMaterialInterface* Void = DPShapes::FindArtOverride(TEXT("M_ObserverVoid"));
	if (!Void)
	{
		Void = DPShapes::MakeColorMaterial(Self, FLinearColor(0.f, 0.f, 0.f));
	}

	auto Part = [Self, Root, Void](EDPShape Shape, const FVector& Loc, const FVector& Scale, const FRotator& Rot = FRotator::ZeroRotator)
	{
		UStaticMeshComponent* C = DPShapes::AddShape(Self, Root, Shape, FTransform(Rot, Loc, Scale), Void, false);
		C->SetCastShadow(true);
		return C;
	};

	// Slightly too tall, slightly too thin, arms slightly too long. Nothing you could point at.
	Part(EDPShape::Cylinder, FVector(0.f, -9.f, 48.f), FVector(0.12f, 0.12f, 0.96f));          // legs
	Part(EDPShape::Cylinder, FVector(0.f, 9.f, 48.f), FVector(0.12f, 0.12f, 0.96f));
	Part(EDPShape::Cylinder, FVector(0.f, 0.f, 128.f), FVector(0.34f, 0.22f, 0.68f));          // torso
	Part(EDPShape::Sphere, FVector(0.f, 0.f, 160.f), FVector(0.36f, 0.24f, 0.18f));            // shoulders
	Part(EDPShape::Cylinder, FVector(0.f, -22.f, 118.f), FVector(0.08f, 0.08f, 0.82f), FRotator(0.f, 0.f, -3.f)); // arms
	Part(EDPShape::Cylinder, FVector(0.f, 22.f, 118.f), FVector(0.08f, 0.08f, 0.82f), FRotator(0.f, 0.f, 3.f));
	Part(EDPShape::Cylinder, FVector(0.f, 0.f, 172.f), FVector(0.09f, 0.09f, 0.1f));           // neck
	Part(EDPShape::Sphere, FVector(0.f, 0.f, 188.f), FVector(0.2f, 0.18f, 0.26f));             // head, featureless
}

void ADPObserver::BeginPlay()
{
	Super::BeginPlay();
	BuildSilhouette(this, Root);
}

void ADPObserver::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);

	const APawn* Player = UGameplayStatics::GetPlayerPawn(this, 0);
	if (!Player)
	{
		return;
	}

	const FVector Ground = GetActorLocation();
	bObserved = !IsHidden() && IsPointObserved(BodyCenter(Ground));

	if (bObserved)
	{
		ObservedTime += DeltaSeconds;
		UnobservedTime = 0.f;
		const float Dist = FVector::Dist(Player->GetActorLocation(), Ground);
		if (!bSeenReported && ObservedTime >= SeenThreshold && Dist <= SeenMaxDistance)
		{
			bSeenReported = true;
			if (OnSeen)
			{
				OnSeen(this);
			}
		}
		return; // never move while watched
	}

	ObservedTime = 0.f;
	UnobservedTime += DeltaSeconds;
	if (UnobservedTime > 1.5f)
	{
		bSeenReported = false; // he can be "seen" again later
	}

	// Unwatched: face the player again.
	FVector To = Player->GetActorLocation() - Ground;
	To.Z = 0.f;
	if (!To.IsNearlyZero())
	{
		SetActorRotation(FRotator(0.f, To.Rotation().Yaw, 0.f));
	}

	// Pending changes only resolve when both the old and new spots are out of view.
	CheckAccumulator += DeltaSeconds;
	if (CheckAccumulator < 0.2f)
	{
		return;
	}
	CheckAccumulator = 0.f;

	if (bPendingVanish)
	{
		bPendingVanish = false;
		bPendingMove = false;
		HideNow();
		return;
	}
	if (bPendingMove && !IsPointObserved(BodyCenter(PendingLocation)))
	{
		bPendingMove = false;
		SetActorLocation(PendingLocation);
		SetActorHiddenInGame(false);
	}
}

bool ADPObserver::IsPointObserved(const FVector& Point) const
{
	TArray<const AActor*> Ignore;
	Ignore.Add(this);
	return DPObservation::IsObserved(GetWorld(), Point, 60.f, Ignore, 14.f);
}

void ADPObserver::RequestRelocation(const FVector& GroundLocation)
{
	bPendingMove = true;
	bPendingVanish = false;
	PendingLocation = GroundLocation;
}

void ADPObserver::RequestVanish()
{
	if (!IsHidden())
	{
		bPendingVanish = true;
		bPendingMove = false;
	}
}

bool ADPObserver::TryAppearAt(const FVector& GroundLocation)
{
	if (IsPointObserved(BodyCenter(GroundLocation)))
	{
		return false;
	}
	if (!IsHidden() && bObserved)
	{
		return false;
	}
	bPendingMove = bPendingVanish = false;
	SetActorLocation(GroundLocation);
	SetActorHiddenInGame(false);
	ObservedTime = 0.f;
	bSeenReported = false;
	return true;
}

void ADPObserver::HideNow()
{
	SetActorHiddenInGame(true);
	bObserved = false;
	ObservedTime = 0.f;
}
