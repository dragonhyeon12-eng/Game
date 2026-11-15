#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "Interaction/DPInteractable.h"
#include "DPInteractableActor.generated.h"

class UBoxComponent;

/**
 * A generic, invisible interaction volume configured in code by the zone that spawns it
 * (bed, computer, notebook, doors...). Visual meshes belong to the zone; this only handles "use".
 */
UCLASS()
class DREAMPROTOCOL_API ADPInteractableActor : public AActor, public IDPInteractable
{
	GENERATED_BODY()

public:
	ADPInteractableActor();

	void Setup(const FVector& HalfExtent, TFunction<FText()> InPrompt, TFunction<void(ADPCharacter*)> InOnInteract,
		TFunction<bool()> InCanInteract = nullptr);

	virtual FText GetInteractPrompt(const ADPCharacter* By) const override;
	virtual bool CanInteract(const ADPCharacter* By) const override;
	virtual void Interact(ADPCharacter* By) override;

private:
	UPROPERTY()
	TObjectPtr<UBoxComponent> Volume;

	TFunction<FText()> PromptFn;
	TFunction<void(ADPCharacter*)> InteractFn;
	TFunction<bool()> CanInteractFn;
};
