#include "Core/DPCharacter.h"
#include "Core/DPGameMode.h"
#include "Core/DPSettings.h"
#include "Core/DPShapes.h"
#include "Dread/DPDreadComponent.h"
#include "Manifestation/DPManifestationComponent.h"
#include "Interaction/DPInteractable.h"
#include "Camera/CameraComponent.h"
#include "Components/AudioComponent.h"
#include "Components/CapsuleComponent.h"
#include "Components/StaticMeshComponent.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "Engine/World.h"

namespace
{
	constexpr float InteractRange = 230.f;
	constexpr float ManifestHoldSeconds = 1.0f;
	constexpr float WakeHoldSeconds = 2.0f;
	constexpr float HandsDuration = 0.35f;
}

ADPCharacter::ADPCharacter()
{
	PrimaryActorTick.bCanEverTick = true;

	GetCapsuleComponent()->InitCapsuleSize(34.f, 88.f);

	bUseControllerRotationYaw = true;
	bUseControllerRotationPitch = false;
	bUseControllerRotationRoll = false;

	UCharacterMovementComponent* Move = GetCharacterMovement();
	Move->MaxWalkSpeed = WalkSpeed;
	Move->MaxWalkSpeedCrouched = 150.f;
	Move->BrakingDecelerationWalking = 1600.f;
	Move->GroundFriction = 9.f;
	Move->JumpZVelocity = 380.f;
	Move->AirControl = 0.25f;
	Move->GetNavAgentPropertiesRef().bCanCrouch = true;

	Camera = CreateDefaultSubobject<UCameraComponent>(TEXT("Camera"));
	Camera->SetupAttachment(GetCapsuleComponent());
	Camera->SetRelativeLocation(FVector(0.f, 0.f, EyeHeight));
	Camera->bUsePawnControlRotation = false; // rotation is applied in UpdateCamera so jolts can be layered on top
	Camera->PostProcessBlendWeight = 1.f;

	HoldPoint = CreateDefaultSubobject<USceneComponent>(TEXT("HoldPoint"));
	HoldPoint->SetupAttachment(Camera);
	HoldPoint->SetRelativeLocation(FVector(42.f, 16.f, -17.f));

	HandsRoot = CreateDefaultSubobject<USceneComponent>(TEXT("HandsRoot"));
	HandsRoot->SetupAttachment(Camera);

	Dread = CreateDefaultSubobject<UDPDreadComponent>(TEXT("Dread"));
	Manifestation = CreateDefaultSubobject<UDPManifestationComponent>(TEXT("Manifestation"));
}

void ADPCharacter::BeginPlay()
{
	Super::BeginPlay();

	// Foley: 2D, follows the player. Event: spatial, positioned in the world for distant sounds. Drone: 2D bed.
	UDPSynthSound* Synth = nullptr;
	FoleyAudio = UDPSynthSound::CreateComponent(this, Camera, EDPSynthVoice::Silence, false, 0.f, &Synth, 11);
	FoleySynth = Synth;
	EventAudio = UDPSynthSound::CreateComponent(this, GetRootComponent(), EDPSynthVoice::Silence, true, 4000.f, &Synth, 23);
	EventAudio->SetUsingAbsoluteLocation(true);
	EventSynth = Synth;
	DroneAudio = UDPSynthSound::CreateComponent(this, Camera, EDPSynthVoice::Drone, false, 0.f, &Synth, 37);
	DroneSynth = Synth;
	DroneSynth->SetIntensity(0.f);

	BuildHands();
	ApplySettings();
}

