#include "UI/DPHUD.h"
#include "UI/DPUIStyle.h"
#include "UI/SDPMenuWidget.h"
#include "UI/SDPNotebookWidget.h"
#include "UI/SDPTutorialWidget.h"
#include "Core/DPCharacter.h"
#include "Core/DPGameInstance.h"
#include "Core/DPGameMode.h"
#include "Core/DPPlayerController.h"
#include "Core/DPSettings.h"
#include "Dialogue/DPDialogueSubsystem.h"
#include "Dread/DPDreadComponent.h"
#include "Interaction/DPInteractable.h"
#include "Manifestation/DPManifestationComponent.h"
#include "Engine/Engine.h"
#include "Misc/App.h"
#include "Engine/GameViewportClient.h"
#include "Framework/Application/SlateApplication.h"
#include "Widgets/SBoxPanel.h"
#include "Widgets/SOverlay.h"
#include "Widgets/SWeakWidget.h"
#include "Widgets/SNullWidget.h"
#include "Widgets/Images/SImage.h"
#include "Widgets/Input/SButton.h"
#include "Widgets/Layout/SBorder.h"
#include "Widgets/Layout/SBox.h"
#include "Widgets/Text/STextBlock.h"

#define LOCTEXT_NAMESPACE "DPHUD"

ADPHUD::ADPHUD()
{
	PrimaryActorTick.bCanEverTick = true;
	PrimaryActorTick.bTickEvenWhenPaused = true;
}

ADPPlayerController* ADPHUD::GetDPController() const
{
	return Cast<ADPPlayerController>(GetOwningPlayerController());
}

ADPCharacter* ADPHUD::GetDPCharacter() const
{
	const APlayerController* PC = GetOwningPlayerController();
	return PC ? Cast<ADPCharacter>(PC->GetPawn()) : nullptr;
}

bool ADPHUD::ShouldShowGameplay() const
{
	return bGameplayHUDVisible && !bMenuOpen && !bOverlayOpen;
}

// ---------------------------------------------------------------- Construction

