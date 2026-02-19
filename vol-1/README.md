# Move Stabletoken Tutorial Volume 1

## Modules

In Move, smart contract logic and assets are stored in the modules. By definition, move modules contains the struct types and the functions that controls these struct types. Structs are the data structure of an on-chain state (i.e. balance of a token or infromation that is recorded in a NFT), whereas the functions control structs to act on those structs(i.e. depositing an asset). One of the best analogy that can be imagined to understand modules (or smart contracts) is vending machine. Vending machine is programmed to supply the intended product if the user qualify the requirements (whether the user provided enough money). In this example, the product may be seen as the defined struct in a move module and all related operations carried out by vending machine may be seen as the functions in a move module.

### Defining a Move Module

The general structure while creating a move module is as following:

```move
module <address>::<identifier> {
    //Module Body
}
```

So, in our case, since we added our address litteral to Move.toml:

```move
module stabletoken::stabletoken_engine {
    //Module Body
}
```

which is equal to:

```move
module 0x5bd82a7c6a44c5b241b074bac9b277e565fb10b77b32e3599dce8412813836ad::stabletoken_engine {
    //Module Body
}
```

In Movement Move, each account may deploy any amount of module on their account address which is stored in the deployed account, `identifier` let developers to name the module so that its functions can be reached under that specific name. In our case, our `identifier` is `stabletoken_engine`.

Module names may start with letters `a` to `z` and `A` to `Z`. Generally, it may include letters `a` to `z`, `A` to `Z`, underscore `_` and numbers `0` to `9`.

The elements within a module block have no required ordering, as long as the logic inside it is solid.

## Data Types

In Move, there are primitive data types that can be used in the module. The most used ones are listed below.

### Integers

Move has signed integers (annoted with i) and unsigned integers (annoted with u) to declare an integer. Integer types always annote the bits that they replace in the memory (i.e. u64 represent unsigned integer that has a length of 64 bits in the memory). The length of an integer can be `8`, `16`, `32`, `64`, `128` and `256` which determines the maximum value that the variable can store.

| Type                             | Value Range                             |
| -------------------------------- | --------------------------------------- |
| Unsigned 8-bit integer, `u8`     | 0 to 2<sup>8</sup> - 1                  |
| Unsigned 16-bit integer, `u16`   | 0 to 2<sup>16</sup> - 1                 |
| Unsigned 32-bit integer, `u32`   | 0 to 2<sup>32</sup> - 1                 |
| Unsigned 64-bit integer, `u64`   | 0 to 2<sup>64</sup> - 1                 |
| Unsigned 128-bit integer, `u128` | 0 to 2<sup>128</sup> - 1                |
| Unsigned 256-bit integer, `u256` | 0 to 2<sup>256</sup> - 1                |
| Signed 8-bit integer, `i8`       | -2<sup>7</sup> to 2<sup>7</sup> - 1     |
| Signed 16-bit integer, `i16`     | -2<sup>15</sup> to 2<sup>15</sup> - 1   |
| Signed 32-bit integer, `i32`     | -2<sup>31</sup> to 2<sup>31</sup> - 1   |
| Signed 64-bit integer, `i64`     | -2<sup>63</sup> to 2<sup>63</sup> - 1   |
| Signed 128-bit integer, `i128`   | -2<sup>127</sup> to 2<sup>127</sup> - 1 |
| Signed 256-bit integer, `i256`   | -2<sup>255</sup> to 2<sup>255</sup> - 1 |

The type declaration of an integer variable may be done explicitly or implicitly.

```move
let deposit_amount = 10; // Implicitly defined
let minted_amount: u64 = 10; // Expilictly defined
let id: u64 = 0x1; // Hexedecimal
```

`let` keyword is used to define a variable, similarly `const` keyword is used to define constants.

### Boolean

`bool` is a primitive data type for `true` and `false`.

```move
let liquidated: bool = true;
```

### Address

`address` is type which is used to represent 256-bit hexedecimal string for account/module addresses.

```move
let addr: address = 0x3f8a2e1c9b7d6f4a8e2c1d9b7f5a3e8c2d1b9f7e5a3c8e2d1f9b7a5e3c8d2f1a
```

## Structs

### Decleration

Structs are objects that contain key-value pairs inside it which are stored in the global storage. Binding values can be any basic data type or other structs, but not as default. They are defined with `struct` keyword as follows:

In our example, we will declare a `Deposit` struct to keep record of the users deposits. For now, we dont assing any ability to our struct, which means in the current state, `Deposit` struct cannot be coppied, dropped or stored in the global stored in the global storage.

