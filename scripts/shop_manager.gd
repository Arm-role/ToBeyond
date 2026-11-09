class_name ShopManager
extends RefCounted

const MAX_ARTIFACTS: int = 5
const HAND_CAP: int = 12
const HAND_PRICE: int = 10
const STAT_PRICE: int = 10
const STONE_UPGRADE_PRICE: int = 3
const STONE_UPGRADE_BONUSES: Array[int] = [1, 1, 2, 2, 3, 4]
const REROLL_START: int = 5
const REROLL_STEP: int = 2
const OFFER_ARTIFACTS: int = 2
const OFFER_MISC: int = 5
# These entries are deliberately disabled in the HTML draft itself: its
# one-row board cannot support the required route/board mechanics yet.
const DRAFT_DISABLED_ARTIFACTS: Array[String] = ["fatePay", "helperC", "helperR", "lshape", "moneybox"]
const ARTIFACT_RARITY: Dictionary = {
	"add5": "common", "mult2": "common", "atk15": "common",
	"dirNHit": "common", "dirEHit": "common", "dirSHit": "common", "dirWHit": "common",
	"artiPay": "common", "greenCoin": "common", "isoGem": "common", "firstGem": "common",
	"emptyAtk": "common", "chaosStack": "common", "discardStack": "common",
	"walkCoin": "common", "chaosAtk": "common",
	"stone3": "uncommon", "tileAtk": "uncommon", "fullSell": "uncommon",
	"stoneUp": "uncommon", "freediscard": "uncommon", "redS": "uncommon",
	"stone7W": "uncommon", "stone7E": "uncommon", "orangeN": "uncommon",
	"equalG": "uncommon", "totem": "uncommon", "helperOdd": "uncommon", "helperEven": "uncommon",
	"north5": "rare", "eastG": "rare", "west5": "rare", "south5": "rare",
	"reverse": "rare"
}

const ARTIFACT_CATALOG: Array[Dictionary] = [
	{"type": "add5",        "name": "Gem Blade",       "icon": "⚔️", "desc": "+10 ATK เพิ่มเติมเมื่อยิงโจมตี",          "color": Color("#2f7fd6"), "price": 5},
	{"type": "mult2",       "name": "Rune Lens",        "icon": "🔮", "desc": "ตัวคูณ +5 ก่อนคิดดาเมจสุดท้าย",          "color": Color("#d63a3a"), "price": 6},
	{"type": "reverse",     "name": "Mirror Walk",      "icon": "↩️", "desc": "ลูกไฟเดินย้อนกลับและทำผลของแต่ละช่องซ้ำ",   "color": Color("#a66cf2"), "price": 6},
	{"type": "emptyAtk",    "name": "Empty Fist",       "icon": "👊", "desc": "+2 ATK ต่อช่องกระดานที่ว่างเปล่า",       "color": Color("#a66cf2"), "price": 6},
	{"type": "firstGem",    "name": "First Strike",     "icon": "🥇", "desc": "Gem ใบแรกที่ลูกไฟถึงได้รับโบนัสพลังตามกลุ่ม",  "color": Color("#f08a24"), "price": 6},
	{"type": "walkCoin",    "name": "Gold Step",        "icon": "👟", "desc": "รับ 🪙 1 เหรียญต่อรอบเดินที่เหลือเมื่อชนะ", "color": Color("#f08a24"), "price": 6},
	{"type": "stoneUp",     "name": "Stone Carver",     "icon": "🪨", "desc": "ตัวคูณเริ่ม ×1 และเพิ่มตามการอัปเกรด Stone",  "color": Color("#a66cf2"), "price": 6, "m": 1.0},
	{"type": "freediscard", "name": "Wild Shuffle",     "icon": "♻️", "desc": "ทิ้งการ์ดได้แม้มี Gem วางอยู่บนกระดาน",   "color": Color("#2e9e5b"), "price": 8},
	{"type": "atk15",       "name": "Power Core",       "icon": "⚡", "desc": "ATK รวมทั้งหมด ×1.5",                    "color": Color("#2f7fd6"), "price": 6},
	{"type": "greenCoin",   "name": "Coin Hoard",       "icon": "🪙", "desc": "ตก Gem สีเขียวมีโอกาส 1/3 ได้ 1🪙",            "color": Color("#2e9e5b"), "price": 6},
	{"type":"stone3", "name":"โบนัสกลุ่มสี", "icon":"💠", "desc":"โบนัส Stone กลุ่มสี", "color":Color("#2f7fd6"), "price":6},
	{"type":"tileAtk", "name":"พลังช่องพิเศษ", "icon":"✴", "desc":"เพิ่มพลังตามช่องพิเศษ", "color":Color("#a66cf2"), "price":6},
	{"type":"north5", "name":"แนวเหนือ", "icon":"N5", "desc":"โบนัสเมื่อทิศเหนือเรียงกัน", "color":Color("#f08a24"), "price":6},
	{"type":"eastG", "name":"แนวตะวันออก", "icon":"E×2", "desc":"โบนัสแนวตะวันออก", "color":Color("#2e9e5b"), "price":6},
	{"type":"west5", "name":"แนวตะวันตก", "icon":"W+", "desc":"โบนัสแนวตะวันตก", "color":Color("#2f7fd6"), "price":6},
	{"type":"south5", "name":"แนวใต้", "icon":"S", "desc":"โบนัสแนวใต้", "color":Color("#d63a3a"), "price":6},
	{"type":"equalG", "name":"ยกระดับกลุ่ม", "icon":"=", "desc":"กลุ่ม Stone ต่ำสุดเท่ากลุ่มสูงสุด", "color":Color("#2f7fd6"), "price":6},
	{"type":"isoGem", "name":"โดดเดี่ยว", "icon":"M+", "desc":"โบนัสเมื่อ Gem อยู่โดดเดี่ยว", "color":Color("#2f7fd6"), "price":6},
	{"type":"chaosStack", "name":"สะสม Chaos", "icon":"+0", "desc":"ใช้ Chaos แล้ว ATK +2 ถาวร", "color":Color("#a66cf2"), "price":6, "m":0},
	{"type":"discardStack", "name":"เก็บไพ่ทิ้ง", "icon":"+0", "desc":"ชนะแล้วเพิ่มตัวคูณตามการทิ้ง", "color":Color("#d63a3a"), "price":6, "m":0},
	{"type":"chaosAtk", "name":"คลัง Chaos", "icon":"+10", "desc":"ATK +10 ต่อ Chaos ที่ถือ", "color":Color("#a66cf2"), "price":6},
	{"type":"fullSell", "name":"ขายเต็มราคา", "icon":"💰", "desc":"ขาย Artifact และ Chaos ได้เต็มราคา", "color":Color("#f08a24"), "price":6},
	{"type":"dirNHit", "name":"คูณทิศเหนือ", "icon":"↑+3", "desc":"โบนัสโจมตีทิศเหนือ", "color":Color("#2e9e5b"), "price":6},
	{"type":"dirEHit", "name":"คูณทิศตะวันออก", "icon":"→+3", "desc":"โบนัสโจมตีทิศตะวันออก", "color":Color("#2e9e5b"), "price":6},
	{"type":"dirSHit", "name":"คูณทิศใต้", "icon":"↓+3", "desc":"โบนัสโจมตีทิศใต้", "color":Color("#2e9e5b"), "price":6},
	{"type":"dirWHit", "name":"คูณทิศตะวันตก", "icon":"←+3", "desc":"โบนัสโจมตีทิศตะวันตก", "color":Color("#2e9e5b"), "price":6},
	{"type":"artiPay", "name":"รายได้ Artifact", "icon":"🏺", "desc":"ชนะแล้วรับรายได้ตาม Artifact", "color":Color("#f08a24"), "price":6},
	{"type":"fatePay", "name":"รายได้ Gem", "icon":"🎴", "desc":"รายได้จาก Gem", "color":Color("#f08a24"), "price":6},
	{"type":"totem", "name":"โทเท็ม", "icon":"🗿", "desc":"วางโบนัสโทเท็มบนช่อง", "color":Color("#a66cf2"), "price":6},
	{"type":"orangeN", "name":"ส้มแจก Chaos", "icon":"N", "desc":"Gem ส้มให้ Chaos", "color":Color("#f08a24"), "price":6},
	{"type":"helperOdd", "name":"ผู้ช่วยเลขคี่", "icon":"คี่", "desc":"ผู้ช่วยช่องคี่", "color":Color("#2e9e5b"), "price":6},
	{"type":"helperEven", "name":"ผู้ช่วยเลขคู่", "icon":"คู่", "desc":"ผู้ช่วยช่องคู่", "color":Color("#2f7fd6"), "price":6},
	{"type":"redS", "name":"คูณแดงใต้", "icon":"S×1", "desc":"โบนัสแดงใต้", "color":Color("#d63a3a"), "price":6},
	{"type":"stone7W", "name":"พลังตะวันตก", "icon":"W+0", "desc":"โบนัส Stone ตะวันตก", "color":Color("#a66cf2"), "price":6},
	{"type":"stone7E", "name":"คูณตะวันออก", "icon":"E+0", "desc":"โบนัส Stone ตะวันออก", "color":Color("#2e9e5b"), "price":6},
	{"type":"helperC", "name":"ผู้ช่วยมุม", "icon":"🔷", "desc":"ผู้ช่วยมุม", "color":Color("#2e9e5b"), "price":6},
	{"type":"helperR", "name":"ผู้ช่วยย้อนกลับ", "icon":"⏪", "desc":"ผู้ช่วยย้อนกลับ", "color":Color("#2e9e5b"), "price":6},
	{"type":"lshape", "name":"สูตรตัว L", "icon":"L", "desc":"สูตรตัว L", "color":Color("#2e9e5b"), "price":8},
	{"type":"moneybox", "name":"กล่องเงิน", "icon":"💰", "desc":"กล่องเงินบนกระดาน", "color":Color("#2e9e5b"), "price":8},
]

