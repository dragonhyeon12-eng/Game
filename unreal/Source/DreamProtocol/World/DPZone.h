#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "Engine/World.h"
#include "Core/DPTypes.h"
#include "Core/DPShapes.h"
#include "Audio/DPSynthSound.h"
#include "DPZone.generated.h"

class ADPCharacter;
class ADPGameMode;
class ADPInteractableActor;
class UInstancedStaticMeshComponent;
class UMaterialInstanceDynamic;
class UPointLightComponent;
class URectLightComponent;
class UTextRenderComponent;

/**
 * A self-contained playable space: geometry, lighting, audio, interactables, NPCs, anomalies.
 * Exactly one zone exists at a time; the game mode spawns it, calls BuildZone(), and destroys it on exit.
 *
 * Zones also define how the dream behaves inside them (fear gain, floor, anomaly pacing, manifestation).
 * New realms are added by subclassing this - no core system needs to change.
 */
UCLASS(Abstract)
class DREAMPROTOCOL_API ADPZone : public AActor
{
	GENERATED_BODY()

public:
	ADPZone();

	virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

	virtual EDPZone GetZoneType() const { return EDPZone::None; }
	virtual void BuildZone() {}
	virtual FTransform GetPlayerStart() const { return FTransform::Identity; }
	/** Called once the player has been placed. bFromSave = continuing from a checkpoint. */
	virtual void OnPlayerEntered(ADPCharacter* Player, bool bFromSave) {}
	/** Per-frame from the dread director (Dread 0..100). */
	virtual void OnDreadUpdate(float Dread, EDPDreadStage Stage, float DeltaSeconds) {}
	/** Story/effect hook, e.g. "closer" for the Observer. */
	virtual void HandleObserverEvent(FName Event) {}

	// Dream rules for this space
	virtual bool IsNightmare() const { return false; }
	virtual bool AllowsManifestation() const { return false; }
	virtual float GetFearGainMultiplier() const { return 1.f; }
	virtual float GetFearFloor() const { return 0.f; }
	virtual float GetFearDecayRate() const { return 1.5f; }
	virtual bool HasSoftFloor() const { return false; }
	virtual float GetWalkSpeed() const { return 260.f; }
	virtual float GetSprintSpeed() const { return 430.f; }
	/** Seconds between unobserved changes when stable / unstable. Negative = never. */
	virtual FVector2D GetAnomalyPacing() const { return FVector2D(-1.f, -1.f); }

	/** Re-apply master volume to this zone's ambience. */
	void ApplyAudioSettings();

protected:
	ADPGameMode* GetGameMode() const;
	ADPCharacter* GetPlayer() const;

	// ---- Builder helpers (zone sits at the world origin, so relative == world)
	UMaterialInterface* Mat(const FLinearColor& Color);
	/** Instanced box; boxes of the same colour/collision share one draw call. */
	void AddBox(const FVector& Center, const FVector& Size, const FLinearColor& Color, bool bCollide = true, const FRotator& Rot = FRotator::ZeroRotator);
	void AddInstanced(EDPShape Shape, const FTransform& Transform, const FLinearColor& Color, bool bCollide);
	/** Individual component (for things that change at runtime). */
	UStaticMeshComponent* AddPart(EDPShape Shape, const FTransform& Transform, const FLinearColor& Color, bool bCollide, USceneComponent* Parent = nullptr);
	UStaticMeshComponent* AddPartBox(const FVector& Center, const FVector& Size, const FLinearColor& Color, bool bCollide, USceneComponent* Parent = nullptr);
	USceneComponent* AddGroup(const FVector& Location, const FRotator& Rotation = FRotator::ZeroRotator);

	UPointLightComponent* AddPointLight(const FVector& Location, const FLinearColor& Color, float Candelas, float Radius, bool bShadows, float SourceRadius = 5.f);
	URectLightComponent* AddRectLight(const FVector& Location, const FRotator& Facing, const FLinearColor& Color, float Candelas, float Width, float Height, float Radius, bool bShadows);
	UTextRenderComponent* AddText(const FVector& Location, const FRotator& Facing, const FText& Text, float WorldSize, const FColor& Color);
	void AddBlocker(const FVector& Center, const FVector& HalfExtent);
	UAudioComponent* AddSynth(EDPSynthVoice Voice, const FVector& Location, bool bSpatial, float Volume, float Falloff, UDPSynthSound** OutSound = nullptr);

	ADPInteractableActor* AddInteractable(const FVector& Center, const FVector& HalfExtent, TFunction<FText()> Prompt,
		TFunction<void(ADPCharacter*)> OnInteract, TFunction<bool()> CanInteract = nullptr);

	template <typename T>
	T* SpawnOwned(const FTransform& Transform)
	{
		FActorSpawnParameters Params;
		Params.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;
		T* Actor = GetWorld()->SpawnActor<T>(T::StaticClass(), Transform, Params);
		if (Actor)
		{
			OwnedActors.Add(Actor);
		}
		return Actor;
	}

	/** Look up the floor height below a point (for placing characters). */
	float GroundZ(const FVector& Location, float Fallback = 0.f) const;

	UPROPERTY()
	TObjectPtr<USceneComponent> Root;

	UPROPERTY()
	TArray<TObjectPtr<AActor>> OwnedActors;

	/** Ambient audio components, with their designed volume (settings multiply on top). */
	UPROPERTY()
	TArray<TObjectPtr<UAudioComponent>> AmbientAudio;
	TArray<float> AmbientBaseVolume;

private:
	UPROPERTY()
	TMap<FString, TObjectPtr<UInstancedStaticMeshComponent>> InstanceGroups;

	UPROPERTY()
	TMap<uint32, TObjectPtr<UMaterialInstanceDynamic>> MaterialCache;
};
