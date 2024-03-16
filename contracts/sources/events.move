module amm::events {

  use sui::event::emit;

  friend amm::interest_protocol_amm;

  struct NewPool<phantom Curve, phantom CoinX, phantom CoinY> has copy, drop {
    pool_address: address,
    amount_x: u64,
    amount_y: u64
  }

  struct Swap<phantom CoinIn, phantom CoinOut, T: drop + copy + store> has copy, drop {
    pool_address: address,
    amount_in: u64,
    amount_out: u64,
    fees: T
  }

  struct AddLiquidity<phantom CoinX, phantom CoinY> has copy, drop {
    pool_address: address,
    amount_x: u64,
    amount_y: u64,
    shares: u64  
  }

  struct RemoveLiquidity<phantom CoinX, phantom CoinY> has copy, drop {
    pool_address: address,
    amount_x: u64,
    amount_y: u64,
    shares: u64,
    manager_amount_x: u64,
    manager_amount_y: u64    
  }

  public(friend) fun new_pool<Curve, CoinX, CoinY>(
    pool_address: address,
    amount_x: u64,
    amount_y: u64
  ) {
    emit(NewPool<Curve, CoinX, CoinY>{ pool_address, amount_x, amount_y });
  }

  public(friend) fun swap<CoinIn, CoinOut, T: copy + drop + store>(
    pool_address: address,
    amount_in: u64,
    amount_out: u64,
    fees: T   
  ) {
    emit(Swap<CoinIn, CoinOut, T> { pool_address, amount_in, amount_out, fees });
  }

  public(friend) fun add_liquidity<CoinX, CoinY>(
    pool_address: address,
    amount_x: u64,
    amount_y: u64,
    shares: u64    
  ) {
    emit(AddLiquidity<CoinX, CoinY> { pool_address, amount_x, amount_y, shares });
  }

  public(friend) fun remove_liquidity<CoinX, CoinY>(
    pool_address: address,
    amount_x: u64,
    amount_y: u64,
    shares: u64,
    manager_amount_x: u64,
    manager_amount_y: u64    
  ) {
    emit(RemoveLiquidity<CoinX, CoinY> { pool_address, amount_x, amount_y, shares, manager_amount_x, manager_amount_y });
  }
}