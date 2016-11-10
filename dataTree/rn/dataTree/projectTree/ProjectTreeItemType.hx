package rn.dataTree.projectTree;

@:enum abstract ProjectTreeItemType(Int) {
	var ProjectItem:Dynamic = 0;
	var DirectoryItem:Dynamic = 1;
	var FileItem:Dynamic = 2;
}
