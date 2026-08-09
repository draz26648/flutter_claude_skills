# Bloc and Cubit

Read this when the profile says `state: bloc`, or when there is no profile. The four
rules in `SKILL.md` are the contract; this is what they look like in Bloc.

Prefer Cubit. Reach for Bloc when the feature genuinely benefits from events as a
record — an audit trail, replay, or event transformers like debounce on a search field.
A Cubit rewritten as a Bloc for uniformity costs a file and an event class per method and
buys nothing.

## State shape

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

Under `models: manual`, the same guarantee without codegen:

```dart
sealed class WalletState {
  const WalletState();
}

final class WalletLoading extends WalletState {
  const WalletLoading();
}
```

Write `==` and `hashCode` by hand in that case, or Bloc's equality dedup will suppress
nothing and every emission will rebuild.

## Emission

```dart
Future<void> load() async {
  emit(const WalletState.loading());
  final result = await _repository.fetchWallet();
  if (isClosed) return;                    // rule 2
  result.fold(
    (failure) => emit(WalletState.failure(failure)),
    (wallet) => emit(WalletState.loaded(
      balance: wallet.balance,
      transactions: wallet.transactions,
    )),
  );
}
```

`isClosed` after every `await` that precedes an `emit`. Not the first one only — after
each of them, if there are several.

## Rebuild scope

```dart
BlocSelector<WalletCubit, WalletState, Money?>(
  selector: (state) => state is WalletLoaded ? state.balance : null,
  builder: (context, balance) => BalanceText(balance),
)
```

`BlocListener` for side effects. `BlocConsumer` only when a widget genuinely needs both —
it is two subscriptions in one widget, which is convenient rather than better.

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
    WalletState.loaded(
      balance: testWallet.balance,
      transactions: testWallet.transactions,
    ),
  ],
);
```

The `expect` list is the sequence, which is what makes `blocTest` worth using over a
plain unit test. Assert the failure path the same way, with the repository stubbed to
return a `Left`.

To test the `isClosed` guard itself: `act` on the cubit, `close()` it before the stubbed
future completes, and assert no further state was emitted. That test fails loudly against
a missing guard, and it is the only way the guard stays in place through a refactor.

## Bloc-specific

Register handlers in the constructor, one `on<Event>` per event type. Concurrency is a
decision, not a default — `EventTransformer` matters when events can overlap:

- `sequential()` when order matters and each event must complete
- `droppable()` for a submit button, so a double-tap does not fire twice
- `restartable()` for search-as-you-type, so a stale response cannot overwrite a fresh one

The default is concurrent, which is the wrong answer for all three of the above.
