# เฟส 3: event stream + Artifact เป็นข้อมูล

ต้องอ่านก่อน: `docs/plan-domino-run.md`, `docs/design-principles.md`, `scripts/greybox/greybox.gd`.
เป้าหมาย: เกมเล่นเหมือน v0.1.21 กับ Artifact 3 ใบเดิม แต่ **กฎอยู่ในตัวจำลองล้วน (ไม่มี UI, ไม่มี await)** และ Artifact เป็นข้อมูล. การวิ่งทุกรอบคือรายการ event ที่แน่นอน (deterministic).

## ขอบเขต
- ทำ: ตัวจำลอง, log ของ event, rule engine, เพดานกันลูป, Artifact 3 ใบเป็น `.tres`, สคริปต์ regress แบบ headless, แยก `_run()` ออกเป็นการเล่นซ้ำ event
- ไม่ทำ: Artifact ใหม่, เลือกรางวัล, เหรียญ, บอส, ขัดเกลาภาพ

## ต้องแก้ก่อน/ระหว่างเฟสนี้ (ปัญหาที่ advisor เจอ)
1. `tools/parity/build.sh` บรรทัด ~16 ตรวจ parse เฉพาะ `scripts/*.gd` → เปลี่ยนเป็น `find scripts -name '*.gd'` (ตอนนี้ `scripts/greybox/` และ `scripts/artifacts/` ไม่ถูกตรวจ)
2. `build.sh` smoke-run เฉพาะฉากหลัก (`--dbg=main`) → เพิ่ม smoke ของ `--mode=greybox`: view พิมพ์ `TB_DOMINO_OK` เมื่อแจกมือเทิร์นแรกแล้ว
3. `class_name` ใหม่ไม่ถูกรู้จักจนกว่า class cache จะสร้างใหม่ (pitfalls.md) → ใช้ `preload()` เป็นค่าคงที่ใน `scripts/domino/` หรือรัน `build.sh` หนึ่งครั้งหลังเพิ่มคลาส

## ไฟล์ (โฟลเดอร์ใหม่ `scripts/domino/`, โหลดด้วย `preload`)
- `domino_rule.gd` (Resource): `trigger: StringName`, `cond: Dictionary`, `effect: StringName`, `args: Dictionary`, `once: StringName` (`&""` | `&"walk"` | `&"fight"`)
- `domino_artifact.gd` (Resource): `id`, `name_th`, `icon`, `text_th`, `archetype` (`blaze|guard|route|ember`), `rarity` (`common|uncommon|rare`), `price:int`, `rules: Array[Resource]`
- `domino_catalog.gd` (static): เลียนแบบ `ArtifactSystem._files()` รวมการ trim `.remap` ที่ web export ต้องใช้ โหลด `data/domino/artifacts/*.tres`
- `domino_sim.gd` (RefCounted ไม่ใช่ Node ไม่มี await): สถานะทั้งหมด
  - `hp, max_hp, enemy_hp, enemy_max, strike_dmg, flags: Array[int]` (ใช้ array ตั้งแต่ตอนนี้ เพราะบอสธงคู่ในเฟส 5 ต้องการ)
  - `board: {tile: {color, life:int, kept:bool, temp:bool}}`, `slots: Array[DominoArtifact]`, `walk_no`, `rng: RandomNumberGenerator` (seed ได้)
  - API: `start_fight(stage)`, `deal_hand() -> Array[String]`, `place(tile, color)`, `run_walk() -> Array[Dictionary]`
- `domino_view.gd` แทน `greybox.gd` (เก็บภาพทั้งหมด): `_run()` กลายเป็น `for ev in sim.run_walk(): await _play(ev)`. view อ่าน HP จากฟิลด์ `hp_after` ใน event เท่านั้น ไม่อ่านจาก sim ระหว่างเล่นอนิเมชัน
- `scenes/greybox.tscn` ชี้ไป `domino_view.gd`, `?mode=greybox` ใช้ต่อได้
- `data/domino/artifacts/*.tres`
- `tools/parity/domino_regress.gd` ใหม่ รันผ่าน `TB_REGRESS_SCRIPTS=artifact_regress,domino_regress` ใน `regress.sh`

