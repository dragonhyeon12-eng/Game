#include "World/DPBedroomZone.h"
#include "Core/DPCharacter.h"
#include "Core/DPGameMode.h"
#include "Core/DPPlayerController.h"
#include "UI/DPHUD.h"
#include "Components/PointLightComponent.h"
#include "Components/PostProcessComponent.h"
#include "Components/RectLightComponent.h"
#include "Components/SkyLightComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Components/TextRenderComponent.h"

#define LOCTEXT_NAMESPACE "DPBedroom"

/*
 * Layout (cm). Interior: X -260..260, Y -220..220, Z 0..260.
 *   -X wall: desk + computer       +X wall: bed (head at -Y) and wardrobe (+Y)
 *   +Y wall: window                -Y wall: door
 */
namespace Bedroom
{
	const FLinearColor Wall(0.36f, 0.39f, 0.46f);
	const FLinearColor Floor(0.30f, 0.19f, 0.11f);
	const FLinearColor Ceiling(0.75f, 0.75f, 0.73f);
	const FLinearColor Wood(0.24f, 0.15f, 0.09f);
	const FLinearColor DarkWood(0.13f, 0.08f, 0.05f);
	const FLinearColor Trim(0.8f, 0.79f, 0.75f);
	const FLinearColor Plastic(0.03f, 0.03f, 0.035f);
	const FLinearColor Sheet(0.82f, 0.82f, 0.8f);
	const FLinearColor Blanket(0.16f, 0.3f, 0.36f);
	const FLinearColor NightSky(0.01f, 0.015f, 0.04f);
}

void ADPBedroomZone::BuildZone()
{
	BuildRoom();
	BuildFurniture();
	BuildLighting();
	BuildInteractables();
	AddSynth(EDPSynthVoice::RoomTone, FVector(-230.f, -80.f, 60.f), false, bWakingVariant ? 0.5f : 1.f, 0.f);
}

FTransform ADPBedroomZone::GetPlayerStart() const
{
	if (bWakingVariant)
	{
		// Sitting up at the edge of the bed, facing the dark monitor.
		return FTransform(FRotator(-8.f, 180.f, 0.f), FVector(120.f, -100.f, 92.f));
	}
	return FTransform(FRotator(-6.f, 180.f, 0.f), FVector(-110.f, -60.f, 92.f));
}

void ADPBedroomZone::BuildRoom()
{
	using namespace Bedroom;

	AddBox(FVector(0, 0, -10), FVector(560, 480, 20), Floor);
	AddBox(FVector(0, 0, 270), FVector(560, 480, 20), Ceiling);
	AddBox(FVector(-270, 0, 130), FVector(20, 480, 260), Wall);
	AddBox(FVector(270, 0, 130), FVector(20, 480, 260), Wall);
	AddBox(FVector(0, -230, 130), FVector(560, 20, 260), Wall);

	// +Y wall with a window opening (X -10..130, Z 90..200)
	AddBox(FVector(-145, 230, 130), FVector(270, 20, 260), Wall);
	AddBox(FVector(205, 230, 130), FVector(150, 20, 260), Wall);
	AddBox(FVector(60, 230, 45), FVector(140, 20, 90), Wall);
	AddBox(FVector(60, 230, 230), FVector(140, 20, 60), Wall);
	// window frame + sill + mullion
	AddBox(FVector(60, 224, 88), FVector(150, 30, 5), Trim);
	AddBox(FVector(60, 232, 200), FVector(146, 8, 5), Trim, false);
	AddBox(FVector(-12, 232, 145), FVector(5, 8, 115), Trim, false);
	AddBox(FVector(132, 232, 145), FVector(5, 8, 115), Trim, false);
	AddBox(FVector(60, 232, 145), FVector(3, 6, 110), Trim, false);
	AddBox(FVector(60, 232, 145), FVector(140, 6, 3), Trim, false);
	// curtains, half drawn
	AddBox(FVector(-30, 214, 150), FVector(40, 6, 130), FLinearColor(0.25f, 0.12f, 0.15f), false);
	AddBox(FVector(150, 214, 150), FVector(30, 6, 130), FLinearColor(0.25f, 0.12f, 0.15f), false);

	// Outside: night sky and a few dark rooftops.
	AddBox(FVector(60, 1400, 300), FVector(4000, 20, 2400), NightSky, false);
	AddBox(FVector(-200, 900, 0), FVector(500, 300, 500), FLinearColor(0.02f, 0.02f, 0.025f), false);
	AddBox(FVector(400, 1000, -50), FVector(400, 300, 600), FLinearColor(0.025f, 0.02f, 0.02f), false);
	AddBox(FVector(60, 600, -100), FVector(1200, 400, 20), FLinearColor(0.02f, 0.02f, 0.02f), false);

	// skirting
	AddBox(FVector(-259, 0, 5), FVector(2, 440, 10), Trim, false);
	AddBox(FVector(259, 0, 5), FVector(2, 440, 10), Trim, false);
	AddBox(FVector(0, -219, 5), FVector(520, 2, 10), Trim, false);

	// rug
	AddBox(FVector(0, 0, 0.6f), FVector(230, 170, 1.2f), FLinearColor(0.38f, 0.16f, 0.14f), false);

	// Door on -Y wall (decorative; it's late)
	AddBox(FVector(150, -219, 100), FVector(92, 4, 202), FLinearColor(0.52f, 0.47f, 0.42f));
	AddInstanced(EDPShape::Sphere, FTransform(FRotator::ZeroRotator, FVector(112, -214, 100), FVector(0.06f)), FLinearColor(0.7f, 0.65f, 0.45f), false);

	// Posters
	AddBox(FVector(-80, -218.5f, 160), FVector(60, 2, 85), FLinearColor(0.12f, 0.2f, 0.35f), false);
	AddBox(FVector(-80, -217.5f, 175), FVector(40, 1, 30), FLinearColor(0.8f, 0.55f, 0.2f), false);
	AddBox(FVector(258.5f, 150, 170), FVector(2, 55, 40), FLinearColor(0.5f, 0.6f, 0.45f), false);
}

