#include "UI/SDPMenuWidget.h"
#include "UI/DPUIStyle.h"
#include "Widgets/SBoxPanel.h"
#include "Widgets/SOverlay.h"
#include "Widgets/Images/SImage.h"
#include "Widgets/Input/SButton.h"
#include "Widgets/Layout/SBorder.h"
#include "Widgets/Layout/SBox.h"
#include "Widgets/Text/STextBlock.h"
#include "InputCoreTypes.h"

void SDPMenuWidget::Construct(const FArguments& InArgs)
{
	Items = InArgs._Items;
	OnBack = InArgs._OnBack;
	OnTimeout = InArgs._OnTimeout;
	bCorrupted = InArgs._Corrupted;
	TimeoutLeft = InArgs._AutoActivateAfter;

	TSharedRef<SVerticalBox> List = SNew(SVerticalBox);
	for (int32 i = 0; i < Items.Num(); ++i)
	{
		List->AddSlot().AutoHeight().Padding(0.f, 4.f)[ MakeRow(i) ];
	}

	const FText Title = InArgs._Title;
	const FText Subtitle = InArgs._Subtitle;
	const FText Footnote = InArgs._Footnote;
	const bool bCorrupt = bCorrupted;

	ChildSlot
	[
		SNew(SOverlay)
		+ SOverlay::Slot()
		[
			SNew(SImage).Image(DPUI::White()).ColorAndOpacity(FLinearColor(0.f, 0.f, 0.f, bCorrupt ? 0.86f : 0.62f))
		]
		+ SOverlay::Slot().HAlign(HAlign_Left).VAlign(VAlign_Center).Padding(FMargin(120.f, 0.f, 0.f, 0.f))
		[
			SNew(SBox).MinDesiredWidth(420.f)
			[
				SNew(SVerticalBox)
				+ SVerticalBox::Slot().AutoHeight().Padding(0.f, 0.f, 0.f, 4.f)
				[
					SNew(STextBlock)
					.Text(Title)
					.Visibility(Title.IsEmpty() ? EVisibility::Collapsed : EVisibility::HitTestInvisible)
					.Font_Lambda([bCorrupt]() { return DPUI::Font(TEXT("Bold"), bCorrupt ? 30.f : 42.f); })
					.ColorAndOpacity(bCorrupt ? FSlateColor(DPUI::Danger) : FSlateColor(DPUI::Text))
				]
				+ SVerticalBox::Slot().AutoHeight().Padding(0.f, 0.f, 0.f, 28.f)
				[
					SNew(STextBlock)
					.Text(Subtitle)
					.Visibility(Subtitle.IsEmpty() ? EVisibility::Collapsed : EVisibility::HitTestInvisible)
					.Font_Lambda([]() { return DPUI::Font(TEXT("Regular"), 14.f); })
					.ColorAndOpacity(FSlateColor(DPUI::Dim))
				]
				+ SVerticalBox::Slot().AutoHeight()
				[
					List
				]
			]
		]
		+ SOverlay::Slot().HAlign(HAlign_Right).VAlign(VAlign_Bottom).Padding(FMargin(0.f, 0.f, 40.f, 30.f))
		[
			SNew(STextBlock)
			.Text(Footnote)
			.Visibility(Footnote.IsEmpty() ? EVisibility::Collapsed : EVisibility::HitTestInvisible)
			.Font_Lambda([]() { return DPUI::Font(TEXT("Regular"), 11.f); })
			.ColorAndOpacity(FSlateColor(FLinearColor(0.55f, 0.55f, 0.55f, 0.8f)))
		]
	];
}

