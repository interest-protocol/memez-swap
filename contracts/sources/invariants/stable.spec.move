spec sc_dex::stable {
  spec invariant_ {    
    pragma aborts_if_is_partial = true;
    
    aborts_if decimals_x == 0;
    aborts_if decimals_y == 0;

    let x = (x * PRECISION) / decimals_x;
    let y = (y * PRECISION) / decimals_y;

    let a = (x * y) / PRECISION; 
    let b = ((x * x) / PRECISION + (y * y) / PRECISION);

    ensures result == ((a * b) / PRECISION);
  }

  spec f {
    let a = (x * y) / PRECISION; 
    let b = ((x * x) / PRECISION + (y * y) / PRECISION);
    
    ensures result == ((a * b) / PRECISION);
  }  

  spec d {
    ensures result == (3 * x0 * ((y * y) / PRECISION)) /
            PRECISION +
            ((((x0 * x0) / PRECISION) * x0) / PRECISION);
  }
}