# Plan: ลบ Chaos + Stone, Gem มีผลต่างชนิด (โจมตี / โล่ / รักษา)

สถานะ: ร่างเพื่อตัดสินใจ ยังไม่เริ่มเขียนโค้ด (2026-11-13). ตรวจโดย `advisor` แล้ว (verdict: go with changes)
เอกสารเดิม `docs/plan-core-loop-path.md` (กริด 2 มิติ) เก็บไว้เป็นทางเลือกสำรอง ไม่ทำคู่กัน

## 1. ข้อเสนอ

1. ธีม ทิศ ลัทธิ Artifact ร้านค้า บอส กระดาน 8 ช่อง คงเดิม
2. **ลบระบบ Chaos และ Stone**
3. **Gem แต่ละใบให้ผลคนละชนิด** (โจมตี โล่ รักษา ...) แทนการรวมทุกอย่างเป็นเลขดาเมจตัวเดียว
4. เป้าหมาย: เกมแนว "สร้างบิลด์" ที่ไม่ใช่ก๊อป Balatro

## 2. ข้อค้นพบสำคัญจาก advisor

1. **HP ปัจจุบันไม่ใช่ HP จริง** `battle_manager.gd:605` ตั้ง `player_hp = enemy_atk * walks_left` คือเป็นตัวนับจำนวนรอบ ดังนั้นโล่/รักษาจะ *ไม่มีผลเลย* จนกว่าจะเปลี่ยนเป็น HP จริง (ศัตรูตีเท่า `enemy_atk` โล่ดูดซับ รักษาเติม)
2. **ส่วนที่ยังเป็น Balatro:** `compute_attack` = chips × mult, Artifact ยิงทีละสล็อตตามลำดับเหมือน Joker, Artifact 30+ ตัวเป็น +atk/+mult/×mult ล้วน, ทิ้งไพ่ + เรียงมือ
3. ข้อเสนอ "ลบ Chaos/Stone + Gem หลายชนิด" ไม่พอถ้าไม่เปลี่ยนโมเดล HP และรูปแบบคะแนนไปพร้อมกัน ไม่งั้นชนิด Gem ใหม่เป็นแค่ลวดลาย
4. ร้านค้าเก็บไว้ได้ ร้านค้าอย่างเดียวไม่ทำให้เกมเหมือน Balatro

## 3. ดีไซน์ Gem (แนะนำ Option 1: สี = ชนิดผล)

| สี | ผล (ร่าง) |
|---|---|
| แดง | โจมตี |
| น้ำเงิน | โล่ |
| เขียว | รักษา |
| ส้ม | ทอง หรือชาร์จ (ต้องตัดสินใจ) |

- **ทิศ** ยังเป็นแกนบิลด์: Gem ทิศตรงกับ `TILE_DIR` ของช่อง = "attuned" ผลคูณสอง หรือทำงานสองครั้ง
- **คอมโบ (แทน Stone):** Gem สีเดียวกันติดกันเป็นสาย แต่ละใบได้ +1 ต่อเพื่อนบ้านในสาย อ่านง่ายในพริบตา
- ตึงเครียดที่ตั้งใจ: แดงล้วนฆ่าเร็วแต่โดนตี, น้ำเงิน/เขียวรอด แต่ฆ่าช้า (เห็น intent ของศัตรูก่อนวาง)
- Artifact กลายเป็นตัวแปลง เช่น "Gem แดงบนช่องทิศใต้ให้โล่ 2" หรือ "แปลงโล่ส่วนเกินเป็นดาเมจ"
- Option 2 (ทิศ = ชนิดผล, สี = กุญแจคอมโบ) **ไม่แนะนำ**: `TILE_DIR` จะกำหนดผลต่อช่องตายตัว กระดานแก้เองได้

