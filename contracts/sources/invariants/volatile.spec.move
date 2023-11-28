spec sc_dex::volatile {

  spec invariant_ {
    ensures result == x * y;
  }

  spec get_amount_in {    
    aborts_if balance_in == 0 || balance_out == 0 || coin_out_amount == 0 || coin_out_amount >= balance_out;

    ensures (result + balance_in) * (balance_out - coin_out_amount) >= balance_in * balance_out; 
  }

  spec get_amount_out {
    aborts_if coin_in_amount == 0 || balance_in == 0 || balance_out == 0;
    
    ensures (balance_out - result) * (balance_in + coin_in_amount) >= balance_in * balance_out;
  }
}