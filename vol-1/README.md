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

In the above function, you may see some unfamiliar operations like `address_of` method on `signer`, `assert!()` conditional and `exists<<object_name>>`. `signer` has method called `address_of` which returns the account address of the `signer`. `assert!()` conditional takes two parameters, one is `bool` conditional, the second one is the error code. If the indicated conditional returns false, it reverts the state changes occurred in the function. In the function above, `assert!()` is used to ensure there is not already an existing user associated with the `signer` account. `exists<<object_name>>(<account_address>)` returns a `bool` indicates wheter given account address owns an instance of the given object, we check if the caller of the function owns an `user` object to ensure the `initilize` function not over-writing on the existent `user` object.

#### Acquires

If a function reads or changes value related to a specific struct, that struct should be included as `acquires` in function's signature.

For our stabletoken, users shall deposit their collateral to be able to mint stabletoken. So lets create a `deposit` function for this operation. At this level, lets assume a perfect world and everyone has infinite amount of balance and they instantly pay the provided amount.

```move
module stabletoken::stabletoken_engine{
// Rest of the module
    public entry fun deposit(account: &signer, amount: u64) acquires User, Deposit {
        let addr = signer::address_of(account); // Retrieves the (transaction) caller address
        assert!(exists<User>(addr), 0); // Checks if the user associated with the account already exists
        let deposit_ref = borrow_global<User>.deposit.amount;
        let deposit_mut = &mut borrow_global_mut<User>.deposit.amountl;
        *deposit_mut = deposit_ref + amount;
    }
}
```

Since we read from the `User` struct and modify state in the `User` struct in `deposit` function, so it should be annoted that `deposit` function `acquires` `User` struct.