const CHAOS_CATALOG: Array[Dictionary] = [
	{"kind":"color", "col":"red", "name":"Chaos เปลี่ยนสีแดง", "icon":"🎨", "price":5, "color":Color("#d63a3a")},
	{"kind":"color", "col":"green", "name":"Chaos เปลี่ยนสีเขียว", "icon":"🎨", "price":5, "color":Color("#2e9e5b")},
	{"kind":"color", "col":"orange", "name":"Chaos เปลี่ยนสีส้ม", "icon":"🎨", "price":5, "color":Color("#f08a24")},
	{"kind":"color", "col":"blue", "name":"Chaos เปลี่ยนสีน้ำเงิน", "icon":"🎨", "price":5, "color":Color("#2f7fd6")},
	{"kind":"dirc", "dir":"N", "name":"Chaos เปลี่ยนทิศเหนือ", "icon":"🧭", "price":4, "color":Color("#a66cf2")},
	{"kind":"dirc", "dir":"E", "name":"Chaos เปลี่ยนทิศตะวันออก", "icon":"🧭", "price":4, "color":Color("#a66cf2")},
	{"kind":"dirc", "dir":"S", "name":"Chaos เปลี่ยนทิศใต้", "icon":"🧭", "price":4, "color":Color("#a66cf2")},
	{"kind":"dirc", "dir":"W", "name":"Chaos เปลี่ยนทิศตะวันตก", "icon":"🧭", "price":4, "color":Color("#a66cf2")},
	{"kind":"tdir", "dir":"N", "name":"Chaos ทิศช่องเหนือ", "icon":"🧭", "price":4, "color":Color("#38c4b8")},
	{"kind":"tdir", "dir":"E", "name":"Chaos ทิศช่องตะวันออก", "icon":"🧭", "price":4, "color":Color("#38c4b8")},
	{"kind":"tdir", "dir":"S", "name":"Chaos ทิศช่องใต้", "icon":"🧭", "price":4, "color":Color("#38c4b8")},
	{"kind":"tdir", "dir":"W", "name":"Chaos ทิศช่องตะวันตก", "icon":"🧭", "price":4, "color":Color("#38c4b8")},
	{"kind":"mtile", "name":"Chaos MULT +5", "icon":"⚡", "price":5, "color":Color("#a66cf2")},
	{"kind":"xmult", "name":"Chaos MULT ×1.2", "icon":"×", "price":6, "color":Color("#a66cf2")},
	{"kind":"xatk", "name":"Chaos ATK ×1.2", "icon":"✴", "price":6, "color":Color("#a66cf2")},
	{"kind":"goldify", "name":"Chaos Gem ทอง", "icon":"✨", "price":6, "color":Color("#f2b63c")},
	{"kind":"destroy", "name":"Chaos ทำลาย Gem", "icon":"💥", "price":5, "color":Color("#e0605e")},
	{"kind":"crystal", "name":"ผลึก Gem", "icon":"💎", "price":6, "color":Color("#72d8ff")},
]


## Display names / descriptions copied from To_Beyond_Draft.html (ITEM_NAME / itemDesc).
const DRAFT_NAMES: Dictionary = {
	"isoGem": "โดดเดี่ยว",
	"firstGem": "ก้าวแรก",
	"emptyAtk": "พลังช่องว่าง",
	"chaosStack": "สะสม Chaos",
	"discardStack": "เก็บไพ่ทิ้ง",
	"walkCoin": "เดินประหยัด",
	"chaosAtk": "คลัง Chaos",
	"helperOdd": "ผู้ช่วยเลขคี่",
	"helperEven": "ผู้ช่วยเลขคู่",
	"equalG": "ยกระดับกลุ่ม",
	"reverse": "Reverse",
	"greenCoin": "เขียวนำโชค",
	"south5": "แนวใต้",
	"west5": "แนวตะวันตก",
	"fullSell": "ขายเต็มราคา",
	"eastG": "แนวตะวันออก",
	"north5": "แนวเหนือ",
	"tileAtk": "พลังช่องพิเศษ",
	"helperC": "ผู้ช่วยมุม",
	"artiPay": "รายได้ Artifact",
	"fatePay": "รายได้ Gem",
	"add5": "พลังโจมตี +10",
	"mult2": "ตัวคูณ +5",
	"redS": "คูณแดงใต้",
	"stoneUp": "คูณอัปเกรด",
	"stone7W": "พลังตะวันตก",
	"stone7E": "คูณตะวันออก",
	"totem": "โทเท็ม",
	"stone3": "โบนัสกลุ่มสี",
	"atk15": "พลังโจมตี ×1.5",
	"orangeN": "ส้มแจก Chaos",
	"helperR": "ผู้ช่วยย้อนกลับ",
	"lshape": "สูตรตัว L",
	"moneybox": "กล่องเงิน",
	"freediscard": "ทิ้งไพ่ฟรี"
}