```move
module stabletoken::stabletoken_engine {
    struct Deposit {
        amount: u64
    }
}
```

Our `Deposit` struct has a key of `amount` whose type assigned as `u64`.

In Move, name of structs should start with a capital letter `A` to `Z`, the rest may contain letters from `a` to `z`, numbers `0` to `9` and underscore `_`

For this part of the tutorial, we will have two structs: `Deposit` and `Stabletoken`. `Deposit` keeps tracks of the user deposits and `Stabletoken` keeps track of the minted stabletoken in return of the deposit. So our module becomes,

```move
module stabletoken::stabletoken_engine{
    struct Deposit {
        amount: u64
}

    struct Stabletoken {
        amount: u64
    }
}
```

### Creating a Struct instance

In order to create an instance of a struct, we can simply assign it to a variable. In our case,

```move
module stabletoken::stabletoken_engine{
    struct Deposit {
        amount: u64
    }

    struct Stabletoken {
        amount: u64
    }

    let deposit = Deposit{amount: 1000};

    let stabletoken = Stabletoken{amount: 1000};
}
```

In Move, we can implicitly assign key-value as,

```move
module stabletoken::stabletoken_engine{
    struct Deposit {
        amount: u64
    }

    struct Stabletoken {
        amount: u64
    }

    const amount = 10;

    let deposit = Deposit{amount} // Same decleration as Deposit{amount:amount} or Deposit{amount:10}
}
```

## Abilities

Abilities may be concieved as the features of the structs. They indicate operations that are allowed to perform on a specific struct, which means they determine whether a struct is an asset (something considered to hold a value) or just operationally needed.

There are four abilities that a struct may have. These are `store`, `key`, `copy`, and `drop`. In short,

- `store`: Enables values of these types to be placed within structs in global storage.

- `key`: Enables the type to function as an identifier for global storage operations.

- `copy`: Enables duplication of values for types that have this ability.

- `drop`: Enables values of these types to be discarded or removed.

### Store

`store` ability enables values of these types to placed within structs in global storage, meaning the structs that has `store` ability to be stored in other structs. For our stabletoken example, we can declare a `User` struct to keep track of the users deposit and minted stabletoken amount. In order to execute this functionality, we need to set `Deposit` and `Stabletoken` structs with `store` ability to be stored in `User` struct.

```move
module stabletoken::stabletoken_engine {

    struct Deposit has store {
        amount: u64
    }

    struct Stabletoken has store {
        amount: u64
    }

    struct User has store { // User struct has store ability since Deposit and Stabletoken structs inside it have alo stroge ability
        deposit: Deposit, // Deposit struct can be stored inside User struct since it has a store ability
        stabletoken: Stabletoken // Stabletoken struct can be stored inside User struct since it has a store ability
    }
}
```

When a struct possesses `store` ability, every struct nested within it must also possess `store`.

### Key

`key` ability enables the struct to function as an identifier for global storage operations, meaning the each account can create one instance of the structs that has `key` ability and can be retrieved from the global storage using account address and object name.

`move_to(<address>, <object>)` command is used to store a stuct with `key` ability in the global storage. `borrow_global<<object>(<address>)>` command is used to retrieve a struct with `key` ability from the globaly storage. `borrow_global_mut<<object>(<address>)` is used to create a mutable reference (changable reference) to the called object.

```move
module stabletoken::stabletoken_engine {

    struct Deposit has store {
        amount: u64
    }

    struct Stabletoken has store {
        amount: u64
    }
    }

    struct User has key { // key ability indicates each account can own only one User strucct associated with the account
        deposit: Deposit,
        stabletoken: Stabletoken
    }

    let address = 0x5bd82a7c6a44c5b241b074bac9b277e565fb10b77b32e3599dce8412813836ad;

    let empty_deposit = Deposit{ amount: 0};
    let empty_stabletoken = Stabletoken{amount: 0};
    let new_user = User{ deposit: empty_deposit, stabletoken: empty_stabletoken}

    move_to(account, new_user) //  Records the new_user struct to the global storage

    let user_reference = borrow_global<User>(address); // User reference to retrieve User struct associated with the account
    let user_deposit = borrow_global<User>(address).deposit.amount; // Deposit amount of the reference user
    let user_stabletoken = borrow_global<User>(address).stabletoken.amount; // Stabletoken  amount of the reference user

    let user_reference_mut = &mut borrow_global_mut<User>(address); // Creates a mutable reference to the user struct associated with the account
    *user_reference_mut = new_user; // Re-assigns the user object of the associated account to new_user

    let user_deposit_mut = &mut borrow_global_mut<User>(address).deposit.amount; // Creates a mutable reference to the deposit struct inside the user struct associated with the account
    *user_deposit_mut = empty_deposit; // Re-assigns deposit object of the user object of the associated account to empty_deposit

    let user_stabletoken_mut = &mut borrow_global_mut<User>(address).stabletoken.amount; // Creates a mutable reference to the stabletoken struct inside the user the struct associated wih the account
    *user_stabletoken_mut = empty_stabletoken; // Re-assigns stabletoken object of the user object of the associated account to empty_deposit

}
```

