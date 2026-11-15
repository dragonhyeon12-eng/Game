#include "World/DPMazeZone.h"
#include "Anomaly/DPAnomalySubsystem.h"
#include "Core/DPCharacter.h"
#include "Core/DPGameMode.h"
#include "Core/DPObservation.h"
#include "Core/DPSettings.h"
#include "Dread/DPDreadComponent.h"
#include "Notebook/DPNotebookSubsystem.h"
#include "NPC/DPObserver.h"
#include "UI/DPHUD.h"
#include "Components/AudioComponent.h"
#include "Components/PointLightComponent.h"
#include "Components/PostProcessComponent.h"
#include "Components/SkyLightComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Math/RandomStream.h"

#define LOCTEXT_NAMESPACE "DPMaze"

namespace Maze
{
	const FLinearColor WallA(0.78f, 0.68f, 0.33f);
	const FLinearColor WallB(0.74f, 0.65f, 0.3f);
	const FLinearColor Baseboard(0.45f, 0.38f, 0.2f);
	const FLinearColor Carpet(0.42f, 0.36f, 0.19f);
	const FLinearColor Ceiling(0.8f, 0.77f, 0.58f);
	const FLinearColor PanelOn(1.f, 0.98f, 0.9f);
	const FLinearColor PanelOff(0.35f, 0.34f, 0.3f);
	const FLinearColor LightColor(1.f, 0.95f, 0.78f);
	const FLinearColor ChairColor(0.12f, 0.12f, 0.14f);

	const int32 DX[4] = { 1, -1, 0, 0 };
	const int32 DY[4] = { 0, 0, 1, -1 };
}

// ---------------------------------------------------------------- Grid helpers

FVector ADPMazeZone::CellCenter(int32 X, int32 Y) const
{
	return FVector(X * Cell, Y * Cell, 0.f);
}

FIntPoint ADPMazeZone::CellAt(const FVector& L) const
{
	return FIntPoint(FMath::Clamp(FMath::RoundToInt(L.X / Cell), 0, Width - 1), FMath::Clamp(FMath::RoundToInt(L.Y / Cell), 0, Height - 1));
}

uint8* ADPMazeZone::EdgeRef(int32 X, int32 Y, int32 Dir)
{
	const int32 NX = X + Maze::DX[Dir];
	const int32 NY = Y + Maze::DY[Dir];
	if (!InBounds(X, Y) || !InBounds(NX, NY))
	{
		return nullptr;
	}
	if (Dir <= 1)
	{
		const int32 MinX = FMath::Min(X, NX);
		return &EdgesX[MinX * Height + Y];
	}
	const int32 MinY = FMath::Min(Y, NY);
	return &EdgesY[X * (Height - 1) + MinY];
}

bool ADPMazeZone::IsPassable(int32 X, int32 Y, int32 Dir) const
{
	const uint8* E = const_cast<ADPMazeZone*>(this)->EdgeRef(X, Y, Dir);
	if (!E)
	{
		return false;
	}
	const EEdge Type = static_cast<EEdge>(*E);
	if (Type == EEdge::Open || Type == EEdge::Extra)
	{
		return true;
	}
	if (Type == EEdge::Dynamic)
	{
		// look up current state
		const FVector A = CellCenter(X, Y);
		const FVector B = CellCenter(X + Maze::DX[Dir], Y + Maze::DY[Dir]);
		const FVector Mid = (A + B) * 0.5f;
		for (const FDynamicWall& W : DynamicWalls)
		{
			if (FVector::Dist2D(W.Center, Mid) < 1.f)
			{
				return W.bOpen;
			}
		}
	}
	return false;
}

// ---------------------------------------------------------------- Build

void ADPMazeZone::BuildZone()
{
	Generate();
	BuildGeometry();
	BuildLights();
	BuildProps();
	BuildExit();
	RegisterAnomalies();

	UDPSynthSound* HumSound = nullptr;
	AddSynth(EDPSynthVoice::FluorescentHum, FVector(0, 0, 200), false, 0.35f, 0.f, &HumSound);
	Hum = HumSound;

	Observer = SpawnOwned<ADPObserver>(FTransform(FVector(0, 0, -10000)));
	if (Observer)
	{
		Observer->HideNow();
		Observer->SeenThreshold = 0.35f;
		Observer->SeenMaxDistance = 4000.f;
		TWeakObjectPtr<ADPMazeZone> WeakThis(this);
		Observer->OnSeen = [WeakThis](ADPObserver*)
		{
			if (!WeakThis.IsValid() || WeakThis->bObserverSeenThisTime)
			{
				return;
			}
			WeakThis->bObserverSeenThisTime = true;
			++WeakThis->ObserverSightings;
			if (ADPCharacter* P = WeakThis->GetPlayer())
			{
				P->GetDread()->AddFear(WeakThis->ObserverSightings == 1 ? 12.f : 7.f, TEXT("ObserverSeen"));
				P->GetDread()->NotifySuspiciousEvent();
			}
			if (ADPGameMode* GM = WeakThis->GetGameMode())
			{
				GM->SetFlag(TEXT("observer_seen_maze"));
			}
		};
	}
}

