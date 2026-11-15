#include "Manifestation/DPManifestationComponent.h"
#include "Manifestation/DPManifestedObject.h"
#include "Core/DPCharacter.h"
#include "Core/DPData.h"
#include "Core/DPGameMode.h"
#include "Dread/DPDreadComponent.h"
#include "Notebook/DPNotebookSubsystem.h"
#include "UI/DPHUD.h"
#include "World/DPZone.h"
#include "Camera/CameraComponent.h"
#include "Engine/World.h"

#define LOCTEXT_NAMESPACE "DPManifest"

namespace
{
	constexpr int32 ForceLimitCount = 6;     // this many manifestations...
	constexpr float ForceLimitWindow = 20.f; // ...within this many seconds breaks rule 5
}

UDPManifestationComponent::UDPManifestationComponent()
{
	PrimaryComponentTick.bCanEverTick = false;
}

ADPCharacter* UDPManifestationComponent::GetCharacter() const
{
	return Cast<ADPCharacter>(GetOwner());
}

void UDPManifestationComponent::ResetUnlocks()
{
	Unlocked = FDPData::Manifestations().StartUnlocked;
	Selected = 0;
	ThoughtShown.Reset();
	FailedAttempts = 0;
}

void UDPManifestationComponent::SetUnlocked(const TArray<FString>& Ids)
{
	Unlocked = Ids;
	Selected = 0;
}

void UDPManifestationComponent::Unlock(const FString& Id)
{
	if (FDPData::FindManifest(Id))
	{
		Unlocked.AddUnique(Id);
	}
}

bool UDPManifestationComponent::TryManifest()
{
	ADPCharacter* Char = GetCharacter();
	ADPGameMode* GM = ADPGameMode::Get(this);
	ADPHUD* HUD = GM ? GM->GetDPHUD() : nullptr;
	if (!Char || !GM)
	{
		return false;
	}

	const ADPZone* Zone = GM->GetZone();
	if (!Zone || !Zone->AllowsManifestation())
	{
		// In a nightmare, nothing comes. That is its own kind of horror.
		if (Zone && Zone->IsNightmare())
		{
			++FailedAttempts;
			if (HUD)
			{
				HUD->ShowThought(FailedAttempts == 1
					? LOCTEXT("NothingFirst", "...Nothing. It worked a minute ago.")
					: LOCTEXT("Nothing", "Nothing comes."), 3.5f);
			}
			Char->GetDread()->AddFear(FailedAttempts == 1 ? 5.f : 2.f, TEXT("ManifestFailed"));
		}
		else if (HUD)
		{
			HUD->ShowThought(LOCTEXT("NotHere", "Nothing happens. Of course nothing happens. You're awake."), 3.5f);
		}
		return false;
	}

	if (Unlocked.Num() == 0)
	{
		return false;
	}
	Selected = FMath::Clamp(Selected, 0, Unlocked.Num() - 1);
	const FDPManifestDef* Def = FDPData::FindManifest(Unlocked[Selected]);
	if (!Def)
	{
		return false;
	}

	// Whatever we were holding drops out of our hand.
	if (Held)
	{
		Held->Release(FVector::ZeroVector);
		Held = nullptr;
	}

	FActorSpawnParameters Params;
	Params.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;
	const FTransform SpawnXf = Char->GetHoldPoint()->GetComponentTransform();
	ADPManifestedObject* Obj = GetWorld()->SpawnActor<ADPManifestedObject>(ADPManifestedObject::StaticClass(), SpawnXf, Params);
	if (!Obj)
	{
		return false;
	}
	Obj->InitFromDef(*Def);
	Obj->SetHeld(true);
	Obj->AttachToComponent(Char->GetHoldPoint(), FAttachmentTransformRules::SnapToTargetNotIncludingScale);
	Held = Obj;
	Spawned.Add(Obj);
	Char->PlayFoley(EDPSynthEvent::Chime, 1.f);

	if (!ThoughtShown.Contains(Def->Id) && HUD && !Def->Thought.IsEmpty())
	{
		ThoughtShown.Add(Def->Id);
		HUD->ShowThought(FText::FromString(Def->Thought), 4.5f);
	}

	if (!GM->HasFlag(TEXT("manifest_first")))
	{
		GM->SetFlag(TEXT("manifest_first"));
		for (const FString& Id : FDPData::Manifestations().UnlockAfterFirst)
		{
			Unlock(Id);
		}
		if (HUD)
		{
			HUD->ShowHint(LOCTEXT("HeldHint", "Left mouse: take a bite    Right mouse: let go / toss\nMouse wheel: picture something else"), 9.f);
		}
	}

	// Rule 5: don't forcefully change your surroundings.
	const double Now = GetWorld()->GetTimeSeconds();
	RecentManifestTimes.Add(Now);
	RecentManifestTimes.RemoveAll([Now](double T) { return Now - T > ForceLimitWindow; });
	if (RecentManifestTimes.Num() >= ForceLimitCount)
	{
		RecentManifestTimes.Reset();
		if (UDPNotebookSubsystem* Notebook = GetWorld()->GetSubsystem<UDPNotebookSubsystem>())
		{
			Notebook->BreakRule(TEXT("rule_force"));
		}
	}

	return true;
}

