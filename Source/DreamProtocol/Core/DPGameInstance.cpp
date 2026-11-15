#include "Core/DPGameInstance.h"
#include "Core/DPSettings.h"
#include "Kismet/GameplayStatics.h"

void UDPGameInstance::Init()
{
	Super::Init();

	if (UGameplayStatics::DoesSaveGameExist(UDPSettingsSave::SlotName(), 0))
	{
		Settings = Cast<UDPSettingsSave>(UGameplayStatics::LoadGameFromSlot(UDPSettingsSave::SlotName(), 0));
	}
	if (!Settings)
	{
		Settings = Cast<UDPSettingsSave>(UGameplayStatics::CreateSaveGameObject(UDPSettingsSave::StaticClass()));
	}
}

void UDPGameInstance::SaveSettings()
{
	if (Settings)
	{
		UGameplayStatics::SaveGameToSlot(Settings, UDPSettingsSave::SlotName(), 0);
	}
}

const UDPSettingsSave& DPSettings::Get(const UObject* WorldContext)
{
	if (WorldContext)
	{
		if (const UWorld* World = WorldContext->GetWorld())
		{
			if (const UDPGameInstance* GI = Cast<UDPGameInstance>(World->GetGameInstance()))
			{
				if (GI->GetSettings())
				{
					return *GI->GetSettings();
				}
			}
		}
	}
	return *GetDefault<UDPSettingsSave>();
}
