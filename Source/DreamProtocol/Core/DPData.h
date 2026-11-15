#pragma once

#include "CoreMinimal.h"
#include "DPData.generated.h"

/*
 * Data-driven content. Everything here is loaded from JSON in Content/Data/ so that dialogue,
 * notebook rules, manifestable objects and the tutorial script can be edited without recompiling.
 * Starting a New Game reloads the files, so designers can iterate while the editor is running.
 *
 * Effects are plain strings ("fear:+10", "rule:break:rule_tell", ...). See DPEffects.h.
 */

// ---------------------------------------------------------------- Dialogue

USTRUCT()
struct FDPDialogueChoice
{
	GENERATED_BODY()

	UPROPERTY() FString Text;
	/** Node to jump to. Empty or "end" closes the conversation. */
	UPROPERTY() FString Next;
	UPROPERTY() TArray<FString> Effects;
	/** Choice is only offered if this condition is true (flag name, or "holding:<manifest id>"). */
	UPROPERTY() FString RequiresFlag;
	/** Choice is hidden once this flag is set. */
	UPROPERTY() FString HiddenIfFlag;
};

USTRUCT()
struct FDPDialogueNode
{
	GENERATED_BODY()

	UPROPERTY() FString Id;
	/** Empty speaker = narration. */
	UPROPERTY() FString Speaker;
	UPROPERTY() FString Text;
	/** Effects applied when the node is shown. */
	UPROPERTY() TArray<FString> Effects;
	UPROPERTY() TArray<FDPDialogueChoice> Choices;
	/** Used when there are no choices: "continue" goes here. */
	UPROPERTY() FString Next;
};

USTRUCT()
struct FDPDialogueEntry
{
	GENERATED_BODY()

	/** Empty = always matches. Entries are tested in order. */
	UPROPERTY() FString IfFlag;
	UPROPERTY() FString Node;
};

USTRUCT()
struct FDPDialogue
{
	GENERATED_BODY()

	UPROPERTY() FString Id;
	UPROPERTY() TArray<FDPDialogueEntry> Entries;
	UPROPERTY() TArray<FDPDialogueNode> Nodes;
	/** One-liners for ambient characters that are not talked to (e.g. the jogger). */
	UPROPERTY() TArray<FString> Barks;

	const FDPDialogueNode* FindNode(const FString& NodeId) const
	{
		return Nodes.FindByPredicate([&NodeId](const FDPDialogueNode& N) { return N.Id == NodeId; });
	}
};

USTRUCT()
struct FDPDialogueFile
{
	GENERATED_BODY()

	UPROPERTY() TArray<FDPDialogue> Dialogues;
};

// ---------------------------------------------------------------- Notebook

USTRUCT()
struct FDPRuleVariant
{
	GENERATED_BODY()

	UPROPERTY() FString Id;
	UPROPERTY() FString Text;
	/** Player | Pressed | Unknown | Smudged. Empty = inherit from the rule. */
	UPROPERTY() FString Style;
};

USTRUCT()
struct FDPRuleDef
{
	GENERATED_BODY()

	UPROPERTY() FString Id;
	UPROPERTY() FString Text;
	UPROPERTY() FString Style;
	/** Position on the page. */
	UPROPERTY() int32 Order = 0;
	/** If non-zero, opening the notebook again while this rule is visible counts as breaking it. */
	UPROPERTY() int32 BreaksOnReread = 0;
	UPROPERTY() TArray<FDPRuleVariant> Variants;
	/** Effects on the first break. */
	UPROPERTY() TArray<FString> OnBreak;
	/** Effects on every later break. Falls back to OnBreak when empty. */
	UPROPERTY() TArray<FString> OnRepeatBreak;
};

USTRUCT()
struct FDPNotebookFile
{
	GENERATED_BODY()

	UPROPERTY() FString Title;
	UPROPERTY() TArray<FDPRuleDef> Rules;
};

// ---------------------------------------------------------------- Manifestation

USTRUCT()
struct FDPShapePart
{
	GENERATED_BODY()

	/** Cube | Sphere | Cylinder | Cone | Plane */
	UPROPERTY() FString Shape;
	/** [x,y,z] in cm */
	UPROPERTY() TArray<float> Offset;
	/** [x,y,z] multiplier of the 100cm engine shape */
	UPROPERTY() TArray<float> Scale;
	/** [pitch,yaw,roll] */
	UPROPERTY() TArray<float> Rotation;
	/** [r,g,b] linear */
	UPROPERTY() TArray<float> Color;
	/** Non-zero parts shrink when the object is bitten. */
	UPROPERTY() int32 Edible = 0;
};

USTRUCT()
struct FDPManifestDef
{
	GENERATED_BODY()

	UPROPERTY() FString Id;
	UPROPERTY() FString Name;
	/** Thought shown the first time this object is manifested. */
	UPROPERTY() FString Thought;
	/** Number of bites before the object is gone. 0 = not edible. */
	UPROPERTY() int32 Bites = 0;
	/** Non-zero objects float upwards when released. */
	UPROPERTY() int32 Buoyant = 0;
	UPROPERTY() float CollisionRadius = 10.f;
	UPROPERTY() float Mass = 1.f;
	UPROPERTY() TArray<FDPShapePart> Parts;
};

USTRUCT()
struct FDPManifestFile
{
	GENERATED_BODY()

	/** Ids unlocked at the start of a new game. */
	UPROPERTY() TArray<FString> StartUnlocked;
	/** Ids unlocked after the first successful manifestation. */
	UPROPERTY() TArray<FString> UnlockAfterFirst;
	UPROPERTY() TArray<FDPManifestDef> Manifestations;
};

// ---------------------------------------------------------------- Tutorial video

USTRUCT()
struct FDPTutorialLine
{
	GENERATED_BODY()

	UPROPERTY() FString Text;
	UPROPERTY() float Duration = 4.f;
	/** If set, the player writes this rule into the notebook when the line plays. */
	UPROPERTY() FString WriteRule;
};

USTRUCT()
struct FDPTutorialFile
{
	GENERATED_BODY()

	UPROPERTY() FString Title;
	UPROPERTY() FString Channel;
	UPROPERTY() FString Views;
	UPROPERTY() TArray<FDPTutorialLine> Lines;
};

// ---------------------------------------------------------------- Loader

class DREAMPROTOCOL_API FDPData
{
public:
	static const FDPDialogueFile& Dialogue();
	static const FDPNotebookFile& Notebook();
	static const FDPManifestFile& Manifestations();
	static const FDPTutorialFile& Tutorial();

	/** Re-read every JSON file from disk. */
	static void ReloadAll();

	static const FDPDialogue* FindDialogue(const FString& Id);
	static const FDPRuleDef* FindRule(const FString& Id);
	static const FDPManifestDef* FindManifest(const FString& Id);

	static FVector ToVector(const TArray<float>& Values, const FVector& Default);
	static FRotator ToRotator(const TArray<float>& Values);
	static FLinearColor ToColor(const TArray<float>& Values, const FLinearColor& Default);
};
