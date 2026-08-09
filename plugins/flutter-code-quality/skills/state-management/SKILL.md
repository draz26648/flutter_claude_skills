---
name: state-management
description: State-management conventions — state shape, safe updates after an await, narrow rebuild scope, and the test pattern — resolved against whichever stack the project uses: Bloc, Cubit, Riverpod, Provider, signals, or plain setState. Use this whenever writing or modifying any Cubit, Bloc, Notifier, provider, or state class, whenever wiring a widget to state, whenever a rebuild or setState question comes up, and whenever adding tests for state logic. Trigger it on any task that touches presentation logic, since updating state after disposal and over-broad rebuild scope are the two most common causes of crashes and jank in an otherwise correct implementation.
---

# State Management

> **Profile first.** Read `.claude/flutter-profile.yaml` in the project root and take the
> stack from `state`. With no profile, assume `state: bloc`, `models: freezed`.
> Then read the reference for that stack before writing code:
>
> | `state` | Read |
> |---|---|
> | `bloc` (default) | `references/bloc.md` |
> | `riverpod` | `references/riverpod.md` |
> | `provider`, `signals`, `setstate` | Neither — apply the four rules below directly, using the translation table at the bottom |
>
> Do not mix stacks. Adding a Cubit to a Riverpod codebase because a Cubit is what you
> know is the single most damaging thing an agent does to a state layer: it compiles, it
> works on the screen it was added to, and it leaves the project with two sources of truth
> that no reviewer asked for. Field list:
> `${CLAUDE_PLUGIN_ROOT}/skills/architecture/references/flutter-profile.md`.

The four rules below hold under every stack. The references only differ in what the code
for them looks like.

## 1. State shape: one type, exhaustively switchable

One state type per feature, expressed as a union of the states that can actually exist —
not a single class with nullable fields covering every case at once. A
nullable-everything state makes every widget check three fields to work out what to
render, and the compiler stops helping.

Under `models: freezed` or `dart_mappable`, that is a sealed union. Under `models:
manual`, it is a sealed class hierarchy written by hand — Dart 3 gives you exhaustive
`switch` on any sealed type, so the guarantee does not depend on codegen.

The point is the exhaustiveness. Adding a state member should produce a compile error
everywhere it needs handling, rather than a silently missing case at runtime.

## 2. Never update state after disposal

Every state update that follows an `await` needs a liveness guard in front of it. Without
one, navigating away mid-request throws. It is intermittent, it depends on network
timing, and it is very hard to reproduce from a bug report — which is exactly why an
agent will not add the guard unless told to.

Each stack spells the guard differently (`isClosed`, `ref.mounted`, `mounted`). All of
them need it. See your stack's reference.

## 3. Subscribe to the narrowest slice that works

A widget reading one field should rebuild when that field changes, and not otherwise. On
a screen where a transaction list and a balance header read the same state, a
whole-state subscription on the header rebuilds it on every list update.

Not fatal on its own, but it compounds, and it is free to avoid at authoring time and
tedious to retrofit. Every stack has a narrowing primitive — `BlocSelector`,
`ref.watch(p.select(...))`, `context.select`. Use it.

Side effects — navigation, snackbars, dialogs — are a separate subscription from
rendering, never a branch inside a builder. A builder can run more than once for the same
state; a snackbar that fires from inside one will eventually fire twice.

## 4. No `BuildContext` in the state holder

Navigation and snackbars are the widget's job. A Cubit or Notifier holding a
`BuildContext` has bound business logic to the widget tree and cannot be tested without
pumping one.

## Testing

Every public method on a state holder gets at least a success case and a failure case.
The failure path is the one that ships broken, because it is the one nobody clicks
through manually.

Assert on the *sequence* of states, not just the final one. A method that reaches
`loaded` without passing through `loading` renders no spinner, and a test that only
checks the endpoint passes anyway.

## Stacks without a reference file

| Rule | `provider` | `signals` | `setstate` |
|---|---|---|---|
| Liveness guard | `if (!mounted) return;` on `ChangeNotifier` | disposal check before assigning | `if (!mounted) return;` in the `State` |
| Narrow subscription | `context.select` | fine-grained signal reads | n/a — keep the `State` small instead |
| Side effects | listener outside `build` | `effect` | after the `await`, not in `build` |
| Test entry point | construct the notifier directly | read the signal | `testWidgets` + `pumpWidget` |

`setstate` is a legitimate answer for genuinely local state — a checkbox, an expansion
tile, a form field's focus. It is not an answer for anything that outlives the widget or
is read by a sibling. If a project's profile says `setstate` and you are about to lift
state to an ancestor to share it, that is the moment to say the project has outgrown the
setting, rather than quietly introducing a second stack.

## Common mistakes, every stack

- Business logic in the state holder that belongs in domain. It orchestrates; it does not
  decide business rules.
- One holder for a whole screen with eight unrelated responsibilities. Split by concern,
  not by route.
- Emitting or assigning a value equal to the current state and expecting a rebuild. Every
  one of these stacks deduplicates by equality. If a list changed in place, produce a new
  list rather than mutating the existing one.
- Reading state non-reactively inside `build` (`context.read`, `ref.read`). It does not
  subscribe, so the UI goes stale in a way that looks like a caching bug.
