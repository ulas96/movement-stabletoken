# Move Stabletoken Tutorial Volume 1

## Modules

In Move, smart contract logic and assets are stored in the modules. By definition, move modules contains the struct types and the functions that controls these struct types. Structs are the data structure of an on-chain state (i.e. balance of a token or infromation that is recorded in a NFT), whereas the functions control structs to act on those structs(i.e. depositing an asset). One of the best analogy that can be imagined to understand modules (or smart contracts) is vending machine. Vending machine is programmed to supply the intended product if the user qualify the requirements (whether the user provided enough money). In this example, the product may be seen as the defined struct in a move module and all related operations carried out by vending machine may be seen as the functions in a move module.

### Defining a Move Module

The general structure while creating a move module is as following:

`module <address>::<identifier> {
//Module Body
}`

So, in our case, since we added our address litteral to Move.toml:

`module stabletoken::stabletoken_engine {
//Module Body
}`

which is equal to:

`module 0x5bd82a7c6a44c5b241b074bac9b277e565fb10b77b32e3599dce8412813836ad::stabletoken_engine {
//Module Body
}`

In Movement Move, each account may deploy any amount of module on their account address which is stored in the deployed account, `identifier` let developers to name the module so that its functions can be reached under that specific name. In our case, our `identifier` is `stabletoken_engine`.

Module names may start with letters `a` to `z` and `A` to `Z`. Generally, it may include letters `a` to `z`, `A` to `Z`, underscore `_` and numbers `0` to `9`.

The elements within a module block have no required ordering, as long as the logic inside it is solid.

### Importing libraries or modules

`use` keyword is used to import libraries or other move modules. For example, if you want to import and use `signer` from the standart library, which is used to call signer parameters like the account address, then in the module we need to declare this as:

`module stabetoken::stabletoken_engine {
use std::signer;
// Rest of the module
}`
