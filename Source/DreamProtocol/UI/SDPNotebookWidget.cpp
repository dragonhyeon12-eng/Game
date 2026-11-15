#include "UI/SDPNotebookWidget.h"
#include "UI/DPUIStyle.h"
#include "Widgets/SBoxPanel.h"
#include "Widgets/SOverlay.h"
#include "Widgets/Images/SImage.h"
#include "Widgets/Layout/SBorder.h"
#include "Widgets/Layout/SBox.h"
#include "Widgets/Text/STextBlock.h"
#include "InputCoreTypes.h"

#define LOCTEXT_NAMESPACE "DPNotebook"

namespace
{
	const FLinearColor Paper(0.93f, 0.9f, 0.8f, 1.f);
	const FLinearColor RuleLine(0.55f, 0.68f, 0.85f, 0.45f);
	const FLinearColor Margin(0.85f, 0.3f, 0.3f, 0.5f);
}

void SDPNotebookWidget::Construct(const FArguments& InArgs)
{
	OnClose = InArgs._OnClose;

	TSharedRef<SVerticalBox> Page = SNew(SVerticalBox);

	Page->AddSlot().AutoHeight().Padding(0.f, 0.f, 0.f, 18.f)
	[
		SNew(STextBlock)
		.Text(InArgs._Header)
		.Font_Lambda([]() { return DPUI::Font(TEXT("Bold"), 20.f); })
		.ColorAndOpacity(FSlateColor(FLinearColor(0.1f, 0.1f, 0.15f)))
	];

	if (InArgs._Lines.Num() == 0)
	{
		Page->AddSlot().AutoHeight()
		[
			SNew(STextBlock)
			.Text(LOCTEXT("Empty", "(empty)"))
			.Font_Lambda([]() { return DPUI::Font(TEXT("Italic"), 18.f); })
			.ColorAndOpacity(FSlateColor(FLinearColor(0.4f, 0.4f, 0.45f)))
		];
	}

	for (const FDPNotebookLine& Line : InArgs._Lines)
	{
		const EDPInkStyle Style = Line.Style;
		const FText Text = Line.Number > 0
			? FText::Format(LOCTEXT("Numbered", "{0}.  {1}"), FText::AsNumber(Line.Number), Line.Text)
			: Line.Text;

		Page->AddSlot().AutoHeight()
		[
			SNew(SVerticalBox)
			+ SVerticalBox::Slot().AutoHeight().Padding(Style == EDPInkStyle::Unknown ? FMargin(46.f, 10.f, 0.f, 4.f) : FMargin(0.f, 8.f, 0.f, 4.f))
			[
				SNew(STextBlock)
				.Text(Text)
				.AutoWrapText(true)
				.Font_Lambda([Style]() { return DPUI::InkFont(Style, 19.f); })
				.ColorAndOpacity(FSlateColor(DPUI::InkColor(Style)))
			]
			+ SVerticalBox::Slot().AutoHeight()
			[
				SNew(SBox).HeightOverride(1.f)
				[
					SNew(SImage).Image(DPUI::White()).ColorAndOpacity(RuleLine)
				]
			]
		];
	}

	ChildSlot
	[
		SNew(SOverlay)
		+ SOverlay::Slot()
		[
			SNew(SImage).Image(DPUI::White()).ColorAndOpacity(FLinearColor(0.f, 0.f, 0.f, 0.55f))
		]
		+ SOverlay::Slot().HAlign(HAlign_Center).VAlign(VAlign_Center)
		[
			SNew(SBox).WidthOverride(640.f).MinDesiredHeight(560.f)
			[
				SNew(SOverlay)
				+ SOverlay::Slot()
				[
					SNew(SImage).Image(DPUI::White()).ColorAndOpacity(Paper)
				]
				+ SOverlay::Slot().HAlign(HAlign_Left).Padding(FMargin(58.f, 0.f, 0.f, 0.f))
				[
					SNew(SBox).WidthOverride(2.f)
					[
						SNew(SImage).Image(DPUI::White()).ColorAndOpacity(Margin)
					]
				]
				+ SOverlay::Slot().Padding(FMargin(76.f, 40.f, 44.f, 40.f))
				[
					Page
				]
			]
		]
		+ SOverlay::Slot().HAlign(HAlign_Center).VAlign(VAlign_Bottom).Padding(FMargin(0.f, 0.f, 0.f, 36.f))
		[
			SNew(STextBlock)
			.Text(LOCTEXT("Close", "N / Esc  close"))
			.Font_Lambda([]() { return DPUI::Font(TEXT("Regular"), 12.f); })
			.ColorAndOpacity(FSlateColor(DPUI::Dim))
		]
	];
}

void SDPNotebookWidget::Tick(const FGeometry& AllottedGeometry, const double InCurrentTime, const float InDeltaTime)
{
	SCompoundWidget::Tick(AllottedGeometry, InCurrentTime, InDeltaTime);
	Age += InDeltaTime;
}

void SDPNotebookWidget::Close()
{
	if (!bClosed && Age > 0.2f && OnClose)
	{
		bClosed = true;
		TFunction<void()> Fn = OnClose;
		Fn();
	}
}

FReply SDPNotebookWidget::OnKeyDown(const FGeometry& MyGeometry, const FKeyEvent& InKeyEvent)
{
	const FKey Key = InKeyEvent.GetKey();
	if (Key == EKeys::N || Key == EKeys::Tab || Key == EKeys::Escape || Key == EKeys::P || Key == EKeys::E
		|| Key == EKeys::Gamepad_Special_Left || Key == EKeys::Gamepad_FaceButton_Right)
	{
		Close();
		return FReply::Handled();
	}
	return FReply::Unhandled();
}

FReply SDPNotebookWidget::OnMouseButtonDown(const FGeometry& MyGeometry, const FPointerEvent& MouseEvent)
{
	Close();
	return FReply::Handled();
}

#undef LOCTEXT_NAMESPACE
