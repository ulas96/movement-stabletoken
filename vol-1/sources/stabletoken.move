module stabletoken::stabletoken_engine {
    use std::signer;

    // Error Codes

    const EACCOUNT_ALREADY_EXISTS: u64 = 0;
    const EACCOUNT_NOT_EXISTS: u64 = 1;
    const ENOT_ENOUGH_DEPOSIT: u64 = 2;
    const ENOT_ENOUGH_STABLETOKEN: u64 = 3;
    const ENOT_ENOUGH_STABLETOKEN: u64 = 4;
    const ENOT_LIQUIDATABLE: u64 = 5;

    // Constants

    const PRICE: u64 = 1;
    const PRECISION: u64 = 100;

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
        let addr = signer::address_of(account); // Retrieves the address of the given account
        assert!(!exists<User>(addr), EACCOUNT_ALREADY_EXISTS); // Checks if the user affiliated with the account already exists
        let empty_deposit = Deposit { amount: 0 }; // Creates an empty deposit struct
        let empty_stabletoken = Stabletoken { amount: 0 }; // Creates an empty stabletoken struct
        let new_user = User { deposit: empty_deposit, stabletoken: empty_stabletoken }; // Creates an empty user struct constructing from empty_deposit and empty_stabletoken
        move_to(account, new_user); // Records newly created new_user struct to the global storage
    }

    public entry fun deposit(account: &signer, amount: u64) acquires User {
        let addr = signer::address_of(account); // Retrieve the caller address and asigns it to addr variable
        assert!(exists<User>(addr), EACCOUNT_NOT_EXISTS); // Checks if the user associated with the account already exists
        let deposit_ref = borrow_global<User>(addr).deposit.amount; // Creates a reference for user deposit of the associated address
        let deposit_mut = &mut borrow_global_mut<User>(addr).deposit.amount; // Creates a mutable reference for user deposit of the associated address
        *deposit_mut = deposit_ref + amount; // Increase the current deposit by provided amount
    }

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

    public entry fun liquidate(account: &signer) acquires User {
        let addr = signer::address_of(account); // Retrieves the address of the given account
        assert!(exists<User>(addr), EACCOUNT_NOT_EXISTS); // Checks if the user exists
        assert!(stabletoken_of(addr) >= ENOT_ENOUGH_STABLETOKEN); //  Checks if the user has valid balance of stabletoken

        // TODO: Check if the user's position is less then `PRECISION` using assert and get_health_factor, if not return `ENOT_LIQUIDATABLE`

        let deposit_mut_ref = &mut borrow_global_mut<User>(addr).stabletoken.amount; // Creates a mutable reference for stabletoken balance of the user
        *deposit_mut_ref = 0; // Equates the deposit balance of the user to zero
    }

    // Public View Functions

    public fun deposit_of(addr: address): u64 acquires User {
        // TODO: Return deposit amount of the user
    }

    public fun stabletoken_of(addr: address): u64 acquires User {
        // TODO: Return stabletoken amount of the user
    }

    public fun get_health_factor(addr: address): u64 acquires User {
        assert!(stabletoken_of(addr) > 0); // Checks whether the user has valid number of stabletoken
        let deposit_balance = deposit_of(addr); // Retrieves the user deposit balance
        let stabletoken_balance = stabletoken_of(addr); // Retrieves the user deposit balance
        deposit_balance * PRICE * PRECISION / stabletoken_balance; // Returns health factor
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
        initialize(account); // Initializes the user fot the account
        deposit(account, 100); // Deposits 100 "tokens"
        let addr = signer::address_of(account); // Retrieves the address of the given account
        let user = borrow_global<User>(addr); // Retrieves the user struct associated with the account
        assert!(user.deposit.amount == 100); // Checks if the user struct has 100 deposit
    }

    // Account refers to the stabletoken account in this test
    #[test(account = @stabletoken)]
    // Test is expected to fail with `EACCOUNT_NOT_EXISTS`
    #[expected_failure(abort_code = EACCOUNT_NOT_EXISTS)]
    fun deposit_check_fails_account_not_exists(account: &signer) acquires User {
        deposit(account, 100); // Deposited 100 "tokens" without account initialization - expected error
    }

    #[test(account = @stabletoken)]
    fun deposit_of_check(account: &signer) acquires User {
        let addr = signer::address_of(account);
        initialize(account); // initializes the user for the account
        assert!(deposit_of(addr) == 0) // Checks if the user has zero deposit
    }

    #[test(account = @stabletoken)]
    fun stabletoken_of_check(account: &signer) acquires User {
        let addr = signer::address_of(account); // Retrieves the address of the given account
        initialize(account); // Initializes the the user for the account
        assert!(stabletoken_of(addr) == 0); // Checks if the user has zero stabletoken
    }

    #[test(account = @stabletoken)]
    #[expected_failure(abort_code = enot_enough_deposit)]
    fun mint_check_fails_not_enough_deposit(account: &signer) acquires user {
        initialize(account); // initializes the the user for the account
        deposit(account, 10); // deposits 100 "tokens"
        mint(account, 20); // mints 20 "tokens" - expected failure since deposit is 10 "tokens" and mint is 20 "tokens"
    }

    #[test(account = @stabletoken)]
    #[expected_failure(abort_code = eaccount_not_exists)]
    fun mint_check_fails_account_not_exists(account: &signer) acquires user {
        mint(account, 10); // mints 10 "tokens" - expected failure since account not initialized
    }

    #[test(account = @stabletoken)]
    #[expected_failure(abort_code = ezero_amount)]
    fun mint_check_fails_zero_amount(account: &signer) acquires user {
        initialize(account); // initializes the user for the account
        deposit(account, 100); // deposits 100 tokens
        mint(account, 0); // mints zero amount - expected failure since minting amount can not be zero
    }

    #[test(account = @stabletoken)]
    fun liquidation_check(account: &signer) acquires User {
        let addr = signer::address_of(account); // Retrieves the address of the given account
        initiliaze(account); // Initializes the account
        deposit(account, 100); // Deposits 100 "tokens"
        let stabletoken_mut_ref = &mut borrow_global_mut<User>(addr).stabletoken.amount; // Creates a mutable reference for stabletoken balance of the user
        *stabletoken_mut_ref = 1000; //  Equates the stabletoken balance of the user to 1000
        liquidate(account); // Liquidates the user who has more stabletoken value then deposit value
        assert!(deposit_of(addr) == 0); // Chekcs if the liquidated user has zero deposit
    }

    #[test(account = @stabletoken)]
    #[expected_failure(abort_code = ENOT_LIQUIDATABLE)]
    fun liquidate_check_fails_not_liquidatable(account: &signer) acquires User {
        initialize(account); // Initiliazes the account
        deposit(account, 100); // Deposits 100 "tokens"
        mint(account, 10); // Mints 10 "stabletokens"
        liquidate(account); // Liquidates the user's stabletoken position - expected failure since the health factor is not below the precision
    }
}
