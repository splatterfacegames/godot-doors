@tool
class_name TypesetterSpriteCharacter
extends Resource
## Maps a unicode value and name to a sprite glyph (TMP_SpriteCharacter).
## TMP: TMP_SpriteCharacter

## 0xFFFE when the sprite has no code point. TMP: unicode
@export var unicode: int = 0xFFFE
## TMP: name
@export var name: String = ""
## TMP: glyphIndex
@export var glyph_index: int = 0
## TMP: scale
@export var scale: float = 1.0

## TMP: hashCode
var hash_code: int:
	get:
		return TypesetterStyle.get_hash_code(name)
