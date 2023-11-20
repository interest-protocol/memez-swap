module sc_dex::events {

  use sui::object::ID;
  use sui::event::emit;

  friend sc_dex::sui_coins_amm;

  struct NewPool<phantom Curve, phantom CoinX, phantom CoinY> has copy, drop {
    pool_id: ID,
    amount_x: u64,
    amount_y: u64
  }

  struct Swap<phantom CoinIn, phantom CoinOut> has copy, drop {
    pool_id: ID,
    amount_in: u64,
    amount_out: u64,
    fee_in: u64,
    fee_out: u64
  }

  struct AddLiquidity<phantom CoinX, phantom CoinY> has copy, drop {
    pool_id: ID,
    amount_x: u64,
    amount_y: u64,
    shares: u64  
  }

  struct RemoveLiquidity<phantom CoinX, phantom CoinY> has copy, drop {
    pool_id: ID,
    amount_x: u64,
    amount_y: u64,
    shares: u64  
  }

  public(friend) fun new_pool<Curve, CoinX, CoinY>(
    pool_id: ID,
    amount_x: u64,
    amount_y: u64
  ) {
    emit(NewPool<Curve, CoinX, CoinY>{ pool_id, amount_x, amount_y });
  }

  public(friend) fun swap<CoinIn, CoinOut>(
    pool_id: ID,
    amount_in: u64,
    amount_out: u64,
    fee_in: u64,
    fee_out: u64    
  ) {
    emit(Swap<CoinIn, CoinOut> { pool_id, amount_in, amount_out, fee_in, fee_out });
  }

  public(friend) fun add_liquidity<CoinX, CoinY>(
    pool_id: ID,
    amount_x: u64,
    amount_y: u64,
    shares: u64    
  ) {
    emit(AddLiquidity<CoinX, CoinY> { pool_id, amount_x, amount_y, shares });
  }

  public(friend) fun remove_liquidity<CoinX, CoinY>(
    pool_id: ID,
    amount_x: u64,
    amount_y: u64,
    shares: u64    
  ) {
    emit(RemoveLiquidity<CoinX, CoinY> { pool_id, amount_x, amount_y, shares });
  }
}