### โมเดลต่อการเดิน
1. เดิน: รวม dmg / block / heal / (gold)
2. ดาเมจศัตรู → เติม HP ผู้เล่น (ไม่เกินเพดาน) → ศัตรูตีเท่า intent − block
3. โล่รีเซ็ตทุกการเดิน (หรือเก็บได้ด้วย Artifact)
4. แต่ละชนิดมี "ราง" ของตัวเอง ไม่ใช้ mult ร่วม ×mult จาก Artifact จำกัดเหลือไม่กี่ชิ้น หรือแปลงเป็น "+1 ต่อชนิด X" / "แปลง X เป็น Y"

## 4. ขอบเขตการลบ

**ต้องย้ายก่อนลบ:** `chaos_controller.gd` มีโค้ดอินพุตหลักที่ต้องอยู่ต่อ: `on_tile_clicked`, `on_discard_pressed`, `place_from_hand`, `move_board_card`, `return_board_card` ย้ายไป `board_input.gd` (หรือ main) ก่อนลบ ไม่งั้นวาง/ทิ้งการ์ดพัง

**Stone**
- `stone_calc.gd` ทั้งไฟล์ (รวม `solve_best_placement` ที่ auto-place ใช้ ที่ `main.gd:737`)
- `board_calc.gd`: `calculate_groups` (+ กฎ `equal_groups`), `matching_group_count`, `compute_attack`, `apply_tile_walk_effects` (อ่าน `grp_val`)
- `main.gd`: `stone_formulas`, `StoneCalc.validate_formulas`, ปุ่ม/โมดัล Stone, toast ค้นพบสูตร, `refresh_calc`
- `ui_renderer.gd`: ฟังก์ชัน gstrip, `setup_stone_modal_content`
- `artifact_context.gd`: `calc`, `gain`, `color_groups`, `matching_groups`
- hook `stone_upgrade` (`artifact_system.gd`, `artifact_effect.gd`, `counter_effect.gd`, ผู้เรียกใน `shop_manager.gd`)

**Chaos**
- `main.gd`: `chaos`, `chaos_*_tiles`, `chaos_crystals`, `chaos_slots`/ChaosRow, แท็บ Chaos ในร้าน, `reset_chaos`, `give_random_chaos`, `passive_chaos_tile_count`; `chaos_msg` เป็น toast ทั่วไป เก็บไว้และเปลี่ยนชื่อ
- `shop_manager.gd`: `CHAOS_CATALOG`, `buy_chaos`, `sell_chaos`, `_render_chaos_catalog`, `chaos_label/name/desc`
- `artifact_system.gd`: `chaos_all`, `chaos_def`, `chaos_used`
- `scripts/artifacts/chaos/*`, `chaos_data.gd`, `data/chaos/*`
- คริสตัล: `battle_manager.gd` (`_hit_crystal` และจุดที่เกี่ยวข้อง), `shuffle_totems`, การนับช่องว่างใน `artifact_context`, รางวัลบอสใน `reward_flow.gd`
- `slot_drag.gd` (ช่อง chaos), `ui_renderer.render_chaos_row`

**Artifact**
- ลบ: `chaosAtk`, `chaosStack`, `orangeN`, `tileAtk`, `stoneUp`, `stone3`, `equalG`, `redS`
- เขียนใหม่: `fullSell` (คำอธิบายกล่าวถึง Chaos), `firstGem`, `isoGem`, `west5` (อ่าน `ctx.gain` ต้องมีค่าต่อช่องแบบใหม่)
- ตรวจ: `stone7E`/`stone7W` (ใช้ `matching_cards` น่าจะไม่กระทบ)

**เครื่องมือ**
- `tools/parity/chaos_dump.gd`, `chaos_use.gd` + baseline, `artifact_regress.gd`, แถวใน `map.md` (`check_refs.py` จะล้มถ้าชื่อที่ลบยังอยู่ ต้องอัปเดต map.md ในขั้นเดียวกัน)

## 5. เฟส (ทุกเฟสต้องผ่าน `build.sh --check`)

