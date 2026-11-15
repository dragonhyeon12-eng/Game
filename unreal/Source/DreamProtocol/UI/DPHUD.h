#pragma once

#include "CoreMinimal.h"
#include "GameFramework/HUD.h"
#include "Notebook/DPNotebookSubsystem.h"
#include "DPHUD.generated.h"

class SBox;
class SOverlay;
class SVerticalBox;
class SWidget;
class ADPPlayerController;
class ADPCharacter;
struct FDPTutorialFile;

/**
 * Owns every on-screen element (Slate, built in code): crosshair, prompts, thoughts, hints, dialogue,
 * DREAD meter, fades, title cards, menus, notebook and the tutorial video.
 * Gameplay code talks to it through small, intention-named calls (ShowThought, FadeTo, ...).
 */
UCLASS()
class DREAMPROTOCOL_API ADPHUD : public AHUD
{
	GENERATED_BODY()

public:
	ADPHUD();

	virtual void BeginPlay() override;
	virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;
	virtual void Tick(float DeltaSeconds) override;

	// ---- Text
	void ShowThought(const FText& Text, float Seconds = 4.f);
	void ShowHint(const FText& Text, float Seconds = 6.f);
	void ClearTransientText();

	// ---- Dialogue
	void ShowDialogue(const FText& Speaker, const FText& Line, const TArray<FText>& Choices);
	void HideDialogue();

	// ---- Screen
	void FadeTo(float TargetAlpha, float Seconds, const FLinearColor& Color = FLinearColor::Black);
	void SetFade(float Alpha, const FLinearColor& Color = FLinearColor::Black);
	void ShowCard(const FText& Big, const FText& Small = FText::GetEmpty(), float FadeSeconds = 1.f);
	void HideCard(float FadeSeconds = 1.f);
	void SetGameplayHUDVisible(bool bVisible) { bGameplayHUDVisible = bVisible; }

	// ---- Menus (return the widget to focus)
	TSharedRef<SWidget> OpenTitleMenu(bool bHasCheckpoint);
	TSharedRef<SWidget> OpenPauseMenu(bool bCorrupted, bool bMayUnpauseItself);
	void CloseMenu();
	bool IsMenuOpen() const { return bMenuOpen; }

	// ---- Full-screen overlays (notebook, tutorial)
	TSharedRef<SWidget> OpenNotebook(const FText& Header, const TArray<FDPNotebookLine>& Lines);
	TSharedRef<SWidget> OpenTutorial(const FDPTutorialFile& Script);
	void CloseOverlay();
	bool IsOverlayOpen() const { return bOverlayOpen; }

	/** Re-read accessibility settings (text scale etc.). */
	void ApplySettings();

private:
	ADPPlayerController* GetDPController() const;
	ADPCharacter* GetDPCharacter() const;

	void SetMenuContent(TSharedRef<SWidget> Widget);
	void ShowSettingsMenu(TFunction<void()> OnBack);
	void ShowPauseSubmenu();
	TSharedRef<SWidget> ShowNormalPause();
	void OnSettingsChanged();

	FText GetPromptText() const;
	FText GetHoldLabel() const;
	float GetHoldProgress() const;
	bool ShouldShowGameplay() const;

	TSharedPtr<SOverlay> Root;
	TSharedPtr<SBox> MenuLayer;
	TSharedPtr<SBox> OverlayLayer;
	TSharedPtr<SVerticalBox> ChoiceBox;
	TSharedPtr<SWidget> ViewportWidget;

	// state read by widget lambdas
	FText ThoughtText;
	float ThoughtTime = 0.f;
	float ThoughtDuration = 1.f;
	FText HintText;
	float HintTime = 0.f;
	float HintDuration = 1.f;

	bool bDialogueVisible = false;
	FText DialogueSpeaker;
	FText DialogueLine;

	float FadeAlpha = 0.f;
	float FadeTarget = 0.f;
	float FadeSpeed = 1.f;
	FLinearColor FadeColor = FLinearColor::Black;

	FText CardBig;
	FText CardSmall;
	float CardAlpha = 0.f;
	float CardTarget = 0.f;
	float CardSpeed = 1.f;

	bool bMenuOpen = false;
	bool bOverlayOpen = false;
	bool bGameplayHUDVisible = false;
};