void UDPManifestationComponent::UseHeld()
{
	ADPCharacter* Char = GetCharacter();
	if (!Held || !Char)
	{
		return;
	}
	if (!Held->IsEdible())
	{
		return;
	}
	Char->PlayFoley(EDPSynthEvent::Bite, 1.f);
	if (Held->Bite())
	{
		Held->Destroy();
		Held = nullptr;
		ADPGameMode* GM = ADPGameMode::Get(this);
		if (GM && !GM->HasFlag(TEXT("ate_icecream")))
		{
			GM->SetFlag(TEXT("ate_icecream"));
			if (ADPHUD* HUD = GM->GetDPHUD())
			{
				HUD->ShowThought(LOCTEXT("Ate", "Tastes exactly like summer used to."), 4.f);
			}
		}
	}
}

void UDPManifestationComponent::ThrowHeld()
{
	ADPCharacter* Char = GetCharacter();
	if (!Held || !Char)
	{
		return;
	}
	const FVector Dir = Char->GetCamera()->GetForwardVector();
	Held->Release(Dir * 420.f + FVector(0, 0, 120.f));
	Held = nullptr;
}

void UDPManifestationComponent::CycleSelection(int32 Direction)
{
	if (Unlocked.Num() <= 1)
	{
		return;
	}
	Selected = (Selected + Direction + Unlocked.Num()) % Unlocked.Num();
	if (ADPGameMode* GM = ADPGameMode::Get(this))
	{
		if (ADPHUD* HUD = GM->GetDPHUD())
		{
			HUD->ShowHint(FText::Format(LOCTEXT("Picturing", "Picturing: {0}  (hold Q)"), GetSelectedName()), 2.5f);
		}
	}
}

void UDPManifestationComponent::ClearAll()
{
	for (const TWeakObjectPtr<ADPManifestedObject>& Obj : Spawned)
	{
		if (Obj.IsValid())
		{
			Obj->Destroy();
		}
	}
	Spawned.Reset();
	Held = nullptr;
	RecentManifestTimes.Reset();
}

bool UDPManifestationComponent::GiveHeldTo(USceneComponent* Receiver, const FVector& RelativeOffset)
{
	if (!Held || !Receiver)
	{
		return false;
	}
	Held->DetachFromActor(FDetachmentTransformRules::KeepWorldTransform);
	Held->AttachToComponent(Receiver, FAttachmentTransformRules::SnapToTargetNotIncludingScale);
	Held->SetActorRelativeLocation(RelativeOffset);
	Held = nullptr;
	return true;
}

bool UDPManifestationComponent::IsHolding(const FString& Id) const
{
	return Held && Held->GetDefId() == Id;
}

AActor* UDPManifestationComponent::GetHeldActor() const
{
	return Held;
}

FText UDPManifestationComponent::GetSelectedName() const
{
	if (Unlocked.IsValidIndex(Selected))
	{
		if (const FDPManifestDef* Def = FDPData::FindManifest(Unlocked[Selected]))
		{
			return FText::FromString(Def->Name);
		}
	}
	return FText::GetEmpty();
}

#undef LOCTEXT_NAMESPACE
