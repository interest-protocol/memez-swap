module sc_dex::stable {

  use sc_dex::errors;
  use sc_dex::math256::{div_up, diff};

  const PRECISION: u256 = 1_000_000_000_000_000_000;

  public fun invariant_(
    x: u64, 
    y: u64,
    decimals_x: u64,
    decimals_y: u64
  ): u256 {
    f(
      ((x as u256) * PRECISION) / (decimals_x as u256),
      ((y as u256) * PRECISION) / (decimals_y as u256)
    )
  }

  public fun get_amount_in(
    coin_amount: u64,
    balance_x: u64,
    balance_y:u64,
    decimals_x: u64,
    decimals_y: u64,
    is_x: bool
  ): u64 {
    let (coin_amount, balance_x, balance_y, decimals_x, decimals_y) =
      (
        (coin_amount as u256),
        (balance_x as u256),
        (balance_y as u256),
        (decimals_x as u256),
        (decimals_y as u256)
      );

    let reserve_x = (balance_x * PRECISION) / decimals_x;
    let reserve_y = (balance_y * PRECISION) / decimals_y;
    
    assert!(reserve_x != 0 && reserve_y != 0, errors::insufficient_liquidity());

    let amount_out = (coin_amount * PRECISION) / if (is_x) { decimals_x } else {decimals_y };

    assert!(amount_out != 0, errors::no_zero_coin());

    let k = f(reserve_x, reserve_y);

    let y = if (is_x) 
                y(reserve_x - amount_out, k, reserve_y) -  reserve_y
              else 
                 y( reserve_y - amount_out, k, reserve_x) - reserve_x;

    (div_up((y * if (is_x) { decimals_y } else { decimals_x }), PRECISION) as u64)  
  }   

  public fun get_amount_out(
    coin_amount: u64,
    balance_x: u64,
    balance_y:u64,
    decimals_x: u64,
    decimals_y: u64,
    is_x: bool
  ): u64 {
    let (coin_amount, balance_x, balance_y, decimals_x, decimals_y) =
      (
        (coin_amount as u256),
        (balance_x as u256),
        (balance_y as u256),
        (decimals_x as u256),
        (decimals_y as u256)
      );

    let reserve_x = (balance_x * PRECISION) / decimals_x;
    let reserve_y = (balance_y * PRECISION) / decimals_y;

    assert!(reserve_x != 0 && reserve_y != 0, errors::insufficient_liquidity());

    let amount_in = (coin_amount * PRECISION) / if (is_x) { decimals_x } else {decimals_y };

    assert!(amount_in != 0, errors::no_zero_coin());

    let k = f(reserve_x, reserve_y);

    let y = if (is_x) 
                reserve_y - y(amount_in + reserve_x, k, reserve_y) 
              else 
                reserve_x - y(amount_in + reserve_y, k, reserve_x);

    ((y * if (is_x) { decimals_y } else { decimals_x }) / PRECISION as u64)   
  } 

  fun y(x0: u256, xy: u256, y: u256): u256 {
    let i = 0;
    while (255 > i) {
      let y_prev = y;
      let k = f(x0, y);
        
      y = if (k < xy)
            y + ((((xy - k) * PRECISION) / d(x0, y)) + 1) // round up
          else
            y - ((k - xy) * PRECISION) / d(x0, y);

      if (1 >= diff(y, y_prev)) return y;
      
      i = i + 1;
    };
    y
  }

  public fun d(x0: u256, y: u256): u256 {
    (3 * x0 * ((y * y) / PRECISION)) /
            PRECISION +
            ((((x0 * x0) / PRECISION) * x0) / PRECISION)
  }

  public fun f(x: u256, y: u256): u256 {
    let a = (x * y) / PRECISION; // xy
    let b = ((x * x) / PRECISION + (y * y) / PRECISION); // x^2 + y^2
    (a * b) / PRECISION // x^3y + y^3x  
  }
}