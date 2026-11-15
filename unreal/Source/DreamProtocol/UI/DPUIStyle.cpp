#include "UI/DPUIStyle.h"
#include "Brushes/SlateColorBrush.h"
#include "Styling/CoreStyle.h"

float DPUI::TextScale = 1.f;

const FSlateBrush* DPUI::White()
{
	static FSlateColorBrush Brush(FLinearColor::White);
	return &Brush;
}

FSlateFontInfo DPUI::Font(const FName& Typeface, float Size)
{
	return FCoreStyle::GetDefaultFontStyle(Typeface, FMath::RoundToFloat(Size * TextScale));
}

const FButtonStyle& DPUI::FlatButton()
{
	static FButtonStyle Style = []()
	{
		FButtonStyle S;
		S.SetNormal(FSlateColorBrush(FLinearColor(0.f, 0.f, 0.f, 0.f)));
		S.SetHovered(FSlateColorBrush(FLinearColor(1.f, 1.f, 1.f, 0.06f)));
		S.SetPressed(FSlateColorBrush(FLinearColor(1.f, 1.f, 1.f, 0.12f)));
		S.SetNormalPadding(FMargin(0.f));
		S.SetPressedPadding(FMargin(0.f));
		return S;
	}();
	return Style;
}

FLinearColor DPUI::InkColor(EDPInkStyle Style)
{
	switch (Style)
	{
	case EDPInkStyle::Pressed: return FLinearColor(0.04f, 0.06f, 0.2f);
	case EDPInkStyle::Unknown: return FLinearColor(0.35f, 0.04f, 0.04f);
	case EDPInkStyle::Smudged: return FLinearColor(0.25f, 0.27f, 0.35f, 0.55f);
	default:                   return FLinearColor(0.08f, 0.13f, 0.38f);
	}
}

FSlateFontInfo DPUI::InkFont(EDPInkStyle Style, float Size)
{
	switch (Style)
	{
	case EDPInkStyle::Pressed: return Font(TEXT("Bold"), Size + 2.f);
	case EDPInkStyle::Unknown: return Font(TEXT("Regular"), Size - 1.f);
	case EDPInkStyle::Smudged: return Font(TEXT("Italic"), Size);
	default:                   return Font(TEXT("Italic"), Size);
	}
}
