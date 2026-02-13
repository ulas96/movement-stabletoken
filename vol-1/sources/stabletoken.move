module stabletoken::stabletoken_engine {
    use std::signer;

    // Error Codes

    const EACCOUNT_ALREADY_EXISTS: u64 = 0;
    const EACCOUNT_NOT_EXISTS: u64 = 1;
    const ENOT_ENOUGH_DEPOSITl: u64 = 2;
    const ENOT_ENOUGH_STABLETOKEN: u64 = 3;

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
        let addr = signer::address_of(account); // Retrieve the caller address and asigns it to addr variable
        assert!(!exists<User>(addr), EACCOUNT_ALREADY_EXISTS); // Checks if the user affiliated with the account already exists
        let empty_deposit = Deposit { amount: 0 }; // Creates an empty deposit struct
        let empty_stabletoken = Stabletoken { amount: 0 }; // Creates an empty stabletoken struct
        let new_user = User { deposit: empty_deposit, stabletoken: empty_stabletoken }; // Creates an empty user struct constructing from empty_deposit and empty_stabletoken
        move_to(account, new_user); // Records newly created new_user struct to the global storage
    }

    public entry fun deposit(account: &signer, amount: u64) acquires User {
        let addr = signer::address_of(account); // Retrieves the (transaction) caller address
        assert!(exists<User>(addr), EACCOUNT_NOT_EXISTS); // Checks if the user associated with the account already exists
        let deposit_ref = borrow_global<User>(addr).deposit.amount; // Creates a reference for user deposit of the associated address
        let deposit_mut = &mut borrow_global_mut<User>(addr).deposit.amount; // Creates a mutable reference for user deposit of the associated address
        *deposit_mut = deposit_ref + amount; // Increase the current deposit by provided amount
    }

    // Account refer to the stabletoken account in this test
    #[test(account = @stabletoken)]
    fun initialization_check(account: &signer) acquires User {
        initialize(account); // initialize the user struct for the given account
        let addr = signer::address_of(account); // Retrieves the address of the given account
        let user = borrow_global<User>(addr); // Retrieves the user struct associated with the account
        assert!(user.deposit.amount == 0); // Checks if the user struct has zero deposit
        assert!(user.stabletoken.amount == 0); // Checks if the user struct has zero stabletoken
    }

    // Account refer to the stabletoken account in this test
    #[test(account = @stabletoken)]
    // Test is expected to fail with `EACCOUNT_ALREADY_EXISTS`
    #[expected_failure(abort_code = EACCOUNT_ALREADY_EXISTS)]
    fun initialize_check_fails_account_already_exists(account: &signer) {
        initialize(account); // Initialized once
        initialize(account); // Initialized twice - expected error
    }

    // Account refers to the stabletoken account in this test
    #[test(account = @stabletoken)]
    fun deposit_check(account: &signer) acquires User {
        initialize(account); // Account initialized
        deposit(account, 100); // Account Deposited 100 "tokens"
        let addr = signer::address_of(account); // Retrieves the address of the given account
        let user = borrow_global<User>(addr); // Retrieves the user struct associated with the account
        assert!(user.deposit.amount == 100); // Checks if the user struct has 100 deposit
    }

    // Account refers to the stabletoken account in this test
    #[test(account = @stabletoken)]
    // Test is expected to fail with `EACCOUNT_NOT_EXISTS`
    #[expected_failure(abort_code = EACCOUNT_NOT_EXISTS)]
    fun deposit_check_fails_account_not_exists(account: &signer) acquires user {
        deposit(account, 100); // Deposited 100 "tokens" without account initialization - expected error
    }
}
