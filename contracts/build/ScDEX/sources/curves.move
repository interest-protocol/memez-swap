module sc_dex::curves {
  use std::type_name;

  /**********************************************************************************************
  // UniswapV2 invariant                                                                       //
  // k = invariant                                                                             //
  // x = Balance of X                  k = x * y                                               //
  // y = Balance of Y                                                                          //
  **********************************************************************************************/
   struct Volatile {}
   
  /**********************************************************************************************
  // Solidly invariant                                                                         //
  // k = invariant                                                                             //
  // x = Balance of X                  k = x^3y + xy^3                                         //
  // y = Balance of Y                                                                          //
  **********************************************************************************************/
   struct Stable {}

   public fun is_volatile<Curve>(): bool {
    type_name::get<Volatile>() == type_name::get<Curve>()
   }
}