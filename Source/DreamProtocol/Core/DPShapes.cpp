#include "Core/DPShapes.h"
#include "DreamProtocol.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/StaticMesh.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "Materials/MaterialInterface.h"
#include "GameFramework/Actor.h"
#include "Misc/PackageName.h"

namespace
{
	UStaticMesh* GMeshes[5] = { nullptr, nullptr, nullptr, nullptr, nullptr };
	UMaterialInterface* GBaseMaterial = nullptr;

	const TCHAR* MeshPath(EDPShape Shape)
	{
		switch (Shape)
		{
		case EDPShape::Sphere:   return TEXT("/Engine/BasicShapes/Sphere.Sphere");
		case EDPShape::Cylinder: return TEXT("/Engine/BasicShapes/Cylinder.Cylinder");
		case EDPShape::Cone:     return TEXT("/Engine/BasicShapes/Cone.Cone");
		case EDPShape::Plane:    return TEXT("/Engine/BasicShapes/Plane.Plane");
		case EDPShape::Cube:
		default:                 return TEXT("/Engine/BasicShapes/Cube.Cube");
		}
	}
}

UStaticMesh* DPShapes::GetMesh(EDPShape Shape)
{
	const int32 Index = static_cast<int32>(Shape);
	if (!GMeshes[Index])
	{
		GMeshes[Index] = LoadObject<UStaticMesh>(nullptr, MeshPath(Shape));
		if (GMeshes[Index])
		{
			GMeshes[Index]->AddToRoot(); // engine content, keep it resident for the session
		}
		else
		{
			UE_LOG(LogDream, Error, TEXT("Missing engine mesh %s"), MeshPath(Shape));
		}
	}
	return GMeshes[Index];
}

EDPShape DPShapes::ParseShape(const FString& Name)
{
	if (Name.Equals(TEXT("Sphere"), ESearchCase::IgnoreCase))   return EDPShape::Sphere;
	if (Name.Equals(TEXT("Cylinder"), ESearchCase::IgnoreCase)) return EDPShape::Cylinder;
	if (Name.Equals(TEXT("Cone"), ESearchCase::IgnoreCase))     return EDPShape::Cone;
	if (Name.Equals(TEXT("Plane"), ESearchCase::IgnoreCase))    return EDPShape::Plane;
	return EDPShape::Cube;
}

UMaterialInterface* DPShapes::GetBaseMaterial()
{
	if (!GBaseMaterial)
	{
		GBaseMaterial = LoadObject<UMaterialInterface>(nullptr, TEXT("/Engine/BasicShapes/BasicShapeMaterial.BasicShapeMaterial"));
		if (GBaseMaterial)
		{
			GBaseMaterial->AddToRoot();
		}
	}
	return GBaseMaterial;
}

UMaterialInterface* DPShapes::FindArtOverride(const TCHAR* Name)
{
	const FString Package = FString::Printf(TEXT("/Game/DreamProtocol/Materials/%s"), Name);
	if (!FPackageName::DoesPackageExist(Package))
	{
		return nullptr; // the normal case until art exists
	}
	return LoadObject<UMaterialInterface>(nullptr, *FString::Printf(TEXT("%s.%s"), *Package, Name));
}

UMaterialInstanceDynamic* DPShapes::MakeColorMaterial(UObject* Outer, const FLinearColor& Color)
{
	UMaterialInstanceDynamic* MID = UMaterialInstanceDynamic::Create(GetBaseMaterial(), Outer);
	if (MID)
	{
		MID->SetVectorParameterValue(TEXT("Color"), Color);
	}
	return MID;
}

UStaticMeshComponent* DPShapes::AddShape(AActor* Owner, USceneComponent* Parent, EDPShape Shape,
	const FTransform& RelativeTransform, UMaterialInterface* Material, bool bCollision)
{
	check(Owner);
	UStaticMeshComponent* Comp = NewObject<UStaticMeshComponent>(Owner);
	Comp->SetStaticMesh(GetMesh(Shape));
	if (Material)
	{
		Comp->SetMaterial(0, Material);
	}
	if (bCollision)
	{
		Comp->SetCollisionProfileName(TEXT("BlockAll"));
	}
	else
	{
		Comp->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	}
	Comp->SetupAttachment(Parent ? Parent : Owner->GetRootComponent());
	Comp->SetRelativeTransform(RelativeTransform);
	Comp->RegisterComponent();
	Owner->AddInstanceComponent(Comp);
	return Comp;
}
