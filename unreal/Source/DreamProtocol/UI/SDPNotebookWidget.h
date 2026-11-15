#pragma once

#include "CoreMinimal.h"
#include "Widgets/SCompoundWidget.h"
#include "Notebook/DPNotebookSubsystem.h"

/** The open notebook: one lined page of rules in whoever's handwriting wrote them. */
class DREAMPROTOCOL_API SDPNotebookWidget : public SCompoundWidget
{
public:
	SLATE_BEGIN_ARGS(SDPNotebookWidget) {}
		SLATE_ARGUMENT(FText, Header)
		SLATE_ARGUMENT(TArray<FDPNotebookLine>, Lines)
		SLATE_ARGUMENT(TFunction<void()>, OnClose)
	SLATE_END_ARGS()

	void Construct(const FArguments& InArgs);

	virtual bool SupportsKeyboardFocus() const override { return true; }
	virtual FReply OnKeyDown(const FGeometry& MyGeometry, const FKeyEvent& InKeyEvent) override;
	virtual FReply OnMouseButtonDown(const FGeometry& MyGeometry, const FPointerEvent& MouseEvent) override;
	virtual void Tick(const FGeometry& AllottedGeometry, const double InCurrentTime, const float InDeltaTime) override;

private:
	void Close();

	TFunction<void()> OnClose;
	float Age = 0.f;
	bool bClosed = false;
};