const DRAFT_DESCS: Dictionary = {
	"add5": "ตอนโจมตี: ATK +10",
	"mult2": "ตอนโจมตี: ตัวคูณ +5",
	"atk15": "ตอนโจมตี: ATK × 1.5",
	"fullSell": "ขาย Artifact และ Chaos ได้เต็มราคาที่ซื้อ (ปกติ Artifact ได้ 1/3, Chaos ได้ 🪙1) · ใบนี้ขายเองก็ได้เต็มราคา",
	"isoGem": "ทุกครั้งที่เดินตกช่อง Gem ที่ทั้งสองข้างเป็นช่องว่าง (ไม่มี Gem · ขอบกระดานนับเป็นช่องว่าง): ตัวคูณ + ATK ของกลุ่ม (สูตร Stone) ของใบนั้น",
	"firstGem": "Gem ใบแรกที่ลูกไฟเดินถึงในแต่ละรอบ: ATK ของใบนั้นกลายเป็นผลบวกไล่ลงถึง 1 เช่น ATK 5 → 5+4+3+2+1 = 15",
	"emptyAtk": "ตอนโจมตี: ATK +2 ต่อช่องว่างบนกระดาน (ช่องที่ไม่มี Gem)",
	"walkCoin": "ตอนชนะศัตรู: ได้เหรียญเพิ่ม +1 ต่อครั้งที่ยังรับการโจมตีได้ (เลือดที่เหลือ)",
	"chaosAtk": "ตอนโจมตี: ATK +10 ต่อการ์ดที่อยู่ในช่อง Chaos",
	"equalG": "กลุ่ม Stone ที่ได้ ATK น้อยที่สุดบนกระดาน จะได้ ATK เท่ากับกลุ่มที่ได้มากที่สุด (ต้องมีอย่างน้อย 2 กลุ่ม)",
	"reverse": "เมื่อลูกไฟเดินถึงช่องสุดท้าย จะเดินย้อนกลับไปช่องเริ่มต้น และเก็บ ATK / ทำให้ Artifact ทำงานซ้ำทุกช่องที่ผ่านขากลับ",
	"greenCoin": "ทุกครั้งที่เดินตกช่องที่วาง Gem สีเขียว: มีโอกาส 1 ใน 3 ได้ 🪙 1 เหรียญทันที",
	"south5": "ถ้ามีช่องทิศใต้ (S) เรียงติดกันตั้งแต่ 5 ช่อง: ตอนเดินถึงช่องสุดท้าย ก่อน Artifact ใบอื่นทำงาน รวมผล ATK × ตัวคูณ ตอนนั้นมาเป็น ATK แล้วตัวคูณกลับเป็น 1 จากนั้น Artifact ใบอื่นจึงทำงานต่อ (ทำงานก่อนเสมอ ไม่ขึ้นกับตำแหน่ง) · ใช้ Chaos เปลี่ยนทิศช่องเพื่อสร้างแนว (ปกติมีช่อง S แค่ 2 ช่อง)",
	"west5": "ถ้ามีช่องทิศตะวันตก (W) เรียงติดกันตั้งแต่ 5 ช่อง: ทุกครั้งที่เดินตกช่องที่วาง Gem ทิศตะวันตก ตัวคูณ + ATK ที่ Gem ใบนั้นได้จากสูตร Stone · ยิ่งอัปเกรด Stone ยิ่งแรง · ใช้ Chaos เปลี่ยนทิศช่องเพื่อสร้างแนว (ปกติมีช่อง W แค่ 2 ช่อง)",
	"tileAtk": "ตอนโจมตี: ATK คูณเพิ่มตามจำนวนช่องบนกระดานที่มี Chaos ช่อง (⚡+5, ×1.2 ตัวคูณ, ×1.2 ATK) วางอยู่\n• 0 ช่อง = ×1\n• 1 ช่อง = ×1.5\n• 2 ช่อง = ×2\n• เพิ่มขึ้น ×0.5 ทุกช่อง\nช่องเดียวมี Chaos หลายอัน นับเป็น 1 ช่อง",
	"stone3": "ตอนโจมตี: ATK +40 ต่อ 1 กลุ่มสี\nกลุ่มสี = Gem สีเดียวกันวางติดกันตั้งแต่ 2 ใบขึ้นไป (แถบสีใต้ช่อง)\nเช่น แดงติดกัน 3 ใบ + น้ำเงินติดกัน 2 ใบ = 2 กลุ่ม = ATK +80\nกลุ่มสูตรทิศ (แถบม่วง) ไม่นับ",
	"artiPay": "ตอนจบด่าน (เมื่อฆ่าศัตรูได้) ได้ 1 เหรียญต่อ Artifact ที่ถืออยู่ (นับรวมใบนี้)",
	"fatePay": "ตอนจบด่าน (เมื่อฆ่าศัตรูได้) ได้ 1 เหรียญต่อ Gem ทุก 10 ใบในสำรับ",
	"freediscard": "ทิ้ง Gem ได้แม้วางการ์ดบนกระดานไปแล้ว · ทิ้งแล้วจั่วเต็มมือ · ข้อเสีย: จำนวนครั้งที่ทิ้งได้ต่อด่าน -1 ตราบที่ถือการ์ดนี้",
	"totem": "ปัก Totem ลงช่องสุ่ม 1 ช่องต่อการ์ด (สุ่มช่องใหม่ทุกรอบเดิน) · ลูกไฟเดินถึงช่องนั้น ได้ ATK ตามเลขช่อง ยิ่งเลขน้อยยิ่งได้มาก\nช่อง 1 = +60 … ช่อง 8 = +20 · ดูค่าได้ใต้ช่องที่มี 🗿",
	"orangeN": "ตอนเดิน ถ้ามีสูตรที่การ์ดสีส้มทิศ N วางบนช่องทิศ N ครบทั้ง 2 ช่อง: ได้การ์ด Chaos สุ่ม 1 ใบต่อสูตร (ช่อง Chaos เต็มจะไม่ได้)",
	"helperC": "ผู้ช่วยที่เดินเฉพาะช่องมุม",
	"helperOdd": "ทุกครั้งที่เดิน: ดาวผู้ช่วย (สีฟ้า) วิ่งก่อนลูกไฟเสมอ แวะเฉพาะช่องเลขคี่ (1, 3, 5, 7) ที่มี Gem / ผลึก / Totem ได้ ATK และทำให้ Artifact, Chaos บนช่อง, ผลึก, Totem ทำงานเหมือนลูกไฟ · มีหลายใบ = วิ่งหลายรอบ",
	"helperEven": "ทุกครั้งที่เดิน: ดาวผู้ช่วย (สีฟ้า) วิ่งก่อนลูกไฟเสมอ แวะเฉพาะช่องเลขคู่ (2, 4, 6, 8) ที่มี Gem / ผลึก / Totem ได้ ATK และทำให้ Artifact, Chaos บนช่อง, ผลึก, Totem ทำงานเหมือนลูกไฟ · มีหลายใบ = วิ่งหลายรอบ",
	"helperR": "ผู้ช่วยที่เดินย้อนกลับเฉพาะช่องเลขคู่",
	"lshape": "ทุกสูตรเรียงเป็นตัว L (หักมุม) ได้",
	"moneybox": "ทุกครั้งที่เริ่มศัตรูใหม่ เกิดกล่องเงินที่ช่องว่างแบบสุ่ม 1 กล่องต่อการ์ด"
}

const DIR_TH: Dictionary = {"N": "เหนือ", "E": "ตะวันออก", "S": "ใต้", "W": "ตะวันตก"}


static func display_name(item: Dictionary) -> String:
	var t: String = item.get("type", "")
	if DRAFT_NAMES.has(t):
		return DRAFT_NAMES[t]
	if t.begins_with("dir") and t.ends_with("Hit"):
		return "คูณทิศ" + DIR_TH.get(t.substr(3, 1), "")
	return item.get("name", t)


static func display_desc(item: Dictionary) -> String:
	var t: String = item.get("type", "")
	if DRAFT_DESCS.has(t):
		return DRAFT_DESCS[t]
	if t.begins_with("dir") and t.ends_with("Hit"):
		return "เดินไปตกช่องที่วาง Gem ทิศ%s (ทิศของการ์ด): ตัวคูณ +3" % DIR_TH.get(t.substr(3, 1), "")
	return item.get("desc", "")


const COL_TH: Dictionary = {"red": "แดง", "green": "เขียว", "orange": "ส้ม", "blue": "น้ำเงิน"}


