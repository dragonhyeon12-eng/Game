#include "Core/DPGameMode.h"
#include "Core/DPCharacter.h"
#include "Core/DPData.h"
#include "Core/DPPlayerController.h"
#include "Core/DPSaveGame.h"
#include "Core/DPSettings.h"
#include "Anomaly/DPAnomalySubsystem.h"
#include "Dialogue/DPDialogueSubsystem.h"
#include "Dread/DPDreadComponent.h"
#include "Dread/DPDreadDirector.h"
#include "Manifestation/DPManifestationComponent.h"
#include "Notebook/DPNotebookSubsystem.h"
#include "UI/DPHUD.h"
#include "World/DPBedroomZone.h"
#include "World/DPMazeZone.h"
#include "World/DPSummerCityZone.h"
#include "DreamProtocol.h"
#include "EngineUtils.h"
#include "Engine/DirectionalLight.h"
#include "Kismet/GameplayStatics.h"
#include "TimerManager.h"
#include "GameFramework/CharacterMovementComponent.h"

#define LOCTEXT_NAMESPACE "DPGameMode"

ADPGameMode::ADPGameMode()
{
	DefaultPawnClass = ADPCharacter::StaticClass();
	PlayerControllerClass = ADPPlayerController::StaticClass();
	HUDClass = ADPHUD::StaticClass();
}

ADPGameMode* ADPGameMode::Get(const UObject* WorldContext)
{
	const UWorld* World = WorldContext ? WorldContext->GetWorld() : nullptr;
	return World ? Cast<ADPGameMode>(World->GetAuthGameMode()) : nullptr;
}

ADPHUD* ADPGameMode::GetDPHUD() const
{
	const ADPPlayerController* PC = GetDPController();
	return PC ? PC->GetDPHUD() : nullptr;
}

ADPPlayerController* ADPGameMode::GetDPController() const
{
	return Cast<ADPPlayerController>(UGameplayStatics::GetPlayerController(this, 0));
}

ADPCharacter* ADPGameMode::GetDPCharacter() const
{
	return Cast<ADPCharacter>(UGameplayStatics::GetPlayerPawn(this, 0));
}

void ADPGameMode::BeginPlay()
{
	Super::BeginPlay();

	// The game builds all of its own lighting; warn if the map brought its own.
	for (TActorIterator<ADirectionalLight> It(GetWorld()); It; ++It)
	{
		UE_LOG(LogDream, Warning, TEXT("The map contains %s. DREAM PROTOCOL expects an *empty* level (File > New Level > Empty Level)."), *It->GetName());
	}

	// Wait one tick so the player controller, pawn and HUD all exist.
	GetWorldTimerManager().SetTimerForNextTick(FTimerDelegate::CreateWeakLambda(this, [this]() { ShowTitle(); }));
}

void ADPGameMode::RestartPlayer(AController* NewPlayer)
{
	Super::RestartPlayer(NewPlayer);
	if (CurrentZone)
	{
		PlacePlayer();
	}
}

// ---------------------------------------------------------------- Sequencing

void ADPGameMode::After(float Seconds, TFunction<void()> Fn)
{
	FTimerHandle Handle;
	GetWorldTimerManager().SetTimer(Handle, FTimerDelegate::CreateWeakLambda(this, [Fn]() { Fn(); }), FMath::Max(0.01f, Seconds), false);
	SequenceTimers.Add(Handle);
}

void ADPGameMode::ClearSequence()
{
	for (FTimerHandle& H : SequenceTimers)
	{
		GetWorldTimerManager().ClearTimer(H);
	}
	SequenceTimers.Reset();
	bInSequence = false;
}

// ---------------------------------------------------------------- Zones

