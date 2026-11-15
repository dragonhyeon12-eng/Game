#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Character.h"
#include "Audio/DPSynthSound.h"
#include "DPCharacter.generated.h"

class UCameraComponent;
class UAudioComponent;
class UDPDreadComponent;
class UDPManifestationComponent;
class UStaticMeshComponent;

/**
 * First-person dreamer. Owns the camera, DREAD, manifestation and foley.
 * Input arrives from ADPPlayerController; the character only acts on it while controls are unlocked.
 */
UCLASS()
class DREAMPROTOCOL_API ADPCharacter : public ACharacter
{
	GENERATED_BODY()

public:
	ADPCharacter();

	virtual void BeginPlay() override;
	virtual void Tick(float DeltaSeconds) override;

	// ---- Input (forwarded by the controller)
	void InputMove(const FVector2D& Axis);
	void InputJump();
	void InputSprint(bool bPressed);
	void InputCrouchToggle();
	void InputInteract();
	void InputManifest(bool bPressed);
	void InputUseItem();
	void InputThrowItem();
	void InputCycleManifest(float Direction);
	void InputWake(bool bPressed);

	// ---- State
	void SetControlsLocked(bool bLocked);
	bool AreControlsLocked() const { return bControlsLocked; }
	void TeleportTo(const FTransform& Transform);
	void SetMovementProfile(float WalkSpeed, float SprintSpeed, bool bSoftFloor);
	/** Ignore world geometry (used to fall through the floor of the dream). */
	void SetPhasing(bool bPhase);
	void ApplySettings();
	/** Hides hands, clears holds; used on respawn / resets. */
	void ResetPresentation();

	// ---- Presentation
	void AddCameraJolt(const FRotator& Kick);
	void PlayShoulderGrab();
	void PlayFoley(EDPSynthEvent Event, float Strength = 1.f);
	void PlayEventAt(EDPSynthEvent Event, const FVector& Location, float Strength = 1.f);
	void SetDroneIntensity(float Intensity);

	UCameraComponent* GetCamera() const { return Camera; }
	UDPDreadComponent* GetDread() const { return Dread; }
	UDPManifestationComponent* GetManifestation() const { return Manifestation; }
	USceneComponent* GetHoldPoint() const { return HoldPoint; }
	AActor* GetFocusedActor() const { return FocusedActor.Get(); }

	/** 0..1 while holding Q / T, negative when not holding. */
	float GetManifestHoldProgress() const { return ManifestHold; }
	float GetWakeHoldProgress() const { return WakeHold; }

private:
	void UpdateInteractionFocus();
	void UpdateCamera(float DeltaSeconds);
	void UpdateFootsteps(float DeltaSeconds);
	void UpdateHolds(float DeltaSeconds);
	void UpdateHands(float DeltaSeconds);
	void BuildHands();

	UPROPERTY(VisibleAnywhere)
	TObjectPtr<UCameraComponent> Camera;

	UPROPERTY(VisibleAnywhere)
	TObjectPtr<USceneComponent> HoldPoint;

	UPROPERTY(VisibleAnywhere)
	TObjectPtr<UDPDreadComponent> Dread;

	UPROPERTY(VisibleAnywhere)
	TObjectPtr<UDPManifestationComponent> Manifestation;

	UPROPERTY()
	TObjectPtr<UAudioComponent> FoleyAudio;

	UPROPERTY()
	TObjectPtr<UAudioComponent> EventAudio;

	UPROPERTY()
	TObjectPtr<UAudioComponent> DroneAudio;

	UPROPERTY()
	TObjectPtr<UDPSynthSound> FoleySynth;

	UPROPERTY()
	TObjectPtr<UDPSynthSound> EventSynth;

	UPROPERTY()
	TObjectPtr<UDPSynthSound> DroneSynth;

	UPROPERTY()
	TObjectPtr<USceneComponent> HandsRoot;

	UPROPERTY()
	TArray<TObjectPtr<USceneComponent>> Hands;

	TWeakObjectPtr<AActor> FocusedActor;

	bool bControlsLocked = false;
	bool bSprinting = false;
	bool bSoftFloor = false;
	float WalkSpeed = 260.f;
	float SprintSpeed = 430.f;

	float ManifestHold = -1.f;
	float WakeHold = -1.f;
	bool bManifestHeld = false;
	bool bWakeHeld = false;

	float BobPhase = 0.f;
	float BobBlend = 0.f;
	float StepAccumulator = 0.f;
	FRotator Jolt = FRotator::ZeroRotator;
	float EyeHeight = 64.f;

	float HandsTime = -1.f;
};
