module amm::auction {
  // === Imports ===
  use std::option::{Self, Option};

  use sui::coin::{Self, Coin};
  use sui::object::{Self, UID};
  use sui::clock::{Self, Clock};
  use sui::table::{Self, Table};
  use sui::balance::{Self, Balance};
  use sui::transfer::public_transfer;
  use sui::tx_context::{Self, TxContext};

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
  
  struct Auction<phantom LpCoin: drop> has key {
    id: UID,
    pool_address: address,
    k: u64,
    active_manager: Manager,
    next_manager: Manager,
    minimum_bid_increment: u64,
    deposits: Table<address, Balance<LpCoin>>,
  }

  struct Manager has store {
    start: u64,
    end: u64,
    account_address: address,
    rent_per_second: u64,
  }

  struct Account has key, store {
    id: UID,
  }

  // === Public-Mutative Functions ===

  public fun new_account(ctx: &mut TxContext): Account {
    Account {
      id: object::new(ctx)
    }
  }  

  public fun destroy_account(account: Account) {
    let Account { id } = account;
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

    let is_usurping = self.next_manager.start > current_timestamp;
    let end = math64::max(self.active_manager.end, current_timestamp);

    if (is_usurping) {
      let minimum_increment = fixed_point::mul_up(self.minimum_bid_increment, self.next_manager.rent_per_second);
      assert!(rent_per_second >= self.next_manager.rent_per_second + minimum_increment, errors::invalid_rent_per_second());

      public_transfer(
        coin::from_balance(
          balance::withdraw_all(table::borrow_mut(&mut self.deposits, self.next_manager.account_address)), 
          ctx
        ),
        self.next_manager.account_address
      );
    };

    set_manager(
      &mut self.next_manager,
      object::uid_to_address(&account.id),
      rent_per_second,
      end + self.k,
      end + duration
    );  
  }

  // === Public-View Functions ===

  // === Admin Functions ===

  public fun set_k<LpCoin: drop>(_: &Admin, self: &mut Auction<LpCoin>, k: u64) {
    self.k = k
  }

  public fun set_minimum_bid_increment<LpCoin: drop>(_: &Admin, self: &mut Auction<LpCoin>, minimum_bid_increment: u64) {
    self.minimum_bid_increment = minimum_bid_increment;
  }

  // === Public-Friend Functions ===

  public(friend) fun new_auction<LpCoin: drop>(pool_address: address, ctx: &mut TxContext): Auction<LpCoin> {
    Auction {
      id: object::new(ctx),
      pool_address,
      k: INITLAL_K,
      minimum_bid_increment: INITIAL_MINIMUM_BID_INCREMENT,
      deposits: table::new(ctx),
      active_manager: Manager {
        start: 0,
        end: 0,
        account_address: NO_MANAGER,
        rent_per_second: 0,
      },
      next_manager: Manager {
        start: 0,
        end: 0,
        account_address: NO_MANAGER,
        rent_per_second: 0,
      }
    }
  }

  // === Private Functions ===

  fun set_manager(manager: &mut Manager, account_address: address, rent_per_second: u64, start: u64, end: u64) {
    manager.account_address = account_address;
    manager.start = start;
    manager.end = end;
    manager.rent_per_second = rent_per_second;
  }

  fun clock_timestamp_s(c: &Clock): u64 {
    clock::timestamp_ms(c) / 1000
  }

  // === Test Functions ===  
}