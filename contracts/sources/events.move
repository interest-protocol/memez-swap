module amm::events {

  use sui::event::emit;

  use amm::fees::Fees;

  friend amm::auction;
  friend amm::interest_protocol_amm;

  struct NewPool<phantom Curve, phantom CoinX, phantom CoinY> has copy, drop {
    pool_address: address,
    amount_x: u64,
    amount_y: u64
  }

  struct NewAuction has copy, drop {
    pool_address: address,
    auction_address: address
  }

  struct Swap<phantom CoinIn, phantom CoinOut, T: drop + copy + store> has copy, drop {
    pool_address: address,
    amount_in: u64,
    swap_amount: T
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
    fee_x_value: u64,
    fee_y_value: u64    
  }

  struct ManagerBurn<phantom LpCoin> has copy, drop {
    pool_address: address,
    amount: u64,
    admin_amount: u64
  }

  struct ManagerFees has copy, drop {
    pool_address: address,
    manager_address: address,
    start: u64,
    end: u64,
    fees: Fees
  }

  struct UpdateFees has copy, drop {
    pool_address: address,
    fees: Fees    
  }

  struct Bid<T: store + drop + copy> has copy, drop {
    pool_address: address,
    manager: T
  }

  struct NewManager<T: store + drop> has copy, drop {
    pool_address: address,
    manager: T,
    balance: u64
  }

  public(friend) fun new_pool<Curve, CoinX, CoinY>(
    pool_address: address,
    amount_x: u64,
    amount_y: u64
  ) {
    emit(NewPool<Curve, CoinX, CoinY>{ pool_address, amount_x, amount_y });
  }

  public(friend) fun new_auction(
    pool_address: address,
    auction_address: address,
  ) {
    emit(NewAuction { pool_address, auction_address });
  }

  public(friend) fun swap<CoinIn, CoinOut, T: copy + drop + store>(
    pool_address: address,
    amount_in: u64,
    swap_amount: T   
  ) {
    emit(Swap<CoinIn, CoinOut, T> { pool_address, amount_in, swap_amount });
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
    fee_x_value: u64,
    fee_y_value: u64  
  ) {
    emit(RemoveLiquidity<CoinX, CoinY> { pool_address, amount_x, amount_y, shares, fee_x_value, fee_y_value });
  }

  public(friend) fun manager_burn<LpCoin>(pool_address: address, amount: u64, admin_amount: u64) {
    emit(ManagerBurn<LpCoin> { pool_address, amount, admin_amount });
  }  

  public(friend) fun manager_fees(
    pool_address: address,
    manager_address: address,
    start: u64,
    end: u64,
    fees: Fees    
  ) {
    emit(ManagerFees { pool_address, manager_address, start, end, fees });
  }  

  public(friend) fun update_fees(pool_address: address, fees: Fees) {
    emit(UpdateFees { pool_address, fees });
  }  

  public(friend)fun bid<T: store + drop + copy>(pool_address: address, manager: T) {
    emit( Bid<T>{ pool_address, manager });
  }  

  public(friend) fun new_manager<T: store + drop + copy>(pool_address: address, manager: T, balance: u64) {
    emit(NewManager<T> { pool_address, manager, balance });
  }  
}