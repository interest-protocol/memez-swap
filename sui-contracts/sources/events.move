module amm::interest_amm_events {

    use std::type_name::{Self, TypeName};

    use sui::event::emit;

    use amm::interest_amm_fees::Fees;

    public struct NewPool has copy, drop {
        pool: address,
        amount_x: u64,
        amount_y: u64,
        coin_x: TypeName,
        coin_y: TypeName
    }

    public struct Swap<phantom CoinIn, phantom CoinOut, T: drop + copy + store> has copy, drop {
        pool: address,
        amount_in: u64,
        swap_amount: T
    }

    public struct UpdateFees has copy, drop {
        pool: address,
        fees: Fees    
    }

    public struct AdminTakeFees has copy, drop {
        pool: address,
        amount_x: u64,
        amount_y: u64
    }

    public struct DeployerTakeFees has copy, drop {
        pool: address,
        amount_x: u64,
        amount_y: u64
    }

    public(package) fun new_pool<CoinX, CoinY>(
        pool: address,
        amount_x: u64,
        amount_y: u64
    ) {
        emit(NewPool{ pool, amount_x, amount_y, coin_x: type_name::get<CoinX>(), coin_y: type_name::get<CoinY>() });
    }

    public(package) fun swap<CoinIn, CoinOut, T: copy + drop + store>(
        pool: address,
        amount_in: u64,
        swap_amount: T   
    ) {
        emit(Swap<CoinIn, CoinOut, T> { pool, amount_in, swap_amount });
    }

    public(package) fun update_fees(pool: address, fees: Fees) {
        emit(UpdateFees { pool, fees });
    }  
}