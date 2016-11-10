package rn.dataTree.flatTree;

import sys.io.File;
import sys.FileSystem;
import haxe.Serializer;
import haxe.Unserializer;

import rn.typext.hlp.FileSystemHelper;

using rn.typext.ext.ArrayExtender;
using rn.typext.ext.StringExtender;

class FlatTree {
	public var itemsList:Array<FlatTreeItem>;
	
	public var length (get, null) : Int;
	function get_length () : Int return this.itemsList.length;
	
	public function new () this.itemsList = new Array<FlatTreeItem>();
	
	public function iterateChildsOf (currIndex:Int, childIndexHandler = null, sortHandler = null) : Int {
		var length = 0;
		var lvl:Int = this.itemsList[currIndex].level;
		
		while ((++currIndex) < this.itemsList.length) {
			if (this.itemsList[currIndex].level <= lvl || (sortHandler == null ? false : sortHandler(currIndex)))
				break;
			
			if (childIndexHandler != null)
				childIndexHandler(currIndex);
			
			length++;
		}
		
		return length;
	}
	
	public function copyTo (srcIndex:Int, destIndex:Int) : Bool {
		var cpItemsList:Array<Dynamic> = new Array<Dynamic>();
		
		var cpItem:FlatTreeItem = Reflect.copy(this.itemsList[srcIndex]);
		cpItem.setParent(null);
		cpItemsList.push({"currItem": cpItem});
		
		var lastLevel:Int = 0;
		var lastParent:FlatTreeItem = cpItem;
		
		this.iterateChildsOf(srcIndex, function (childIndex:Int) {
			cpItem = Reflect.copy(this.itemsList[childIndex]);
			var lvlDiff:Int = cpItem.level - lastLevel;
			
			if (lvlDiff < 0) {
				lvlDiff = cast(Math.abs(lvlDiff), Int);
				lastLevel -= lvlDiff;
				
				while ((lvlDiff--) > 0)
					lastParent = lastParent.getParent();
			}
			else if (lvlDiff > 0) {
				lastParent = cpItemsList[cpItemsList.length - 1].currItem;
				lastLevel = cpItem.level;
			}
			
			cpItemsList.push({"currItem": cpItem, "oldParent": cpItem.getParent()});
			cpItem.setParent(lastParent);
		});
		
		cpItemsList.reverse();
		destIndex = this.addItemTo(cpItemsList.pop().currItem, destIndex);
		
		while (cpItemsList.length > 0) {
			var cpData:Dynamic = cpItemsList.pop();
			cpData.currItem.setParent(cpData.currItem.getParent());
			
			this.itemsList.insert(++destIndex, cpData.currItem);
		}
		
		return true;
	}
	
	public function moveToWithSort (srcIndex:Int, destIndex:Int, sortHandler = null) : Int {
		var parentIndex = destIndex;
		destIndex += this.iterateChildsOf(destIndex, null, sortHandler) + 1;
		
		if (destIndex > -1) {
			var itemsToMove:Array<Int> = new Array<Int>();
			itemsToMove.push(srcIndex);
			
			this.iterateChildsOf(srcIndex, function (childIndex:Int) itemsToMove.push(childIndex));
			
			itemsToMove.reverse();
			
			var moveIndex:Int = itemsToMove.pop();
			this.itemsList[moveIndex].setParent(this.itemsList[parentIndex]);
			this.itemsList.moveTo(moveIndex, destIndex);
			
			while (itemsToMove.length > 0) {
				moveIndex = itemsToMove.pop();
				this.itemsList[moveIndex].setParent(this.itemsList[moveIndex].getParent());
				this.itemsList.moveTo(moveIndex, ++destIndex);
			}
		}
		
		return destIndex;
	}
	
	public function addItemTo (item:FlatTreeItem, destIndex:Int) : Int
		return this.moveToWithSort(this.itemsList.push(item) - 1, destIndex);
	
	public function saveTreeToFile (treePath:String) : Void {
		var s:Serializer = new Serializer();
		s.useCache = true;
		s.serialize(this.itemsList);
		
		File.saveContent(treePath, s.toString());
	}
	
	public function loadTreeFromFile (treePath:String) : Void
		if (FileSystem.exists(treePath))
			this.itemsList = new Unserializer(File.getContent(treePath)).unserialize();
}