void ADPMazeZone::Generate()
{
	FRandomStream Rng(Seed);
	EdgesX.Init(static_cast<uint8>(EEdge::Wall), (Width - 1) * Height);
	EdgesY.Init(static_cast<uint8>(EEdge::Wall), Width * (Height - 1));

	// Randomised depth-first spanning tree => every cell reachable through Open edges, forever.
	TArray<bool> Visited;
	Visited.Init(false, Width * Height);
	TArray<FIntPoint> Stack;
	Stack.Push(FIntPoint(0, 0));
	Visited[0] = true;
	while (Stack.Num() > 0)
	{
		const FIntPoint C = Stack.Last();
		TArray<int32, TInlineAllocator<4>> Dirs;
		for (int32 D = 0; D < 4; ++D)
		{
			const int32 NX = C.X + Maze::DX[D], NY = C.Y + Maze::DY[D];
			if (InBounds(NX, NY) && !Visited[NX * Height + NY])
			{
				Dirs.Add(D);
			}
		}
		if (Dirs.Num() == 0)
		{
			Stack.Pop();
			continue;
		}
		const int32 D = Dirs[Rng.RandRange(0, Dirs.Num() - 1)];
		*EdgeRef(C.X, C.Y, D) = static_cast<uint8>(EEdge::Open);
		const FIntPoint N(C.X + Maze::DX[D], C.Y + Maze::DY[D]);
		Visited[N.X * Height + N.Y] = true;
		Stack.Push(N);
	}

	// Non-tree walls: some removed for loops, some made "dynamic" (may change while unobserved).
	auto Decorate = [&Rng](TArray<uint8>& Edges)
	{
		for (uint8& E : Edges)
		{
			if (E != static_cast<uint8>(EEdge::Wall))
			{
				continue;
			}
			const float R = Rng.FRand();
			if (R < 0.12f)
			{
				E = static_cast<uint8>(EEdge::Extra);
			}
			else if (R < 0.27f)
			{
				E = static_cast<uint8>(EEdge::Dynamic);
			}
		}
	};
	Decorate(EdgesX);
	Decorate(EdgesY);

	// A few open-plan "office" rooms (2x2).
	for (int32 r = 0; r < 3; ++r)
	{
		const int32 RX = Rng.RandRange(1, Width - 3);
		const int32 RY = Rng.RandRange(1, Height - 3);
		auto OpenEdge = [](uint8* E) { if (E && *E != static_cast<uint8>(EEdge::Open)) { *E = static_cast<uint8>(EEdge::Extra); } };
		OpenEdge(EdgeRef(RX, RY, 0));
		OpenEdge(EdgeRef(RX, RY + 1, 0));
		OpenEdge(EdgeRef(RX, RY, 2));
		OpenEdge(EdgeRef(RX + 1, RY, 2));
	}

	// Exit: the boundary cell farthest from the start (BFS over permanent openings).
	TArray<int32> Dist;
	Dist.Init(-1, Width * Height);
	TArray<FIntPoint> Queue;
	Queue.Add(FIntPoint(0, 0));
	Dist[0] = 0;
	for (int32 Head = 0; Head < Queue.Num(); ++Head)
	{
		const FIntPoint C = Queue[Head];
		for (int32 D = 0; D < 4; ++D)
		{
			uint8* E = EdgeRef(C.X, C.Y, D);
			if (!E || (*E != static_cast<uint8>(EEdge::Open) && *E != static_cast<uint8>(EEdge::Extra)))
			{
				continue;
			}
			const FIntPoint N(C.X + Maze::DX[D], C.Y + Maze::DY[D]);
			if (Dist[N.X * Height + N.Y] < 0)
			{
				Dist[N.X * Height + N.Y] = Dist[C.X * Height + C.Y] + 1;
				Queue.Add(N);
			}
		}
	}
	int32 Best = -1;
	for (int32 X = 0; X < Width; ++X)
	{
		for (int32 Y = 0; Y < Height; ++Y)
		{
			const bool bBoundary = X == Width - 1 || Y == Height - 1;
			if (bBoundary && Dist[X * Height + Y] > Best)
			{
				Best = Dist[X * Height + Y];
				ExitCell = FIntPoint(X, Y);
			}
		}
	}
	ExitDir = (ExitCell.X == Width - 1) ? 0 : 2;

	// Face the start toward an open corridor.
	for (int32 D = 0; D < 4; ++D)
	{
		uint8* E = EdgeRef(0, 0, D);
		if (E && *E == static_cast<uint8>(EEdge::Open))
		{
			StartYaw = D == 0 ? 0.f : D == 1 ? 180.f : D == 2 ? 90.f : -90.f;
			break;
		}
	}
}