void ADPCharacter::BuildHands()
{
	// Two black, slightly-too-long hands that reach over the shoulders during the "waking" sequence.
	UMaterialInterface* Void = DPShapes::FindArtOverride(TEXT("M_ObserverVoid"));
	if (!Void)
	{
		Void = DPShapes::MakeColorMaterial(this, FLinearColor(0.002f, 0.002f, 0.002f));
	}

	for (int32 Side = 0; Side < 2; ++Side)
	{
		USceneComponent* Hand = NewObject<USceneComponent>(this);
		Hand->SetupAttachment(HandsRoot);
		Hand->RegisterComponent();
		AddInstanceComponent(Hand);

		const float Mirror = Side == 0 ? -1.f : 1.f;
		// palm
		DPShapes::AddShape(this, Hand, EDPShape::Cube, FTransform(FRotator::ZeroRotator, FVector(0, 0, 0), FVector(0.11f, 0.09f, 0.025f)), Void, false);
		// fingers, draping forward and down over the shoulder
		for (int32 F = 0; F < 4; ++F)
		{
			const float Y = (-3.f + F * 2.f) * Mirror;
			DPShapes::AddShape(this, Hand, EDPShape::Cylinder,
				FTransform(FRotator(70.f, 0.f, 0.f), FVector(9.f, Y, -3.f), FVector(0.016f, 0.016f, 0.13f)), Void, false);
		}
		// thumb
		DPShapes::AddShape(this, Hand, EDPShape::Cylinder,
			FTransform(FRotator(40.f, 0.f, 50.f * Mirror), FVector(2.f, 5.5f * -Mirror, -2.f), FVector(0.018f, 0.018f, 0.08f)), Void, false);
		// forearm reaching from behind
		DPShapes::AddShape(this, Hand, EDPShape::Cylinder,
			FTransform(FRotator(90.f, 0.f, 0.f), FVector(-22.f, 0.f, 1.f), FVector(0.05f, 0.05f, 0.4f)), Void, false);

		Hand->SetVisibility(false, true);
		Hands.Add(Hand);
	}
}

void ADPCharacter::ApplySettings()
{
	const UDPSettingsSave& S = DPSettings::Get(this);
	Camera->SetFieldOfView(S.FieldOfView);
	const float Volume = S.MasterVolume;
	if (FoleyAudio) FoleyAudio->SetVolumeMultiplier(Volume);
	if (EventAudio) EventAudio->SetVolumeMultiplier(Volume * S.AudioIntensity);
	if (DroneAudio) DroneAudio->SetVolumeMultiplier(Volume * S.AudioIntensity);
}

void ADPCharacter::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);

	UpdateCamera(DeltaSeconds);
	UpdateFootsteps(DeltaSeconds);
	UpdateHolds(DeltaSeconds);
	UpdateHands(DeltaSeconds);

	if (!bControlsLocked)
	{
		UpdateInteractionFocus();
	}
	else
	{
		FocusedActor.Reset();
	}
}

// ---------------------------------------------------------------- Input

void ADPCharacter::InputMove(const FVector2D& Axis)
{
	if (bControlsLocked)
	{
		return;
	}
	AddMovementInput(GetActorForwardVector(), Axis.Y);
	AddMovementInput(GetActorRightVector(), Axis.X);
}

void ADPCharacter::InputJump()
{
	if (!bControlsLocked)
	{
		Jump();
	}
}

void ADPCharacter::InputSprint(bool bPressed)
{
	bSprinting = bPressed;
	GetCharacterMovement()->MaxWalkSpeed = bSprinting ? SprintSpeed : WalkSpeed;
}

void ADPCharacter::InputCrouchToggle()
{
	if (bControlsLocked)
	{
		return;
	}
	if (bIsCrouched)
	{
		UnCrouch();
	}
	else
	{
		Crouch();
	}
}

void ADPCharacter::InputInteract()
{
	if (bControlsLocked)
	{
		return;
	}
	if (AActor* Target = FocusedActor.Get())
	{
		if (IDPInteractable* I = Cast<IDPInteractable>(Target))
		{
			if (I->CanInteract(this))
			{
				I->Interact(this);
			}
		}
	}
}

void ADPCharacter::InputManifest(bool bPressed)
{
	bManifestHeld = bPressed && !bControlsLocked;
	ManifestHold = bManifestHeld ? 0.f : -1.f;
}

void ADPCharacter::InputWake(bool bPressed)
{
	// Only meaningful inside a dream.
	const ADPGameMode* GM = ADPGameMode::Get(this);
	const bool bDreaming = GM && (GM->GetZoneType() == EDPZone::SummerCity || GM->GetZoneType() == EDPZone::Maze);
	bWakeHeld = bPressed && !bControlsLocked && bDreaming;
	WakeHold = bWakeHeld ? 0.f : -1.f;
}

void ADPCharacter::InputUseItem()
{
	if (!bControlsLocked)
	{
		Manifestation->UseHeld();
	}
}

