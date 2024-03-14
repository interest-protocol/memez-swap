module amm::manager {
  // === Imports ===

  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;

  // === Friends ===

  // === Structs ===

  struct Manager has key, store {
    id: UID,
    start: u64,
    end: u64
  }

  // === Public-Mutative Functions ===

  public fun new(ctx: &mut TxContext): Manager {
    Manager {
      id: object::new(ctx),
      start: 0,
      end: 0
    }
  }

  public fun destroy(self: Manager) {
    let Manager { id, start: _, end: _ } = self;

    object::delete(id);
  }

  // === Public-View Functions ===

  public fun start(self: &Manager): u64 {
    self.start
  }

  public fun end(self: &Manager): u64 {
    self.end
  }

  // === Public-Friend Functions ===

  public(friend) fun set_time(self: &mut Manager, start: u64, end: u64) {
    self.start = start;
    self.end = end;
  }
}