package rn.dataTree.flatTree;

class FlatTreeItem {
	public  var level (default, null) : Int = 0;
	private var parent:FlatTreeItem = null;
	
	public function new () { }
	
	public function setParent (parent:FlatTreeItem) : Void {
		if (parent != this) {
			this.parent = parent;
			this.level = (this.parent == null ? -1 : this.parent.level) + 1;
		}
	}
	
	public function getParent () : FlatTreeItem return this.parent;
}