void ADPCharacter::InputThrowItem()
{
	if (!bControlsLocked)
	{
		Manifestation->ThrowHeld();
	}
}

void ADPCharacter::InputCycleManifest(float Direction)
{
	if (!bControlsLocked && !FMath::IsNearlyZero(Direction))
	{
		Manifestation->CycleSelection(Direction > 0.f ? 1 : -1);
	}
}

// ---------------------------------------------------------------- State

void ADPCharacter::SetControlsLocked(bool bLocked)
{
	bControlsLocked = bLocked;
	if (bLocked)
	{
		bManifestHeld = bWakeHeld = false;
		ManifestHold = WakeHold = -1.f;
		GetCharacterMovement()->StopMovementImmediately();
		InputSprint(false);
	}
}

void ADPCharacter::TeleportTo(const FTransform& Transform)
{
	if (bIsCrouched)
	{
		UnCrouch();
	}
	GetCharacterMovement()->StopMovementImmediately();
	GetCharacterMovement()->SetMovementMode(MOVE_Falling); // re-enables movement after DisableMovement; lands immediately
	SetActorLocationAndRotation(Transform.GetLocation(), Transform.Rotator(), false, nullptr, ETeleportType::TeleportPhysics);
	if (AController* C = GetController())
	{
		C->SetControlRotation(Transform.Rotator());
	}
	Jolt = FRotator::ZeroRotator;
	StepAccumulator = 0.f;
}

void ADPCharacter::SetMovementProfile(float InWalkSpeed, float InSprintSpeed, bool bInSoftFloor)
{
	WalkSpeed = InWalkSpeed;
	SprintSpeed = InSprintSpeed;
	bSoftFloor = bInSoftFloor;
	GetCharacterMovement()->MaxWalkSpeed = bSprinting ? SprintSpeed : WalkSpeed;
}

void ADPCharacter::SetPhasing(bool bPhase)
{
	UCapsuleComponent* Capsule = GetCapsuleComponent();
	const ECollisionResponse R = bPhase ? ECR_Ignore : ECR_Block;
	Capsule->SetCollisionResponseToChannel(ECC_WorldStatic, R);
	Capsule->SetCollisionResponseToChannel(ECC_WorldDynamic, R);
	if (bPhase)
	{
		GetCharacterMovement()->SetMovementMode(MOVE_Falling);
	}
}

void ADPCharacter::ResetPresentation()
{
	HandsTime = -1.f;
	for (USceneComponent* H : Hands)
	{
		H->SetVisibility(false, true);
	}
	Jolt = FRotator::ZeroRotator;
	SetPhasing(false);
	Manifestation->ClearAll();
	SetDroneIntensity(0.f);
}

// ---------------------------------------------------------------- Presentation

void ADPCharacter::AddCameraJolt(const FRotator& Kick)
{
	if (DPSettings::Get(this).bCameraEffects)
	{
		Jolt += Kick;
	}
}

void ADPCharacter::PlayShoulderGrab()
{
	HandsTime = 0.f;
	for (USceneComponent* H : Hands)
	{
		H->SetVisibility(true, true);
	}
}

void ADPCharacter::PlayFoley(EDPSynthEvent Event, float Strength)
{
	if (FoleySynth)
	{
		FoleySynth->Trigger(Event, Strength);
	}
}

void ADPCharacter::PlayEventAt(EDPSynthEvent Event, const FVector& Location, float Strength)
{
	if (EventSynth && EventAudio)
	{
		EventAudio->SetWorldLocation(Location);
		EventSynth->Trigger(Event, Strength);
	}
}

void ADPCharacter::SetDroneIntensity(float Intensity)
{
	if (DroneSynth)
	{
		DroneSynth->SetIntensity(Intensity);
	}
}

// ---------------------------------------------------------------- Per-frame

void ADPCharacter::UpdateInteractionFocus()
{
	FocusedActor.Reset();

	const FVector Start = Camera->GetComponentLocation();
	const FVector End = Start + Camera->GetForwardVector() * InteractRange;

	FCollisionQueryParams Params(SCENE_QUERY_STAT(DPInteract), false, this);
	if (AActor* Held = Manifestation->GetHeldActor())
	{
		Params.AddIgnoredActor(Held);
	}

	FHitResult Hit;
	if (GetWorld()->SweepSingleByChannel(Hit, Start, End, FQuat::Identity, ECC_Visibility, FCollisionShape::MakeSphere(6.f), Params))
	{
		AActor* HitActor = Hit.GetActor();
		if (IDPInteractable* I = Cast<IDPInteractable>(HitActor))
		{
			if (I->CanInteract(this))
			{
				FocusedActor = HitActor;
			}
		}
	}
}

