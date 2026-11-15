#pragma once

#include "CoreMinimal.h"
#include "Widgets/SCompoundWidget.h"

class SVerticalBox;

/** A menu row. Settings rows provide GetValue + OnAdjust. */
struct FDPMenuItem
{
	FText Label;
	TFunction<void()> OnActivate;
	TFunction<FText()> GetValue;
	TFunction<void(int32)> OnAdjust;
	/** Rendered small and dim (e.g. a footnote action). */
	bool bMinor = false;
};

/**
 * Keyboard/mouse/gamepad menu used for the title screen, pause menu (including its corrupted form)
 * and settings. Up/Down select, Enter/Space/A activate, Left/Right adjust, Esc/B go back.
 */
class DREAMPROTOCOL_API SDPMenuWidget : public SCompoundWidget
{
public:
	SLATE_BEGIN_ARGS(SDPMenuWidget)
		: _Corrupted(false)
		, _AutoActivateAfter(-1.f)
	{}
		SLATE_ARGUMENT(FText, Title)
		SLATE_ARGUMENT(FText, Subtitle)
		SLATE_ARGUMENT(FText, Footnote)
		SLATE_ARGUMENT(TArray<FDPMenuItem>, Items)
		SLATE_ARGUMENT(bool, Corrupted)
		/** Seconds of real time after which OnTimeout fires (used by the rare self-unpause). */
		SLATE_ARGUMENT(float, AutoActivateAfter)
		SLATE_ARGUMENT(TFunction<void()>, OnBack)
		SLATE_ARGUMENT(TFunction<void()>, OnTimeout)
	SLATE_END_ARGS()

	void Construct(const FArguments& InArgs);

	virtual bool SupportsKeyboardFocus() const override { return true; }
	virtual FReply OnKeyDown(const FGeometry& MyGeometry, const FKeyEvent& InKeyEvent) override;
	virtual void Tick(const FGeometry& AllottedGeometry, const double InCurrentTime, const float InDeltaTime) override;

private:
	TSharedRef<SWidget> MakeRow(int32 Index);
	void Activate(int32 Index);
	void Adjust(int32 Index, int32 Direction);
	void MoveSelection(int32 Direction);

	TArray<FDPMenuItem> Items;
	TFunction<void()> OnBack;
	TFunction<void()> OnTimeout;
	int32 Selected = 0;
	bool bCorrupted = false;
	float TimeoutLeft = -1.f;
	float Age = 0.f;
};
