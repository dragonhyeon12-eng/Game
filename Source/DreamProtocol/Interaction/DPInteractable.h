#pragma once

#include "CoreMinimal.h"
#include "UObject/Interface.h"
#include "DPInteractable.generated.h"

class ADPCharacter;

UINTERFACE(MinimalAPI, meta = (CannotImplementInterfaceInBlueprint))
class UDPInteractable : public UInterface
{
	GENERATED_BODY()
};

/**
 * Anything the player can use with the Interact key. The character traces from the camera every frame;
 * the first hit actor implementing this interface (and returning CanInteract) is focused.
 */
class DREAMPROTOCOL_API IDPInteractable
{
	GENERATED_BODY()

public:
	virtual FText GetInteractPrompt(const ADPCharacter* By) const = 0;
	virtual bool CanInteract(const ADPCharacter* By) const { return true; }
	virtual void Interact(ADPCharacter* By) = 0;
};