void ADPHUD::BeginPlay()
{
	Super::BeginPlay();
	ApplySettings();

	if (!GEngine || !GEngine->GameViewport)
	{
		return;
	}

	TWeakObjectPtr<ADPHUD> W(this);
	auto Vis = [W](TFunction<bool(const ADPHUD&)> Pred)
	{
		return TAttribute<EVisibility>::CreateLambda([W, Pred]()
		{
			return (W.IsValid() && Pred(*W.Get())) ? EVisibility::HitTestInvisible : EVisibility::Collapsed;
		});
	};

	SAssignNew(Root, SOverlay)

	// Crosshair dot
	+ SOverlay::Slot().HAlign(HAlign_Center).VAlign(VAlign_Center)
	[
		SNew(SBox).WidthOverride(4.f).HeightOverride(4.f)
		.Visibility(Vis([](const ADPHUD& H) { return H.ShouldShowGameplay() && !H.bDialogueVisible; }))
		[
			SNew(SImage).Image(DPUI::White())
			.ColorAndOpacity_Lambda([W]()
			{
				const bool bFocus = W.IsValid() && !W->GetPromptText().IsEmpty();
				return FSlateColor(FLinearColor(1.f, 1.f, 1.f, bFocus ? 0.9f : 0.35f));
			})
		]
	]

	// Interaction prompt
	+ SOverlay::Slot().HAlign(HAlign_Center).VAlign(VAlign_Center).Padding(FMargin(0.f, 90.f, 0.f, 0.f))
	[
		SNew(STextBlock)
		.Visibility(Vis([](const ADPHUD& H) { return H.ShouldShowGameplay() && !H.bDialogueVisible && !H.GetPromptText().IsEmpty(); }))
		.Text_Lambda([W]() { return W.IsValid() ? W->GetPromptText() : FText::GetEmpty(); })
		.Font_Lambda([]() { return DPUI::Font(TEXT("Regular"), 16.f); })
		.ColorAndOpacity(FSlateColor(DPUI::Text))
		.ShadowOffset(FVector2D(1.f, 1.f))
		.ShadowColorAndOpacity(FLinearColor(0.f, 0.f, 0.f, 0.8f))
	]

	// Hold progress (manifest / wake)
	+ SOverlay::Slot().HAlign(HAlign_Center).VAlign(VAlign_Center).Padding(FMargin(0.f, 150.f, 0.f, 0.f))
	[
		SNew(SVerticalBox)
		.Visibility(Vis([](const ADPHUD& H) { return H.ShouldShowGameplay() && H.GetHoldProgress() >= 0.f; }))
		+ SVerticalBox::Slot().AutoHeight().HAlign(HAlign_Center)
		[
			SNew(STextBlock)
			.Text_Lambda([W]() { return W.IsValid() ? W->GetHoldLabel() : FText::GetEmpty(); })
			.Font_Lambda([]() { return DPUI::Font(TEXT("Italic"), 15.f); })
			.ColorAndOpacity(FSlateColor(DPUI::Text))
		]
		+ SVerticalBox::Slot().AutoHeight().HAlign(HAlign_Center).Padding(0.f, 6.f)
		[
			SNew(SBox).WidthOverride(180.f).HeightOverride(3.f)
			[
				SNew(SHorizontalBox)
				+ SHorizontalBox::Slot().FillWidth(TAttribute<float>::CreateLambda([W]() { return W.IsValid() ? FMath::Max(0.001f, W->GetHoldProgress()) : 0.001f; }))
				[
					SNew(SImage).Image(DPUI::White()).ColorAndOpacity(DPUI::Accent)
				]
				+ SHorizontalBox::Slot().FillWidth(TAttribute<float>::CreateLambda([W]() { return W.IsValid() ? FMath::Max(0.001f, 1.f - W->GetHoldProgress()) : 1.f; }))
				[
					SNew(SImage).Image(DPUI::White()).ColorAndOpacity(FLinearColor(1.f, 1.f, 1.f, 0.15f))
				]
			]
		]
	]

	// Hint (top left)
	+ SOverlay::Slot().HAlign(HAlign_Left).VAlign(VAlign_Top).Padding(FMargin(48.f, 44.f, 0.f, 0.f))
	[
		SNew(SBorder)
		.BorderImage(DPUI::White())
		.BorderBackgroundColor(DPUI::Panel)
		.Padding(FMargin(16.f, 10.f))
		.Visibility(Vis([](const ADPHUD& H) { return H.ShouldShowGameplay() && H.HintTime > 0.f; }))
		.ColorAndOpacity_Lambda([W]() { return FLinearColor(1.f, 1.f, 1.f, W.IsValid() ? FMath::Clamp(W->HintTime / 0.6f, 0.f, 1.f) : 0.f); })
		[
			SNew(STextBlock)
			.Text_Lambda([W]() { return W.IsValid() ? W->HintText : FText::GetEmpty(); })
			.Font_Lambda([]() { return DPUI::Font(TEXT("Regular"), 15.f); })
			.ColorAndOpacity(FSlateColor(DPUI::Text))
		]
	]

	// Thought / subtitle (lower third)
	+ SOverlay::Slot().HAlign(HAlign_Center).VAlign(VAlign_Bottom).Padding(FMargin(0.f, 0.f, 0.f, 150.f))
	[
		SNew(SBox).MaxDesiredWidth(1000.f)
		.Visibility(Vis([](const ADPHUD& H) { return H.ThoughtTime > 0.f && !H.bMenuOpen && !H.bOverlayOpen && !H.bDialogueVisible; }))
		[
			SNew(STextBlock)
			.Text_Lambda([W]() { return W.IsValid() ? W->ThoughtText : FText::GetEmpty(); })
			.AutoWrapText(true)
			.Justification(ETextJustify::Center)
			.Font_Lambda([]() { return DPUI::Font(TEXT("Italic"), 20.f); })
			.ColorAndOpacity_Lambda([W]() { return FSlateColor(FLinearColor(0.95f, 0.94f, 0.9f, W.IsValid() ? FMath::Clamp(W->ThoughtTime / 0.5f, 0.f, 1.f) : 0.f)); })
			.ShadowOffset(FVector2D(1.f, 1.f))
			.ShadowColorAndOpacity(FLinearColor(0.f, 0.f, 0.f, 0.85f))
		]
	]

	// DREAD meter (bottom left)
	+ SOverlay::Slot().HAlign(HAlign_Left).VAlign(VAlign_Bottom).Padding(FMargin(48.f, 0.f, 0.f, 44.f))
	[
		SNew(SVerticalBox)
		.Visibility(Vis([](const ADPHUD& H)
		{
			const ADPCharacter* C = H.GetDPCharacter();
			const ADPGameMode* GM = ADPGameMode::Get(&H);
			return H.ShouldShowGameplay() && C && GM && GM->GetZoneType() != EDPZone::Bedroom && DPSettings::Get(&H).bShowDreadMeter;
		}))
		+ SVerticalBox::Slot().AutoHeight()
		[
			SNew(STextBlock)
			.Text_Lambda([W]()
			{
				const ADPCharacter* C = W.IsValid() ? W->GetDPCharacter() : nullptr;
				return C ? FText::Format(LOCTEXT("Dread", "DREAD   {0}"), DPDread::StageName(C->GetDread()->GetStage())) : FText::GetEmpty();
			})
			.Font_Lambda([]() { return DPUI::Font(TEXT("Bold"), 12.f); })
			.ColorAndOpacity_Lambda([W]()
			{
				const ADPCharacter* C = W.IsValid() ? W->GetDPCharacter() : nullptr;
				const float A = C ? C->GetDread()->GetDreadAlpha() : 0.f;
				return FSlateColor(FMath::Lerp(FLinearColor(0.85f, 0.85f, 0.82f, 0.7f), FLinearColor(0.8f, 0.08f, 0.06f, 0.95f), A));
			})
		]
		+ SVerticalBox::Slot().AutoHeight().Padding(0.f, 5.f, 0.f, 0.f)
		[
			SNew(SBox).WidthOverride(160.f).HeightOverride(3.f)
			[
				SNew(SHorizontalBox)
				+ SHorizontalBox::Slot().FillWidth(TAttribute<float>::CreateLambda([W]()
				{
					const ADPCharacter* C = W.IsValid() ? W->GetDPCharacter() : nullptr;
					return FMath::Max(0.001f, C ? C->GetDread()->GetDreadAlpha() : 0.f);
				}))
				[
					SNew(SImage).Image(DPUI::White()).ColorAndOpacity(FLinearColor(0.75f, 0.12f, 0.1f, 0.9f))
				]
				+ SHorizontalBox::Slot().FillWidth(TAttribute<float>::CreateLambda([W]()
				{
					const ADPCharacter* C = W.IsValid() ? W->GetDPCharacter() : nullptr;
					return FMath::Max(0.001f, 1.f - (C ? C->GetDread()->GetDreadAlpha() : 0.f));
				}))
				[
					SNew(SImage).Image(DPUI::White()).ColorAndOpacity(FLinearColor(1.f, 1.f, 1.f, 0.12f))
				]
			]
		]
	]

	// Dialogue panel
	+ SOverlay::Slot().HAlign(HAlign_Center).VAlign(VAlign_Bottom).Padding(FMargin(0.f, 0.f, 0.f, 60.f))
	[
		SNew(SBox).WidthOverride(900.f)
		.Visibility_Lambda([W]() { return (W.IsValid() && W->bDialogueVisible && !W->bMenuOpen && !W->bOverlayOpen) ? EVisibility::Visible : EVisibility::Collapsed; })
		[
			SNew(SBorder)
			.BorderImage(DPUI::White())
			.BorderBackgroundColor(DPUI::Panel)
			.Padding(FMargin(26.f, 18.f))
			[
				SNew(SVerticalBox)
				+ SVerticalBox::Slot().AutoHeight().Padding(0.f, 0.f, 0.f, 6.f)
				[
					SNew(STextBlock)
					.Text_Lambda([W]() { return W.IsValid() ? W->DialogueSpeaker : FText::GetEmpty(); })
					.Font_Lambda([]() { return DPUI::Font(TEXT("Bold"), 16.f); })
					.ColorAndOpacity(FSlateColor(DPUI::Accent))
				]
				+ SVerticalBox::Slot().AutoHeight().Padding(0.f, 0.f, 0.f, 14.f)
				[
					SNew(STextBlock)
					.Text_Lambda([W]() { return W.IsValid() ? W->DialogueLine : FText::GetEmpty(); })
					.AutoWrapText(true)
					.Font_Lambda([W]()
					{
						const bool bNarration = W.IsValid() && W->DialogueSpeaker.IsEmpty();
						return DPUI::Font(bNarration ? TEXT("Italic") : TEXT("Regular"), 19.f);
					})
					.ColorAndOpacity_Lambda([W]()
					{
						const bool bNarration = W.IsValid() && W->DialogueSpeaker.IsEmpty();
						return FSlateColor(bNarration ? DPUI::Dim : DPUI::Text);
					})
				]
				+ SVerticalBox::Slot().AutoHeight()
				[
					SAssignNew(ChoiceBox, SVerticalBox)
				]
			]
		]
	]

	// Notebook / tutorial
	+ SOverlay::Slot()
	[
		SAssignNew(OverlayLayer, SBox)
	]

	// Fade
	+ SOverlay::Slot()
	[
		SNew(SImage).Image(DPUI::White())
		.Visibility_Lambda([W]() { return (W.IsValid() && W->FadeAlpha > 0.001f) ? EVisibility::HitTestInvisible : EVisibility::Collapsed; })
		.ColorAndOpacity_Lambda([W]()
		{
			if (!W.IsValid()) return FSlateColor(FLinearColor::Transparent);
			FLinearColor C = W->FadeColor;
			C.A = W->FadeAlpha;
			return FSlateColor(C);
		})
	]

	// Title card
	+ SOverlay::Slot().HAlign(HAlign_Center).VAlign(VAlign_Center)
	[
		SNew(SVerticalBox)
		.Visibility_Lambda([W]() { return (W.IsValid() && W->CardAlpha > 0.001f) ? EVisibility::HitTestInvisible : EVisibility::Collapsed; })
		+ SVerticalBox::Slot().AutoHeight().HAlign(HAlign_Center)
		[
			SNew(STextBlock)
			.Text_Lambda([W]() { return W.IsValid() ? W->CardBig : FText::GetEmpty(); })
			.Font_Lambda([]() { return DPUI::Font(TEXT("Regular"), 34.f); })
			.ColorAndOpacity_Lambda([W]() { return FSlateColor(FLinearColor(0.92f, 0.9f, 0.86f, W.IsValid() ? W->CardAlpha : 0.f)); })
		]
		+ SVerticalBox::Slot().AutoHeight().HAlign(HAlign_Center).Padding(0.f, 14.f, 0.f, 0.f)
		[
			SNew(STextBlock)
			.Text_Lambda([W]() { return W.IsValid() ? W->CardSmall : FText::GetEmpty(); })
			.Font_Lambda([]() { return DPUI::Font(TEXT("Regular"), 14.f); })
			.ColorAndOpacity_Lambda([W]() { return FSlateColor(FLinearColor(0.6f, 0.6f, 0.58f, W.IsValid() ? W->CardAlpha : 0.f)); })
		]
	]

	// Menus
	+ SOverlay::Slot()
	[
		SAssignNew(MenuLayer, SBox)
	];

	ViewportWidget = SNew(SWeakWidget).PossiblyNullContent(Root);
	GEngine->GameViewport->AddViewportWidgetContent(ViewportWidget.ToSharedRef(), 10);
}