## รูปแบบ event
`{k, i (ดัชนีใน log), step, tile, dir (+1/-1), lap, depth, src ("base" หรือ id ของ artifact), ...payload}`

| k | payload | ออกเมื่อ |
|---|---|---|
| `ignite` | `walk` | ก่อนก้าวแรก |
| `pass` | — | ลูกไฟเข้าช่อง ทุกก้าว |
| `pop` | `color, nth (ลำดับป๊อปในรอบ), tile_pops, cause ("pass" หรือ id artifact), kept, temp` | Gem บนช่องทำงาน |
| `hit` | `target (enemy/hero), amount, hp_after` | ความเสียหายทุกชนิด |
| `shield` | `amount, total` | ได้โล่ |
| `strike` | `dmg, block, redirect ("" หรือ "enemy"), tile_color` | ลูกไฟเข้าช่องธง แก้ไขได้ระหว่าง artifact ตอบสนอง |
| `shield_break` | — | หลังการตีทุกครั้ง |
| `reach_end` | — | ช่องสุดท้ายของเส้นทางในทิศปัจจุบันเสร็จ |
| `bounce` | — | เปลี่ยนทิศแล้วเข้าช่องเดิมซ้ำ |
| `kill` | `target` | HP ถึง 0 การวิ่งหยุด |
| `walk_end` | `kept_tiles` | จบรอบ |
| `capped` | `what (pop/depth/steps/events)` | เพดานทำงาน view แสดงป้ายเล็ก "สุดทาง" |

### ลำดับที่รับประกัน
1. ในแต่ละช่อง: `pass` → `pop` (ถ้ามี Gem) → `strike` (ถ้าช่องมีธง). คงกฎเดิมว่า Gem น้ำเงินบนช่องธงนับ
2. ทุก event: ผลในตัวทำงานก่อน (แดง = `hit` 4, น้ำเงิน = `shield` +3, strike = `hit` หรือไม่มีอะไร) แล้ว artifact ตอบสนอง **ตามลำดับช่อง ซ้ายไปขวา** และกฎของแต่ละ artifact ตามลำดับที่เขียน
3. ปฏิกิริยาเป็น depth-first: event ลูกจบสมบูรณ์พร้อมปฏิกิริยาของมันก่อน event พี่น้องถัดไป ข้อยกเว้น: `strike` ปฏิกิริยาแบบแก้ไขทั้งหมดทำงานก่อนที่มันจะ resolve
4. `kill` ล้างคิว เหลือเฉพาะกฎที่ trigger ด้วย `kill`
5. trigger ที่ artifact ใช้ได้: `ignite, pass, pop, strike, reach_end, kill, walk_end, fight_start` เท่านั้น. `hit` และ `shield` เป็น trigger ไม่ได้ (ตัดวงจรดาเมจป้อนดาเมจที่ราก)

## เงื่อนไข (`cond`, ทุกคีย์ต้องตรง)
`color`; `tile` (`"flag"|"first"|"last"|เลขช่อง`); `dir` (`fwd|back`); `nth`, `every` (nth % every == 0); `cause` (กริยา `repop` ต้องมี `cause:"pass"` โดยปริยาย); `kept`; `temp`; `neighbor` (ช่องข้างเคียงซ้ายหรือขวามี Gem สีนั้น); `before_flag` (ยังมีธงข้างหน้าในรอบนี้); `flag_struck` (มีการตีแล้วในรอบนี้); `tile_color` (กับ event strike); `blocked_full` (strike: `block >= dmg` และ `redirect == ""`)

## กริยา (effect verbs, ชุดตายตัว)
`damage{amount}`, `shield{amount}`, `heal{amount}`, `repop{where: same/next}`, `bounce{}`, `reflect_strike{mult}`, `keep_gems{walks}`, `spawn_gem{color, where: first_empty, temp:true}`, `move_flag{delta}`, `add_stat{stat, amount, max}` (ขอบเขตหนึ่งรอบ), `set_route{start:"after_flag", wrap:true}`, `convert{to:"damage"}`, และ `gold{amount}` (เฟส 5).
`amount` เป็นตัวเลขหรือชื่อคีย์ใน payload (`"base"` = ค่าของ Gem เอง, `"excess"` = โล่ลบดาเมจ)

