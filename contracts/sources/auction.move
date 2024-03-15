module amm::auction {
  // === Imports ===

  use sui::coin::{Self, Coin};
  use sui::object::{Self, UID};
  use sui::clock::{Self, Clock};
  use sui::table::{Self, Table};
  use sui::tx_context::TxContext;
  use sui::balance::{Self, Balance};
  use sui::transfer::{share_object, public_transfer};

  use amm::admin::Admin;

  use suitears::math64;
  use suitears::fixed_point_roll as fixed_point;

  // === Friends ===

  friend amm::interest_protocol_amm;

  // === Errors ===

  use amm::errors;

  // === Constants ===

  //@dev 10 seconds
  const INITLAL_K: u64 = 10;
  const INITIAL_MINIMUM_BID_INCREMENT: u64 = 10000000;
  const NO_MANAGER: address = @0x0;

  // === Structs ===
  
  struct Auction<phantom LpCoin> has key {
    id: UID,
    pool_address: address,
    k: u64,
    active_manager: Manager,
    next_manager: Manager,
    minimum_bid_increment: u64,
    deposits: Table<address, Balance<LpCoin>>,
    burn_wallet: Balance<LpCoin>
  }

  struct Manager has store, copy, drop {
    start: u64,
    end: u64,
    address: address,
    rent_per_second: u64,
  }

  struct Account has key, store {
    id: UID,
    /// `sui::object::uid_to_address` of {Account}
    address: address
  }

  // === Public-Mutative Functions ===

  public fun new_account(ctx: &mut TxContext): Account {
    let id = object::new(ctx);
    let address = object::uid_to_address(&id);
    Account {
      id,
      address
    }
  }  

  public fun destroy_account(account: Account) {
    let Account { id, address: _ } = account;
    object::delete(id);
  }

  public fun bid<LpCoin: drop>(
    self: &mut Auction<LpCoin>,
    clock: &Clock, 
    account: &Account, 
    deposit: Coin<LpCoin>, 
    period: u64,
    ctx: &mut TxContext
  ) {
    let deposit_value = coin::value(&deposit);
    let duration = period + self.k;
    let rent_per_second = deposit_value / (period + self.k);
    
    assert!(rent_per_second != 0, errors::invalid_rent_per_second());
    
    let current_timestamp = clock_timestamp_s(clock);

    let is_usurping_next_manager = self.next_manager.address != NO_MANAGER;
    let active_manager_end = math64::max(self.active_manager.end, current_timestamp);

    if (is_usurping_next_manager) {
      let minimum_increment = fixed_point::mul_up(self.minimum_bid_increment, self.next_manager.rent_per_second);
      assert!(rent_per_second >= self.next_manager.rent_per_second + minimum_increment, errors::invalid_rent_per_second());

      public_transfer(
        coin::from_balance(
          balance::withdraw_all(table::borrow_mut(&mut self.deposits, self.next_manager.address)), 
          ctx
        ),
        self.next_manager.address
      );
    };

    self.next_manager.address = account.address;
    self.next_manager.start = active_manager_end + self.k;
    self.next_manager.end = active_manager_end + self.k + duration;
    self.next_manager.rent_per_second = rent_per_second; 

    if (current_timestamp > self.active_manager.end) activate_impl(self);

    deposit(self, account, deposit);
  }

  public fun activate<LpCoin: drop>(self: &mut Auction<LpCoin>, clock: &Clock) {
    let current_timestamp = clock_timestamp_s(clock);

    assert!(current_timestamp > self.active_manager.end, errors::there_is_an_active_manager());
    assert!(self.next_manager.address != NO_MANAGER, errors::invalid_next_manager());

    activate_impl(self);
  }

  // === Public-View Functions ===

  public fun assert_is_active<LpCoin>(self: &mut Auction<LpCoin>, clock: &Clock, account: &Account) {
    let current_timestamp = clock_timestamp_s(clock);

    assert!(
      self.active_manager.start >= current_timestamp
      && current_timestamp > self.active_manager.end 
      && self.active_manager.address == account.address,
      errors::invalid_active_account()
    );
  }

  public fun active_manager_start<LpCoin>(self: &Auction<LpCoin>): u64 {
    self.active_manager.start
  }

  public fun active_manager_end<LpCoin>(self: &Auction<LpCoin>): u64 {
    self.active_manager.end
  }

  public fun active_manager_address<LpCoin>(self: &Auction<LpCoin>): address {
    self.active_manager.address
  }

  public fun active_manager_rent_per_second<LpCoin>(self: &Auction<LpCoin>): u64 {
    self.active_manager.rent_per_second
  }

  // === Admin Functions ===

  public fun set_k<LpCoin: drop>(_: &Admin, self: &mut Auction<LpCoin>, k: u64) {
    self.k = k
  }

  public fun set_minimum_bid_increment<LpCoin: drop>(_: &Admin, self: &mut Auction<LpCoin>, minimum_bid_increment: u64) {
    self.minimum_bid_increment = minimum_bid_increment;
  }

  // === Public-Friend Functions ===

  public(friend) fun new_auction<LpCoin>(pool_address: address, ctx: &mut TxContext) {
    let auction = Auction<LpCoin> {
      id: object::new(ctx),
      pool_address,
      k: INITLAL_K,
      minimum_bid_increment: INITIAL_MINIMUM_BID_INCREMENT,
      deposits: table::new(ctx),
      active_manager: no_manager(),
      next_manager: no_manager(),
      burn_wallet: balance::zero()
    };

    share_object(auction);
  }

  public(friend) fun burn_wallet_mut<LpCoin>(self: &mut Auction<LpCoin>): &mut Balance<LpCoin> {
    &mut self.burn_wallet
  }

  // === Private Functions ===

  fun activate_impl<LpCoin: drop>(self: &mut Auction<LpCoin>) {
    self.active_manager = self.next_manager;
    self.next_manager = no_manager();    

    let deposit = balance::withdraw_all(table::borrow_mut(&mut self.deposits, self.active_manager.address));
    balance::join(&mut self.burn_wallet, deposit);
  }

  fun clock_timestamp_s(c: &Clock): u64 {
    clock::timestamp_ms(c) / 1000
  }

  fun no_manager(): Manager {
    Manager {
        start: 0,
        end: 0,
        address: NO_MANAGER,
        rent_per_second: 0,
    }
  }

  fun deposit<LpCoin: drop>(self: &mut Auction<LpCoin>, account: &Account, deposit: Coin<LpCoin>) {

    if (!table::contains(&self.deposits, account.address))
      table::add(&mut self.deposits, account.address, balance::zero<LpCoin>());

    balance::join(table::borrow_mut(&mut self.deposits, account.address), coin::into_balance(deposit));
  }

  // === Test Functions ===  
}