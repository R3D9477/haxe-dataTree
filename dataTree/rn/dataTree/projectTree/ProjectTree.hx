package rn.dataTree.projectTree;

import haxe.Json;
import sys.io.File;
import haxe.io.Path;
import sys.io.Process;
import sys.FileSystem;
import haxe.io.Output;
import sys.io.FileInput;
import sys.io.FileOutput;
import haxe.io.BytesOutput;

import hxTypeExt.SysHelper;
import hxTypeExt.FileSystemHelper;

import rn.dataTree.flatTree.FlatTree;

using StringTools;
using hxTypeExt.StringExtender;

class ProjectTree extends FlatTree {
	public var projectPath:String;
	public var config:Config;
	
	public function new (projectPath:String) {
		super();
		
		projectPath = projectPath.replace("\\ ", " ");
		this.projectPath = Path.join([FileSystem.fullPath(Path.directory(projectPath)), Path.withoutDirectory(projectPath)]); // if project's file is not exists
		
		var configPath:String = Path.withExtension(this.projectPath, "json");
		
		if (!FileSystem.exists(configPath)) {
			if (FileSystem.exists(this.projectPath))
				FileSystem.deleteFile(this.projectPath);
			
			File.copy("ProjectDefaults.json", configPath);
		}
		
		this.config = new Config(configPath);
		
		var projDirPath:String = Path.withoutExtension(this.projectPath);
		var treePath:String = Path.withExtension(this.projectPath, "tree");
		
		if (!FileSystem.exists(projDirPath)) {
			FileSystem.createDirectory(projDirPath);
			
			if (FileSystem.exists(treePath))
				FileSystem.deleteFile(treePath);
		}
		
		if (!FileSystem.exists(treePath))
			this.loadTreeFromProjectDir();
		else
			this.loadTreeFromFile(treePath);
	}
	
	public function printMaskToFile () : Void {
		var maskFile:FileOutput = File.write(this.projectPath, false);
		this.printMaskToStream(maskFile);
		maskFile.close();
	}
	
	public function printMaskToString () : String {
		var maskString:BytesOutput = new BytesOutput();
		printMaskToStream(maskString);
		
		return maskString.getBytes().toString();
	}
	
	public function printMaskToStream (sOut:Output) : Void {
		var rnIndex:Int = this.itemsList.length;
		
		for (item in this.itemsList) {
			var pItem:ProjectItem = cast(item, ProjectItem);
			
			sOut.writeString(
				this.config.getSettingStr("vimStudio", "charSubitem").repeat(item.level) +
				
				this.config.getSettingStr("vimStudio",
					(switch(pItem.type) {
						case ProjectItemType.ProjectItem: "charProject_l";
						case ProjectItemType.DirectoryItem: "charDirectory_l";
						case ProjectItemType.FileItem: "charFile_l";
						default: "";
					})
				) +
				
				(FileSystem.exists(this.getAbsolutePath(pItem.path)) ? "" : this.config.getSettingStr("vimStudio", "charNotFound_l")) +
				
				(pItem.isLink ? this.config.getSettingStr("vimStudio", "charLink_l") : "") +
				
				pItem.title +
				
				(pItem.isLink ? this.config.getSettingStr("vimStudio", "charLink_r") : "") + 
				
				(FileSystem.exists(this.getAbsolutePath(pItem.path)) ? "" : this.config.getSettingStr("vimStudio", "charNotFound_r")) +
				
				this.config.getSettingStr("vimStudio",
					(switch(pItem.type) {
						case ProjectItemType.ProjectItem: "charProject_r";
						case ProjectItemType.DirectoryItem: "charDirectory_r";
						case ProjectItemType.FileItem: "charFile_r";
						default: "";
					})
				)
			);
			
			if ((--rnIndex) > 0)
				sOut.writeString("\r\n");
		}
	}
	
	public function getIndexByPath (fndPath:String) : Int {
		for (itemIndex in 0...this.itemsList.length)
			if (cast(this.itemsList[itemIndex], ProjectItem).path == fndPath)
				return itemIndex;
		
		return -1;
	}
	
	public function getAbsolutePath (itemPath:String) : String
		return Path.join([FileSystem.fullPath(Path.directory(this.projectPath)), itemPath]);
	
	public function getRelativePath (filePath:String) : String
		return FileSystemHelper.getRelativePath(Path.directory(this.projectPath), filePath);
	
	public function loadTreeFromProjectDir () : Void {
		while (this.itemsList.length > 0)
			this.itemsList.remove(this.itemsList[0]);
		
		this.addFileTo(Path.withoutExtension(this.projectPath), false, 0, true);
	}
	