void ADPMazeZone::AddWallSegment(const FVector& Center, bool bAlongY, float Length, const FLinearColor& Color)
{
	const FVector Size = bAlongY ? FVector(Thickness, Length, WallHeight) : FVector(Length, Thickness, WallHeight);
	AddBox(Center + FVector(0, 0, WallHeight * 0.5f), Size, Color);
	const FVector Base = bAlongY ? FVector(Thickness + 3.f, Length, 12.f) : FVector(Length, Thickness + 3.f, 12.f);
	AddBox(Center + FVector(0, 0, 6.f), Base, Maze::Baseboard, false);
}

void ADPMazeZone::BuildGeometry()
{
	const FVector Mid((Width - 1) * Cell * 0.5f, (Height - 1) * Cell * 0.5f, 0.f);
	const FVector Extent(Width * Cell + 200.f, Height * Cell + 200.f, 10.f);
	AddBox(Mid + FVector(0, 0, -5), Extent, Maze::Carpet);
	AddBox(Mid + FVector(0, 0, WallHeight + 5.f), Extent, Maze::Ceiling);
	// ceiling grid strips
	for (int32 X = 0; X <= Width; ++X)
	{
		AddBox(FVector((X - 0.5f) * Cell, Mid.Y, WallHeight - 0.5f), FVector(4, Height * Cell, 1), Maze::Ceiling * 0.8f, false);
	}
	for (int32 Y = 0; Y <= Height; ++Y)
	{
		AddBox(FVector(Mid.X, (Y - 0.5f) * Cell, WallHeight - 0.5f), FVector(Width * Cell, 4, 1), Maze::Ceiling * 0.8f, false);
	}

	FRandomStream Rng(Seed + 7);
	const float Len = Cell + Thickness;

	// Interior walls
	for (int32 X = 0; X < Width; ++X)
	{
		for (int32 Y = 0; Y < Height; ++Y)
		{
			for (int32 D : { 0, 2 })
			{
				uint8* E = EdgeRef(X, Y, D);
				if (!E)
				{
					continue;
				}
				const EEdge Type = static_cast<EEdge>(*E);
				const FVector Center = (CellCenter(X, Y) + CellCenter(X + Maze::DX[D], Y + Maze::DY[D])) * 0.5f;
				const bool bAlongY = (D == 0);
				const FLinearColor Col = Rng.FRand() < 0.3f ? Maze::WallB : Maze::WallA;

				if (Type == EEdge::Wall)
				{
					AddWallSegment(Center, bAlongY, Len, Col);
				}
				else if (Type == EEdge::Dynamic)
				{
					FDynamicWall W;
					W.Center = Center;
					W.Group = AddGroup(Center);
					const FVector Size = bAlongY ? FVector(Thickness, Len, WallHeight) : FVector(Len, Thickness, WallHeight);
					W.Wall = AddPartBox(FVector(0, 0, WallHeight * 0.5f), Size, Col, true, W.Group);
					const FVector Base = bAlongY ? FVector(Thickness + 3.f, Len, 12.f) : FVector(Len, Thickness + 3.f, 12.f);
					AddPartBox(FVector(0, 0, 6.f), Base, Maze::Baseboard, false, W.Group);
					DynamicWalls.Add(W);
					SetDynamicWall(DynamicWalls.Last(), Rng.FRand() < 0.5f);
				}
			}
		}
	}

	// Boundary (the exit segment is built by BuildExit)
	for (int32 X = 0; X < Width; ++X)
	{
		AddWallSegment(FVector(X * Cell, -0.5f * Cell, 0), false, Len, Maze::WallA);
		if (!(ExitDir == 2 && ExitCell.X == X))
		{
			AddWallSegment(FVector(X * Cell, (Height - 0.5f) * Cell, 0), false, Len, Maze::WallA);
		}
	}
	for (int32 Y = 0; Y < Height; ++Y)
	{
		AddWallSegment(FVector(-0.5f * Cell, Y * Cell, 0), true, Len, Maze::WallA);
		if (!(ExitDir == 0 && ExitCell.Y == Y))
		{
			AddWallSegment(FVector((Width - 0.5f) * Cell, Y * Cell, 0), true, Len, Maze::WallA);
		}
	}

	// Flat, dim fill light - the space never has real shadows of its own.
	USkyLightComponent* Fill = NewObject<USkyLightComponent>(this);
	Fill->SetupAttachment(Root);
	Fill->SetMobility(EComponentMobility::Movable);
	Fill->bRealTimeCapture = true;
	Fill->SourceType = ESkyLightSourceType::SLS_CapturedScene;
	Fill->SetIntensity(0.2f);
	Fill->RegisterComponent();
	AddInstanceComponent(Fill);

	UPostProcessComponent* PPC = NewObject<UPostProcessComponent>(this);
	PPC->SetupAttachment(Root);
	PPC->bUnbound = true;
	FPostProcessSettings& S = PPC->Settings;
	S.bOverride_WhiteTemp = true;         S.WhiteTemp = 5200.f;
	S.bOverride_WhiteTint = true;         S.WhiteTint = -0.08f;
	S.bOverride_ColorSaturation = true;   S.ColorSaturation = FVector4(1.05f, 1.02f, 0.85f, 1.f);
	S.bOverride_BloomIntensity = true;    S.BloomIntensity = 1.1f;
	S.bOverride_AutoExposureBias = true;  S.AutoExposureBias = 0.2f;
	PPC->RegisterComponent();
	AddInstanceComponent(PPC);
}

