#pragma once

#include "CoreMinimal.h"
#include "World/DPZone.h"
#include "DPSummerCityZone.generated.h"

class ADPNPC;
class ADPObserver;
class UStaticMeshComponent;

/**
 * The first dream: a warm, bright summer city that feels like the perfect lucid dream.
 * It is deliberately comforting - fear gains are heavily damped and nothing changes behind your back.
 * The only thing out of place is a black figure at the far end of the avenue, easy to overlook.
 */
UCLASS()
class DREAMPROTOCOL_API ADPSummerCityZone : public ADPZone
{
	GENERATED_BODY()

public:
	virtual EDPZone GetZoneType() const override { return EDPZone::SummerCity; }
	virtual void BuildZone() override;
	virtual FTransform GetPlayerStart() const override;
	virtual void OnPlayerEntered(ADPCharacter* Player, bool bFromSave) override;
	virtual void Tick(float DeltaSeconds) override;
	virtual void HandleObserverEvent(FName Event) override;

	virtual bool AllowsManifestation() const override { return true; }
	virtual float GetFearGainMultiplier() const override { return 0.35f; }
	virtual float GetFearDecayRate() const override { return 5.f; }
	virtual float GetWalkSpeed() const override { return 300.f; }
	virtual float GetSprintSpeed() const override { return 540.f; }

private:
	void BuildGround();
	void BuildBuildings();
	void BuildStreets();
	void BuildPark();
	void BuildSkyline();
	void BuildLighting();
	void BuildCharacters();

	void AddTree(const FVector& Base, float Scale, int32 Variant);
	void AddBench(const FVector& Center, float Yaw);
	void AddCar(const FVector& Center, float Yaw, const FLinearColor& Color);
	void AddLamp(const FVector& Base);
	void AddCrosswalk(const FVector& Center, bool bAlongX);

	FVector FindObserverSpotNear(const FVector& PlayerLoc, float MinDist, float MaxDist) const;
	void UpdateHints(float DeltaSeconds);
	void UpdateLife(float DeltaSeconds);

	UPROPERTY()
	TObjectPtr<ADPObserver> Observer;

	UPROPERTY()
	TObjectPtr<ADPNPC> Theo;

	UPROPERTY()
	TObjectPtr<USceneComponent> Kite;

	UPROPERTY()
	TObjectPtr<UStaticMeshComponent> KiteLine;

	UPROPERTY()
	TArray<TObjectPtr<USceneComponent>> Pigeons;

	TArray<FVector> ObserverSpots;
	TArray<FVector> PigeonHome;

	float TimeInZone = 0.f;
	float PigeonFreezeTime = 0.f;
	bool bSawLotteryFlag = false;
	int32 HintStage = 0;
	float HintTimer = 0.f;
};
