# L'IA ne fera rien sans nous

**Industrialiser et dompter Gemini CLI en équipe**

Talk presented at [GDG Cloud Paris](https://gdg.community.dev/gdg-cloud-paris/) — March 17, 2026.

> **Language:** French (`lang: fr`). An English version may be added later.

## Viewing the slides

The presentation was built with [Slides Extended](https://github.com/ebullient/obsidian-slides-extended) (Obsidian plugin, powered by reveal.js).

### Option 1 — Local HTTP server (recommended)

Any static HTTP server works. From this directory:

```bash
# Python
python3 -m http.server 8000

# Node
npx serve .
```

Then open <http://localhost:8000> in your browser.

> **Note:** opening `index.html` directly as a `file://` URL will not work because
> reveal.js needs to fetch `Slides.md` via HTTP.

### Option 2 — Obsidian + Slides Extended

If you use Obsidian with the *Slides Extended* community plugin installed, open
`Slides.md` and trigger the slide preview as usual.

## Contents

| File | Description |
|------|-------------|
| `Slides.md` | Slide deck (Markdown + reveal.js directives) |
| `gdg-theme.css` | Custom GDG Material theme |
| `index.html` | Standalone reveal.js viewer (CDN-based) |
| `assets/` | Images used in the slides |
