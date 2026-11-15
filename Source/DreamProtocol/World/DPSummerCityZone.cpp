#include "World/DPSummerCityZone.h"
#include "Core/DPCharacter.h"
#include "Core/DPGameMode.h"
#include "Core/DPObservation.h"
#include "Dread/DPDreadComponent.h"
#include "NPC/DPNPC.h"
#include "NPC/DPObserver.h"
#include "UI/DPHUD.h"
#include "Components/DirectionalLightComponent.h"
#include "Components/ExponentialHeightFogComponent.h"
#include "Components/PostProcessComponent.h"
#include "Components/SkyAtmosphereComponent.h"
#include "Components/SkyLightComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Components/VolumetricCloudComponent.h"
#include "Math/RandomStream.h"

#define LOCTEXT_NAMESPACE "DPCity"

/*
 * City grid: 5x5 blocks. Block pitch 4200cm = 3200 block (incl. 350 sidewalk) + 1000 street.
 * Block (0,0) is the park. The player starts at its west entrance.
 */
namespace City
{
	constexpr float Pitch = 4200.f;
	constexpr float Block = 3200.f;
	constexpr float Sidewalk = 350.f;
	constexpr float Curb = 15.f;
	constexpr int32 Half = 2;
	constexpr float GrassZ = 17.f;
	constexpr float Bounds = 10900.f;

	const FLinearColor Asphalt(0.09f, 0.095f, 0.105f);
	const FLinearColor Pavement(0.62f, 0.6f, 0.56f);
	const FLinearColor Grass(0.22f, 0.45f, 0.12f);
	const FLinearColor Path(0.72f, 0.66f, 0.55f);
	const FLinearColor Glass(0.22f, 0.34f, 0.45f);
	const FLinearColor Trim(0.9f, 0.88f, 0.84f);
	const FLinearColor Bark(0.28f, 0.18f, 0.11f);
	const FLinearColor Stone(0.7f, 0.68f, 0.64f);
	const FLinearColor Water(0.12f, 0.38f, 0.55f);
	const FLinearColor Metal(0.18f, 0.2f, 0.22f);

	const FLinearColor Facades[] =
	{
		FLinearColor(0.85f, 0.6f, 0.45f),
		FLinearColor(0.92f, 0.85f, 0.68f),
		FLinearColor(0.55f, 0.7f, 0.78f),
		FLinearColor(0.85f, 0.56f, 0.55f),
		FLinearColor(0.64f, 0.78f, 0.6f),
		FLinearColor(0.95f, 0.76f, 0.5f),
		FLinearColor(0.74f, 0.7f, 0.86f),
		FLinearColor(0.9f, 0.9f, 0.87f),
	};
	constexpr int32 NumFacades = UE_ARRAY_COUNT(Facades);

	const FLinearColor Leaves[] =
	{
		FLinearColor(0.2f, 0.45f, 0.12f),
		FLinearColor(0.28f, 0.52f, 0.14f),
		FLinearColor(0.16f, 0.38f, 0.1f),
	};
}

void ADPSummerCityZone::BuildZone()
{
	BuildGround();
	BuildBuildings();
	BuildStreets();
	BuildPark();
	BuildSkyline();
	BuildLighting();
	BuildCharacters();

	AddSynth(EDPSynthVoice::CityAmbience, FVector(0, 0, 200), false, 1.f, 0.f);
	AddSynth(EDPSynthVoice::Water, FVector(0, 0, 80), true, 1.2f, 2200.f);

	// Invisible edges of the dream.
	using namespace City;
	AddBlocker(FVector(Bounds, 0, 1000), FVector(50, Bounds, 2000));
	AddBlocker(FVector(-Bounds, 0, 1000), FVector(50, Bounds, 2000));
	AddBlocker(FVector(0, Bounds, 1000), FVector(Bounds, 50, 2000));
	AddBlocker(FVector(0, -Bounds, 1000), FVector(Bounds, 50, 2000));
}

FTransform ADPSummerCityZone::GetPlayerStart() const
{
	return FTransform(FRotator(0.f, 0.f, 0.f), FVector(-1350.f, 0.f, City::GrassZ + 95.f));
}

// ---------------------------------------------------------------- Ground & buildings

void ADPSummerCityZone::BuildGround()
{
	using namespace City;
	AddBox(FVector(0, 0, -25), FVector(80000, 80000, 50), Asphalt);

	for (int32 i = -Half; i <= Half; ++i)
	{
		for (int32 j = -Half; j <= Half; ++j)
		{
			AddBox(FVector(i * Pitch, j * Pitch, Curb * 0.5f), FVector(Block, Block, Curb), Pavement);
		}
	}

	// Lane markings on the streets around the park.
	for (int32 k = -Half; k < Half; ++k)
	{
		const float Mid = (k + 0.5f) * Pitch;
		for (float t = -9000.f; t <= 9000.f; t += 600.f)
		{
			AddBox(FVector(t, Mid, 0.5f), FVector(300, 14, 1), FLinearColor(0.85f, 0.75f, 0.3f), false);
			AddBox(FVector(Mid, t, 0.5f), FVector(14, 300, 1), FLinearColor(0.85f, 0.75f, 0.3f), false);
		}
	}
}

