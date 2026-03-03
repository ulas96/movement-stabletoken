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
use aptos_framework::event; // Event lbibray that let events to be emitted

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

## Collateral Refactoring

For now, our stabletoken accepts an imaginery "coin" as a collateral, not the actual MOVE coin. We have to make sure that our stabletoken accepts MOVE coin as a collateral so that users can deposit their MOVE coin to mint stabletoken.

### `SignerCap`

In Move, in order to send funds to and withdraw from a module, that module needs to have `SignerCapability`. To define a module with a `SignerCapability`, the module should have `SignerCap` struct with `key` ability - since it is stored in the global storage . This allows us to create a resource address associoated with the module. `SignerCap` needs to have `cap` key with a value type of `account::SignerCapability` and `resource_addr` key with a value type `address`.
`resource_addr` indicates the address the address of the module send and withdraw funds.

`account` library is not included in the standart library, so we need to import it explicitly from `aptos_framework`.

```move
module stabletoken::stabletoken_engine{
// Rest of the module

    use aptos_framework::account;

    struct SignerCap has key {
        cap: account::SignerCapability, // The capability that allows creating a signer for the account
        resource_addr: address // Address that signer will correspond to
    }
}
```

### Moving Funds

To move funds to a module, first the resource address of the module should be obtained, then the transfer can be executed to the obtained resource address using `transfer` method exists on `coin` library in `aptos_framework`.

```move
module stabletoken::stabletoken_engine {
use aptos_framework::coin;

let resource_addr = borrow_global<SignerCap>(@stabletoken).resource_addr; // Obtains the resource address associoated with the module
coin::transfer<AptosCoin>(account, resource_addr, amount); // Transfers the amount to the module
}
```

`@` operator returns an address literal that resolves from a named address (e.g., `@stabletoken`) to its concrete on-chain account address as configured in Move.toml (or provided at publish time).

The transfer method takes a generic type argument (e.g., `<AptosCoin>`) that specifies which coin type’s balance is debited from the sender and credited to the recipient. To transfer a different coin/token, you simply change this type argument to that coin’s type.

### `init_module` Function

In order the module own a resource account, the resource account for the module should be initialized. `init_module` function creates a resource account associoated with the module using `account::create_resource_account(<address>, b"seed")` method and capture the generated abilities. Then, it registers Move coins for the resource account.

```move
module stabletoken::stabletoken_engine{
// Rest of the module
fun init_module(admin: &signer) {
        let (resource_signer, signer_cap) =
            account::create_resource_account(admin, b"seed"); // Creates a reource signer and signer cap from `admin` and "seed"
        coin::register<AptosCoin>(&resource_signer); // Register coins for the resource account
        let resource_addr = signer::address_of(&resource_signer); // Retrieves the account addres for the reource signer
        move_to(admin, SignerCap { cap: signer_cap, resource_addr }); // Publishes a `SignerCap` resource under the admin's account
    }
}
```

Modules without function like `init_module` or the module that `init_module` like functions not invoked cannot recieve or send funds.

### MOVE Balance

To obtain the MOVE balance of a user, `balance` method on `coin` library can be called.

```move
module stabletoken::stabletoken_engine{
// Rest of the module
let addr = 0x5bd82a7c6a44c5b241b074bac9b277e565fb10b77b32e3599dce8412813836ad // Address literal
let move_balance = coin::balance<AptosCoin>(addr) // Returns the MOVE balance of the address
}
```

Notice that we also used `coin::balance` with generic type argument (`<AptosCoin>`). This means the same `balance` function can be used to query balances for any asset implemented as an Aptos coin type, by changing the type argument

###Re `deposit` Function Refactoring

We have learnt enough to refactor our function so that the module actually accepts MOVE coin as a collateral.

```move
module stabletoken::stabletoken_engine{
// Rest of the module

    const ENOT_ENOUGH_BALANCE: u64 = 7;

    public entry fun deposit(account: &signer, amount: u64) acquires User, SignerCap { // SignerCap acquired to use reource address
        assert!(amount > 0, EZERO_AMOUNT);
        let addr = signer::address_of(account);
        assert!(exists<User>(addr), EACCOUNT_NOT_INITIALIZED);
        //TODO: Check if the user has a MOVE balance greater than or equal to the indicated `amount` using `assert!()`, `coin::balance<AptosCoin>`, if not return `ENOT_ENOUGH_BALANCE`
        let resource_addr = borrow_global<SignerCap>(@stabletoken).resource_addr; // Retrieves the resource address associoated with the module
        coin::transfer<AptosCoin>(account, resource_addr, amount); // Transfer coins from the user account to the module's resource account
        let deposit_amount = borrow_global<User>(addr).deposit.amount;
        let deposit_ref = &mut borrow_global_mut<User>(addr).deposit.amount;
        *deposit_ref = deposit_amount + amount;
        event::emit(DepositEvent { account: addr, amount });
    }
}
```

