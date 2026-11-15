#include "Audio/DPSynthSound.h"
#include "Components/AudioComponent.h"
#include "GameFramework/Actor.h"

namespace
{
	constexpr int32 GSampleRate = 48000;
	constexpr float GTwoPi = 6.28318530718f;

	/** Sine of a double-precision phase, so long-running voices keep their pitch accurate. */
	FORCEINLINE float Sn(double X) { return static_cast<float>(FMath::Sin(X)); }
}

UDPSynthSound::UDPSynthSound(const FObjectInitializer& ObjectInitializer)
	: Super(ObjectInitializer)
{
	SetSampleRate(GSampleRate);
	NumChannels = 1;
	Duration = INDEFINITELY_LOOPING_DURATION;
	bLooping = true;
	SoundGroup = SOUNDGROUP_Default;
}

void UDPSynthSound::Configure(EDPSynthVoice InVoice, int32 Seed)
{
	Voice = InVoice;
	RngState = static_cast<uint32>(Seed) * 2654435761u + 1u;
}

void UDPSynthSound::Trigger(EDPSynthEvent Event, float Strength)
{
	Pending.Enqueue(FQueuedEvent{ Event, Strength });
}

UAudioComponent* UDPSynthSound::CreateComponent(AActor* Owner, USceneComponent* AttachTo, EDPSynthVoice InVoice,
	bool bSpatial, float FalloffDistance, UDPSynthSound** OutSound, int32 Seed)
{
	check(Owner);
	UDPSynthSound* Sound = NewObject<UDPSynthSound>(Owner);
	Sound->Configure(InVoice, Seed);

	UAudioComponent* AC = NewObject<UAudioComponent>(Owner);
	AC->bAutoActivate = false;
	AC->bAllowSpatialization = bSpatial;
	if (bSpatial)
	{
		AC->bOverrideAttenuation = true;
		AC->AttenuationOverrides.bAttenuate = true;
		AC->AttenuationOverrides.bSpatialize = true;
		AC->AttenuationOverrides.DistanceAlgorithm = EAttenuationDistanceModel::NaturalSound;
		AC->AttenuationOverrides.AttenuationShapeExtents = FVector(150.f, 0.f, 0.f);
		AC->AttenuationOverrides.FalloffDistance = FalloffDistance;
	}
	if (AttachTo)
	{
		AC->SetupAttachment(AttachTo);
	}
	AC->SetSound(Sound);
	AC->RegisterComponent();
	Owner->AddInstanceComponent(AC);
	AC->Play();

	if (OutSound)
	{
		*OutSound = Sound;
	}
	return AC;
}

float UDPSynthSound::Rand01()
{
	// xorshift32
	RngState ^= RngState << 13;
	RngState ^= RngState >> 17;
	RngState ^= RngState << 5;
	return (RngState & 0x00FFFFFF) / 16777215.f;
}

float UDPSynthSound::Noise()
{
	return Rand01() * 2.f - 1.f;
}

int32 UDPSynthSound::OnGeneratePCMAudio(TArray<uint8>& OutAudio, int32 NumSamples)
{
	FQueuedEvent Q;
	while (Pending.Dequeue(Q))
	{
		FActiveEvent E;
		E.Type = Q.Type;
		E.Strength = Q.Strength;
		E.Freq = 2600.f + Rand01() * 1800.f;
		if (Active.Num() < 24)
		{
			Active.Add(E);
		}
	}

	OutAudio.Reset();
	OutAudio.AddZeroed(NumSamples * sizeof(int16));
	int16* Out = reinterpret_cast<int16*>(OutAudio.GetData());

	const float Dt = 1.f / GSampleRate;
	const float TargetLevel = Intensity.load();

	for (int32 i = 0; i < NumSamples; ++i)
	{
		SmoothedLevel += (TargetLevel - SmoothedLevel) * 0.0005f;
		float S = RenderVoice(Dt, SmoothedLevel);

		for (int32 e = Active.Num() - 1; e >= 0; --e)
		{
			bool bDone = false;
			S += RenderEvent(Active[e], Dt, bDone);
			if (bDone)
			{
				Active.RemoveAtSwap(e);
			}
		}

		Clock += Dt;
		Out[i] = static_cast<int16>(FMath::Clamp(S, -1.f, 1.f) * 32000.f);
	}
	return NumSamples;
}

