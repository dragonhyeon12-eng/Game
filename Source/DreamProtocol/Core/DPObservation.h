#pragma once

#include "CoreMinimal.h"

/**
 * "Is the player looking at this?" - the foundation of every unobserved-change mechanic.
 *
 * A point counts as observed if a sphere around it overlaps the camera frustum (with a safety margin, so
 * changes never happen at the edge of the screen) and is not fully occluded by geometry.
 * The test is deliberately conservative: when in doubt, it reports "observed".
 */
namespace DPObservation
{
	struct FView
	{
		FVector Location = FVector::ZeroVector;
		FRotator Rotation = FRotator::ZeroRotator;
		float HalfFovH = 45.f; // degrees
		float HalfFovV = 30.f; // degrees
	};

	DREAMPROTOCOL_API bool GetPlayerView(const UWorld* World, FView& OutView);

	/** Frustum-only test. */
	DREAMPROTOCOL_API bool IsInView(const FView& View, const FVector& Point, float Radius, float MarginDegrees = 12.f);

	/** Frustum + occlusion test. Actors in IgnoreActors never occlude. */
	DREAMPROTOCOL_API bool IsObserved(const UWorld* World, const FVector& Point, float Radius,
		const TArray<const AActor*>& IgnoreActors = TArray<const AActor*>(), float MarginDegrees = 12.f);

	/** Line of sight from the player's eyes to a point (ignores frustum). */
	DREAMPROTOCOL_API bool HasLineOfSight(const UWorld* World, const FVector& Point, const TArray<const AActor*>& IgnoreActors = TArray<const AActor*>());
}
