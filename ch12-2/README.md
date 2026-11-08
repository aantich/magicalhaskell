# Jarvis — ch12-2

`Mid` is `MRWST Settings Usage AppState IO`. Its Reader environment is immutable;
its state and writer output are held in TVars. It supports `MonadReader`,
`MonadState`, `MonadWriter`, `MonadRWS`, `MonadUnliftIO`, and exception masking.
State operations need `MonadIO`; scoped writer operations additionally need
`MonadMask` and `Monoid w`. It is an IO-based transformer, not a pure `RWS` or
an `ST` computation.

## State lifetime

`runMRWST`, `evalMRWST`, and `execMRWST` allocate an independent environment,
matching the usual RWST runner interface. To retain mutations across callbacks,
requests, or CLI actions, allocate once and reuse it:

```haskell
env <- newMRWSTEnv settings initialState
runMRWSTWith env firstAction
runMRWSTWith env secondAction
(finalState, totalOutput) <- readMRWSTEnv env
```

The application creates one environment for the CLI, web request middleware and
Scotty actions. `local` changes only the Reader settings for its scope; state and
output remain shared. The environment is opaque, so the standard Reader interface
does not expose its internal references.

## Atomic updates and mutable variables

The module's `modify`, `modify'`, `state`, and `state'` perform atomic state
transitions. Primed operations force the new state to weak head normal form
before committing; they do not recursively force lazy record fields. `tell`
forces the updated writer accumulator to weak head normal form.

A separate `get` followed by `put` is not atomic. The generic mtl `modify` and
`modify'` helpers also use separate reads and writes; use this module's functions
or the standard `MonadState.state` method for concurrent updates.

Use `stateWriter` to change state and output in one transaction:

```haskell
stateWriter $ \(s, w) -> ((), updateState s, w <> additionalOutput)
```

Use `atomicallyMRWST` to compose those changes with mutable variables from STM.
The new state and output are forced to weak head normal form before commit:

```haskell
counter <- liftIO $ newTVarIO (0 :: Int)
atomicallyMRWST $ \(s, w) -> do
    modifyTVar' counter (+1)
    pure ((), updateState s, w <> additionalOutput)
```

Import `newTVarIO`, `modifyTVar'`, and other STM operations from
`Control.Concurrent.STM`. Transactions support `retry`, `orElse`, and `throwSTM`;
failed transactions commit none of their state, output, or variable changes.
Other IO references can also be used through `liftIO`, but arbitrary IO cannot
be rolled back.

## Writer scopes, exceptions and concurrency

`listen`, `listens`, `pass`, and `censor` use a private writer accumulator while
sharing the original state. Nested scopes work normally, and concurrent siblings'
output cannot be captured or transformed by a scope. Its output is appended to
the enclosing accumulator when the scope exits, so concurrent output order follows
transaction/flush order rather than wall-clock event order. State changes are
visible immediately; a transaction inside a writer scope updates that scope's
output, which becomes visible to its parent on exit.

Mutations survive caught exceptions, as they do with ordinary IO references.
There is no implicit RWST-style restoration of the old state or writer output.
On exceptions, cancellation, or an underlying monad abort (such as `ExceptT`
returning `Left`), a writer scope publishes its accumulated output exactly once.
A failed `pass` publishes the original output if its action or transformation
fails. `local` still restores the surrounding Reader
settings. Reusing the environment also allows inspection after an uncaught error.
Use a single STM transaction when rollback is required.

Join child threads before leaving a writer scope or collecting a runner's final
snapshot. An escaped callback can still mutate its captured environment, but a
previously returned snapshot cannot include future changes. The application's
server lifetime is scoped to the CLI lifetime.

## Validation

Run `stack test` from this chapter directory. The regression suite covers the
standard mtl interfaces, strictness, independent and shared runners, unlifted
callbacks, nested and concurrent writer scopes, exceptions, cancellation, atomic
updates, and STM composition and rollback. It does not require live MongoDB or LLM
credentials.