TSharedRef<SWidget> SDPMenuWidget::MakeRow(int32 Index)
{
	TWeakPtr<SDPMenuWidget> WeakSelf = StaticCastSharedRef<SDPMenuWidget>(AsShared());
	const FDPMenuItem& Item = Items[Index];
	const bool bMinor = Item.bMinor;
	const bool bHasValue = Item.GetValue != nullptr;
	const bool bCorrupt = bCorrupted;

	auto IsSelected = [WeakSelf, Index]()
	{
		TSharedPtr<SDPMenuWidget> Self = WeakSelf.Pin();
		return Self.IsValid() && Self->Selected == Index;
	};

	return SNew(SButton)
		.ButtonStyle(&DPUI::FlatButton())
		.ContentPadding(FMargin(10.f, 4.f))
		.OnClicked_Lambda([WeakSelf, Index]()
		{
			if (TSharedPtr<SDPMenuWidget> Self = WeakSelf.Pin())
			{
				Self->Selected = Index;
				if (Self->Items[Index].OnAdjust)
				{
					Self->Adjust(Index, +1);
				}
				else
				{
					Self->Activate(Index);
				}
			}
			return FReply::Handled();
		})
		.OnHovered_Lambda([WeakSelf, Index]()
		{
			if (TSharedPtr<SDPMenuWidget> Self = WeakSelf.Pin())
			{
				Self->Selected = Index;
			}
		})
		[
			SNew(SHorizontalBox)
			+ SHorizontalBox::Slot().AutoWidth().VAlign(VAlign_Center).Padding(0.f, 0.f, 12.f, 0.f)
			[
				SNew(SBox).WidthOverride(4.f).HeightOverride(bMinor ? 14.f : 22.f)
				[
					SNew(SImage).Image(DPUI::White())
					.ColorAndOpacity_Lambda([IsSelected, bCorrupt]()
					{
						return IsSelected() ? FSlateColor(bCorrupt ? DPUI::Danger : DPUI::Accent) : FSlateColor(FLinearColor::Transparent);
					})
				]
			]
			+ SHorizontalBox::Slot().FillWidth(1.f).VAlign(VAlign_Center)
			[
				SNew(STextBlock)
				.Text(Item.Label)
				.Font_Lambda([bMinor]() { return DPUI::Font(TEXT("Regular"), bMinor ? 13.f : 22.f); })
				.ColorAndOpacity_Lambda([IsSelected]() { return FSlateColor(IsSelected() ? DPUI::Text : DPUI::Dim); })
			]
			+ SHorizontalBox::Slot().AutoWidth().VAlign(VAlign_Center).Padding(30.f, 0.f, 0.f, 0.f)
			[
				SNew(STextBlock)
				.Visibility(bHasValue ? EVisibility::HitTestInvisible : EVisibility::Collapsed)
				.Text_Lambda([WeakSelf, Index]()
				{
					TSharedPtr<SDPMenuWidget> Self = WeakSelf.Pin();
					if (Self.IsValid() && Self->Items[Index].GetValue)
					{
						return FText::Format(NSLOCTEXT("DPMenu", "Value", "<  {0}  >"), Self->Items[Index].GetValue());
					}
					return FText::GetEmpty();
				})
				.Font_Lambda([]() { return DPUI::Font(TEXT("Regular"), 18.f); })
				.ColorAndOpacity(FSlateColor(DPUI::Accent))
			]
		];
}

void SDPMenuWidget::Tick(const FGeometry& AllottedGeometry, const double InCurrentTime, const float InDeltaTime)
{
	SCompoundWidget::Tick(AllottedGeometry, InCurrentTime, InDeltaTime);
	Age += InDeltaTime;
	if (TimeoutLeft > 0.f)
	{
		TimeoutLeft -= InDeltaTime;
		if (TimeoutLeft <= 0.f && OnTimeout)
		{
			TFunction<void()> Fn = OnTimeout;
			OnTimeout = nullptr;
			Fn();
		}
	}
}

void SDPMenuWidget::MoveSelection(int32 Direction)
{
	if (Items.Num() > 0)
	{
		Selected = (Selected + Direction + Items.Num()) % Items.Num();
	}
}

void SDPMenuWidget::Activate(int32 Index)
{
	if (Age < 0.15f || !Items.IsValidIndex(Index))
	{
		return; // ignore the key press that opened the menu
	}
	if (Items[Index].OnActivate)
	{
		TFunction<void()> Fn = Items[Index].OnActivate; // the menu may be replaced inside
		Fn();
	}
}

void SDPMenuWidget::Adjust(int32 Index, int32 Direction)
{
	if (Items.IsValidIndex(Index) && Items[Index].OnAdjust)
	{
		Items[Index].OnAdjust(Direction);
	}
}

FReply SDPMenuWidget::OnKeyDown(const FGeometry& MyGeometry, const FKeyEvent& InKeyEvent)
{
	const FKey Key = InKeyEvent.GetKey();

	if (Key == EKeys::Up || Key == EKeys::W || Key == EKeys::Gamepad_DPad_Up || Key == EKeys::Gamepad_LeftStick_Up)
	{
		MoveSelection(-1);
		return FReply::Handled();
	}
	if (Key == EKeys::Down || Key == EKeys::S || Key == EKeys::Gamepad_DPad_Down || Key == EKeys::Gamepad_LeftStick_Down)
	{
		MoveSelection(+1);
		return FReply::Handled();
	}
	if (Key == EKeys::Left || Key == EKeys::A || Key == EKeys::Gamepad_DPad_Left)
	{
		Adjust(Selected, -1);
		return FReply::Handled();
	}
	if (Key == EKeys::Right || Key == EKeys::D || Key == EKeys::Gamepad_DPad_Right)
	{
		Adjust(Selected, +1);
		return FReply::Handled();
	}
	if (Key == EKeys::Enter || Key == EKeys::SpaceBar || Key == EKeys::E || Key == EKeys::Gamepad_FaceButton_Bottom)
	{
		if (Items.IsValidIndex(Selected) && Items[Selected].OnAdjust && !Items[Selected].OnActivate)
		{
			Adjust(Selected, +1);
		}
		else
		{
			Activate(Selected);
		}
		return FReply::Handled();
	}
	if (Key == EKeys::Escape || Key == EKeys::P || Key == EKeys::Gamepad_FaceButton_Right || Key == EKeys::Gamepad_Special_Right)
	{
		if (Age >= 0.15f && OnBack)
		{
			TFunction<void()> Fn = OnBack;
			Fn();
		}
		return FReply::Handled();
	}
	return FReply::Unhandled();
}