void ADPSummerCityZone::BuildBuildings()
{
	using namespace City;
	FRandomStream Rng(1987);
	const float Lot = Block - 2.f * Sidewalk;

	for (int32 i = -Half; i <= Half; ++i)
	{
		for (int32 j = -Half; j <= Half; ++j)
		{
			if (i == 0 && j == 0)
			{
				continue; // park
			}
			const FVector C(i * Pitch, j * Pitch, Curb);
			const bool bNearPark = FMath::Abs(i) <= 1 && FMath::Abs(j) <= 1;
			const int32 Layout = Rng.RandRange(0, 2);
			const int32 Splits = Layout == 0 ? 1 : 2;
			const int32 SplitsY = Layout == 2 ? 2 : 1;
			const float Gap = 60.f;
			const float W = (Lot - Gap * (Splits - 1)) / Splits;
			const float D = (Lot - Gap * (SplitsY - 1)) / SplitsY;

			for (int32 a = 0; a < Splits; ++a)
			{
				for (int32 b = 0; b < SplitsY; ++b)
				{
					const float X = C.X - Lot * 0.5f + W * 0.5f + a * (W + Gap);
					const float Y = C.Y - Lot * 0.5f + D * 0.5f + b * (D + Gap);
					const float H = bNearPark ? Rng.FRandRange(900.f, 2300.f) : Rng.FRandRange(1600.f, 4800.f);
					const FLinearColor Facade = Facades[Rng.RandRange(0, NumFacades - 1)];
					const FLinearColor Shop = Facade * 0.55f;

					AddBox(FVector(X, Y, C.Z + H * 0.5f), FVector(W, D, H), Facade);
					// storefront + awning
					AddBox(FVector(X, Y, C.Z + 125.f), FVector(W + 10.f, D + 10.f, 250.f), Shop, false);
					AddBox(FVector(X, Y, C.Z + 268.f), FVector(W + 70.f, D + 70.f, 10.f), Facades[Rng.RandRange(0, NumFacades - 1)], false);
					// window bands
					for (float Z = 380.f; Z < H - 200.f; Z += 360.f)
					{
						AddBox(FVector(X, Y, C.Z + Z), FVector(W + 8.f, D + 8.f, 150.f), Glass, false);
					}
					// cornice + rooftop unit
					AddBox(FVector(X, Y, C.Z + H + 12.f), FVector(W + 16.f, D + 16.f, 24.f), Trim, false);
					if (Rng.FRand() < 0.6f)
					{
						AddBox(FVector(X + Rng.FRandRange(-W, W) * 0.25f, Y + Rng.FRandRange(-D, D) * 0.25f, C.Z + H + 70.f),
							FVector(220, 160, 110), FLinearColor(0.6f, 0.6f, 0.6f), false);
					}
				}
			}

			// street trees
			for (int32 Side = 0; Side < 4; ++Side)
			{
				for (int32 t = -1; t <= 1; ++t)
				{
					const float Along = t * 1050.f + Rng.FRandRange(-80.f, 80.f);
					const float Edge = Block * 0.5f - 175.f;
					FVector P = C;
					switch (Side)
					{
					case 0: P += FVector(Along, Edge, 0); break;
					case 1: P += FVector(Along, -Edge, 0); break;
					case 2: P += FVector(Edge, Along, 0); break;
					default: P += FVector(-Edge, Along, 0); break;
					}
					AddTree(P, Rng.FRandRange(0.8f, 1.1f), Rng.RandRange(0, 2));
				}
			}
		}
	}
}

void ADPSummerCityZone::BuildSkyline()
{
	using namespace City;
	FRandomStream Rng(77);
	for (int32 Side = 0; Side < 4; ++Side)
	{
		for (float t = -17000.f; t <= 17000.f; t += 1700.f)
		{
			const float Depth = 12600.f + Rng.FRandRange(0.f, 2500.f);
			const float H = Rng.FRandRange(2500.f, 9500.f);
			const FLinearColor Col = Facades[Rng.RandRange(0, NumFacades - 1)] * 0.9f;
			FVector P;
			switch (Side)
			{
			case 0: P = FVector(t, Depth, H * 0.5f); break;
			case 1: P = FVector(t, -Depth, H * 0.5f); break;
			case 2: P = FVector(Depth, t, H * 0.5f); break;
			default: P = FVector(-Depth, t, H * 0.5f); break;
			}
			AddBox(P, FVector(1400, 1400, H), Col, false);
		}
	}
}

// ---------------------------------------------------------------- Street details