## Chaos texts from the draft (chaosLabel / chaosName / chaosDesc).
static func chaos_label(c: Dictionary) -> String:
	match c.get("kind", ""):
		"color": return COL_TH.get(c.get("col", ""), "")
		"dirc": return DIR_TH.get(c.get("dir", ""), "")
		"tdir": return "ช่อง " + str(c.get("dir", ""))
		"mtile": return "⚡+5"
		"xmult": return "MULT"
		"xatk": return "ATK"
		"goldify": return "ทอง"
		"destroy": return "ทำลาย"
		"crystal": return "ผลึก"
	return ""


static func chaos_name(c: Dictionary) -> String:
	match c.get("kind", ""):
		"color": return "Chaos เปลี่ยนสี" + COL_TH.get(c.get("col", ""), "")
		"dirc": return "Chaos เปลี่ยนทิศ Gem" + DIR_TH.get(c.get("dir", ""), "")
		"tdir": return "Chaos เปลี่ยนทิศช่อง" + DIR_TH.get(c.get("dir", ""), "")
		"mtile": return "Chaos ช่อง ⚡+5"
		"xmult": return "Chaos ช่อง ×1.2 มัลติ"
		"xatk": return "Chaos ช่อง ×1.2 ATK"
		"goldify": return "Chaos ทอง"
		"destroy": return "Chaos ทำลาย"
		"crystal": return "ผลึก Gem"
	return "Chaos"


static func chaos_desc(c: Dictionary) -> String:
	var tile := "แตะการ์ดนี้แล้วแตะช่องบนกระดาน (อยู่ถาวรจนจบเกม) · ทำงานเมื่อเดินตกช่องที่มี Gem และทิศการ์ดตรงกับทิศช่อง"
	var d: String = DIR_TH.get(c.get("dir", ""), "")
	match c.get("kind", ""):
		"color": return "เลือก Gem ในมือสูงสุด 2 ใบ แล้วแตะการ์ดนี้: เปลี่ยนเป็นสี%s ถาวร (การ์ดในสำรับเปลี่ยนตลอดเกม)" % COL_TH.get(c.get("col", ""), "")
		"dirc": return "เลือก Gem ในมือ 1 ใบ แล้วแตะการ์ดนี้: เปลี่ยนเป็นทิศ%s ถาวร (การ์ดในสำรับเปลี่ยนตลอดเกม)" % d
		"tdir": return "แตะการ์ดนี้แล้วแตะช่องบนกระดาน: เปลี่ยนทิศของช่องเป็น%s ถาวรจนจบเกม (วางทับช่องที่เปลี่ยนแล้วเพื่อเปลี่ยนอีกได้) · Gem ทิศ%sที่วางบนช่องนี้จะนับว่าตรงทิศ" % [d, d]
		"mtile": return "ตัวคูณ +5 · " + tile
		"xmult": return "ตัวคูณ ×1.2 · " + tile
		"xatk": return "ATK ×1.2 · " + tile
		"goldify": return "เลือก Gem 1 ใบ แล้วแตะการ์ดนี้: เป็นการ์ดทองถาวร ตกช่องแล้วทำงานซ้ำ 2 รอบ"
		"destroy": return "เลือก Gem 2 ใบ แล้วแตะการ์ดนี้: ทำลายออกจากสำรับถาวร"
		"crystal": return "แตะการ์ดนี้แล้วแตะช่องว่างบนกระดาน วางผลึก Gem (HP 5) · ตอนเดินแวะช่องนี้ ATK ที่สะสมจะหักเลือดผลึก ผลึกแตกแล้วได้ Gem สุ่ม +3 ใบ (เข้ามือและเพิ่มในสำรับถาวร) · วาง Gem บนช่องนี้ไม่ได้"
	return ""


## Cover art like the draft's itemCover(): SVG art, else the direction emblem.
func art_cover(item: Dictionary) -> Texture2D:
	var t: String = item.get("type", "")
	var tex: Texture2D = _main.ART_TEX.get(t)
	if tex != null:
		return tex
	var dir := ""
	if t.begins_with("dir") and t.ends_with("Hit"):
		dir = t.substr(3, 1)
	elif t in ["orangeN", "north5"]:
		dir = "N"
	elif t in ["redS", "south5"]:
		dir = "S"
	elif t in ["stone7W", "west5"]:
		dir = "W"
	elif t in ["stone7E", "eastG"]:
		dir = "E"
	return _main.EMBLEMS.get(dir) if dir != "" else null


var _main: Node
var shop_tab: String = "game"
var shop_offers: Array[Dictionary] = []
var shop_bought: Array[String] = []
var reroll_cost: int = REROLL_START

func _init(main: Node = null) -> void:
	_main = main

static func has_artifact(artifacts: Array, type_key: String) -> bool:
	for it in artifacts:
		if it != null and it.get("type") == type_key:
			return true
	return false


static func is_draft_enabled(type_key: String) -> bool:
	return not DRAFT_DISABLED_ARTIFACTS.has(type_key)

func get_sell_price(artifact: Dictionary) -> int:
	return int(artifact.get("price", 6)) if _main.has_artifact("fullSell") else int(artifact.get("price", 6) / 3.0)

static func get_stone_upgrade_cost() -> int:
	return STONE_UPGRADE_PRICE

static func get_unowned_artifact_offers(artifacts: Array, count: int = 4) -> Array[Dictionary]:
	var owned_types: Array[String] = []
	for art in artifacts:
		if art != null:
			owned_types.append(art["type"])

	var pool: Array[Dictionary] = []
	for a in ARTIFACT_CATALOG:
		if is_draft_enabled(a["type"]) and not owned_types.has(a["type"]):
			pool.append(a.duplicate())

	pool.shuffle()
	var result: Array[Dictionary] = []
	var limit = mini(count, pool.size())
	for i in range(limit):
		result.append(pool[i])
	return result


# ==============================================================================
# Shop UI & Operations (Instance Methods)
# ==============================================================================

func open_shop() -> void:
	shop_tab = "game"
	reroll_cost = REROLL_START
	shop_bought.clear()
	generate_game_offers()
	_main.shop_modal.visible = true
	# Draft `.shopscroll`: dashed, rounded frame around the offers.
	var frame := DashedStyleBox.new()
	frame.border_color = Color(0.827451, 0.65098, 0.290196, 0.35)
	frame.corner_radius = 21.0
	frame.set_content_margin_all(12.0)
	_main.shop_offer_frame.add_theme_stylebox_override("panel", frame)
	render_shop_owned()
	render_shop_offers()
	_main.shop_coins_label.text = "🪙 %s" % _main.fmt_num(_main.coins)
	_update_tab_buttons()


func set_tab(tab: String) -> void:
	shop_tab = tab
	render_shop_offers()
	_update_tab_buttons()


## Draft `.shoptabs`: active tab is solid brass; TEST tabs have dashed borders.
func _update_tab_buttons() -> void:
	var tabs := {"game": _main.shop_game_tab, "artifact": _main.shop_artifact_tab, "chaos": _main.shop_chaos_tab, "upgrade": _main.shop_upgrade_tab}
	for key in tabs:
		var button: Button = tabs[key]
		var active: bool = key == shop_tab
		var sb: StyleBox
		if active:
			var flat := StyleBoxFlat.new()
			flat.bg_color = _main.COLORS["brass"]
			flat.border_color = _main.COLORS["brass"]
			flat.set_border_width_all(3)
			flat.set_corner_radius_all(18)
			sb = flat
		elif key == "game":
			var outline := StyleBoxFlat.new()
			outline.bg_color = Color(0, 0, 0, 0)
			outline.border_color = _main.COLORS["brass"]
			outline.set_border_width_all(3)
			outline.set_corner_radius_all(18)
			sb = outline
		else:
			var dashed := DashedStyleBox.new()
			dashed.border_color = _main.COLORS["brass"]
			dashed.corner_radius = 18.0
			sb = dashed
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(st, sb)
		var font_col: Color = Color("#2a2140") if active else _main.COLORS["brass_bright"]
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(c, font_col)
		button.modulate = Color(1, 1, 1, 0.85) if (key != "game" and not active) else Color.WHITE
		button.disabled = false