`account` inside the `move_to()` has the type `&signer` which will be covered in more detail in the following chapters. This command can be only be invoked inside a function.

## Importing libraries or modules

`use` keyword is used to import libraries or other move modules. For example, if you want to import and use `signer` from the standart library, which is used to call signer parameters like the account address, then in the module we need to declare this as:

```move
module stabletoken::stabletoken_engine {
    use std::signer;
    // Rest of the module
}
```

## Functions

### Decleration

In order to declare a function in Move, `fun` keyword is used. The general structure to declare a function is as following:

```move
fun <identifier><[type_parameters: constraint],*>([identifier: type],*): <return_type> <acquires [identifier],*> <function_body>
```

Simple function to carry out addition:

```move
module stabletoken::stabletoken_engine {
    fun add(num1: u64, num2: u64): u64 {
        num1 + num2
    }
}
```

This function takes num1 with a type of `u64` and num2 with a type of `u64` as a parameter and returns a value whose type is u64. Normally, as you can see, `;` is appended at the end of each operation (each line except end of any scope decleration - modules, functions and structs). When a value to be returned in a function, it is enough not to append the value with `;` at the end. In this simple example, `add` function returns the value `num1 + num2`.

### Visibilty

Visibility determines who or what can be called the function, meaning whether it is available to call from any module/account or just inside the defined module. By default functions are only to be called in the scope of module that functions are defined, which indicates functions are private when otherwise explicitly stated.

#### Public Visibility

`public` keyword is used to indicate that a function can be called from anywhere. `public` functions are allowed to be called by:

- Functions defined in the same module.
- Functions defined in the other modules.
- Any account.

So, in our previous example if we wanted to make `add` function `public`, which was private, we simply add `public` keyword function signature.

```move
module stabletoken::stabletoken_engine {
   public fun add(num1: u64, num2: u64): u64 {
        num1 + num2
    }
}
```

#### Entry Functions

Functions that changes the global storage is called entry functions, which are annoted with `entry` keyword. `entry` functions are strictly void so they shall not return any value.

To example this, we can create a function called `initialize` to create a new user struct that has empty deposit struct and empty stabletoken struct to store in the global storage. As we discussed before, `signer` is the transaction (function) executor. So the `signer` owns the state changes related to that function. In this example, we use it to obtain the account address of the transaction caller and to store the `new_user` struct under to the `signer` address.

```move
module stabletoken::stabletoken_engine {
      use std::signer;

    struct Deposit has store {
        amount: u64
    }

    struct Stabletoken has store {
        amount: u6
    }

    struct User has key {
        deposit: Deposit,
        stabletoken: Stabletoken
    }

    public entry fun initialize(account: &signer) {
        let addr = signer::address_of(account); // Retrieves the (transaction) caller address
        assert!(!exists<User>(addr), 0); // Checks if the user associated with the account already exists
        let empty_deposit = Deposit { amount: 0 }; // Creates an empty deposit struct
        let empty_stabletoken = Stabletoken { amount: 0 }; // Creates an empty stabletoken struct
        let new_user = User { deposit: empty_deposit, stabletoken: empty_stabletoken }; // Creates an empty user struct constructing from empty_deposit and empty_stabletoken
        move_to(account, new_user); // Publish  new_user struct to the global storage
    }
}
```

Here, `initialize` function publish a `User` under the signer address, hence, it changes the global storage, which requires `entry` decleration in the function signature.

In the above function, you may see some unfamiliar operations like `address_of` method on `signer`, `assert!()` conditional and `exists<<object_name>>`. `signer` has method called `address_of` which returns the account address of the `signer`. `assert!()` conditional takes two parameters, one is `bool` conditional, the second one is the error code. If the indicated conditional returns false, it reverts the state changes occurred in the function. In the function above, `assert!()` is used to ensure there is not already an existing user associated with the `signer` account. `exists<<object_name>>(<account_address>)` returns a `bool` indicates wheter given account address owns an instance of the given object, we check if the caller of the function owns an `user` object to ensure the `initialize` function not over-writing on the existent `user` object.

