#include "NPC/DPNPC.h"
#include "Core/DPCharacter.h"
#include "Core/DPData.h"
#include "Core/DPGameMode.h"
#include "Core/DPShapes.h"
#include "Dialogue/DPDialogueSubsystem.h"
#include "UI/DPHUD.h"
#include "Components/CapsuleComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Kismet/GameplayStatics.h"
#include "Engine/World.h"

#define LOCTEXT_NAMESPACE "DPNPC"

ADPNPC::ADPNPC()
{
	PrimaryActorTick.bCanEverTick = true;

	Capsule = CreateDefaultSubobject<UCapsuleComponent>(TEXT("Capsule"));
	Capsule->InitCapsuleSize(30.f, 88.f);
	Capsule->SetCollisionEnabled(ECollisionEnabled::QueryAndPhysics);
	Capsule->SetCollisionObjectType(ECC_Pawn);
	Capsule->SetCollisionResponseToAllChannels(ECR_Block);
	RootComponent = Capsule;

	BodyRoot = CreateDefaultSubobject<USceneComponent>(TEXT("BodyRoot"));
	BodyRoot->SetupAttachment(Capsule);
	BodyRoot->SetRelativeLocation(FVector(0.f, 0.f, -88.f));
}

USceneComponent* ADPNPC::AddPivot(USceneComponent* Parent, const FVector& Location)
{
	USceneComponent* P = NewObject<USceneComponent>(this);
	P->SetupAttachment(Parent);
	P->SetRelativeLocation(Location);
	P->RegisterComponent();
	AddInstanceComponent(P);
	return P;
}

void ADPNPC::Setup(const FString& InDialogueId, const FText& InName, const FText& InUnknownLabel, const FDPNPCLook& Look)
{
	DialogueId = InDialogueId;
	DisplayName = InName;
	UnknownLabel = InUnknownLabel;
	bSeated = Look.bSeated;
	Phase = FMath::FRand() * 10.f;
	BuildBody(Look);
}