void ADPGameMode::EnterZone(EDPZone Zone, bool bFromSave, bool bWakingVariant)
{
	ADPCharacter* Char = GetDPCharacter();
	if (Char)
	{
		Char->GetManifestation()->ClearAll();
	}
	if (UDPDialogueSubsystem* Dialogue = GetWorld()->GetSubsystem<UDPDialogueSubsystem>())
	{
		Dialogue->EndDialogue();
	}

	if (CurrentZone)
	{
		CurrentZone->Destroy();
		CurrentZone = nullptr;
	}

	FActorSpawnParameters Params;
	Params.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;
	switch (Zone)
	{
	case EDPZone::Bedroom:
	{
		ADPBedroomZone* Z = GetWorld()->SpawnActor<ADPBedroomZone>(ADPBedroomZone::StaticClass(), FTransform::Identity, Params);
		Z->bWakingVariant = bWakingVariant;
		CurrentZone = Z;
		break;
	}
	case EDPZone::SummerCity:
		CurrentZone = GetWorld()->SpawnActor<ADPSummerCityZone>(ADPSummerCityZone::StaticClass(), FTransform::Identity, Params);
		break;
	case EDPZone::Maze:
	{
		ADPMazeZone* Z = GetWorld()->SpawnActor<ADPMazeZone>(ADPMazeZone::StaticClass(), FTransform::Identity, Params);
		Z->Seed = MazeSeed;
		CurrentZone = Z;
		break;
	}
	default:
		break;
	}
	CurrentZoneType = Zone;

	if (!CurrentZone)
	{
		UE_LOG(LogDream, Error, TEXT("Failed to spawn zone %d"), static_cast<int32>(Zone));
		return;
	}

	CurrentZone->BuildZone();
	PlacePlayer();

	if (Char)
	{
		Char->GetDread()->SetZoneProfile(CurrentZone->IsNightmare(), CurrentZone->GetFearGainMultiplier(),
			CurrentZone->GetFearFloor(), CurrentZone->GetFearDecayRate());
		Char->SetMovementProfile(CurrentZone->GetWalkSpeed(), CurrentZone->GetSprintSpeed(), CurrentZone->HasSoftFloor());
		CurrentZone->OnPlayerEntered(Char, bFromSave);
	}

	UE_LOG(LogDream, Log, TEXT("Entered zone %d%s"), static_cast<int32>(Zone), bWakingVariant ? TEXT(" (waking)") : TEXT(""));
}

void ADPGameMode::PlacePlayer()
{
	ADPCharacter* Char = GetDPCharacter();
	if (!Char || !CurrentZone)
	{
		return;
	}
	BindPlayer();
	Char->TeleportTo(CurrentZone->GetPlayerStart());
}

void ADPGameMode::BindPlayer()
{
	ADPCharacter* Char = GetDPCharacter();
	if (!Char || BoundCharacter.Get() == Char)
	{
		return;
	}
	BoundCharacter = Char;
	Char->GetDread()->OnOverwhelmed.AddUObject(this, &ADPGameMode::OnOverwhelmed);
}

void ADPGameMode::ApplySettingsEverywhere()
{
	if (ADPCharacter* Char = GetDPCharacter())
	{
		Char->ApplySettings();
	}
	if (CurrentZone)
	{
		CurrentZone->ApplyAudioSettings();
	}
	if (ADPHUD* HUD = GetDPHUD())
	{
		HUD->ApplySettings();
	}
}

// ---------------------------------------------------------------- Game state

void ADPGameMode::ResetWorldState()
{
	ClearSequence();
	Flags.Reset();

	UWorld* World = GetWorld();
	if (UDPNotebookSubsystem* Notebook = World->GetSubsystem<UDPNotebookSubsystem>()) Notebook->ResetState();
	if (UDPDialogueSubsystem* Dialogue = World->GetSubsystem<UDPDialogueSubsystem>()) Dialogue->EndDialogue();
	if (UDPAnomalySubsystem* Anomalies = World->GetSubsystem<UDPAnomalySubsystem>()) Anomalies->Clear();
	if (UDPDreadDirector* Director = World->GetSubsystem<UDPDreadDirector>()) Director->ResetDirector();

	if (ADPCharacter* Char = GetDPCharacter())
	{
		Char->ResetPresentation();
		Char->GetDread()->SetValues(0.f, 100.f);
		Char->GetManifestation()->ResetUnlocks();
	}
	if (ADPHUD* HUD = GetDPHUD())
	{
		HUD->ClearTransientText();
		HUD->CloseOverlay();
		HUD->HideCard(0.f);
	}
	if (ADPPlayerController* PC = GetDPController())
	{
		PC->SetPause(false);
	}
}

bool ADPGameMode::HasCheckpoint() const
{
	return UGameplayStatics::DoesSaveGameExist(UDPSaveGame::SlotName(), 0);
}