func generate_game_offers() -> void:
	shop_offers.clear()
	var used: Dictionary = {}
	var owned_types: Array[String] = []
	for artifact in _main.artifacts:
		if artifact != null:
			owned_types.append(artifact["type"])

	for _offer_index in range(OFFER_ARTIFACTS):
		for _attempt in range(60):
			var rarity_roll := randf()
			var rarity := "common" if rarity_roll < 0.70 else ("uncommon" if rarity_roll < 0.95 else "rare")
			var candidates: Array[Dictionary] = []
			for artifact in ARTIFACT_CATALOG:
				var artifact_type: String = artifact["type"]
				var offer_key := "artifact:%s" % artifact_type
				if (is_draft_enabled(artifact_type) and not owned_types.has(artifact_type)
					and ARTIFACT_RARITY.get(artifact_type, "") == rarity and not used.has(offer_key)):
					candidates.append(artifact)
			if candidates.is_empty():
				continue
			var item: Dictionary = candidates[randi_range(0, candidates.size() - 1)].duplicate()
			used["artifact:%s" % item["type"]] = true
			shop_offers.append({"kind": "artifact", "item": item, "sold": false})
			break

	for _offer_index in range(OFFER_MISC):
		for _attempt in range(60):
			var roll := randf()
			if roll < 0.35:
				var stone_indices: Array[int] = []
				for idx in range(_main.stone_formulas.size()):
					var offer_key := "stone:%d" % idx
					if (_main.discovered_formulas.has(_main.stone_formulas[idx]["key"])
						and not shop_bought.has("stone:%d" % idx) and not used.has(offer_key)):
						stone_indices.append(idx)
				if stone_indices.is_empty():
					continue
				var stone_idx: int = stone_indices[randi_range(0, stone_indices.size() - 1)]
				used["stone:%d" % stone_idx] = true
				shop_offers.append({"kind": "stone", "idx": stone_idx, "sold": false})
				break
			elif roll < 0.75:
				var chaos_indices: Array[int] = []
				for idx in range(CHAOS_CATALOG.size()):
					if not used.has("chaos:%d" % idx):
						chaos_indices.append(idx)
				if chaos_indices.is_empty():
					continue
				var chaos_idx: int = chaos_indices[randi_range(0, chaos_indices.size() - 1)]
				used["chaos:%d" % chaos_idx] = true
				shop_offers.append({"kind": "chaos", "item": CHAOS_CATALOG[chaos_idx], "sold": false})
				break
			else:
				var upgrade_keys: Array[String] = []
				var stat_types: Array[String] = ["hand", "walk", "disc"]
				for key in stat_types:
					if shop_bought.has(key) or used.has("upgrade:%s" % key):
						continue
					if key == "hand" and _main.hand_max >= HAND_CAP:
						continue
					upgrade_keys.append(key)
				if upgrade_keys.is_empty():
					continue
				var stat: String = upgrade_keys[randi_range(0, upgrade_keys.size() - 1)]
				used["upgrade:%s" % stat] = true
				shop_offers.append({"kind": "stat", "stat": stat, "sold": false})
				break


func reroll_shop() -> void:
	if _main.coins < reroll_cost:
		return
	_main.coins -= reroll_cost
	reroll_cost += REROLL_STEP
	generate_game_offers()
	_main.shop_coins_label.text = "🪙 %s" % _main.fmt_num(_main.coins)
	_main.update_all_ui()
	render_shop_offers()


# ------------------------------------------------------------------------------
# Shop cards — Godot version of the draft's `.sitem` (104×122, rows 104×106),
# scaled 1.5× for the 1920×1080 canvas.
# ------------------------------------------------------------------------------

var _offer_target: Container = null
var _card_height: float = 183.0


func _card_box(bg: Color, border: Color = Color("#d3a64a"), dashed: bool = false) -> StyleBox:
	if dashed:
		var d := DashedStyleBox.new()
		d.bg_color = bg
		d.border_color = border
		d.corner_radius = 15.0
		return d
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(15)
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	return style


func _make_price_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.35)
	style.set_corner_radius_all(12)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	return style


func _card_label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"BoldLabel"
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("line_spacing", -4)
	return l


## Builds one shop card.  `opts`: cover (Texture2D), big (String, shown large
## when there is no cover), rarity ("uncommon"/"rare"), stone (Dictionary with
## name/up/lv), text_color, dashed (bool), sold (bool), on_click (Callable).
func _add_shop_card(category: String, title: String, detail: String, price: int, color: Color, available: bool, on_buy: Callable, tooltip: String = "", icon_texture: Texture2D = null, opts: Dictionary = {}) -> void:
	var card := Control.new()
	card.custom_minimum_size = Vector2(156, _card_height)
	card.tooltip_text = tooltip
	var sold: bool = price == -2
	if sold:
		card.modulate.a = 0.35
	elif not available:
		card.modulate.a = 0.45
	var text_color: Color = opts.get("text_color", Color.WHITE)

	var action := Button.new()
	action.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	action.tooltip_text = tooltip
	action.disabled = sold
	var box := _card_box(color, Color("#d3a64a"), opts.get("dashed", false))
	var hover := _card_box(color.lightened(0.08), Color("#f0cf86"), opts.get("dashed", false))
	action.add_theme_stylebox_override("normal", box)
	action.add_theme_stylebox_override("hover", hover)
	action.add_theme_stylebox_override("pressed", hover)
	action.add_theme_stylebox_override("disabled", box)
	action.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if opts.has("on_click"):
		action.pressed.connect(opts["on_click"])
	elif category == "REROLL":
		action.pressed.connect(on_buy)
	else:
		var label := "ซื้อ 🪙 %d" % price
		var blocked := not available
		if blocked:
			if price >= 0 and _main.coins < price:
				label = "เหรียญไม่พอ"
			elif category == "ARTIFACT" and not _main.artifacts.has(null):
				label = "ช่อง Artifact เต็ม"
			elif category == "CHAOS" and not _main.chaos.has(null):
				label = "ช่อง Chaos เต็ม"
			elif price == -1:
				label = "ปิดไว้ก่อน"
		var rar: String = opts.get("rarity", "") if category == "ARTIFACT" else ""
		action.pressed.connect(func():
			_main.show_action_dialog(title, detail, label, on_buy, blocked, rar)
		)
	card.add_child(action)

	var price_text: String = opts.get("price_text", "ซื้อแล้ว" if sold else ("สูงสุด" if price < 0 else "🪙 %d" % price))
	if opts.get("closed", false):
		card.modulate = Color(0.75, 0.72, 0.8, 0.4)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 6.0
	vb.offset_right = -6.0
	vb.offset_top = 10.0
	vb.offset_bottom = -9.0
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 3)
	card.add_child(vb)

	if opts.has("stone"):
		var st: Dictionary = opts["stone"]
		vb.add_child(_card_label(st["name"], 16, text_color))
		var spv := HBoxContainer.new()
		spv.alignment = BoxContainer.ALIGNMENT_CENTER
		spv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spv.add_theme_constant_override("separation", 3)
		for c in st.get("pv", []):
			spv.add_child(_main.ui_renderer.make_mini_card(c[0], c[1], Vector2(29, 39)))
		vb.add_child(spv)
		vb.add_child(_card_label("+%d" % st["up"], 33, text_color))
		vb.add_child(_card_label("Lv%d → %d" % [st["lv"], st["lv"] + 1], 15, Color(1, 1, 1, 0.8)))
	elif opts.has("cover_text"):
		var ct := _card_label(opts["cover_text"], 28, Color("#fff6d6"))
		ct.custom_minimum_size = Vector2(0, 60)
		vb.add_child(ct)
		vb.add_child(_card_label(title, 17, text_color))
	elif icon_texture != null:
		var cover := TextureRect.new()
		cover.custom_minimum_size = Vector2(0, 60)
		cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cover.texture = icon_texture
		cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		vb.add_child(cover)
		vb.add_child(_card_label(title, 17, text_color))
	else:
		var big: String = opts.get("big", title)
		var n := big.length()
		var big_size := 36 if big.contains("\n") else (33 if n <= 4 else (26 if n <= 7 else 21))
		var big_label := _card_label(big, big_size, text_color)
		big_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vb.add_child(big_label)

	var price_label := _card_label(price_text, 19)
	price_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	price_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	price_label.add_theme_stylebox_override("normal", _make_price_style())
	vb.add_child(price_label)

	var rarity: String = opts.get("rarity", "")
	if rarity == "uncommon" or rarity == "rare":
		var tag := Label.new()
		tag.text = "R" if rarity == "rare" else "U"
		tag.theme_type_variation = &"BoldLabel"
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_theme_font_size_override("font_size", 16)
		tag.add_theme_color_override("font_color", Color("#ffcf5a") if rarity == "rare" else Color("#6df0a8"))
		var tag_sb := StyleBoxFlat.new()
		tag_sb.bg_color = Color("#4a3a10") if rarity == "rare" else Color("#1e4a37")
		tag_sb.set_corner_radius_all(9)
		tag_sb.content_margin_left = 7.0
		tag_sb.content_margin_right = 7.0
		tag.add_theme_stylebox_override("normal", tag_sb)
		tag.position = Vector2(156 - 34, 6)
		card.add_child(tag)

	(_offer_target if _offer_target != null else _main.shop_offer_container).add_child(card)