void ADPNPC::BuildBody(const FDPNPCLook& L)
{
	const float H = L.Height;
	const float HalfHeight = 88.f * H;
	Capsule->SetCapsuleHalfHeight(HalfHeight);
	BodyRoot->SetRelativeLocation(FVector(0.f, 0.f, -HalfHeight));

	UMaterialInterface* Skin = DPShapes::MakeColorMaterial(this, L.Skin);
	UMaterialInterface* Hair = DPShapes::MakeColorMaterial(this, L.Hair);
	UMaterialInterface* Shirt = DPShapes::MakeColorMaterial(this, L.Shirt);
	UMaterialInterface* Pants = DPShapes::MakeColorMaterial(this, L.Pants);
	UMaterialInterface* Shoes = DPShapes::MakeColorMaterial(this, FLinearColor(0.06f, 0.05f, 0.05f));
	UMaterialInterface* Eyes = DPShapes::MakeColorMaterial(this, FLinearColor(0.03f, 0.025f, 0.02f));

	auto Part = [this](USceneComponent* Parent, EDPShape Shape, const FVector& Loc, const FVector& Scale, UMaterialInterface* Mat, const FRotator& Rot = FRotator::ZeroRotator)
	{
		return DPShapes::AddShape(this, Parent, Shape, FTransform(Rot, Loc, Scale), Mat, false);
	};

	const float HipZ = bSeated ? 46.f : 90.f * H;

	if (bSeated)
	{
		for (int32 S = -1; S <= 1; S += 2)
		{
			Part(BodyRoot, EDPShape::Cylinder, FVector(22.f, 10.f * S, HipZ), FVector(0.14f, 0.14f, 0.45f), Pants, FRotator(90.f, 0.f, 0.f));
			Part(BodyRoot, EDPShape::Cylinder, FVector(44.f, 10.f * S, 24.f), FVector(0.12f, 0.12f, 0.46f), Pants);
			Part(BodyRoot, EDPShape::Cube, FVector(50.f, 10.f * S, 4.f), FVector(0.26f, 0.12f, 0.08f), Shoes);
		}
	}
	else
	{
		LegL = AddPivot(BodyRoot, FVector(0.f, -10.f, HipZ));
		LegR = AddPivot(BodyRoot, FVector(0.f, 10.f, HipZ));
		for (USceneComponent* Leg : { LegL.Get(), LegR.Get() })
		{
			Part(Leg, EDPShape::Cylinder, FVector(0.f, 0.f, -44.f * H), FVector(0.13f, 0.13f, 0.88f * H), Pants);
			Part(Leg, EDPShape::Cube, FVector(5.f, 0.f, -86.f * H), FVector(0.26f, 0.12f, 0.08f), Shoes);
		}
	}

	Torso = AddPivot(BodyRoot, FVector(0.f, 0.f, HipZ));
	Part(Torso, EDPShape::Cylinder, FVector(0.f, 0.f, 30.f * H), FVector(0.36f, 0.25f, 0.62f * H), Shirt);
	if (L.bApron)
	{
		Part(Torso, EDPShape::Cube, FVector(12.5f, 0.f, 18.f * H), FVector(0.02f, 0.3f, 0.55f * H), DPShapes::MakeColorMaterial(this, L.ApronColor));
	}

	ArmL = AddPivot(Torso, FVector(0.f, -22.f, 56.f * H));
	ArmR = AddPivot(Torso, FVector(0.f, 22.f, 56.f * H));
	for (USceneComponent* Arm : { ArmL.Get(), ArmR.Get() })
	{
		Part(Arm, EDPShape::Cylinder, FVector(0.f, 0.f, -28.f * H), FVector(0.09f, 0.09f, 0.58f * H), Shirt);
		Part(Arm, EDPShape::Sphere, FVector(0.f, 0.f, -60.f * H), FVector(0.1f), Skin);
	}
	HandPoint = AddPivot(ArmR, FVector(8.f, 0.f, -62.f * H));
	if (bSeated)
	{
		// hands resting on the thighs
		ArmL->SetRelativeRotation(FRotator(35.f, 0.f, 0.f));
		ArmR->SetRelativeRotation(FRotator(35.f, 0.f, 0.f));
	}

	Part(Torso, EDPShape::Cylinder, FVector(0.f, 0.f, 64.f * H), FVector(0.1f, 0.1f, 0.08f), Skin);
	Head = AddPivot(Torso, FVector(0.f, 0.f, 68.f * H));
	Part(Head, EDPShape::Sphere, FVector(0.f, 0.f, 12.f), FVector(0.21f, 0.19f, 0.25f), Skin);
	Part(Head, EDPShape::Sphere, FVector(-2.5f, 0.f, 17.f), FVector(0.225f, 0.205f, 0.19f), Hair);
	// A face. Everyone here has one.
	Part(Head, EDPShape::Sphere, FVector(9.5f, -4.f, 14.f), FVector(0.025f), Eyes);
	Part(Head, EDPShape::Sphere, FVector(9.5f, 4.f, 14.f), FVector(0.025f), Eyes);
	if (L.bCap)
	{
		UMaterialInterface* Cap = DPShapes::MakeColorMaterial(this, L.CapColor);
		Part(Head, EDPShape::Cylinder, FVector(0.f, 0.f, 24.f), FVector(0.23f, 0.23f, 0.07f), Cap);
		Part(Head, EDPShape::Cube, FVector(13.f, 0.f, 21.5f), FVector(0.14f, 0.2f, 0.015f), Cap);
	}
}

void ADPNPC::SetPatrol(const TArray<FVector>& Points, float Speed)
{
	Patrol = Points;
	PatrolSpeed = Speed;
	PatrolIndex = 0;
}

void ADPNPC::SetTalking(bool bInTalking)
{
	bTalking = bInTalking;
}

