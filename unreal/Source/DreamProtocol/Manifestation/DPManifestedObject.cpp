#include "Manifestation/DPManifestedObject.h"
#include "Core/DPShapes.h"
#include "Components/SphereComponent.h"
#include "Components/StaticMeshComponent.h"

ADPManifestedObject::ADPManifestedObject()
{
	PrimaryActorTick.bCanEverTick = true;

	Body = CreateDefaultSubobject<USphereComponent>(TEXT("Body"));
	Body->InitSphereRadius(10.f);
	Body->SetCollisionProfileName(TEXT("PhysicsActor"));
	Body->SetSimulatePhysics(false);
	RootComponent = Body;

	Visual = CreateDefaultSubobject<USceneComponent>(TEXT("Visual"));
	Visual->SetupAttachment(Body);
	Visual->SetRelativeScale3D(FVector(0.01f));
}

void ADPManifestedObject::InitFromDef(const FDPManifestDef& Def)
{
	DefId = Def.Id;
	DisplayName = FText::FromString(Def.Name);
	BitesLeft = TotalBites = Def.Bites;
	bBuoyant = Def.Buoyant != 0;

	Body->SetSphereRadius(FMath::Max(2.f, Def.CollisionRadius));
	Body->SetMassOverrideInKg(NAME_None, FMath::Max(0.05f, Def.Mass), true);

	for (const FDPShapePart& Part : Def.Parts)
	{
		const FTransform Xf(
			FDPData::ToRotator(Part.Rotation),
			FDPData::ToVector(Part.Offset, FVector::ZeroVector),
			FDPData::ToVector(Part.Scale, FVector(0.1f)));
		UMaterialInterface* Mat = DPShapes::MakeColorMaterial(this, FDPData::ToColor(Part.Color, FLinearColor::White));
		UStaticMeshComponent* Mesh = DPShapes::AddShape(this, Visual, DPShapes::ParseShape(Part.Shape), Xf, Mat, false);
		Mesh->SetCastShadow(true);
		if (Part.Edible)
		{
			EdibleParts.Add(Mesh);
		}
	}
}

void ADPManifestedObject::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);
	Age += DeltaSeconds;

	// Materialise with a soft overshoot instead of popping in.
	if (SpawnAlpha < 1.f)
	{
		SpawnAlpha = FMath::Min(1.f, SpawnAlpha + DeltaSeconds / 0.45f);
		const float A = SpawnAlpha;
		const float Overshoot = 1.f + 0.12f * FMath::Sin(A * PI);
		Visual->SetRelativeScale3D(FVector(FMath::Max(0.01f, A * Overshoot)));
	}

	if (bReleased && bBuoyant && Body->IsSimulatingPhysics())
	{
		// Balloons drift up, slowly.
		Body->AddForce(FVector(0.f, 0.f, 1.15f * 980.f * Body->GetMass()));
	}

	if (bReleased && Age > 600.f)
	{
		Destroy(); // don't let the dream fill up forever
	}
}

void ADPManifestedObject::SetHeld(bool bHeld)
{
	bReleased = !bHeld;
	Body->SetSimulatePhysics(!bHeld);
	Body->SetCollisionEnabled(bHeld ? ECollisionEnabled::NoCollision : ECollisionEnabled::QueryAndPhysics);
	Body->SetEnableGravity(!bBuoyant);
	if (bBuoyant)
	{
		Body->SetLinearDamping(2.f);
	}
}

void ADPManifestedObject::Release(const FVector& Impulse)
{
	DetachFromActor(FDetachmentTransformRules::KeepWorldTransform);
	SetHeld(false);
	Age = 0.f;
	Body->AddImpulse(Impulse, NAME_None, true);
}

bool ADPManifestedObject::Bite()
{
	if (BitesLeft <= 0)
	{
		return false;
	}
	--BitesLeft;
	const float Remaining = TotalBites > 0 ? static_cast<float>(BitesLeft) / TotalBites : 0.f;
	for (UStaticMeshComponent* Part : EdibleParts)
	{
		Part->SetRelativeScale3D(Part->GetRelativeScale3D() * FMath::Lerp(0.55f, 0.85f, Remaining));
	}
	return BitesLeft == 0;
}
