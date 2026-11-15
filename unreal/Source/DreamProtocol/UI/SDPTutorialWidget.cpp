#include "UI/SDPTutorialWidget.h"
#include "UI/DPUIStyle.h"
#include "Core/DPData.h"
#include "Widgets/SBoxPanel.h"
#include "Widgets/SOverlay.h"
#include "Widgets/Images/SImage.h"
#include "Widgets/Layout/SBox.h"
#include "Widgets/Layout/SScaleBox.h"
#include "Widgets/Text/STextBlock.h"
#include "InputCoreTypes.h"

#define LOCTEXT_NAMESPACE "DPTutorial"

void SDPTutorialWidget::Construct(const FArguments& InArgs)
{
	Script = InArgs._Script;
	OnWriteRule = InArgs._OnWriteRule;
	OnFinished = InArgs._OnFinished;

	TotalDuration = 0.f;
	for (const FDPTutorialLine& L : Script.Lines)
	{
		TotalDuration += FMath::Max(0.5f, L.Duration);
	}
	TotalDuration = FMath::Max(1.f, TotalDuration);

	TWeakPtr<SDPTutorialWidget> WeakSelf = StaticCastSharedRef<SDPTutorialWidget>(AsShared());
	const FLinearColor Page(0.07f, 0.07f, 0.08f, 1.f);
	const FLinearColor Video(0.015f, 0.02f, 0.035f, 1.f);

	ChildSlot
	[
		SNew(SOverlay)
		+ SOverlay::Slot()
		[
			SNew(SImage).Image(DPUI::White()).ColorAndOpacity(Page)
		]
		+ SOverlay::Slot().Padding(FMargin(60.f, 40.f))
		[
			SNew(SHorizontalBox)
			// ---- the "video"
			+ SHorizontalBox::Slot().FillWidth(1.f)
			[
				SNew(SVerticalBox)
				+ SVerticalBox::Slot().FillHeight(1.f)
				[
					SNew(SOverlay)
					+ SOverlay::Slot()
					[
						SNew(SImage).Image(DPUI::White()).ColorAndOpacity(Video)
					]
					+ SOverlay::Slot().VAlign(VAlign_Top).HAlign(HAlign_Left).Padding(18.f)
					[
						SNew(STextBlock)
						.Text(LOCTEXT("Live", "LucidLarry  -  recorded at 3:07 AM"))
						.Font_Lambda([]() { return DPUI::Font(TEXT("Regular"), 12.f); })
						.ColorAndOpacity(FSlateColor(FLinearColor(0.6f, 0.65f, 0.8f, 0.7f)))
					]
					+ SOverlay::Slot().VAlign(VAlign_Center).HAlign(HAlign_Center).Padding(70.f)
					[
						SNew(STextBlock)
						.Text_Lambda([WeakSelf]() { TSharedPtr<SDPTutorialWidget> S = WeakSelf.Pin(); return S.IsValid() ? S->CurrentCaption() : FText::GetEmpty(); })
						.AutoWrapText(true)
						.Justification(ETextJustify::Center)
						.Font_Lambda([]() { return DPUI::Font(TEXT("Bold"), 30.f); })
						.ColorAndOpacity(FSlateColor(FLinearColor(0.95f, 0.95f, 1.f)))
					]
					+ SOverlay::Slot().VAlign(VAlign_Bottom).HAlign(HAlign_Fill)
					[
						SNew(SBox).HeightOverride(5.f)
						[
							SNew(SHorizontalBox)
							+ SHorizontalBox::Slot().FillWidth(TAttribute<float>::CreateLambda([WeakSelf]()
							{
								TSharedPtr<SDPTutorialWidget> S = WeakSelf.Pin();
								return S.IsValid() ? FMath::Max(0.001f, S->Progress()) : 0.001f;
							}))
							[
								SNew(SImage).Image(DPUI::White()).ColorAndOpacity(FLinearColor(0.85f, 0.15f, 0.15f))
							]
							+ SHorizontalBox::Slot().FillWidth(TAttribute<float>::CreateLambda([WeakSelf]()
							{
								TSharedPtr<SDPTutorialWidget> S = WeakSelf.Pin();
								return S.IsValid() ? FMath::Max(0.001f, 1.f - S->Progress()) : 1.f;
							}))
							[
								SNew(SImage).Image(DPUI::White()).ColorAndOpacity(FLinearColor(0.3f, 0.3f, 0.3f))
							]
						]
					]
				]
				+ SVerticalBox::Slot().AutoHeight().Padding(0.f, 16.f, 0.f, 2.f)
				[
					SNew(STextBlock)
					.Text(FText::FromString(Script.Title))
					.Font_Lambda([]() { return DPUI::Font(TEXT("Bold"), 22.f); })
					.ColorAndOpacity(FSlateColor(DPUI::Text))
				]
				+ SVerticalBox::Slot().AutoHeight()
				[
					SNew(STextBlock)
					.Text(FText::Format(LOCTEXT("Channel", "{0}  -  {1}"), FText::FromString(Script.Channel), FText::FromString(Script.Views)))
					.Font_Lambda([]() { return DPUI::Font(TEXT("Regular"), 14.f); })
					.ColorAndOpacity(FSlateColor(DPUI::Dim))
				]
				+ SVerticalBox::Slot().AutoHeight().Padding(0.f, 14.f, 0.f, 0.f)
				[
					SNew(STextBlock)
					.Text(LOCTEXT("Controls", "Space  skip line        Esc  skip video"))
					.Font_Lambda([]() { return DPUI::Font(TEXT("Regular"), 12.f); })
					.ColorAndOpacity(FSlateColor(FLinearColor(0.45f, 0.45f, 0.45f)))
				]
			]
			// ---- the notebook in the margin
			+ SHorizontalBox::Slot().AutoWidth().Padding(36.f, 0.f, 0.f, 0.f)
			[
				SNew(SBox).WidthOverride(380.f)
				[
					SNew(SOverlay)
					+ SOverlay::Slot()
					[
						SNew(SImage).Image(DPUI::White()).ColorAndOpacity(FLinearColor(0.93f, 0.9f, 0.8f))
					]
					+ SOverlay::Slot().Padding(26.f)
					[
						SAssignNew(Margin, SVerticalBox)
						+ SVerticalBox::Slot().AutoHeight().Padding(0.f, 0.f, 0.f, 14.f)
						[
							SNew(STextBlock)
							.Text(LOCTEXT("Rules", "LUCID DREAM RULES (!!)"))
							.Font_Lambda([]() { return DPUI::InkFont(EDPInkStyle::Player, 18.f); })
							.ColorAndOpacity(FSlateColor(DPUI::InkColor(EDPInkStyle::Player)))
						]
					]
				]
			]
		]
	];

	EnterLine(0);
}