void ADPNPC::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);
	Time += DeltaSeconds;

	if (bFrozen)
	{
		return; // perfectly, unnaturally still
	}

	const APawn* Player = UGameplayStatics::GetPlayerPawn(this, 0);
	const FVector PlayerLoc = Player ? Player->GetActorLocation() : FVector::ZeroVector;
	const float DistToPlayer = Player ? FVector::Dist2D(PlayerLoc, GetActorLocation()) : 1e9f;

	// Breathing.
	if (Torso)
	{
		Torso->SetRelativeScale3D(FVector(1.f, 1.f, 1.f + 0.012f * FMath::Sin((Time + Phase) * 1.7f)));
	}

	// Walking a loop.
	const bool bWalking = Patrol.Num() > 1 && !bTalking;
	if (bWalking)
	{
		const FVector Target = Patrol[PatrolIndex];
		FVector To = Target - GetActorLocation();
		To.Z = 0.f;
		if (To.Size() < 40.f)
		{
			PatrolIndex = (PatrolIndex + 1) % Patrol.Num();
		}
		else
		{
			const FVector Dir = To.GetSafeNormal();
			AddActorWorldOffset(Dir * PatrolSpeed * DeltaSeconds);
			const FRotator Want = Dir.Rotation();
			SetActorRotation(FMath::RInterpTo(GetActorRotation(), FRotator(0.f, Want.Yaw, 0.f), DeltaSeconds, 5.f));
		}

		const float Swing = FMath::Sin(Time * PatrolSpeed / 40.f) * 32.f;
		if (LegL) LegL->SetRelativeRotation(FRotator(Swing, 0.f, 0.f));
		if (LegR) LegR->SetRelativeRotation(FRotator(-Swing, 0.f, 0.f));
		if (ArmL) ArmL->SetRelativeRotation(FRotator(-Swing * 0.8f, 0.f, 0.f));
		if (ArmR) ArmR->SetRelativeRotation(FRotator(Swing * 0.8f, 0.f, 0.f));
		BodyRoot->SetRelativeLocation(FVector(0.f, 0.f, -Capsule->GetUnscaledCapsuleHalfHeight() + FMath::Abs(FMath::Sin(Time * PatrolSpeed / 40.f)) * 3.f));

		if (DistToPlayer < 450.f)
		{
			TryBark();
		}
	}

	// Turn to face the player while talking.
	if (bTalking && Player && !bSeated)
	{
		const FRotator Want = (PlayerLoc - GetActorLocation()).Rotation();
		SetActorRotation(FMath::RInterpTo(GetActorRotation(), FRotator(0.f, Want.Yaw, 0.f), DeltaSeconds, 4.f));
	}

	// Look at the player when nearby.
	if (Head)
	{
		FRotator HeadTarget = FRotator::ZeroRotator;
		if (Player && DistToPlayer < 800.f)
		{
			const FVector Local = GetActorTransform().InverseTransformPosition(PlayerLoc + FVector(0, 0, 60.f));
			const FRotator LookRot = Local.Rotation();
			HeadTarget = FRotator(FMath::Clamp(LookRot.Pitch, -20.f, 20.f), FMath::Clamp(LookRot.Yaw, -65.f, 65.f), 0.f);
		}
		else
		{
			// idle glance around
			HeadTarget = FRotator(0.f, FMath::Sin((Time + Phase) * 0.3f) * 25.f, 0.f);
		}
		Head->SetRelativeRotation(FMath::RInterpTo(Head->GetRelativeRotation(), HeadTarget, DeltaSeconds, 3.f));
	}
}

void ADPNPC::TryBark()
{
	const double Now = GetWorld()->GetTimeSeconds();
	if (Now < NextBarkTime)
	{
		return;
	}
	const FDPDialogue* D = FDPData::FindDialogue(DialogueId);
	if (!D || D->Barks.Num() == 0)
	{
		return;
	}
	NextBarkTime = Now + 25.0;
	if (ADPGameMode* GM = ADPGameMode::Get(this))
	{
		if (ADPHUD* HUD = GM->GetDPHUD())
		{
			const FString& Line = D->Barks[BarkIndex % D->Barks.Num()];
			++BarkIndex;
			HUD->ShowThought(FText::Format(LOCTEXT("Bark", "{0}: \"{1}\""), UnknownLabel, FText::FromString(Line)), 3.f);
		}
	}
}

FText ADPNPC::GetInteractPrompt(const ADPCharacter* By) const
{
	const ADPGameMode* GM = ADPGameMode::Get(this);
	const bool bKnown = GM && GM->HasFlag(FName(*FString::Printf(TEXT("talked_%s"), *DialogueId)));
	return FText::Format(LOCTEXT("Talk", "Talk to {0}"), bKnown ? DisplayName : UnknownLabel);
}

bool ADPNPC::CanInteract(const ADPCharacter* By) const
{
	if (bFrozen || Patrol.Num() > 1)
	{
		return false;
	}
	const UDPDialogueSubsystem* Dialogue = GetWorld()->GetSubsystem<UDPDialogueSubsystem>();
	return Dialogue && !Dialogue->IsActive() && FDPData::FindDialogue(DialogueId) != nullptr;
}

void ADPNPC::Interact(ADPCharacter* By)
{
	if (UDPDialogueSubsystem* Dialogue = GetWorld()->GetSubsystem<UDPDialogueSubsystem>())
	{
		Dialogue->StartDialogue(this, DialogueId);
	}
}

#undef LOCTEXT_NAMESPACE
