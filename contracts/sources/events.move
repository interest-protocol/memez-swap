module amm::events {

    use std::type_name::{Self, TypeName};

    use sui::event::emit;

    use amm::fees::Fees;

    public struct NewPool has copy, drop {
        pool_address: address,
        amount_x: u64,
        amount_y: u64,
        curve: TypeName,
        coin_x: TypeName,
        coin_y: TypeName
    }

    public struct NewAuction has copy, drop {
        pool_address: address,
        auction_address: address
    }

    public struct Swap<phantom CoinIn, phantom CoinOut, T: drop + copy + store> has copy, drop {
        pool_address: address,
        amount_in: u64,
        swap_amount: T
    }

    public struct AddLiquidity<phantom CoinX, phantom CoinY> has copy, drop {
        pool_address: address,
        amount_x: u64,
        amount_y: u64,
        shares: u64  
    }

    public struct RemoveLiquidity<phantom CoinX, phantom CoinY> has copy, drop {
        pool_address: address,
        amount_x: u64,
        amount_y: u64,
        shares: u64   
    }

    public struct UpdateFees has copy, drop {
        pool_address: address,
        fees: Fees    
    }

    public(package) fun new_pool<Curve, CoinX, CoinY>(
        pool_address: address,
        amount_x: u64,
        amount_y: u64
    ) {
        emit(NewPool{ pool_address, amount_x, amount_y, curve: type_name::get<Curve>(), coin_x: type_name::get<CoinX>(), coin_y: type_name::get<CoinY>() });
    }

    public(package) fun new_auction(
        pool_address: address,
        auction_address: address,
    ) {
        emit(NewAuction { pool_address, auction_address });
    }

    public(package) fun swap<CoinIn, CoinOut, T: copy + drop + store>(
        pool_address: address,
        amount_in: u64,
        swap_amount: T   
    ) {
        emit(Swap<CoinIn, CoinOut, T> { pool_address, amount_in, swap_amount });
    }

    public(package) fun add_liquidity<CoinX, CoinY>(
        pool_address: address,
        amount_x: u64,
        amount_y: u64,
        shares: u64    
    ) {
        emit(AddLiquidity<CoinX, CoinY> { pool_address, amount_x, amount_y, shares });
    }

    public(package) fun remove_liquidity<CoinX, CoinY>(
        pool_address: address,
        amount_x: u64,
        amount_y: u64,
        shares: u64
    ) {
        emit(RemoveLiquidity<CoinX, CoinY> { pool_address, amount_x, amount_y, shares });
    }

    public(package) fun update_fees(pool_address: address, fees: Fees) {
        emit(UpdateFees { pool_address, fees });
    }  
}