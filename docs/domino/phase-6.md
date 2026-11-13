# เฟส 6: ทำให้ Domino เป็นเกมหลัก และลบของเก่า

ต้องอ่านก่อน: `docs/plan-domino-run.md` และเฟส 3–5 ต้องเสร็จ. **อย่าลบอะไรในเฟสนี้จนกว่าผู้ใช้ยืนยัน** และอย่าลบใน push เดียวกับการสลับฉากหลัก.

## ขั้นตอน (แต่ละขั้นเป็น commit และเพิ่มเวอร์ชันของตัวเอง)
1. เปลี่ยนชื่อเป็น `scenes/domino.tscn`, ตั้ง `run/main_scene` ให้ชี้ไป, ย้ายการเช็กอาร์กิวเมนต์เริ่มต้นไปที่ `domino_view._ready`: `?mode=classic` เรียก `change_scene_to_file("res://scenes/main.tscn")` เกมเก่ายังเล่นได้หนึ่งรุ่น
2. ชี้ smoke ใน `build.sh` ไปที่ `TB_DOMINO_OK` และเลิกบังคับ `--dbg=main` / `TB_RECTS`
3. เมื่อผู้ใช้ยืนยัน ลบเกมเก่า

## ลบ
- `scripts/main.gd`, `action_dialog.gd`, `battle_manager.gd`, `board_calc.gd`, `board_input.gd`, `slot_drag.gd`, `toolbar_controls.gd`, `reward_flow.gd`, `shop_manager.gd`, `ui_renderer.gd`, `debug_scenarios.gd`, `card_sway.gd`
- `scenes/main.tscn`, `scripts/artifacts/**`, `data/artifacts/*.tres`
- `tools/parity/artifact_regress.gd`, `tools/parity/baseline/artifact_regress.txt`, `parity.js`, `scenarios.js`
- แผนเก่า (`plan-chaos-data-driven`, `plan-core-loop-path`, `plan-gem-types`, `refactor-main-split`) ย้ายไป `docs/archive/`

## เก็บ
`sfx_manager.gd`, `fx_particles.gd`, `vfx_manager.gd`, `game_assets.gd`, `dashed_style_box.gd` (ไม่มีตัวไหนใช้ `_main`), `assets/fonts/main_theme.tres`, `assets/pwa`, `assets/shaders`, `tools/parity/setup_godot.sh`, `build.sh`, `regress.sh`, `record.js`, `check_refs.py`, `tools/hooks/`. ใน `node_tree.py` ให้ชี้ path ฉากใหม่.

## ต้องอัปเดตใน commit เดียวกัน
- `CLAUDE.md` (โครงโค้ด), `.claude/skills/tobeyond-dev/SKILL.md` และ `reference/map.md` (ไม่งั้น `check_refs.py` ทำ `--check` ล้ม)
- เลิกใช้หรือชี้ใหม่ agent `parity-checker` และ skill `parity-check`
- **ถามผู้ใช้ก่อนแตะ** `.claude/settings*.json` หรือ `tools/hooks/` (มี hook ถามสิทธิ์)

## เช็กก่อนลบ asset
ลบ `assets/tiles` และ `assets/emblems` ต่อเมื่อ `grep -r` แล้วไม่มีที่ใช้นอกไฟล์ที่ถูกลบ.

## เสร็จเมื่อ
`build.sh --check`, `--regress` (เฉพาะ domino) และ web export ผ่านทั้งหมด; preview ที่ root URL เปิดเกม Domino; `grep -r "ArtifactSystem\|_main\." scripts` ไม่พบอะไร

## ถอยกลับ
ขั้น 3 เป็น revert commit เดียว; `?mode=classic` ของขั้น 1 ใช้งานได้ตลอด
