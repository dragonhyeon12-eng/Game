#include "Core/DPEffects.h"
#include "Core/DPCharacter.h"
#include "Core/DPGameMode.h"
#include "Dread/DPDreadComponent.h"
#include "Manifestation/DPManifestationComponent.h"
#include "Notebook/DPNotebookSubsystem.h"
#include "NPC/DPNPC.h"
#include "UI/DPHUD.h"
#include "World/DPZone.h"
#include "DreamProtocol.h"
#include "Kismet/GameplayStatics.h"

namespace
{
	/** Splits "verb:a:b:rest with: colons" into at most MaxParts parts (the last keeps its colons). */
	TArray<FString> SplitEffect(const FString& Effect, int32 MaxParts)
	{
		TArray<FString> Parts;
		FString Rest = Effect.TrimStartAndEnd();
		while (Parts.Num() < MaxParts - 1)
		{
			FString Left, Right;
			if (!Rest.Split(TEXT(":"), &Left, &Right))
			{
				break;
			}
			Parts.Add(Left.TrimStartAndEnd());
			Rest = Right;
		}
		Parts.Add(Rest.TrimStartAndEnd());
		return Parts;
	}
}

bool DPEffects::CheckCondition(UWorld* World, const FString& Condition)
{
	if (Condition.IsEmpty())
	{
		return true;
	}
	FString Left, Right;
	if (Condition.Split(TEXT(":"), &Left, &Right) && Left.Equals(TEXT("holding"), ESearchCase::IgnoreCase))
	{
		const ADPCharacter* Char = Cast<ADPCharacter>(UGameplayStatics::GetPlayerPawn(World, 0));
		return Char && Char->GetManifestation()->IsHolding(Right);
	}
	const ADPGameMode* GM = ADPGameMode::Get(World);
	return GM && GM->HasFlag(FName(*Condition));
}

void DPEffects::ApplyAll(UWorld* World, const TArray<FString>& Effects, const FContext& Context)
{
	for (const FString& E : Effects)
	{
		Apply(World, E, Context);
	}
}

void DPEffects::Apply(UWorld* World, const FString& Effect, const FContext& Context)
{
	if (!World || Effect.IsEmpty())
	{
		return;
	}
	ADPGameMode* GM = ADPGameMode::Get(World);
	ADPCharacter* Char = Cast<ADPCharacter>(UGameplayStatics::GetPlayerPawn(World, 0));
	ADPHUD* HUD = GM ? GM->GetDPHUD() : nullptr;
	UDPNotebookSubsystem* Notebook = World->GetSubsystem<UDPNotebookSubsystem>();

	const TArray<FString> P = SplitEffect(Effect, 4);
	const FString Verb = P[0].ToLower();
	auto Arg = [&P](int32 i) { return P.IsValidIndex(i) ? P[i] : FString(); };

	if (Verb == TEXT("fear") && Char)
	{
		Char->GetDread()->AddFear(FCString::Atof(*Arg(1)), TEXT("Effect"));
	}
	else if (Verb == TEXT("stability") && Char)
	{
		Char->GetDread()->AddStability(FCString::Atof(*Arg(1)));
	}
	else if (Verb == TEXT("flag") && GM)
	{
		GM->SetFlag(FName(*Arg(1)));
	}
	else if (Verb == TEXT("unflag") && GM)
	{
		GM->ClearFlag(FName(*Arg(1)));
	}
	else if (Verb == TEXT("rule") && Notebook)
	{
		if (Arg(1).Equals(TEXT("break"), ESearchCase::IgnoreCase))
		{
			Notebook->BreakRule(Arg(2));
		}
	}
	else if (Verb == TEXT("notebook") && Notebook)
	{
		const FString Op = Arg(1).ToLower();
		if (Op == TEXT("write"))        Notebook->Write(Arg(2));
		else if (Op == TEXT("reveal"))  Notebook->RevealOnNextOpen(Arg(2));
		else if (Op == TEXT("hide"))    Notebook->Hide(Arg(2));
		else if (Op == TEXT("rewrite")) Notebook->Rewrite(Arg(2), Arg(3));
		else UE_LOG(LogDream, Warning, TEXT("Unknown notebook effect '%s'"), *Effect);
	}
	else if (Verb == TEXT("observer") && GM && GM->GetZone())
	{
		GM->GetZone()->HandleObserverEvent(FName(*Arg(1)));
	}
	else if (Verb == TEXT("thought") && HUD)
	{
		// Re-join: thoughts may contain colons.
		const FString Text = Effect.RightChop(Effect.Find(TEXT(":")) + 1).TrimStartAndEnd();
		HUD->ShowThought(FText::FromString(Text), 4.f);
	}
	else if (Verb == TEXT("hint") && HUD)
	{
		const FString Text = Effect.RightChop(Effect.Find(TEXT(":")) + 1).TrimStartAndEnd();
		HUD->ShowHint(FText::FromString(Text), 6.f);
	}
	else if (Verb == TEXT("unlock") && Char)
	{
		Char->GetManifestation()->Unlock(Arg(1));
	}
	else if (Verb == TEXT("manifest") && Char)
	{
		if (Arg(1).Equals(TEXT("give"), ESearchCase::IgnoreCase) && Context.Speaker)
		{
			Char->GetManifestation()->GiveHeldTo(Context.Speaker->GetHandPoint(), FVector(4.f, 0.f, 6.f));
		}
	}
	else if (Verb == TEXT("sound") && Char)
	{
		const FString S = Arg(1).ToLower();
		if (S == TEXT("page"))       Char->PlayFoley(EDPSynthEvent::Page);
		else if (S == TEXT("knock")) Char->PlayFoley(EDPSynthEvent::Knock);
		else if (S == TEXT("thud"))  Char->PlayFoley(EDPSynthEvent::Thud);
		else if (S == TEXT("chime")) Char->PlayFoley(EDPSynthEvent::Chime);
	}
	else
	{
		UE_LOG(LogDream, Warning, TEXT("Unknown effect '%s'"), *Effect);
	}
}
