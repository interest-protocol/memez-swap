module sc_dex::math64 {

  use sc_dex::math256;

  public fun mul_div_down(x: u64, y: u64, z: u64): u64 {
    (math256::mul_div_down((x as u256), (y as u256), (z as u256)) as u64)
  }

  public fun min(a: u64, b: u64): u64 {
    if (a < b) a else b
  } 

  public fun mul_div_up(x: u64, y: u64, z: u64): u64 {
    (math256::mul_div_up((x as u256), (y as u256), (z as u256)) as u64)
  }  
}