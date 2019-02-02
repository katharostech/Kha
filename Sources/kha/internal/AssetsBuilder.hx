package kha.internal;

import haxe.Json;
import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr;

#if macro
import sys.io.File;
#end

using StringTools;

typedef AssetFile = {
	name:String,
	files:Array<String>,
	type:String
}

class AssetsBuilder {
	public static function findResources(): String {
		#if macro
		var output = Compiler.getOutput();
		if (output == "Nothing__" || output == "") { // For Haxe background compilation
			#if kha_output
			output = Compiler.getDefine("kha_output");
			if (output.startsWith('"')) {
				output = output.substr(1, output.length - 2);
			}
			#end
		}
		output = output.replace("\\", "/");
		output = output.substring(0, output.lastIndexOf("/"));
		if (output.endsWith("/Assets")) { // For Unity
			output = output.substring(0, output.lastIndexOf("/"));
		}
		if (output.lastIndexOf("/") >= 0) {
			var system = output.substring(output.lastIndexOf("/") + 1);
			if (system.endsWith("-build")) system = system.substr(0, system.length - "-build".length);
			output = output.substring(0, output.lastIndexOf("/"));
			return output + "/" + system + "-resources/";
		}
		else {
			if (output.endsWith("-build")) output = output.substr(0, output.length - "-build".length);
			if (output == "") output = "empty";
			return output + "-resources/";
		}
		#else
		return "";
		#end
	}

	macro static public function build(type: String): Array<Field> {
		var fields = Context.getBuildFields();
		var content = Json.parse(File.getContent(findResources() + "files.json"));
		var files: Iterable<AssetFile> = content.files;

		var names = new Array<Expr>();

		for (file in files) {
			var name = file.name;
			var filename = file.files[0];

			if (file.type == type) {

				names.push(macro $v{name});

				switch (type) {
					case "image":
						fields.push({
							name: name,
							doc: null,
							meta: [],
							access: [APublic],
							kind: FVar(macro: kha.Image, macro null),
							pos: Context.currentPos()
						});
					case "sound":
						fields.push({
							name: name,
							doc: null,
							meta: [],
							access: [APublic],
							kind: FVar(macro: kha.Sound, macro null),
							pos: Context.currentPos()
						});
					case "blob":
						fields.push({
							name: name,
							doc: null,
							meta: [],
							access: [APublic],
							kind: FVar(macro: kha.Blob, macro null),
							pos: Context.currentPos()
						});
					case "font":
						fields.push({
							name: name,
							doc: null,
							meta: [],
							access: [APublic],
							kind: FVar(macro: kha.Font, macro null),
							pos: Context.currentPos()
						});
					case "video":
						fields.push({
							name: name,
							doc: null,
							meta: [],
							access: [APublic],
							kind: FVar(macro: kha.Video, macro null),
							pos: Context.currentPos()
						});
				}

				fields.push({
					name: name + "Name",
					doc: null,
					meta: [],
					access: [APublic],
					kind: FVar(macro: String, macro $v { name }),
					pos: Context.currentPos()
				});

				fields.push({
					name: name + "Description",
					doc: null,
					meta: [],
					access: [APublic],
					kind: FVar(macro: Dynamic, macro $v { file }),
					pos: Context.currentPos()
				});

				var loadExpressions = macro { };
				switch (type) {
					case "image":
						loadExpressions = macro {
							Assets.loadImage($v{name}, function (image: Image) done(), kha.Assets.reporter(failure));
						};
					case "sound":
						loadExpressions = macro {
							Assets.loadSound($v{name}, function (sound: Sound) done(), kha.Assets.reporter(failure));
						};
					case "blob":
						loadExpressions = macro {
							Assets.loadBlob($v{name}, function (blob: Blob) done(), kha.Assets.reporter(failure));
						};
					case "font":
						loadExpressions = macro {
							Assets.loadFont($v{name}, function (font: Font) done(), kha.Assets.reporter(failure));
						};
					case "video":
						loadExpressions = macro {
							Assets.loadVideo($v{name}, function (video: Video) done(), kha.Assets.reporter(failure));
						};
				}

				fields.push({
					name: name + "Load",
					doc: null,
					meta: [],
					access: [APublic],
					kind: FFun({
						ret: null,
						params: null,
						expr: loadExpressions,
						args: [{
							value: null,
							type: Context.toComplexType(Context.getType("kha.internal.VoidCallback")),
							opt: null,
							name: "done"
						}, {
							value: null,
							type: Context.toComplexType(Context.getType("kha.internal.AssetErrorCallback")),
							opt: null,
							name: "failure"
						}]
					}),
					pos: Context.currentPos()
				});

				fields.push({
					name: name + "Unload",
					doc: null,
					meta: [],
					access: [APublic],
					kind: FFun({
						ret: null,
						params: null,
						expr: macro {
							$i{name}.unload();
							$i{name} = null;
						},
						args: []
					}),
					pos: Context.currentPos()
				});
			}
		}

		fields.push({
			name: "names",
			doc: null,
			meta: [],
			access: [APublic],
			kind: FVar(macro: Array<String>, macro $a { names }),
			pos: Context.currentPos()
		});

		return fields;
	}

	static public macro function buildAssets():Array<Field> {
		var fields = Context.getBuildFields();
		var khabindLibs:Iterable<Dynamic> = Json.parse(File.getContent(findResources() + "khabindLibs.json"));

		// Add the `loadKhabindJsLibs` function to the `Assets` class
		if (Context.defined("js")) {
			var expr = macro {
				var tasks = 1;
			};

			for (lib in khabindLibs) {
				var libName = lib.options.nativeLib;

				expr = macro {
					$expr;
					untyped tasks++;

					untyped var loaded = (lib) -> {
						__js__("{0} = lib;", $i{libName});
						tasks--;
						if (tasks < 1) done();
					};

					untyped __js__("{0} = {0}().then(loaded);", $i{libName});
				}
			}

			expr = macro {
				$expr;
				untyped tasks--;
				untyped if (tasks < 1) done();
			}

			fields.push({
				name: "loadKhabindJsLibs",
				doc: null,
				meta: [],
				access: [APublic, AStatic],
				kind: FFun({
					ret: null,
					params: null,
					expr: expr,
					args: [{name: "done", type: macro:Void->Void}]
				}),
				pos: Context.currentPos()
			});
		}

		return fields;
	}
}