void ADPSummerCityZone::AddTree(const FVector& Base, float Scale, int32 Variant)
{
	using namespace City;
	const FLinearColor Leaf = Leaves[FMath::Clamp(Variant, 0, 2)];
	AddInstanced(EDPShape::Cylinder, FTransform(FRotator::ZeroRotator, Base + FVector(0, 0, 160 * Scale), FVector(0.22f, 0.22f, 3.2f) * Scale), Bark, true);
	AddInstanced(EDPShape::Sphere, FTransform(FRotator::ZeroRotator, Base + FVector(0, 0, 400 * Scale), FVector(3.2f, 3.2f, 2.6f) * Scale), Leaf, false);
	AddInstanced(EDPShape::Sphere, FTransform(FRotator::ZeroRotator, Base + FVector(70, -40, 500 * Scale), FVector(2.2f, 2.2f, 2.0f) * Scale), Leaf * 1.12f, false);
	AddInstanced(EDPShape::Sphere, FTransform(FRotator::ZeroRotator, Base + FVector(-60, 60, 330 * Scale), FVector(2.0f) * Scale), Leaf * 0.9f, false);
}

void ADPSummerCityZone::AddBench(const FVector& Center, float Yaw)
{
	using namespace City;
	const FRotator R(0.f, Yaw, 0.f);
	const FLinearColor Slat(0.5f, 0.32f, 0.18f);
	auto At = [&](const FVector& Local) { return Center + R.RotateVector(Local); };
	AddBox(At(FVector(0, 0, 45)), FVector(50, 180, 8), Slat, true, R);
	AddBox(At(FVector(-24, 0, 75)), FVector(6, 180, 45), Slat, false, R);
	AddBox(At(FVector(0, -80, 22)), FVector(46, 6, 44), Metal, false, R);
	AddBox(At(FVector(0, 80, 22)), FVector(46, 6, 44), Metal, false, R);
}

void ADPSummerCityZone::AddCar(const FVector& Center, float Yaw, const FLinearColor& Color)
{
	using namespace City;
	const FRotator R(0.f, Yaw, 0.f);
	auto At = [&](const FVector& Local) { return Center + R.RotateVector(Local); };
	AddBox(At(FVector(0, 0, 55)), FVector(420, 180, 70), Color, true, R);
	AddBox(At(FVector(-20, 0, 115)), FVector(230, 165, 55), Color * 0.95f, true, R);
	AddBox(At(FVector(-20, 0, 116)), FVector(234, 168, 40), Glass, false, R);
	for (const FVector& W : { FVector(130, 90, 32), FVector(130, -90, 32), FVector(-130, 90, 32), FVector(-130, -90, 32) })
	{
		AddInstanced(EDPShape::Cylinder, FTransform(FRotator(0.f, Yaw, 90.f), At(W), FVector(0.64f, 0.64f, 0.24f)), FLinearColor(0.03f, 0.03f, 0.03f), false);
	}
}

void ADPSummerCityZone::AddLamp(const FVector& Base)
{
	using namespace City;
	AddInstanced(EDPShape::Cylinder, FTransform(FRotator::ZeroRotator, Base + FVector(0, 0, 250), FVector(0.12f, 0.12f, 5.f)), Metal, true);
	AddBox(Base + FVector(0, 0, 505), FVector(40, 40, 30), Metal, false);
	AddBox(Base + FVector(0, 0, 486), FVector(32, 32, 8), FLinearColor(0.95f, 0.92f, 0.8f), false);
}

void ADPSummerCityZone::AddCrosswalk(const FVector& Center, bool bAlongX)
{
	for (int32 k = -4; k <= 4; ++k)
	{
		const FVector Offset = bAlongX ? FVector(0, k * 105.f, 0) : FVector(k * 105.f, 0, 0);
		const FVector Size = bAlongX ? FVector(300, 55, 1) : FVector(55, 300, 1);
		AddBox(Center + Offset + FVector(0, 0, 0.6f), Size, FLinearColor(0.85f, 0.85f, 0.82f), false);
	}
}

