package rn.dataTree.projectTree;

import haxe.Json;
import sys.io.File;
import haxe.io.Path;
import sys.io.Process;
import sys.FileSystem;

import rn.typext.hlp.SysHelper;
import rn.typext.hlp.FileSystemHelper;

using StringTools;
using rn.typext.ext.StringExtender;

class ProjectTemplate {
	public static function getClassName (projectTitle:String) : String
		return Path.withoutExtension(Path.withoutDirectory(projectTitle))
			.replace(" - ", "_")
			.multiSplit([" ", ".", ",", "	", "-", "(", ")", "+", "=", "~", "#", "%"]).map(function (s:String) return s.toCapitalLetterCase()).join("");
	
	public static function extract (tree:ProjectTree, templatePath:String, destIndex:Int, destName:String) : Bool {
		var templateConfig:Dynamic = Json.parse(File.getContent(Path.join([templatePath, "init.json"])));
		
		var templateVars:Dynamic = {
			title: "%title%",
			main: "%main%",
			osFamily: "%os%",
			cpuArch: "%cpuArch%",
			currWorkDir: "%cwd%",
			templateDir: "%td%",
			projectPath: "%proj%"
		};
		
		if (templateConfig.generic != null)
			if (templateConfig.generic.templateVars != null)
				for (varName in Reflect.fields(templateVars))
					if (Reflect.hasField(templateConfig.generic.templateVars, varName))
						Reflect.setField(templateVars, varName, Reflect.field(templateConfig.generic.templateVars, varName));
		
		var replceTemplateVars:Dynamic = function (arg:Dynamic) : Dynamic {
			if (Type.getClassName(Type.getClass(arg)) == "String")
				return cast(arg, String)
					.replace(templateVars.title, destName)
					.replace(templateVars.main, getClassName(destName))
					.replace(templateVars.osFamily, Sys.systemName().toLowerCase())
					.replace(templateVars.cpuArch, Std.string(SysHelper.getCpuArch()))
					.replace(templateVars.currWorkDir, Path.removeTrailingSlashes(Sys.getCwd()))
					.replace(templateVars.templateDir, Path.removeTrailingSlashes(templatePath))
					.replace(templateVars.projectPath, tree.projectPath);
			
			return arg;
		}
		
		var runCmd:Dynamic = function (configSection:Dynamic, cmdType:String) : Bool {
			var result:Bool = true;
			
			if (configSection != null)
				if (Reflect.field(configSection, cmdType) != null)
					for (commandSection in cast(Reflect.field(configSection, cmdType), Array<Dynamic>)) {
						var cwd:String = Sys.getCwd();
						Sys.setCwd(tree.getItemPathAt(destIndex));
						
						if (commandSection.checkResult)
							result = (new Process(
								replceTemplateVars(commandSection.cmd),
								commandSection.args.map(function (arg:Dynamic) return replceTemplateVars(arg))
							)).stdout.readAll().toString().trim() == "1";
						else
							Sys.command(
								replceTemplateVars(commandSection.cmd),
								commandSection.args.map(function (arg:Dynamic) return replceTemplateVars(arg))
							);
						
						Sys.setCwd(cwd);
						
						if (!result)
							break;
					}
			
			return result;
		}
		
		var addSettings:Dynamic = function (configSection:Dynamic) : Void
			if (configSection != null)
				if (configSection.settings != null)
					for (s in cast(configSection.settings, Array<Dynamic>))
						tree.config.setSetting(s[0], s[1], replceTemplateVars(s[2]));
		
		var platformConfig:Dynamic = Reflect.field(templateConfig.platforms, Sys.systemName().toLowerCase());
		
		if (templateConfig.platforms != null)
			if (!runCmd(templateConfig.platforms.all, "before") || !runCmd(platformConfig, "before"))
				return null;
		
		var destDir:String = tree.getAbsolutePath(cast(tree.itemsList[destIndex], ProjectTreeItem).path);
		
		if (FileSystem.exists(Path.join([templatePath, "files"])))
			for (tFile in FileSystem.readDirectory(Path.join([templatePath, "files"]))) {
				FileSystemHelper.copy(
					Path.join([templatePath, "files", tFile]),
					Path.addTrailingSlash(destDir),
					replceTemplateVars,
					function (file:String) if (!FileSystem.isDirectory(file)) File.saveContent(file, replceTemplateVars(File.getContent(file)))
				);
				
				tree.addFileTo(Path.join([destDir, replceTemplateVars(tFile)]), false, destIndex);
			}
		
		if (templateConfig.platforms != null) {
			addSettings(templateConfig.platforms.all);
			addSettings(platformConfig);
			tree.config.saveToFile(Path.withExtension(tree.projectPath, "json"));
		}
		
		tree.save();
		
		if (templateConfig.platforms != null)
			if (!runCmd(templateConfig.platforms.all, "after") || !runCmd(platformConfig, "after"))
				return null;
		
		return templateConfig;
	}
}
