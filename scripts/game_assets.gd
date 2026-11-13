class_name GameAssets
extends RefCounted

# ==============================================================================
# GameAssets - palette and textures shared by every screen.
# Static, so any script reads GameAssets.COLORS[...] or GameAssets.EMBLEMS[...]
# without going through Main. Main calls load_all() once in _ready().
# ==============================================================================

const COLORS = {
	"red": Color("#d63a3a"),
	"green": Color("#2e9e5b"),
	"orange": Color("#f08a24"),
	"blue": Color("#2f7fd6"),
	"blank": Color("#555566"),
	"empty_tile": Color("#2b2250"),
	"brass": Color("#d3a64a"),
	"brass_bright": Color("#f0cf86"),
	"gold": Color("#F2B63C"),
	"bg": Color("#1f1836"),
	"text_dim": Color("#a79fc4"),
	"text_bright": Color("#f3ead7")
}

static var EMBLEMS = {}           # dir -> Texture2D (white)
static var EMBLEMS_GOLD = {}      # dir -> Texture2D (gold, matched)
static var GEM_FRAME_TEX = {}     # color -> Texture2D (placed card frame)
static var TILE_EMPTY_TEX = {}    # tile index -> Texture2D
static var PLACED_TILE_TEX = {}   # "idx_color_dir" or "idx_blank" -> Texture2D
static var CARD_TEMPLATE_TEX: Texture2D = null
static var BALL_TEXTURE: Texture2D = null

static func load_all(n_tiles: int) -> void:
	"""Loads every texture used by the board, cards and shop into the static tables above."""
	if ResourceLoader.exists("res://assets/frames/card_template.svg"):
		CARD_TEMPLATE_TEX = load("res://assets/frames/card_template.svg")

	# Emblems (white & gold variants)
	for d in ["N", "E", "S", "W"]:
		var dl = d.to_lower()
		var pw = "res://assets/emblems/emblem_%s.svg" % dl
		var pg = "res://assets/emblems/emblem_%s_gold.svg" % dl
		if ResourceLoader.exists(pw):
			EMBLEMS[d] = load(pw)
		if ResourceLoader.exists(pg):
			EMBLEMS_GOLD[d] = load(pg)

	# Gem frames (placed card)
	for col in ["red","green","orange","blue","blank"]:
		var p = "res://assets/frames/gem_frame_%s.svg" % col
		if ResourceLoader.exists(p):
			GEM_FRAME_TEX[col] = load(p)

	# Tile empty SVGs (per slot)
	for i in range(n_tiles):
		var p = "res://assets/tiles/tile_empty_%d.svg" % i
		if ResourceLoader.exists(p):
			TILE_EMPTY_TEX[i] = load(p)

	# Placed tile SVGs (exact match with To_Beyond_Draft.html syncTiles)
	for i in range(n_tiles):
		for col in ["red", "green", "orange", "blue"]:
			for d in ["N", "E", "S", "W"]:
				var p = "res://assets/tiles/placed/tile_%d_%s_%s.svg" % [i, col, d]
				if ResourceLoader.exists(p):
					PLACED_TILE_TEX["%d_%s_%s" % [i, col, d]] = load(p)
		var pb = "res://assets/tiles/placed/tile_%d_blank.svg" % i
		if ResourceLoader.exists(pb):
			PLACED_TILE_TEX["%d_blank" % i] = load(pb)

	# Ball
	if ResourceLoader.exists("res://assets/ball.svg"):
		BALL_TEXTURE = load("res://assets/ball.svg")