void ADPGameMode::SaveCheckpoint()
{
	UDPSaveGame* Save = Cast<UDPSaveGame>(UGameplayStatics::CreateSaveGameObject(UDPSaveGame::StaticClass()));
	if (!Save)
	{
		return;
	}
	Save->Zone = CurrentZoneType;
	Save->Flags = Flags.Array();
	Save->MazeSeed = MazeSeed;
	if (const UDPNotebookSubsystem* Notebook = GetWorld()->GetSubsystem<UDPNotebookSubsystem>())
	{
		Save->Rules = Notebook->GetState();
	}
	if (const ADPCharacter* Char = GetDPCharacter())
	{
		Save->Fear = Char->GetDread()->GetFear();
		Save->Stability = Char->GetDread()->GetStability();
		Save->UnlockedManifests = Char->GetManifestation()->GetUnlocked();
	}
	const bool bOk = UGameplayStatics::SaveGameToSlot(Save, UDPSaveGame::SlotName(), 0);
	UE_LOG(LogDream, Log, TEXT("Checkpoint %s (zone %d)"), bOk ? TEXT("saved") : TEXT("FAILED"), static_cast<int32>(CurrentZoneType));
}

bool ADPGameMode::RestoreCheckpoint(float FearOverride, float StabilityOverride)
{
	const UDPSaveGame* Save = HasCheckpoint() ? Cast<UDPSaveGame>(UGameplayStatics::LoadGameFromSlot(UDPSaveGame::SlotName(), 0)) : nullptr;
	if (!Save || Save->Zone == EDPZone::None)
	{
		return false;
	}

	ResetWorldState();
	for (const FName& F : Save->Flags)
	{
		Flags.Add(F);
	}
	MazeSeed = Save->MazeSeed;
	if (UDPNotebookSubsystem* Notebook = GetWorld()->GetSubsystem<UDPNotebookSubsystem>())
	{
		Notebook->LoadState(Save->Rules);
	}

	EnterZone(Save->Zone, true);

	if (ADPCharacter* Char = GetDPCharacter())
	{
		Char->GetManifestation()->SetUnlocked(Save->UnlockedManifests);
		Char->GetDread()->SetValues(FearOverride >= 0.f ? FearOverride : Save->Fear, StabilityOverride >= 0.f ? StabilityOverride : Save->Stability);
	}
	return true;
}

// ---------------------------------------------------------------- Flow

void ADPGameMode::ShowTitle()
{
	ResetWorldState();
	EnterZone(EDPZone::Bedroom, false);
	if (ADPHUD* HUD = GetDPHUD())
	{
		HUD->SetFade(1.f);
		HUD->FadeTo(0.f, 2.f);
	}
	if (ADPPlayerController* PC = GetDPController())
	{
		PC->ShowTitle(HasCheckpoint());
	}
}

void ADPGameMode::StartNewGame()
{
	ADPHUD* HUD = GetDPHUD();
	ADPPlayerController* PC = GetDPController();
	if (HUD)
	{
		HUD->CloseMenu();
	}

	FDPData::ReloadAll();
	ResetWorldState();
	MazeSeed = FMath::RandRange(1, 1 << 30);
	EnterZone(EDPZone::Bedroom, false);
	SaveCheckpoint();

	if (PC)
	{
		PC->SetInputModeDP(EDPInputMode::Game);
	}
	if (HUD)
	{
		HUD->SetFade(1.f);
		HUD->FadeTo(0.f, 2.5f);
		After(2.f, [HUD]() { HUD->ShowThought(LOCTEXT("Late", "Almost three in the morning. The video's still open."), 4.5f); });
		After(6.f, [HUD]() { HUD->ShowHint(LOCTEXT("Controls", "Mouse: look     WASD: move     Shift: run     E: interact\nEsc / P: pause"), 9.f); });
	}
}

void ADPGameMode::ContinueGame()
{
	ADPHUD* HUD = GetDPHUD();
	if (HUD)
	{
		HUD->CloseMenu();
	}
	if (!RestoreCheckpoint())
	{
		StartNewGame();
		return;
	}
	if (ADPPlayerController* PC = GetDPController())
	{
		PC->SetInputModeDP(EDPInputMode::Game);
	}
	if (HUD)
	{
		HUD->SetFade(1.f);
		HUD->FadeTo(0.f, 2.f);
	}
}

void ADPGameMode::ReturnToTitle()
{
	if (ADPHUD* HUD = GetDPHUD())
	{
		HUD->CloseMenu();
	}
	ShowTitle();
}

// ---------------------------------------------------------------- Bedroom

