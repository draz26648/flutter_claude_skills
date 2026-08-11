# Project profile

Everything in these skills is an opinion about how a Flutter project is built. Most of
those opinions are safe defaults. A few of them are wrong for your codebase, and a skill
that is wrong about the codebase loses every argument it has with the developer.

`.claude/flutter-profile.yaml` in the project root is how a project states which opinions
apply to it.

## Reading it

Before applying any rule that names a package, a folder layout, or a severity, read
`.claude/flutter-profile.yaml` from the project root.

- **No file?** Use the defaults below. They are the conventions these skills shipped with,
  so a project that already agrees with them sees no change and needs no file.
- **File present, field missing?** That field takes its default. Partial profiles are
  normal — write only the fields where the project differs.
- **Value you do not recognise?** Stop and say so. Do not quietly fall back to the
  default: an unrecognised value is almost always a typo, and treating `riverpood` as
  `bloc` hands the project the opposite of what it asked for.

Read the file rather than inferring its contents from `pubspec.yaml`. The profile is a
statement of intent, and intent is not always visible in the dependency list — a project
part-way through a Provider-to-Riverpod migration has both packages installed, and only
one of them is the answer to "what should I write next".

## Fields

| Field | Values | Default | What it changes |
|---|---|---|---|
| `state` | `bloc`, `riverpod`, `provider`, `signals`, `setstate` | `bloc` | Which state-management reference applies, what a "state class" means, and how presentation subscribes to it |
| `models` | `freezed`, `dart_mappable`, `json_serializable`, `manual` | `freezed` | Whether state classes get sealed unions, and how entities and DTOs are declared |
| `structure` | `feature_first`, `layer_first` | `feature_first` | Where a new file goes |
| `di` | `get_it`, `injectable`, `riverpod`, `provider`, `none` | `get_it` | How a Cubit or notifier receives its repository |
| `routing` | `go_router`, `auto_route`, `navigator` | `go_router` | How navigation is declared and where route definitions live |
| `tokens` | `theme_extension`, `theme_only`, `constants`, `none` | `theme_extension` | How a widget resolves a colour or a spacing value, and whether hardcoded literals are a finding at all |
| `l10n` | `arb`, `easy_localization`, `slang`, `none` | `arb` | Where user-facing strings live, and whether a literal in `Text(...)` is a finding |
| `locales` | list of language codes, e.g. `[en, ar]` | undeclared | Which golden variants are worth generating, and whether RTL rules are blocking |
| `strictness` | `block`, `warn` | `block` | Whether a convention violation blocks a commit or is reported and moved past |

### Notes on the values that carry the most weight

**`tokens: none`** means the project has no token layer and is not planning one. Under it,
a hardcoded `Color(0xFF...)` is not a finding, and the design-tokens skill stops asking
for one. Do not use it to mean "we have not built one yet" — that is `theme_extension`
with work outstanding, and the skills should keep pushing.

**`tokens: theme_only`** means the project uses stock `ThemeData` and `Theme.of(context)`
with no custom extension. Values resolve through the theme; there is just no `AppTokens`.

**`locales`** drives RTL severity rather than RTL advice. `EdgeInsetsDirectional` is
better practice in any project, so the skills recommend it regardless — but a project
declaring only `en` gets it as a warning, and a project listing `ar`, `he`, `fa`, `ur`,
`ps`, `sd`, `ug`, `dv`, or `yi` gets it as a blocker, because there it is a visible bug
rather than a habit.

This is the one field with no default. Leaving it out keeps RTL blocking, because the
gate cannot tell whether the project ships an RTL language and the safe assumption is
that it might. Declare `locales: [en]` to take the downgrade — that is a statement, and
the point is that somebody made it deliberately.

**`strictness: warn`** is for an existing codebase adopting these skills partway through
its life, where a blocking gate on day one means the gate gets switched off on day two.
It downgrades every blocking convention finding to a warning. It does not touch
formatting, static analysis, failing tests, or committed credentials — those block under
any profile, because they are not matters of house style.

## Example

```yaml
# .claude/flutter-profile.yaml
state: riverpod
models: freezed
structure: feature_first
di: riverpod
routing: go_router
tokens: theme_extension
l10n: arb
locales: [en, ar]
strictness: block
```

## Generating one

```
/flutter-code-quality:flutter-adapt
```

It inspects `pubspec.yaml` and `lib/`, infers each field from what the code actually does,
and reports what it could not determine rather than guessing. If only
`flutter-design-fidelity` is installed, write the file by hand from the table above — it
is nine lines.

## What the profile is not

It is not a lint config and not a place for thresholds. It holds the small number of
decisions an agent cannot safely infer and will otherwise get wrong in a way that is
expensive to undo — which stack, which layout, which strings mechanism. Formatting rules
belong in `analysis_options.yaml`, which already exists and which the analyzer already
enforces.
