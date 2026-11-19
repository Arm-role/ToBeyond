---
name: tobeyond-dev
description: Work on ToBeyond, the Godot 4.7 GDScript game - change screens, text, numbers, game logic and game feel (animation, easing, timing, sfx on the beat, juice, hit-stop, shake, pacing), build the Web export, record animations to check them, compare layout with the old draft when the user orders it, deploy previews. Use for any change under scripts/, scenes/ or assets/, for animation / game feel / juice requests ("ให้ลื่น", "เร็วไป", "พุ่ง", "ค้าง"), and before running or testing the game.
---

# ToBeyond in Claude Code

Read the [shared workflow](../../../docs/tobeyond-dev/workflow.md) before game work. Claude Code hook rules are documented in [CLAUDE.md](../../../CLAUDE.md). Honor the hook prompts for draft access and protected operations.

- Batch shell work and keep output short. Keep one task per session and use the shared feature map for targeted reads. Group fixes into one Web build where practical.
- Use `runner` for long commands and `advisor` for major decisions, repeated failures, or the final review of a large task. Give the advisor the relevant files and one concrete question.
- Use the `parity-check` skill and `parity-checker` for image comparisons when available. Start with text reports for layout and timing differences.
- When repeated fixes or an advisor review reveal a reusable lesson, add it to the shared pitfalls guide. Use `python3 tools/parity/token_report.py` to report costs for large tasks.
