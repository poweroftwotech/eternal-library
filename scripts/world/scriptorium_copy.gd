class_name ScriptoriumCopy
extends StaticBody3D
## A copy on a desk of the Orosi Scriptorium (phase 17 step 4, the brief's Q5):
## E reads it. Each copy names the copyist whose hand it is in, and the desks of
## one row copy the same text, the two beside each other disagreeing in one
## word (the trust theme starts here, without rules yet). ScriptoriumGrammar
## sets what's on it as meta: "text" (TEXTS index), "variant" (0 or 1), "hand"
## (HANDS index) and "state" ("busy", "left" or "dust"). The texts are
## placeholders.

const PLACEHOLDER: String = "[i]Placeholder text: replace or approve.[/i]\n\n"
## [title, text]; {a|b} is the word copies disagree on (variant 0 or 1).
const TEXTS: Array = [
	["The Lamp-Keeper's Rule", "Keep the lamp before you keep the book. A book in the dark is {only paper|still a book}; a lamp without a book is still a light, and someone may yet come to read by it."],
	["On the Lower Stair", "Count the steps going down, and count them again coming up. If the two counts {differ|agree}, sit down where you are and wait for someone to come for you."],
	["The Garden Behind the Glass", "The first copyists planted the moss behind the glass so they would never need {fire|the sun}. It has outlived every one of them, and still it brightens and dims as if it were breathing."],
	["A Catalogue of Doors", "There are doors in the Library that open only from the side you are not on. Do not wait at them. {Nobody|Something} is waiting on the other side as well."],
	["The Copyist's Oath", "I will copy what is written and not what I would have written. Where the hand before mine has erred, I will {copy the error|mend it} and mark the place in the margin."],
	["Of the Sleepers in the Stacks", "Those who sleep between the shelves dream the books they lie beside. Wake them {gently|quickly}, and do not ask them what they read."],
]
## The copyists, by hand.
const HANDS: PackedStringArray = [
	"Behrouz son of Kaveh", "Mahin of the Lower Stacks", "old Sohrab", "Parisa, who writes left-handed",
	"Daryush the younger", "Golnar", "Farrokh of the Gorge", "Shirin the corrector", "Ardavan", "Roshan, a novice",
]
## How much of the text a copy in progress has reached.
const HALF: float = 0.55


func _ready() -> void:
	collision_layer = 2     # only the interaction ray
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 0.28, 0.52)
	shape.shape = box
	# Over the desk top (the desk faces -Z; its top is 0.35..0.85 in front of
	# the copyist's place), poking above the desk's own collision so the ray
	# finds the copy first.
	shape.position = Vector3(0.0, 0.44, 0.6)
	add_child(shape)


func interaction_prompt(_hit: Vector3) -> String:
	return "Read the copy"


func interact(_actor: Node3D, _hit: Vector3) -> void:
	get_tree().current_scene.open_panel(title(), PLACEHOLDER + body(), [{"text": "Leave it on the desk", "action": "close"}], "book")


func title() -> String:
	var t: Array = TEXTS[int(get_meta("text", 0)) % TEXTS.size()]
	return "%s, in the hand of %s" % [t[0], hand()]


func hand() -> String:
	return HANDS[int(get_meta("hand", 0)) % HANDS.size()]


## The copy as far as it got, then a line on what you find.
func body() -> String:
	var t: Array = TEXTS[int(get_meta("text", 0)) % TEXTS.size()]
	var text: String = chosen(str(t[1]), int(get_meta("variant", 0)))
	match str(get_meta("state", "busy")):
		"busy":
			return _cut(text) + "\n\n[i]The ink is still wet.[/i]"
		"left":
			return _cut(text) + "\n\n[i]The line stops halfway through a word. The ink dried long ago.[/i]"
		_:
			return text + "\n\n[i]Finished and signed, and never collected. Dust lies thick on the page.[/i]"


## `text` with each {a|b} resolved to a (variant 0) or b (variant 1).
static func chosen(text: String, variant: int) -> String:
	var out: String = ""
	var at: int = 0
	while true:
		var open: int = text.find("{", at)
		if open < 0:
			break
		var close: int = text.find("}", open)
		var pair: PackedStringArray = text.substr(open + 1, close - open - 1).split("|")
		out += text.substr(at, open - at) + pair[clampi(variant, 0, pair.size() - 1)]
		at = close + 1
	return out + text.substr(at)


## The first HALF of the words, broken off.
static func _cut(text: String) -> String:
	var words: PackedStringArray = text.split(" ")
	var n: int = maxi(3, int(words.size() * HALF))
	return " ".join(words.slice(0, n)) + "..."
