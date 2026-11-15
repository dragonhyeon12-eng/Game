#pragma once

#include "CoreMinimal.h"
#include "Engine/GameInstance.h"
#include "DPGameInstance.generated.h"

class UDPSettingsSave;

/** Owns settings and session-wide counters that must survive in-place game resets. */
UCLASS()
class DREAMPROTOCOL_API UDPGameInstance : public UGameInstance
{
	GENERATED_BODY()

public:
	virtual void Init() override;

	UDPSettingsSave* GetSettings() const { return Settings; }
	void SaveSettings();

	// Session-scoped pause-menu horror bookkeeping (kept rare on purpose).
	int32 CorruptedMenusShown = 0;
	double LastCorruptedMenuTime = -1000.0;
	bool bSelfUnpauseUsed = false;

private:
	UPROPERTY()
	TObjectPtr<UDPSettingsSave> Settings;
};
