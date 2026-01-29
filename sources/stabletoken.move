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

    // Constants
    const PRICE: u64 = 1;
    const PRECISION: u64 = 100;

    // Error Codes
    const EACCOUNT_ALREADY_INITIALIZED: u64 = 0;
    const EACCOUNT_NOT_INITIALIZED: u64 = 1;
    const ENOT_ENOUGH_DEPOSIT: u64 = 2;
    const EEXCEEDS_DEPOSIT_AMOUNT: u64 = 3;
    const ENOT_ENOUGH_MINT: u64 = 4;
    const ENOT_LIQUIDATABLE: u64 = 5;
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

    public entry fun deposit(account: &signer, amount: u64) acquires Deposit {
        let addr = signer::address_of(account);
        assert!(
            exists<Deposit>(addr),
            EACCOUNT_NOT_INITIALIZED
        );
        assert!(coin::balance<AptosCoin>(addr) >= amount);
        coin::transfer<AptosCoin>(account, @stabletoken, amount);
        let deposit = borrow_global<Deposit>(addr).amount;
        let deposit_ref = &mut borrow_global_mut<Deposit>(addr).amount;
        *deposit_ref = deposit + amount;
    }

    public entry fun mint(account: &signer, amount: u64) acquires Coin, Deposit {
        let addr = signer::address_of(account);
        assert!(exists<Coin>(addr), EACCOUNT_NOT_INITIALIZED);
        let max_mintible: u64 = deposit_of(addr) * get_price();
        assert!(max_mintible >= amount, ENOT_ENOUGH_DEPOSIT);
        let coin_balance: u64 = borrow_global<Coin>(addr).amount;
        let coin_ref = &mut borrow_global_mut<Coin>(addr).amount;
        *coin_ref = coin_balance + amount;
    }

    public entry fun liquidate(account: &signer) acquires Coin, Deposit {
        let addr = signer::address_of(account);
        assert!(exists<Coin>(addr), ENOT_ENOUGH_MINT);
        assert!(get_health_factor(addr) <= PRECISION, ENOT_LIQUIDATABLE);
        let deposit_ref = &mut borrow_global_mut<Deposit>(addr).amount;
        *deposit_ref = 0;

    }

    public entry fun withdraw(account: &signer, amount: u64) acquires Deposit, Coin {
        let addr = signer::address_of(account);
        let deposit = deposit_of(addr);
        let coin = coin_of(addr);
        let max_allow_withdraw = deposit - coin / get_price();
        assert!(max_allow_withdraw >= amount, EEXCEEDS_DEPOSIT_AMOUNT);
        assert!(deposit >= amount, ENOT_ENOUGH_DEPOSIT);

        let deposit_ref = &mut borrow_global_mut<Deposit>(addr).amount;
        *deposit_ref = deposit - amount;
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
        let deposit = borrow_global<Deposit>(addr).amount;
        let mint = borrow_global<Coin>(addr).amount;

        deposit * get_price() * PRECISION / mint
    }

    #[test(account = @stabletoken)]
    fun initialization_check(account: &signer) {
        let addr = signer::address_of(account);
        initialize(account);
        assert!(exists<Coin>(addr) && exists<Coin>(addr), 0);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun deposit_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Deposit {
        let deposit_amount: u64 = 10;
        let addr = signer::address_of(account);

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);

        register_account(stabletoken);
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
    fun mint_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Coin, Deposit {
        let addr = signer::address_of(account);
        let mint_amount: u64 = 10;
        let deposit_amount: u64 = 100;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);
        register_account(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        mint(account, mint_amount);

        assert!(coin_of(addr) == mint_amount);

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = ENOT_ENOUGH_DEPOSIT)]
    fun mint_fail(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Coin, Deposit {
        let addr = signer::address_of(account);
        let mint_amount: u64 = 100;
        let deposit_amount: u64 = 10;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);
        register_account(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        mint(account, mint_amount);

        assert!(coin_of(addr) == mint_amount);

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun health_factor_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Coin, Deposit {
        let addr = signer::address_of(account);
        let deposit_amount = 1000;
        let mint_amount = 100;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);
        register_account(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        mint(account, mint_amount);

        assert!(get_health_factor(addr) == 1000);

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun liquidation_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Coin, Deposit {
        let addr = signer::address_of(account);
        let deposit_amount = 100;
        let coin_amount = 1000;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);
        register_account(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        set_coin_amount(addr, coin_amount);
        liquidate(account);

        assert!(deposit_of(addr) == 0);

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = ENOT_LIQUIDATABLE)]
    fun liquidation_fail(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Coin, Deposit {
        let addr = signer::address_of(account);
        let deposit_amount = 1000;
        let coin_amount = 100;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);
        register_account(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        set_coin_amount(addr, coin_amount);
        liquidate(account);

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    fun withdraw_check(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Deposit, Coin {
        let addr = signer::address_of(account);
        let deposit_amount = 1000;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);
        register_account(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        withdraw(account, deposit_amount);
        assert!(deposit_of(addr) == 0);

        clean_test_coins(burn_cap, mint_cap);
    }

    #[test(account = @0x123, stabletoken = @stabletoken, framework = @aptos_framework)]
    #[expected_failure(abort_code = EEXCEEDS_DEPOSIT_AMOUNT)]
    fun withdraw_fail(
        account: &signer, stabletoken: &signer, framework: &signer
    ) acquires Deposit, Coin {
        let deposit_amount = 1000;
        let mint_amount = 100;

        let (burn_cap, mint_cap) = setup_test_coins(account, framework, deposit_amount);
        register_account(stabletoken);

        initialize(account);
        deposit(account, deposit_amount);
        mint(account, mint_amount);

        withdraw(account, deposit_amount);

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
}
