module stabletoken::stabletoken_engine_sol {
    use std::signer;

    // Error Codes

    const EACCOUNT_ALREADY_EXISTS: u64 = 0;
    const EACCOUNT_NOT_EXISTS: u64 = 1;
    const ENOT_ENOUGH_DEPOSIT: u64 = 2;
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
        let addr = signer::address_of(account);
        assert!(!exists<User>(addr), EACCOUNT_ALREADY_EXISTS);
        let empty_deposit = Deposit { amount: 0 };
        let empty_stabletoken = Stabletoken { amount: 0 };
        let new_user = User { deposit: empty_deposit, stabletoken: empty_stabletoken };
        move_to(account, new_user);
    }

    public entry fun deposit(account: &signer, amount: u64) acquires User {
        let addr = signer::address_of(account);
        assert!(exists<User>(addr), EACCOUNT_NOT_EXISTS);
        let deposit_ref = deposit_of(addr);
        let deposit_mut = &mut borrow_global_mut<User>(addr).deposit.amount;
        *deposit_mut = deposit_ref + amount;
    }

    public fun deposit_of(addr: address): u64 acquires User {
        borrow_global<User>(addr).deposit.amount
    }

    public fun stabletoken_of(addr: address): u64 acquires User {
        borrow_global<User>(addr).stabletoken.amount
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
}
