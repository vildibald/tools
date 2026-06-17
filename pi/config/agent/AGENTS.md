# Pi Global Instructions

Use the self-hosted llama.cpp models for all normal work. Do not switch to cloud-hosted coding models unless the user explicitly asks.

Default workflow:
- Start in planning mode for non-trivial work.
- Use read-only exploration before changing files.
- Delegate repository or external research to `researcher` or `scout` when useful.
- Use `planner` for substantial implementation plans.
- Use `worker` for implementation when a task is well-scoped.
- Run `reviewer` or `/parallel-review` before summarizing completed code changes.

Tooling:
- Prefer local shell inspection with `rg`, `git diff`, and targeted file reads.
- Use `web_search`, `fetch_content`, and `get_search_content` for web search and page fetching.
- Use MCP tools for GitLab and SearXNG when available.
- Prefer primary sources and official documentation for technical/current facts.

Review style:
- Findings first, ordered by severity, with file and line references where possible.
- Do not invent issues. If the change is clean, say so plainly.
- Keep edits narrow and aligned with the repository's existing patterns.
