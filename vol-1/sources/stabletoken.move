module stabletoken::stabletoken_engine {
    use std::signer;

    struct Deposit has store {
        amount: u64
    }

    struct Stabletoken has store {
        amount: u64
    }

    struct User has key {
        deposit: Deposit,
        stabletoken: Stabletoken
    }

    public entry fun initialize(account: &signer) {
        let addr = signer::address_of(account); // retrieve the caller address and asigns it to addr variable
        assert!(!exists<User>(addr), 0); // Checks if the user affiliated with the account already exists
        let empty_deposit = Deposit { amount: 0 }; // Creates an empty deposit struct
        let empty_stabletoken = Stabletoken { amount: 0 }; // Creates an empty stabletoken struct
        let new_user = User { deposit: empty_deposit, stabletoken: empty_stabletoken }; // Creates an empty user struct constructing from empty_deposit and empty_stabletoken
        move_to(account, new_user); // Records newly created new_user struct to the global storage
    }

    public entry fun deposit(account: &signer, amount: u64) acquires User {
        let addr = signer::address_of(account); // Retrieves the (transaction) caller address
        assert!(exists<User>(addr), 0); // Checks if the user associated with the account already exists
        let deposit_ref = borrow_global<User>(addr).deposit.amount; // Creates a reference for user deposit of the associated address
        let deposit_mut = &mut borrow_global_mut<User>(addr).deposit.amount; // Creates a mutable reference for user deposit of the associated address
        *deposit_mut = deposit_ref + amount; // Increase the current deposit by provided amount
    }
}
