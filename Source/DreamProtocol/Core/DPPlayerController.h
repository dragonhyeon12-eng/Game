#pragma once

#include "CoreMinimal.h"
#include "GameFramework/PlayerController.h"
#include "DPPlayerController.generated.h"

class UInputAction;
class UInputMappingContext;
class ADPCharacter;
class ADPHUD;
class SWidget;
struct FInputActionValue;

/** What the player's input is currently driving. */
enum class EDPInputMode : uint8
{
	Game,       // walking around
	Dialogue,   // in conversation: no movement, cursor visible, choices by click or number keys
	Overlay,    // notebook / tutorial: UI-only, game keeps running
	Menu,       // title / pause / settings
	Cinematic   // scripted sequence: no input at all
};

/**
 * Builds all input bindings in code (Enhanced Input, no assets needed) and owns UI/pause flow.
 * The pause menu's horror variant is decided here, and is always escapable.
 */
UCLASS()
class DREAMPROTOCOL_API ADPPlayerController : public APlayerController
{
	GENERATED_BODY()

public:
	ADPPlayerController();

	virtual void BeginPlay() override;
	virtual void SetupInputComponent() override;

	void SetInputModeDP(EDPInputMode Mode, TSharedPtr<SWidget> Focus = nullptr);
	EDPInputMode GetInputModeDP() const { return Mode; }

	// Flow
	void EnterDialogueMode();
	void ExitDialogueMode();
	void OpenNotebook();
	void CloseNotebook();
	void OpenPauseMenu();
	void ResumeFromPause(bool bSelfUnpause = false);
	void ShowTitle(bool bHasCheckpoint);
	void QuitToDesktop();

	ADPCharacter* GetDPCharacter() const;
	ADPHUD* GetDPHUD() const;

private:
	void BuildInput();
	bool CanControlCharacter() const;

	void OnMove(const FInputActionValue& Value);
	void OnLook(const FInputActionValue& Value);
	void OnLookGamepad(const FInputActionValue& Value);
	void OnJump();
	void OnSprintStart();
	void OnSprintStop();
	void OnCrouch();
	void OnInteract();
	void OnManifestStart();
	void OnManifestStop();
	void OnUse();
	void OnThrow();
	void OnCycle(const FInputActionValue& Value);
	void OnWakeStart();
	void OnWakeStop();
	void OnNotebook();
	void OnPause();
	void OnChoice(int32 Index);
	void OnChoice1();
	void OnChoice2();
	void OnChoice3();
	void OnChoice4();

	UPROPERTY()
	TObjectPtr<UInputMappingContext> Mapping;

	UPROPERTY()
	TMap<FName, TObjectPtr<UInputAction>> Actions;

	EDPInputMode Mode = EDPInputMode::Game;
	EDPInputMode ModeBeforeMenu = EDPInputMode::Game;
	bool bInputBuilt = false;
};
