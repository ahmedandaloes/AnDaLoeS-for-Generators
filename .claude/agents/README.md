# Project Agents — AnDaLoeS for Generators

Project-scoped expert subagents, tuned to this exact stack (Flutter + Supabase
generator rental marketplace). Claude Code auto-discovers them; invoke with the
Agent tool using the `name` in each file's frontmatter.

| Agent | Expertise | Use when |
|-------|-----------|----------|
| `supabase-db-expert` | PostgreSQL, RLS, triggers, migrations | Any `supabase/migrations/` change, SQL, schema, or DB error. Knows the notifications/`data` jsonb and `generator_status` enum gotchas. |
| `flutter-ui-expert` | Flutter, Material 3, animations, GoRouter | Building/editing screens & widgets; theme/locale toggles; analyze gotchas. |
| `riverpod-state-expert` | Riverpod v2 providers, async state, invalidation | Adding/refactoring providers, data fetching, realtime, cache invalidation. |
| `rental-workflow-expert` | Rental lifecycle, pricing, commissions, availability | Booking, status transitions, the money path, double-booking logic. |
| `security-rls-auditor` | Auth, 3-role model, RLS, input validation | Before any commit touching auth, roles, RLS, or input handling. |

These complement the global agents in `~/.claude/agents/` (planner, code-reviewer,
build-error-resolver, etc.). Project agents win on domain specificity — prefer
them for anything AnDaLoeS-specific.
