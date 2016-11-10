package rn.dataTree.projectTree;

import rn.dataTree.flatTree.FlatTreeItem;

class ProjectTreeItem extends FlatTreeItem {
	public var tree:ProjectTree;
	public var type:ProjectItemType;
	public var title:String;
	public var path:String;
	public var isLink:Bool;
	
	public function new (tree:ProjectTree) {
		super();
		
		this.tree = tree;
		this.type = ProjectItemType.DirectoryItem;
		this.title = "";
		this.path = "";
		this.isLink = false;
	}
	
	public override function setParent (parent:Item) : Void {
		super.setParent(parent);
		
		if (parent != this && parent != null && this.path > "" && !this.isLink) {
			var oldPath:String = this.path;
			this.path = Path.join([parent == null ? "" : cast(parent, ProjectItem).path, Path.withoutDirectory(this.path)]);
			
			if (this.path != oldPath && tree != null) {
				var srcAbsPath:String = this.tree.getAbsolutePath(oldPath);
				var destAbsPath:String = this.tree.getAbsolutePath(this.path);
				
				if (FileSystem.exists(srcAbsPath) && !FileSystem.exists(destAbsPath))
					FileSystem.rename(srcAbsPath, destAbsPath);
			}
		}
	}
}