void ADPMazeZone::SetDynamicWall(FDynamicWall& W, bool bOpen)
{
	W.bOpen = bOpen;
	if (W.Group)
	{
		W.Group->SetVisibility(!bOpen, true);
	}
	if (W.Wall)
	{
		W.Wall->SetCollisionEnabled(bOpen ? ECollisionEnabled::NoCollision : ECollisionEnabled::QueryAndPhysics);
	}
}

void ADPMazeZone::BuildLights()
{
	for (int32 X = 0; X < Width; X += 2)
	{
		for (int32 Y = 0; Y < Height; Y += 2)
		{
			const FVector C = CellCenter(X, Y);
			FLight L;
			L.Panel = AddPartBox(C + FVector(0, 0, WallHeight - 2.f), FVector(120, 60, 3), Maze::PanelOn, false);
			L.Light = AddPointLight(C + FVector(0, 0, WallHeight - 28.f), Maze::LightColor, 55.f, 760.f, true, 30.f);
			L.Base = L.Applied = 55.f;
			Lights.Add(L);
		}
	}
}

void ADPMazeZone::BuildProps()
{
	// The office chair. You will see it again.
	Chair = AddGroup(CellCenter(0, 0) + FVector(150.f, 140.f, 0.f), FRotator(0.f, 200.f, 0.f));
	AddPartBox(FVector(0, 0, 48), FVector(48, 48, 7), Maze::ChairColor, true, Chair);
	AddPartBox(FVector(-22, 0, 82), FVector(6, 44, 55), Maze::ChairColor, false, Chair);
	AddPart(EDPShape::Cylinder, FTransform(FRotator::ZeroRotator, FVector(0, 0, 25), FVector(0.05f, 0.05f, 0.42f)), Maze::ChairColor, false, Chair);
	AddPart(EDPShape::Cylinder, FTransform(FRotator::ZeroRotator, FVector(0, 0, 4), FVector(0.55f, 0.55f, 0.05f)), Maze::ChairColor, false, Chair);

	FRandomStream Rng(Seed + 99);
	// Water coolers and abandoned desks scattered around.
	for (int32 i = 0; i < 6; ++i)
	{
		const FIntPoint C(Rng.RandRange(1, Width - 1), Rng.RandRange(1, Height - 1));
		if (C == ExitCell)
		{
			continue;
		}
		const FVector P = CellCenter(C.X, C.Y) + FVector(Rng.FRandRange(-150.f, 150.f), Rng.FRandRange(-150.f, 150.f), 0.f);
		if (i % 2 == 0)
		{
			AddBox(P + FVector(0, 0, 50), FVector(32, 32, 100), FLinearColor(0.85f, 0.85f, 0.82f));
			AddInstanced(EDPShape::Cylinder, FTransform(FRotator::ZeroRotator, P + FVector(0, 0, 125), FVector(0.28f, 0.28f, 0.48f)), FLinearColor(0.5f, 0.7f, 0.85f), false);
		}
		else
		{
			AddBox(P + FVector(0, 0, 73), FVector(140, 70, 4), FLinearColor(0.55f, 0.5f, 0.42f));
			AddBox(P + FVector(-60, 0, 36), FVector(4, 66, 72), FLinearColor(0.4f, 0.38f, 0.33f), false);
			AddBox(P + FVector(60, 0, 36), FVector(4, 66, 72), FLinearColor(0.4f, 0.38f, 0.33f), false);
		}
	}

	// Pictures of a summer street that should not be here. Hidden until the dream leaks.
	for (int32 i = 0; i < 3; ++i)
	{
		const int32 Y = Rng.RandRange(2, Height - 2);
		const FVector WallFace(-0.5f * Cell + Thickness * 0.5f + 1.5f, Y * Cell, 150.f);
		USceneComponent* Pic = AddGroup(WallFace);
		AddPartBox(FVector(0, 0, 0), FVector(2, 70, 52), FLinearColor(0.2f, 0.14f, 0.08f), false, Pic);
		AddPartBox(FVector(1.5f, 0, 8), FVector(1, 62, 28), FLinearColor(0.45f, 0.7f, 0.95f), false, Pic);  // sky
		AddPartBox(FVector(1.5f, 0, -12), FVector(1, 62, 16), FLinearColor(0.85f, 0.62f, 0.45f), false, Pic); // street
		AddPart(EDPShape::Sphere, FTransform(FRotator::ZeroRotator, FVector(2.f, 18.f, 15.f), FVector(0.08f)), FLinearColor(1.f, 0.85f, 0.3f), false, Pic); // sun
		AddPartBox(FVector(2.f, -16.f, -8.f), FVector(1, 3, 10), FLinearColor(0.f, 0.f, 0.f), false, Pic); // a small black figure
		Pic->SetVisibility(false, true);
		Pictures.Add(Pic);
	}
}

