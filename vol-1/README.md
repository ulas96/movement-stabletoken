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
let explicit_integer = 10;
let implicit_integer: i64 = 10;
let hex_unsigned: u64 = 0x1;
```

`let` keyword is used to define a variable, similarly `const` keyword is used to define constants.

### Boolean

`bool` is a primitive data type for `true` and `false`.

```move
let some_boolean: bool = true;
let some_other_booolean: bool = false;
```

### Address

`address` is type which is used to represent 256-bit hexedecimal string for account/module addresses.

```move
let addr: address = 0x3f8a2e1c9b7d6f4a8e2c1d9b7f5a3e8c2d1b9f7e5a3c8e2d1f9b7a5e3c8d2f1a
```

### Structs

#### Defining a Struct

Structs are objects that contain key-value pairs inside it which are stored in the global storage. Binding values can be any basic data type or other structs, but not as default. They are defined with `struct` keyword as follows:

In our example, we will declare a `Deposit` struct to keep record of the users deposits. For now, we dont assing any ability to our struct, which means in the current state, `Deposit` struct cannot be coppied, dropped or stored in the global stored in the global storage.

```move
module stabletoken::stabletoken_engine {
    struct Deposit {
        amount: u64
    }
}
```

Our `Deposit` struct has a key of `amount` whose value type assigned as `u64` which means `amount` may be ranged from `0` to `2^64 - 1`

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

#### Creating a Struct instance

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

### Importing libraries or modules

`use` keyword is used to import libraries or other move modules. For example, if you want to import and use `signer` from the standart library, which is used to call signer parameters like the account address, then in the module we need to declare this as:

```move
module stabletoken::stabletoken_engine {
    use std::signer;
    // Rest of the module
}
```