#### Acquires

If a function reads or changes value related to a specific struct, that struct should be included as `acquires` in function's signature.

For our stabletoken, users shall deposit their collateral to be able to mint stabletoken. So lets create a `deposit` function for this operation. At this level, lets assume a perfect world and everyone has infinite amount of balance and they instantly pay the provided amount.

```move
module stabletoken::stabletoken_engine{
// Rest of the module
    public entry fun deposit(account: &signer, amount: u64) acquires User {
        let addr = signer::address_of(account); // Retrieves the (transaction) caller address
        assert!(exists<User>(addr), 0); // Checks if the user associated with the account already exists
        let deposit_ref = borrow_global<User>(addr).deposit.amount; // Creates a reference for user deposit of the associated address
        let deposit_mut = &mut borrow_global_mut<User>(addr).deposit.amount; // Creates a mutable reference for user deposit of the associated address
        *deposit_mut = deposit_ref + amount; // Increase the current deposit by provided amountH
    }
}
```

Since we read from the `User` struct and modify state in the `User` struct in `deposit` function, so it should be annoted that `deposit` function `acquires` `User` struct.

## Error Codes

In the `assert!()` method we used above, make sure the first statement holds true, if not return the second parameter like an error code. You may realize for both usage we return the same error code if the boolean operation falls to false, which is not really desirable since with this structure we are not able to undestand where we get the error from. So, we can customize our error coders to understand where the code fails.

There is no special method to create a custom error but we may define error codes as constants and return those error. Let's refactor our functins to have custom errors.

```move
module stabletoken::stabletoken_engine{
// Rest of the module

// Error Codes

    const EACCOUNT_ALREADY_EXISTS: u64 = 0;
    const EACCOUNT_NOT_EXISTS: u64 = 1;

    public entry fun initialize(account: &signer) {
        let addr = signer::address_of(account);
        assert!(!exists<User>(addr), EACCOUNT_ALREADY_EXISTS); // Returns EACCOUNT_ALREADY_EXISTS if the bool parameter returns false
        let empty_deposit = Deposit { amount: 0 };
        let empty_stabletoken = Stabletoken { amount: 0 };
        let new_user = User { deposit: empty_deposit, stabletoken: empty_stabletoken };
        move_to(account, new_user);
    }

    public entry fun deposit(account: &signer, amount: u64) acquires User {
        let addr = signer::address_of(account);
I        assert!(exists<User>(addr), EACCOUNT_NOT_EXISTS); // Returns EACCOUNT_NOT_EXISTS if the bool parameter returns false
        let deposit_ref = borrow_global<User>(addr).deposit.amount;
        let deposit_mut = &mut borrow_global_mut<User>(addr).deposit.amount;
        *deposit_mut = deposit_ref + amount;
    }

}

```

## Testing

Testing is a vital process to ensure the smart contracts function as they promise without a bug. Move has a default testing feature that allows developer to benchmark their smart contracts.

`#[test]` or `#[test_only]` refers that the following function is defined to test functions in the module. We can use `#[test(<paramater> = value)]`, when we want to use a specfic value for the associated parameter during the test execution. For example, in our `initialize` function, we need to pass an `account` vairable with a type of `&signer`. In order to imitate an `account` variable in tests, we assign the intended value in the `#[test]` tag. `#[test_only]` may percieved as the helper function for tests.

With above information, we can create a test to see if our `initialize` function works correctly.

```move
module stabletoken::stabletoken_engine {
// Rest of the module

    #[test(account = @stabletoken)] // Account refers to the stabletoken account in this test
    fun initialization_check(account: &signer) acquires User {
        initialize(account); // initialize the user struct for the given account
        let addr = signer::address_of(account); // Retrieves the address of the given account
        let user = borrow_global<User>(addr); // Retrieves the user struct associated with the account
        assert!(user.deposit.amount == 0, 100); // Checks if the user struct has zero deposit
        assert!(user.stabletoken.amount == 0, 101); // Checks if the user struct has zero stabletoken
    }
}
```

In order to run tests in the module, we may use `move test --skip-fetch-latest-git-deps`

When we want to ensure a function fail with pre-defined error, `#[expected_failure(abort_code = <desired_error>)]`.

`initialize` function ensures that the provided account doesn't have any prior `User` struct record. So an account cannot be initialized twice, it should return the error `EACCOUNT_ALREADY_EXISTS`, which means we `initialize` is called twice, the function should return `EACCOUNT_ALREADY_EXISTS`. Now, we know what we want, it is time to put that into coding.

