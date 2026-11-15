#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "Interaction/DPInteractable.h"
#include "DPNPC.generated.h"

class UCapsuleComponent;

/** Appearance of a dream character, assembled from primitives until real characters exist. */
struct FDPNPCLook
{
	FLinearColor Skin = FLinearColor(0.8f, 0.6f, 0.48f);
	FLinearColor Hair = FLinearColor(0.15f, 0.1f, 0.07f);
	FLinearColor Shirt = FLinearColor(0.3f, 0.5f, 0.8f);
	FLinearColor Pants = FLinearColor(0.2f, 0.2f, 0.25f);
	float Height = 1.f;      // 1 = ~175cm
	bool bSeated = false;
	bool bApron = false;
	FLinearColor ApronColor = FLinearColor::White;
	bool bCap = false;
	FLinearColor CapColor = FLinearColor::Red;
};

/**
 * A friendly dream character. Breathes, looks at the player when nearby, turns to face them when talking,
 * can follow a waypoint loop (jogger) and bark one-liners from data.
 */
UCLASS()
class DREAMPROTOCOL_API ADPNPC : public AActor, public IDPInteractable
{
	GENERATED_BODY()

public:
	ADPNPC();

	void Setup(const FString& InDialogueId, const FText& InName, const FText& InUnknownLabel, const FDPNPCLook& Look);
	void SetPatrol(const TArray<FVector>& Points, float Speed);
	void SetFrozen(bool bInFrozen) { bFrozen = bInFrozen; }
	void SetTalking(bool bInTalking);

	/** Attachment point for objects handed to this character. */
	USceneComponent* GetHandPoint() const { return HandPoint; }

	virtual void Tick(float DeltaSeconds) override;

	// IDPInteractable
	virtual FText GetInteractPrompt(const ADPCharacter* By) const override;
	virtual bool CanInteract(const ADPCharacter* By) const override;
	virtual void Interact(ADPCharacter* By) override;

private:
	void BuildBody(const FDPNPCLook& Look);
	USceneComponent* AddPivot(USceneComponent* Parent, const FVector& Location);
	void TryBark();

	UPROPERTY()
	TObjectPtr<UCapsuleComponent> Capsule;

	UPROPERTY()
	TObjectPtr<USceneComponent> BodyRoot;

	UPROPERTY()
	TObjectPtr<USceneComponent> Torso;

	UPROPERTY()
	TObjectPtr<USceneComponent> Head;

	UPROPERTY()
	TObjectPtr<USceneComponent> LegL;

	UPROPERTY()
	TObjectPtr<USceneComponent> LegR;

	UPROPERTY()
	TObjectPtr<USceneComponent> ArmL;

	UPROPERTY()
	TObjectPtr<USceneComponent> ArmR;

	UPROPERTY()
	TObjectPtr<USceneComponent> HandPoint;

	FString DialogueId;
	FText DisplayName;
	FText UnknownLabel;

	TArray<FVector> Patrol;
	int32 PatrolIndex = 0;
	float PatrolSpeed = 0.f;

	bool bTalking = false;
	bool bFrozen = false;
	bool bSeated = false;
	float Time = 0.f;
	float Phase = 0.f;
	double NextBarkTime = 0.0;
	int32 BarkIndex = 0;
};