void ADPGameMode::RequestTutorial()
{
	ADPHUD* HUD = GetDPHUD();
	ADPPlayerController* PC = GetDPController();
	if (!HUD || !PC)
	{
		return;
	}
	TSharedRef<SWidget> W = HUD->OpenTutorial(FDPData::Tutorial());
	PC->SetInputModeDP(EDPInputMode::Overlay, W);
}

void ADPGameMode::OnTutorialFinished()
{
	ADPHUD* HUD = GetDPHUD();
	SetFlag(TEXT("tutorial_done"));
	After(0.6f, [this, HUD]()
	{
		if (HUD)
		{
			HUD->CloseOverlay();
			HUD->ShowThought(LOCTEXT("Written", "Five rules. Written down. Okay."), 3.5f);
			HUD->ShowHint(LOCTEXT("TakeIt", "Take the notebook from the desk, then go to bed."), 7.f);
		}
		if (ADPPlayerController* PC = GetDPController())
		{
			PC->SetInputModeDP(EDPInputMode::Game);
		}
	});
}

void ADPGameMode::RequestSleep()
{
	if (bInSequence)
	{
		return;
	}
	bInSequence = true;
	ADPHUD* HUD = GetDPHUD();
	if (ADPPlayerController* PC = GetDPController())
	{
		PC->SetInputModeDP(EDPInputMode::Cinematic);
	}
	if (HUD)
	{
		HUD->ShowThought(LOCTEXT("Mantra", "I will know I'm dreaming. I will know I'm dreaming..."), 5.f);
		HUD->FadeTo(1.f, 3.f);
	}

	After(4.f, [HUD]() { if (HUD) HUD->ShowCard(LOCTEXT("Time", "3:12 AM"), FText::GetEmpty(), 1.f); });
	After(7.f, [HUD]() { if (HUD) HUD->HideCard(1.f); });
	After(8.5f, [this, HUD]()
	{
		EnterZone(EDPZone::SummerCity, false);
		SaveCheckpoint();
		if (HUD)
		{
			HUD->FadeTo(0.f, 3.5f);
		}
		bInSequence = false;
		if (ADPPlayerController* PC = GetDPController())
		{
			PC->SetInputModeDP(EDPInputMode::Game);
		}
	});
}

// ---------------------------------------------------------------- Waking up (falling)

void ADPGameMode::RequestWake()
{
	ADPHUD* HUD = GetDPHUD();
	ADPCharacter* Char = GetDPCharacter();
	if (bInSequence || !HUD || !Char)
	{
		return;
	}

	if (CurrentZoneType == EDPZone::Maze)
	{
		HUD->ShowThought(LOCTEXT("CantWake", "Wake up. Wake up. Wake up. ...Nothing."), 3.5f);
		Char->GetDread()->AddFear(4.f, TEXT("CantWake"));
		return;
	}
	if (CurrentZoneType != EDPZone::SummerCity)
	{
		return;
	}

	bInSequence = true;
	if (ADPPlayerController* PC = GetDPController())
	{
		PC->SetInputModeDP(EDPInputMode::Cinematic);
	}
	HUD->ShowThought(LOCTEXT("WakeUp", "Okay. That's enough. Wake up."), 3.f);

	After(1.6f, [this, Char]()
	{
		// The floor simply stops being there.
		Char->PlayFoley(EDPSynthEvent::Thud, 0.8f);
		Char->PlayFoley(EDPSynthEvent::Whoosh, 1.f);
		Char->AddCameraJolt(FRotator(-8.f, 0.f, 3.f));
		Char->SetPhasing(true);
		SetFlag(TEXT("fell_through"));
		if (UDPNotebookSubsystem* Notebook = GetWorld()->GetSubsystem<UDPNotebookSubsystem>())
		{
			Notebook->RevealOnNextOpen(TEXT("never_twice"));
		}
	});
	After(3.2f, [HUD]() { HUD->FadeTo(1.f, 0.6f); });
	After(4.2f, [this, HUD, Char]()
	{
		Char->SetPhasing(false);
		EnterZone(EDPZone::Maze, false);
		Char->GetDread()->SetValues(FMath::Max(Char->GetDread()->GetFear(), 22.f), Char->GetDread()->GetStability());
		SaveCheckpoint();
		HUD->FadeTo(0.f, 3.f);
		bInSequence = false;
		if (ADPPlayerController* PC = GetDPController())
		{
			PC->SetInputModeDP(EDPInputMode::Game);
		}
	});
}

// ---------------------------------------------------------------- Maze exit (end of slice)