void ADPHUD::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
	if (GEngine && GEngine->GameViewport && ViewportWidget.IsValid())
	{
		GEngine->GameViewport->RemoveViewportWidgetContent(ViewportWidget.ToSharedRef());
	}
	ViewportWidget.Reset();
	Root.Reset();
	Super::EndPlay(EndPlayReason);
}

void ADPHUD::ApplySettings()
{
	DPUI::TextScale = FMath::Clamp(DPSettings::Get(this).TextScale, 0.75f, 2.f);
}

// ---------------------------------------------------------------- Tick

void ADPHUD::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);
	// Real time, so fades still work while paused.
	const float Dt = static_cast<float>(FMath::Min(FApp::GetDeltaTime(), 0.1));

	ThoughtTime = FMath::Max(0.f, ThoughtTime - Dt);
	if (!bMenuOpen && !bOverlayOpen)
	{
		HintTime = FMath::Max(0.f, HintTime - Dt);
	}
	FadeAlpha = FMath::FInterpConstantTo(FadeAlpha, FadeTarget, Dt, FadeSpeed);
	CardAlpha = FMath::FInterpConstantTo(CardAlpha, CardTarget, Dt, CardSpeed);
}

// ---------------------------------------------------------------- Text / screen

void ADPHUD::ShowThought(const FText& Text, float Seconds)
{
	ThoughtText = Text;
	ThoughtDuration = Seconds;
	ThoughtTime = Seconds;
}