```move
module stabletoken::stabletoken_engine {
// Rest of the module

    #[test(account = @stabletoken)] // Account refers to the stabletoken account in this test
    #[expected_failure(abort_code = EACCOUNT_ALREADY_EXISTS)] // Test is expected to fail with `EACCOUNT_ALREADY_EXISTS`
    fun initialize_check_fails_account_already_exists(account: &signer) {
        initialize(account); // Account initialized once
        initialize(account); // Initialized twice - expected error
    }
}
```

We completed tests about `initialize` function, so we can move to test `deposit` function. We may use similar approach and write one test for correct usage and one for expected failure.

```move
module stabletoken::stabletoken_engine {
// Rest of the module

    #[test(account = @stabletoken)] // Account refers to the stabletoken account in this test
    fun deposit_check(account: &signer) acquires User {
        initialize(account); // Account initialized
        deposit(account, 100); // Account Deposited 100 "tokens"
        let addr = signer::address_of(account); // Retrieves the address of the given account
        let user = borrow_global<User>(addr); // Retrieves the user struct associated with the account
        assert!(user.deposit.amount == 100, 200); // Checks if the user struct has 100 deposit
    }

    #[test(account = @stabletoken)] // Account refers to the stabletoken account in this test
    #[expected_failure(abort_code = EACCOUNT_NOT_EXISTS)] // Test is expected to fail with `EACCOUNT_NOT_EXISTS`
    fun deposit_check_fails_account_not_exists(account: &signer) acquires user {
        deposit(account, 100); // Deposited 100 "tokens" without account initialization - expected error
    }
}
```

It is strongly suggested to write the test before defining the tested function. With this way it easier to write the function and test.

## `deposit_of` Function

In Move, view function do not have a seperate decleration, if a function is not labeled as `entry` then it is a view function.

With this information, it is pretty straight forward to define `deposit_of` function which returns deposit amount of the user.

### Write the test first

Before declaring our `deposit_of` function, let's create a test for it first to see, whether our future function will operates correctly.

It is already tested that new initialized `User` struct has 0 deposit. We can use this to test if our future deposit_of function will operate correctly.

````move
module stabletoken::stabletoken_engine {
// Rest of the module

    #[test(account = @stabletoken)]
    fun deposit_of_check(account: &signer) acquires Deposit {
        let addr = signer::address_of(account); // Retrieve the caller address and asigns it to addr variable
        initialize(account); // Initializes acount
        assert!(deposit_of(addr) == 0) // Checks whether newly created user has a zero deposit balance using `deposit_of` function.
    }
}
```

### Function

Since we know what this function will do, it is easier to create the actual function. This function is left uncomplete for new learners to test themselves. So, you are expected to complete the body of the `deposit_of` function.

```move
module stabletoken::stabletoken_engine{
// Rest of the module