void ADPSummerCityZone::BuildStreets()
{
	using namespace City;
	// Crosswalks at the four intersections around the park.
	for (int32 sx = -1; sx <= 1; sx += 2)
	{
		for (int32 sy = -1; sy <= 1; sy += 2)
		{
			const FVector I(sx * Pitch * 0.5f, sy * Pitch * 0.5f, 0.f);
			AddCrosswalk(I + FVector(0, 670, 0), false);
			AddCrosswalk(I + FVector(0, -670, 0), false);
			AddCrosswalk(I + FVector(670, 0, 0), true);
			AddCrosswalk(I + FVector(-670, 0, 0), true);
		}
	}

	// Parked cars.
	FRandomStream Rng(4242);
	const FVector CarSpots[] =
	{
		FVector(-3000, -2100 + 360, 0), FVector(3400, -2100 + 360, 0), FVector(900, 2100 - 360, 0),
		FVector(-2100 + 360, 3300, 0), FVector(2100 - 360, -3200, 0), FVector(2100 - 360, 4200, 0),
		FVector(5600, 2100 - 360, 0), FVector(-6000, -2100 + 360, 0), FVector(-2100 + 360, -5200, 0),
	};
	for (int32 i = 0; i < static_cast<int32>(UE_ARRAY_COUNT(CarSpots)); ++i)
	{
		const FVector& S = CarSpots[i];
		const bool bAlongX = FMath::Abs(FMath::Abs(S.Y) - 1740.f) < 5.f;
		const FLinearColor Col = Facades[Rng.RandRange(0, NumFacades - 1)] * Rng.FRandRange(0.6f, 1.f);
		AddCar(S, bAlongX ? 0.f : 90.f, Col);
	}

	// The bus stop at the far end of the avenue.
	const FVector Stop(6975, -3150, Curb);
	AddBox(Stop + FVector(60, 0, 250), FVector(180, 420, 10), Metal);
	AddBox(Stop + FVector(140, 0, 125), FVector(6, 400, 240), FLinearColor(0.5f, 0.62f, 0.7f), false);
	AddBox(Stop + FVector(-20, -205, 125), FVector(8, 8, 250), Metal, true);
	AddBox(Stop + FVector(-20, 205, 125), FVector(8, 8, 250), Metal, true);
	AddBox(Stop + FVector(100, 0, 45), FVector(45, 300, 8), Metal, true);
}

void ADPSummerCityZone::BuildPark()
{
	using namespace City;
	const float Inner = Block - 2.f * Sidewalk;

	AddBox(FVector(0, 0, GrassZ - 1.f), FVector(Inner, Inner, 2.f), Grass, false);
	AddBox(FVector(0, 0, GrassZ - 0.5f), FVector(Inner, 260, 2.f), Path, false);
	AddBox(FVector(0, 0, GrassZ - 0.5f), FVector(260, Inner, 2.f), Path, false);
	// low hedge with gaps at the paths
	for (int32 Side = 0; Side < 4; ++Side)
	{
		for (int32 s = -1; s <= 1; s += 2)
		{
			const float Len = Inner * 0.5f - 220.f;
			const float Mid = s * (220.f + Len * 0.5f);
			const float E = Inner * 0.5f;
			const FVector P = Side == 0 ? FVector(Mid, E, 50) : Side == 1 ? FVector(Mid, -E, 50) : Side == 2 ? FVector(E, Mid, 50) : FVector(-E, Mid, 50);
			const FVector Sz = Side < 2 ? FVector(Len, 70, 80) : FVector(70, Len, 80);
			AddBox(P, Sz, Leaves[2], true);
		}
	}

	// Fountain
	AddInstanced(EDPShape::Cylinder, FTransform(FRotator::ZeroRotator, FVector(0, 0, GrassZ + 25), FVector(5.2f, 5.2f, 0.5f)), Stone, true);
	AddInstanced(EDPShape::Cylinder, FTransform(FRotator::ZeroRotator, FVector(0, 0, GrassZ + 45), FVector(4.8f, 4.8f, 0.06f)), Water, false);
	AddInstanced(EDPShape::Cylinder, FTransform(FRotator::ZeroRotator, FVector(0, 0, GrassZ + 100), FVector(0.6f, 0.6f, 1.6f)), Stone, true);
	AddInstanced(EDPShape::Cylinder, FTransform(FRotator::ZeroRotator, FVector(0, 0, GrassZ + 175), FVector(2.f, 2.f, 0.2f)), Stone, false);
	AddInstanced(EDPShape::Cylinder, FTransform(FRotator::ZeroRotator, FVector(0, 0, GrassZ + 186), FVector(1.8f, 1.8f, 0.04f)), Water, false);
	AddInstanced(EDPShape::Sphere, FTransform(FRotator::ZeroRotator, FVector(0, 0, GrassZ + 215), FVector(0.35f, 0.35f, 0.5f)), Water * 1.4f, false);

	// Trees
	FRandomStream Rng(31337);
	for (int32 i = 0; i < 26; ++i)
	{
		FVector P(Rng.FRandRange(-1300.f, 1300.f), Rng.FRandRange(-1300.f, 1300.f), GrassZ);
		if (FMath::Abs(P.X) < 320.f || FMath::Abs(P.Y) < 320.f || P.Size2D() < 700.f)
		{
			continue; // keep paths and the fountain clear
		}
		if (FVector::Dist2D(P, FVector(950, -950, 0)) < 500.f || FVector::Dist2D(P, FVector(240, 950, 0)) < 400.f)
		{
			continue; // Theo's lawn, the cart
		}
		AddTree(P, Rng.FRandRange(0.9f, 1.35f), Rng.RandRange(0, 2));
	}

	// Benches along the paths
	AddBench(FVector(-900, -200, GrassZ), 90.f);
	AddBench(FVector(-500, 200, GrassZ), -90.f);
	AddBench(FVector(700, 200, GrassZ), -90.f);
	AddBench(FVector(200, -800, GrassZ), 0.f);
	AddBench(FVector(-200, 900, GrassZ), 180.f);

	// Lamps
	for (const FVector& L : { FVector(-1000, 170, GrassZ), FVector(1000, -170, GrassZ), FVector(170, 1000, GrassZ), FVector(-170, -1000, GrassZ) })
	{
		AddLamp(L);
	}

	// Ice cream cart (out of ice cream)
	const FVector Cart(240, 900, GrassZ);
	AddBox(Cart + FVector(0, 0, 70), FVector(280, 120, 90), FLinearColor(0.98f, 0.95f, 0.88f));
	AddBox(Cart + FVector(0, 0, 108), FVector(284, 124, 14), FLinearColor(0.95f, 0.5f, 0.6f), false);
	AddBox(Cart + FVector(0, 0, 118), FVector(200, 100, 6), FLinearColor(0.75f, 0.85f, 0.9f), false);
	AddInstanced(EDPShape::Cylinder, FTransform(FRotator(0.f, 0.f, 90.f), Cart + FVector(-100, 0, 22), FVector(0.44f, 0.44f, 1.3f)), FLinearColor(0.1f, 0.1f, 0.1f), false);
	AddInstanced(EDPShape::Cylinder, FTransform(FRotator::ZeroRotator, Cart + FVector(110, 30, 200), FVector(0.05f, 0.05f, 2.2f)), Trim, false);
	AddInstanced(EDPShape::Cone, FTransform(FRotator::ZeroRotator, Cart + FVector(110, 30, 330), FVector(2.8f, 2.8f, 0.55f)), FLinearColor(0.98f, 0.62f, 0.7f), false);
	AddText(Cart + FVector(0, -62, 75), FRotator(0.f, -90.f, 0.f), LOCTEXT("Cart", "ICE CREAM"), 22.f, FColor(220, 90, 120));
}