void ADPHUD::ShowHint(const FText& Text, float Seconds)
{
	HintText = Text;
	HintDuration = Seconds;
	HintTime = Seconds;
}

void ADPHUD::ClearTransientText()
{
	ThoughtTime = 0.f;
	HintTime = 0.f;
	HideDialogue();
}

void ADPHUD::FadeTo(float TargetAlpha, float Seconds, const FLinearColor& Color)
{
	FadeColor = Color;
	FadeTarget = FMath::Clamp(TargetAlpha, 0.f, 1.f);
	FadeSpeed = Seconds <= 0.f ? 1000.f : FMath::Max(0.01f, FMath::Abs(FadeTarget - FadeAlpha) / Seconds);
	if (Seconds <= 0.f)
	{
		FadeAlpha = FadeTarget;
	}
}

void ADPHUD::SetFade(float Alpha, const FLinearColor& Color)
{
	FadeColor = Color;
	FadeAlpha = FadeTarget = FMath::Clamp(Alpha, 0.f, 1.f);
}

void ADPHUD::ShowCard(const FText& Big, const FText& Small, float FadeSeconds)
{
	CardBig = Big;
	CardSmall = Small;
	CardTarget = 1.f;
	CardSpeed = FadeSeconds <= 0.f ? 1000.f : 1.f / FadeSeconds;
	if (FadeSeconds <= 0.f)
	{
		CardAlpha = 1.f;
	}
}

