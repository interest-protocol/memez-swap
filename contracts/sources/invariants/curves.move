module sc_dex::curves {
  use std::type_name;

  use sc_dex::errors;

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

   public fun assert_is_curve<Curve>() {
    let curve_type_name = type_name::get<Curve>();
    assert!(
      type_name::get<Volatile>() == curve_type_name || 
      type_name::get<Stable>() == curve_type_name, 
      errors::invalid_curve());
   }

   public fun is_volatile<Curve>(): bool {
    type_name::get<Volatile>() == type_name::get<Curve>()
   }

  public fun is_stable<Curve>(): bool {
    type_name::get<Stable>() == type_name::get<Curve>()
   }
}