// ---------------------------------------------------------------- Lighting

void ADPSummerCityZone::BuildLighting()
{
	UDirectionalLightComponent* Sun = NewObject<UDirectionalLightComponent>(this);
	Sun->SetupAttachment(Root);
	Sun->SetMobility(EComponentMobility::Movable);
	Sun->SetRelativeRotation(FRotator(-38.f, -50.f, 0.f));
	Sun->SetIntensity(10.f);
	Sun->SetLightColor(FLinearColor(1.f, 0.93f, 0.82f));
	Sun->SetAtmosphereSunLight(true);
	Sun->SetCastShadows(true);
	Sun->SetVolumetricScatteringIntensity(1.2f);
	Sun->RegisterComponent();
	AddInstanceComponent(Sun);

	USkyAtmosphereComponent* Atmosphere = NewObject<USkyAtmosphereComponent>(this);
	Atmosphere->SetupAttachment(Root);
	Atmosphere->RegisterComponent();
	AddInstanceComponent(Atmosphere);

	UVolumetricCloudComponent* Clouds = NewObject<UVolumetricCloudComponent>(this);
	Clouds->SetupAttachment(Root);
	Clouds->RegisterComponent();
	AddInstanceComponent(Clouds);

	USkyLightComponent* Sky = NewObject<USkyLightComponent>(this);
	Sky->SetupAttachment(Root);
	Sky->SetMobility(EComponentMobility::Movable);
	Sky->bRealTimeCapture = true;
	Sky->SourceType = ESkyLightSourceType::SLS_CapturedScene;
	Sky->SetIntensity(1.f);
	Sky->RegisterComponent();
	AddInstanceComponent(Sky);

	UExponentialHeightFogComponent* Fog = NewObject<UExponentialHeightFogComponent>(this);
	Fog->SetupAttachment(Root);
	Fog->SetFogDensity(0.012f);
	Fog->SetFogHeightFalloff(0.15f);
	Fog->SetStartDistance(1500.f);
	Fog->SetVolumetricFog(true);
	Fog->SetVolumetricFogScatteringDistribution(0.7f);
	Fog->SetVolumetricFogExtinctionScale(0.4f);
	Fog->RegisterComponent();
	AddInstanceComponent(Fog);

	UPostProcessComponent* PPC = NewObject<UPostProcessComponent>(this);
	PPC->SetupAttachment(Root);
	PPC->bUnbound = true;
	FPostProcessSettings& S = PPC->Settings;
	S.bOverride_AutoExposureBias = true;      S.AutoExposureBias = 0.5f;
	S.bOverride_WhiteTemp = true;             S.WhiteTemp = 5900.f;
	S.bOverride_ColorSaturation = true;       S.ColorSaturation = FVector4(1.12f, 1.1f, 1.08f, 1.f);
	S.bOverride_BloomIntensity = true;        S.BloomIntensity = 0.9f;
	S.bOverride_VignetteIntensity = true;     S.VignetteIntensity = 0.2f;
	PPC->RegisterComponent();
	AddInstanceComponent(PPC);
}