void ADPBedroomZone::BuildFurniture()
{
	using namespace Bedroom;

	// Desk against -X wall
	AddBox(FVector(-225, -80, 74), FVector(70, 150, 4), Wood);
	for (const FVector2D& Leg : { FVector2D(-255, -150), FVector2D(-195, -150), FVector2D(-255, -10), FVector2D(-195, -10) })
	{
		AddBox(FVector(Leg.X, Leg.Y, 36), FVector(4, 4, 72), DarkWood);
	}
	// Monitor
	AddInstanced(EDPShape::Cylinder, FTransform(FRotator::ZeroRotator, FVector(-242, -80, 80), FVector(0.18f, 0.18f, 0.02f)), Plastic, false);
	AddBox(FVector(-244, -80, 88), FVector(4, 4, 16), Plastic, false);
	AddBox(FVector(-243, -80, 113), FVector(5, 64, 38), Plastic);
	// screen surface
	AddBox(FVector(-240.3f, -80, 113), FVector(0.5f, 58, 33), bWakingVariant ? FLinearColor(0.01f, 0.01f, 0.012f) : FLinearColor(0.55f, 0.65f, 0.8f), false);
	if (!bWakingVariant)
	{
		ScreenText = AddText(FVector(-239.8f, -80, 116), FRotator::ZeroRotator,
			LOCTEXT("Screen", "HOW TO LUCID DREAM TONIGHT!\n(100% WORKING)"), 3.2f, FColor(250, 250, 255));
	}
	// keyboard, mouse, mug
	AddBox(FVector(-213, -80, 77), FVector(16, 44, 2), Plastic, false);
	AddBox(FVector(-212, -40, 77), FVector(10, 6, 2.5f), Plastic, false);
	AddInstanced(EDPShape::Cylinder, FTransform(FRotator::ZeroRotator, FVector(-230, -138, 81), FVector(0.08f, 0.08f, 0.1f)), FLinearColor(0.7f, 0.25f, 0.2f), false);

	// Desk notebook (dark red cover)
	DeskNotebook = AddPartBox(FVector(-213, -20, 76.8f), FVector(17, 23, 1.6f), FLinearColor(0.42f, 0.06f, 0.06f), false);

	// Desk lamp
	AddInstanced(EDPShape::Cylinder, FTransform(FRotator::ZeroRotator, FVector(-240, -142, 77), FVector(0.12f, 0.12f, 0.02f)), Plastic, false);
	AddBox(FVector(-240, -142, 98), FVector(2, 2, 42), Plastic, false);
	AddInstanced(EDPShape::Cone, FTransform(FRotator(0, 0, 0), FVector(-236, -142, 120), FVector(0.14f, 0.14f, 0.12f)), Plastic, false);

	// Chair
	AddBox(FVector(-165, -80, 46), FVector(44, 44, 6), Plastic);
	AddBox(FVector(-142, -80, 80), FVector(5, 42, 55), Plastic);
	AddInstanced(EDPShape::Cylinder, FTransform(FRotator::ZeroRotator, FVector(-165, -80, 22), FVector(0.05f, 0.05f, 0.4f)), Plastic, false);
	AddInstanced(EDPShape::Cylinder, FTransform(FRotator::ZeroRotator, FVector(-165, -80, 3), FVector(0.5f, 0.5f, 0.04f)), Plastic, false);

	// Bed along +X wall (X 145..255, Y -205..0)
	AddBox(FVector(200, -102, 18), FVector(112, 206, 26), DarkWood);
	AddBox(FVector(200, -100, 40), FVector(102, 194, 18), Sheet);
	AddBox(FVector(200, -178, 54), FVector(62, 32, 11), FLinearColor(0.88f, 0.88f, 0.86f), false);
	AddBox(FVector(200, -78, 51), FVector(104, 140, 5), Blanket, false);
	AddBox(FVector(200, -208, 62), FVector(112, 8, 90), DarkWood);
	// bedside table
	AddBox(FVector(225, 30, 28), FVector(50, 45, 56), Wood);

	// Wardrobe with the covered mirror
	AddBox(FVector(225, 140, 100), FVector(70, 130, 200), Wood);
	AddBox(FVector(189.5f, 140, 115), FVector(1.5f, 56, 100), FLinearColor(0.55f, 0.6f, 0.62f), false); // the mirror (barely visible)
	AddBox(FVector(188, 140, 128), FVector(2, 62, 82), FLinearColor(0.82f, 0.8f, 0.74f), false);        // the towel over it
	AddBox(FVector(187.5f, 140, 168), FVector(3, 64, 6), FLinearColor(0.78f, 0.76f, 0.7f), false);
}

