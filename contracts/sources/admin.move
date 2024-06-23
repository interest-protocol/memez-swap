module amm::interest_amm_admin {

    public struct Admin has key, store {
        id: UID
    }

    #[allow(unused_function)]
    fun init(ctx: &mut TxContext) {
        transfer::transfer(Admin { id: object::new(ctx) }, tx_context::sender(ctx));
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}