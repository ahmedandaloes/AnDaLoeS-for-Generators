# Project Agent Team — AnDaLoeS for Generators

Project-scoped expert subagents, tuned to this exact stack (Flutter + Supabase
generator rental marketplace). Claude Code auto-discovers them; invoke with the
Agent tool using the `name` in each file's frontmatter.

## How the team works together
The **`master-orchestrator`** is the lead. Hand it any non-trivial task; it
decomposes the work, routes each part to the right expert, sequences
plan→build→review→verify, and enforces quality gates. It is backed by two
support agents — **`delivery-coordinator`** (planning, tracking, the dev loop,
git) and **`qa-gatekeeper`** (the final block/pass gate). The orchestrator may
define new agents when a durable capability gap appears.

```
                      master-orchestrator
                     /         |          \
        delivery-coordinator   |        qa-gatekeeper
                               |
   ┌──────────────┬───────────┼────────────┬─────────────────┐
 architecture     build      platform    quality/security   product/business
```

## Orchestration
| Agent | Role |
|-------|------|
| `master-orchestrator` | Lead. Decomposes, delegates, sequences, enforces gates, resolves conflicts, creates new agents. (Opus) |
| `delivery-coordinator` | Support: task breakdown, tracking, GOAL.md loop, git/branch/commit/push. |
| `qa-gatekeeper` | Support: final gate — analyze/build/tests/reviews/DB-consistency. Can BLOCK. |

## Architecture (plan first, read-only)
| Agent | Expertise |
|-------|-----------|
| `code-architect` | System design, module boundaries, layering, scalability, refactors. |
| `security-architect` | Threat modeling, trust boundaries, authz model, defense-in-depth. |
| `data-architect` | Schema/data modeling, integrity constraints, indexing, migration safety. |

## Build (domain experts)
| Agent | Expertise |
|-------|-----------|
| `flutter-ui-expert` | Flutter/Material 3/GoRouter, widgets, animations, analyze gotchas. |
| `riverpod-state-expert` | Riverpod v2 providers, async state, cache invalidation, realtime. |
| `supabase-db-expert` | Postgres/RLS/triggers/migrations; live-DB verification. |
| `rental-workflow-expert` | Rental lifecycle, pricing, commissions, availability — the money path. |

## Platform
| Agent | Expertise |
|-------|-----------|
| `flutter-ios-expert` | CocoaPods, signing, Info.plist, deployment target, App Store. |
| `flutter-android-expert` | Gradle, AndroidManifest, intent queries, signing, Play Store. |
| `release-ci-expert` | GitHub Actions, build pipelines, versioning, release prep. |

## Quality & Security
| Agent | Expertise |
|-------|-----------|
| `flutter-security-expert` | Client-side: secrets, secure storage, deep links, hardening. |
| `security-rls-auditor` | Backend authorization: 3-role model, RLS policies, input validation. |
| `flutter-test-expert` | Unit/widget/integration tests, mocking, 80% coverage goal, TDD. |

## Product & Business (shape goals in GOAL.md)
| Agent | Expertise |
|-------|-----------|
| `product-strategy-expert` | Roadmap, prioritization, owns GOAL.md. |
| `marketplace-growth-expert` | Two-sided growth: acquisition, retention, supply/demand balance. |
| `monetization-expert` | Commission model, pricing, payouts, unit economics. |

These complement the global agents in `~/.claude/agents/` (planner,
code-reviewer, build-error-resolver, etc.). Project agents win on domain
specificity — prefer them for anything AnDaLoeS-specific. Each agent encodes
hard-won project gotchas (e.g. notifications use a `data` jsonb not a
`rental_request_id` column; `generator_status` is only `available`/`unavailable`;
`android/` and `ios/` are gitignored) so the team avoids repeating past mistakes.