void ADPBedroomZone::BuildLighting()
{
	// Dim sky light so shadows are never pitch black.
	USkyLightComponent* Sky = NewObject<USkyLightComponent>(this);
	Sky->SetupAttachment(Root);
	Sky->SetMobility(EComponentMobility::Movable);
	Sky->bRealTimeCapture = true;
	Sky->SourceType = ESkyLightSourceType::SLS_CapturedScene;
	Sky->SetIntensity(0.25f);
	Sky->SetLightColor(FLinearColor(0.5f, 0.6f, 1.f));
	Sky->RegisterComponent();
	AddInstanceComponent(Sky);

	// Moonlight through the window and a sodium street lamp below it.
	AddRectLight(FVector(60, 330, 230), FRotator(-35.f, -90.f, 0.f), FLinearColor(0.55f, 0.65f, 1.f), 6.f, 140.f, 110.f, 900.f, true);
	AddPointLight(FVector(250, 700, -40), FLinearColor(1.f, 0.6f, 0.3f), bWakingVariant ? 15.f : 30.f, 1200.f, true, 20.f);

	if (!bWakingVariant)
	{
		// Desk lamp (warm) and the monitor glow (cold).
		AddPointLight(FVector(-232, -142, 112), FLinearColor(1.f, 0.72f, 0.42f), 14.f, 650.f, true, 4.f);
		MonitorLight = AddRectLight(FVector(-238, -80, 113), FRotator::ZeroRotator, FLinearColor(0.65f, 0.78f, 1.f), 5.f, 56.f, 32.f, 520.f, true);
		MonitorLight->SetBarnDoorAngle(80.f);
	}

	UPostProcessComponent* PPC = NewObject<UPostProcessComponent>(this);
	PPC->SetupAttachment(Root);
	PPC->bUnbound = true;
	PPC->Settings.bOverride_AutoExposureBias = true;
	PPC->Settings.AutoExposureBias = bWakingVariant ? -0.3f : 0.4f;
	PPC->Settings.bOverride_WhiteTemp = true;
	PPC->Settings.WhiteTemp = 7600.f;
	PPC->Settings.bOverride_BloomIntensity = true;
	PPC->Settings.BloomIntensity = 0.8f;
	PPC->RegisterComponent();
	AddInstanceComponent(PPC);
}

