#include "Dialogue/DPDialogueSubsystem.h"
#include "Core/DPData.h"
#include "Core/DPEffects.h"
#include "Core/DPGameMode.h"
#include "Core/DPPlayerController.h"
#include "Core/DPCharacter.h"
#include "NPC/DPNPC.h"
#include "UI/DPHUD.h"
#include "DreamProtocol.h"

#define LOCTEXT_NAMESPACE "DPDialogue"

bool UDPDialogueSubsystem::DoesSupportWorldType(const EWorldType::Type WorldType) const
{
	return WorldType == EWorldType::Game || WorldType == EWorldType::PIE;
}

bool UDPDialogueSubsystem::StartDialogue(ADPNPC* InSpeaker, const FString& DialogueId)
{
	if (IsActive())
	{
		return false;
	}
	const FDPDialogue* D = FDPData::FindDialogue(DialogueId);
	if (!D)
	{
		UE_LOG(LogDream, Warning, TEXT("Dialogue '%s' not found"), *DialogueId);
		return false;
	}

	ADPGameMode* GM = ADPGameMode::Get(this);
	if (!GM)
	{
		return false;
	}

	// Choose the entry node by flags (first match wins).
	FString EntryNode;
	for (const FDPDialogueEntry& E : D->Entries)
	{
		if (DPEffects::CheckCondition(GetWorld(), E.IfFlag))
		{
			EntryNode = E.Node;
			break;
		}
	}
	if (EntryNode.IsEmpty() && D->Nodes.Num() > 0)
	{
		EntryNode = D->Nodes[0].Id;
	}

	Dialogue = D;
	Speaker = InSpeaker;
	StartedTime = GetWorld()->GetTimeSeconds();

	if (InSpeaker)
	{
		InSpeaker->SetTalking(true);
	}
	if (ADPPlayerController* PC = GM->GetDPController())
	{
		PC->EnterDialogueMode();
	}

	EnterNode(EntryNode);

	// Flags are set after entry selection so "first meeting" entries work.
	GM->SetFlag(FName(*FString::Printf(TEXT("talked_%s"), *DialogueId)));
	GM->SetFlag(TEXT("talked_any"));
	return true;
}

void UDPDialogueSubsystem::EnterNode(const FString& NodeId)
{
	if (!Dialogue || NodeId.IsEmpty() || NodeId.Equals(TEXT("end"), ESearchCase::IgnoreCase))
	{
		EndDialogue();
		return;
	}
	Node = Dialogue->FindNode(NodeId);
	if (!Node)
	{
		UE_LOG(LogDream, Warning, TEXT("Dialogue '%s': node '%s' not found"), *Dialogue->Id, *NodeId);
		EndDialogue();
		return;
	}

	DPEffects::FContext Ctx;
	Ctx.Speaker = Speaker.Get();
	const TArray<FString> Effects = Node->Effects;
	DPEffects::ApplyAll(GetWorld(), Effects, Ctx);

	if (IsActive())
	{
		Present();
	}
}

void UDPDialogueSubsystem::Present()
{
	ADPGameMode* GM = ADPGameMode::Get(this);
	ADPHUD* HUD = GM ? GM->GetDPHUD() : nullptr;
	if (!HUD || !Node)
	{
		return;
	}

	VisibleChoices.Reset();
	TArray<FText> ChoiceTexts;
	for (int32 i = 0; i < Node->Choices.Num(); ++i)
	{
		const FDPDialogueChoice& C = Node->Choices[i];
		if (!DPEffects::CheckCondition(GetWorld(), C.RequiresFlag))
		{
			continue;
		}
		if (!C.HiddenIfFlag.IsEmpty() && DPEffects::CheckCondition(GetWorld(), C.HiddenIfFlag))
		{
			continue;
		}
		VisibleChoices.Add(i);
		ChoiceTexts.Add(FText::FromString(C.Text));
	}

	HUD->ShowDialogue(FText::FromString(Node->Speaker), FText::FromString(Node->Text), ChoiceTexts);
}

void UDPDialogueSubsystem::Choose(int32 VisibleIndex)
{
	if (!IsActive() || !Node)
	{
		return;
	}
	if (VisibleChoices.Num() == 0)
	{
		Advance();
		return;
	}
	if (!VisibleChoices.IsValidIndex(VisibleIndex))
	{
		return;
	}

	const FDPDialogueChoice Choice = Node->Choices[VisibleChoices[VisibleIndex]];
	DPEffects::FContext Ctx;
	Ctx.Speaker = Speaker.Get();
	DPEffects::ApplyAll(GetWorld(), Choice.Effects, Ctx);

	if (IsActive())
	{
		EnterNode(Choice.Next);
	}
}

void UDPDialogueSubsystem::Advance()
{
	if (!IsActive() || !Node)
	{
		return;
	}
	if (VisibleChoices.Num() > 0)
	{
		return; // must pick a choice
	}
	EnterNode(Node->Next);
}

void UDPDialogueSubsystem::EndDialogue()
{
	if (!Dialogue)
	{
		return;
	}
	Dialogue = nullptr;
	Node = nullptr;
	VisibleChoices.Reset();

	if (ADPNPC* S = Speaker.Get())
	{
		S->SetTalking(false);
	}
	Speaker.Reset();

	if (ADPGameMode* GM = ADPGameMode::Get(this))
	{
		if (ADPHUD* HUD = GM->GetDPHUD())
		{
			HUD->HideDialogue();
		}
		if (ADPPlayerController* PC = GM->GetDPController())
		{
			PC->ExitDialogueMode();
		}
	}
}

#undef LOCTEXT_NAMESPACE
