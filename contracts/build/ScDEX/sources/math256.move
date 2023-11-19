module sc_dex::math256 {
  
  public fun diff(x: u256, y: u256): u256 {
    if (x > y) x - y else y - x
  }

  public fun div_up(a: u256, b: u256): u256 {
    if (a == 0) 0 else 1 + (a - 1) / b
  }

  public fun mul_div_down(x: u256, y: u256, z: u256): u256 {
    x * y / z
  }

  public fun mul_div_up(x: u256, y: u256, z: u256): u256 {
    let r = mul_div_down(x, y, z);
    r + if ((x * y) % z != 0) 1 else 0
  }

  public fun sqrt_down(a: u256): u256 {
    if (a == 0) return 0;

    let result = 1 << ((log2_down(a) >> 1) as u8);

    result = (result + a / result) >> 1;
    result = (result + a / result) >> 1;
    result = (result + a / result) >> 1;
    result = (result + a / result) >> 1;
    result = (result + a / result) >> 1;
    result = (result + a / result) >> 1;
    result = (result + a / result) >> 1;

    min(result, a / result)
  }  

  public fun min(a: u256, b: u256): u256 {
    if (a < b) a else b
  }  

  public fun log2_down(value: u256): u8 {
        let result = 0;
        if (value >> 128 > 0) {
          value = value >> 128;
          result = result + 128;
        };
        
        if (value >> 64 > 0) {
            value = value >> 64;
            result = result + 64;
        };
        
        if (value >> 32 > 0) {
          value = value >> 32;
          result = result + 32;
        };
        
        if (value >> 16 > 0) {
            value = value >> 16;
            result = result + 16;
        };
        
        if (value >> 8 > 0) {
            value = value >> 8;
            result = result + 8;
        };
        
        if (value >> 4 > 0) {
            value = value >> 4;
            result = result + 4;
        };
        
        if (value >> 2 > 0) {
            value = value >> 2;
            result = result + 2;
        };
        
        if (value >> 1 > 0) 
          result = result + 1;

       result
    }  
}