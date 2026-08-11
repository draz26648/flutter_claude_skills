# Riverpod

Read this when the profile says `state: riverpod`. The four rules in `SKILL.md` are the
contract; this is what they look like in Riverpod.

Examples use `riverpod_generator` (`@riverpod`), which is the current default. Without
codegen the same shapes exist as `NotifierProvider` and `AsyncNotifierProvider` declared
by hand — the rules are identical, only the declaration differs.

## State shape

For anything loaded asynchronously, `AsyncValue` is already the sealed union — `loading`,
`error`, `data`. Do not wrap it in a hand-written union with its own loading and failure
members; that is two state machines for one piece of state, and they drift.

```dart
@riverpod
class WalletController extends _$WalletController {
  @override
  Future<WalletData> build() =>
      ref.watch(walletRepositoryProvider).fetchWallet();
}
```

Write a sealed union (rule 1) when the feature has states `AsyncValue` cannot express —
a multi-step form, an editing mode, an optimistic update pending confirmation. Then it is
`Notifier<MyState>` with the union as its type.

`build()` runs on first read and again on every dependency change, so it holds the
initial load and nothing else. No analytics calls, no navigation, no writes — a side
effect in `build()` fires again on every invalidation, which is the Riverpod bug that
takes longest to find.

## Updating state

```dart
Future<void> refresh() async {
  state = const AsyncValue.loading();
  state = await AsyncValue.guard(
    () => ref.read(walletRepositoryProvider).fetchWallet(),
  );
}
```

`AsyncValue.guard` routes a thrown error into `AsyncError` instead of an unhandled
exception, and it preserves the stack trace. A bare `try/catch` that assigns
`AsyncValue.error(e, StackTrace.current)` loses the original trace.

For a manual `await` outside `guard`, the liveness check (rule 2) is explicit — assigning
`state` after disposal throws:

```dart
Future<void> submit(Transfer transfer) async {
  final result = await ref.read(transferRepositoryProvider).send(transfer);
  if (!ref.mounted) return;
  state = AsyncValue.data(result);
}
```

If the project's Riverpod predates `ref.mounted`, keep a flag instead:

```dart
var _disposed = false;
// in build(): ref.onDispose(() => _disposed = true);
```

`autoDispose` (the default under `@riverpod`) makes this sharply more likely to matter,
not less: the provider is torn down as soon as the last listener leaves the screen, which
is exactly the navigate-away-mid-request case.

## Rebuild scope

```dart
final balance = ref.watch(
  walletControllerProvider.select((s) => s.valueOrNull?.balance),
);
```

`select` is the narrowing primitive (rule 3) — the widget rebuilds only when the selected
value changes by `==`. Selecting an object without value equality selects nothing.

`ref.listen` for side effects, in the widget, never in a provider:

```dart
ref.listen(walletControllerProvider, (previous, next) {
  if (next case AsyncError(:final error)) showErrorSnackBar(context, error);
});
```

Render every branch of `AsyncValue` explicitly. `.when(data:, loading:, error:)` forces
that; `.value!` skips the loading and error cases and crashes on the first slow network.

## Dependency injection

Riverpod is the DI container — under `di: riverpod` there is no `get_it`. A repository is
a provider, and a controller reads it with `ref.watch`. Overriding that provider in a test
is what makes the controller testable, which is the same role the constructor parameter
plays under Bloc.

## Testing

```dart
test('refresh emits loading then data', () async {
  final container = ProviderContainer(
    overrides: [
      walletRepositoryProvider.overrideWithValue(FakeWalletRepository()),
    ],
  );
  addTearDown(container.dispose);

  final states = <AsyncValue<WalletData>>[];
  container.listen(
    walletControllerProvider,
    (_, next) => states.add(next),
    fireImmediately: true,
  );

  await container.read(walletControllerProvider.notifier).refresh();

  expect(states.map((s) => s.runtimeType), [
    AsyncLoading<WalletData>,
    AsyncData<WalletData>,
  ]);
});
```

`addTearDown(container.dispose)` is not optional — a leaked container keeps its providers
alive across tests and produces failures that only appear when the whole file runs.

`container.listen` with `fireImmediately: true` records the sequence, which is what makes
this the equivalent of `blocTest`'s `expect` list. Reading only the final value passes on
a controller that never emitted `loading`.

Test the failure path by overriding the repository with one that throws, and assert
`AsyncError` — not that an exception escaped.
