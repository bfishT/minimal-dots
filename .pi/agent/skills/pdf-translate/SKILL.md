---
name: pdf-translate
description: Translate academic PDF papers from English to Chinese while preserving the original layout. Use when the user asks to translate a PDF, paper, or tech report into Chinese (or another target language).
---

# PDF translation (layout-preserving)

Use `pdf2zh` (PDFMathTranslate, installed via `uv tool`) to translate PDFs. It
rebuilds the PDF with translated text in place, keeping figures, tables,
formulas, and two-column layout intact.

## Basic usage

Run from the directory containing the PDF:

```bash
mkdir -p translated
pdf2zh <file.pdf> -s <service> -o translated
```

Outputs two files in `translated/`:

- `<name>-mono.pdf`: fully translated version
- `<name>-dual.pdf`: side-by-side bilingual version

Useful flags:

- `-p 1-3`: translate only selected pages (do a 1-page smoke test first for long papers)
- `-li en -lo zh`: source/target language codes
- `--ignore-cache`: force retranslation (pdf2zh caches by content otherwise)
- `--prompt <file>`: custom LLM prompt. In pdf2zh v1.9 this takes a **file
  path**, not inline text; the file must contain `$text` where source text is
  substituted. A ready-made prompt lives at `prompt.txt` next to this SKILL.md:

```bash
pdf2zh file.pdf -s openai --prompt <skill-dir>/prompt.txt -o translated
```

## Translation services

- Free, no key: `-s bing` (Google is rate-limited from this network)
- LLM quality (preferred for papers): `-s openai` with env vars:

```bash
export OPENAI_BASE_URL=https://api.ilovetoken.top/v1
export OPENAI_API_KEY=$(python3 -c "import json;print(json.load(open('$HOME/.pi/agent/auth.json'))['ilovetoken']['key'])")
export OPENAI_MODEL=glm-5.3
pdf2zh file.pdf -s openai --prompt <skill-dir>/prompt.txt -o translated
```

Read the API key from `~/.pi/agent/auth.json` (field `ilovetoken.key`) at runtime; do not hardcode it.

## Workflow

1. Confirm the target file path and page range with the user if unclear.
2. For papers over ~5 pages, translate page 1 first and report the output path
   so the user can check quality before committing to the full document.
3. Long documents can take several minutes; run with a generous timeout and
   report progress. Never let the user wait silently.
4. Report both `-mono.pdf` and `-dual.pdf` paths when done. If a translated
   page comes out as chat-style text ("please provide the text to translate"),
   the prompt file is missing the `$text` placeholder or was passed inline;
   fix that and rerun with `--ignore-cache`.

For delegated/background translation, a `translator` subagent is available via
the `subagent` tool.