void ADPMazeZone::BuildExit()
{
	const bool bAlongY = ExitDir == 0;
	const FVector Center = ExitDir == 0
		? FVector((Width - 0.5f) * Cell, ExitCell.Y * Cell, 0.f)
		: FVector(ExitCell.X * Cell, (Height - 0.5f) * Cell, 0.f);
	const FVector Inward = ExitDir == 0 ? FVector(-1, 0, 0) : FVector(0, -1, 0);
	const FVector Along = bAlongY ? FVector(0, 1, 0) : FVector(1, 0, 0);

	const float Len = Cell + Thickness;
	const float DoorHalf = 60.f;
	const float SideLen = Len * 0.5f - DoorHalf;
	AddWallSegment(Center + Along * (DoorHalf + SideLen * 0.5f), bAlongY, SideLen, Maze::WallA);
	AddWallSegment(Center - Along * (DoorHalf + SideLen * 0.5f), bAlongY, SideLen, Maze::WallA);
	const float LintelH = WallHeight - 220.f;
	const FVector LintelSize = bAlongY ? FVector(Thickness, DoorHalf * 2.f, LintelH) : FVector(DoorHalf * 2.f, Thickness, LintelH);
	AddBox(Center + FVector(0, 0, 220.f + LintelH * 0.5f), LintelSize, Maze::WallA);

	// The door itself, set back into the frame.
	const FVector DoorSize = bAlongY ? FVector(8, DoorHalf * 2.f - 4.f, 218.f) : FVector(DoorHalf * 2.f - 4.f, 8, 218.f);
	AddBox(Center - Inward * 6.f + FVector(0, 0, 109.f), DoorSize, FLinearColor(0.5f, 0.38f, 0.25f));
	AddInstanced(EDPShape::Sphere, FTransform(FRotator::ZeroRotator, Center + Inward * 2.f + Along * 40.f + FVector(0, 0, 100.f), FVector(0.06f)),
		FLinearColor(0.75f, 0.7f, 0.5f), false);

	// EXIT sign above it
	const FVector SignPos = Center + Inward * (Thickness * 0.5f + 4.f) + FVector(0, 0, 250.f);
	const FVector SignSize = bAlongY ? FVector(6, 64, 24) : FVector(64, 6, 24);
	AddBox(SignPos, SignSize, FLinearColor(0.5f, 0.04f, 0.03f), false);
	AddText(SignPos + Inward * 3.5f, Inward.Rotation(), LOCTEXT("Exit", "EXIT"), 18.f, FColor(255, 235, 225));
	AddPointLight(SignPos + Inward * 30.f, FLinearColor(1.f, 0.2f, 0.15f), 6.f, 300.f, false);

	// The loudest hum in the building.
	AddSynth(EDPSynthVoice::FluorescentHum, Center + Inward * 40.f + FVector(0, 0, 200.f), true, 1.4f, 3800.f);

	TWeakObjectPtr<ADPMazeZone> WeakThis(this);
	AddInteractable(Center - Inward * 2.f + FVector(0, 0, 110.f), bAlongY ? FVector(16, 58, 105) : FVector(58, 16, 105),
		[]() { return LOCTEXT("Open", "Open the door"); },
		[WeakThis](ADPCharacter*)
		{
			if (WeakThis.IsValid())
			{
				if (ADPGameMode* GM = WeakThis->GetGameMode())
				{
					GM->OnMazeExitReached();
				}
			}
		});
}

