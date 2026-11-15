#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "Core/DPData.h"
#include "DPManifestedObject.generated.h"

class USphereComponent;
class UStaticMeshComponent;

/** An object summoned out of thin air, assembled from the shape parts in Manifestations.json. */
UCLASS()
class DREAMPROTOCOL_API ADPManifestedObject : public AActor
{
	GENERATED_BODY()

public:
	ADPManifestedObject();

	void InitFromDef(const FDPManifestDef& Def);
	virtual void Tick(float DeltaSeconds) override;

	void SetHeld(bool bHeld);
	/** Physics release with an impulse. */
	void Release(const FVector& Impulse);

	/** Returns true when the last bite has been taken. */
	bool Bite();
	bool IsEdible() const { return BitesLeft > 0; }
	const FString& GetDefId() const { return DefId; }
	const FText& GetDisplayName() const { return DisplayName; }

private:
	UPROPERTY()
	TObjectPtr<USphereComponent> Body;

	UPROPERTY()
	TObjectPtr<USceneComponent> Visual;

	UPROPERTY()
	TArray<TObjectPtr<UStaticMeshComponent>> EdibleParts;

	FString DefId;
	FText DisplayName;
	int32 BitesLeft = 0;
	int32 TotalBites = 0;
	bool bBuoyant = false;
	bool bReleased = false;
	float SpawnAlpha = 0.f;
	float Age = 0.f;
};