    public fun deposit_of(addr: address): u64 acquires User {
    // TODO: Return deposit amount of the user
}
````

The relevant test is already provided, your task to make it pass with the correct implementation of `deposit_of` function.

Optional TODO: Refactor `deposit` function so that it uses `deposit_of` function in its operation in its operations.

## `stabletoken_of` Function

To keep track of the stabletoken balance of the user, our stabletoken module needs a function to return the stabletoken balance of the users.

### Write the test first

Similar to `balance_of_check` test, `stabletoken_of_check` checks whether a new user has zero stabletoken balance.

```move
  #[test(account = @stabletoken)] // Account refers to the stabletoken account in this test
    fun stabletoken_of_check(account: &signer) acquires Deposit {
        let addr = signer::address_of(account); // Retrieve the caller address and asigns it to addr variable
        initialize(account); // Initializes acount
        assert!(stabletoken_of(addr) == 0) // Checks whether newly created user has a zero stabletoken balance using `deposit_of` function.
    }

```

### Function

The body of the `stabletoken_of` function, is incomplete and expected to be completed correctly.

```move
  public fun stabletoken_of(addr: address): u64 acquires User {
        // TODO: Return stabletoken amount of the user
    }

```

## `mint` Function

`mint` function shall mint stabletokens to the user if the user deposited enough collateral.

### Write the test first

For the correct usage of the `mint` function, the following test is suitable.

```move
module stabletoken::stabletoken_engine {
// Rest of the module
    #[test(account = @stabletoken)] // Account refers to the stabletoken account in this test
    fun mint_check(
        account: &signer
    ) acquires User {
        let addr = signer::address_of(account); // Retrieves the address of the given account
        let mint_amount: u64 = 10;
        let deposit_amount: u64 = 100;

        initialize(account); // Initializes the user for the  account
        deposit(account, deposit_amount); // Deposits
        mint(account, mint_amount); // Mints stabletoken

        assert!(coin_of(addr) == mint_amount);
    }
}
```

Also, there are some boundaries of the function where `mint` function shall revert. For these cases, we can create these test that we expect them to fail.

```move
module stabletoken::stabletoken_engine {
    #[test(account = @stabletoken)] // Account refers to the stabletoken account in this test
    #[expected_failure(abort_code = ENOT_ENOUGH_DEPOSIT)] // Test is expected to fail with `ENOT_ENOUGH_DEPOSIT`
    fun mint_check_fails_Rnot_enough_deposit(account: &signer) acquires user {
        initialize(account); // initializes the the user for the account
        deposit(account, 10); // deposits 100 "tokens"
   Re     mint(account, 20); // mints 20 "tokens" - expected failure since deposit is 10 "tokens" and mint is 20 "tokens"
    }

    #[test(account = @stabletoken)] // Account refers to the stabletoken account in this test
    #[expected_failure(abort_code = EACCOUNT_NOT_EXISTS)] // Test is expected to fail with `EACCOUNT_NOT_EXISTS`
    fun mint_check_fails_account_not_exists(account: &signer) acquires user {
        mint(account, 10); // mints 10 "tokens" - expected failure since account not initialized
    }

    #[test(account = @stabletoken)] // Account refers to the stabletoken account in this test
    #[expected_failure(abort_code = EZERO_AMOUNT)] // Test is expected to fail with `EZERO_AMOUNT`
    fun mint_check_fails_zero_amount(account: &signer) acquires user {
        initialize(account); // initializes the user for the account
        deposit(account, 100); // deposits 100 tokens
        mint(account, 0); // mints zero amount - expected failure since minting amount can not be zero
    }
}
```

### Function

Normally, stabletokens shall use oracle price avoiding from price manipulation occurs in the liquidity pools. We will also integrate an oracle our stabletoken eventually. However, for now, we keep things simple and have a hard coded price until we integrate oracle to our stabletoken.

Hence, we declare a constant to use it as the price.

```move
module stabletoken::stabletoken_engine {
// Rest of the module
    const PRICE: u64 = 1; // Represents the price for now
}
```

Since, we obtained our price temprorarly, our function is more straight forward.

In `mint` function below, there are some missing part that is expexted to be completed. For this time, you are expexted to write three operations so that the function operates in logic. For the first part, you should check whether the `mint_avl` is bigger than `amount`, if not return `ENOT_ENOUGH_DEPOSIT`. For the second part, you should create a mutable reference for the stabletoken balance of the user. Finally, the newly created mutable reference should be increased by `amount`.

```move
module stabletoken::stabletoken_engine {
// Rest of the module

    public entry fun mint(account: &signer, amount: u64) acquires User {
        assert!(amount > 0, EZERO_AMOUNT); // Checks if the amount bigger than zero
        let addr = signer::address_of(account); // Retrieves the address of the given account
        assert!(exists<User>(addr), EACCOUNT_NOT_EXISTS); // Checks if the user associated with the account already exists

        let deposit_balance = deposit_of(addr); // Retrieves deposit balance
        let stabletoken_balance = stabletoken_of(addr); // Retrieves stabletoken balance
        let mint_avl = deposit_balance * PRICE - stabletoken_balance; // Calculates maximum mint available

        // TODO: Check if mint_avl is bigger than amount, if not return ENOT_ENOUGH_DEPOSIT
        // TODO: Create a mutable refernce for stabletoken balance of the user
        // TODO: Increase the stabletoken balance of the user by the amount
    }
}
```

## `get_health_factor` function

In stabletokens, users deposits their funds to mint stabletokens. If the value of the deposited tokens decreased to a certain level, the value of the minted stabletokens is more than or equal to the deposited amount, the user becomes liquidated; meaning, the value of the token in the module is less then the borrowed amount.

For this operation, we need to make sure that the module calculates whether the the user's position shall be liquidated or not. `get_health_factor` function helps us to determine the position health. Since for now, it is a simple read function, we skip the tests for this function.

```move
module stabletoken::stabletoken_engine {C
// Rest of the module
    const PRECISION: u64 = 100;
    public fun get_health_factor(addr: address): u64 acquires User {
        assert!(stabletoken_of(addr) > 0); // Checks whether the user has valid number of stabletoken
        let deposit_balance = deposit_of(addr); // Retrieves the user deposit balance
        let stabletoken_balance = stabletoken_of(addr); // Retrieves the user deposit balance
        deposit_balance * PRICE * PRECISION / stabletoken_balance; // Returns health factor
    }
}
```

We didn't talk about `PRECISION` yet it appears here. What is that and why we need it? You may notice that there is no decimal point in Move. However, health factor is a ratio and shoould not have to be an integer. Hence, we are multiplying with `PRECISION`, so that we can later compare it with `PRECISION`. If the health factor is less than `PRECISION`, then the user's position should be liquidated.

## `liquidate` function

In stabletokens, generally, if there is an inbalance between the lended (deposit) and borrowed(minted stabletoken), meaning if the deposited value becomes less than minted stabletoken in value, then the user must be liquidated. Liquidated users are no longer is able to withdraw their deposit yet they keep the minted stabletoken.

### Write the test first

Let's create a one for correct usage of the `liquidate` function and one for expected failure.

```move
module stabletoken::stabletoken_engine {
// Rest of the module

    #[test(account = @stabletoken)] // Account refers to the stabletoken account in this test
    fun liquidation_check(account: &signer) acquires User{
        let addr = signer::address_of(account); // Retrieves the address of the given account
        initiliaze(account); // Initializes the account
        deposit(account, 100); // Deposits 100 "tokens"
        let stabletoken_mut_ref =  &mut borrow_global_mut<User>(addr).stabletoken.amount; // Creates a mutable reference for stabletoken balance of the user
        *stabletoken_mut_ref = 1000; //  Equates the stabletoken balance of the user to 1000
        liquidate(account); // Liquidates the user who has more stabletoken value then deposit value
        assert!(deposit_of(addr) == 0); // Chekcs if the liquidated user has zero deposit
    }

    #[test(account = @stabletoken)] // Account refers to the stabletoken account in this test
    #[expected_failure(abort_code = ENOT_LIQUIDATABLE)] // Test is expected to fail with `ENOT_LIQUIDATABLE`
    fun liquidate_check_fails_not_liquidatable(account: &signer) acquires User {
        initialize(account); // Initiliazes the account
        deposit(account, 100); // Deposits 100 "tokens"
        mint(account, 10); // Mints 10 "stabletokens"
        liquidate(account);  // Liquidates the user's stabletoken position - expected failure since the health factor is not below the precision
    }
}
```

### Function

Upon relevant decribtions, `liquidate` function becomes pretty straight forward. Except on little line which miscomplete: creating a `assert!()` conditional to check if the users health factor is below liquidation threshold.

```move
module stabletoken::stabletoken_engine {
// Rest of the module

    const ENOT_LIQUIDATABLE: u64 = 5;

    public entry fun liquidate(account: &signer) acquires User {
        let addr = signer::address_of(account); // Retrieves the address of the given account
        assert!(exists<User>(addr), EACCOUNT_NOT_EXISTS); // Checks if the user exists
        assert!(stabletoken_of(addr) >= ENOT_ENOUGH_STABLETOKEN); //  Checks if the user has valid balance of stabletoken

        // TODO: Check if the user's position is less then `PRECISION` using assert and get_health_factor, if not return `ENOT_LIQUIDATABLE`

        let deposit_mut_ref = &mut borrow_global_mut<User>(addr).stabletoken.amount; // Creates a mutable reference for stabletoken balance of the user
        *deposit_mut_ref = 0; // Equates the deposit balance of the user to zero
    }
}
```

## `withdraw` function

In our stabletoken contract, users should be able to withdraw funds to decrease their deposit. That's said, this function should take into account that user who has minted some amount of stabletoken should not withdraw all of his funds since some of his deposit is tied to the minted stabletoken.

### Write the test first

At this point, we know that withdrawal amount should be deducted from the deposit and users shouldn't able to withdraw more than the available deposit - due to minting stabletoken. If we put this sentence into coding, we may have two test - one for correct usage and one for exptected failure.

```move
module stabletoken::stabletoken_engine {
// Rest of the module
    #[test(account = @stabletoken)] // Account refers to the stabletoken account in this test
    fun withdrawal_check(account: &signer) acquires User {
        let addr = signer::address_of(account); // Retrieves the address of the given account
        initialize(account); // Intializes the account
        deposit(account, 1000); // Deposits 1000 "tokens"

        withdraw(account, 100); // Withdraws 100 "tokens"

        let deposit_balance = deposit_of(addr); // Retrives the deposit balance of the user

        assert!(deposit_balance == 900); // Checks if the current balance is equal to the deposited amount minus withdrown amount
    }

    #[test(account = @stabletoken)] // Account refers to the stabletoken account in this test
    #[expected_failure(abort_code = EEXCEEDS_DEPOSIT_AMOUNT)] // Test is expected to fail with `EEXCEEDS_DEPOSIT_AMOUNT`
    fun withdrawal_fail_exceeds_deposit_amount(account: &signer) acquires User {
        initialize(account); // Initiliazes the account
        deposit(account, 1000); // Deposits 1000 "tokens"
        mint(account, 500); // Mints 500 "tokens"
        withdraw(account, 600); // Withdraws 600 "tokens" - expected failure since the user already minted 500 "tokens" for his 1000 deposited "tokens"
    }

}
```

### Function

```move
module stabletoken::stabletoken_engine {
// Rest of the module

public entry fun withdraw(account: &signer, amount: u64) acquires User {
        let addr = signer::address_of(account); // Retrieves the address of the given account
        let deposit_balance = deposit_of(addr); // Retrieves deposit balance of the user
        let stabletoken_balance = stabletoken_of(addr); // Retrieves stabletoken balance of the user
        let max_allow_withdraw = deposit_balance - stabletoken_balance / PRICE; // Calculates maximum allowable withdraw due to minting
        assert!(max_allow_withdraw >= amount, EEXCEEDS_DEPOSIT_AMOUNT); // Checks if `amount` is less then or equal to `max_allow_withdraw`, if not return `EEXCEEDS_DEPOSIT_AMOUNT`
        assert!(deposit_balance >= amount, ENOT_ENOUGH_DEPOSIT); // Checks if the `deposit_balance` is less then or equal to `amount`, if not return `ENOT_ENOUGH_DEPOSIT`

        let deposit_mut_ref = &mut borrow_global_mut<User>(addr).deposit.amount; // Creates a mutable reference for deposit balance of the user
        *deposit_mut_ref = deposit_balance - amount; // Equates the deposit balance of the user to subtraction of `amount` from `deposit_balance`
    }
}
```

## `burn` function

Users should be able to give up their stabletokens to withdraw more deposit or make a profit.

### Write the test first

We know that `burn` amount should be deducted from the stabletoken balance and users should not burn more than their stabletoken balance.

```move
module stabletoken::stabletoken_engine {
// Rest of the module

    #[test(account = @stabletoken)] // Account refers to the stabletoken account in this test
    fun burn_check(account: &signer) acquires User {
        let addr = signer::address_of(account); // Retrieves the address of the given account
        initialize(account); // Initializes the account
        deposit(account, 1000); // Deposits 1000 "tokens"
        mint(account, 100); // Mints 100 "tokens"

        let stabletoken_balance = stabletoken_of(addr); // Retrieve the stabletoken balance of the user
        burn(account, 100); // Burns 100 "tokens"

        assert!(
            stabletoken_of(addr) == stabletoken_balance - 100
        ); // Checks if the stabltoken balance of the user is the stabletoken balance before minus burn amount
    }

    #[test(account = @stabletoken)]
    // Account refers to the stabletoken account in this test
    #[expected_failure(abort_code = ENOT_ENOUGH_STABLETOKEN)]
    // Test is expected to fail with `ENOT_ENOUGH_STABLETOKEN`
    fun burn_fail_not_enough_stabletoken(account: &signer) acquires User {
        initialize(account); // Initializes the account
        deposit(account, 1000); // Deposits 1000 "tokens"
        mint(account, 100); // Mints 100 "tokens"
        burn(account, 200); // Burns 200"tokens" - expected failure since the burn amount is more than the stabletoken balance of the user
    }
}
```

### Function

```move
module stabletoken::stabletoken_engine{
// Rest of the module

    public entry fun burn(account: &signer, amount: u64) acquires User {
        assert!(amount > 0, EZERO_AMOUNT); // Checks if the burn amount is more than zero
        let addr = signer::address_of(account); // Retrieves the address of the given account
        let stabletoken_balance = stabletoken_of(addr); // Retrieves the stabletoken balance of the user
        assert!(stabletoken_balance >= amount, ENOT_ENOUGH_STABLETOKEN); // Checks if the user has more or same stabletoken balance than `amount`

        let stabletoken_mut_ref = &mut borrow_global_mut<User>(addr).stabletoken.amount; // Creates a mutable reference for stabletoken balance of the user
        *stabletoken_mut_ref = stabletoken_balance - amount; // Subrtracts `amount` from the user's old stabletoken balance and equates it to the current stabletoken balance of the user
    }
}
```
