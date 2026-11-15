#pragma once

#include "CoreMinimal.h"
#include "Sound/SoundWaveProcedural.h"
#include "Containers/Queue.h"
#include <atomic>
#include "DPSynthSound.generated.h"

class UAudioComponent;

/** Continuous beds the synth can generate. */
UENUM()
enum class EDPSynthVoice : uint8
{
	Silence,        // event-only (foley)
	RoomTone,       // bedroom at night: low air + computer fan
	CityAmbience,   // soft wind/traffic wash + birdsong
	Water,          // fountain splash
	FluorescentHum, // 120Hz ballast hum with buzz
	Drone           // low dread drone, scaled by intensity
};

/** One-shot sounds mixed on top of the voice. */
UENUM()
enum class EDPSynthEvent : uint8
{
	FootstepHard,
	FootstepSoft,
	Knock,
	Thud,
	Chime,
	Page,
	Whoosh,
	Bite,
	Chirp
};

/**
 * A tiny procedural synthesizer, so the prototype has real (spatialized) audio without any sound assets.
 * The audio render thread calls OnGeneratePCMAudio; game-thread code only touches the atomic intensity
 * and the lock-free event queue.
 */
UCLASS()
class DREAMPROTOCOL_API UDPSynthSound : public USoundWaveProcedural
{
	GENERATED_BODY()

public:
	UDPSynthSound(const FObjectInitializer& ObjectInitializer);

	void Configure(EDPSynthVoice InVoice, int32 Seed = 1337);
	void SetIntensity(float Value) { Intensity.store(FMath::Clamp(Value, 0.f, 2.f)); }
	void Trigger(EDPSynthEvent Event, float Strength = 1.f);

	/**
	 * Creates an audio component playing a new synth voice.
	 * Spatial components attenuate over FalloffDistance; non-spatial ones are 2D.
	 */
	static UAudioComponent* CreateComponent(AActor* Owner, USceneComponent* AttachTo, EDPSynthVoice Voice,
		bool bSpatial, float FalloffDistance, UDPSynthSound** OutSound = nullptr, int32 Seed = 1337);

protected:
	virtual int32 OnGeneratePCMAudio(TArray<uint8>& OutAudio, int32 NumSamples) override;

private:
	struct FQueuedEvent
	{
		EDPSynthEvent Type;
		float Strength;
	};

	struct FActiveEvent
	{
		EDPSynthEvent Type = EDPSynthEvent::Chime;
		float Time = 0.f;
		float Strength = 1.f;
		float Phase = 0.f;
		float Freq = 0.f;
		float Filter = 0.f;
	};

	float RenderVoice(float Dt, float Level);
	float RenderEvent(FActiveEvent& E, float Dt, bool& bOutDone);
	float Noise();      // -1..1
	float Rand01();

	EDPSynthVoice Voice = EDPSynthVoice::Silence;
	std::atomic<float> Intensity{ 1.f };
	TQueue<FQueuedEvent, EQueueMode::Mpsc> Pending;

	// Audio-thread state.
	TArray<FActiveEvent> Active;
	uint32 RngState = 1337u;
	double Clock = 0.0;
	float Brown = 0.f;
	float Lp1 = 0.f;
	float Lp2 = 0.f;
	float NextChirpTime = 2.f;
	float SmoothedLevel = 0.f;
};