	public function save () : Void {
		super.saveTreeToFile(Path.withExtension(this.projectPath, "tree"));
		this.printMaskToFile();
	}
	
	public override function addItemTo (item:Item, destIndex:Int) : Int
		return this.moveTo(this.itemsList.push(item) - 1, destIndex);
	
	public function moveTo (srcIndex:Int, destIndex:Int) : Int {
		var sortItemLevel:Int = this.itemsList[destIndex].level + 1;
		var sortItem:ProjectItem = cast(this.itemsList[srcIndex], ProjectItem);
		
		return super.moveToWithSort(srcIndex, destIndex, function (childIndex:Int) {
			var childItem:ProjectItem = cast(this.itemsList[childIndex], ProjectItem);
			
			var res:Bool = (childItem.level == sortItemLevel);
			
			var childItemType:Int = cast(childItem.type, Int);
			var sortItemType:Int = cast(sortItem.type, Int);
			
			if (res) {
				if (childItemType != sortItemType) {
					res = res &&
						(switch (this.config.getSettingInt("vimStudio", "sortByType")) {
							case 1: childItemType > sortItemType;
							case 2: childItemType < sortItemType;
							default: true;
						});
				}
				else {
					res = res &&
						(switch (this.config.getSettingInt("vimStudio", "sortByName")) {
							case 1: childItem.title > sortItem.title;
							case 2: childItem.title < sortItem.title;
							default: true;
						});
				}
			}
			
			return res;
		});
	}
	
	public function addFileTo (filePath:String, isLink:Bool, destIndex:Int, isProject:Bool = false) : Bool {
		if (!FileSystem.exists(filePath))
			return false;
		
		if (!isLink && !isProject)
			FileSystemHelper.copy(filePath, filePath = Path.join([this.getItemPathAt(destIndex), Path.withoutDirectory(filePath)]));
		
		var itemBuf:Array<Item> = new Array<Item>();
		
		if (this.itemsList.length > 0 && destIndex >= 0)
			itemBuf.push(this.itemsList[destIndex]);
		
		var addHidden:Bool = this.config.getSettingBool("vimStudio", "addHidden");
		
		FileSystemHelper.iterateFilesTree(filePath, function (currPath:String) : Void {
			if (FileSystemHelper.isHiddenFile(currPath) && !addHidden)
				return;
			
			var item:ProjectItem = new ProjectItem(this);
			item.isLink = isLink;
			item.path = this.getRelativePath(currPath);
			item.title = Path.withoutDirectory(currPath);
			item.type = isProject ? ProjectItemType.ProjectItem : FileSystem.isDirectory(currPath) ? ProjectItemType.DirectoryItem : ProjectItemType.FileItem;
			
			if (itemBuf.length > 0)
				if (destIndex < 0) {
					while (itemBuf.length > 1) {
						if (Path.directory(item.path) == cast(itemBuf[itemBuf.length - 1], ProjectItem).path)
							break;
						
						itemBuf.pop();
					}
					
					destIndex = this.itemsList.indexOf(itemBuf[itemBuf.length - 1]);
				}
			
			this.addItemTo(item, destIndex);
			
			if (item.type == ProjectItemType.ProjectItem || item.type == ProjectItemType.DirectoryItem)
				itemBuf.push(item);
			
			isProject = false;
			destIndex = -1;
		});
		
		return true;
	}
	
	public override function copyTo (srcIndex:Int, destIndex:Int) : Bool {
		FileSystemHelper.copy(
			this.getItemPathAt(srcIndex),
			Path.addTrailingSlash(this.getItemPathAt(destIndex))
		);
		
		return super.copyTo(srcIndex, destIndex);
	}
	
	public function renameFileItemAt (itemIndex:Int, newTitle:String) : Void {
		var item:ProjectItem = cast(this.itemsList[itemIndex], ProjectItem);
		var newItemPath:String = Path.addTrailingSlash(Path.join([Path.directory(item.path), newTitle]));
		var itemAbsPath:String = this.getAbsolutePath(item.path);
		
		if (FileSystem.exists(itemAbsPath))
			FileSystem.rename(itemAbsPath, this.getAbsolutePath(newItemPath));
		
		this.iterateChildsOf(itemIndex, function (childIndex:Int) : Void {
			var chItem:ProjectItem = cast(this.itemsList[childIndex], ProjectItem);
			
			if (!chItem.isLink)
				chItem.path = chItem.path.replace(Path.addTrailingSlash(item.path), newItemPath);
		});
		
		item.title = newTitle;
		item.path = Path.removeTrailingSlashes(this.getRelativePath(newItemPath));
	}
	
