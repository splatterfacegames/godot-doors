class_name TypesetterEvents
extends RefCounted
## Global Typesetter events (TMP's static events and TMPro_EventManager).
## Reach the shared instance through `TypesetterSettings.events`.

## A character was not found in the font asset or any fallback.
## TMP: TMP_Text.OnMissingCharacter
signal missing_character(unicode: int, string_index: int, text: String, font_asset: TypesetterFontAsset, text_component: Node)
## Any Typesetter text node's text changed.
## TMP: TMPro_EventManager.TEXT_CHANGED_EVENT
signal text_changed(text_component: Node)
## A font asset's properties changed (TMPro_EventManager.FONT_PROPERTY_EVENT).
signal font_property_changed(font_asset: Resource)
## A material's properties changed (TMPro_EventManager.MATERIAL_PROPERTY_EVENT).
signal material_property_changed(material: Material)
## A sprite asset changed (TMPro_EventManager.SPRITE_ASSET_PROPERTY_EVENT).
signal sprite_asset_property_changed(sprite_asset: Resource)
## A colour gradient preset changed (TMPro_EventManager.COLOR_GRADIENT_PROPERTY_EVENT).
signal color_gradient_property_changed(gradient: Resource)
