module amm::memez_amm_shill {
    // === Imports ===

    use std::type_name::{Self, TypeName};

    use sui::{
        table::{Self, Table}
    };

    use amm::{
        memez_amm_admin:: Admin,
        memez_amm_errors as errors
    };

    // === Structs ===

    public struct Shillers has key {
        id: UID,
        list: Table<address, bool>
    }

    public struct Shill has key {
        id: UID,
        coin: TypeName,
        shiller: address,
        owner: address
    }

    // === Mutative Function ===

    fun init(ctx: &mut TxContext) {
        let shillers = Shillers {
            id: object::new(ctx),
            list: table::new(ctx)
        };

        transfer::share_object(shillers);
    }

    public fun shill<CoinType>(shillers: &Shillers, recipient: address, ctx: &mut TxContext) {
        assert!(shillers.list.contains(ctx.sender()), errors::you_are_not_a_shiller());
        assert!(ctx.sender() != recipient, errors::cannot_shill_yourself());

        let shill = Shill {
            id: object::new(ctx),
            coin: type_name::get<CoinType>(),
            shiller: ctx.sender(),
            owner: recipient
        };  

        transfer::transfer(shill, recipient);
    }

    public fun destroy(shill: Shill, shillers: &Shillers) {
        let Shill { id, owner, .. } = shill;
        assert!(shillers.list.contains(owner), errors::you_are_not_a_shiller());
        id.delete();
    }

    // === Admin Only Functions ===

    public fun add(shillers: &mut Shillers, _: &Admin, shiller: address) {
        if (shillers.list.contains(shiller)) return;
        shillers.list.add(shiller, true);
    }

    public fun remove(shillers: &mut Shillers, _: &Admin, shiller: address) {
        if (!shillers.list.contains(shiller)) return;
        shillers.list.remove(shiller);
    }

    // === Package Only Functions ===

    public(package) fun coin(shill: &Shill): TypeName {
        shill.coin
    }

    public(package) fun shiller(shill: &Shill): address {
        shill.shiller
    }
}