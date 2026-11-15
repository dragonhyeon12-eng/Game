using UnrealBuildTool;

public class DreamProtocolTarget : TargetRules
{
	public DreamProtocolTarget(TargetInfo Target) : base(Target)
	{
		Type = TargetType.Game;
		DefaultBuildSettings = BuildSettingsVersion.Latest;
		IncludeOrderVersion = EngineIncludeOrderVersion.Latest;
		ExtraModuleNames.Add("DreamProtocol");
	}
}