void ADPCharacter::UpdateCamera(float DeltaSeconds)
{
	const UDPSettingsSave& S = DPSettings::Get(this);

	// Jolt decays back to zero.
	Jolt = FMath::RInterpTo(Jolt, FRotator::ZeroRotator, DeltaSeconds, 6.f);

	const FRotator ControlRot = GetController() ? GetController()->GetControlRotation() : GetActorRotation();
	Camera->SetWorldRotation(ControlRot + Jolt);

	// Head bob.
	const float Speed = GetVelocity().Size2D();
	const bool bMoving = GetCharacterMovement()->IsMovingOnGround() && Speed > 30.f && !bControlsLocked;
	BobBlend = FMath::FInterpTo(BobBlend, (bMoving && S.bHeadBob) ? 1.f : 0.f, DeltaSeconds, 6.f);
	if (bMoving)
	{
		BobPhase += DeltaSeconds * Speed / 170.f * PI;
	}
	const float Amp = BobBlend * FMath::Clamp(Speed / 300.f, 0.4f, 1.4f);
	const FVector Bob(0.f, FMath::Cos(BobPhase) * 0.9f * Amp, (FMath::Abs(FMath::Sin(BobPhase)) * 2.0f - 1.0f) * Amp);
	Camera->SetRelativeLocation(FVector(0.f, 0.f, EyeHeight) + Bob);
}

void ADPCharacter::UpdateFootsteps(float DeltaSeconds)
{
	const float Speed = GetVelocity().Size2D();
	if (!GetCharacterMovement()->IsMovingOnGround() || Speed < 40.f)
	{
		StepAccumulator = FMath::Min(StepAccumulator, 120.f);
		return;
	}
	StepAccumulator += Speed * DeltaSeconds;
	const float Stride = bSprinting ? 210.f : 165.f;
	if (StepAccumulator >= Stride)
	{
		StepAccumulator = 0.f;
		PlayFoley(bSoftFloor ? EDPSynthEvent::FootstepSoft : EDPSynthEvent::FootstepHard, FMath::Clamp(Speed / 350.f, 0.4f, 1.3f));
	}
}

void ADPCharacter::UpdateHolds(float DeltaSeconds)
{
	ADPGameMode* GM = ADPGameMode::Get(this);

	if (bManifestHeld && ManifestHold >= 0.f)
	{
		ManifestHold += DeltaSeconds / ManifestHoldSeconds;
		if (ManifestHold >= 1.f)
		{
			ManifestHold = -1.f;
			bManifestHeld = false;
			Manifestation->TryManifest();
		}
	}

	if (bWakeHeld && WakeHold >= 0.f)
	{
		WakeHold += DeltaSeconds / WakeHoldSeconds;
		if (WakeHold >= 1.f)
		{
			WakeHold = -1.f;
			bWakeHeld = false;
			if (GM)
			{
				GM->RequestWake();
			}
		}
	}
}

void ADPCharacter::UpdateHands(float DeltaSeconds)
{
	if (HandsTime < 0.f || Hands.Num() < 2)
	{
		return;
	}
	HandsTime += DeltaSeconds;
	const float A = FMath::Clamp(HandsTime / HandsDuration, 0.f, 1.f);
	const float Ease = 1.f - FMath::Pow(1.f - A, 3.f);

	for (int32 Side = 0; Side < 2; ++Side)
	{
		const float Mirror = Side == 0 ? -1.f : 1.f;
		// from out of view (below/behind) to gripping the shoulders at the bottom corners of the screen
		const FVector From(-10.f, 34.f * Mirror, -48.f);
		const FVector To(24.f, 23.f * Mirror, -21.f);
		Hands[Side]->SetRelativeLocation(FMath::Lerp(From, To, Ease));
		Hands[Side]->SetRelativeRotation(FRotator(-15.f * (1.f - Ease), 15.f * Mirror, 0.f));
	}
}