	public function rename (newTitle:String) : Void {
		this.renameFileItemAt(0, newTitle);
		
		var newProjectPath:String = Path.join([Path.directory(this.projectPath), Path.withExtension(newTitle, "visp")]);
		
		FileSystem.rename(this.projectPath, newProjectPath);
		FileSystem.rename(Path.withExtension(this.projectPath, "tree"), Path.withExtension(newProjectPath, "tree"));
		FileSystem.rename(Path.withExtension(this.projectPath, "json"), Path.withExtension(newProjectPath, "json"));
		
		this.projectPath = newProjectPath;
	}
	
	public function removeFileItemAt (itemIndex:Int, deleteFromDisk:Bool) : Void {
		var item:ProjectItem = cast(this.itemsList[itemIndex], ProjectItem);
		
		if (item.type == ProjectItemType.DirectoryItem || item.type == ProjectItemType.FileItem) {
			if (deleteFromDisk)
				FileSystemHelper.delete(this.getAbsolutePath(item.path));
			
			this.itemsList.splice(itemIndex, this.iterateChildsOf(itemIndex) + 1);
		}
	}
	
	public function getItemTypeAt (itemIndex:Int) : ProjectItemType
		return cast(this.itemsList[itemIndex], ProjectItem).type;
	
	public function getItemPathAt (itemIndex:Int) : String
		return this.getAbsolutePath(cast(this.itemsList[itemIndex], ProjectItem).path);
	
	public function execFileItemAt (itemIndex:Int) : Void
		FileSystemHelper.execUrl(this.getAbsolutePath(cast(this.itemsList[itemIndex], ProjectItem).path));
	
	public function execParentDirAt (itemIndex:Int) : Void
		FileSystemHelper.execUrl(Path.directory(this.getAbsolutePath(cast(this.itemsList[itemIndex], ProjectItem).path)));
	
	public function getChildsCountAt (itemIndex:Int) : Int {
		var count:Int = 0;
		
		var lvl:Int = this.itemsList[itemIndex].level + 1;
		
		this.iterateChildsOf(itemIndex, function (childIndex:Int) : Void {
			if (this.itemsList[childIndex].level == lvl)
				count++;
		}, null);
		
		return count;
	}
	
	public function searchTextAt (itemIndex:Int, searchJsonStr:String) : String {
		var currItem:ProjectItem = cast(this.itemsList[itemIndex], ProjectItem);
		var searchStruct:Dynamic = Json.parse(searchJsonStr.replace("&#34;", "\""));
		
		switch (currItem.type) {
			case ProjectItemType.FileItem:
				return FileSystemHelper.searchInFile(this.getAbsolutePath(currItem.path), searchStruct);
			case ProjectItemType.ProjectItem, ProjectItemType.DirectoryItem:
				var searchRes:String = "";
				this.iterateChildsOf(itemIndex, function (childIndex:Int) : Void {
					var chItem:ProjectItem = cast(this.itemsList[childIndex], ProjectItem);
					if (chItem.type == ProjectItemType.FileItem)
						searchRes += FileSystemHelper.searchInFile(this.getAbsolutePath(chItem.path), searchStruct);
				});
				return searchRes.substring(0, searchRes.length - 1);
			default:
				return "";
		}
	}
	
	public function delete () : Void {
		deleteProject(this.projectPath);
		
		this.projectPath = null;
		this.config = null;
		this.itemsList.splice(-1, 0);
	}
	
	public function extractTemplate (templatePath:String) : Bool {
		var templateConfig:Dynamic = ProjectTemplate.extract(this, templatePath, 0, Path.withoutDirectory(Path.withoutExtension(this.projectPath)));
		
		if (templateConfig == null)
			return false;
		
		if (templateConfig.settings != null)
			for (s in cast(templateConfig.settings, Array<Dynamic>))
				this.config.setSetting(s[0], s[1], s[2]);
		
		this.config.saveToFile(Path.withExtension(this.projectPath, "json"));
		
		return true;
	}
	
	public static function deleteProject (projectPath:String) : Void {
		FileSystemHelper.delete(projectPath);
		FileSystemHelper.delete(Path.join([Path.directory(projectPath), Path.withoutExtension(Path.withoutDirectory(projectPath))]));
		FileSystemHelper.delete(Path.withExtension(projectPath, "json"));
		FileSystemHelper.delete(Path.withExtension(projectPath, "tree"));
	}
}
