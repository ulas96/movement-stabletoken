module stabletoken::stabletoken_engine {

    struct Deposit has store {
        amount: u64
    }

    struct User has store {
        deposit: Deposit
    }

    struct User has key {
        deposit: Deposit,
        stabletoken: Stabletoken
    }
}