void ADPGameMode::OnMazeExitReached()
{
	if (bInSequence)
	{
		return;
	}
	bInSequence = true;
	ADPHUD* HUD = GetDPHUD();
	if (ADPPlayerController* PC = GetDPController())
	{
		PC->SetInputModeDP(EDPInputMode::Cinematic);
	}
	SetFlag(TEXT("maze_escaped"));
	if (HUD)
	{
		HUD->FadeTo(1.f, 1.2f);
	}

	// Deliberate silence: everything stops at once.
	After(1.5f, [this]()
	{
		if (CurrentZone)
		{
			CurrentZone->Destroy();
			CurrentZone = nullptr;
		}
		CurrentZoneType = EDPZone::None;
		if (ADPCharacter* Char = GetDPCharacter())
		{
			Char->GetCharacterMovement()->DisableMovement(); // nothing below; just hang in the dark
			Char->SetDroneIntensity(0.f);
			Char->GetDread()->SetZoneProfile(false, 0.f, 0.f, 10.f);
		}
	});
	After(4.5f, [HUD]()
	{
		if (HUD)
		{
			HUD->ShowCard(LOCTEXT("Begins", "Now the nightmare begins."),
				LOCTEXT("SliceEnd", "End of the DREAM PROTOCOL vertical slice. Thank you for playing."), 2.f);
		}
	});
	After(12.f, [HUD]() { if (HUD) HUD->HideCard(1.5f); });
	After(14.f, [this]() { ReturnToTitle(); });
}

// ---------------------------------------------------------------- Death

void ADPGameMode::OnOverwhelmed()
{
	if (bInSequence || !CurrentZone || !CurrentZone->IsNightmare())
	{
		return;
	}
	PlayDeathSequence();
}

void ADPGameMode::PlayDeathSequence()
{
	ADPHUD* HUD = GetDPHUD();
	ADPCharacter* Char = GetDPCharacter();
	ADPPlayerController* PC = GetDPController();
	if (!HUD || !Char || !PC)
	{
		return;
	}
	bInSequence = true;
	HUD->CloseOverlay();
	HUD->ClearTransientText();
	PC->SetInputModeDP(EDPInputMode::Cinematic);
	HUD->FadeTo(1.f, 0.15f);

	After(0.8f, [this, HUD, Char]()
	{
		// You seem to wake up.
		EnterZone(EDPZone::Bedroom, false, /*bWakingVariant*/ true);
		Char->GetDread()->SetValues(0.f, 100.f);
		Char->SetControlsLocked(true);
		HUD->FadeTo(0.f, 2.5f);
	});
	After(3.0f, [HUD]() { HUD->ShowThought(LOCTEXT("Awake", "...I'm awake. Okay. I'm awake."), 3.f); });
	After(6.5f, [Char]()
	{
		// Something, right behind you.
		const FVector Behind = Char->GetActorLocation() - Char->GetActorForwardVector() * 120.f + FVector(0, 0, 40.f);
		Char->PlayEventAt(EDPSynthEvent::Thud, Behind, 1.f);
	});
	After(7.3f, [this, HUD, Char]()
	{
		Char->PlayShoulderGrab();
		Char->AddCameraJolt(FRotator(-7.f, 4.f, -3.f));
		const float V = FMath::Clamp(DPSettings::Get(this).VisualIntensity, 0.3f, 1.f);
		HUD->SetFade(0.75f * V, FLinearColor(0.55f, 0.f, 0.f));
	});
	After(7.5f, [HUD]() { HUD->FadeTo(1.f, 0.2f); });
	After(9.f, [HUD]() { HUD->ShowCard(LOCTEXT("WokeUp", "You woke up."), FText::GetEmpty(), 1.2f); });
	After(12.f, [HUD]() { HUD->HideCard(0.8f); });
	After(13.2f, [HUD]() { HUD->ShowCard(LOCTEXT("DidYou", "Didn't you?"), FText::GetEmpty(), 0.8f); });
	After(16.f, [HUD]() { HUD->HideCard(0.8f); });
	After(17.2f, [this, HUD, Char]()
	{
		Char->ResetPresentation();
		if (!RestoreCheckpoint(30.f, 60.f))
		{
			ShowTitle();
			return;
		}
		HUD->FadeTo(0.f, 2.f);
		if (ADPPlayerController* P = GetDPController())
		{
			P->SetInputModeDP(EDPInputMode::Game);
		}
	});
}

#undef LOCTEXT_NAMESPACE
