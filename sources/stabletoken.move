module stabletoken::stabletoken_engine {
    use std::signer;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::account;

    // Structs
    struct Deposit has key, drop {
        amount: u64
    }

    struct Coin has key {
        amount: u64
    }

    struct SignerCap has key {
        cap: account::SignerCapability,
        resource_addr: address
    }

    // Constants
    const PRICE: u64 = 1;
    const PRECISION: u64 = 100;

    // Error Codes
    const EACCOUNT_ALREADY_INITIALIZED: u64 = 0;
    const EZERO_AMOUNT: u64 = 1;
    const EACCOUNT_NOT_INITIALIZED: u64 = 2;
    const ENOT_ENOUGH_BALANCE: u64 = 3;
    const ENOT_ENOUGH_DEPOSIT: u64 = 4;
    const EEXCEEDS_DEPOSIT_AMOUNT: u64 = 5;
    const ENOT_ENOUGH_MINT: u64 = 6;
    const ENOT_LIQUIDATABLE: u64 = 7;

    // Functions

    // Public Entry Functions
    public entry fun initialize(account: &signer) {
        let addr = signer::address_of(account);
        assert!(
            !exists<Deposit>(addr) && !exists<Coin>(addr),
            EACCOUNT_ALREADY_INITIALIZED
        );
        let empty_deposit = Deposit { amount: 0 };
        let empty_coin = Coin { amount: 0 };
        move_to(account, empty_deposit);
        move_to(account, empty_coin);
    }

    public entry fun deposit(account: &signer, amount: u64) acquires Deposit, SignerCap {
        assert!(amount > 0, EZERO_AMOUNT);
        let addr = signer::address_of(account);
        assert!(
            exists<Deposit>(addr),
            EACCOUNT_NOT_INITIALIZED
        );
        assert!(coin::balance<AptosCoin>(addr) >= amount, ENOT_ENOUGH_BALANCE);
        let resource_addr = borrow_global<SignerCap>(@stabletoken).resource_addr;
        coin::transfer<AptosCoin>(account, resource_addr, amount);
        let deposit_amount = borrow_global<Deposit>(addr).amount;
        let deposit_ref = &mut borrow_global_mut<Deposit>(addr).amount;
        *deposit_ref = deposit_amount + amount;
    }

    public entry fun mint(account: &signer, amount: u64) acquires Coin, Deposit {
        assert!(amount > 0, EZERO_AMOUNT);
        let addr = signer::address_of(account);
        assert!(exists<Coin>(addr), EACCOUNT_NOT_INITIALIZED);
        let deposit_balance = deposit_of(addr);
        let coin_balance = borrow_global<Coin>(addr).amount;
        let max_mintible_amount = get_available_collateral(
            deposit_balance, coin_balance
        );
        assert!(max_mintible_amount >= amount, ENOT_ENOUGH_DEPOSIT);
        let coin_ref = &mut borrow_global_mut<Coin>(addr).amount;
        *coin_ref = coin_balance + amount;
    }

    public entry fun liquidate(addr: address) acquires Coin, Deposit {
        assert!(exists<Coin>(addr), ENOT_ENOUGH_MINT);
        assert!(get_health_factor(addr) < PRECISION, ENOT_LIQUIDATABLE);
        let deposit_ref = &mut borrow_global_mut<Deposit>(addr).amount;
        *deposit_ref = 0;

    }

    public entry fun withdraw(account: &signer, amount: u64) acquires Deposit, Coin, SignerCap {
        assert!(amount > 0, EZERO_AMOUNT);
        let addr = signer::address_of(account);
        let deposit = deposit_of(addr);
        let coin = coin_of(addr);
        let max_allow_withdraw = deposit - coin / get_price();
        assert!(max_allow_withdraw >= amount, EEXCEEDS_DEPOSIT_AMOUNT);
        assert!(deposit >= amount, ENOT_ENOUGH_DEPOSIT);

        let deposit_ref = &mut borrow_global_mut<Deposit>(addr).amount;
        *deposit_ref = deposit - amount;

        let signer_cap = borrow_global<SignerCap>(@stabletoken);
        let contract_signer = account::create_signer_with_capability(&signer_cap.cap);
        coin::transfer<AptosCoin>(&contract_signer, addr, amount);
    }

    public entry fun burn(account: &signer, amount: u64) acquires Coin {
        assert!(amount > 0, EZERO_AMOUNT);
        let addr = signer::address_of(account);
        let coin_balance = coin_of(addr);
        assert!(coin_balance >= amount, ENOT_ENOUGH_MINT);

        let coin_ref = &mut borrow_global_mut<Coin>(addr).amount;
        *coin_ref = coin_balance - amount;

    }

    // View Functions
    public fun coin_of(addr: address): u64 acquires Coin {
        borrow_global<Coin>(addr).amount
    }

    public fun deposit_of(addr: address): u64 acquires Deposit {
        borrow_global<Deposit>(addr).amount
    }

    public fun get_price(): u64 {
        PRICE
    }

    public fun get_health_factor(addr: address): u64 acquires Coin, Deposit {
        assert!(coin_of(addr) > 0, ENOT_ENOUGH_MINT);
        let deposit = deposit_of(addr);
        let mint = coin_of(addr);

        deposit * get_price() * PRECISION / mint
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
        assert!(exists<Coin>(addr) && exists<Deposit>(addr), 0);
    }

    #[test(account = @stabletoken)]
    #[expected_failure(abort_code = EACCOUNT_ALREADY_INITIALIZED)]
    fun initialize_fail(account: &signer) {
        initialize(account);
        initialize(account);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun deposit_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Deposit, SignerCap {
        let deposit_amount = 10;
        let addr = signer::address_of(account);

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);

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
        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = EZERO_AMOUNT)]
    fun deposit_fail_zero_amount(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Deposit, SignerCap {
        let deposit_amount = 0;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);

        register_account(stabletoken);
        init_module(stabletoken);
        initialize(account);

        deposit(account, deposit_amount);

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun multiple_deposits_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Deposit, SignerCap {
        let deposit_amount = 10;
        let addr = signer::address_of(account);

        let (burn_cap, mint_cap) = setup_test_coins(
            account, framework, 2 * deposit_amount
        );

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
        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = EACCOUNT_NOT_INITIALIZED)]
    fun deposit_fail_not_init(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Deposit, SignerCap {
        let deposit_amount = 10;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        deposit(account, deposit_amount);

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun mint_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Coin, Deposit, SignerCap {
        let addr = signer::address_of(account);
        let mint_amount: u64 = 10;
        let deposit_amount: u64 = 100;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        mint(account, mint_amount);

        assert!(coin_of(addr) == mint_amount);

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun mint_exact_max_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Coin, Deposit, SignerCap {
        let addr = signer::address_of(account);
        let mint_amount: u64 = 100;
        let deposit_amount: u64 = 100;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);

        mint(account, mint_amount);

        assert!(coin_of(addr) == mint_amount);

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun multiple_mints_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Coin, Deposit, SignerCap {
        let addr = signer::address_of(account);
        let mint_amount: u64 = 10;
        let deposit_amount: u64 = 100;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);

        mint(account, mint_amount);
        mint(account, mint_amount);

        assert!(coin_of(addr) == 2 * mint_amount);

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = EZERO_AMOUNT)]
    fun mint_fail_zero_amount(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Coin, Deposit {
        let mint_amount: u64 = 0;
        let deposit_amount: u64 = 100;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);
        register_account(stabletoken);

        create_mock_deposit(account, deposit_amount);
        mint(account, mint_amount);

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = EACCOUNT_NOT_INITIALIZED)]
    fun mint_fail_not_initialized(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Coin, Deposit {
        let mint_amount: u64 = 10;
        let deposit_amount: u64 = 100;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);
        register_account(stabletoken);

        create_mock_deposit(account, deposit_amount);
        mint(account, mint_amount);

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = ENOT_ENOUGH_DEPOSIT)]
    fun mint_fail_not_enough_deposit(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Coin, Deposit, SignerCap {
        let mint_amount: u64 = 100;
        let deposit_amount: u64 = 10;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        mint(account, mint_amount);

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = ENOT_ENOUGH_DEPOSIT)]
    fun mint_fail_overcollateralization(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Deposit, Coin, SignerCap {
        let mint_amount: u64 = 100;
        let deposit_amount: u64 = 100;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        mint(account, mint_amount);
        mint(account, mint_amount);

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun health_factor_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Coin, Deposit, SignerCap {
        let addr = signer::address_of(account);
        let deposit_amount = 1000;
        let mint_amount = 100;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        mint(account, mint_amount);

        assert!(get_health_factor(addr) == 1000);

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun liquidation_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Coin, Deposit, SignerCap {
        let addr = signer::address_of(account);
        let deposit_amount = 100;
        let coin_amount = 1000;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);
        register_account(stabletoken);

        init_module(stabletoken);
        initialize(account);

        deposit(account, deposit_amount);
        set_coin_amount(addr, coin_amount);
        liquidate(addr);

        assert!(deposit_of(addr) == 0);

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = ENOT_LIQUIDATABLE)]
    fun liquidation_fail(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Coin, Deposit, SignerCap {
        let addr = signer::address_of(account);
        let deposit_amount = 1000;
        let coin_amount = 100;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        set_coin_amount(addr, coin_amount);
        liquidate(addr);

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun withdrawal_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Deposit, Coin, SignerCap {
        let addr = signer::address_of(account);
        let deposit_amount = 1000;
        let withdrawal_amount = 100;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);
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

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun withdraw_max_allowed_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Deposit, Coin, SignerCap {
        let addr = signer::address_of(account);
        let deposit_amount = 1000;
        let mint_amount = 100;
        let withdrawal_amount = get_available_collateral(deposit_amount, mint_amount);

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);
        register_account(stabletoken);

        init_module(stabletoken);
        initialize(account);
        deposit(account, deposit_amount);
        mint(account, mint_amount);

        withdraw(account, withdrawal_amount);
        assert!(
            deposit_of(addr) == deposit_amount - withdrawal_amount
        );

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun multiple_withdrawals_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Deposit, Coin, SignerCap {
        let addr = signer::address_of(account);
        let deposit_amount = 1000;
        let withdrawal_amount = 100;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);
        register_account(stabletoken);

        init_module(stabletoken);
        initialize(account);
        deposit(account, deposit_amount);

        withdraw(account, withdrawal_amount);
        withdraw(account, withdrawal_amount);

        assert!(
            deposit_of(addr) == deposit_amount - 2 * withdrawal_amount
        );

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = EZERO_AMOUNT)]
    fun withdrawal_fail_zero_amount(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Deposit, Coin, SignerCap {
        let deposit_amount = 1000;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);
        register_account(stabletoken);

        init_module(stabletoken);
        initialize(account);
        deposit(account, deposit_amount);

        withdraw(account, 0);

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = EEXCEEDS_DEPOSIT_AMOUNT)]
    fun withdrawal_fail(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Deposit, Coin, SignerCap {
        let deposit_amount = 1000;
        let mint_amount = 100;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);
        register_account(stabletoken);

        init_module(stabletoken);
        initialize(account);
        deposit(account, deposit_amount);
        mint(account, mint_amount);

        withdraw(account, deposit_amount);

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun burn_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Deposit, Coin, SignerCap {
        let addr = signer::address_of(account);
        let deposit_amount = 1000;
        let mint_amount = 100;
        let burn_amount = 100;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        mint(account, mint_amount);

        let coin_balance = coin_of(addr);

        burn(account, burn_amount);

        assert!(coin_of(addr) == coin_balance - burn_amount);

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = EZERO_AMOUNT)]
    fun burn_fail_zero_amount(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Coin, Deposit, SignerCap {
        let deposit_amount = 1000;
        let mint_amount = 100;
        let burn_amount = 0;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        mint(account, mint_amount);

        burn(account, burn_amount);

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = ENOT_ENOUGH_MINT)]
    fun burn_fail_not_enough_mint(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Coin, Deposit, SignerCap {
        let deposit_amount = 1000;
        let mint_amount = 100;
        let burn_amount = 200;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        mint(account, mint_amount);

        burn(account, burn_amount);

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = ENOT_ENOUGH_BALANCE)]
    fun deposit_fail_insufficient_balance(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Deposit, SignerCap {
        let aptos_balance = 50;
        let deposit_amount = 100;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, aptos_balance);
        register_account(stabletoken);
        init_module(stabletoken);
        initialize(account);

        deposit(account, deposit_amount);

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = ENOT_ENOUGH_MINT)]
    fun health_factor_fail_zero_mint(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Coin, Deposit, SignerCap {
        let addr = signer::address_of(account);
        let deposit_amount = 1000;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);

        get_health_factor(addr);

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun health_factor_exact_boundary_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Coin, Deposit, SignerCap {
        let addr = signer::address_of(account);
        let deposit_amount = 100;
        let mint_amount = 100;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        mint(account, mint_amount);

        assert!(get_health_factor(addr) == 100);

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = ENOT_LIQUIDATABLE)]
    fun liquidation_fail_exact_boundary(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Coin, Deposit, SignerCap {
        let addr = signer::address_of(account);
        let deposit_amount = 100;
        let coin_amount = 100;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        set_coin_amount(addr, coin_amount);

        liquidate(addr);

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun liquidation_coin_unchanged_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Coin, Deposit, SignerCap {
        let addr = signer::address_of(account);
        let deposit_amount = 100;
        let coin_amount = 1000;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        set_coin_amount(addr, coin_amount);

        let coin_before = coin_of(addr);
        liquidate(addr);

        assert!(deposit_of(addr) == 0);
        assert!(coin_of(addr) == coin_before);

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(arithmetic_error, location = Self)]
    fun withdraw_after_liquidation_fail(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Deposit, Coin, SignerCap {
        let addr = signer::address_of(account);
        let deposit_amount = 100;
        let coin_amount = 1000;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        set_coin_amount(addr, coin_amount);

        liquidate(addr);

        withdraw(account, 1);

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun burn_after_liquidation_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Coin, Deposit, SignerCap {
        let addr = signer::address_of(account);
        let deposit_amount = 100;
        let coin_amount = 1000;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        set_coin_amount(addr, coin_amount);

        liquidate(addr);

        assert!(deposit_of(addr) == 0);
        assert!(coin_of(addr) == coin_amount);

        burn(account, 500);

        assert!(coin_of(addr) == 500);

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun deposit_after_liquidation_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Coin, Deposit, SignerCap {
        let addr = signer::address_of(account);
        let initial_deposit = 100;
        let coin_amount = 1000;
        let redeposit_amount = 500;

        let (burn_cap, mint_cap) =
            setup_test_coins(account, framework, initial_deposit + redeposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, initial_deposit);
        set_coin_amount(addr, coin_amount);

        liquidate(addr);
        assert!(deposit_of(addr) == 0);

        deposit(account, redeposit_amount);
        assert!(deposit_of(addr) == redeposit_amount);

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun multiple_burns_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Deposit, Coin, SignerCap {
        let addr = signer::address_of(account);
        let deposit_amount = 1000;
        let mint_amount = 500;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        mint(account, mint_amount);

        burn(account, 100);
        assert!(coin_of(addr) == 400);

        burn(account, 150);
        assert!(coin_of(addr) == 250);

        burn(account, 250);
        assert!(coin_of(addr) == 0);

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun burn_exact_full_amount_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Deposit, Coin, SignerCap {
        let addr = signer::address_of(account);
        let deposit_amount = 1000;
        let mint_amount = 500;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        mint(account, mint_amount);

        burn(account, mint_amount);

        assert!(coin_of(addr) == 0);

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun full_lifecycle_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Deposit, Coin, SignerCap {
        let addr = signer::address_of(account);
        let deposit_amount = 1000;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);

        deposit(account, deposit_amount);
        assert!(deposit_of(addr) == 1000);

        mint(account, 500);
        assert!(coin_of(addr) == 500);

        burn(account, 200);
        assert!(coin_of(addr) == 300);

        withdraw(account, 700);
        assert!(deposit_of(addr) == 300);

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun mint_after_partial_burn_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Deposit, Coin, SignerCap {
        let addr = signer::address_of(account);
        let deposit_amount = 1000;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);

        mint(account, 1000);
        assert!(coin_of(addr) == 1000);

        burn(account, 500);
        assert!(coin_of(addr) == 500);

        mint(account, 300);
        assert!(coin_of(addr) == 800);

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun withdraw_with_active_mint_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Deposit, Coin, SignerCap {
        let addr = signer::address_of(account);
        let deposit_amount = 1000;
        let mint_amount = 200;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);
        register_account(stabletoken);
        init_module(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        mint(account, mint_amount);

        withdraw(account, 800);

        assert!(deposit_of(addr) == 200);
        assert!(coin_of(addr) == 200);
        assert!(get_health_factor(addr) == 100);

        clean_test_coins(burn_cap, mint_cap);
    }

    // Test Helpers
    #[test_only]
    fun setup_test_coins(
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
    fun clean_test_coins(
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
    fun set_coin_amount(addr: address, amount: u64) acquires Coin {
        let coin_ref = &mut borrow_global_mut<Coin>(addr).amount;
        *coin_ref = amount;
    }

    #[test_only]
    fun create_mock_deposit(account: &signer, amount: u64) {
        let deposit = Deposit { amount };
        move_to(account, deposit);
    }
}
