package rn.dataTree.projectTree;

import haxe.Json;
import sys.io.File;
import sys.FileSystem;

class Config {
	private var configData:Dynamic;
	
	public function new (configPath:String = null)
		this.loadFromFile(configPath);
	
	public function getSettingStr (groupName:String, settingName:String) : String
		return cast(this.getSetting(groupName, settingName), String);
	
	public function getSettingInt (groupName:String, settingName:String) : Int
		return cast(this.getSetting(groupName, settingName), Int);
	
	public function getSettingFloat (groupName:String, settingName:String) : Float
		return cast(this.getSetting(groupName, settingName), Float);
	
	public function getSettingBool (groupName:String, settingName:String) : Bool
		return cast(this.getSetting(groupName, settingName), Bool);
	
	public function getSetting (groupName:String, settingName:String) : Dynamic
		return Reflect.field(Reflect.field(this.configData, groupName), settingName);
	
	public function setSetting (groupName:String, settingName:String, settingValue:Dynamic) : Void {
		if (!Reflect.hasField(this.configData, groupName))
			Reflect.setField(this.configData, groupName, { });
		
		Reflect.setField(Reflect.field(this.configData, groupName), settingName, settingValue);
	}
	
	public function saveToFile (configPath:String, indent:String = "	") : Void
		File.saveContent(configPath, Json.stringify(this.configData, null, indent));
	
	public function loadFromFile (configPath:String) : Void
		if (FileSystem.exists(configPath))
			this.configData = Json.parse(File.getContent(configPath));
}