func _chaos_card_look(chaos_def: Dictionary) -> Dictionary:
	var kind: String = chaos_def["kind"]
	var look := {"bg": Color("#a66cf2"), "text": Color.WHITE, "cover": null}
	match kind:
		"color":
			look["bg"] = _main.COLORS.get(chaos_def.get("col", ""), look["bg"])
			look["cover"] = _main.CHAOS_TEX.get("color")
		"goldify":
			look["bg"] = Color("#e8bf4c")
			look["text"] = Color("#3a2a00")
			look["cover"] = _main.CHAOS_TEX.get("goldify")
		"destroy":
			look["bg"] = Color("#b73e3d")
			look["cover"] = _main.CHAOS_TEX.get("destroy")
		"tdir":
			look["bg"] = Color("#23978e")
			look["cover"] = _main.EMBLEMS.get(chaos_def.get("dir", "N"))
		"dirc":
			look["cover"] = _main.EMBLEMS.get(chaos_def.get("dir", "N"))
		"mtile", "crystal":
			look["cover"] = _main.CHAOS_TEX.get(kind)
	return look


func _add_chaos_card(chaos_def: Dictionary, price: int, available: bool, on_buy: Callable) -> void:
	var look := _chaos_card_look(chaos_def)
	var title: String = chaos_name(chaos_def)
	var extra := {"text_color": look["text"]}
	if look["cover"] == null:
		extra["cover_text"] = {"xmult": "×1.2", "xatk": "×1.2"}.get(chaos_def["kind"], chaos_def.get("icon", ""))
	_add_shop_card("CHAOS", title, chaos_desc(chaos_def), price, look["bg"], available, on_buy, title, look["cover"], extra)


func _add_offer_row(label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var lab := Label.new()
	lab.text = label_text
	lab.theme_type_variation = &"BoldLabel"
	lab.custom_minimum_size = Vector2(126, 0)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 18)
	lab.add_theme_color_override("font_color", _main.COLORS["brass_bright"])
	lab.add_theme_constant_override("line_spacing", -2)
	row.add_child(lab)
	_main.shop_offer_container.add_child(row)
	return row


func _owned_slot(parent: Container, kind: String, filled: bool, bg: Color) -> Button:
	var slot := Button.new()
	slot.custom_minimum_size = Vector2(96, 126)
	slot.clip_text = true
	_main.ui_renderer._style_item_slot(slot, filled, bg, _main.COLORS["brass"] if kind == "art" else Color("#c79bff"), kind)
	slot.disabled = not filled
	parent.add_child(slot)
	return slot


func render_shop_owned() -> void:
	for child in _main.shop_items_container.get_children():
		child.queue_free()
	for child in _main.shop_chaos_container.get_children():
		child.queue_free()

	for i in range(MAX_ARTIFACTS):
		var art = _main.artifacts[i]
		var slot := _owned_slot(_main.shop_items_container, "art", art != null, art.get("color", Color.BLACK) if art != null else Color.BLACK)
		if art == null:
			continue
		slot.icon = art_cover(art)
		slot.expand_icon = slot.icon != null
		slot.text = "" if slot.icon != null else str(art["icon"])
		slot.add_theme_font_size_override("font_size", 30)
		slot.tooltip_text = "%s\n%s\nแตะเพื่อขาย 🪙 %d" % [display_name(art), display_desc(art), get_sell_price(art)]
		var sell_idx = i
		slot.pressed.connect(func(): confirm_sell_artifact(sell_idx))

	for i in range(_main.chaos.size()):
		var chaos_card = _main.chaos[i]
		var look := _chaos_card_look(chaos_card) if chaos_card != null else {"bg": Color.BLACK}
		var slot := _owned_slot(_main.shop_chaos_container, "chaos", chaos_card != null, look["bg"])
		if chaos_card == null:
			continue
		var chaos_title := chaos_name(chaos_card)
		slot.icon = look["cover"]
		slot.expand_icon = true
		slot.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		slot.add_theme_constant_override("icon_max_width", 60)
		slot.text = chaos_label(chaos_card) if look["cover"] != null else "×1.2\n" + chaos_label(chaos_card)
		slot.add_theme_font_size_override("font_size", 19)
		slot.add_theme_color_override("font_color", look["text"])
		slot.tooltip_text = "%s\nแตะเพื่อขาย 🪙 %d" % [chaos_title, get_chaos_sell_price(chaos_card)]
		var sell_chaos_idx: int = i
		slot.pressed.connect(func(): confirm_sell_chaos(sell_chaos_idx))


func get_chaos_title(chaos_card: Dictionary) -> String:
	for definition in CHAOS_CATALOG:
		if definition["kind"] != chaos_card.get("kind"):
			continue
		if definition.get("col", "") != chaos_card.get("col", ""):
			continue
		if definition.get("dir", "") != chaos_card.get("dir", ""):
			continue
		return definition["name"]
	return "Chaos"


func get_chaos_icon(chaos_card: Dictionary) -> String:
	for definition in CHAOS_CATALOG:
		if definition["kind"] != chaos_card.get("kind"):
			continue
		if definition.get("col", "") == chaos_card.get("col", "") and definition.get("dir", "") == chaos_card.get("dir", ""):
			return definition["icon"]
	return "✴"


func get_chaos_sell_price(chaos_card: Dictionary) -> int:
	for definition in CHAOS_CATALOG:
		if definition["kind"] != chaos_card.get("kind"):
			continue
		if definition.get("col", "") == chaos_card.get("col", "") and definition.get("dir", "") == chaos_card.get("dir", ""):
			return int(definition["price"]) if _main.has_artifact("fullSell") else 1
	return 1