void ADPHUD::HideCard(float FadeSeconds)
{
	CardTarget = 0.f;
	CardSpeed = FadeSeconds <= 0.f ? 1000.f : 1.f / FadeSeconds;
}

FText ADPHUD::GetPromptText() const
{
	const ADPCharacter* C = GetDPCharacter();
	if (!C || C->AreControlsLocked())
	{
		return FText::GetEmpty();
	}
	const IDPInteractable* I = Cast<IDPInteractable>(C->GetFocusedActor());
	if (!I)
	{
		return FText::GetEmpty();
	}
	return FText::Format(LOCTEXT("Prompt", "[E]  {0}"), I->GetInteractPrompt(C));
}

float ADPHUD::GetHoldProgress() const
{
	const ADPCharacter* C = GetDPCharacter();
	if (!C)
	{
		return -1.f;
	}
	return FMath::Max(C->GetManifestHoldProgress(), C->GetWakeHoldProgress());
}

FText ADPHUD::GetHoldLabel() const
{
	const ADPCharacter* C = GetDPCharacter();
	if (!C)
	{
		return FText::GetEmpty();
	}
	if (C->GetWakeHoldProgress() >= 0.f)
	{
		return LOCTEXT("Waking", "Wake up...");
	}
	return FText::Format(LOCTEXT("Picturing", "Picturing {0}..."), C->GetManifestation()->GetSelectedName());
}

// ---------------------------------------------------------------- Dialogue

void ADPHUD::ShowDialogue(const FText& Speaker, const FText& Line, const TArray<FText>& Choices)
{
	bDialogueVisible = true;
	DialogueSpeaker = Speaker;
	DialogueLine = Line;

	if (!ChoiceBox.IsValid())
	{
		return;
	}
	ChoiceBox->ClearChildren();

	TWeakObjectPtr<ADPHUD> W(this);
	auto MakeChoice = [W](const FText& Label, int32 Index)
	{
		return SNew(SButton)
			.ButtonStyle(&DPUI::FlatButton())
			.ContentPadding(FMargin(8.f, 5.f))
			.OnClicked_Lambda([W, Index]()
			{
				if (W.IsValid())
				{
					if (UDPDialogueSubsystem* D = W->GetWorld()->GetSubsystem<UDPDialogueSubsystem>())
					{
						D->Choose(Index);
					}
				}
				return FReply::Handled();
			})
			[
				SNew(STextBlock)
				.Text(Label)
				.Font_Lambda([]() { return DPUI::Font(TEXT("Regular"), 17.f); })
				.ColorAndOpacity(FSlateColor(DPUI::Text))
			];
	};

	if (Choices.Num() == 0)
	{
		ChoiceBox->AddSlot().AutoHeight()[ MakeChoice(LOCTEXT("Continue", "[E]  Continue"), 0) ];
	}
	for (int32 i = 0; i < Choices.Num(); ++i)
	{
		ChoiceBox->AddSlot().AutoHeight()
		[
			MakeChoice(FText::Format(LOCTEXT("Choice", "{0}.  {1}"), FText::AsNumber(i + 1), Choices[i]), i)
		];
	}
}

void ADPHUD::HideDialogue()
{
	bDialogueVisible = false;
	if (ChoiceBox.IsValid())
	{
		ChoiceBox->ClearChildren();
	}
}

// ---------------------------------------------------------------- Menus