// ---------------------------------------------------------------- Characters

void ADPSummerCityZone::BuildCharacters()
{
	using namespace City;
	const float StandZ = GrassZ + 88.f;

	// Mina, the ice cream vendor without ice cream.
	{
		FDPNPCLook L;
		L.Skin = FLinearColor(0.86f, 0.64f, 0.5f);
		L.Hair = FLinearColor(0.32f, 0.16f, 0.07f);
		L.Shirt = FLinearColor(0.95f, 0.55f, 0.62f);
		L.Pants = FLinearColor(0.2f, 0.25f, 0.42f);
		L.bApron = true;
		L.bCap = true;
		L.CapColor = FLinearColor(0.98f, 0.98f, 0.95f);
		L.Height = 0.95f;
		if (ADPNPC* Mina = SpawnOwned<ADPNPC>(FTransform(FRotator(0.f, -90.f, 0.f), FVector(240, 1040, GrassZ + 88.f * L.Height))))
		{
			Mina->Setup(TEXT("mina"), LOCTEXT("Mina", "Mina"), LOCTEXT("Vendor", "the ice cream vendor"), L);
		}
	}

	// Mr. Halvorsen, on the bench, with the pigeons.
	{
		FDPNPCLook L;
		L.Skin = FLinearColor(0.84f, 0.68f, 0.58f);
		L.Hair = FLinearColor(0.78f, 0.78f, 0.76f);
		L.Shirt = FLinearColor(0.42f, 0.47f, 0.34f);
		L.Pants = FLinearColor(0.33f, 0.29f, 0.24f);
		L.bSeated = true;
		L.bCap = true;
		L.CapColor = FLinearColor(0.28f, 0.28f, 0.3f);
		if (ADPNPC* Arne = SpawnOwned<ADPNPC>(FTransform(FRotator(0.f, 90.f, 0.f), FVector(-900, -205, StandZ))))
		{
			Arne->Setup(TEXT("halvorsen"), LOCTEXT("Halvorsen", "Mr. Halvorsen"), LOCTEXT("OldMan", "the old man"), L);
		}
	}

	// Pigeons.
	for (int32 i = 0; i < 7; ++i)
	{
		const FVector P(-900 + FMath::FRandRange(-170.f, 170.f), FMath::FRandRange(-60.f, 90.f), GrassZ + 6.f);
		USceneComponent* Bird = AddGroup(P, FRotator(0.f, FMath::FRandRange(0.f, 360.f), 0.f));
		AddPart(EDPShape::Sphere, FTransform(FRotator::ZeroRotator, FVector(0, 0, 6), FVector(0.14f, 0.09f, 0.09f)), FLinearColor(0.42f, 0.43f, 0.47f), false, Bird);
		AddPart(EDPShape::Sphere, FTransform(FRotator::ZeroRotator, FVector(7, 0, 12), FVector(0.055f)), FLinearColor(0.25f, 0.3f, 0.32f), false, Bird);
		Pigeons.Add(Bird);
		PigeonHome.Add(P);
	}

	// Theo and his kite.
	{
		FDPNPCLook L;
		L.Skin = FLinearColor(0.58f, 0.4f, 0.28f);
		L.Hair = FLinearColor(0.05f, 0.04f, 0.04f);
		L.Shirt = FLinearColor(0.96f, 0.8f, 0.2f);
		L.Pants = FLinearColor(0.25f, 0.4f, 0.62f);
		L.Height = 0.68f;
		L.bCap = true;
		L.CapColor = FLinearColor(0.85f, 0.15f, 0.12f);
		Theo = SpawnOwned<ADPNPC>(FTransform(FRotator(0.f, -60.f, 0.f), FVector(950, -950, GrassZ + 88.f * 0.68f)));
		if (Theo)
		{
			Theo->Setup(TEXT("theo"), LOCTEXT("Theo", "Theo"), LOCTEXT("Kid", "the kid with the kite"), L);
		}
		Kite = AddGroup(FVector(1400, -1700, 1500));
		AddPart(EDPShape::Cube, FTransform(FRotator(0.f, 0.f, 45.f), FVector::ZeroVector, FVector(0.03f, 0.9f, 0.9f)), FLinearColor(0.9f, 0.2f, 0.25f), false, Kite);
		AddPart(EDPShape::Cube, FTransform(FRotator(0.f, 0.f, 45.f), FVector(1, 0, 0), FVector(0.02f, 0.5f, 0.5f)), FLinearColor(0.98f, 0.85f, 0.3f), false, Kite);
		for (int32 t = 1; t <= 5; ++t)
		{
			AddPart(EDPShape::Cube, FTransform(FRotator(0.f, 0.f, 45.f), FVector(0, 0, -60.f - t * 30.f), FVector(0.02f, 0.12f, 0.12f)),
				t % 2 ? FLinearColor(0.2f, 0.5f, 0.9f) : FLinearColor(0.98f, 0.98f, 0.95f), false, Kite);
		}
		KiteLine = AddPart(EDPShape::Cylinder, FTransform::Identity, FLinearColor(0.95f, 0.95f, 0.95f), false);
	}

	// The jogger, looping the park.
	{
		FDPNPCLook L;
		L.Skin = FLinearColor(0.74f, 0.52f, 0.38f);
		L.Hair = FLinearColor(0.6f, 0.42f, 0.2f);
		L.Shirt = FLinearColor(0.25f, 0.72f, 0.72f);
		L.Pants = FLinearColor(0.08f, 0.08f, 0.1f);
		const float E = Block * 0.5f - 175.f;
		if (ADPNPC* Jogger = SpawnOwned<ADPNPC>(FTransform(FVector(-E, -E, Curb + 88.f))))
		{
			Jogger->Setup(TEXT("jogger"), LOCTEXT("Jogger", "the jogger"), LOCTEXT("JoggerU", "the jogger"), L);
			Jogger->SetPatrol({ FVector(-E, -E, Curb + 88.f), FVector(E, -E, Curb + 88.f), FVector(E, E, Curb + 88.f), FVector(-E, E, Curb + 88.f) }, 330.f);
		}
	}

	// The Observer. Far end of the avenue, by the bus stop. Easy to overlook.
	ObserverSpots = { FVector(6975, -2780, Curb), FVector(-6975, 900, Curb), FVector(-900, 6975, Curb), FVector(900, -6975, Curb) };
	Observer = SpawnOwned<ADPObserver>(FTransform(ObserverSpots[0]));
	if (Observer)
	{
		Observer->SeenMaxDistance = 12000.f;
		Observer->SeenThreshold = 1.0f;
		TWeakObjectPtr<ADPSummerCityZone> WeakThis(this);
		Observer->OnSeen = [WeakThis](ADPObserver*)
		{
			if (!WeakThis.IsValid())
			{
				return;
			}
			ADPGameMode* GM = WeakThis->GetGameMode();
			if (GM && !GM->HasFlag(TEXT("observer_noticed")))
			{
				GM->SetFlag(TEXT("observer_noticed"));
				if (ADPCharacter* P = WeakThis->GetPlayer())
				{
					P->GetDread()->AddFear(3.f, TEXT("ObserverNoticed")); // a flicker of unease, scaled down here
				}
			}
		};
	}
}