| เฟส | งาน |
|---|---|
| P0 | ย้ายโค้ดอินพุตออกจาก `ChaosController` ไม่เปลี่ยนพฤติกรรม |
| P1 (ทำแล้ว: ศัตรูตี = `player_hp -= enemy_atk`, เติมเต็มทุกศัตรูเหมือนเดิม; HP ต่อเนื่องข้ามศัตรูยังไม่ทำ รอจูน P5) | **HP จริง + intent ของศัตรู** (ดาเมจยังเป็น atk×mult ชั่วคราว) ปรับ `on_shop_leave` ที่คูณ HP ×1.5 |
| P2 (ทำแล้ว: Gem ละ 2 ATK คงที่ `BoardCalc.GEM_ATK`, auto-place greedy, ลบ equalG/stone3/stoneUp/redS/orangeN) | ลบ Stone: Gem ให้ค่าคงที่ต่อใบ (`calculate_groups` คืนกลุ่มว่าง `grp_val` = ค่าการ์ด คงซิกเนเจอร์ไว้ก่อน), ลบ/เขียน Artifact ที่อ่านกลุ่ม, auto-place เป็น greedy แบบง่าย, ลบไฟล์/โมดัล/gstrip/toast |
| P3 | ลบ Chaos ตามลำดับ: รางวัล+แท็บร้าน → ช่อง/แถว/ลาก → คริสตัลในการเดิน → data+scripts → parity tools+baseline → map.md |
| P4 | ชนิด Gem ตามสี + สายสีเดียวกัน + attuned + เลิกใช้ mult ร่วม |
| P5 | ปรับ Artifact/ร้าน/รางวัลให้เข้ากับ resource ใหม่ จูนตัวเลข `--regress --update` |

## 6. ความเสี่ยง

1. ลบ `ChaosController` ทั้งก้อนทำให้วาง/ทิ้งการ์ดพัง (แก้ด้วย P0)
2. การสเกลพัง: `on_shop_leave` คูณ HP ×1.5 ใช้ไม่ได้เมื่อดาเมจไม่มี mult
3. baseline และ `check_refs.py` ล้มเพราะชื่อที่ลบ
4. auto-place หายไปพร้อม `StoneCalc`
5. Artifact เหลือน้อยหลังลบราว 8 ตัว ร้านจะเสนอซ้ำ ต้องเขียนชุดใหม่ (เฟส P5)
6. (ข้อสังเกตเพิ่ม) P1 เปลี่ยนความรู้สึกของเกมมากที่สุด ควรเล่นทดสอบก่อนไปต่อ

บทเรียนที่ควรเพิ่มใน `reference/pitfalls.md` ตอนเริ่มทำ: `player_hp` ดูเหมือน HP แต่ถูกตั้งเป็น `enemy_atk * walks_left` (`battle_manager.gd:605`) จึงเป็นตัวนับรอบ ต้องทำให้เป็น HP จริงก่อนเพิ่ม Gem ป้องกัน

## 7. คำถามที่ต้องตัดสินใจ

1. HP ผู้เล่นต่อเนื่องข้ามศัตรู หรือรีเซ็ตทุกศัตรู? ยังมีจำนวนรอบเดินจำกัดต่อศัตรูหรือไม่ (`walks_left`)?
2. ชนิดผลมีแค่ โจมตี/โล่/รักษา หรือเพิ่ม ทอง/ชาร์จ/พิษ?
3. สี = ชนิดผล (แนะนำ) หรือ ทิศ = ชนิดผล?
4. เก็บ ×mult ไว้บ้างไหม (เช่น 1 ชิ้นต่อ run) หรือเลิกหมด?
5. รางวัลบอส (ผลึก Chaos) เปลี่ยนเป็น Artifact ใช่ไหม?
6. เก็บ auto-place ไว้ไหม (ถ้าเก็บ ต้องเขียน greedy ใหม่)?
7. ค่าเริ่มต้นถ้าไม่ตอบ: HP ต่อเนื่อง + ยังมีจำนวนรอบจำกัด / แดง-น้ำเงิน-เขียว-ส้ม(ทอง) / สี = ชนิด / ×mult เก็บ 1 ชิ้น / บอสให้ Artifact / เก็บ auto-place แบบ greedy