func confirm_sell_artifact(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= _main.artifacts.size():
		return
	var art = _main.artifacts[slot_idx]
	if art == null:
		return
	var price: int = get_sell_price(art)
	var can_sell: bool = not _main.is_busy or _main.shop_modal.visible
	_main.show_action_dialog(display_name(art), display_desc(art), "ขาย 🪙 %d" % price, func(): sell_artifact(slot_idx), not can_sell, ARTIFACT_RARITY.get(art.get("type", ""), ""))


func confirm_sell_chaos(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= _main.chaos.size():
		return
	var chaos_card = _main.chaos[slot_idx]
	if chaos_card == null:
		return
	var price: int = get_chaos_sell_price(chaos_card)
	_main.show_action_dialog(chaos_name(chaos_card), chaos_desc(chaos_card), "ขาย 🪙 %d" % price, func(): sell_chaos(slot_idx))


func render_shop_offers() -> void:
	for child in _main.shop_offer_container.get_children():
		child.queue_free()
	_offer_target = null
	if shop_tab == "game":
		_card_height = 159.0
		_render_game_offers()
	else:
		_card_height = 183.0
		if shop_tab == "artifact":
			_render_artifact_catalog()
		elif shop_tab == "chaos":
			_render_chaos_catalog()
		else:
			_render_upgrade_catalog()
	_offer_target = null


## Draft `.shsec` section title + a wrapping row of cards below it.
func _add_section(title: String) -> void:
	var first := true
	for child in _main.shop_offer_container.get_children():
		if not child.is_queued_for_deletion():
			first = false
			break
	var lab := Label.new()
	lab.text = title
	lab.theme_type_variation = &"BoldLabel"
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 18)
	lab.add_theme_color_override("font_color", _main.COLORS["brass_bright"])
	if not first:
		var line := StyleBoxFlat.new()
		line.bg_color = Color(0, 0, 0, 0)
		line.border_width_top = 2
		line.border_color = Color(0.827451, 0.65098, 0.290196, 0.3)
		line.content_margin_top = 12.0
		lab.add_theme_stylebox_override("normal", line)
	_main.shop_offer_container.add_child(lab)
	var flow := HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 15)
	flow.add_theme_constant_override("v_separation", 15)
	_main.shop_offer_container.add_child(flow)
	_offer_target = flow


func _render_game_offers() -> void:
	# Row 1: artifacts + reroll card · Row 2: Chaos / Stone / upgrades (draft genOffers).
	_offer_target = _add_offer_row("ARTIFACT")
	for index in range(shop_offers.size()):
		if shop_offers[index]["kind"] == "artifact":
			_render_offer(index)
	_add_shop_card("REROLL", "🎲\nสุ่มใหม่", "", reroll_cost, Color("#473b78"), _main.coins >= reroll_cost, reroll_shop, "สุ่มสินค้าใหม่", null, {"big": "🎲\nสุ่มใหม่", "dashed": true})
	_offer_target = _add_offer_row("CHAOS\nSTONE\nอัปเกรด")
	for index in range(shop_offers.size()):
		if shop_offers[index]["kind"] != "artifact":
			_render_offer(index)


func _render_offer(index: int) -> void:
	var offer: Dictionary = shop_offers[index]
	var captured_index := index
	var sold: bool = offer.get("sold", false)
	var kind: String = offer["kind"]
	if kind == "artifact":
		var item: Dictionary = offer["item"]
		_add_shop_card("ARTIFACT", display_name(item), display_desc(item), -2 if sold else item["price"], item["color"], not sold and _main.artifacts.has(null) and _main.coins >= item["price"], func(): buy_game_offer(captured_index), display_desc(item), art_cover(item), {"rarity": ARTIFACT_RARITY.get(item["type"], "")})
	elif kind == "chaos":
		var chaos_def: Dictionary = offer["item"]
		_add_chaos_card(chaos_def, -2 if sold else chaos_def["price"], not sold and _main.chaos.has(null) and _main.coins >= chaos_def["price"], func(): buy_game_offer(captured_index))
	elif kind == "stone":
		var stone_idx: int = offer["idx"]
		var stone: Dictionary = _main.stone_formulas[stone_idx]
		var stone_cost := get_stone_upgrade_cost()
		var stone_bonus: int = STONE_UPGRADE_BONUSES[stone_idx]
		var stone_level: int = int(stone.get("lv", 1))
		var stone_key := "stone:%d" % stone_idx
		var is_sold: bool = sold or shop_bought.has(stone_key)
		_add_shop_card("STONE", "Stone %s Lv%d → %d" % [stone["name"], stone_level, stone_level + 1], "%s\nค่าเริ่ม ATK %d → %d" % [stone.get("desc", ""), stone["a"], stone["a"] + stone_bonus], -2 if is_sold else stone_cost, Color("#b8741f"), not is_sold and _main.coins >= stone_cost, func(): buy_game_offer(captured_index), "เพิ่มพลังเริ่มต้น Stone", null, {"stone": {"name": stone["name"], "up": stone_bonus, "lv": stone_level, "pv": stone.get("pv", [])}})
	elif kind == "stat":
		var stat: String = offer["stat"]
		var stat_info := _get_stat_offer_info(stat)
		var stat_price: int = HAND_PRICE if stat == "hand" else STAT_PRICE
		var unavailable: bool = shop_bought.has(stat) or (stat == "hand" and _main.hand_max >= HAND_CAP)
		_add_shop_card("UPGRADE", stat_info["title"], stat_info["detail"], -2 if sold or unavailable else stat_price, stat_info["color"], not sold and not unavailable and _main.coins >= stat_price, func(): buy_game_offer(captured_index), stat_info["detail"], null, {"big": stat_info["big"]})


func _get_stat_offer_info(stat_type: String) -> Dictionary:
	match stat_type:
		"hand":
			return {"title": "Hand +1", "big": "Hand\n+1", "detail": "ถือ Gem ในมือได้เพิ่ม 1 ใบ (%d/%d)" % [_main.hand_max, HAND_CAP], "color": Color("#3a8f5a")}
		"walk":
			var pct := roundi(100.0 / float(_main.walk_max))
			return {"title": "HP เพิ่ม", "big": "HP\n+%d%%" % pct, "detail": "เลือดสูงสุดเพิ่ม (รับการโจมตีได้อีก 1 ครั้ง)", "color": Color("#8a5cd6")}
		"disc":
			return {"title": "ทิ้ง +1", "big": "ทิ้ง\n+1", "detail": "ทิ้ง Gem ได้เพิ่ม 1 ครั้งต่อศัตรู", "color": Color("#8a5cd6")}
	return {}


func _render_artifact_catalog() -> void:
	for rarity in ["common", "uncommon", "rare"]:
		_add_section(rarity.to_upper())
		for item in ARTIFACT_CATALOG:
			if not is_draft_enabled(item["type"]) or ARTIFACT_RARITY.get(item["type"], "") != rarity:
				continue
			var captured_item: Dictionary = item
			var owned: bool = has_artifact(_main.artifacts, item["type"])
			_add_shop_card("ARTIFACT", display_name(item), display_desc(item), -2 if owned else item["price"], item["color"], not owned and _main.artifacts.has(null) and _main.coins >= item["price"], func(): buy_artifact(captured_item), display_desc(item), art_cover(item), {"rarity": rarity})
	_add_section("ปิดไว้ก่อน (เสี่ยง bug จากการเปลี่ยนระบบเกม) · แตะดูเหตุผล")
	for item in ARTIFACT_CATALOG:
		if is_draft_enabled(item["type"]):
			continue
		_add_shop_card("ARTIFACT", display_name(item), display_desc(item) + "\n\nปิดไว้ก่อน: ระบบที่ใช้ยังไม่รองรับกระดานแถวเดียว", -1, item["color"], false, func(): pass, display_desc(item), null, {"price_text": "ปิดไว้ก่อน", "closed": true})