void ADPHUD::SetMenuContent(TSharedRef<SWidget> Widget)
{
	bMenuOpen = true;
	if (MenuLayer.IsValid())
	{
		MenuLayer->SetContent(Widget);
	}
	FSlateApplication::Get().SetAllUserFocus(Widget, EFocusCause::SetDirectly);
}

void ADPHUD::CloseMenu()
{
	bMenuOpen = false;
	if (MenuLayer.IsValid())
	{
		MenuLayer->SetContent(SNullWidget::NullWidget);
	}
}

TSharedRef<SWidget> ADPHUD::OpenTitleMenu(bool bHasCheckpoint)
{
	TWeakObjectPtr<ADPHUD> W(this);
	TArray<FDPMenuItem> Items;
	if (bHasCheckpoint)
	{
		Items.Add({ LOCTEXT("Continue", "CONTINUE"), [W]() { if (W.IsValid()) { if (ADPGameMode* GM = ADPGameMode::Get(W.Get())) GM->ContinueGame(); } } });
	}
	Items.Add({ LOCTEXT("NewGame", "NEW GAME"), [W]() { if (W.IsValid()) { if (ADPGameMode* GM = ADPGameMode::Get(W.Get())) GM->StartNewGame(); } } });
	Items.Add({ LOCTEXT("Settings", "SETTINGS"), [W]()
	{
		if (W.IsValid())
		{
			const bool bSave = ADPGameMode::Get(W.Get()) && ADPGameMode::Get(W.Get())->HasCheckpoint();
			W->ShowSettingsMenu([W, bSave]() { if (W.IsValid()) { W->OpenTitleMenu(bSave); } });
		}
	} });
	Items.Add({ LOCTEXT("Quit", "QUIT"), [W]() { if (W.IsValid() && W->GetDPController()) W->GetDPController()->QuitToDesktop(); } });

	TSharedRef<SDPMenuWidget> Menu = SNew(SDPMenuWidget)
		.Title(LOCTEXT("TitleName", "DREAM PROTOCOL"))
		.Subtitle(LOCTEXT("TitleSub", "a lucid dream"))
		.Footnote(LOCTEXT("TitleFoot", "Vertical slice - work in progress"))
		.Items(Items);
	SetMenuContent(Menu);
	return Menu;
}

TSharedRef<SWidget> ADPHUD::OpenPauseMenu(bool bCorrupted, bool bMayUnpauseItself)
{
	TWeakObjectPtr<ADPHUD> W(this);
	if (!bCorrupted)
	{
		return ShowNormalPause();
	}

	// All three really do resume.
	auto Resume = [W]() { if (W.IsValid() && W->GetDPController()) W->GetDPController()->ResumeFromPause(); };
	TArray<FDPMenuItem> Items;
	Items.Add({ LOCTEXT("Resume1", "RESUME"), Resume });
	Items.Add({ LOCTEXT("Resume2", "RESUME"), Resume });
	Items.Add({ LOCTEXT("Resume3", "RESUME"), Resume });

	TSharedRef<SDPMenuWidget> Menu = SNew(SDPMenuWidget)
		.Title(LOCTEXT("Hiding", "WHY ARE YOU HIDING?"))
		.Footnote(LOCTEXT("DevNote", "(Note from dev: press ESC to actually leave. Sorry man)"))
		.Items(Items)
		.Corrupted(true)
		.AutoActivateAfter(bMayUnpauseItself ? 6.f : -1.f)
		.OnTimeout([W]() { if (W.IsValid() && W->GetDPController()) W->GetDPController()->ResumeFromPause(/*bSelf*/ true); })
		.OnBack([W]() { if (W.IsValid()) W->ShowNormalPause(); });
	SetMenuContent(Menu);
	return Menu;
}

TSharedRef<SWidget> ADPHUD::ShowNormalPause()
{
	TWeakObjectPtr<ADPHUD> W(this);
	auto Resume = [W]() { if (W.IsValid() && W->GetDPController()) W->GetDPController()->ResumeFromPause(); };
	TArray<FDPMenuItem> Items;
	Items.Add({ LOCTEXT("Exit", "EXIT"), [W]() { if (W.IsValid() && W->GetDPController()) W->GetDPController()->QuitToDesktop(); } });
	Items.Add({ LOCTEXT("Menu", "MENU"), [W]() { if (W.IsValid()) W->ShowPauseSubmenu(); } });
	Items.Add({ LOCTEXT("Resume", "RESUME"), Resume });

	TSharedRef<SDPMenuWidget> Menu = SNew(SDPMenuWidget)
		.Title(LOCTEXT("Paused", "PAUSED"))
		.Items(Items)
		.OnBack(Resume);
	SetMenuContent(Menu);
	return Menu;
}

