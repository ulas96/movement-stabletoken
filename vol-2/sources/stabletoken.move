module stabletoken::stabletoken_engine_sol {
    use std::signer;
    use aptos_framework::event;

    // Error Codes

    const EACCOUNT_ALREADY_EXISTS: u64 = 0;
    const EACCOUNT_NOT_EXISTS: u64 = 1;
    const ENOT_ENOUGH_DEPOSIT: u64 = 2;
    const ENOT_ENOUGH_STABLETOKEN: u64 = 3;
    const EZERO_AMOUNT: u64 = 4;
    const ENOT_LIQUIDATABLE: u64 = 5;
    const EEXCEEDS_DEPOSIT_AMOUNT: u64 = 6;

    // Constants
    const PRICE: u64 = 1;
    const PRECISION: u64 = 100;

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
        amount: u64 // Liquidation amount that should be emitted
    }

    public entry fun initialize(account: &signer) {
        let addr = signer::address_of(account);
        assert!(!exists<User>(addr), EACCOUNT_ALREADY_EXISTS);
        let empty_deposit = Deposit { amount: 0 };
        let empty_stabletoken = Stabletoken { amount: 0 };
        let new_user = User { deposit: empty_deposit, stabletoken: empty_stabletoken };
        move_to(account, new_user);
        event::emit(InitializeEvent { account: addr }); // Emits the Initalize event including the account address of the new `User` struct
    }

    public entry fun deposit(account: &signer, amount: u64) acquires User {
        let addr = signer::address_of(account);
        assert!(exists<User>(addr), EACCOUNT_NOT_EXISTS);
        let deposit_ref = deposit_of(addr);
        let deposit_mut = &mut borrow_global_mut<User>(addr).deposit.amount;
        *deposit_mut = deposit_ref + amount;
        event::emit(DepositEvent { account: addr, amount }); // Emits DepositEvent including the account address of the transaction caller and deposit amount
    }

    public entry fun mint(account: &signer, amount: u64) acquires User {
        assert!(amount > 0, EZERO_AMOUNT);
        let addr = signer::address_of(account);
        assert!(exists<User>(addr), EACCOUNT_NOT_EXISTS);

        let deposit_balance = deposit_of(addr);
        let stabletoken_balance = stabletoken_of(addr);
        let mint_avl = deposit_balance * PRICE - stabletoken_balance;

        assert!(mint_avl >= amount, ENOT_ENOUGH_DEPOSIT);

        let stabletoken_mut_ref = &mut borrow_global_mut<User>(addr).stabletoken.amount;
        *stabletoken_mut_ref = stabletoken_balance + amount;
        event::emit(MintEvent { account: addr, amount }); // Emits the account address of the transaction caller and mint amount
    }

    public entry fun liquidate(account: &signer) acquires User {
        assert!(exists<User>(addr), ENOT_ENOUGH_MINT);
        assert!(get_health_factor(addr) < PRECISION, ENOT_LIQUIDATABLE);
        let deposit_amount = borrow_global<User>(addr).deposit.amount;
        let deposit_ref = &mut borrow_global_mut<User>(addr).deposit.amount;
        *deposit_ref = 0;
        event::emit(LiquidateEvent { account: addr, deposit_seized: deposit_amount }); // Emits the account addres of the liquidated user and liquidation amount

    }

    public entry fun withdraw(account: &signer, amount: u64) acquires User {
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

    public entry fun burn(account: &signer, amount: u64) acquires User {
        assert!(amount > 0, EZERO_AMOUNT);
        let addr = signer::address_of(account);
        let coin_balance = coin_of(addr);
        assert!(coin_balance >= amount, ENOT_ENOUGH_MINT);

        let coin_ref = &mut borrow_global_mut<User>(addr).stabletoken.amount;
        *coin_ref = coin_balance - amount;
        event::emit(BurnEvent { account: addr, amount }); // Emits the account address of the transaction caller and burn amount
    }

    // Public View Functions

    public fun deposit_of(addr: address): u64 acquires User {
        borrow_global<User>(addr).deposit.amount
    }

    public fun stabletoken_of(addr: address): u64 acquires User {
        borrow_global<User>(addr).stabletoken.amount
    }

    public fun get_health_factor(addr: address): u64 acquires User {
        assert!(stabletoken_of(addr) > 0);
        let deposit_balance = deposit_of(addr);
        let stabletoken_balance = stabletoken_of(addr);
        deposit_balance * PRICE * PRECISION / stabletoken_balance
    }

    #[test(account = @stabletoken)]
    fun initialization_check(account: &signer) acquires User {
        initialize(account);
        let addr = signer::address_of(account);
        let user = borrow_global<User>(addr);
        assert!(user.deposit.amount == 0);
        assert!(user.stabletoken.amount == 0);
    }

    #[test(account = @stabletoken)]
    #[expected_failure(abort_code = EACCOUNT_ALREADY_EXISTS)]
    fun initialize_check_fails_account_already_exists(account: &signer) {
        initialize(account);
        initialize(account);
    }

    #[test(account = @stabletoken)]
    fun deposit_check(account: &signer) acquires User {
        initialize(account);
        deposit(account, 100);
        let addr = signer::address_of(account);
        let user = borrow_global<User>(addr);
        assert!(user.deposit.amount == 100);
    }

    #[test(account = @stabletoken)]
    #[expected_failure(abort_code = EACCOUNT_NOT_EXISTS)]
    fun deposit_check_fails_account_not_exists(account: &signer) acquires User {
        deposit(account, 100);
    }

    #[test(account = @stabletoken)]
    fun deposit_of_check(account: &signer) acquires User {
        let addr = signer::address_of(account);
        initialize(account);
        assert!(deposit_of(addr) == 0)
    }

    #[test(account = @stabletoken)]
    fun stabletoken_of_check(account: &signer) acquires User {
        let addr = signer::address_of(account);
        initialize(account);
        assert!(stabletoken_of(addr) == 0)
    }

    #[test(account = @stabletoken)]
    fun mint_check(account: &signer) acquires User {
        let addr = signer::address_of(account);
        let mint_amount: u64 = 10;
        let deposit_amount: u64 = 100;

        initialize(account);
        deposit(account, deposit_amount);
        mint(account, mint_amount);

        assert!(stabletoken_of(addr) == mint_amount);
    }

    #[test(account = @stabletoken)]
    #[expected_failure(abort_code = ENOT_ENOUGH_DEPOSIT)]
    fun mint_check_fails_not_enough_deposit(account: &signer) acquires User {
        initialize(account);
        deposit(account, 10);
        mint(account, 20);
    }

    #[test(account = @stabletoken)]
    #[expected_failure(abort_code = EACCOUNT_NOT_EXISTS)]
    fun mint_check_fails_account_not_exists(account: &signer) acquires User {
        mint(account, 10);
    }

    #[test(account = @stabletoken)]
    #[expected_failure(abort_code = EZERO_AMOUNT)]
    fun mint_check_fails_zero_amount(account: &signer) acquires User {
        initialize(account);
        deposit(account, 100);
        mint(account, 0);
    }

    fun liquidation_check(account: &signer) acquires User {
        let addr = signer::address_of(account);
        initialize(account);
        deposit(account, 100);
        let stabletoken_mut_ref = &mut borrow_global_mut<User>(addr).stabletoken.amount;
        *stabletoken_mut_ref = 1000;
        liquidate(account);
        assert!(deposit_of(addr) == 0);
    }

    #[test(account = @stabletoken)]
    #[expected_failure(abort_code = ENOT_LIQUIDATABLE)]
    fun liquidate_check_fails_not_liquidatable(account: &signer) acquires User {
        initialize(account);
        deposit(account, 100);
        mint(account, 10);
        liquidate(account);
    }

    #[test(account = @stabletoken)]
    fun withdrawal_check(account: &signer) acquires User {
        let addr = signer::address_of(account);
        initialize(account);
        deposit(account, 1000);

        withdraw(account, 100);

        let deposit_balance = deposit_of(addr);

        assert!(deposit_balance == 900);
    }

    #[test(account = @stabletoken)]
    #[expected_failure(abort_code = EEXCEEDS_DEPOSIT_AMOUNT)]
    fun withdrawal_fail_exceeds_deposit_amount(account: &signer) acquires User {
        initialize(account);
        deposit(account, 1000);
        mint(account, 500);
        withdraw(account, 600);
    }

    #[test(account = @stabletoken)]
    fun burn_check(account: &signer) acquires User {
        let addr = signer::address_of(account);
        initialize(account);
        deposit(account, 1000);
        mint(account, 100);

        let stabletoken_balance = stabletoken_of(addr);
        burn(account, 100);

        assert!(
            stabletoken_of(addr) == stabletoken_balance - 100
        );
    }

    #[test(account = @stabletoken)]
    #[expected_failure(abort_code = ENOT_ENOUGH_STABLETOKEN)]
    fun burn_fail_not_enough_stabletoken(account: &signer) acquires User {
        initialize(account);
        deposit(account, 1000);
        mint(account, 100);
        burn(account, 200);
    }
}
