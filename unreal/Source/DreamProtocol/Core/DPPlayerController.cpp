#include "Core/DPPlayerController.h"
#include "Core/DPCharacter.h"
#include "Core/DPGameInstance.h"
#include "Core/DPGameMode.h"
#include "Core/DPSettings.h"
#include "Dialogue/DPDialogueSubsystem.h"
#include "Dread/DPDreadComponent.h"
#include "Notebook/DPNotebookSubsystem.h"
#include "UI/DPHUD.h"
#include "World/DPZone.h"
#include "EnhancedInputComponent.h"
#include "EnhancedInputSubsystems.h"
#include "InputAction.h"
#include "InputMappingContext.h"
#include "InputModifiers.h"
#include "Engine/LocalPlayer.h"
#include "Kismet/KismetSystemLibrary.h"
#include "Framework/Application/SlateApplication.h"

#define LOCTEXT_NAMESPACE "DPController"

namespace
{
	UInputAction* MakeAction(UObject* Outer, EInputActionValueType Type, bool bWhenPaused = false)
	{
		UInputAction* A = NewObject<UInputAction>(Outer);
		A->ValueType = Type;
		A->bTriggerWhenPaused = bWhenPaused;
		return A;
	}

	template <typename TModifier>
	TModifier* AddModifier(UInputMappingContext* Ctx, FEnhancedActionKeyMapping& Mapping)
	{
		TModifier* M = NewObject<TModifier>(Ctx);
		Mapping.Modifiers.Add(M);
		return M;
	}
}

ADPPlayerController::ADPPlayerController()
{
	bShowMouseCursor = false;
}

void ADPPlayerController::BuildInput()
{
	if (bInputBuilt)
	{
		return;
	}
	bInputBuilt = true;

	Mapping = NewObject<UInputMappingContext>(this);

	auto Add = [this](FName Name, EInputActionValueType Type, bool bWhenPaused = false)
	{
		UInputAction* A = MakeAction(this, Type, bWhenPaused);
		Actions.Add(Name, A);
		return A;
	};

	UInputAction* Move = Add(TEXT("Move"), EInputActionValueType::Axis2D);
	{
		// W/S map to Y, A/D to X.
		FEnhancedActionKeyMapping& W = Mapping->MapKey(Move, EKeys::W);
		AddModifier<UInputModifierSwizzleAxis>(Mapping, W);
		FEnhancedActionKeyMapping& S = Mapping->MapKey(Move, EKeys::S);
		AddModifier<UInputModifierSwizzleAxis>(Mapping, S);
		AddModifier<UInputModifierNegate>(Mapping, S);
		FEnhancedActionKeyMapping& A = Mapping->MapKey(Move, EKeys::A);
		AddModifier<UInputModifierNegate>(Mapping, A);
		Mapping->MapKey(Move, EKeys::D);
		FEnhancedActionKeyMapping& Stick = Mapping->MapKey(Move, EKeys::Gamepad_Left2D);
		AddModifier<UInputModifierDeadZone>(Mapping, Stick);
	}

	UInputAction* Look = Add(TEXT("Look"), EInputActionValueType::Axis2D);
	Mapping->MapKey(Look, EKeys::Mouse2D);

	UInputAction* LookPad = Add(TEXT("LookPad"), EInputActionValueType::Axis2D);
	{
		FEnhancedActionKeyMapping& Stick = Mapping->MapKey(LookPad, EKeys::Gamepad_Right2D);
		AddModifier<UInputModifierDeadZone>(Mapping, Stick);
	}

	auto Bool = [this, &Add](FName Name, std::initializer_list<FKey> Keys, bool bWhenPaused = false)
	{
		UInputAction* A = Add(Name, EInputActionValueType::Boolean, bWhenPaused);
		for (const FKey& K : Keys)
		{
			Mapping->MapKey(A, K);
		}
		return A;
	};

	Bool(TEXT("Jump"), { EKeys::SpaceBar, EKeys::Gamepad_FaceButton_Bottom });
	Bool(TEXT("Sprint"), { EKeys::LeftShift, EKeys::Gamepad_LeftThumbstick });
	Bool(TEXT("Crouch"), { EKeys::LeftControl, EKeys::C, EKeys::Gamepad_RightThumbstick });
	Bool(TEXT("Interact"), { EKeys::E, EKeys::F, EKeys::Gamepad_FaceButton_Left });
	Bool(TEXT("Manifest"), { EKeys::Q, EKeys::Gamepad_LeftShoulder });
	Bool(TEXT("Use"), { EKeys::LeftMouseButton, EKeys::Gamepad_RightTrigger });
	Bool(TEXT("Throw"), { EKeys::RightMouseButton, EKeys::Gamepad_LeftTrigger });
	Bool(TEXT("Wake"), { EKeys::T, EKeys::Gamepad_DPad_Up });
	Bool(TEXT("Notebook"), { EKeys::N, EKeys::Tab, EKeys::Gamepad_Special_Left });
	Bool(TEXT("Pause"), { EKeys::Escape, EKeys::P, EKeys::Gamepad_Special_Right }, true);
	Bool(TEXT("Choice1"), { EKeys::One });
	Bool(TEXT("Choice2"), { EKeys::Two });
	Bool(TEXT("Choice3"), { EKeys::Three });
	Bool(TEXT("Choice4"), { EKeys::Four });

	UInputAction* Cycle = Add(TEXT("Cycle"), EInputActionValueType::Axis1D);
	Mapping->MapKey(Cycle, EKeys::MouseWheelAxis);
	{
		FEnhancedActionKeyMapping& Left = Mapping->MapKey(Cycle, EKeys::Gamepad_DPad_Left);
		AddModifier<UInputModifierNegate>(Mapping, Left);
		Mapping->MapKey(Cycle, EKeys::Gamepad_DPad_Right);
	}
}

