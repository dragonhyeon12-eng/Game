#pragma once

#include "CoreMinimal.h"
#include "Subsystems/WorldSubsystem.h"
#include "DPDialogueSubsystem.generated.h"

class ADPNPC;
struct FDPDialogue;
struct FDPDialogueNode;

/**
 * Runs one conversation at a time from Content/Data/Dialogue.json.
 * Nodes and choices carry effect strings, so story consequences live in data, not code.
 */
UCLASS()
class DREAMPROTOCOL_API UDPDialogueSubsystem : public UWorldSubsystem
{
	GENERATED_BODY()

public:
	virtual bool DoesSupportWorldType(const EWorldType::Type WorldType) const override;

	bool StartDialogue(ADPNPC* Speaker, const FString& DialogueId);
	/** Index into the currently *visible* choices. */
	void Choose(int32 VisibleIndex);
	/** Continue a node that has no choices. */
	void Advance();
	void EndDialogue();

	bool IsActive() const { return Dialogue != nullptr; }
	ADPNPC* GetSpeaker() const { return Speaker.Get(); }

private:
	void EnterNode(const FString& NodeId);
	void Present();

	const FDPDialogue* Dialogue = nullptr;
	const FDPDialogueNode* Node = nullptr;
	TArray<int32> VisibleChoices;
	TWeakObjectPtr<ADPNPC> Speaker;
	double StartedTime = 0.0;
};