## เพดาน (ค่าคงที่ใน `domino_sim.gd`; ตัวแรกที่ชนส่ง `capped` และหยุดกิ่งนั้น)
- ช่องหนึ่งป๊อปไม่เกิน **3 ครั้ง/รอบ**; หนึ่งรอบไม่เกิน **24 ป๊อป**
- ความลึกปฏิกิริยาไม่เกิน **3**
- artifact แต่ละใบทำงานไม่เกิน **8 ครั้ง/รอบ**
- เด้งไม่เกิน **2 ครั้ง** และไม่เกิน **3×8 ก้าว** ต่อรอบ
- ไม่เกิน **400 event/รอบ** (ชนแล้วจบรอบทันที)
- เป็นเจ้าของ artifact ใบเดียวกันได้ใบเดียว
- view คุมเวลาเคลื่อนลูกไฟให้ ≤ 2.5 วินาที: `step_dur = min(0.20, 2.2/steps)` (เวลาหยุดตอนตีไม่นับ)

## Artifact 3 ใบเดิมเป็นข้อมูล
- `mirror`: `reach_end, cond{dir:fwd}, bounce` → ลูกไฟเข้าช่อง 8 ซ้ำแล้วเดิน 8→1 ทุก Gem และธงทำงานสองครั้ง ตรงกับ `seq` ปัจจุบัน
- `coal`: `walk_end, cond{kept:false, temp:false}, keep_gems{walks:1}` ตรงกับ `_end_walk` (Gem ที่ถูกเก็บแล้วไม่ถูกเก็บซ้ำ)
- `riposte`: `strike, cond{tile_color:"blue"}, reflect_strike{mult:1}, once:walk` → resolver เห็น `redirect=="enemy"` ส่ง `hit(enemy, dmg)` ฮีโร่ไม่โดน; `once:walk` กันสะท้อนซ้ำเมื่อมีกำแพงกระจก

## ลำดับงาน
1. แก้ glob ใน `build.sh` (+ smoke greybox)
2. เขียน Resource สองตัวและ `.tres` 3 ไฟล์
3. เขียน `domino_sim.gd` ยังไม่มี artifact ให้ตัวเลขตรงกับของเดิม
4. เพิ่ม rule engine และเพดาน
5. เขียน `domino_regress.gd`: seed และกระดานคงที่; ปิด artifact; แต่ละใบเดี่ยว; ทั้ง 3 พร้อมกัน; กระดาน stress ที่ชนเพดาน; พิมพ์หนึ่งบรรทัดต่อหนึ่ง event
6. สร้าง baseline (`tools/parity/regress.sh --update`)
7. พอร์ต view ให้เล่น event ซ้ำ ปุ่มสลับ debug ตอนนี้เติมลง `slots`
8. เพิ่ม smoke headless `--mode=greybox` ใน `build.sh`

## ทดสอบ
- regress ต้องเหมือนกันแบบ byte-identical สองรอบ
- ด้วยตา: mirror = ช่อง 8 ป๊อปสองครั้งติดกันและธงตีสองครั้ง; riposte = ลำแสงทองกลับไปศัตรู; coal = Gem ที่ถูกเก็บมีกรอบ; เพดาน = เห็นป้ายและไม่ค้าง
- เปรียบเทียบกับ v0.1.21 ด้วยตาทีละปุ่มสลับ ก่อนลบโค้ดเก่า

## เสร็จเมื่อ
greybox เล่นเหมือน v0.1.21 กับแต่ละปุ่ม; `greybox.gd` ไม่มี `_run` แล้ว; regress และ `--check` ผ่าน

## ความเสี่ยง / ถอยกลับ
พฤติกรรมเพี้ยนระหว่างพอร์ต → ถอยด้วย git (ฉากชี้ไปสคริปต์เดียว). ปรึกษา `advisor` ก่อนเริ่ม (โครงข้อมูล) และก่อนประกาศจบ