void ADPPlayerController::SetupInputComponent()
{
	Super::SetupInputComponent();
	BuildInput();

	UEnhancedInputComponent* EIC = Cast<UEnhancedInputComponent>(InputComponent);
	if (!EIC)
	{
		UE_LOG(LogTemp, Error, TEXT("DREAM PROTOCOL needs Enhanced Input (see Config/DefaultInput.ini)."));
		return;
	}

	auto A = [this](const TCHAR* Name) { return Actions.FindRef(Name).Get(); };

	EIC->BindAction(A(TEXT("Move")), ETriggerEvent::Triggered, this, &ADPPlayerController::OnMove);
	EIC->BindAction(A(TEXT("Look")), ETriggerEvent::Triggered, this, &ADPPlayerController::OnLook);
	EIC->BindAction(A(TEXT("LookPad")), ETriggerEvent::Triggered, this, &ADPPlayerController::OnLookGamepad);
	EIC->BindAction(A(TEXT("Jump")), ETriggerEvent::Started, this, &ADPPlayerController::OnJump);
	EIC->BindAction(A(TEXT("Sprint")), ETriggerEvent::Started, this, &ADPPlayerController::OnSprintStart);
	EIC->BindAction(A(TEXT("Sprint")), ETriggerEvent::Completed, this, &ADPPlayerController::OnSprintStop);
	EIC->BindAction(A(TEXT("Crouch")), ETriggerEvent::Started, this, &ADPPlayerController::OnCrouch);
	EIC->BindAction(A(TEXT("Interact")), ETriggerEvent::Started, this, &ADPPlayerController::OnInteract);
	EIC->BindAction(A(TEXT("Manifest")), ETriggerEvent::Started, this, &ADPPlayerController::OnManifestStart);
	EIC->BindAction(A(TEXT("Manifest")), ETriggerEvent::Completed, this, &ADPPlayerController::OnManifestStop);
	EIC->BindAction(A(TEXT("Use")), ETriggerEvent::Started, this, &ADPPlayerController::OnUse);
	EIC->BindAction(A(TEXT("Throw")), ETriggerEvent::Started, this, &ADPPlayerController::OnThrow);
	EIC->BindAction(A(TEXT("Cycle")), ETriggerEvent::Started, this, &ADPPlayerController::OnCycle);
	EIC->BindAction(A(TEXT("Wake")), ETriggerEvent::Started, this, &ADPPlayerController::OnWakeStart);
	EIC->BindAction(A(TEXT("Wake")), ETriggerEvent::Completed, this, &ADPPlayerController::OnWakeStop);
	EIC->BindAction(A(TEXT("Notebook")), ETriggerEvent::Started, this, &ADPPlayerController::OnNotebook);
	EIC->BindAction(A(TEXT("Pause")), ETriggerEvent::Started, this, &ADPPlayerController::OnPause);
	EIC->BindAction(A(TEXT("Choice1")), ETriggerEvent::Started, this, &ADPPlayerController::OnChoice1);
	EIC->BindAction(A(TEXT("Choice2")), ETriggerEvent::Started, this, &ADPPlayerController::OnChoice2);
	EIC->BindAction(A(TEXT("Choice3")), ETriggerEvent::Started, this, &ADPPlayerController::OnChoice3);
	EIC->BindAction(A(TEXT("Choice4")), ETriggerEvent::Started, this, &ADPPlayerController::OnChoice4);
}

