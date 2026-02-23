# Move Stabletoken Tutorial Volume 2

In volume 1, we have completed basic functionality of the stabletoken:

- `initialize` function: Creates a user on the global storage with `Deposit` and `Stabletoken` fields.
- `deposit` function: Deposits an imaginery balance to the module
- `mint` function: Mints stabletoken according to the user deposit
- `liquidate` function: Liquidates the user if the user falls below the health factor
- `withdraw` funciton: Withdraws the available deposit from the module
- `burn` function: Burns stabletoken to diminish user's stabletoken position

However, there are some critical assumptions that we need to handle:

- Module accepts imaginery balance: Module doesn't accept `MOVE` coin as a collateral
- Module only mints `Stabletoken` object rather than minting an actual token: A token module should be integrated.
- Hard-coded price: Module should use the oracle price.

In this module, we are going to refactor our stabletoken module so that it accepts `MOVE` coin as a collateral and emits related events.

The current version of the stabletoken module should look like this now: https://github.com/ulas96/movement-stabletoken