void ADPHUD::ShowPauseSubmenu()
{
	TWeakObjectPtr<ADPHUD> W(this);
	TArray<FDPMenuItem> Items;
	Items.Add({ LOCTEXT("SettingsItem", "SETTINGS"), [W]() { if (W.IsValid()) W->ShowSettingsMenu([W]() { if (W.IsValid()) W->ShowPauseSubmenu(); }); } });
	Items.Add({ LOCTEXT("ToTitle", "RETURN TO TITLE"), [W]()
	{
		if (W.IsValid())
		{
			if (ADPGameMode* GM = ADPGameMode::Get(W.Get()))
			{
				GM->ReturnToTitle();
			}
		}
	} });
	Items.Add({ LOCTEXT("Back", "BACK"), [W]() { if (W.IsValid()) W->ShowNormalPause(); } });

	TSharedRef<SDPMenuWidget> Menu = SNew(SDPMenuWidget)
		.Title(LOCTEXT("MenuTitle", "MENU"))
		.Subtitle(LOCTEXT("MenuSub", "Progress is saved at the start of each area."))
		.Items(Items)
		.OnBack([W]() { if (W.IsValid()) W->ShowNormalPause(); });
	SetMenuContent(Menu);
}

void ADPHUD::OnSettingsChanged()
{
	if (UDPGameInstance* GI = Cast<UDPGameInstance>(GetGameInstance()))
	{
		GI->SaveSettings();
	}
	ApplySettings();
	if (ADPGameMode* GM = ADPGameMode::Get(this))
	{
		GM->ApplySettingsEverywhere();
	}
}

void ADPHUD::ShowSettingsMenu(TFunction<void()> OnBack)
{
	UDPGameInstance* GI = Cast<UDPGameInstance>(GetGameInstance());
	UDPSettingsSave* S = GI ? GI->GetSettings() : nullptr;
	if (!S)
	{
		return;
	}
	TWeakObjectPtr<ADPHUD> W(this);
	TWeakObjectPtr<UDPSettingsSave> WS(S);

	auto Percent = [](float V) { return FText::Format(LOCTEXT("Pct", "{0}%"), FText::AsNumber(FMath::RoundToInt(V * 100.f))); };
	auto OnOff = [](bool b) { return b ? LOCTEXT("On", "ON") : LOCTEXT("Off", "OFF"); };
	auto Changed = [W]() { if (W.IsValid()) W->OnSettingsChanged(); };

	auto FloatRow = [WS, Changed](const FText& Label, float UDPSettingsSave::* Field, float Min, float Max, float Step, TFunction<FText(float)> Fmt)
	{
		FDPMenuItem Item;
		Item.Label = Label;
		Item.GetValue = [WS, Field, Fmt]() { return WS.IsValid() ? Fmt(WS.Get()->*Field) : FText::GetEmpty(); };
		Item.OnAdjust = [WS, Field, Min, Max, Step, Changed](int32 Dir)
		{
			if (WS.IsValid())
			{
				float& V = WS.Get()->*Field;
				V = FMath::Clamp(FMath::RoundToFloat((V + Dir * Step) / Step) * Step, Min, Max);
				Changed();
			}
		};
		return Item;
	};
	auto BoolRow = [WS, Changed, OnOff](const FText& Label, bool UDPSettingsSave::* Field)
	{
		FDPMenuItem Item;
		Item.Label = Label;
		Item.GetValue = [WS, Field, OnOff]() { return WS.IsValid() ? OnOff(WS.Get()->*Field) : FText::GetEmpty(); };
		Item.OnAdjust = [WS, Field, Changed](int32)
		{
			if (WS.IsValid())
			{
				WS.Get()->*Field = !(WS.Get()->*Field);
				Changed();
			}
		};
		return Item;
	};

	TArray<FDPMenuItem> Items;
	Items.Add(FloatRow(LOCTEXT("Sens", "Mouse sensitivity"), &UDPSettingsSave::MouseSensitivity, 0.2f, 3.f, 0.1f,
		[](float V) { return FText::AsNumber(V, &FNumberFormattingOptions().SetMinimumFractionalDigits(1).SetMaximumFractionalDigits(1)); }));
	Items.Add(BoolRow(LOCTEXT("Invert", "Invert look"), &UDPSettingsSave::bInvertY));
	Items.Add(FloatRow(LOCTEXT("Fov", "Field of view"), &UDPSettingsSave::FieldOfView, 70.f, 110.f, 5.f,
		[](float V) { return FText::AsNumber(FMath::RoundToInt(V)); }));
	Items.Add(BoolRow(LOCTEXT("Bob", "Head bob"), &UDPSettingsSave::bHeadBob));
	Items.Add(BoolRow(LOCTEXT("CamFx", "Camera jolts"), &UDPSettingsSave::bCameraEffects));
	Items.Add(FloatRow(LOCTEXT("Visual", "Visual intensity"), &UDPSettingsSave::VisualIntensity, 0.f, 1.f, 0.1f, Percent));
	Items.Add(FloatRow(LOCTEXT("Audio", "Horror audio intensity"), &UDPSettingsSave::AudioIntensity, 0.f, 1.f, 0.1f, Percent));
	Items.Add(FloatRow(LOCTEXT("Volume", "Master volume"), &UDPSettingsSave::MasterVolume, 0.f, 1.f, 0.1f, Percent));
	Items.Add(FloatRow(LOCTEXT("TextSize", "Text size"), &UDPSettingsSave::TextScale, 1.f, 1.5f, 0.25f, Percent));
	Items.Add(BoolRow(LOCTEXT("Meter", "DREAD meter"), &UDPSettingsSave::bShowDreadMeter));
	Items.Add(BoolRow(LOCTEXT("Corrupt", "Menu corruption"), &UDPSettingsSave::bMenuCorruption));
	Items.Add(BoolRow(LOCTEXT("SelfUnpause", "Game may unpause itself"), &UDPSettingsSave::bSelfUnpause));
	FDPMenuItem Back;
	Back.Label = LOCTEXT("SettingsBack", "BACK");
	Back.OnActivate = OnBack;
	Items.Add(Back);

	TSharedRef<SDPMenuWidget> Menu = SNew(SDPMenuWidget)
		.Title(LOCTEXT("SettingsTitle", "SETTINGS"))
		.Subtitle(LOCTEXT("SettingsSub", "Left / Right to change. Intensity settings soften flicker, distortion and horror audio."))
		.Items(Items)
		.OnBack(OnBack);
	SetMenuContent(Menu);
}