float UDPSynthSound::RenderVoice(float Dt, float Level)
{
	const double T = Clock;
	switch (Voice)
	{
	case EDPSynthVoice::RoomTone:
	{
		Brown = (Brown + Noise() * 0.02f) * 0.998f;
		const float Fan = Sn(GTwoPi * 110.0 * T) * 0.004f + Sn(GTwoPi * 221.0 * T) * 0.002f;
		return (Brown * 0.18f + Fan) * Level;
	}
	case EDPSynthVoice::CityAmbience:
	{
		Lp1 += (Noise() - Lp1) * 0.015f;
		Lp2 += (Lp1 - Lp2) * 0.05f;
		const float Swell = 0.65f + 0.35f * Sn(GTwoPi * 0.05 * T);
		if (static_cast<float>(T) >= NextChirpTime)
		{
			// a short phrase of 2-4 chirps
			const int32 Count = 2 + static_cast<int32>(Rand01() * 3.f);
			for (int32 c = 0; c < Count && Active.Num() < 24; ++c)
			{
				FActiveEvent E;
				E.Type = EDPSynthEvent::Chirp;
				E.Time = -0.13f * c; // staggered start
				E.Strength = 0.6f + Rand01() * 0.4f;
				E.Freq = 2600.f + Rand01() * 1800.f;
				Active.Add(E);
			}
			NextChirpTime = static_cast<float>(T) + 1.5f + Rand01() * 5.f;
		}
		return Lp2 * 1.6f * Swell * Level;
	}
	case EDPSynthVoice::Water:
	{
		const float N = Noise();
		Lp1 += (N - Lp1) * 0.3f;
		const float Bright = N - Lp1; // high-passed
		const float Flutter = 0.7f + 0.3f * Sn(GTwoPi * 3.1 * T) * Sn(GTwoPi * 0.7 * T);
		return Bright * 0.06f * Flutter * Level;
	}
	case EDPSynthVoice::FluorescentHum:
	{
		const float W = GTwoPi * 120.f;
		const float Base = Sn(W * T);
		float Hum = Base * 0.5f + Sn(2.f * W * T) * 0.3f + Sn(3.f * W * T) * 0.15f;
		Hum += FMath::Clamp(Base * 4.f, -1.f, 1.f) * 0.08f; // ballast buzz
		float Crackle = 0.f;
		if (Rand01() < 0.00003f * Level)
		{
			Crackle = Noise() * 0.6f;
		}
		return (Hum * 0.035f + Crackle * 0.05f) * Level;
	}
	case EDPSynthVoice::Drone:
	{
		Lp1 += (Noise() - Lp1) * 0.004f;
		const float Wobble = 1.f + 0.004f * Sn(GTwoPi * 0.13 * T);
		const float D = Sn(GTwoPi * 55.0 * T) + Sn(GTwoPi * 55.6 * T) * 0.8f
			+ Sn(GTwoPi * 82.4 * Wobble * T) * 0.35f;
		return (D * 0.05f + Lp1 * 0.6f) * Level;
	}
	default:
		return 0.f;
	}
}

float UDPSynthSound::RenderEvent(FActiveEvent& E, float Dt, bool& bOutDone)
{
	E.Time += Dt;
	const float t = E.Time;
	if (t < 0.f)
	{
		return 0.f; // staggered start
	}

	const float S = E.Strength;
	switch (E.Type)
	{
	case EDPSynthEvent::FootstepHard:
	case EDPSynthEvent::FootstepSoft:
	{
		const bool bSoft = E.Type == EDPSynthEvent::FootstepSoft;
		E.Filter += (Noise() - E.Filter) * (bSoft ? 0.08f : 0.35f);
		bOutDone = t > 0.12f;
		return E.Filter * FMath::Exp(-t * (bSoft ? 38.f : 50.f)) * (bSoft ? 0.35f : 0.22f) * S;
	}
	case EDPSynthEvent::Knock:
	{
		// three knocks
		float Out = 0.f;
		const float Starts[3] = { 0.f, 0.3f, 0.58f };
		for (float St : Starts)
		{
			const float k = t - St;
			if (k >= 0.f && k < 0.25f)
			{
				Out += FMath::Sin(GTwoPi * 95.f * k) * FMath::Exp(-k * 26.f) + Noise() * FMath::Exp(-k * 120.f) * 0.4f;
			}
		}
		bOutDone = t > 0.9f;
		return Out * 0.45f * S;
	}
	case EDPSynthEvent::Thud:
	{
		E.Filter += (Noise() - E.Filter) * 0.05f;
		bOutDone = t > 1.3f;
		return (FMath::Sin(GTwoPi * 48.f * t) * FMath::Exp(-t * 5.f) * 0.7f + E.Filter * FMath::Exp(-t * 12.f) * 1.2f) * S;
	}
	case EDPSynthEvent::Chime:
	{
		const float Env = FMath::Min(1.f, t * 80.f) * FMath::Exp(-t * 2.4f);
		bOutDone = t > 1.8f;
		return (FMath::Sin(GTwoPi * 880.f * t) + 0.6f * FMath::Sin(GTwoPi * 1318.5f * t) + 0.4f * FMath::Sin(GTwoPi * 1760.f * t))
			* Env * 0.08f * S;
	}
	case EDPSynthEvent::Page:
	{
		const float N = Noise();
		E.Filter += (N - E.Filter) * 0.25f;
		const float Env = FMath::Sin(PI * FMath::Clamp(t / 0.32f, 0.f, 1.f));
		bOutDone = t > 0.32f;
		return (N - E.Filter) * Env * 0.14f * S;
	}
	case EDPSynthEvent::Whoosh:
	{
		const float Dur = 2.4f;
		const float Cut = 0.01f + 0.2f * FMath::Clamp(t / Dur, 0.f, 1.f);
		E.Filter += (Noise() - E.Filter) * Cut;
		bOutDone = t > Dur;
		return E.Filter * FMath::Sin(PI * FMath::Clamp(t / Dur, 0.f, 1.f)) * 0.9f * S;
	}
	case EDPSynthEvent::Bite:
	{
		const float Burst = (t < 0.05f || (t > 0.07f && t < 0.12f)) ? 1.f : 0.f;
		bOutDone = t > 0.14f;
		return Noise() * Burst * 0.12f * S;
	}
	case EDPSynthEvent::Chirp:
	{
		const float Dur = 0.08f;
		const float Env = FMath::Sin(PI * FMath::Clamp(t / Dur, 0.f, 1.f));
		const float F = E.Freq + 1400.f * (t / Dur);
		E.Phase += GTwoPi * F * Dt;
		bOutDone = t > Dur;
		return FMath::Sin(E.Phase) * Env * 0.035f * S;
	}
	default:
		bOutDone = true;
		return 0.f;
	}
}