// ---------------------------------------------------------------- Runtime

void ADPSummerCityZone::OnPlayerEntered(ADPCharacter* Player, bool bFromSave)
{
	TimeInZone = 0.f;
	HintStage = 0;
	HintTimer = 0.f;
}

void ADPSummerCityZone::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);
	TimeInZone += DeltaSeconds;
	UpdateHints(DeltaSeconds);
	UpdateLife(DeltaSeconds);

	// You can never quite reach him.
	ADPCharacter* Player = GetPlayer();
	if (Observer && Player && !Observer->HasPendingMove() && Observer->IsPresent())
	{
		const float Dist = FVector::Dist2D(Player->GetActorLocation(), Observer->GetActorLocation());
		if (Dist < 2600.f)
		{
			FVector Best = ObserverSpots[0];
			float BestDist = -1.f;
			for (const FVector& S : ObserverSpots)
			{
				const float D = FVector::Dist2D(S, Player->GetActorLocation());
				if (D > BestDist)
				{
					BestDist = D;
					Best = S;
				}
			}
			Observer->RequestRelocation(Best);
		}
	}
}

void ADPSummerCityZone::UpdateHints(float DeltaSeconds)
{
	ADPGameMode* GM = GetGameMode();
	ADPHUD* HUD = GM ? GM->GetDPHUD() : nullptr;
	if (!GM || !HUD || GM->IsInSequence())
	{
		return;
	}
	HintTimer += DeltaSeconds;

	switch (HintStage)
	{
	case 0:
		if (TimeInZone > 3.f)
		{
			HUD->ShowThought(LOCTEXT("Arrive", "...Okay. Okay. This is-- I'm dreaming. I'm actually dreaming."), 5.f);
			HintStage = 1;
			HintTimer = 0.f;
		}
		break;
	case 1:
		if (HintTimer > 6.f)
		{
			if (!GM->HasFlag(TEXT("manifest_first")))
			{
				HUD->ShowHint(LOCTEXT("TryManifest", "You're lucid. Picture something. Something sweet.\nHold Q"), 10.f);
			}
			HintStage = 2;
			HintTimer = 0.f;
		}
		break;
	case 2:
		if (GM->HasFlag(TEXT("manifest_first")) && HintTimer > 25.f)
		{
			if (!GM->HasFlag(TEXT("talked_any")))
			{
				HUD->ShowHint(LOCTEXT("TryTalk", "The people here seem... real.\nE: talk"), 8.f);
			}
			HintStage = 3;
			HintTimer = 0.f;
		}
		else if (HintTimer > 60.f && !GM->HasFlag(TEXT("manifest_first")))
		{
			HUD->ShowHint(LOCTEXT("TryManifest2", "Hold Q to picture something."), 6.f);
			HintTimer = 0.f;
		}
		break;
	case 3:
		if ((GM->HasFlag(TEXT("talked_any")) && HintTimer > 40.f) || TimeInZone > 300.f)
		{
			HUD->ShowHint(LOCTEXT("TryWake", "You can wake up whenever you like.\nHold T"), 10.f);
			GM->SetFlag(TEXT("wake_hint"));
			HintStage = 4;
		}
		break;
	default:
		break;
	}
}

