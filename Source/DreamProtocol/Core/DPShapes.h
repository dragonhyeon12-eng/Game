#pragma once

#include "CoreMinimal.h"

class UStaticMesh;
class UMaterialInterface;
class UMaterialInstanceDynamic;
class UStaticMeshComponent;

/** Engine basic shapes. Every shape is 100cm across and centred on its pivot. */
enum class EDPShape : uint8
{
	Cube,
	Sphere,
	Cylinder,
	Cone,
	Plane
};

/**
 * Helpers for building geometry out of engine primitives at runtime, so the prototype runs without
 * any authored art. Art can replace these later without touching gameplay code.
 */
namespace DPShapes
{
	DREAMPROTOCOL_API UStaticMesh* GetMesh(EDPShape Shape);
	DREAMPROTOCOL_API EDPShape ParseShape(const FString& Name);

	/** /Engine/BasicShapes/BasicShapeMaterial: a lit material with a "Color" vector parameter. */
	DREAMPROTOCOL_API UMaterialInterface* GetBaseMaterial();

	/**
	 * Optional art override: if /Game/DreamProtocol/Materials/<Name> exists it is returned, otherwise null.
	 * Lets an artist drop in e.g. M_ObserverVoid without code changes.
	 */
	DREAMPROTOCOL_API UMaterialInterface* FindArtOverride(const TCHAR* Name);

	DREAMPROTOCOL_API UMaterialInstanceDynamic* MakeColorMaterial(UObject* Outer, const FLinearColor& Color);

	/** Create, attach and register a static mesh component. */
	DREAMPROTOCOL_API UStaticMeshComponent* AddShape(AActor* Owner, USceneComponent* Parent, EDPShape Shape,
		const FTransform& RelativeTransform, UMaterialInterface* Material, bool bCollision);

	/** Scale that turns a 100cm cube into Size (cm). */
	inline FVector CubeScale(const FVector& Size) { return Size / 100.f; }
}
