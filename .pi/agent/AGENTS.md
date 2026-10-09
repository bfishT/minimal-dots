# Global

## Web research

Use `ketch` for external research (web search, page reading, OSS code search, library docs). It is installed at ~/.local/bin/ketch.

- `ketch search "query"` — web search; add `--scrape` to fetch full page content per result, `--multi` to fuse rankings across backends
- `ketch search "query" --limit 5` — default limit is 5; raise it for broad discovery
- `ketch scrape <url> [url...]` — fetch one or more URLs as clean markdown (handles PDFs too); cached 72h, `--no-cache` to bypass
- `ketch code "query" --lang go` — search real OSS source; `--repo owner/name` to scope to one repository
- `ketch docs "query" --library org/repo` — version-aware library documentation (needs a free Context7 key: `ketch config set context7_api_key <key>`)
- All commands accept `--json`. Exit codes: 2 bad input, 3 not found, 4 network failure, 5 missing key, 6 cancelled.
- Search backend is `auto` (Parallel → Exa → Keenable → You.com → Firecrawl → DDG fallback chain, keyless). If a query fails, retry once, then fall back to `curl` directly.
- For academic paper lookups, prefer arXiv/Semantic Scholar APIs via curl (e.g. `http://export.arxiv.org/api/query?search_query=...`, `https://api.semanticscholar.org/graph/v1/paper/search?query=...`) — they are JSON, keyless, and bot-free. Use `ketch search` for discovery and non-academic sources.
- For downloading datasets or files, use `curl`/`wget`/`aria2c`/`hf download` directly; ketch is for reading content, not bulk transfer.