void ADPBedroomZone::BuildInteractables()
{
	if (bWakingVariant)
	{
		return;
	}

	TWeakObjectPtr<ADPBedroomZone> WeakThis(this);
	auto GM = [WeakThis]() -> ADPGameMode* { return WeakThis.IsValid() ? WeakThis->GetGameMode() : nullptr; };

	// Computer
	AddInteractable(FVector(-232, -80, 112), FVector(14, 36, 24),
		[GM]()
		{
			const ADPGameMode* G = GM();
			return (G && G->HasFlag(TEXT("tutorial_done"))) ? LOCTEXT("PcDone", "The video's over") : LOCTEXT("PcWatch", "Watch the video");
		},
		[GM](ADPCharacter*)
		{
			if (ADPGameMode* G = GM())
			{
				if (G->HasFlag(TEXT("tutorial_done")))
				{
					G->GetDPHUD()->ShowThought(LOCTEXT("PcAgain", "\"Like and subscribe.\" Yeah. Sure."), 3.f);
				}
				else
				{
					G->RequestTutorial();
				}
			}
		});

	// Notebook
	AddInteractable(FVector(-213, -20, 78), FVector(14, 16, 6),
		[GM]()
		{
			const ADPGameMode* G = GM();
			return (G && G->HasFlag(TEXT("tutorial_done"))) ? LOCTEXT("NbTake", "Take the notebook") : LOCTEXT("NbLook", "Notebook");
		},
		[GM, WeakThis](ADPCharacter*)
		{
			ADPGameMode* G = GM();
			if (!G)
			{
				return;
			}
			if (!G->HasFlag(TEXT("tutorial_done")))
			{
				G->GetDPHUD()->ShowThought(LOCTEXT("NbEmpty", "My dream journal. Empty, mostly. Tonight that changes."), 3.5f);
				return;
			}
			G->SetFlag(TEXT("has_notebook"));
			if (WeakThis.IsValid())
			{
				WeakThis->SetDeskNotebookVisible(false);
			}
			G->GetDPHUD()->ShowHint(LOCTEXT("NbHint", "Read the notebook any time: N"), 6.f);
		},
		[GM]()
		{
			const ADPGameMode* G = GM();
			return G && !G->HasFlag(TEXT("has_notebook"));
		});

	// Bed
	AddInteractable(FVector(200, -100, 50), FVector(55, 100, 25),
		[]() { return LOCTEXT("Sleep", "Go to sleep"); },
		[GM](ADPCharacter*)
		{
			ADPGameMode* G = GM();
			if (!G)
			{
				return;
			}
			if (!G->HasFlag(TEXT("tutorial_done")))
			{
				G->GetDPHUD()->ShowThought(LOCTEXT("NotYet", "Not yet. I want to finish that video first."), 3.f);
			}
			else if (!G->HasFlag(TEXT("has_notebook")))
			{
				G->GetDPHUD()->ShowThought(LOCTEXT("TakeNb", "The notebook. I should keep it close tonight."), 3.f);
			}
			else
			{
				G->RequestSleep();
			}
		});

	// The covered mirror
	AddInteractable(FVector(190, 140, 125), FVector(8, 34, 48),
		[]() { return LOCTEXT("Mirror", "Wardrobe mirror"); },
		[GM](ADPCharacter*)
		{
			if (ADPGameMode* G = GM())
			{
				G->GetDPHUD()->ShowThought(LOCTEXT("Towel", "There's a towel hanging over the mirror. You leave it there."), 3.5f);
			}
		});

	// Door
	AddInteractable(FVector(150, -214, 100), FVector(46, 8, 100),
		[]() { return LOCTEXT("Door", "Door"); },
		[GM](ADPCharacter*)
		{
			if (ADPGameMode* G = GM())
			{
				G->GetDPHUD()->ShowThought(LOCTEXT("Late", "It's late. Everyone's asleep."), 2.5f);
			}
		});

	// Window
	AddInteractable(FVector(60, 222, 145), FVector(70, 8, 55),
		[]() { return LOCTEXT("Window", "Window"); },
		[GM](ADPCharacter*)
		{
			if (ADPGameMode* G = GM())
			{
				G->GetDPHUD()->ShowThought(LOCTEXT("Night", "Quiet street. Somebody left a light on across the road."), 3.f);
			}
		});
}

void ADPBedroomZone::OnPlayerEntered(ADPCharacter* Player, bool bFromSave)
{
	ADPGameMode* G = GetGameMode();
	if (G && G->HasFlag(TEXT("has_notebook")))
	{
		SetDeskNotebookVisible(bWakingVariant);
	}
	if (bWakingVariant)
	{
		SetDeskNotebookVisible(true);
	}
}

void ADPBedroomZone::SetDeskNotebookVisible(bool bVisible)
{
	if (DeskNotebook)
	{
		DeskNotebook->SetVisibility(bVisible);
	}
}

#undef LOCTEXT_NAMESPACE
