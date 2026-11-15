#include "Notebook/DPNotebookSubsystem.h"
#include "Core/DPData.h"
#include "Core/DPEffects.h"
#include "DreamProtocol.h"

namespace
{
	EDPInkStyle ParseInk(const FString& S, EDPInkStyle Fallback)
	{
		if (S.Equals(TEXT("Player"), ESearchCase::IgnoreCase))  return EDPInkStyle::Player;
		if (S.Equals(TEXT("Pressed"), ESearchCase::IgnoreCase)) return EDPInkStyle::Pressed;
		if (S.Equals(TEXT("Unknown"), ESearchCase::IgnoreCase)) return EDPInkStyle::Unknown;
		if (S.Equals(TEXT("Smudged"), ESearchCase::IgnoreCase)) return EDPInkStyle::Smudged;
		return Fallback;
	}
}

bool UDPNotebookSubsystem::DoesSupportWorldType(const EWorldType::Type WorldType) const
{
	return WorldType == EWorldType::Game || WorldType == EWorldType::PIE;
}

void UDPNotebookSubsystem::ResetState()
{
	Rules.Reset();
}

void UDPNotebookSubsystem::LoadState(const TArray<FDPRuleState>& Saved)
{
	Rules = Saved;
}

FDPRuleState* UDPNotebookSubsystem::FindState(const FString& Id)
{
	return Rules.FindByPredicate([&Id](const FDPRuleState& R) { return R.Id == Id; });
}

const FDPRuleState* UDPNotebookSubsystem::FindState(const FString& Id) const
{
	return Rules.FindByPredicate([&Id](const FDPRuleState& R) { return R.Id == Id; });
}

FDPRuleState& UDPNotebookSubsystem::FindOrAdd(const FString& Id)
{
	if (FDPRuleState* Existing = FindState(Id))
	{
		return *Existing;
	}
	FDPRuleState& New = Rules.AddDefaulted_GetRef();
	New.Id = Id;
	return New;
}

void UDPNotebookSubsystem::Write(const FString& Id)
{
	if (!FDPData::FindRule(Id))
	{
		UE_LOG(LogDream, Warning, TEXT("Notebook: unknown rule '%s'"), *Id);
		return;
	}
	FDPRuleState& R = FindOrAdd(Id);
	R.bWritten = true;
	R.bHidden = false;
	R.bPendingReveal = false;
}

void UDPNotebookSubsystem::RevealOnNextOpen(const FString& Id)
{
	if (!FDPData::FindRule(Id))
	{
		UE_LOG(LogDream, Warning, TEXT("Notebook: unknown rule '%s'"), *Id);
		return;
	}
	FDPRuleState& R = FindOrAdd(Id);
	if (!R.bWritten || R.bHidden)
	{
		R.bPendingReveal = true;
	}
}

void UDPNotebookSubsystem::Hide(const FString& Id)
{
	if (FDPRuleState* R = FindState(Id))
	{
		R->bHidden = true;
		R->bPendingReveal = false;
	}
}

void UDPNotebookSubsystem::Rewrite(const FString& Id, const FString& VariantId)
{
	FDPRuleState& R = FindOrAdd(Id);
	R.VariantId = VariantId;
}

void UDPNotebookSubsystem::BreakRule(const FString& Id)
{
	const FDPRuleDef* Def = FDPData::FindRule(Id);
	if (!Def)
	{
		UE_LOG(LogDream, Warning, TEXT("Notebook: tried to break unknown rule '%s'"), *Id);
		return;
	}
	FDPRuleState& R = FindOrAdd(Id);
	++R.BreakCount;
	UE_LOG(LogDream, Log, TEXT("Rule broken: %s (x%d)"), *Id, R.BreakCount);

	const TArray<FString>& Effects = (R.BreakCount > 1 && Def->OnRepeatBreak.Num() > 0) ? Def->OnRepeatBreak : Def->OnBreak;
	// Copy: effects may modify the rule array.
	const TArray<FString> EffectsCopy = Effects;
	DPEffects::ApplyAll(GetWorld(), EffectsCopy);
}

void UDPNotebookSubsystem::OnNotebookOpened()
{
	TArray<FString> RereadBreaks;

	// Rules that punish re-reading are checked against what was visible *before* this opening.
	for (FDPRuleState& R : Rules)
	{
		if (R.bWritten && !R.bHidden)
		{
			const FDPRuleDef* Def = FDPData::FindRule(R.Id);
			if (Def && Def->BreaksOnReread)
			{
				if (R.ReadsWhileVisible >= 1)
				{
					RereadBreaks.Add(R.Id);
				}
			}
			++R.ReadsWhileVisible;
		}
	}

	// New lines appear now; this opening counts as their first reading.
	for (FDPRuleState& R : Rules)
	{
		if (R.bPendingReveal)
		{
			R.bPendingReveal = false;
			R.bWritten = true;
			R.bHidden = false;
			R.ReadsWhileVisible = 1;
		}
	}

	for (const FString& Id : RereadBreaks)
	{
		BreakRule(Id);
	}
}

TArray<FDPNotebookLine> UDPNotebookSubsystem::BuildPage() const
{
	struct FSortable
	{
		int32 Order;
		FDPNotebookLine Line;
	};
	TArray<FSortable> Items;

	for (const FDPRuleState& R : Rules)
	{
		if (!R.bWritten || R.bHidden)
		{
			continue;
		}
		const FDPRuleDef* Def = FDPData::FindRule(R.Id);
		if (!Def)
		{
			continue;
		}

		FString Text = Def->Text;
		EDPInkStyle Style = ParseInk(Def->Style, EDPInkStyle::Player);
		if (!R.VariantId.IsEmpty())
		{
			if (const FDPRuleVariant* V = Def->Variants.FindByPredicate([&R](const FDPRuleVariant& X) { return X.Id == R.VariantId; }))
			{
				Text = V->Text;
				Style = ParseInk(V->Style, Style);
			}
		}

		FSortable& S = Items.AddDefaulted_GetRef();
		S.Order = Def->Order;
		S.Line.Text = FText::FromString(Text);
		S.Line.Style = Style;
	}

	Items.Sort([](const FSortable& A, const FSortable& B) { return A.Order < B.Order; });

	TArray<FDPNotebookLine> Page;
	int32 Number = 1;
	for (FSortable& S : Items)
	{
		// Only the player's own rules are numbered; other handwriting just... appears.
		S.Line.Number = (S.Line.Style == EDPInkStyle::Unknown) ? 0 : Number++;
		Page.Add(S.Line);
	}
	return Page;
}

bool UDPNotebookSubsystem::HasAnyWritten() const
{
	return Rules.ContainsByPredicate([](const FDPRuleState& R) { return R.bWritten; });
}

int32 UDPNotebookSubsystem::GetBreakCount(const FString& Id) const
{
	const FDPRuleState* R = FindState(Id);
	return R ? R->BreakCount : 0;
}

bool UDPNotebookSubsystem::HasPendingChanges() const
{
	return Rules.ContainsByPredicate([](const FDPRuleState& R) { return R.bPendingReveal; });
}