void ADPPlayerController::BeginPlay()
{
	Super::BeginPlay();
	BuildInput();

	if (ULocalPlayer* LP = GetLocalPlayer())
	{
		if (UEnhancedInputLocalPlayerSubsystem* Sub = ULocalPlayer::GetSubsystem<UEnhancedInputLocalPlayerSubsystem>(LP))
		{
			Sub->ClearAllMappings();
			Sub->AddMappingContext(Mapping, 0);
		}
	}
}

ADPCharacter* ADPPlayerController::GetDPCharacter() const
{
	return Cast<ADPCharacter>(GetPawn());
}

ADPHUD* ADPPlayerController::GetDPHUD() const
{
	return Cast<ADPHUD>(GetHUD());
}

// ---------------------------------------------------------------- Modes

void ADPPlayerController::SetInputModeDP(EDPInputMode NewMode, TSharedPtr<SWidget> Focus)
{
	Mode = NewMode;
	switch (NewMode)
	{
	case EDPInputMode::Game:
	case EDPInputMode::Cinematic:
	{
		FInputModeGameOnly M;
		SetInputMode(M);
		bShowMouseCursor = false;
		FSlateApplication::Get().SetAllUserFocusToGameViewport();
		break;
	}
	case EDPInputMode::Dialogue:
	{
		FInputModeGameAndUI M;
		M.SetHideCursorDuringCapture(false);
		M.SetLockMouseToViewportBehavior(EMouseLockMode::LockAlways);
		SetInputMode(M);
		bShowMouseCursor = true;
		break;
	}
	case EDPInputMode::Overlay:
	case EDPInputMode::Menu:
	{
		FInputModeUIOnly M;
		if (Focus.IsValid())
		{
			M.SetWidgetToFocus(Focus);
		}
		M.SetLockMouseToViewportBehavior(EMouseLockMode::LockAlways);
		SetInputMode(M);
		bShowMouseCursor = (NewMode == EDPInputMode::Menu);
		if (Focus.IsValid())
		{
			FSlateApplication::Get().SetAllUserFocus(Focus, EFocusCause::SetDirectly);
		}
		break;
	}
	}

	if (ADPCharacter* C = GetDPCharacter())
	{
		C->SetControlsLocked(NewMode != EDPInputMode::Game);
	}
	if (ADPHUD* HUD = GetDPHUD())
	{
		HUD->SetGameplayHUDVisible(NewMode == EDPInputMode::Game || NewMode == EDPInputMode::Dialogue);
	}
}

bool ADPPlayerController::CanControlCharacter() const
{
	return Mode == EDPInputMode::Game && GetDPCharacter() != nullptr;
}

void ADPPlayerController::EnterDialogueMode()
{
	SetInputModeDP(EDPInputMode::Dialogue);
}

void ADPPlayerController::ExitDialogueMode()
{
	if (Mode == EDPInputMode::Dialogue)
	{
		SetInputModeDP(EDPInputMode::Game);
	}
}

void ADPPlayerController::ShowTitle(bool bHasCheckpoint)
{
	if (ADPHUD* HUD = GetDPHUD())
	{
		SetInputModeDP(EDPInputMode::Menu, HUD->OpenTitleMenu(bHasCheckpoint));
	}
}

// ---------------------------------------------------------------- Notebook

