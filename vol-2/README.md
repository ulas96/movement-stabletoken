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

## Events

Events are a piece of data that module emits in to the transaction receipt logs when any action to be tracked happens. Events are off-chain records of an on-chain action, meaning they are only accesesible from standart back-end - they are not accesesible (after they are emitted) on blockchain.

In Aptos Move, event payloads are defined as structs that have the store and drop abilities. Before the decleration of an event struct, annotation of `#[event]` indicates that the following struct is an event. We briefly introduced abilities in the previous volume.

- `store` means the value is allowed to be persisted (saved) by the VM—events must be storable because their payload is written into the on-chain event log.

- `drop` means the value can be discarded automatically when it goes out of scope, without needing explicit cleanup.

Any data to be traced can be stated as key-value pair in the defined event struct. For our stabletoken, we may want to track each new user. Emitting a the address of a newly created `User` struct added to the global storage would allow us to track when there is a new user.

Events are emitted via `emit` method in `event` library. `event` library is not included in the standart library so it has to be imported explicitly as,

```move
module stabletoken::stabletoken_engine {
// Rest of the module

use aptos_framwork::event;

event::emit(SomeEvent{ someKey: someValue});
}
```

### `InitializeEvent`

Let's first declare our custom `InitializeEvent` struct. This event should emit the account address of the newly created `User` struct. So, it will have `account` key with a value type of `address`.

#### Event Struct

```move
module stabletoken::stabletoken_engine {
// Rest of the module

#[event] // Indicates following struct is an event
struct InitializeEvent has drop, store { // Event struct with drop and store abilities
account: address // Account address of the transaction caller that should be emitted
}
}
```

#### Function Integration

As we defined our event struct, next to integrate to our `initalize` function so that we actually emit the account address of the newlt created `User` struct.

```move
module stabletoken::stabletoken_engine{
// Rest of the module
use aptos_framwork::event; // Event lbibray that let events to be emitted

public entry fun initialize(account: &signer){
        let addr = signer::address_of(account);
        assert!(!exists<User>(addr), EACCOUNT_ALREADY_EXISTS);
        let empty_deposit = Deposit { amount: 0 };
        let empty_stabletoken = Stabletoken { amount: 0 };
        let new_user = User { deposit: empty_deposit, stabletoken: empty_stabletoken };
        move_to(account, new_user);
        event::emit(InitializeEvent {account: addr}); // Emits the Initalize event including the account address of the new `User` struct
}
}
```

In `initialize` function, we simply emit account address of the new `User` struct to keep track of the new users.

### `DepositEvent`

As we created an event to keep track of the new users, we may apply the same logic to track new deposits. This event should emit the account address who deposits the fund and amount deposit.

#### Event Struct

```move
module stabletoken::stabletoken_engine{
// Rest of the module

    #[event] // Indicates that following struct is an event
    struct DepositEvent has drop, store { // Event struct with drop and store abilities
        account: address, // Account address of the transaction caller that should be emitted
        amount: u64 // Deposit amount that should be emitted
    }
}
```

#### Function Integration

```move
module stabletoken::stabletoken_engine {
// Rest of the module

    public entry fun deposit(account: &signer, amount: u64) acquires User {
        let addr = signer::address_of(account);
        assert!(exists<User>(addr), EACCOUNT_NOT_EXISTS);
        let deposit_ref = deposit_of(addr);
        let deposit_mut = &mut borrow_global_mut<User>(addr).deposit.amount;
        *deposit_mut = deposit_ref + amount;
        event::emit(DepositEvent{account: addr, amount}); // Emits DepositEvent including the account address of the transaction caller and deposit amount
}
```

### `MintEvent`

To track minted stabletoken in the module, custom `MintEvent` shall be created. This event should emit the account address of the transcation caller and mint amount.

#### Event Struct

```move
module stabletoken::stabletoken_engine {
// Rest of the module
    #[event] // Indicates that following struct is an event
    struct MintEvent has drop, store { // Event struct with drop and store abilities
        account: address, // Account address of the transaction caller that should be emitted
        amount: u64 // Mint amount that should be emitted
    }
}
```

#### Function Integration

