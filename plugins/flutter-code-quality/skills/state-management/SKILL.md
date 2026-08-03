---
name: state-management
description: Cubit and Bloc conventions for this codebase — sealed state classes, naming, safe emission, selective rebuilds with BlocSelector, and the bloc_test pattern. Use this whenever writing or modifying any Cubit, Bloc, or state class, whenever wiring a widget to state, whenever a rebuild or setState question comes up, and whenever adding tests for state logic. Trigger it on any task that touches presentation logic, since incorrect emission and over-broad BlocBuilder scope are the two most common causes of jank in an otherwise correct implementation.
---

# State Management

## State shape

One sealed state class per feature, using freezed. Union members, not a single class with
nullable fields — a nullable-everything state makes every widget check three fields to
know what to render, and the compiler stops helping.

```dart
@freezed
sealed class WalletState with _$WalletState {
  const factory WalletState.initial() = WalletInitial;
  const factory WalletState.loading() = WalletLoading;
  const factory WalletState.loaded({
    required Money balance,
    required List<Transaction> transactions,
  }) = WalletLoaded;
  const factory WalletState.failure(Failure failure) = WalletFailure;
}
```

Exhaustive switching in the widget means adding a state member produces a compile error
everywhere it needs handling, rather than a silently missing case at runtime.

## Emission rules

**Never emit after close.** Guard any emission that follows an await:

```dart
Future<void> load() async {
  emit(const WalletState.loading());
  final result = await _repository.fetchWallet();
  if (isClosed) return;
  result.fold(
    (failure) => emit(WalletState.failure(failure)),
    (wallet) => emit(WalletState.loaded(
      balance: wallet.balance,
      transactions: wallet.transactions,
    )),
  );
}
```

Without the `isClosed` guard, navigating away mid-request throws. It is intermittent,
depends on network timing, and is very hard to reproduce from a bug report.

**Never emit the same state twice expecting a rebuild.** Bloc deduplicates by equality.
With freezed, two identical `loaded` states are equal and the second emission does
nothing. If a list changed in place, emit a new list rather than mutating the existing one.

**No `BuildContext` in a Cubit.** Navigation and snackbars are the widget's job, driven
by `BlocListener`.

## Rebuild scope

`BlocBuilder` rebuilds on every state change. When a widget only needs one field, use
`BlocSelector`:

```dart
BlocSelector<WalletCubit, WalletState, Money?>(
  selector: (state) => state is WalletLoaded ? state.balance : null,
  builder: (context, balance) => BalanceText(balance),
)
```

On a screen where a transaction list and a balance header read the same Cubit, a plain
`BlocBuilder` on the header rebuilds it on every list update. Not fatal, but it adds up,
and it is free to avoid.

Use `BlocListener` for side effects and `BlocConsumer` only when a widget genuinely needs
both.

## Testing

```dart
blocTest<WalletCubit, WalletState>(
  'emits loading then loaded when fetch succeeds',
  setUp: () => when(() => repository.fetchWallet())
      .thenAnswer((_) async => Right(testWallet)),
  build: () => WalletCubit(repository),
  act: (cubit) => cubit.load(),
  expect: () => [
    const WalletState.loading(),
    WalletState.loaded(balance: testWallet.balance, transactions: testWallet.transactions),
  ],
);
```

Every Cubit method gets at least a success case and a failure case. The failure path is
the one that ships broken, because it is the one nobody clicks through manually.

## Common mistakes

- Business logic in the Cubit that belongs in domain. A Cubit orchestrates; it does not
  decide business rules.
- One giant Cubit for a whole screen with eight unrelated responsibilities. Split by
  concern, not by route.
- `context.read` inside `build()`. Use `context.watch` or a builder — `read` in build
  does not subscribe and produces stale UI.