FText SDPTutorialWidget::CurrentCaption() const
{
	if (Script.Lines.IsValidIndex(LineIndex))
	{
		return FText::FromString(Script.Lines[LineIndex].Text);
	}
	return FText::GetEmpty();
}

float SDPTutorialWidget::Progress() const
{
	return FMath::Clamp(Elapsed / TotalDuration, 0.f, 1.f);
}

void SDPTutorialWidget::EnterLine(int32 Index)
{
	LineIndex = Index;
	LineTime = 0.f;
	if (!Script.Lines.IsValidIndex(Index))
	{
		Finish();
		return;
	}

	const FDPTutorialLine& L = Script.Lines[Index];
	if (!L.WriteRule.IsEmpty())
	{
		if (const FDPRuleDef* Rule = FDPData::FindRule(L.WriteRule))
		{
			const int32 Number = Margin.IsValid() ? Margin->NumSlots() : 1;
			Margin->AddSlot().AutoHeight().Padding(0.f, 6.f)
			[
				SNew(STextBlock)
				.Text(FText::Format(LOCTEXT("MarginLine", "{0}. {1}"), FText::AsNumber(Number), FText::FromString(Rule->Text)))
				.AutoWrapText(true)
				.Font_Lambda([]() { return DPUI::InkFont(EDPInkStyle::Player, 16.f); })
				.ColorAndOpacity(FSlateColor(DPUI::InkColor(EDPInkStyle::Player)))
			];
		}
		if (OnWriteRule)
		{
			OnWriteRule(L.WriteRule);
		}
	}
}

void SDPTutorialWidget::Tick(const FGeometry& AllottedGeometry, const double InCurrentTime, const float InDeltaTime)
{
	SCompoundWidget::Tick(AllottedGeometry, InCurrentTime, InDeltaTime);
	if (bDone)
	{
		return;
	}
	Age += InDeltaTime;
	LineTime += InDeltaTime;
	Elapsed += InDeltaTime;
	if (Script.Lines.IsValidIndex(LineIndex) && LineTime >= FMath::Max(0.5f, Script.Lines[LineIndex].Duration))
	{
		EnterLine(LineIndex + 1);
	}
}

void SDPTutorialWidget::Finish()
{
	if (bDone)
	{
		return;
	}
	bDone = true;
	if (OnFinished)
	{
		TFunction<void()> Fn = OnFinished;
		Fn();
	}
}

FReply SDPTutorialWidget::OnKeyDown(const FGeometry& MyGeometry, const FKeyEvent& InKeyEvent)
{
	if (bDone || Age < 0.3f)
	{
		return FReply::Handled();
	}
	const FKey Key = InKeyEvent.GetKey();
	if (Key == EKeys::SpaceBar || Key == EKeys::Enter || Key == EKeys::E || Key == EKeys::Gamepad_FaceButton_Bottom)
	{
		// Recompute elapsed so the progress bar stays honest.
		if (Script.Lines.IsValidIndex(LineIndex))
		{
			Elapsed += FMath::Max(0.f, Script.Lines[LineIndex].Duration - LineTime);
		}
		EnterLine(LineIndex + 1);
		return FReply::Handled();
	}
	if (Key == EKeys::Escape || Key == EKeys::Gamepad_FaceButton_Right)
	{
		// Skipping still writes every rule down.
		while (!bDone)
		{
			EnterLine(LineIndex + 1);
		}
		return FReply::Handled();
	}
	return FReply::Handled();
}

#undef LOCTEXT_NAMESPACE
