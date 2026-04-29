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

    struct SignerCap has key {
        cap: account::SignerCapability,
        resource_addr: address
    }

    // Events
    #[event]
    struct InitializeEvent has drop, store {
        account: address
    }

    #[event]
    struct DepositEvent has drop, store {
        account: address,
        amount: u64
    }

    #[event]
    struct MintEvent has drop, store {
        account: address,
        amount: u64
    }

    #[event]
    struct BurnEvent has drop, store {
        account: address,
        amount: u64
    }

    #[event]
    struct WithdrawEvent has drop, store {
        account: address,
        amount: u64
    }

    #[event]
    struct LiquidateEvent has drop, store {
        account: address,
        deposit_seized: u64
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
        let addr = signer::address_of(account);
        assert!(!exists<User>(addr), EACCOUNT_ALREADY_EXISTS);
        let empty_deposit = Deposit { amount: 0 };
        let empty_stabletoken = Stabletoken { amount: 0 };
        move_to(account, User { deposit: empty_deposit, stabletoken: empty_stabletoken });
        event::emit(InitializeEvent { account: addr });
    }

    public entry fun deposit(account: &signer, amount: u64) acquires User, SignerCap {
        assert!(amount > 0, EZERO_AMOUNT);
        let addr = signer::address_of(account);

        assert!(exists<User>(addr), EACCOUNT_NOT_EXISTS);
        assert!(coin::balance<AptosCoin>(addr) >= amount, ENOT_ENOUGH_BALANCE);

        let resource_addr = borrow_global<SignerCap>(@stabletoken).resource_addr;
        coin::transfer<AptosCoin>(account, resource_addr, amount);

        let deposit_amount = deposit_of(addr);
        let deposit_ref = &mut borrow_global_mut<User>(addr).deposit.amount;

        *deposit_ref = deposit_amount + amount;
        event::emit(DepositEvent { account: addr, amount });
    }

    public entry fun mint(account: &signer, amount: u64) acquires User {
        assert!(amount > 0, EZERO_AMOUNT);
        let addr = signer::address_of(account);
        assert!(exists<User>(addr), EACCOUNT_NOT_EXISTS);

        let stabletoken_balance = stabletoken_of(addr);

        let stabletoken_mut_ref = &mut borrow_global_mut<User>(addr).stabletoken.amount;
        *stabletoken_mut_ref = stabletoken_balance + amount;

        let health_factor = get_health_factor(addr);
        assert!(health_factor >= PRECISION, EUNHEALTHY_USER);

        event::emit(MintEvent { account: addr, amount });
    }

    public entry fun liquidate(addr: address) acquires User {
        assert!(exists<User>(addr), ENOT_ENOUGH_STABLETOKEN);
        assert!(get_health_factor(addr) < PRECISION, ENOT_LIQUIDATABLE);

        let deposit_amount = deposit_of(addr);
        let deposit_ref = &mut borrow_global_mut<User>(addr).deposit.amount;

        *deposit_ref = 0;
        event::emit(LiquidateEvent { account: addr, deposit_seized: deposit_amount });
    }

    public entry fun withdraw(account: &signer, amount: u64) acquires User, SignerCap {
        assert!(amount > 0, EZERO_AMOUNT);
        let addr = signer::address_of(account);

        let deposit_balance = deposit_of(addr);

        let deposit_ref = &mut borrow_global_mut<User>(addr).deposit.amount;
        *deposit_ref = deposit_balance - amount;

        let signer_cap = borrow_global<SignerCap>(@stabletoken);
        let contract_signer = account::create_signer_with_capability(&signer_cap.cap);
        coin::transfer<AptosCoin>(&contract_signer, addr, amount);

        let health_factor = get_health_factor(addr);

        assert!(health_factor >= PRECISION, EUNHEALTHY_USER);
        event::emit(WithdrawEvent { account: addr, amount });
    }

    public entry fun burn(account: &signer, amount: u64) acquires User {
        assert!(amount > 0, EZERO_AMOUNT);
        let addr = signer::address_of(account);
        let stabletoken_balance = stabletoken_of(addr);
        assert!(stabletoken_balance >= amount, ENOT_ENOUGH_STABLETOKEN);

        let stabletoken_ref = &mut borrow_global_mut<User>(addr).stabletoken.amount;
        *stabletoken_ref = stabletoken_balance - amount;
        event::emit(BurnEvent { account: addr, amount });
    }

    // View Functions
    public fun stabletoken_of(addr: address): u64 acquires User {
        borrow_global<User>(addr).stabletoken.amount
    }

    public fun deposit_of(addr: address): u64 acquires User {
        borrow_global<User>(addr).deposit.amount
    }

    public fun get_price(): u64 {
        PRICE
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
    fun init_module(admin: &signer) {
        let (resource_signer, signer_cap) =
            account::create_resource_account(admin, b"seed");
        coin::register<AptosCoin>(&resource_signer);
        let resource_addr = signer::address_of(&resource_signer);
        move_to(admin, SignerCap { cap: signer_cap, resource_addr });
    }

    fun get_available_collateral(deposit_amount: u64, mint_amount: u64): u64 {
        deposit_amount - (mint_amount / get_price())
    }

    #[test(account = @stabletoken)]
    fun initialization_check(account: &signer) {
        let addr = signer::address_of(account);
        initialize(account);
        assert!(exists<User>(addr), 0);
    }

    #[test(account = @stabletoken)]
    #[expected_failure(abort_code = EACCOUNT_ALREADY_EXISTS)]
    fun initialize_fail(account: &signer) {
        initialize(account);
        initialize(account);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun deposit_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let deposit_amount = 10;
        let addr = signer::address_of(account);

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount);

        register_account(stabletoken);
        init_module(stabletoken);
        initialize(account);

        let before_balance = coin::balance<AptosCoin>(addr);

        deposit(account, deposit_amount);

        let after_balance = coin::balance<AptosCoin>(addr);

        assert!(deposit_of(addr) == deposit_amount);
        assert!(
            before_balance - after_balance >= deposit_amount
        );
        clean_test_caps(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = EZERO_AMOUNT)]
    fun deposit_fail_zero_amount(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let deposit_amount = 0;

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount);

        register_account(stabletoken);
        init_module(stabletoken);
        initialize(account);

        deposit(account, deposit_amount);

        clean_test_caps(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun multiple_deposits_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let deposit_amount = 10;
        let addr = signer::address_of(account);

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, 2
            * deposit_amount);

        register_account(stabletoken);
        init_module(stabletoken);
        initialize(account);

        let before_balance = coin::balance<AptosCoin>(addr);

        deposit(account, deposit_amount);
        deposit(account, deposit_amount);

        let after_balance = coin::balance<AptosCoin>(addr);

        assert!(deposit_of(addr) == 2 * deposit_amount);
        assert!(
            before_balance - after_balance >= 2 * deposit_amount
        );
        clean_test_caps(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = EACCOUNT_NOT_EXISTS)]
    fun deposit_fail_not_init(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let deposit_amount = 10;

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        deposit(account, deposit_amount);

        clean_test_caps(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun mint_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account);
        let mint_amount: u64 = 10;
        let deposit_amount: u64 = 100;

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        mint(account, mint_amount);

        assert!(stabletoken_of(addr) == mint_amount);

        clean_test_caps(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun mint_exact_max_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account);
        let mint_amount: u64 = 100;
        let deposit_amount: u64 = 100;

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);

        mint(account, mint_amount);

        assert!(stabletoken_of(addr) == mint_amount);

        clean_test_caps(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun multiple_mints_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account);
        let mint_amount: u64 = 10;
        let deposit_amount: u64 = 100;

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);

        mint(account, mint_amount);
        mint(account, mint_amount);

        assert!(stabletoken_of(addr) == 2 * mint_amount);

        clean_test_caps(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = EZERO_AMOUNT)]
    fun mint_fail_zero_amount(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User {
        let mint_amount: u64 = 0;

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, 100);
        register_account(stabletoken);

        initialize(account);
        mint(account, mint_amount);

        clean_test_caps(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = EACCOUNT_NOT_EXISTS)]
    fun mint_fail_not_initialized(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User {
        let mint_amount: u64 = 10;

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, 100);
        register_account(stabletoken);

        mint(account, mint_amount);

        clean_test_caps(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = EUNHEALTHY_USER)]
    fun mint_fail_not_enough_deposit(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let mint_amount: u64 = 100;
        let deposit_amount: u64 = 10;

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        mint(account, mint_amount);

        clean_test_caps(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = EUNHEALTHY_USER)]
    fun mint_fail_overcollateralization(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let mint_amount: u64 = 100;
        let deposit_amount: u64 = 100;

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        mint(account, mint_amount);
        mint(account, mint_amount);

        clean_test_caps(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun health_factor_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account);
        let deposit_amount = 1000;
        let mint_amount = 100;

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        mint(account, mint_amount);

        assert!(get_health_factor(addr) == 1000);

        clean_test_caps(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun liquidation_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account);
        let deposit_amount = 100;
        let stabletoken_amount = 1000;

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount);
        register_account(stabletoken);

        init_module(stabletoken);
        initialize(account);

        deposit(account, deposit_amount);
        set_coin_amount(addr, stabletoken_amount);
        liquidate(addr);

        assert!(deposit_of(addr) == 0);

        clean_test_caps(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = ENOT_LIQUIDATABLE)]
    fun liquidation_fail(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account);
        let deposit_amount = 1000;
        let stabletoken_amount = 100;

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        set_coin_amount(addr, stabletoken_amount);
        liquidate(addr);

        clean_test_caps(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun withdrawal_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account);
        let deposit_amount = 1000;
        let withdrawal_amount = 100;

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount);
        register_account(stabletoken);

        init_module(stabletoken);
        initialize(account);

        let before_balance = coin::balance<AptosCoin>(addr);

        deposit(account, deposit_amount);
        withdraw(account, withdrawal_amount);

        let after_balance = coin::balance<AptosCoin>(addr);

        assert!(
            deposit_of(addr) == deposit_amount - withdrawal_amount
        );

        assert!(
            after_balance == before_balance - deposit_amount + withdrawal_amount
        );

        clean_test_caps(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun withdraw_max_allowed_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account);
        let deposit_amount = 1000;
        let mint_amount = 100;
        let withdrawal_amount = get_available_collateral(deposit_amount, mint_amount);

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount);
        register_account(stabletoken);

        init_module(stabletoken);
        initialize(account);
        deposit(account, deposit_amount);
        mint(account, mint_amount);

        withdraw(account, withdrawal_amount);
        assert!(
            deposit_of(addr) == deposit_amount - withdrawal_amount
        );

        clean_test_caps(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun multiple_withdrawals_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account);
        let deposit_amount = 1000;
        let withdrawal_amount = 100;

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount);
        register_account(stabletoken);

        init_module(stabletoken);
        initialize(account);
        deposit(account, deposit_amount);

        withdraw(account, withdrawal_amount);
        withdraw(account, withdrawal_amount);

        assert!(
            deposit_of(addr) == deposit_amount - 2 * withdrawal_amount
        );

        clean_test_caps(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = EZERO_AMOUNT)]
    fun withdrawal_fail_zero_amount(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let deposit_amount = 1000;

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount);
        register_account(stabletoken);

        init_module(stabletoken);
        initialize(account);
        deposit(account, deposit_amount);

        withdraw(account, 0);

        clean_test_caps(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = EUNHEALTHY_USER)]
    fun withdrawal_fail(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let deposit_amount = 1000;
        let mint_amount = 100;

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount);
        register_account(stabletoken);

        init_module(stabletoken);
        initialize(account);
        deposit(account, deposit_amount);
        mint(account, mint_amount);

        withdraw(account, deposit_amount);

        clean_test_caps(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun burn_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account);
        let deposit_amount = 1000;
        let mint_amount = 100;
        let burn_amount = 100;

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        mint(account, mint_amount);

        let stabletoken_balance = stabletoken_of(addr);

        burn(account, burn_amount);

        assert!(
            stabletoken_of(addr) == stabletoken_balance - burn_amount
        );

        clean_test_caps(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = EZERO_AMOUNT)]
    fun burn_fail_zero_amount(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let deposit_amount = 1000;
        let mint_amount = 100;
        let burn_amount = 0;

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        mint(account, mint_amount);

        burn(account, burn_amount);

        clean_test_caps(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = ENOT_ENOUGH_STABLETOKEN)]
    fun burn_fail_not_enough_mint(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let deposit_amount = 1000;
        let mint_amount = 100;
        let burn_amount = 200;

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        mint(account, mint_amount);

        burn(account, burn_amount);

        clean_test_caps(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = ENOT_ENOUGH_BALANCE)]
    fun deposit_fail_insufficient_balance(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let aptos_balance = 50;
        let deposit_amount = 100;

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, aptos_balance);
        register_account(stabletoken);
        init_module(stabletoken);
        initialize(account);

        deposit(account, deposit_amount);

        clean_test_caps(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun health_factor_exact_boundary_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account);
        let deposit_amount = 100;
        let mint_amount = 100;

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        mint(account, mint_amount);

        assert!(get_health_factor(addr) == 100);

        clean_test_caps(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = ENOT_LIQUIDATABLE)]
    fun liquidation_fail_exact_boundary(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account);
        let deposit_amount = 100;
        let stabletoken_amount = 100;

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        set_coin_amount(addr, stabletoken_amount);

        liquidate(addr);

        clean_test_caps(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun liquidation_coin_unchanged_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account);
        let deposit_amount = 100;
        let stabletoken_amount = 1000;

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        set_coin_amount(addr, stabletoken_amount);

        let coin_before = stabletoken_of(addr);
        liquidate(addr);

        assert!(deposit_of(addr) == 0);
        assert!(stabletoken_of(addr) == coin_before);

        clean_test_caps(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(arithmetic_error, location = Self)]
    fun withdraw_after_liquidation_fail(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account);
        let deposit_amount = 100;
        let stabletoken_amount = 1000;

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        set_coin_amount(addr, stabletoken_amount);

        liquidate(addr);

        withdraw(account, 1);

        clean_test_caps(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun burn_after_liquidation_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account);
        let deposit_amount = 100;
        let stabletoken_amount = 1000;

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        set_coin_amount(addr, stabletoken_amount);

        liquidate(addr);

        assert!(deposit_of(addr) == 0);
        assert!(stabletoken_of(addr) == stabletoken_amount);

        burn(account, 500);

        assert!(stabletoken_of(addr) == 500);

        clean_test_caps(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun deposit_after_liquidation_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account);
        let initial_deposit = 100;
        let stabletoken_amount = 1000;
        let redeposit_amount = 500;

        let (burn_cap, mint_cap) =
            setup_test_caps(account, framework, initial_deposit + redeposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, initial_deposit);
        set_coin_amount(addr, stabletoken_amount);

        liquidate(addr);
        assert!(deposit_of(addr) == 0);

        deposit(account, redeposit_amount);
        assert!(deposit_of(addr) == redeposit_amount);

        clean_test_caps(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun multiple_burns_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account);
        let deposit_amount = 1000;
        let mint_amount = 500;

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        mint(account, mint_amount);

        burn(account, 100);
        assert!(stabletoken_of(addr) == 400);

        burn(account, 150);
        assert!(stabletoken_of(addr) == 250);

        burn(account, 250);
        assert!(stabletoken_of(addr) == 0);

        clean_test_caps(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun burn_exact_full_amount_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account);
        let deposit_amount = 1000;
        let mint_amount = 500;

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        mint(account, mint_amount);

        burn(account, mint_amount);

        assert!(stabletoken_of(addr) == 0);

        clean_test_caps(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun full_lifecycle_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account);
        let deposit_amount = 1000;

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);

        deposit(account, deposit_amount);
        assert!(deposit_of(addr) == 1000);

        mint(account, 500);
        assert!(stabletoken_of(addr) == 500);

        burn(account, 200);
        assert!(stabletoken_of(addr) == 300);

        withdraw(account, 700);
        assert!(deposit_of(addr) == 300);

        clean_test_caps(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun mint_after_partial_burn_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account);
        let deposit_amount = 1000;

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);

        mint(account, 1000);
        assert!(stabletoken_of(addr) == 1000);

        burn(account, 500);
        assert!(stabletoken_of(addr) == 500);

        mint(account, 300);
        assert!(stabletoken_of(addr) == 800);

        clean_test_caps(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun withdraw_with_active_mint_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires User, SignerCap {
        let addr = signer::address_of(account);
        let deposit_amount = 1000;
        let mint_amount = 200;

        let (burn_cap, mint_cap) = setup_test_caps(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        mint(account, mint_amount);

        withdraw(account, 800);

        assert!(deposit_of(addr) == 200);
        assert!(stabletoken_of(addr) == 200);
        assert!(get_health_factor(addr) == 100);

        clean_test_caps(burn_cap, mint_cap);
    }

    // Test Helpers
    #[test_only]
    fun setup_test_caps(
        account: &signer, framework: &signer, amount: u64
    ): (coin::BurnCapability<AptosCoin>, coin::MintCapability<AptosCoin>) {
        let addr = signer::address_of(account);
        let (burn_cap, mint_cap) =
            aptos_framework::aptos_coin::initialize_for_test(framework);
        register_account(account);
        coin::deposit(addr, coin::mint<AptosCoin>(amount, &mint_cap));
        (burn_cap, mint_cap)
    }

    #[test_only]
    fun clean_test_caps(
        burn_cap: coin::BurnCapability<AptosCoin>,
        mint_cap: coin::MintCapability<AptosCoin>
    ) {
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test_only]
    fun register_account(account: &signer) {
        let addr = signer::address_of(account);
        account::create_account_for_test(addr);
        coin::register<AptosCoin>(account);

    }

    #[test_only]
    fun set_coin_amount(addr: address, amount: u64) acquires User {
        let stabletoken_ref = &mut borrow_global_mut<User>(addr).stabletoken.amount;
        *stabletoken_ref = amount;
    }
}
