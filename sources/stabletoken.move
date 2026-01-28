module stabletoken::stabletoken_engine {
    use std::signer;
    // use aptos_framework::coin;

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

    #[test(account = @stabletoken)]
    fun deposit_check(account: &signer) acquires Deposit {
        let deposit_amount: u64 = 10;
        let addr = signer::address_of(account);
        initialize(account);
        deposit(account, deposit_amount);
        assert!(deposit_of(addr) == deposit_amount);
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
}