FTransform ADPMazeZone::GetPlayerStart() const
{
	return FTransform(FRotator(0.f, StartYaw, 0.f), CellCenter(0, 0) + FVector(0, 0, 92.f));
}

// ---------------------------------------------------------------- Anomalies

void ADPMazeZone::RegisterAnomalies()
{
	UDPAnomalySubsystem* Anomalies = GetWorld()->GetSubsystem<UDPAnomalySubsystem>();
	if (!Anomalies)
	{
		return;
	}
	TWeakObjectPtr<ADPMazeZone> WeakThis(this);

	// Walls that come and go. Never part of the spanning tree, so the maze stays solvable.
	for (int32 i = 0; i < DynamicWalls.Num(); ++i)
	{
		FDPAnomaly A;
		A.Id = *FString::Printf(TEXT("wall_%d"), i);
		A.Location = DynamicWalls[i].Center + FVector(0, 0, WallHeight * 0.5f);
		A.Radius = 260.f;
		A.MinUnobservedSeconds = 2.5f;
		A.DiscoveryFear = 3.f;
		A.Owner = this;
		A.Apply = [WeakThis, i]()
		{
			if (WeakThis.IsValid() && WeakThis->DynamicWalls.IsValidIndex(i))
			{
				FDynamicWall& W = WeakThis->DynamicWalls[i];
				WeakThis->SetDynamicWall(W, !W.bOpen);
			}
		};
		Anomalies->Register(MoveTemp(A));
	}

	// Lights that die (and sometimes come back).
	for (int32 i = 0; i < Lights.Num(); ++i)
	{
		if (i % 3 != 1)
		{
			continue;
		}
		FDPAnomaly A;
		A.Id = *FString::Printf(TEXT("light_%d"), i);
		A.Location = Lights[i].Light->GetComponentLocation();
		A.Radius = 120.f;
		A.MinStage = EDPDreadStage::Uneasy;
		A.Weight = 0.6f;
		A.DiscoveryFear = 2.f;
		A.Owner = this;
		A.Apply = [WeakThis, i]()
		{
			if (WeakThis.IsValid() && WeakThis->Lights.IsValidIndex(i))
			{
				FLight& L = WeakThis->Lights[i];
				L.bDead = !L.bDead;
				L.Panel->SetMaterial(0, WeakThis->Mat(L.bDead ? Maze::PanelOff : Maze::PanelOn));
			}
		};
		Anomalies->Register(MoveTemp(A));
	}

	// The chair moves to another room.
	{
		FDPAnomaly A;
		A.Id = TEXT("chair");
		A.Radius = 90.f;
		A.Weight = 1.2f;
		A.DiscoveryFear = 4.f;
		A.MaxPlayerDistance = 6000.f;
		A.Owner = this;
		A.GetLocation = [WeakThis]() { return WeakThis.IsValid() ? WeakThis->Chair->GetComponentLocation() + FVector(0, 0, 50) : FVector::ZeroVector; };
		A.Apply = [WeakThis]()
		{
			if (!WeakThis.IsValid())
			{
				return;
			}
			ADPMazeZone* Z = WeakThis.Get();
			for (int32 Try = 0; Try < 12; ++Try)
			{
				const FIntPoint C(FMath::RandRange(0, Z->Width - 1), FMath::RandRange(0, Z->Height - 1));
				const FVector P = Z->CellCenter(C.X, C.Y) + FVector(FMath::FRandRange(-140.f, 140.f), FMath::FRandRange(-140.f, 140.f), 0.f);
				if (!DPObservation::IsObserved(Z->GetWorld(), P + FVector(0, 0, 50), 90.f))
				{
					Z->Chair->SetRelativeLocationAndRotation(P, FRotator(0.f, FMath::FRandRange(0.f, 360.f), 0.f));
					break;
				}
			}
		};
		Anomalies->Register(MoveTemp(A));
	}

	// Something from the summer leaks in (once).
	for (int32 i = 0; i < Pictures.Num(); ++i)
	{
		FDPAnomaly A;
		A.Id = *FString::Printf(TEXT("picture_%d"), i);
		A.Location = Pictures[i]->GetComponentLocation();
		A.Radius = 60.f;
		A.MinStage = EDPDreadStage::Uneasy;
		A.MaxChanges = 1;
		A.Weight = 0.8f;
		A.DiscoveryFear = 6.f;
		A.Owner = this;
		A.CanApply = [WeakThis]() { return WeakThis.IsValid() && !WeakThis->bPictureShown; };
		A.Apply = [WeakThis, i]()
		{
			if (WeakThis.IsValid())
			{
				WeakThis->bPictureShown = true;
				WeakThis->Pictures[i]->SetVisibility(true, true);
			}
		};
		Anomalies->Register(MoveTemp(A));
	}
}