```move
module stabletoken::stabletoken_engine {
// Rest of the module

    public entry fun mint(account: &signer, amount: u64) acquires User {
        assert!(amount > 0, EZERO_AMOUNT);
        let addr = signer::address_of(account);
        assert!(exists<User>(addr), EACCOUNT_NOT_INITIALIZED);
        let deposit_balance = deposit_of(addr);
        let coin_balance = borrow_global<User>(addr).stabletoken.amount;
        let max_mintible_amount = get_available_collateral(
            deposit_balance, coin_balance
        );
        assert!(max_mintible_amount >= amount, ENOT_ENOUGH_DEPOSIT);
        let coin_ref = &mut borrow_global_mut<User>(addr).stabletoken.amount;
        *coin_ref = coin_balance + amount;
        event::emit(MintEvent { account: addr, amount }); // Emits the account address of the transaction caller and mint amount
    }
}
```

### `BurnEvent`

`BurnEvent` allows us to track who burned how much stabletokens.

#### Event Struct

```move
module stabletoken::stabletoken_engine{
// Rest of the module

    #[event] // Indicates that following struct is an event
    struct BurnEvent has drop, store { // Event struct with drop and store abilities
        account: address, // Account address of the transaction caller that should be emitted
        amount: u64 // Burn amount that should be emitted
    }
}
```

#### Function Integration

```move
module stabletoken::stabletoken_engine {
// Rest of the module
 public entry fun burn(account: &signer, amount: u64) acquires User {
        assert!(amount > 0, EZERO_AMOUNT);
        let addr = signer::address_of(account);
        let coin_balance = coin_of(addr);
        assert!(coin_balance >= amount, ENOT_ENOUGH_MINT);

        let coin_ref = &mut borrow_global_mut<User>(addr).stabletoken.amount;
        *coin_ref = coin_balance - amount;
        event::emit(BurnEvent { account: addr, amount }); // Emits the account address of the transaction caller and burn amount
    }
}
```

### `WithdrawEvent`

`WithdrawEvent` tracks the account address of the transaction caller and withdraw amount.

#### Event Struct

```move
module stabletoken::stabletoken_engine{
// Rest of the module

    #[event] // Indicates that following struct is an event
    struct WithdrawEvent has drop, store { // Event struct with drop and store abilities
        account: address, // Account address of the transaction caller that should be emitted
        amount: u64 // Withdraw amount that should be emitted
    }
}
```

#### Function Integration

```move
module stabletoken::stabletoken_engine {
// Rest of the moudule
public entry fun withdraw(account: &signer, amount: u64) acquires User, SignerCap {
        let addr = signer::address_of(account);
        let deposit_balance = deposit_of(addr);
        let stabletoken_balance = stabletoken_of(addr);
        let max_allow_withdraw = deposit_balance - stabletoken_balance / PRICE;
        assert!(max_allow_withdraw >= amount, EEXCEEDS_DEPOSIT_AMOUNT);
        assert!(deposit_balance >= amount, ENOT_ENOUGH_DEPOSIT);

        let deposit_mut_ref = &mut borrow_global_mut<User>(addr).deposit.amount;
        *deposit_mut_ref = deposit_balance - amount;
        event::emit(WithdrawEvent { account: addr, amount }); // Emits the account address of the transaction caller and withdraw amount
    }
}
```

### `LiquidateEvent`

`LiquidateEvent` tracks the users who got liquidated and liquidation amount.

#### Event Struct

```move
module stabletoken::stabletoken_engine{
// Rest of the module

    #[event] // Indicates that following struct is an event
    struct LiquidateEvent has drop, store { // Event struct with drop and store abilities
        account: address, // Account address of the liquidated user that should be emitted
        amount: u64 // Liquidation amount that should be emitted
    }
}
```

#### Function Integration

```move
module stabletoken::stabletoken_engine {
// Rest of the module

public entry fun liquidate(addr: address) acquires User {
        assert!(exists<User>(addr), ENOT_ENOUGH_MINT);
        assert!(get_health_factor(addr) < PRECISION, ENOT_LIQUIDATABLE);
        let deposit_amount = borrow_global<User>(addr).deposit.amount;
        let deposit_ref = &mut borrow_global_mut<User>(addr).deposit.amount;
        *deposit_ref = 0;
        event::emit(LiquidateEvent { account: addr, deposit_seized: deposit_amount }); // Emits the account addres of the liquidated user and liquidation amount
    }
}
```
