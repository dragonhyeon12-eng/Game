#pragma once

#include "CoreMinimal.h"
#include "World/DPZone.h"
#include "DPBedroomZone.generated.h"

class URectLightComponent;
class UPointLightComponent;
class UStaticMeshComponent;
class UTextRenderComponent;

/**
 * The player's bedroom, late at night. The computer plays the lucid dreaming tutorial; the notebook
 * receives the rules; the bed starts the dream.
 *
 * The "waking" variant is used by the death sequence: the same room, monitor off, lamp off.
 */
UCLASS()
class DREAMPROTOCOL_API ADPBedroomZone : public ADPZone
{
	GENERATED_BODY()

public:
	/** Set before BuildZone(). */
	bool bWakingVariant = false;

	virtual EDPZone GetZoneType() const override { return EDPZone::Bedroom; }
	virtual void BuildZone() override;
	virtual FTransform GetPlayerStart() const override;
	virtual void OnPlayerEntered(ADPCharacter* Player, bool bFromSave) override;

	virtual float GetFearGainMultiplier() const override { return 0.5f; }
	virtual float GetFearDecayRate() const override { return 4.f; }
	virtual float GetWalkSpeed() const override { return 200.f; }
	virtual float GetSprintSpeed() const override { return 280.f; }

	/** The notebook on the desk disappears once picked up. */
	void SetDeskNotebookVisible(bool bVisible);

private:
	void BuildRoom();
	void BuildFurniture();
	void BuildLighting();
	void BuildInteractables();

	UPROPERTY()
	TObjectPtr<UStaticMeshComponent> DeskNotebook;

	UPROPERTY()
	TObjectPtr<URectLightComponent> MonitorLight;

	UPROPERTY()
	TObjectPtr<UTextRenderComponent> ScreenText;
};