void ADPSummerCityZone::UpdateLife(float DeltaSeconds)
{
	ADPGameMode* GM = GetGameMode();

	// The pigeons stop when you ask the wrong question.
	if (GM && GM->HasFlag(TEXT("asked_lottery")) && !bSawLotteryFlag)
	{
		bSawLotteryFlag = true;
		PigeonFreezeTime = 30.f;
	}
	PigeonFreezeTime = FMath::Max(0.f, PigeonFreezeTime - DeltaSeconds);

	if (PigeonFreezeTime <= 0.f)
	{
		for (int32 i = 0; i < Pigeons.Num(); ++i)
		{
			const float T = TimeInZone * 2.3f + i * 1.7f;
			const float Hop = FMath::Max(0.f, FMath::Sin(T * 2.f)) * 4.f;
			const FVector Wander(FMath::Sin(T * 0.21f + i) * 25.f, FMath::Cos(T * 0.17f + i * 2.f) * 25.f, Hop);
			Pigeons[i]->SetRelativeLocation(PigeonHome[i] + Wander);
			Pigeons[i]->SetRelativeRotation(FRotator(0.f, i * 50.f + FMath::Sin(T * 0.4f) * 70.f, 0.f));
		}
	}

	// The kite sways; its string runs to Theo's hand.
	if (Kite)
	{
		const FVector KitePos(1400.f + FMath::Sin(TimeInZone * 0.4f) * 160.f, -1700.f + FMath::Cos(TimeInZone * 0.33f) * 120.f,
			1500.f + FMath::Sin(TimeInZone * 0.7f) * 70.f);
		Kite->SetRelativeLocation(KitePos);
		Kite->SetRelativeRotation(FRotator(FMath::Sin(TimeInZone * 1.1f) * 10.f, -40.f, FMath::Sin(TimeInZone * 0.9f) * 15.f));

		if (Theo && KiteLine)
		{
			const FVector Hand = Theo->GetHandPoint()->GetComponentLocation();
			const FVector Delta = KitePos - Hand;
			const float Len = Delta.Size();
			const FQuat Rot = FRotationMatrix::MakeFromZ(Delta.GetSafeNormal()).ToQuat();
			KiteLine->SetWorldLocationAndRotation(Hand + Delta * 0.5f, Rot);
			KiteLine->SetWorldScale3D(FVector(0.006f, 0.006f, Len / 100.f));
		}
	}
}

FVector ADPSummerCityZone::FindObserverSpotNear(const FVector& PlayerLoc, float MinDist, float MaxDist) const
{
	TArray<const AActor*> Ignore;
	Ignore.Add(Observer);
	for (int32 Attempt = 0; Attempt < 24; ++Attempt)
	{
		const FVector Dir = FRotator(0.f, FMath::FRandRange(0.f, 360.f), 0.f).Vector();
		FVector P = PlayerLoc + Dir * FMath::FRandRange(MinDist, MaxDist);
		if (FMath::Abs(P.X) > City::Bounds - 300.f || FMath::Abs(P.Y) > City::Bounds - 300.f)
		{
			continue;
		}
		P.Z = GroundZ(P, City::Curb);
		const FVector Body = P + FVector(0, 0, 95);
		// unobserved now, but in plain sight the moment you turn around
		if (!DPObservation::IsObserved(GetWorld(), Body, 60.f, Ignore) && DPObservation::HasLineOfSight(GetWorld(), Body, Ignore))
		{
			return P;
		}
	}
	return FVector::ZeroVector;
}

void ADPSummerCityZone::HandleObserverEvent(FName Event)
{
	ADPCharacter* Player = GetPlayer();
	if (!Observer || !Player)
	{
		return;
	}
	if (Event == TEXT("closer"))
	{
		const float CurrentDist = FVector::Dist2D(Observer->GetActorLocation(), Player->GetActorLocation());
		const float Target = FMath::Clamp(CurrentDist * 0.6f, 2700.f, 5000.f);
		const FVector Spot = FindObserverSpotNear(Player->GetActorLocation(), Target * 0.85f, Target);
		if (!Spot.IsZero())
		{
			ObserverSpots.Insert(Spot, 0);
			Observer->RequestRelocation(Spot);
		}
	}
}

#undef LOCTEXT_NAMESPACE
