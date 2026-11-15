#include "World/DPZone.h"
#include "Core/DPCharacter.h"
#include "Core/DPGameMode.h"
#include "Core/DPSettings.h"
#include "Anomaly/DPAnomalySubsystem.h"
#include "Interaction/DPInteractableActor.h"
#include "Components/AudioComponent.h"
#include "Components/BoxComponent.h"
#include "Components/InstancedStaticMeshComponent.h"
#include "Components/PointLightComponent.h"
#include "Components/RectLightComponent.h"
#include "Components/TextRenderComponent.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "Kismet/GameplayStatics.h"
#include "Engine/World.h"

ADPZone::ADPZone()
{
	PrimaryActorTick.bCanEverTick = true;
	Root = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
	RootComponent = Root;
}

void ADPZone::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
	if (UDPAnomalySubsystem* Anomalies = GetWorld()->GetSubsystem<UDPAnomalySubsystem>())
	{
		Anomalies->UnregisterOwner(this);
	}
	for (AActor* A : OwnedActors)
	{
		if (IsValid(A))
		{
			A->Destroy();
		}
	}
	OwnedActors.Reset();
	Super::EndPlay(EndPlayReason);
}

ADPGameMode* ADPZone::GetGameMode() const
{
	return ADPGameMode::Get(this);
}

ADPCharacter* ADPZone::GetPlayer() const
{
	return Cast<ADPCharacter>(UGameplayStatics::GetPlayerPawn(this, 0));
}

UMaterialInterface* ADPZone::Mat(const FLinearColor& Color)
{
	const FColor Key = Color.ToFColor(false);
	const uint32 Hash = Key.DWColor();
	if (TObjectPtr<UMaterialInstanceDynamic>* Found = MaterialCache.Find(Hash))
	{
		return *Found;
	}
	UMaterialInstanceDynamic* MID = DPShapes::MakeColorMaterial(this, Color);
	MaterialCache.Add(Hash, MID);
	return MID;
}

void ADPZone::AddInstanced(EDPShape Shape, const FTransform& Transform, const FLinearColor& Color, bool bCollide)
{
	const FString Key = FString::Printf(TEXT("%d_%u_%d"), static_cast<int32>(Shape), Color.ToFColor(false).DWColor(), bCollide ? 1 : 0);
	TObjectPtr<UInstancedStaticMeshComponent>* Found = InstanceGroups.Find(Key);
	UInstancedStaticMeshComponent* ISM = Found ? Found->Get() : nullptr;
	if (!ISM)
	{
		ISM = NewObject<UInstancedStaticMeshComponent>(this);
		ISM->SetStaticMesh(DPShapes::GetMesh(Shape));
		ISM->SetMaterial(0, Mat(Color));
		if (bCollide)
		{
			ISM->SetCollisionProfileName(TEXT("BlockAll"));
		}
		else
		{
			ISM->SetCollisionEnabled(ECollisionEnabled::NoCollision);
		}
		ISM->SetupAttachment(Root);
		ISM->RegisterComponent();
		AddInstanceComponent(ISM);
		InstanceGroups.Add(Key, ISM);
	}
	ISM->AddInstance(Transform, /*bWorldSpace*/ true);
}

void ADPZone::AddBox(const FVector& Center, const FVector& Size, const FLinearColor& Color, bool bCollide, const FRotator& Rot)
{
	AddInstanced(EDPShape::Cube, FTransform(Rot, Center, DPShapes::CubeScale(Size)), Color, bCollide);
}

UStaticMeshComponent* ADPZone::AddPart(EDPShape Shape, const FTransform& Transform, const FLinearColor& Color, bool bCollide, USceneComponent* Parent)
{
	return DPShapes::AddShape(this, Parent ? Parent : Root.Get(), Shape, Transform, Mat(Color), bCollide);
}

UStaticMeshComponent* ADPZone::AddPartBox(const FVector& Center, const FVector& Size, const FLinearColor& Color, bool bCollide, USceneComponent* Parent)
{
	return AddPart(EDPShape::Cube, FTransform(FRotator::ZeroRotator, Center, DPShapes::CubeScale(Size)), Color, bCollide, Parent);
}

USceneComponent* ADPZone::AddGroup(const FVector& Location, const FRotator& Rotation)
{
	USceneComponent* G = NewObject<USceneComponent>(this);
	G->SetupAttachment(Root);
	G->SetRelativeLocationAndRotation(Location, Rotation);
	G->RegisterComponent();
	AddInstanceComponent(G);
	return G;
}

