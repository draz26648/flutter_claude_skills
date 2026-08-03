---
name: architecture
description: The layering rules for this Flutter codebase — feature-first structure, a pure Dart domain layer with no Flutter imports, Cubit or Bloc as the only bridge to presentation, and repositories behind interfaces. Use this whenever creating a new feature, adding any new file, deciding where code belongs, refactoring, or answering any question about project structure. Trigger it before writing the first file of any new feature, because a file placed in the wrong layer is far more expensive to move later than to place correctly now.
---

# Architecture

Feature-first, three layers per feature. The rules exist to keep business logic testable
without a Flutter binding and swappable without touching the UI.

## Structure

```
lib/
├── core/                      # shared across features
│   ├── theme/                 # tokens, ThemeExtension
│   ├── network/               # Dio setup, interceptors
│   ├── errors/                # Failure types
│   └── widgets/               # genuinely shared widgets
└── features/
    └── wallet/
        ├── domain/            # pure Dart — no flutter/ imports at all
        │   ├── entities/
        │   ├── repositories/  # abstract interfaces only
        │   └── usecases/
        ├── data/
        │   ├── models/        # DTOs with fromJson/toJson
        │   ├── datasources/   # remote and local
        │   └── repositories/  # concrete implementations
        └── presentation/
            ├── cubit/
            ├── pages/
            └── widgets/
```

## The rules and why

**Domain imports nothing from Flutter.** Not `material.dart`, not `widgets.dart`, not
even for `Color` or `IconData`. The moment domain depends on Flutter it needs a binding
to test, and unit tests slow from milliseconds to seconds. If domain needs to express a
visual concept, it returns an enum and presentation maps it.

**Dependencies point inward.** Presentation knows domain. Data knows domain. Domain
knows nothing about either. A domain file importing from `data/` is the inversion this
structure exists to prevent.

**Repositories are interfaces in domain, implementations in data.** The Cubit depends on
the interface, which is what makes it testable with a mock instead of a live API.

**No `BuildContext` below presentation.** A use case taking a context has bound business
logic to the widget tree.

**Entities and models are separate.** The API's shape is not the app's shape. Models
handle JSON and live in data; entities express the domain and have no serialization code.
When the backend renames a field, exactly one file changes.

## Where things go

| Thing | Layer |
|---|---|
| "Transfer requires balance ≥ amount" | domain/usecases |
| "Balance shows two decimals" | presentation |
| "The API returns cents as an int" | data/models |
| "Failed transfers retry twice" | data/repositories |
| "The button is disabled while loading" | presentation/cubit |

## When to skip a use case

A use case that only forwards a call to a repository adds a file and no behaviour. For a
straight read with no rules, let the Cubit call the repository directly. Add the use case
when there is actual logic to hold — validation, orchestration across repositories,
business rules. Ceremony for its own sake makes a codebase harder to read, not more
correct.

## Common mistakes

- A `utils/` or `helpers/` folder at the root. It becomes a dumping ground within a
  month. Put the function next to what uses it.
- Shared widgets moved to `core/widgets/` on first reuse. Wait for the third usage —
  two usages that diverge later are cheaper to split than to un-merge.
- Cubits calling data sources directly, skipping the repository. That couples
  presentation to the transport layer.
