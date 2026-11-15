#include "Interaction/DPInteractableActor.h"
#include "Components/BoxComponent.h"

ADPInteractableActor::ADPInteractableActor()
{
	PrimaryActorTick.bCanEverTick = false;

	Volume = CreateDefaultSubobject<UBoxComponent>(TEXT("Volume"));
	Volume->SetCollisionEnabled(ECollisionEnabled::QueryOnly);
	Volume->SetCollisionObjectType(ECC_WorldDynamic);
	Volume->SetCollisionResponseToAllChannels(ECR_Ignore);
	Volume->SetCollisionResponseToChannel(ECC_Visibility, ECR_Block);
	Volume->SetHiddenInGame(true);
	RootComponent = Volume;
}

void ADPInteractableActor::Setup(const FVector& HalfExtent, TFunction<FText()> InPrompt,
	TFunction<void(ADPCharacter*)> InOnInteract, TFunction<bool()> InCanInteract)
{
	Volume->SetBoxExtent(HalfExtent);
	PromptFn = MoveTemp(InPrompt);
	InteractFn = MoveTemp(InOnInteract);
	CanInteractFn = MoveTemp(InCanInteract);
}

FText ADPInteractableActor::GetInteractPrompt(const ADPCharacter* By) const
{
	return PromptFn ? PromptFn() : FText::GetEmpty();
}

bool ADPInteractableActor::CanInteract(const ADPCharacter* By) const
{
	return CanInteractFn ? CanInteractFn() : true;
}

void ADPInteractableActor::Interact(ADPCharacter* By)
{
	if (InteractFn)
	{
		InteractFn(By);
	}
}