func _render_chaos_catalog() -> void:
	_add_section("CHAOS · แตะดูรายละเอียด / ซื้อ")
	for chaos_def in CHAOS_CATALOG:
		var captured_chaos: Dictionary = chaos_def
		_add_chaos_card(chaos_def, chaos_def["price"], _main.chaos.has(null) and _main.coins >= chaos_def["price"], func(): buy_chaos(captured_chaos))


func _render_upgrade_catalog() -> void:
	var hand_maxed: bool = _main.hand_max >= HAND_CAP
	_add_section("อัปเกรดพื้นฐาน")
	for stat in ["hand", "walk", "disc"]:
		var info := _get_stat_offer_info(stat)
		var price: int = HAND_PRICE if stat == "hand" else STAT_PRICE
		var captured_stat: String = stat
		var unavailable: bool = shop_bought.has(stat) or (stat == "hand" and hand_maxed)
		_add_shop_card("UPGRADE", info["title"], info["detail"], -2 if shop_bought.has(stat) else (-1 if unavailable else price), info["color"], not unavailable and _main.coins >= price, func(): buy_stat(captured_stat, price), info["detail"], null, {"big": info["big"]})
	_add_section("STONE")
	for idx in range(_main.stone_formulas.size()):
		var stone: Dictionary = _main.stone_formulas[idx]
		if not _main.discovered_formulas.has(stone["key"]):
			continue
		var cost := get_stone_upgrade_cost()
		var key := "stone:%d" % idx
		var bonus: int = STONE_UPGRADE_BONUSES[idx]
		var level: int = int(stone.get("lv", 1))
		var captured_idx := idx
		var captured_cost := cost
		_add_shop_card("STONE", "Stone %s Lv%d → %d" % [stone["name"], level, level + 1], "%s\nค่าเริ่ม ATK %d → %d" % [stone.get("desc", ""), stone["a"], stone["a"] + bonus], -2 if shop_bought.has(key) else cost, Color("#b8741f"), not shop_bought.has(key) and _main.coins >= cost, func(): buy_stone_upgrade(captured_idx, captured_cost), "เพิ่มพลังเริ่มต้น Stone", null, {"stone": {"name": stone["name"], "up": bonus, "lv": level, "pv": stone.get("pv", [])}})


func buy_game_offer(index: int) -> void:
	if index < 0 or index >= shop_offers.size() or shop_offers[index].get("sold", false):
		return
	var offer: Dictionary = shop_offers[index]
	var before: int = _main.coins
	if offer["kind"] == "artifact":
		buy_artifact(offer["item"])
	elif offer["kind"] == "chaos":
		buy_chaos(offer["item"])
	elif offer["kind"] == "stone":
		buy_stone_upgrade(offer["idx"], get_stone_upgrade_cost())
	elif offer["kind"] == "stat":
		var stat_type: String = offer["stat"]
		buy_stat(stat_type, HAND_PRICE if stat_type == "hand" else STAT_PRICE)
	if _main.coins < before:
		shop_offers[index]["sold"] = true
		render_shop_offers()


func buy_stat(stat_type: String, price: int) -> void:
	if not ["hand", "walk", "disc"].has(stat_type) or shop_bought.has(stat_type):
		return
	if (stat_type == "hand" and _main.hand_max >= HAND_CAP) or _main.coins < price:
		return
	_main.coins -= price
	if stat_type == "hand":
		_main.hand_max += 1
	elif stat_type == "walk":
		_main.walk_max += 1
		_main.walks_left = _main.walk_max
		_main.player_max_hp = _main.enemy_atk * _main.walk_max
		_main.player_hp = _main.player_max_hp
	elif stat_type == "disc":
		_main.discard_max += 1
	shop_bought.append(stat_type)

	_main.update_all_ui()
	render_shop_offers()
	_main.shop_coins_label.text = "🪙 %s" % _main.fmt_num(_main.coins)


func buy_stone_upgrade(formula_idx: int, cost: int) -> void:
	if formula_idx < 0 or formula_idx >= _main.stone_formulas.size():
		return
	var key := "stone:%d" % formula_idx
	if shop_bought.has(key) or cost != STONE_UPGRADE_PRICE or _main.coins < cost:
		return
	_main.coins -= cost
	_main.stone_formulas[formula_idx]["a"] += STONE_UPGRADE_BONUSES[formula_idx]
	_main.stone_formulas[formula_idx]["lv"] = int(_main.stone_formulas[formula_idx].get("lv", 1)) + 1
	shop_bought.append(key)
	if _main.has_artifact("stoneUp"):
		_main.stone_up_multiplier = snappedf(_main.stone_up_multiplier + 0.2, 0.1)
	_main.update_all_ui()
	render_shop_offers()
	_main.shop_coins_label.text = "🪙 %s" % _main.fmt_num(_main.coins)


func buy_artifact(item: Dictionary) -> void:
	var slot: int = _main.artifacts.find(null)
	if slot == -1 or _main.coins < item["price"]: return
	_main.coins -= item["price"]
	_main.artifacts[slot] = item.duplicate()
	_main.sync_totems()
	_main.update_all_ui()
	render_shop_owned()
	render_shop_offers()
	_main.shop_coins_label.text = "🪙 %s" % _main.fmt_num(_main.coins)
	_main.render_artifact_row()


func buy_chaos(definition: Dictionary) -> void:
	var slot: int = _main.chaos.find(null)
	if slot == -1 or _main.coins < definition["price"]:
		return
	_main.coins -= definition["price"]
	var chaos_card: Dictionary = {"kind": definition["kind"]}
	if definition.has("col"):
		chaos_card["col"] = definition["col"]
	if definition.has("dir"):
		chaos_card["dir"] = definition["dir"]
	_main.chaos[slot] = chaos_card
	_main.update_all_ui()
	render_shop_owned()
	render_shop_offers()
	_main.shop_coins_label.text = "🪙 %s" % _main.fmt_num(_main.coins)


func sell_artifact(slot_idx: int) -> void:
	var art = _main.artifacts[slot_idx]
	if art == null: return
	var sell_price = get_sell_price(art)
	_main.coins += sell_price
	_main.artifacts[slot_idx] = null
	_main.sync_totems()
	_main.update_all_ui()
	render_shop_owned()
	render_shop_offers()
	_main.shop_coins_label.text = "🪙 %s" % _main.fmt_num(_main.coins)
	_main.render_artifact_row()


func sell_chaos(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= _main.chaos.size():
		return
	var chaos_card = _main.chaos[slot_idx]
	if chaos_card == null:
		return
	_main.coins += get_chaos_sell_price(chaos_card)
	_main.chaos[slot_idx] = null
	_main.update_all_ui()
	render_shop_owned()
	render_shop_offers()
	_main.shop_coins_label.text = "🪙 %s" % _main.fmt_num(_main.coins)


func on_shop_leave() -> void:
	_main.shop_modal.visible = false
	_main.stage += 1
	_main.enemy_pic.modulate = Color.WHITE
	_main.enemy_pic.scale = Vector2.ONE

	# Enemy scaling per draft
	_main.enemy_max_hp = int(_main.enemy_max_hp * 1.5)
	_main.enemy_hp = _main.enemy_max_hp
	_main.enemy_atk = int(_main.enemy_atk * _main.PHP_GROW)

	_main.walks_left = _main.walk_max
	_main.player_max_hp = _main.enemy_atk * _main.walk_max
	_main.player_hp = _main.player_max_hp

	# Wild Shuffle permits discarding after placement, in exchange for one use.
	_main.discards_left = maxi(0, _main.discard_max - (1 if _main.has_artifact("freediscard") else 0))

	_main.build_deck()
	_main.spawn_current_enemy()


func on_artifact_slot_pressed(slot_idx: int) -> void:
	# Draft openOwnedPop(): name, rarity, description and a sell button.
	confirm_sell_artifact(slot_idx)