void ADPPlayerController::OpenNotebook()
{
	ADPGameMode* GM = ADPGameMode::Get(this);
	ADPHUD* HUD = GetDPHUD();
	UDPNotebookSubsystem* Notebook = GetWorld()->GetSubsystem<UDPNotebookSubsystem>();
	if (!GM || !HUD || !Notebook || Mode != EDPInputMode::Game)
	{
		return;
	}
	if (!GM->HasFlag(TEXT("has_notebook")))
	{
		if (GM->GetZoneType() == EDPZone::Bedroom && Notebook->HasAnyWritten())
		{
			HUD->ShowThought(LOCTEXT("OnDesk", "It's on the desk."), 2.f);
		}
		return;
	}

	Notebook->OnNotebookOpened();
	if (ADPCharacter* C = GetDPCharacter())
	{
		C->PlayFoley(EDPSynthEvent::Page, 0.8f);
	}
	TSharedRef<SWidget> W = HUD->OpenNotebook(LOCTEXT("NotebookHeader", "LUCID DREAM RULES (!!)"), Notebook->BuildPage());
	SetInputModeDP(EDPInputMode::Overlay, W);
}

void ADPPlayerController::CloseNotebook()
{
	if (ADPHUD* HUD = GetDPHUD())
	{
		HUD->CloseOverlay();
	}
	if (ADPCharacter* C = GetDPCharacter())
	{
		C->PlayFoley(EDPSynthEvent::Page, 0.5f);
	}
	SetInputModeDP(EDPInputMode::Game);
}

// ---------------------------------------------------------------- Pause

void ADPPlayerController::OpenPauseMenu()
{
	ADPHUD* HUD = GetDPHUD();
	ADPGameMode* GM = ADPGameMode::Get(this);
	if (!HUD || !GM || HUD->IsMenuOpen())
	{
		return;
	}

	// Decide whether the menu is "corrupted". Rare, only during real fear, never permanent.
	bool bCorrupted = false;
	bool bMaySelfUnpause = false;
	UDPGameInstance* GI = Cast<UDPGameInstance>(GetGameInstance());
	const UDPSettingsSave& S = DPSettings::Get(this);
	const ADPCharacter* C = GetDPCharacter();
	const ADPZone* Zone = GM->GetZone();
	if (GI && C && Zone && Zone->IsNightmare() && S.bMenuCorruption && !GM->IsInSequence())
	{
		const EDPDreadStage Stage = C->GetDread()->GetStage();
		const double Now = FPlatformTime::Seconds();
		const bool bCooledDown = Now - GI->LastCorruptedMenuTime > 120.0;
		const bool bScaredEnough = Stage >= EDPDreadStage::Terrified || (Stage == EDPDreadStage::Afraid && FMath::FRand() < 0.35f);
		if (bCooledDown && bScaredEnough && GI->CorruptedMenusShown < 3)
		{
			bCorrupted = true;
			GI->CorruptedMenusShown++;
			GI->LastCorruptedMenuTime = Now;
			bMaySelfUnpause = S.bSelfUnpause && !GI->bSelfUnpauseUsed && Stage >= EDPDreadStage::Terrified;
		}
	}

	ModeBeforeMenu = (Mode == EDPInputMode::Menu) ? EDPInputMode::Game : Mode;
	TSharedRef<SWidget> W = HUD->OpenPauseMenu(bCorrupted, bMaySelfUnpause);
	SetPause(true);
	SetInputModeDP(EDPInputMode::Menu, W);
}

void ADPPlayerController::ResumeFromPause(bool bSelfUnpause)
{
	ADPHUD* HUD = GetDPHUD();
	if (HUD)
	{
		HUD->CloseMenu();
	}
	SetPause(false);

	const EDPInputMode Back = (ModeBeforeMenu == EDPInputMode::Overlay || ModeBeforeMenu == EDPInputMode::Menu) ? EDPInputMode::Game : ModeBeforeMenu;
	SetInputModeDP(Back);

	if (bSelfUnpause)
	{
		if (UDPGameInstance* GI = Cast<UDPGameInstance>(GetGameInstance()))
		{
			GI->bSelfUnpauseUsed = true;
		}
		if (ADPCharacter* C = GetDPCharacter())
		{
			C->GetDread()->AddFear(5.f, TEXT("SelfUnpause"));
			C->AddCameraJolt(FRotator(2.f, -3.f, 0.f));
		}
	}
}

