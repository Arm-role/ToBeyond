---
name: parity-check
description: Compare the ToBeyond Godot build with To_Beyond_Draft.html for test scenarios (main, arts, boss, win, shop, lose, deck, stone) and get back a short list of visible differences. Runs in the parity-checker agent so screenshots stay out of the main conversation.
argument-hint: "[scenario,scenario] [--region=screen|center|top|board|bottom] [--seq]"
context: fork
agent: parity-checker
background: false
---

Check parity for: $ARGUMENTS

If no scenario is given, use `main,placed,boss` with `--region=screen` and `win,shop,lose,deck,stone` with `--region=center`.
Follow your agent instructions and reply in the agreed short format.
