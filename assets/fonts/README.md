# Fonts

| File | Font | License |
|---|---|---|
| `Sarabun-Regular.ttf`, `Sarabun-Bold.ttf` | [Sarabun](https://github.com/cadsondemak/Sarabun) (Thai + Latin, same as `To_Beyond_Draft.html`) | SIL OFL 1.1 (`OFL.txt`) |
| `NotoColorEmoji.ttf` | [Noto Color Emoji](https://github.com/googlefonts/noto-emoji) | SIL OFL 1.1 |
| `Gelasio-Regular.ttf`, `Gelasio-Bold.ttf` | [Gelasio](https://github.com/SorkinType/Gelasio) (Latin serif, Georgia metrics; headings) | SIL OFL 1.1 |
| `NotoSerifThai-Regular.ttf`, `NotoSerifThai-Bold.ttf` | [Noto Serif Thai](https://github.com/notofonts/thai) (Thai fallback for Gelasio) | SIL OFL 1.1 |

`main_theme.tres` is set as the project theme (`gui/theme/custom`): Sarabun is the default
font with Noto Color Emoji as a fallback, so Thai text and emoji render in Web builds
(where Godot cannot fall back to system fonts). Headings (enemy name, victory and shop titles) use the `SerifLabel` type: Gelasio with Noto Serif Thai for Thai, the same stack as the draft's `@font-face` rules.

Only use symbols covered by these two fonts; other glyphs render as empty boxes on Web.