void ADPPlayerController::QuitToDesktop()
{
	UKismetSystemLibrary::QuitGame(this, this, EQuitPreference::Quit, false);
}

// ---------------------------------------------------------------- Handlers

void ADPPlayerController::OnMove(const FInputActionValue& Value)
{
	if (CanControlCharacter())
	{
		GetDPCharacter()->InputMove(Value.Get<FVector2D>());
	}
}

void ADPPlayerController::OnLook(const FInputActionValue& Value)
{
	if (!CanControlCharacter())
	{
		return;
	}
	const UDPSettingsSave& S = DPSettings::Get(this);
	const FVector2D V = Value.Get<FVector2D>() * S.MouseSensitivity;
	AddYawInput(V.X);
	AddPitchInput(S.bInvertY ? V.Y : -V.Y);
}

void ADPPlayerController::OnLookGamepad(const FInputActionValue& Value)
{
	if (!CanControlCharacter())
	{
		return;
	}
	const UDPSettingsSave& S = DPSettings::Get(this);
	const float Dt = GetWorld()->GetDeltaSeconds();
	const FVector2D V = Value.Get<FVector2D>() * S.MouseSensitivity * 60.f * Dt;
	AddYawInput(V.X);
	AddPitchInput(S.bInvertY ? V.Y : -V.Y);
}

void ADPPlayerController::OnJump()          { if (CanControlCharacter()) GetDPCharacter()->InputJump(); }
void ADPPlayerController::OnSprintStart()   { if (GetDPCharacter()) GetDPCharacter()->InputSprint(true); }
void ADPPlayerController::OnSprintStop()    { if (GetDPCharacter()) GetDPCharacter()->InputSprint(false); }
void ADPPlayerController::OnCrouch()        { if (CanControlCharacter()) GetDPCharacter()->InputCrouchToggle(); }
void ADPPlayerController::OnManifestStart() { if (CanControlCharacter()) GetDPCharacter()->InputManifest(true); }
void ADPPlayerController::OnManifestStop()  { if (GetDPCharacter()) GetDPCharacter()->InputManifest(false); }
void ADPPlayerController::OnUse()           { if (CanControlCharacter()) GetDPCharacter()->InputUseItem(); }
void ADPPlayerController::OnThrow()         { if (CanControlCharacter()) GetDPCharacter()->InputThrowItem(); }
void ADPPlayerController::OnWakeStart()     { if (CanControlCharacter()) GetDPCharacter()->InputWake(true); }
void ADPPlayerController::OnWakeStop()      { if (GetDPCharacter()) GetDPCharacter()->InputWake(false); }

void ADPPlayerController::OnCycle(const FInputActionValue& Value)
{
	if (CanControlCharacter())
	{
		GetDPCharacter()->InputCycleManifest(Value.Get<float>());
	}
}

void ADPPlayerController::OnInteract()
{
	if (Mode == EDPInputMode::Dialogue)
	{
		if (UDPDialogueSubsystem* D = GetWorld()->GetSubsystem<UDPDialogueSubsystem>())
		{
			D->Advance();
		}
		return;
	}
	if (CanControlCharacter())
	{
		GetDPCharacter()->InputInteract();
	}
}

void ADPPlayerController::OnChoice(int32 Index)
{
	if (Mode == EDPInputMode::Dialogue)
	{
		if (UDPDialogueSubsystem* D = GetWorld()->GetSubsystem<UDPDialogueSubsystem>())
		{
			D->Choose(Index);
		}
	}
}

void ADPPlayerController::OnChoice1() { OnChoice(0); }
void ADPPlayerController::OnChoice2() { OnChoice(1); }
void ADPPlayerController::OnChoice3() { OnChoice(2); }
void ADPPlayerController::OnChoice4() { OnChoice(3); }

void ADPPlayerController::OnNotebook()
{
	if (Mode == EDPInputMode::Game)
	{
		OpenNotebook();
	}
}

void ADPPlayerController::OnPause()
{
	// Menus and overlays handle Escape themselves (they have keyboard focus).
	if (Mode == EDPInputMode::Game || Mode == EDPInputMode::Dialogue || Mode == EDPInputMode::Cinematic)
	{
		OpenPauseMenu();
	}
}

#undef LOCTEXT_NAMESPACE
