#pragma once

#include "CoreMinimal.h"
#include "Subsystems/WorldSubsystem.h"
#include "Core/DPTypes.h"
#include "DPNotebookSubsystem.generated.h"

/** One line on the notebook page, ready for display. */
struct FDPNotebookLine
{
	FText Text;
	EDPInkStyle Style = EDPInkStyle::Player;
	int32 Number = 0;
};

/**
 * The notebook's state: which rules exist, how they are worded, and which have been broken.
 * Rule *definitions* live in Content/Data/Notebook.json; this holds the mutable state.
 *
 * The notebook never tells the player which rules are trustworthy. It only changes.
 */
UCLASS()
class DREAMPROTOCOL_API UDPNotebookSubsystem : public UWorldSubsystem
{
	GENERATED_BODY()

public:
	virtual bool DoesSupportWorldType(const EWorldType::Type WorldType) const override;

	void ResetState();
	void LoadState(const TArray<FDPRuleState>& Saved);
	const TArray<FDPRuleState>& GetState() const { return Rules; }

	void Write(const FString& Id);
	void RevealOnNextOpen(const FString& Id);
	void Hide(const FString& Id);
	void Rewrite(const FString& Id, const FString& VariantId);
	void BreakRule(const FString& Id);

	/** Called right before the notebook UI opens: applies pending reveals and re-read rules. */
	void OnNotebookOpened();

	TArray<FDPNotebookLine> BuildPage() const;
	bool HasAnyWritten() const;
	int32 GetBreakCount(const FString& Id) const;

	/** True while there are unseen changes (pending reveals). */
	bool HasPendingChanges() const;

private:
	FDPRuleState* FindState(const FString& Id);
	const FDPRuleState* FindState(const FString& Id) const;
	FDPRuleState& FindOrAdd(const FString& Id);

	UPROPERTY()
	TArray<FDPRuleState> Rules;
};