UPointLightComponent* ADPZone::AddPointLight(const FVector& Location, const FLinearColor& Color, float Candelas, float Radius, bool bShadows, float SourceRadius)
{
	UPointLightComponent* L = NewObject<UPointLightComponent>(this);
	L->SetupAttachment(Root);
	L->SetRelativeLocation(Location);
	L->SetIntensityUnits(ELightUnits::Candelas);
	L->SetIntensity(Candelas);
	L->SetLightColor(Color);
	L->SetAttenuationRadius(Radius);
	L->SetCastShadows(bShadows);
	L->SetSourceRadius(SourceRadius);
	L->RegisterComponent();
	AddInstanceComponent(L);
	return L;
}

URectLightComponent* ADPZone::AddRectLight(const FVector& Location, const FRotator& Facing, const FLinearColor& Color, float Candelas,
	float Width, float Height, float Radius, bool bShadows)
{
	URectLightComponent* L = NewObject<URectLightComponent>(this);
	L->SetupAttachment(Root);
	L->SetRelativeLocationAndRotation(Location, Facing);
	L->SetIntensityUnits(ELightUnits::Candelas);
	L->SetIntensity(Candelas);
	L->SetLightColor(Color);
	L->SetAttenuationRadius(Radius);
	L->SetSourceWidth(Width);
	L->SetSourceHeight(Height);
	L->SetCastShadows(bShadows);
	L->RegisterComponent();
	AddInstanceComponent(L);
	return L;
}

UTextRenderComponent* ADPZone::AddText(const FVector& Location, const FRotator& Facing, const FText& Text, float WorldSize, const FColor& Color)
{
	UTextRenderComponent* T = NewObject<UTextRenderComponent>(this);
	T->SetupAttachment(Root);
	T->SetRelativeLocationAndRotation(Location, Facing);
	T->SetText(Text);
	T->SetWorldSize(WorldSize);
	T->SetTextRenderColor(Color);
	T->SetHorizontalAlignment(EHTA_Center);
	T->SetVerticalAlignment(EVRTA_TextCenter);
	T->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	T->RegisterComponent();
	AddInstanceComponent(T);
	return T;
}

void ADPZone::AddBlocker(const FVector& Center, const FVector& HalfExtent)
{
	UBoxComponent* B = NewObject<UBoxComponent>(this);
	B->SetupAttachment(Root);
	B->SetRelativeLocation(Center);
	B->SetBoxExtent(HalfExtent);
	B->SetCollisionProfileName(TEXT("BlockAll"));
	B->SetHiddenInGame(true);
	B->RegisterComponent();
	AddInstanceComponent(B);
}

UAudioComponent* ADPZone::AddSynth(EDPSynthVoice Voice, const FVector& Location, bool bSpatial, float Volume, float Falloff, UDPSynthSound** OutSound)
{
	UAudioComponent* AC = UDPSynthSound::CreateComponent(this, Root, Voice, bSpatial, Falloff, OutSound, FMath::Rand());
	AC->SetRelativeLocation(Location);
	AmbientAudio.Add(AC);
	AmbientBaseVolume.Add(Volume);
	ApplyAudioSettings();
	return AC;
}

void ADPZone::ApplyAudioSettings()
{
	const float Master = DPSettings::Get(this).MasterVolume;
	for (int32 i = 0; i < AmbientAudio.Num(); ++i)
	{
		if (AmbientAudio[i])
		{
			AmbientAudio[i]->SetVolumeMultiplier(AmbientBaseVolume[i] * Master);
		}
	}
}

ADPInteractableActor* ADPZone::AddInteractable(const FVector& Center, const FVector& HalfExtent, TFunction<FText()> Prompt,
	TFunction<void(ADPCharacter*)> OnInteract, TFunction<bool()> CanInteract)
{
	ADPInteractableActor* A = SpawnOwned<ADPInteractableActor>(FTransform(Center));
	if (A)
	{
		A->Setup(HalfExtent, MoveTemp(Prompt), MoveTemp(OnInteract), MoveTemp(CanInteract));
	}
	return A;
}

float ADPZone::GroundZ(const FVector& Location, float Fallback) const
{
	FHitResult Hit;
	FCollisionQueryParams Params(SCENE_QUERY_STAT(DPGroundZ), false);
	Params.AddIgnoredActor(GetPlayer());
	const FVector Start(Location.X, Location.Y, Location.Z + 2000.f);
	const FVector End(Location.X, Location.Y, Location.Z - 5000.f);
	if (GetWorld()->LineTraceSingleByChannel(Hit, Start, End, ECC_WorldStatic, Params))
	{
		return Hit.ImpactPoint.Z;
	}
	return Fallback;
}
