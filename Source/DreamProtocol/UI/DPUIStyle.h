#pragma once

#include "CoreMinimal.h"
#include "Fonts/SlateFontInfo.h"
#include "Styling/SlateTypes.h"
#include "Core/DPTypes.h"

struct FSlateBrush;

/** Shared look for every DREAM PROTOCOL widget. */
namespace DPUI
{
	/** Accessibility text scale, kept in sync with settings by the HUD. */
	extern DREAMPROTOCOL_API float TextScale;

	DREAMPROTOCOL_API const FSlateBrush* White();
	DREAMPROTOCOL_API FSlateFontInfo Font(const FName& Typeface, float Size);
	DREAMPROTOCOL_API const FButtonStyle& FlatButton();

	DREAMPROTOCOL_API FLinearColor InkColor(EDPInkStyle Style);
	DREAMPROTOCOL_API FSlateFontInfo InkFont(EDPInkStyle Style, float Size);

	const FLinearColor Text(0.93f, 0.92f, 0.88f, 1.f);
	const FLinearColor Dim(0.6f, 0.6f, 0.58f, 1.f);
	const FLinearColor Accent(0.95f, 0.78f, 0.45f, 1.f);
	const FLinearColor Danger(0.75f, 0.1f, 0.08f, 1.f);
	const FLinearColor Panel(0.02f, 0.02f, 0.025f, 0.72f);
}
