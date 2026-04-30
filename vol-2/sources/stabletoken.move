module stabletoken::stabletoken_engine {
    use std::signer;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::account;
    use aptos_framework::event;

    // Structs
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

    struct SignerCap has key { // Resource that holds the module's signer capability for its resource account
        cap: account::SignerCapability, // Signer capability used to authorize transfers from the resource account
        resource_addr: address // Address of the module's resource account holding deposited collateral
    }

    // Events
    #[event]
    // Indicates following struct is an event
    struct InitializeEvent has drop, store { // Event struct with drop and store abilities
        account: address // Account address of the transaction caller that should be emitted
    }

    #[event]
    // Indicates that following struct is an event
    struct DepositEvent has drop, store { // Event struct with drop and store abilities
        account: address, // Account address of the transaction caller that should be emitted
        amount: u64 // Deposit amount that should be emitted
    }

    #[event]
    // Indicates that following struct is an event
    struct MintEvent has drop, store { // Event struct with drop and store abilities
        account: address, // Account address of the transaction caller that should be emitted
        amount: u64 // Mint amount that should be emitted
    }

    #[event]
    // Indicates that following struct is an event
    struct BurnEvent has drop, store { // Event struct with drop and store abilities
        account: address, // Account address of the transaction caller that should be emitted
        amount: u64 // Burn amount that should be emitted
    }

    #[event]
    // Indicates that following struct is an event
    struct WithdrawEvent has drop, store { // Event struct with drop and store abilities
        account: address, // Account address of the transaction caller that should be emitted
        amount: u64 // Withdraw amount that should be emitted
    }

    #[event]
    // Indicates that following struct is an event
    struct LiquidateEvent has drop, store { // Event struct with drop and store abilities
        account: address, // Account address of the liquidated user that should be emitted
        deposit_seized: u64 // Deposit amount seized during liquidation that should be emitted
    }

    // Constants
    const PRICE: u64 = 1;
    const PRECISION: u64 = 100;

    // Error Codes
    const EACCOUNT_ALREADY_EXISTS: u64 = 0;
    const EACCOUNT_NOT_EXISTS: u64 = 1;
    const ENOT_ENOUGH_DEPOSIT: u64 = 2;
    const ENOT_ENOUGH_STABLETOKEN: u64 = 3;
    const EZERO_AMOUNT: u64 = 4;
    const ENOT_LIQUIDATABLE: u64 = 5;
    const EEXCEEDS_DEPOSIT_AMOUNT: u64 = 6;
    const EUNHEALTHY_USER: u64 = 7;
    const ENOT_ENOUGH_BALANCE: u64 = 8;

    // Functions

    // Public Entry Functions
    public entry fun initialize(account: &signer) {
        let addr = signer::address_of(account); // Retrieves the address of the given account
        assert!(!exists<User>(addr), EACCOUNT_ALREADY_EXISTS); // Checks if the user affiliated with the account already exists
        let empty_deposit = Deposit { amount: 0 }; // Creates an empty deposit struct
        let empty_stabletoken = Stabletoken { amount: 0 }; // Creates an empty stabletoken struct
        move_to(account, User { deposit: empty_deposit, stabletoken: empty_stabletoken }); // Records newly created `User` struct to the global storage
        event::emit(InitializeEvent { account: addr }); // Emits the Initalize event including the account address of the new `User` struct
    }

    public entry fun deposit(account: &signer, amount: u64) acquires User, SignerCap { // SignerCap acquired to use reource address
        assert!(amount > 0, EZERO_AMOUNT); // Asserts that the deposit amount is greater than zero
        let addr = signer::address_of(account); // Retrieves the account address of the transaction caller

        assert!(exists<User>(addr), EACCOUNT_NOT_EXISTS); // Checks if the user associated with the account already exists
        //TODO: Check if the user has a MOVE balance greater than or equal to the indicated `amount` using `assert!()`, `coin::balance<AptosCoin>`, if not return `ENOT_ENOUGH_BALANCE`

        let resource_addr = borrow_global<SignerCap>(@stabletoken).resource_addr; // Retrieves the resource address associoated with the module

        coin::transfer<AptosCoin>(account, resource_addr, amount); // Transfer coins from the user account to the module's resource account

        let deposit_amount = deposit_of(addr); // Retrieves the current deposit amount of the user
        let deposit_ref = &mut borrow_global_mut<User>(addr).deposit.amount; // Obtains a mutable reference to the user's deposit amount

        *deposit_ref = deposit_amount + amount; // Increments the user's deposit by the deposited amount
        event::emit(DepositEvent { account: addr, amount }); // Emits the Deposit event including the account address of the transaction caller and deposit amount
    }

    public entry fun mint(account: &signer, amount: u64) acquires User {
        assert!(amount > 0, EZERO_AMOUNT); // Asserts that the mint amount is greater than zero
        let addr = signer::address_of(account); // Retrieves the address of the given account
        assert!(exists<User>(addr), EACCOUNT_NOT_EXISTS); // Checks if the user associated with the account already exists

        let stabletoken_balance = stabletoken_of(addr); // Retrieves the current stabletoken balance of the user

        let stabletoken_mut_ref = &mut borrow_global_mut<User>(addr).stabletoken.amount; // Obtains a mutable reference to the user's stabletoken amount
        *stabletoken_mut_ref = stabletoken_balance + amount; // Increments the user's stabletoken balance by the mint amount

        let health_factor = get_health_factor(addr); // Retrieves the user's health factor after the mint
        assert!(health_factor >= PRECISION, EUNHEALTHY_USER); // Asserts that the user remains healthy after minting

        event::emit(MintEvent { account: addr, amount }); // Emits the Mint event including the account address of the transaction caller and mint amount
    }

    public entry fun liquidate(addr: address) acquires User {
        assert!(exists<User>(addr), ENOT_ENOUGH_STABLETOKEN); // Checks if the user exists in the global storage
        assert!(get_health_factor(addr) < PRECISION, ENOT_LIQUIDATABLE); // Asserts that the user's position is unhealthy and therefore liquidatable

        let deposit_amount = deposit_of(addr); // Retrieves the user's current deposit amount before seizing
        let deposit_ref = &mut borrow_global_mut<User>(addr).deposit.amount; // Obtains a mutable reference to the user's deposit amount

        *deposit_ref = 0; // Seizes the user's deposit by setting it to zero
        event::emit(LiquidateEvent { account: addr, deposit_seized: deposit_amount }); // Emits the Liquidate event including the account address of the liquidated user and seized deposit
    }

    public entry fun withdraw(account: &signer, amount: u64) acquires User, SignerCap { // SignerCap acquired to use the contract signer for the transfer
        assert!(amount > 0, EZERO_AMOUNT); // Asserts that the withdraw amount is greater than zero
        let addr = signer::address_of(account); // Retrieves the account address of the transaction caller

        let deposit_balance = deposit_of(addr); // Retrieves the current deposit amount of the user

        let deposit_ref = &mut borrow_global_mut<User>(addr).deposit.amount; // Obtains a mutable reference to the user's deposit amount
        *deposit_ref = deposit_balance - amount; // Decrements the user's deposit by the withdraw amount

        //TODO: Retrieve the SignerCap resource stored under the module's address and assign to signer_cap
        let contract_signer = account::create_signer_with_capability(&signer_cap.cap); // Creates a signer for the contract using the signer capability
        coin::transfer<AptosCoin>(&contract_signer, addr, amount); // Transfers the withdraw amount from the module's resource account to the user

        let health_factor = get_health_factor(addr); // Retrieves the user's health factor after the withdrawal

        assert!(health_factor >= PRECISION, EUNHEALTHY_USER); // Asserts that the user remains healthy after withdrawing
        event::emit(WithdrawEvent { account: addr, amount }); // Emits the WithdrawEvent including the account address of the transaction caller and withdraw amount
    }

    public entry fun burn(account: &signer, amount: u64) acquires User {
        assert!(amount > 0, EZERO_AMOUNT); // Checks if the burn amount is more than zero
        let addr = signer::address_of(account); // Retrieves the address of the given account
        let stabletoken_balance = stabletoken_of(addr); // Retrieves the stabletoken balance of the user
        assert!(stabletoken_balance >= amount, ENOT_ENOUGH_STABLETOKEN); // Checks if the user has more or same stabletoken balance than `amount`

        let stabletoken_ref = &mut borrow_global_mut<User>(addr).stabletoken.amount; // Creates a mutable reference for stabletoken balance of the user
        *stabletoken_ref = stabletoken_balance - amount; // Subrtracts `amount` from the user's old stabletoken balance and equates it to the current stabletoken balance of the user
        event::emit(BurnEvent { account: addr, amount }); // Emits the account address of the transaction caller and burn amount
    }

    // View Functions
    public fun stabletoken_of(addr: address): u64 acquires User {
        borrow_global<User>(addr).stabletoken.amount // Returns the stabletoken amount stored under the user
    }

    public fun deposit_of(addr: address): u64 acquires User {
        borrow_global<User>(addr).deposit.amount // Returns the deposit amount stored under the user
    }

    public fun get_price(): u64 {
        PRICE // Returns the fixed collateral price constant
    }

    public fun get_health_factor(addr: address): u64 acquires User {
        let stabletoken_balance = stabletoken_of(addr); // Retrieves the user stabletoken balance
        if (stabletoken_balance == 0) {
            return PRECISION // Returns PRECISION if the user have not minted any stabletoken
        };
        let deposit_balance = deposit_of(addr); // Retrieves the user deposit balance
        deposit_balance * PRICE * PRECISION / stabletoken_balance // Returns health factor
    }

    // Private Functions
    fun init_module(admin: &signer) { // Module initializer; runs once when the module is published under `admin`
        let (resource_signer, signer_cap) =
            account::create_resource_account(admin, b"seed"); // Creates a deterministic resource account owned by the module
        coin::register<AptosCoin>(&resource_signer); // Registers the resource account so it can hold AptosCoin
        let resource_addr = signer::address_of(&resource_signer); // Retrieves the address of the newly created resource account
        move_to(admin, SignerCap { cap: signer_cap, resource_addr }); // Stores the SignerCap under the admin so the module can later sign transfers
    }

    fun get_available_collateral(deposit_amount: u64, mint_amount: u64): u64 {
        deposit_amount - (mint_amount / get_price()) // Returns the deposit portion not backing existing minted stabletoken
    }

    #[test(account = @stabletoken)]
    fun initialization_check(account: &signer) {
        let addr = signer::address_of(account); // Retrieves the address of the given account
        initialize(account); // Initializes the user for the account
        assert!(exists<User>(addr), 0); // Asserts that the `User` resource was created under the account
    }

    #[test(account = @stabletoken)]
    #[expected_failure(abort_code = EACCOUNT_ALREADY_EXISTS)]
    fun initialize_fail(account: &signer) {
        initialize(account); // Initialized once
        initialize(account); // Initialized twice - expected error
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    // Marks as a test; injects signers: `account` at address 0x123 (simulated user), `stabletoken` at the module's named address (module admin), `framework` at @aptos_framework (privileged authority for coin initialization)
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

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = EZERO_AMOUNT)]
    // Test is expected to fail with `EZERO_AMOUNT`
    fun deposit_fail_zero_amount(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let deposit_amount = 0; // Sets the deposit amount to zero to trigger the failure

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount); // Sets up test coins and returns burn and mint capabilities

        register_account(stabletoken); // Registers the stabletoken account
        init_module(stabletoken); // Initializes the module, creating a resource account for the module
        initialize(account); // Initializes the user

        deposit(account, deposit_amount); // Attempts to deposit zero - expected failure

        clean_test_caps(burn_cap, mint_cap); // Cleans up the test capabilities
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun multiple_deposits_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let deposit_amount = 10; // Single deposit unit used twice in this test
        let addr = signer::address_of(account); // Retrieves the account address of the transaction caller

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, 2
            * deposit_amount); // Sets up test coins funded for two deposits

        register_account(stabletoken); // Registers the stabletoken account
        init_module(stabletoken); // Initializes the module
        initialize(account); // Initializes the user

        let before_balance = coin::balance<AptosCoin>(addr); // Retrieves the MOVE balance before any deposit

        deposit(account, deposit_amount); // First deposit
        deposit(account, deposit_amount); // Second deposit

        let after_balance = coin::balance<AptosCoin>(addr); // Retrieves the MOVE balance after both deposits

        assert!(deposit_of(addr) == 2 * deposit_amount); // Asserts that the recorded deposit equals the sum of both deposits
        assert!(
            before_balance - after_balance >= 2 * deposit_amount // Asserts that the on-chain balance decreased by at least the combined deposit
        );
        clean_test_caps(burn_cap, mint_cap); // Cleans up the test capabilities
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = EACCOUNT_NOT_EXISTS)]
    // Test is expected to fail with `EACCOUNT_NOT_EXISTS`
    fun deposit_fail_not_init(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let deposit_amount = 10; // Sets the deposit amount used in the test

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount); // Sets up test coins and returns burn and mint capabilities
        register_account(stabletoken); // Registers the stabletoken account
        init_module(stabletoken); // Initializes the module - note: user is intentionally NOT initialized

        deposit(account, deposit_amount); // Attempts to deposit before initializing the user - expected failure

        clean_test_caps(burn_cap, mint_cap); // Cleans up the test capabilities
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun mint_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account); // Retrieves the account address of the transaction caller
        let mint_amount: u64 = 10; // Sets the mint amount used in the test
        let deposit_amount: u64 = 100; // Sets the deposit amount used in the test

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount); // Sets up test coins and returns burn and mint capabilities
        register_account(stabletoken); // Registers the stabletoken account
        init_module(stabletoken); // Initializes the module

        initialize(account); // Initializes the user
        deposit(account, deposit_amount); // Deposits collateral
        mint(account, mint_amount); // Mints stabletoken against the deposited collateral

        assert!(stabletoken_of(addr) == mint_amount); // Asserts that the recorded stabletoken balance equals the minted amount

        clean_test_caps(burn_cap, mint_cap); // Cleans up the test capabilities
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun mint_exact_max_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account); // Retrieves the account address of the transaction caller
        let mint_amount: u64 = 100; // Sets the mint amount equal to the maximum allowed by the deposit
        let deposit_amount: u64 = 100; // Sets the deposit amount that backs the maximum mint

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount); // Sets up test coins and returns burn and mint capabilities
        register_account(stabletoken); // Registers the stabletoken account
        init_module(stabletoken); // Initializes the module

        initialize(account); // Initializes the user
        deposit(account, deposit_amount); // Deposits collateral

        mint(account, mint_amount); // Mints exactly the maximum allowed amount

        assert!(stabletoken_of(addr) == mint_amount); // Asserts that the boundary mint succeeded

        clean_test_caps(burn_cap, mint_cap); // Cleans up the test capabilities
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun multiple_mints_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account); // Retrieves the account address of the transaction caller
        let mint_amount: u64 = 10; // Single mint unit used twice in this test
        let deposit_amount: u64 = 100; // Sets the deposit amount that backs both mints

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount); // Sets up test coins and returns burn and mint capabilities
        register_account(stabletoken); // Registers the stabletoken account
        init_module(stabletoken); // Initializes the module

        initialize(account); // Initializes the user
        deposit(account, deposit_amount); // Deposits collateral

        mint(account, mint_amount); // First mint
        mint(account, mint_amount); // Second mint

        assert!(stabletoken_of(addr) == 2 * mint_amount); // Asserts that the recorded stabletoken equals the sum of both mints

        clean_test_caps(burn_cap, mint_cap); // Cleans up the test capabilities
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = EZERO_AMOUNT)]
    // Test is expected to fail with `EZERO_AMOUNT`
    fun mint_fail_zero_amount(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User {
        let mint_amount: u64 = 0; // Sets the mint amount to zero to trigger the failure

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, 100); // Sets up test coins and returns burn and mint capabilities
        register_account(stabletoken); // Registers the stabletoken account

        initialize(account); // Initializes the user
        mint(account, mint_amount); // Attempts to mint zero - expected failure

        clean_test_caps(burn_cap, mint_cap); // Cleans up the test capabilities
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = EACCOUNT_NOT_EXISTS)]
    // Test is expected to fail with `EACCOUNT_NOT_EXISTS`
    fun mint_fail_not_initialized(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User {
        let mint_amount: u64 = 10; // Sets the mint amount used in the test

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, 100); // Sets up test coins and returns burn and mint capabilities
        register_account(stabletoken); // Registers the stabletoken account

        mint(account, mint_amount); // Attempts to mint before initializing the user - expected failure

        clean_test_caps(burn_cap, mint_cap); // Cleans up the test capabilities
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = EUNHEALTHY_USER)]
    // Test is expected to fail with `EUNHEALTHY_USER`
    fun mint_fail_not_enough_deposit(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let mint_amount: u64 = 100; // Sets a mint amount that exceeds what the deposit can back
        let deposit_amount: u64 = 10; // Sets a small deposit insufficient to back the mint

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount); // Sets up test coins and returns burn and mint capabilities
        register_account(stabletoken); // Registers the stabletoken account
        init_module(stabletoken); // Initializes the module

        initialize(account); // Initializes the user
        deposit(account, deposit_amount); // Deposits the small amount of collateral
        mint(account, mint_amount); // Attempts to mint more than the deposit can back - expected failure

        clean_test_caps(burn_cap, mint_cap); // Cleans up the test capabilities
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = EUNHEALTHY_USER)]
    // Test is expected to fail with `EUNHEALTHY_USER`
    fun mint_fail_overcollateralization(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let mint_amount: u64 = 100; // Sets the mint amount used in the test
        let deposit_amount: u64 = 100; // Sets the deposit amount used in the test

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount); // Sets up test coins and returns burn and mint capabilities
        register_account(stabletoken); // Registers the stabletoken account
        init_module(stabletoken); // Initializes the module

        initialize(account); // Initializes the user
        deposit(account, deposit_amount); // Deposits collateral
        mint(account, mint_amount); // First mint at the maximum boundary
        mint(account, mint_amount); // Second mint pushes the user past the healthy threshold - expected failure

        clean_test_caps(burn_cap, mint_cap); // Cleans up the test capabilities
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun health_factor_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account); // Retrieves the account address of the transaction caller
        let deposit_amount = 1000; // Sets the deposit amount used in the test
        let mint_amount = 100; // Sets the mint amount used in the test

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount); // Sets up test coins and returns burn and mint capabilities
        register_account(stabletoken); // Registers the stabletoken account
        init_module(stabletoken); // Initializes the module

        initialize(account); // Initializes the user
        deposit(account, deposit_amount); // Deposits collateral
        mint(account, mint_amount); // Mints stabletoken against the deposited collateral

        assert!(get_health_factor(addr) == 1000); // Asserts that the health factor matches the expected value (deposit * PRICE * PRECISION / mint)

        clean_test_caps(burn_cap, mint_cap); // Cleans up the test capabilities
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun liquidation_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account); // Retrieves the address of the given account
        let deposit_amount = 100; // Sets the deposit amount used in the test
        let stabletoken_amount = 1000; // Sets a high stabletoken balance to force the user underwater

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount); // Sets up test coins and returns burn and mint capabilities
        register_account(stabletoken); // Registers the stabletoken account

        init_module(stabletoken); // Initializes the module
        initialize(account); // Initializes the user

        deposit(account, deposit_amount); // Deposits 100 collateral
        set_coin_amount(addr, stabletoken_amount); // Forces the user's stabletoken balance directly to make them liquidatable
        liquidate(addr); // Liquidates the user

        assert!(deposit_of(addr) == 0); // Asserts that the liquidated user has zero deposit

        clean_test_caps(burn_cap, mint_cap); // Cleans up the test capabilities
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = ENOT_LIQUIDATABLE)]
    // Test is expected to fail with `ENOT_LIQUIDATABLE`
    fun liquidation_fail(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account); // Retrieves the address of the given account
        let deposit_amount = 1000; // Sets a large deposit so the user remains healthy
        let stabletoken_amount = 100; // Sets a small stabletoken balance so the user is not liquidatable

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount); // Sets up test coins and returns burn and mint capabilities
        register_account(stabletoken); // Registers the stabletoken account
        init_module(stabletoken); // Initializes the module

        initialize(account); // Initializes the user
        deposit(account, deposit_amount); // Deposits collateral
        set_coin_amount(addr, stabletoken_amount); // Sets the user's stabletoken balance directly
        liquidate(addr); // Attempts to liquidate a healthy user - expected failure

        clean_test_caps(burn_cap, mint_cap); // Cleans up the test capabilities
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun withdrawal_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account); // Retrieves the address of the given account
        let deposit_amount = 1000; // Sets the deposit amount used in the test
        let withdrawal_amount = 100; // Sets the withdrawal amount used in the test

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount); // Sets up test coins and returns burn and mint capabilities
        register_account(stabletoken); // Registers the stabletoken account

        init_module(stabletoken); // Initializes the module
        initialize(account); // Intializes the account

        let before_balance = coin::balance<AptosCoin>(addr); // Retrieves the MOVE balance before deposit and withdrawal

        deposit(account, deposit_amount); // Deposits 1000 "tokens"
        withdraw(account, withdrawal_amount); // Withdraws 100 "tokens"

        let after_balance = coin::balance<AptosCoin>(addr); // Retrieves the MOVE balance after deposit and withdrawal

        assert!(
            deposit_of(addr) == deposit_amount - withdrawal_amount // Checks if the recorded deposit decreased by the withdrawn amount
        );

        assert!(
            after_balance == before_balance - deposit_amount + withdrawal_amount // Checks the on-chain balance reflects deposit minus withdraw
        );

        clean_test_caps(burn_cap, mint_cap); // Cleans up the test capabilities
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun withdraw_max_allowed_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account); // Retrieves the address of the given account
        let deposit_amount = 1000; // Sets the deposit amount used in the test
        let mint_amount = 100; // Sets the mint amount used in the test
        let withdrawal_amount = get_available_collateral(deposit_amount, mint_amount); // Computes the maximum withdrawable amount given the active mint

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount); // Sets up test coins and returns burn and mint capabilities
        register_account(stabletoken); // Registers the stabletoken account

        init_module(stabletoken); // Initializes the module
        initialize(account); // Initializes the user
        deposit(account, deposit_amount); // Deposits collateral
        mint(account, mint_amount); // Mints stabletoken against the deposited collateral

        withdraw(account, withdrawal_amount); // Withdraws exactly the maximum allowed amount
        assert!(
            deposit_of(addr) == deposit_amount - withdrawal_amount // Asserts the deposit decreased by the maximum withdrawal
        );

        clean_test_caps(burn_cap, mint_cap); // Cleans up the test capabilities
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun multiple_withdrawals_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account); // Retrieves the address of the given account
        let deposit_amount = 1000; // Sets the deposit amount used in the test
        let withdrawal_amount = 100; // Single withdrawal unit used twice in this test

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount); // Sets up test coins and returns burn and mint capabilities
        register_account(stabletoken); // Registers the stabletoken account

        init_module(stabletoken); // Initializes the module
        initialize(account); // Initializes the user
        deposit(account, deposit_amount); // Deposits collateral

        withdraw(account, withdrawal_amount); // First withdrawal
        withdraw(account, withdrawal_amount); // Second withdrawal

        assert!(
            deposit_of(addr) == deposit_amount - 2 * withdrawal_amount // Asserts the deposit decreased by both withdrawals
        );

        clean_test_caps(burn_cap, mint_cap); // Cleans up the test capabilities
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = EZERO_AMOUNT)]
    // Test is expected to fail with `EZERO_AMOUNT`
    fun withdrawal_fail_zero_amount(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let deposit_amount = 1000; // Sets the deposit amount used in the test

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount); // Sets up test coins and returns burn and mint capabilities
        register_account(stabletoken); // Registers the stabletoken account

        init_module(stabletoken); // Initializes the module
        initialize(account); // Initializes the user
        deposit(account, deposit_amount); // Deposits collateral

        withdraw(account, 0); // Attempts to withdraw zero - expected failure

        clean_test_caps(burn_cap, mint_cap); // Cleans up the test capabilities
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = EUNHEALTHY_USER)]
    // Test is expected to fail with `EUNHEALTHY_USER`
    fun withdrawal_fail(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let deposit_amount = 1000; // Sets the deposit amount used in the test
        let mint_amount = 100; // Sets the mint amount that pins required collateral

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount); // Sets up test coins and returns burn and mint capabilities
        register_account(stabletoken); // Registers the stabletoken account

        init_module(stabletoken); // Initializes the module
        initialize(account); // Initializes the user
        deposit(account, deposit_amount); // Deposits collateral
        mint(account, mint_amount); // Mints stabletoken locking part of the collateral

        withdraw(account, deposit_amount); // Withdraws the entire deposit while a mint is outstanding - expected failure

        clean_test_caps(burn_cap, mint_cap); // Cleans up the test capabilities
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun burn_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account); // Retrieves the address of the given account
        let deposit_amount = 1000; // Sets the deposit amount used in the test
        let mint_amount = 100; // Sets the mint amount used in the test
        let burn_amount = 100; // Sets the burn amount used in the test

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount); // Sets up test coins and returns burn and mint capabilities
        register_account(stabletoken); // Registers the stabletoken account
        init_module(stabletoken); // Initializes the module

        initialize(account); // Initializes the user
        deposit(account, deposit_amount); // Deposits collateral
        mint(account, mint_amount); // Mints stabletoken

        let stabletoken_balance = stabletoken_of(addr); // Retrieves the stabletoken balance before burning

        burn(account, burn_amount); // Burns 100 stabletoken

        assert!(
            stabletoken_of(addr) == stabletoken_balance - burn_amount // Asserts the stabletoken balance decreased by the burn amount
        );

        clean_test_caps(burn_cap, mint_cap); // Cleans up the test capabilities
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = EZERO_AMOUNT)]
    // Test is expected to fail with `EZERO_AMOUNT`
    fun burn_fail_zero_amount(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let deposit_amount = 1000; // Sets the deposit amount used in the test
        let mint_amount = 100; // Sets the mint amount used in the test
        let burn_amount = 0; // Sets the burn amount to zero to trigger the failure

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount); // Sets up test coins and returns burn and mint capabilities
        register_account(stabletoken); // Registers the stabletoken account
        init_module(stabletoken); // Initializes the module

        initialize(account); // Initializes the user
        deposit(account, deposit_amount); // Deposits collateral
        mint(account, mint_amount); // Mints stabletoken

        burn(account, burn_amount); // Attempts to burn zero - expected failure

        clean_test_caps(burn_cap, mint_cap); // Cleans up the test capabilities
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = ENOT_ENOUGH_STABLETOKEN)]
    // Test is expected to fail with `ENOT_ENOUGH_STABLETOKEN`
    fun burn_fail_not_enough_mint(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let deposit_amount = 1000; // Sets the deposit amount used in the test
        let mint_amount = 100; // Sets the mint amount used in the test
        let burn_amount = 200; // Sets a burn amount larger than the user's stabletoken balance

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount); // Sets up test coins and returns burn and mint capabilities
        register_account(stabletoken); // Registers the stabletoken account
        init_module(stabletoken); // Initializes the module

        initialize(account); // Initializes the user
        deposit(account, deposit_amount); // Deposits collateral
        mint(account, mint_amount); // Mints stabletoken

        burn(account, burn_amount); // Attempts to burn more than the user has minted - expected failure

        clean_test_caps(burn_cap, mint_cap); // Cleans up the test capabilities
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = ENOT_ENOUGH_BALANCE)]
    // Test is expected to fail with `ENOT_ENOUGH_BALANCE`
    fun deposit_fail_insufficient_balance(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let aptos_balance = 50; // Sets the on-chain MOVE balance the user starts with
        let deposit_amount = 100; // Sets a deposit amount larger than the user's balance

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, aptos_balance); // Sets up test coins funded with the smaller balance
        register_account(stabletoken); // Registers the stabletoken account
        init_module(stabletoken); // Initializes the module
        initialize(account); // Initializes the user

        deposit(account, deposit_amount); // Attempts to deposit more than the user holds - expected failure

        clean_test_caps(burn_cap, mint_cap); // Cleans up the test capabilities
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun health_factor_exact_boundary_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account); // Retrieves the address of the given account
        let deposit_amount = 100; // Sets the deposit amount equal to the mint amount
        let mint_amount = 100; // Sets the mint amount equal to the deposit amount

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount); // Sets up test coins and returns burn and mint capabilities
        register_account(stabletoken); // Registers the stabletoken account
        init_module(stabletoken); // Initializes the module

        initialize(account); // Initializes the user
        deposit(account, deposit_amount); // Deposits collateral
        mint(account, mint_amount); // Mints at the exact boundary

        assert!(get_health_factor(addr) == 100); // Asserts the health factor equals PRECISION at the boundary

        clean_test_caps(burn_cap, mint_cap); // Cleans up the test capabilities
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = ENOT_LIQUIDATABLE)]
    // Test is expected to fail with `ENOT_LIQUIDATABLE`
    fun liquidation_fail_exact_boundary(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account); // Retrieves the address of the given account
        let deposit_amount = 100; // Sets the deposit amount equal to the stabletoken amount
        let stabletoken_amount = 100; // Sets the stabletoken amount equal to the deposit amount

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount); // Sets up test coins and returns burn and mint capabilities
        register_account(stabletoken); // Registers the stabletoken account
        init_module(stabletoken); // Initializes the module

        initialize(account); // Initializes the user
        deposit(account, deposit_amount); // Deposits collateral
        set_coin_amount(addr, stabletoken_amount); // Sets stabletoken balance directly to the boundary

        liquidate(addr); // Attempts to liquidate at the exact healthy boundary - expected failure

        clean_test_caps(burn_cap, mint_cap); // Cleans up the test capabilities
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun liquidation_coin_unchanged_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account); // Retrieves the address of the given account
        let deposit_amount = 100; // Sets the deposit amount used in the test
        let stabletoken_amount = 1000; // Sets a high stabletoken balance to force the user underwater

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount); // Sets up test coins and returns burn and mint capabilities
        register_account(stabletoken); // Registers the stabletoken account
        init_module(stabletoken); // Initializes the module

        initialize(account); // Initializes the user
        deposit(account, deposit_amount); // Deposits collateral
        set_coin_amount(addr, stabletoken_amount); // Forces stabletoken balance directly to make user liquidatable

        let coin_before = stabletoken_of(addr); // Records the stabletoken balance before liquidation
        liquidate(addr); // Liquidates the user

        assert!(deposit_of(addr) == 0); // Asserts the deposit was seized
        assert!(stabletoken_of(addr) == coin_before); // Asserts the user's stabletoken balance was not affected by liquidation

        clean_test_caps(burn_cap, mint_cap); // Cleans up the test capabilities
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(arithmetic_error, location = Self)]
    // Test is expected to fail with an arithmetic underflow when withdrawing from a zero deposit
    fun withdraw_after_liquidation_fail(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account); // Retrieves the address of the given account
        let deposit_amount = 100; // Sets the initial deposit before liquidation
        let stabletoken_amount = 1000; // Sets a high stabletoken balance to force the user underwater

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount); // Sets up test coins and returns burn and mint capabilities
        register_account(stabletoken); // Registers the stabletoken account
        init_module(stabletoken); // Initializes the module

        initialize(account); // Initializes the user
        deposit(account, deposit_amount); // Deposits collateral
        set_coin_amount(addr, stabletoken_amount); // Forces stabletoken balance directly to make user liquidatable

        liquidate(addr); // Liquidates the user, zeroing out the deposit

        withdraw(account, 1); // Attempts to withdraw from a zero deposit - expected arithmetic underflow

        clean_test_caps(burn_cap, mint_cap); // Cleans up the test capabilities
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun burn_after_liquidation_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account); // Retrieves the address of the given account
        let deposit_amount = 100; // Sets the initial deposit before liquidation
        let stabletoken_amount = 1000; // Sets a high stabletoken balance to force the user underwater

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount); // Sets up test coins and returns burn and mint capabilities
        register_account(stabletoken); // Registers the stabletoken account
        init_module(stabletoken); // Initializes the module

        initialize(account); // Initializes the user
        deposit(account, deposit_amount); // Deposits collateral
        set_coin_amount(addr, stabletoken_amount); // Forces stabletoken balance directly to make user liquidatable

        liquidate(addr); // Liquidates the user

        assert!(deposit_of(addr) == 0); // Asserts the deposit was seized
        assert!(stabletoken_of(addr) == stabletoken_amount); // Asserts the stabletoken balance is preserved through liquidation

        burn(account, 500); // Burns part of the remaining stabletoken balance

        assert!(stabletoken_of(addr) == 500); // Asserts the stabletoken balance decreased by the burned amount

        clean_test_caps(burn_cap, mint_cap); // Cleans up the test capabilities
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun deposit_after_liquidation_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account); // Retrieves the address of the given account
        let initial_deposit = 100; // Sets the initial deposit before liquidation
        let stabletoken_amount = 1000; // Sets a high stabletoken balance to force the user underwater
        let redeposit_amount = 500; // Sets the deposit amount used after liquidation

        let (burn_cap, mint_cap) =
            setup_test_caps(account, framework, initial_deposit + redeposit_amount); // Sets up test coins funded for both deposits
        register_account(stabletoken); // Registers the stabletoken account
        init_module(stabletoken); // Initializes the module

        initialize(account); // Initializes the user
        deposit(account, initial_deposit); // Deposits initial collateral
        set_coin_amount(addr, stabletoken_amount); // Forces stabletoken balance directly to make user liquidatable

        liquidate(addr); // Liquidates the user
        assert!(deposit_of(addr) == 0); // Asserts the deposit was seized

        deposit(account, redeposit_amount); // Re-deposits collateral after liquidation
        assert!(deposit_of(addr) == redeposit_amount); // Asserts the new deposit was recorded

        clean_test_caps(burn_cap, mint_cap); // Cleans up the test capabilities
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun multiple_burns_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account); // Retrieves the address of the given account
        let deposit_amount = 1000; // Sets the deposit amount used in the test
        let mint_amount = 500; // Sets the mint amount used in the test

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount); // Sets up test coins and returns burn and mint capabilities
        register_account(stabletoken); // Registers the stabletoken account
        init_module(stabletoken); // Initializes the module

        initialize(account); // Initializes the user
        deposit(account, deposit_amount); // Deposits collateral
        mint(account, mint_amount); // Mints stabletoken

        burn(account, 100); // First burn
        assert!(stabletoken_of(addr) == 400); // Asserts balance decreased to 400

        burn(account, 150); // Second burn
        assert!(stabletoken_of(addr) == 250); // Asserts balance decreased to 250

        burn(account, 250); // Third burn drains the remaining balance
        assert!(stabletoken_of(addr) == 0); // Asserts the stabletoken balance is now zero

        clean_test_caps(burn_cap, mint_cap); // Cleans up the test capabilities
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun burn_exact_full_amount_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account); // Retrieves the address of the given account
        let deposit_amount = 1000; // Sets the deposit amount used in the test
        let mint_amount = 500; // Sets the mint amount used in the test

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount); // Sets up test coins and returns burn and mint capabilities
        register_account(stabletoken); // Registers the stabletoken account
        init_module(stabletoken); // Initializes the module

        initialize(account); // Initializes the user
        deposit(account, deposit_amount); // Deposits collateral
        mint(account, mint_amount); // Mints stabletoken

        burn(account, mint_amount); // Burns the full minted amount in one call

        assert!(stabletoken_of(addr) == 0); // Asserts the stabletoken balance is now zero

        clean_test_caps(burn_cap, mint_cap); // Cleans up the test capabilities
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun full_lifecycle_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account); // Retrieves the address of the given account
        let deposit_amount = 1000; // Sets the deposit amount used in the lifecycle

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount); // Sets up test coins and returns burn and mint capabilities
        register_account(stabletoken); // Registers the stabletoken account
        init_module(stabletoken); // Initializes the module

        initialize(account); // Initializes the user

        deposit(account, deposit_amount); // Deposits collateral
        assert!(deposit_of(addr) == 1000); // Asserts the deposit was recorded

        mint(account, 500); // Mints stabletoken
        assert!(stabletoken_of(addr) == 500); // Asserts the stabletoken balance equals the minted amount

        burn(account, 200); // Burns part of the minted stabletoken
        assert!(stabletoken_of(addr) == 300); // Asserts the stabletoken balance decreased by the burn amount

        withdraw(account, 700); // Withdraws collateral while a mint remains outstanding
        assert!(deposit_of(addr) == 300); // Asserts the deposit decreased by the withdrawn amount

        clean_test_caps(burn_cap, mint_cap); // Cleans up the test capabilities
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun mint_after_partial_burn_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account); // Retrieves the address of the given account
        let deposit_amount = 1000; // Sets the deposit amount used in the test

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount); // Sets up test coins and returns burn and mint capabilities
        register_account(stabletoken); // Registers the stabletoken account
        init_module(stabletoken); // Initializes the module

        initialize(account); // Initializes the user
        deposit(account, deposit_amount); // Deposits collateral

        mint(account, 1000); // Mints up to the maximum
        assert!(stabletoken_of(addr) == 1000); // Asserts the stabletoken balance equals the mint

        burn(account, 500); // Burns half of the minted amount
        assert!(stabletoken_of(addr) == 500); // Asserts the stabletoken balance decreased to 500

        mint(account, 300); // Mints again now that headroom is freed
        assert!(stabletoken_of(addr) == 800); // Asserts the new stabletoken balance reflects the additional mint

        clean_test_caps(burn_cap, mint_cap); // Cleans up the test capabilities
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun withdraw_with_active_mint_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account); // Retrieves the address of the given account
        let deposit_amount = 1000; // Sets the deposit amount used in the test
        let mint_amount = 200; // Sets the mint amount used in the test

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount); // Sets up test coins and returns burn and mint capabilities
        register_account(stabletoken); // Registers the stabletoken account
        init_module(stabletoken); // Initializes the module

        initialize(account); // Initializes the user
        deposit(account, deposit_amount); // Deposits collateral
        mint(account, mint_amount); // Mints stabletoken

        withdraw(account, 800); // Withdraws to leave the user exactly at the healthy boundary

        assert!(deposit_of(addr) == 200); // Asserts the deposit decreased to 200
        assert!(stabletoken_of(addr) == 200); // Asserts the stabletoken balance is unchanged
        assert!(get_health_factor(addr) == 100); // Asserts the user is exactly at the PRECISION boundary

        clean_test_caps(burn_cap, mint_cap); // Cleans up the test capabilities
    }

    // Test Helpers
    #[test_only]
    // Indicates that the following only for test
    fun setup_test_caps(
        account: &signer, framework: &signer, amount: u64
    ): (coin::BurnCapability<AptosCoin>, coin::MintCapability<AptosCoin>) {
        let addr = signer::address_of(account); // Retrieves the account address associoated with the transaction caller
        let (burn_cap, mint_cap) =
            aptos_framework::aptos_coin::initialize_for_test(framework); // Initialize burn and mint capabilites using `framework`
        register_account(account); // Registers the account so it can hold AptosCoin
        coin::deposit(addr, coin::mint<AptosCoin>(amount, &mint_cap)); // Deposit indicated amount of test coins to the signer
        (burn_cap, mint_cap) // Returns burn and mint capabilites
    }

    #[test_only]
    // Indicates that the following only for test
    fun clean_test_caps(
        burn_cap: coin::BurnCapability<AptosCoin>,
        mint_cap: coin::MintCapability<AptosCoin>
    ) {
        coin::destroy_burn_cap(burn_cap); // Destroys the burn capability
        coin::destroy_mint_cap(mint_cap); // Destrys the mint capability
    }

    #[test_only]
    // Indicates that the following only for test
    fun register_account(account: &signer) { // Helper that creates a fresh account and registers it for AptosCoin
        let addr = signer::address_of(account); // Retrieves the address of the given account
        account::create_account_for_test(addr); // Creates the on-chain account record for testing
        coin::register<AptosCoin>(account); // Registers the account so it can hold AptosCoin

    }

    #[test_only]
    // Indicates that the following only for test
    fun set_coin_amount(addr: address, amount: u64) acquires User { // Helper that overrides the user's stabletoken balance directly for testing edge cases
        let stabletoken_ref = &mut borrow_global_mut<User>(addr).stabletoken.amount; // Obtains a mutable reference to the user's stabletoken amount
        *stabletoken_ref = amount; // Forces the stabletoken balance to the indicated value
    }
}
