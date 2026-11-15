#pragma once

#include "CoreMinimal.h"
#include "Widgets/SCompoundWidget.h"
#include "Core/DPData.h"

class SVerticalBox;

/**
 * The fictional video, "HOW TO LUCID DREAM TONIGHT! (100% WORKING)", shown full-screen on the bedroom PC.
 * Lines advance on a timer (Space skips a line, Esc skips to the end). When a line names a rule, the player
 * writes it into the notebook, shown in the margin.
 */
class DREAMPROTOCOL_API SDPTutorialWidget : public SCompoundWidget
{
public:
	SLATE_BEGIN_ARGS(SDPTutorialWidget) {}
		SLATE_ARGUMENT(FDPTutorialFile, Script)
		SLATE_ARGUMENT(TFunction<void(const FString&)>, OnWriteRule)
		SLATE_ARGUMENT(TFunction<void()>, OnFinished)
	SLATE_END_ARGS()

	void Construct(const FArguments& InArgs);

	virtual bool SupportsKeyboardFocus() const override { return true; }
	virtual FReply OnKeyDown(const FGeometry& MyGeometry, const FKeyEvent& InKeyEvent) override;
	virtual void Tick(const FGeometry& AllottedGeometry, const double InCurrentTime, const float InDeltaTime) override;

private:
	void EnterLine(int32 Index);
	void Finish();
	FText CurrentCaption() const;
	float Progress() const;

	FDPTutorialFile Script;
	TFunction<void(const FString&)> OnWriteRule;
	TFunction<void()> OnFinished;
	TSharedPtr<SVerticalBox> Margin;

	int32 LineIndex = -1;
	float LineTime = 0.f;
	float Elapsed = 0.f;
	float TotalDuration = 1.f;
	float Age = 0.f;
	bool bDone = false;
};
