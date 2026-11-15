using UnrealBuildTool;

public class DreamProtocolEditorTarget : TargetRules
{
	public DreamProtocolEditorTarget(TargetInfo Target) : base(Target)
	{
		Type = TargetType.Editor;
		DefaultBuildSettings = BuildSettingsVersion.Latest;
		IncludeOrderVersion = EngineIncludeOrderVersion.Latest;
		ExtraModuleNames.Add("DreamProtocol");
	}
}
