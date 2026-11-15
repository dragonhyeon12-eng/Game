#include "Core/DPData.h"
#include "DreamProtocol.h"
#include "JsonObjectConverter.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"

namespace
{
	FDPDialogueFile GDialogue;
	FDPNotebookFile GNotebook;
	FDPManifestFile GManifest;
	FDPTutorialFile GTutorial;
	bool GLoaded = false;

	template <typename TStruct>
	bool LoadJsonStruct(const TCHAR* FileName, TStruct& Out)
	{
		const FString Path = FPaths::Combine(FPaths::ProjectContentDir(), TEXT("Data"), FileName);
		FString Json;
		if (!FFileHelper::LoadFileToString(Json, *Path))
		{
			UE_LOG(LogDream, Error, TEXT("Could not read data file %s"), *Path);
			return false;
		}

		TStruct Parsed;
		if (!FJsonObjectConverter::JsonObjectStringToUStruct(Json, &Parsed, 0, 0))
		{
			UE_LOG(LogDream, Error, TEXT("Could not parse data file %s (check the JSON syntax)"), *Path);
			return false;
		}
		Out = MoveTemp(Parsed);
		return true;
	}

	void EnsureLoaded()
	{
		if (!GLoaded)
		{
			FDPData::ReloadAll();
		}
	}
}

void FDPData::ReloadAll()
{
	LoadJsonStruct(TEXT("Dialogue.json"), GDialogue);
	LoadJsonStruct(TEXT("Notebook.json"), GNotebook);
	LoadJsonStruct(TEXT("Manifestations.json"), GManifest);
	LoadJsonStruct(TEXT("Tutorial.json"), GTutorial);
	GLoaded = true;

	UE_LOG(LogDream, Log, TEXT("Data loaded: %d dialogues, %d rules, %d manifestations, %d tutorial lines"),
		GDialogue.Dialogues.Num(), GNotebook.Rules.Num(), GManifest.Manifestations.Num(), GTutorial.Lines.Num());
}

const FDPDialogueFile& FDPData::Dialogue()       { EnsureLoaded(); return GDialogue; }
const FDPNotebookFile& FDPData::Notebook()       { EnsureLoaded(); return GNotebook; }
const FDPManifestFile& FDPData::Manifestations() { EnsureLoaded(); return GManifest; }
const FDPTutorialFile& FDPData::Tutorial()       { EnsureLoaded(); return GTutorial; }

const FDPDialogue* FDPData::FindDialogue(const FString& Id)
{
	return Dialogue().Dialogues.FindByPredicate([&Id](const FDPDialogue& D) { return D.Id == Id; });
}

const FDPRuleDef* FDPData::FindRule(const FString& Id)
{
	return Notebook().Rules.FindByPredicate([&Id](const FDPRuleDef& R) { return R.Id == Id; });
}

const FDPManifestDef* FDPData::FindManifest(const FString& Id)
{
	return Manifestations().Manifestations.FindByPredicate([&Id](const FDPManifestDef& M) { return M.Id == Id; });
}

FVector FDPData::ToVector(const TArray<float>& V, const FVector& Default)
{
	if (V.Num() == 1) return FVector(V[0]);
	if (V.Num() >= 3) return FVector(V[0], V[1], V[2]);
	return Default;
}

FRotator FDPData::ToRotator(const TArray<float>& V)
{
	return V.Num() >= 3 ? FRotator(V[0], V[1], V[2]) : FRotator::ZeroRotator;
}

FLinearColor FDPData::ToColor(const TArray<float>& V, const FLinearColor& Default)
{
	if (V.Num() >= 4) return FLinearColor(V[0], V[1], V[2], V[3]);
	if (V.Num() >= 3) return FLinearColor(V[0], V[1], V[2], 1.f);
	return Default;
}