// ---------------------------------------------------------------- Runtime

void ADPMazeZone::OnPlayerEntered(ADPCharacter* Player, bool bFromSave)
{
	TimeInZone = 0.f;
	HintStage = bFromSave ? 2 : 0;
	if (UDPAnomalySubsystem* Anomalies = GetWorld()->GetSubsystem<UDPAnomalySubsystem>())
	{
		const FVector2D Pacing = GetAnomalyPacing();
		Anomalies->SetPacing(Pacing.X, Pacing.Y);
	}
}

void ADPMazeZone::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);
	TimeInZone += DeltaSeconds;
	UpdateHints(DeltaSeconds);
}

void ADPMazeZone::UpdateHints(float DeltaSeconds)
{
	ADPGameMode* GM = GetGameMode();
	ADPHUD* HUD = GM ? GM->GetDPHUD() : nullptr;
	if (!GM || !HUD || GM->IsInSequence())
	{
		return;
	}

	if (HintStage == 0 && TimeInZone > 2.5f)
	{
		HUD->ShowThought(LOCTEXT("NotRoom", "...This isn't my room."), 4.f);
		HintStage = 1;
	}
	else if (HintStage == 1 && TimeInZone > 10.f)
	{
		HUD->ShowHint(LOCTEXT("Notebook", "Your notebook is still in your pocket.\nN: read"), 7.f);
		HintStage = 2;
	}
	else if (HintStage == 2 && TimeInZone > 150.f && !GM->HasFlag(TEXT("maze_hint_written")))
	{
		// Somebody writes in your notebook. You only hear the page.
		GM->SetFlag(TEXT("maze_hint_written"));
		if (UDPNotebookSubsystem* Notebook = GetWorld()->GetSubsystem<UDPNotebookSubsystem>())
		{
			Notebook->RevealOnNextOpen(TEXT("maze_hint"));
		}
		if (ADPCharacter* P = GetPlayer())
		{
			P->PlayFoley(EDPSynthEvent::Page, 1.f);
		}
		HintStage = 3;
	}
}