Simple to-do: Check if the user has enough balance to deposit indicated amount.

### Test Refactoring

#### `setup_test_caps` Function

Previously in our stabletoken module, we were accepting an imaginery coin. In tests, we created fake structs to imitate that the user enough deposit and stabletoken to carry out tests. However now, the module accepts MOVE coin as a collateral so we need to imitate that the test account has enough balance to carry out tests.

To execute that, we will define a test helper to create test coins called `setup_test_caps`. `setup_test_caps` creates test coins to imitate a fake MOVE balance in tests. It takes an `framework` argument with a type of `&signer`. `framework` represents the priviliged authority that owns the Move framework coin configuration and is allowed to perform actions that normal account cannot (i.e. initialization and capability creation).

`setup_test_caps` returns tuple of of two capabilities to grant priviliged authority over the AptosCoin coin type. `BurnCapability<AptosCoin>` gives the ability to burn AptosCoin type and `MintCapability<AptosCoin>` gives the ability to mint AptosCoin type.

```move
module stabletoken::stabletoken_engine{
// Rest of the module

#[test_only] // Indicates that the following only for test
    fun setup_test_caps(
        account: &signer, framework: &signer, amount: u64
    ): (coin::BurnCapability<AptosCoin>, coin::MintCapability<AptosCoin>) {
        let addr = signer::address_of(account); // Retrieves the account address associoated with the transaction caller
        let (burn_cap, mint_cap) =
            aptos_framework::aptos_coin::initialize_for_test(framework); // Initialize burn and mint capabilites using `framework`
        coin::deposit(addr, coin::mint<AptosCoin>(amount, &mint_cap)); // Deposit indicated amount of test coins to the signer
        (burn_cap, mint_cap) // Returns burn and mint capabilites
    }
}
```

#### `clean_test_caps` Function

`setup_test_caps` only creates test coins for an account. However, we also need to clear the provided test capabilites. Let's create a function to clean up test tokens. This function uses `coin::destroy_burn_cap()` and `coin::destroy_mint_cap()` methods to destroy created test capabilities.

```move
module stabletoken::stabletoken_engine{
// Rest of the module

    #[test_only] // Indicates that the following only for test
    fun clean_test_caps(
        burn_cap: coin::BurnCapability<AptosCoin>,
        mint_cap: coin::MintCapability<AptosCoin>
 ) {
        coin::destroy_burn_cap(burn_cap); // Destroys the burn capability
        coin::destroy_mint_cap(mint_cap); // Destrys the mint capability
    }

}
```

#### `deposit_check` Test Refactoring

Now, we are ready to refactor `deposit_check` test to integrate MOVE coin as a collateral.

```move
module stabletoken::stabletoken_engine {
// Rest of the module
    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)] // Marks as a test; injects signers: `account` at address 0x123 (simulated user), `stabletoken` at the module's named address (module admin), `framework` at @aptos_framework (privileged authority for coin initialization)
    fun deposit_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let deposit_amount = 10; // Sets the deposit amount to be used in the test
        let addr = signer::address_of(account); // Retrieves the account address of the transaction caller

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount); // Sets up test coins and returns burn and mint capabilities

        register_account(stabletoken); // Registers the stabletoken account
        init_module(stabletoken); // Initializes the module, creating a resource account for the module
        initialize(account); // Initializes the user, creating a `User` struct in the global storage

        let before_balance = coin::balance<AptosCoin>(addr); // Retrieves the MOVE balance of the account before the deposit

        deposit(account, deposit_amount); // Deposits the indicated amount to the module

        let after_balance = coin::balance<AptosCoin>(addr); // Retrieves the MOVE balance of the account after the deposit

        assert!(deposit_of(addr) == deposit_amount); // Asserts that the deposit recorded in the module equals the deposited amount
        assert!(
            before_balance - after_balance >= deposit_amount // Asserts that the on-chain balance decreased by at least the deposit amount
        );
        clean_test_caps(burn_cap, mint_cap); // Cleans up the test capabilities
    }
}
```

Previously, we were not assigning number used in test to variable. However, it always increases readibility to do so. That's why, from now on, we are going to assign every number used in tests to a variable.
