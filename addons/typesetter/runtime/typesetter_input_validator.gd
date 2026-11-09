@tool
class_name TypesetterInputValidator
extends Resource
## Base class for custom input validation (TMP_InputValidator). Override
## `validate` to accept, change or reject each typed character.
## TMP: TMP_InputValidator


## Called for every inserted character. Return the (possibly changed)
## character to insert, or "" to reject it. `text` is the current text and
## `pos` the insertion index.
## TMP: Validate(ref string text, ref int pos, char ch)
func validate(text: String, pos: int, ch: String) -> String:
	return ch


## Accepts digits only (TMP_DigitValidator).
class DigitValidator:
	extends TypesetterInputValidator

	func validate(_text: String, _pos: int, ch: String) -> String:
		return ch if ch >= "0" and ch <= "9" else ""


## Formats a phone number as (123) 456-7890 (TMP_PhoneNumberValidator).
class PhoneNumberValidator:
	extends TypesetterInputValidator

	func validate(text: String, pos: int, ch: String) -> String:
		if not (ch >= "0" and ch <= "9"):
			return ""
		var digits := text.substr(0, pos).replace("(", "").replace(")", "").replace(" ", "").replace("-", "")
		match digits.length():
			0:
				return "(" + ch
			2:
				return ch + ") "
			5:
				return ch + "-"
		return ch if digits.length() < 10 else ""