// ---------------------------------------------------------------- Overlays

TSharedRef<SWidget> ADPHUD::OpenNotebook(const FText& Header, const TArray<FDPNotebookLine>& Lines)
{
	TWeakObjectPtr<ADPHUD> W(this);
	TSharedRef<SDPNotebookWidget> Widget = SNew(SDPNotebookWidget)
		.Header(Header)
		.Lines(Lines)
		.OnClose([W]() { if (W.IsValid() && W->GetDPController()) W->GetDPController()->CloseNotebook(); });
	bOverlayOpen = true;
	OverlayLayer->SetContent(Widget);
	FSlateApplication::Get().SetAllUserFocus(Widget, EFocusCause::SetDirectly);
	return Widget;
}

TSharedRef<SWidget> ADPHUD::OpenTutorial(const FDPTutorialFile& Script)
{
	TWeakObjectPtr<ADPHUD> W(this);
	TSharedRef<SDPTutorialWidget> Widget = SNew(SDPTutorialWidget)
		.Script(Script)
		.OnWriteRule([W](const FString& RuleId)
		{
			if (W.IsValid())
			{
				if (UDPNotebookSubsystem* N = W->GetWorld()->GetSubsystem<UDPNotebookSubsystem>())
				{
					N->Write(RuleId);
				}
			}
		})
		.OnFinished([W]()
		{
			if (W.IsValid())
			{
				if (ADPGameMode* GM = ADPGameMode::Get(W.Get()))
				{
					GM->OnTutorialFinished();
				}
			}
		});
	bOverlayOpen = true;
	OverlayLayer->SetContent(Widget);
	FSlateApplication::Get().SetAllUserFocus(Widget, EFocusCause::SetDirectly);
	return Widget;
}

void ADPHUD::CloseOverlay()
{
	bOverlayOpen = false;
	if (OverlayLayer.IsValid())
	{
		OverlayLayer->SetContent(SNullWidget::NullWidget);
	}
}

#undef LOCTEXT_NAMESPACE
