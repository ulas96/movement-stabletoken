module stabletoken::stabletoken_engine {
    use std::signer;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;

    // Structs
    struct Deposit has key, drop {
        amount: u64
    }

    struct Coin has key {
        amount: u64
    }

    // Constants
    const PRICE: u64 = 1;

    // Error Codes
    const EACCOUNT_ALREADY_INITIALIZED: u64 = 0;
    const EACCOUNT_NOT_INITIALIZED: u64 = 1;
    const ENOT_ENOUGH_DEPOSIT: u64 = 2;

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

    #[test(account = @stabletoken)]
    fun initialization_check(account: &signer) {
        let addr = signer::address_of(account);
        initialize(account);
        assert!(exists<Coin>(addr) && exists<Coin>(addr), 0);
    }

    #[test(account = @stabletoken, framework = @aptos_framework)]
    fun deposit_check(account: &signer, framework: &signer) acquires Deposit {
        let deposit_amount: u64 = 10;
        let addr = signer::address_of(account);

        let (burn_cap, mint_cap) = set_up_test_coins(account, framework, deposit_amount);

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

    #[test(account = @stabletoken)]
    fun deposit_of_check(account: &signer) acquires Deposit {
        let deposit_amount: u64 = 10;
        let addr = signer::address_of(account);
        initialize(account);
        deposit(account, deposit_amount);
        assert!(deposit_of(addr) == deposit_amount);
    }

    #[test(account = @stabletoken)]
    fun coin_of_check(account: &signer) acquires Coin, Deposit {
        let addr = signer::address_of(account);
        let mint_amount: u64 = 10;
        let deposit_amount: u64 = 100;
        initialize(account);
        deposit(account, deposit_amount);
        mint(account, mint_amount);
        assert!(coin_of(addr) == mint_amount);
    }

    // Test Helpers
    #[test_only]
    fun set_up_test_coins(
        account: &signer, framework: &signer, amount: u64
    ): (coin::BurnCapability<AptosCoin>, coin::MintCapability<AptosCoin>) {
        let addr = signer::address_of(account);
        let (burn_cap, mint_cap) =
            aptos_framework::aptos_coin::initialize_for_test(framework);
        coin::register<AptosCoin>(account);
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
}
