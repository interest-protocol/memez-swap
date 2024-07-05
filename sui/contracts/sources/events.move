module amm::memez_amm_events {

    use std::type_name::{Self, TypeName};

    use sui::event::emit;

    use amm::memez_amm_fees::Fees;

    public struct NewPool has copy, drop {
        pool: address,
        deployer: address,
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

    public struct TakeAdminFees has copy, drop {
        pool: address,
        amount_x: u64,
        amount_y: u64
    }

    public struct TakeDeployerFees has copy, drop {
        pool: address,
        amount_x: u64,
        amount_y: u64
    }

    public(package) fun new_pool<CoinX, CoinY>(
        pool: address,
        deployer: address,
        amount_x: u64,
        amount_y: u64
    ) {
        emit(NewPool{ pool, deployer, amount_x, amount_y, coin_x: type_name::get<CoinX>(), coin_y: type_name::get<CoinY>() });
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

    public(package) fun take_admin_fees(pool: address, amount_x: u64, amount_y: u64) {
        emit(TakeAdminFees { pool, amount_x, amount_y });
    } 

    public(package) fun take_deployer_fees(pool: address, amount_x: u64, amount_y: u64) {
        emit(TakeDeployerFees { pool, amount_x, amount_y });
    }  
}