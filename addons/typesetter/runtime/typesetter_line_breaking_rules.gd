class_name TypesetterLineBreakingRules
extends RefCounted
## Line-breaking rules for CJK text (TMP_Settings.LineBreakingTable).
##
## The defaults follow the Japanese kinsoku rules of JIS X 4051: characters in
## DEFAULT_LEADING may not begin a line, characters in DEFAULT_FOLLOWING may not
## end one. Override them in Project Settings (typesetter/leading_characters,
## typesetter/following_characters).

const DEFAULT_LEADING := ")]}»›〕〉》」』】〙〗〟’”｠ヽヾーァィゥェォッャュョヮヵヶぁぃぅぇぉっゃゅょゎゕゖㇰㇱㇲㇳㇴㇵㇶㇷㇸㇹㇺㇻㇼㇽㇾㇿ々〻‐゠–〜～?!‼⁇⁈⁉・、:;,。.？！：；，．）］｝｣、。・ｰﾞﾟｧｨｩｪｫｬｭｮｯ%‰℃°′″"
const DEFAULT_FOLLOWING := "([{«‹〔〈《「『【〘〖〝‘“｟（［｛｢$£¥€＄￡￥"

var leading_characters: String = DEFAULT_LEADING
var following_characters: String = DEFAULT_FOLLOWING


static func from_settings() -> TypesetterLineBreakingRules:
	var r := TypesetterLineBreakingRules.new()
	r.leading_characters = TypesetterSettings.get_leading_characters()
	r.following_characters = TypesetterSettings.get_following_characters()
	return r
