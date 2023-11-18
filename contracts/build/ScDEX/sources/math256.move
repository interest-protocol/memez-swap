module sc_dex::math256 {
  
  public fun diff(x: u256, y: u256): u256 {
    if (x > y) x - y else y - x
  }

  public fun div_up(a: u256, b: u256): u256 {
    if (a == 0) 0 else 1 + (a - 1) / b
  }

}