void ADPMazeZone::OnDreadUpdate(float Dread, EDPDreadStage Stage, float DeltaSeconds)
{
	const float D = Dread / 100.f;
	const float V = FMath::Clamp(DPSettings::Get(this).VisualIntensity, 0.f, 1.f);
	ADPCharacter* Player = GetPlayer();
	const FVector PlayerLoc = Player ? Player->GetActorLocation() : FVector::ZeroVector;

	// Fluorescent flicker, stronger as the dream destabilises. Scaled by visual intensity (photosensitivity).
	for (FLight& L : Lights)
	{
		if (!L.Light)
		{
			continue;
		}
		float Target = 0.f;
		if (!L.bDead)
		{
			Target = L.Base * (1.f - 0.3f * D * V);
			if (FVector::DistSquared(L.Light->GetComponentLocation(), PlayerLoc) < FMath::Square(2600.f))
			{
				L.DipTimer -= DeltaSeconds;
				if (L.DipTimer <= 0.f)
				{
					const float ChancePerSecond = (0.01f + 0.5f * D * D) * V;
					if (FMath::FRand() < ChancePerSecond * DeltaSeconds)
					{
						L.DipTimer = FMath::FRandRange(0.04f, 0.25f);
						L.DipLevel = FMath::FRandRange(0.05f, 0.6f);
					}
				}
				if (L.DipTimer > 0.f)
				{
					Target *= FMath::Lerp(1.f, L.DipLevel, V);
				}
			}
		}
		if (FMath::Abs(Target - L.Applied) > L.Base * 0.02f)
		{
			L.Applied = Target;
			L.Light->SetIntensity(Target);
		}
	}

	if (Hum)
	{
		Hum->SetIntensity((0.8f + 0.7f * D) * FMath::Lerp(0.6f, 1.f, DPSettings::Get(this).AudioIntensity));
	}

	UpdateObserver(DeltaSeconds, Stage, D);
}

bool ADPMazeZone::TrySummonObserver(int32 MinCells)
{
	ADPCharacter* Player = GetPlayer();
	if (!Player || !Observer)
	{
		return false;
	}
	const FIntPoint Start = CellAt(Player->GetActorLocation());

	// Look down straight corridors from the player's cell: he stands at the far end of one.
	TArray<FIntPoint> Candidates;
	for (int32 D = 0; D < 4; ++D)
	{
		FIntPoint C = Start;
		for (int32 Step = 1; Step <= 7; ++Step)
		{
			if (!IsPassable(C.X, C.Y, D))
			{
				break;
			}
			C = FIntPoint(C.X + Maze::DX[D], C.Y + Maze::DY[D]);
			if (Step >= MinCells)
			{
				Candidates.Add(C);
			}
		}
	}

	TArray<const AActor*> Ignore;
	Ignore.Add(Observer);
	while (Candidates.Num() > 0)
	{
		const int32 Index = FMath::RandRange(0, Candidates.Num() - 1);
		const FIntPoint C = Candidates[Index];
		Candidates.RemoveAtSwap(Index);
		const FVector Ground = CellCenter(C.X, C.Y);
		if (!DPObservation::IsObserved(GetWorld(), Ground + FVector(0, 0, 95), 60.f, Ignore) && Observer->TryAppearAt(Ground))
		{
			bObserverSeenThisTime = false;
			ObserverPresentTime = 0.f;
			return true;
		}
	}
	return false;
}

void ADPMazeZone::UpdateObserver(float DeltaSeconds, EDPDreadStage Stage, float D)
{
	if (!Observer)
	{
		return;
	}
	ADPGameMode* GM = GetGameMode();
	if (GM && GM->IsInSequence())
	{
		return;
	}

	if (Observer->IsPresent())
	{
		ObserverPresentTime += DeltaSeconds;
		// Once seen, he is gone the moment you look away. If never seen, he leaves eventually.
		if ((bObserverSeenThisTime && Observer->GetUnobservedTime() > 0.4f) || (ObserverPresentTime > 18.f && !Observer->IsObservedNow()))
		{
			Observer->HideNow();
			ObserverCooldown = FMath::Lerp(90.f, 30.f, D) * FMath::FRandRange(0.8f, 1.2f);
		}
		return;
	}

	ObserverCooldown -= DeltaSeconds;
	ObserverCheckTimer += DeltaSeconds;
	if (ObserverCooldown > 0.f || ObserverCheckTimer < 1.f || Stage == EDPDreadStage::Calm)
	{
		return;
	}
	ObserverCheckTimer = 0.f;

	const float Chance = Stage == EDPDreadStage::Uneasy ? 0.04f : Stage == EDPDreadStage::Afraid ? 0.1f : 0.2f;
	if (FMath::FRand() < Chance)
	{
		TrySummonObserver(3);
	}
}

void ADPMazeZone::HandleObserverEvent(FName Event)
{
	if (Event == TEXT("closer"))
	{
		// Breaking the rules brings him sooner, and nearer.
		ObserverCooldown = FMath::Min(ObserverCooldown, 4.f);
		if (Observer && !Observer->IsPresent())
		{
			TrySummonObserver(2);
		}
	}
}

#undef LOCTEXT_NAMESPACE
