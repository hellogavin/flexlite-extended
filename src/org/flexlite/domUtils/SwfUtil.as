package org.flexlite.domUtils
{
	import com.codeazur.as3swf.SWF;
	import com.codeazur.as3swf.data.SWFFillStyle;
	import com.codeazur.as3swf.data.SWFScene;
	import com.codeazur.as3swf.data.SWFShapeRecord;
	import com.codeazur.as3swf.data.SWFShapeRecordStyleChange;
	import com.codeazur.as3swf.data.SWFShapeWithStyle;
	import com.codeazur.as3swf.data.SWFSymbol;
	import com.codeazur.as3swf.tags.IDefinitionTag;
	import com.codeazur.as3swf.tags.ITag;
	import com.codeazur.as3swf.tags.TagDefineBits;
	import com.codeazur.as3swf.tags.TagDefineBitsJPEG2;
	import com.codeazur.as3swf.tags.TagDefineBitsLossless;
	import com.codeazur.as3swf.tags.TagDefineSceneAndFrameLabelData;
	import com.codeazur.as3swf.tags.TagDefineShape;
	import com.codeazur.as3swf.tags.TagDefineShape4;
	import com.codeazur.as3swf.tags.TagDefineSprite;
	import com.codeazur.as3swf.tags.TagDoABC;
	import com.codeazur.as3swf.tags.TagEnd;
	import com.codeazur.as3swf.tags.TagFileAttributes;
	import com.codeazur.as3swf.tags.TagMetadata;
	import com.codeazur.as3swf.tags.TagPlaceObject;
	import com.codeazur.as3swf.tags.TagSetBackgroundColor;
	import com.codeazur.as3swf.tags.TagShowFrame;
	import com.codeazur.as3swf.tags.TagSymbolClass;
	
	import flash.utils.ByteArray;
	
	/**
	 * SWF文件操作工具类
	 * @author DOM
	 */
	public class SwfUtil
	{
		/**
		 * 合并指定的SWF文件字节流列表，导出的SWF移除了所有添加在舞台上的显示对象。
		 */		
		public static function mergeBytes(swfBytesList:Array):ByteArray
		{
			if(!swfBytesList||swfBytesList.length==0)
				return null;
			var infoList:Vector.<TagInfo> = new Vector.<TagInfo>();
			for each(var bytes:ByteArray in swfBytesList)
			{
				infoList.push(getTagInfo(bytes));
			}
			var characterId:int = 1;
			var tags:Array = [];
			var abcTags:Array = [];
			var symbolTag:TagSymbolClass = new TagSymbolClass();
			for each(var info:TagInfo in infoList)
			{
				characterId = updateId(info,characterId);
				tags = tags.concat(info.tags);
				abcTags = abcTags.concat(info.abcTags);
				for each(var symbol:SWFSymbol in info.symbolTag.symbols)
				{
					symbolTag.symbols.push(symbol);
				}
			}
			
			tags = tags.concat(abcTags);
			if(symbolTag.symbols.length>0)
				tags.push(symbolTag);
			tags.push(new TagShowFrame);
			tags.push(new TagEnd);
			tags.splice(0,0,new TagFileAttributes());
			
			var newSwf:SWF = new SWF();
			for each(var tag:ITag in tags)
			{
				newSwf.tags.push(tag);
			}
			var newBytes:ByteArray = new ByteArray();
			newSwf.publish(newBytes);
			return newBytes;
		}
		/**
		 * 从字节流内获取标签信息
		 */		
		private static function getTagInfo(bytes:ByteArray):TagInfo
		{
			var swf:SWF = new SWF(bytes);
			var tags:Vector.<ITag> = swf.tags;
			var length:int = tags.length;
			var tag:ITag;
			var info:TagInfo = new TagInfo();
			for(var i:int=0;i<length;i++)
			{
				tag = tags[i];
				if(tag is TagFileAttributes||tag is TagMetadata||tag is TagShowFrame||tag is TagEnd||
					tag is TagDefineSceneAndFrameLabelData||tag is TagSetBackgroundColor||tag is TagPlaceObject)
				{
					continue;
				}
				if(tag is TagSymbolClass)
					info.symbolTag = tag as TagSymbolClass;
				else if(tag is TagDoABC)
					info.abcTags.push(tag);
				else
					info.tags.push(tag);
			}
			if(!info.symbolTag)
				info.symbolTag = new TagSymbolClass();
			return info;
		}
		/**
		 * 更新标签列表的characterId
		 */		
		private static function updateId(info:TagInfo,characterId:uint=1):uint
		{
			var tag:Object;
			for each(tag in info.tags)
			{
				if(tag  is IDefinitionTag)
				{
					var isBitmap:Boolean = (tag is TagDefineBits||tag is TagDefineBitsLossless);
					replaceId(info,IDefinitionTag(tag).characterId,characterId,isBitmap);
					IDefinitionTag(tag).characterId = characterId;
					characterId++;
				}
			}
			return characterId;
		}
		/**
		 * 替换引用的characterId
		 */		
		private static function replaceId(info:TagInfo,oldId:uint,newId:uint,checkShape:Boolean=false):void
		{
			var tag:Object;
			for each(tag in info.tags)
			{
				if(tag is TagDefineSprite)
				{
					for each(tag in TagDefineSprite(tag).tags)
					{
						if(tag is TagPlaceObject&&TagPlaceObject(tag).characterId==oldId)
						{
							TagPlaceObject(tag).characterId = newId;
						}
					}
				}
				else if(checkShape&&tag is TagDefineShape)
				{
					var shapes:SWFShapeWithStyle = TagDefineShape(tag).shapes;
					var fillStyle:SWFFillStyle;
					for each(fillStyle in shapes.initialFillStyles)
					{
						checkSwfFillStyle(fillStyle,oldId,newId);
					}
					var record:SWFShapeRecord;
					for each(record in shapes.records)
					{
						if(record is SWFShapeRecordStyleChange)
						{
							for each(fillStyle in SWFShapeRecordStyleChange(record).fillStyles)
							{
								checkSwfFillStyle(fillStyle,oldId,newId);
							}
						}
					}
				}
			}
			var symbol:SWFSymbol;
			for each(symbol in info.symbolTag.symbols)
			{
				if(symbol.tagId==oldId)
					symbol.tagId = newId;
			}
			
			function checkSwfFillStyle(fillStyle:SWFFillStyle,oldId:uint,newId:uint):void
			{
				var type:uint = fillStyle.type;
				if(fillStyle.bitmapId==oldId&&(type==0x40||type==0x41||type==0x42||type==0x43))
				{
					fillStyle.bitmapId = newId;
				}
			}
		}
		
		/**
		 * 从一个SWF文件字节流里提取指定列表的导出类,返回新的SWF文件字节流,若所有类名都不存在，返回null。
		 * @param bytes 要从中提取类定义的SWF字节流
		 * @param symbols 要提取导出类名列表
		 */		
		public static function extractSymbols(bytes:ByteArray,symbols:Array):ByteArray
		{
			var oldSwf:SWF = new SWF(bytes);
			var oldTags:Vector.<ITag> = oldSwf.tags;
			var length:int = oldTags.length;
			var i:int = 0;
			var symbolTag:TagSymbolClass;
			var tag:ITag;
			for(i=0;i<length;i++)
			{
				if(oldTags[i] is TagSymbolClass)
				{
					symbolTag = oldTags[i] as TagSymbolClass;
					break;
				}
			}
			length = symbolTag.symbols.length;
			var symbol:SWFSymbol;
			var newSymbolTag:TagSymbolClass = new TagSymbolClass();
			var abcTagList:Array = [];
			for(i=0;i<length;i++)
			{
				symbol = symbolTag.symbols[i];
				if(symbols.indexOf(symbol.name)!=-1)
				{
					newSymbolTag.symbols.push(symbol);
					var tagBytes:ByteArray = createAbcBytesForSymbol(symbol.name);
					abcTagList.push(TagDoABC.create(tagBytes,symbol.name));
				}
			}
			if(newSymbolTag.symbols.length==0)
				return null;
			var newTags:Array = [];
			for each(symbol in newSymbolTag.symbols)
			{
				getTags(oldSwf,symbol.tagId,newTags);
			}
			newTags.sort(compareFunction);
			newTags = newTags.concat(abcTagList);
			newTags.push(newSymbolTag);
			newTags.push(new TagShowFrame);
			newTags.push(new TagEnd);
			newTags.splice(0,0,new TagFileAttributes());
			
			var newSwf:SWF = new SWF();
			for each(tag in newTags)
			{
				newSwf.tags.push(tag);
			}
			var newBytes:ByteArray = new ByteArray();
			newSwf.publish(newBytes);
			return newBytes;
			
			function compareFunction(tagA:ITag,tagB:ITag):int
			{
				return tagA["characterId"]-tagB["characterId"];
			}
		}
		/**
		 * 根据characterId获取一个标签及其所有引用的子标签列表
		 */		
		private static function getTags(swf:SWF,tagId:uint,tags:Array):void
		{
			var tag:ITag = swf.getCharacter(tagId);
			if(tag is TagDefineSprite)
			{
				for each(var childTag:ITag in (tag as TagDefineSprite).tags)
				{
					if(childTag is TagPlaceObject)
					{
						getTags(swf,(childTag as TagPlaceObject).characterId,tags);
					}
				}
			}
			if(tags.indexOf(tag)==-1)
				tags.push(tag);
		}
		
		/**
		 * 为指定的导出类名生成一个abc文件字节流
		 */		
		private static function createAbcBytesForSymbol(symbol:String):ByteArray
		{
			var abcBytes:ByteArray = new ByteArray();
			abcBytes.writeBytes(symbolStartBytes);
			
			var remaining:uint = symbol.length;
			var bytesWritten:uint;
			var currentByte:uint;
			var shouldContinue:Boolean = true;
			var filter:uint = ~0 >>> -7;
			while(shouldContinue && bytesWritten < 5)
			{
				currentByte = remaining & filter;
				remaining = remaining >> 7;
				if(remaining > 0)
				{
					currentByte = currentByte | (1 << 7);
				}
				abcBytes.writeByte(currentByte);
				shouldContinue = remaining > 0;
				bytesWritten++;
			}
			abcBytes.writeUTFBytes(symbol);
			
			abcBytes.writeBytes(symbolEndBytes);
			abcBytes.position = 0;
			return abcBytes;
		}
		
		/**
		 * 模板abc文件头部分
		 */		
		private static var symbolStartFile:Array = [0x10,0x0,0x2e,0x0,0x0,0x0,0x0,0xc,0x0];
		/**
		 * 模板abc文件结尾部分
		 */		
		private static var symbolEndFile:Array = [
			0xd,0x66,0x6c,0x61,0x73,0x68,0x2e,0x64,0x69,0x73,0x70,0x6c,0x61,0x79,0x9
			,0x4d,0x6f,0x76,0x69,0x65,0x43,0x6c,0x69,0x70,0x6,0x4f,0x62,0x6a,0x65,0x63,0x74
			,0xc,0x66,0x6c,0x61,0x73,0x68,0x2e,0x65,0x76,0x65,0x6e,0x74,0x73,0xf,0x45,0x76
			,0x65,0x6e,0x74,0x44,0x69,0x73,0x70,0x61,0x74,0x63,0x68,0x65,0x72,0xd,0x44,0x69
			,0x73,0x70,0x6c,0x61,0x79,0x4f,0x62,0x6a,0x65,0x63,0x74,0x11,0x49,0x6e,0x74,0x65
			,0x72,0x61,0x63,0x74,0x69,0x76,0x65,0x4f,0x62,0x6a,0x65,0x63,0x74,0x16,0x44,0x69
			,0x73,0x70,0x6c,0x61,0x79,0x4f,0x62,0x6a,0x65,0x63,0x74,0x43,0x6f,0x6e,0x74,0x61
			,0x69,0x6e,0x65,0x72,0x6,0x53,0x70,0x72,0x69,0x74,0x65,0x5,0x16,0x1,0x16,0x3
			,0x18,0x2,0x16,0x6,0x0,0x9,0x7,0x1,0x2,0x7,0x2,0x4,0x7,0x1,0x5,0x7
			,0x4,0x7,0x7,0x2,0x8,0x7,0x2,0x9,0x7,0x2,0xa,0x7,0x2,0xb,0x3,0x0
			,0x0,0x0,0x0,0x0,0x0,0x0,0x0,0x0,0x0,0x0,0x0,0x0,0x1,0x1,0x2,0x8
			,0x3,0x0,0x1,0x0,0x0,0x0,0x1,0x2,0x1,0x1,0x4,0x1,0x0,0x3,0x0,0x1
			,0x1,0x9,0xa,0x3,-0x30,0x30,0x47,0x0,0x0,0x1,0x1,0x1,0xa,0xb,0x6,-0x30
			,0x30,-0x30,0x49,0x0,0x47,0x0,0x0,0x2,0x2,0x1,0x1,0x9,0x27,-0x30,0x30,0x65
			,0x0,0x60,0x3,0x30,0x60,0x4,0x30,0x60,0x5,0x30,0x60,0x6,0x30,0x60,0x7,0x30
			,0x60,0x8,0x30,0x60,0x2,0x30,0x60,0x2,0x58,0x0,0x1d,0x1d,0x1d,0x1d,0x1d,0x1d
			,0x1d,0x68,0x1,0x47,0x0,0x0];
		
		/**
		 * 模板abc文件头部分字节流
		 */		
		private static var symbolStartBytes:ByteArray = arrayToBytes(symbolStartFile);
		/**
		 * 模板abc文件结尾部分字节流
		 */		
		private static var symbolEndBytes:ByteArray = arrayToBytes(symbolEndFile);
		
		/**
		 * 数组转换成字节流
		 */		
		private static function arrayToBytes(fileArray:Array):ByteArray
		{
			var bytes:ByteArray = new ByteArray();
			var length:int = fileArray.length;
			for(var i:int=0;i<length;i++)
			{
				bytes.writeByte(fileArray[i]);
			}
			return bytes;
		}
		
	}
}
import com.codeazur.as3swf.tags.ITag;
import com.codeazur.as3swf.tags.TagDoABC;
import com.codeazur.as3swf.tags.TagSymbolClass;

class TagInfo
{
	public function TagInfo()
	{
	}
	
	public var tags:Array = [];
	
	public var abcTags:Array = [];
	
	public var symbolTag:TagSymbolClass;
}