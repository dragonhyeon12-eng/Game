#pragma once

#include "CoreMinimal.h"
#include "World/DPZone.h"
#include "DPMazeZone.generated.h"

class ADPObserver;
class UPointLightComponent;
class UStaticMeshComponent;
class UDPSynthSound;

/**
 * The first nightmare: endless yellow office corridors under fluorescent light.
 *
 * Layout is a seeded spanning-tree maze (always solvable) plus extra openings and open-plan rooms.
 * Walls that are *not* part of the spanning tree may open or close while unobserved, so the way out
 * always exists, but the way you came may not. Lights die, a chair keeps turning up, and something
 * from the summer leaks in. The exit is wherever the hum is loudest.
 */
UCLASS()
class DREAMPROTOCOL_API ADPMazeZone : public ADPZone
{
	GENERATED_BODY()

public:
	/** Set before BuildZone(). Same seed = same maze (saved in checkpoints). */
	int32 Seed = 1;

	virtual EDPZone GetZoneType() const override { return EDPZone::Maze; }
	virtual void BuildZone() override;
	virtual FTransform GetPlayerStart() const override;
	virtual void OnPlayerEntered(ADPCharacter* Player, bool bFromSave) override;
	virtual void OnDreadUpdate(float Dread, EDPDreadStage Stage, float DeltaSeconds) override;
	virtual void Tick(float DeltaSeconds) override;
	virtual void HandleObserverEvent(FName Event) override;

	virtual bool IsNightmare() const override { return true; }
	virtual float GetFearGainMultiplier() const override { return 1.f; }
	virtual float GetFearFloor() const override { return 10.f; }
	virtual float GetFearDecayRate() const override { return 1.2f; }
	virtual bool HasSoftFloor() const override { return true; }
	virtual float GetWalkSpeed() const override { return 240.f; }
	virtual float GetSprintSpeed() const override { return 400.f; }
	virtual FVector2D GetAnomalyPacing() const override { return FVector2D(35.f, 5.f); }

private:
	enum class EEdge : uint8 { Wall, Open, Extra, Dynamic };

	struct FLight
	{
		UPointLightComponent* Light = nullptr;
		UStaticMeshComponent* Panel = nullptr;
		float Base = 60.f;
		float Applied = 60.f;
		float DipTimer = 0.f;
		float DipLevel = 1.f;
		bool bDead = false;
	};

	struct FDynamicWall
	{
		USceneComponent* Group = nullptr;
		UStaticMeshComponent* Wall = nullptr;
		FVector Center = FVector::ZeroVector;
		bool bOpen = false;
	};

	void Generate();
	void BuildGeometry();
	void BuildLights();
	void BuildProps();
	void BuildExit();
	void RegisterAnomalies();

	FVector CellCenter(int32 X, int32 Y) const;
	bool InBounds(int32 X, int32 Y) const { return X >= 0 && Y >= 0 && X < Width && Y < Height; }
	/** Edge between a cell and its neighbour in direction D (0:+X 1:-X 2:+Y 3:-Y). nullptr at the boundary. */
	uint8* EdgeRef(int32 X, int32 Y, int32 Dir);
	bool IsPassable(int32 X, int32 Y, int32 Dir) const;
	FIntPoint CellAt(const FVector& Location) const;
	void SetDynamicWall(FDynamicWall& W, bool bOpen);
	void AddWallSegment(const FVector& Center, bool bAlongY, float Length, const FLinearColor& Color);

	void UpdateObserver(float DeltaSeconds, EDPDreadStage Stage, float Dread);
	bool TrySummonObserver(int32 MinCells);
	void UpdateHints(float DeltaSeconds);

	int32 Width = 12;
	int32 Height = 12;
	float Cell = 500.f;
	float WallHeight = 290.f;
	float Thickness = 24.f;

	TArray<uint8> EdgesX; // between (x,y) and (x+1,y): index x*Height + y
	TArray<uint8> EdgesY; // between (x,y) and (x,y+1): index x*(Height-1) + y
	TArray<FDynamicWall> DynamicWalls;
	TArray<FLight> Lights;

	FIntPoint ExitCell = FIntPoint(0, 0);
	int32 ExitDir = 0;
	float StartYaw = 0.f;

	UPROPERTY()
	TObjectPtr<USceneComponent> Chair;

	UPROPERTY()
	TArray<TObjectPtr<USceneComponent>> Pictures;

	UPROPERTY()
	TObjectPtr<ADPObserver> Observer;

	UPROPERTY()
	TObjectPtr<UDPSynthSound> Hum;

	float TimeInZone = 0.f;
	int32 HintStage = 0;
	float ObserverCooldown = 40.f;
	float ObserverCheckTimer = 0.f;
	float ObserverPresentTime = 0.f;
	bool bObserverSeenThisTime = false;
	int32 ObserverSightings = 0;
	bool bPictureShown = false;
};
