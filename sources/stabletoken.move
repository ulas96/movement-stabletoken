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

    // Functions
    public entry fun initialize(account: &signer) {
        let addr = signer::address_of(account);
        assert!(!exists<Deposit>(addr) && !exists<Coin>(addr));
        let empty_deposit = Deposit { amount: 0 };
        let empty_coin = Coin { amount: 0 };
        move_to(account, empty_deposit);
        move_to(account, empty_coin);
    }

    public entry fun deposit(account: &signer, amount: u64) acquires Deposit {
        let addr = signer::address_of(account);
        let deposit = borrow_global<Deposit>(addr).amount;
        assert!(
            exists<Deposit>(addr),
            EACCOUNT_NOT_INITIALIZED
        );
        let deposit_ref = &mut borrow_global_mut<Deposit>(addr).amount;
        *deposit_ref = deposit + amount;
    }

    // View Functions
    public fun coin_of(addr: address): u64 acquires Coin {
        borrow_global<Coin>(addr).amount
    }

    public fun deposit_of(addr: address): u64 acquires Deposit {
        borrow_global<Deposit>(addr).amount
    }

    // public fun mint(account: &signer, amount: u64): Coin acquires Coin {}
    #[test(account = @stabletoken)]
    fun initialization_check(account: &signer) {
        let addr = signer::address_of(account);
        initialize(account);
        assert!(exists<Coin>(addr) && exists<Coin>(addr), 0)
    }

    #[test(account = @stabletoken)]
    fun deposit_check(account: &signer) acquires Deposit {
        let deposit_amount: u64 = 10;
        let addr = signer::address_of(account);
        initialize(account);
        deposit(account, deposit_amount);
        assert!(deposit_of(addr) == deposit_amount);
    }
}
