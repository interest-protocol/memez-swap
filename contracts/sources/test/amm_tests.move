#[test_only]
module sc_dex::sui_coins_amm_tests {
  use std::option;
  use std::string::{utf8, to_ascii};

  use sui::table;
  use sui::test_utils::assert_eq;
  use sui::coin::{Self, mint_for_testing, burn_for_testing, TreasuryCap, CoinMetadata};
  use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};

  use sc_dex::fees;
  use sc_dex::quote;
  use sc_dex::stable;
  use sc_dex::math256;
  use sc_dex::btc::BTC;
  use sc_dex::eth::ETH;
  use sc_dex::volatile;
  use sc_dex::usdc::USDC;
  use sc_dex::usdt::USDT;
  use sc_dex::admin::{Self, Admin};
  use sc_dex::curves::{Volatile, Stable};
  use sc_dex::sc_btce_eth::{Self, SC_BTCE_ETH};
  use sc_dex::sc_v_eth_usdc::{Self, SC_V_ETH_USDC};
  use sc_dex::sc_s_usdc_usdt::{Self, SC_S_USDC_USDT};
  use sc_dex::sui_coins_amm::{Self, Registry, SuiCoinsPool};
  use sc_dex::test_utils::{people, scenario, deploy_coins, deploy_eth_usdc_pool, deploy_usdc_usdt_pool};

  const PRECISION: u256 = 1_000_000_000_000_000_000;
  const MINIMUM_LIQUIDITY: u64 = 100;
  const USDC_DECIMAL_SCALAR: u64 = 1_000_000;
  const ETH_DECIMAL_SCALAR: u64 = 1_000_000_000;
  const USDT_DECIMAL_SCALAR: u64 = 1_000_000_000;
  const INITIAL_STABLE_FEE_PERCENT: u256 = 250_000_000_000_000; // 0.025%
  const INITIAL_VOLATILE_FEE_PERCENT: u256 = 3_000_000_000_000_000; // 0.3%
  const INITIAL_ADMIN_FEE: u256 = 200_000_000_000_000_000; // 20%
  const FLASH_LOAN_FEE_PERCENT: u256 = 5_000_000_000_000_000; //0.5% 
  const MAX_FEE_PERCENT: u256 = 20_000_000_000_000_000; // 2%

  #[test]
  fun test_new_pool() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up_test(test);  
    
    next_tx(test, alice);
    {
      sc_v_eth_usdc::init_for_testing(ctx(test));
      sc_s_usdc_usdt::init_for_testing(ctx(test));
    };


    let eth_amount = 10 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 25000 * USDC_DECIMAL_SCALAR;
    let expected_shares = (math256::sqrt_down((eth_amount as u256) * (usdc_amount as u256)) as u64);

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let lp_coin_cap = test::take_from_sender<TreasuryCap<SC_V_ETH_USDC>>(test);
      let eth_metadata = test::take_shared<CoinMetadata<ETH>>(test);
      let usdc_metadata = test::take_shared<CoinMetadata<USDC>>(test);
      let lp_coin_metadata = test::take_shared<CoinMetadata<SC_V_ETH_USDC>>(test);
      
      assert_eq(table::is_empty(sui_coins_amm::borrow_pools(&registry)), true);
      

      let lp_coin = sui_coins_amm::new_pool<ETH, USDC, SC_V_ETH_USDC>(
        &mut registry,
        mint_for_testing(eth_amount, ctx(test)),
        mint_for_testing(usdc_amount, ctx(test)),
        lp_coin_cap,
        &eth_metadata,
        &usdc_metadata,
        &mut lp_coin_metadata,
        true,
        ctx(test)
      );

      assert_eq(coin::get_symbol(&lp_coin_metadata), to_ascii(utf8(b"sc-v-ETH-USDC")));
      assert_eq(coin::get_name(&lp_coin_metadata), utf8(b"sc volatile Ether USD Coin Lp Coin"));
      assert_eq(sui_coins_amm::exists_<Volatile, ETH, USDC>(&registry), true);
      assert_eq(burn_for_testing(lp_coin), expected_shares);

      test::return_shared(eth_metadata);
      test::return_shared(usdc_metadata);
      test::return_shared(lp_coin_metadata);
      test::return_shared(registry);
    };

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Volatile, ETH, USDC>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));

      assert_eq(sui_coins_amm::lp_coin_supply<ETH, USDC, SC_V_ETH_USDC>(&pool), expected_shares + MINIMUM_LIQUIDITY);
      assert_eq(sui_coins_amm::balance_x<ETH, USDC, SC_V_ETH_USDC>(&pool), eth_amount);
      assert_eq(sui_coins_amm::balance_y<ETH, USDC, SC_V_ETH_USDC>(&pool), usdc_amount);
      assert_eq(sui_coins_amm::decimals_x<ETH, USDC, SC_V_ETH_USDC>(&pool), ETH_DECIMAL_SCALAR);
      assert_eq(sui_coins_amm::decimals_y<ETH, USDC, SC_V_ETH_USDC>(&pool), USDC_DECIMAL_SCALAR);
      assert_eq(sui_coins_amm::volatile<ETH, USDC, SC_V_ETH_USDC>(&pool), true);
      assert_eq(sui_coins_amm::seed_liquidity<ETH, USDC, SC_V_ETH_USDC>(&pool), MINIMUM_LIQUIDITY);
      assert_eq(sui_coins_amm::locked<ETH, USDC, SC_V_ETH_USDC>(&pool), false);
      assert_eq(sui_coins_amm::admin_balance_x<ETH, USDC, SC_V_ETH_USDC>(&pool), 0);
      assert_eq(sui_coins_amm::admin_balance_y<ETH, USDC, SC_V_ETH_USDC>(&pool), 0);

      let fees = sui_coins_amm::fees<ETH, USDC, SC_V_ETH_USDC>(&pool);

      assert_eq(fees::fee_in_percent(&fees), INITIAL_VOLATILE_FEE_PERCENT);
      assert_eq(fees::fee_out_percent(&fees), INITIAL_VOLATILE_FEE_PERCENT);
      assert_eq(fees::admin_fee_percent(&fees), INITIAL_ADMIN_FEE);

      test::return_shared(registry);
      test::return_shared(pool);
    };

    let usdc_amount = 7777 * USDC_DECIMAL_SCALAR;
    let usdt_amount = 7777 * USDT_DECIMAL_SCALAR;
    let expected_shares = (math256::sqrt_down((usdt_amount as u256) * (usdc_amount as u256)) as u64);

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let lp_coin_cap = test::take_from_sender<TreasuryCap<SC_S_USDC_USDT>>(test);
      let usdc_metadata = test::take_shared<CoinMetadata<USDC>>(test);
      let usdt_metadata = test::take_shared<CoinMetadata<USDT>>(test);
      let lp_coin_metadata = test::take_shared<CoinMetadata<SC_S_USDC_USDT>>(test);
      
      assert_eq(table::is_empty(sui_coins_amm::borrow_pools(&registry)), false);
      assert_eq(table::length(sui_coins_amm::borrow_pools(&registry)), 1);
      

      let lp_coin = sui_coins_amm::new_pool<USDC, USDT, SC_S_USDC_USDT>(
        &mut registry,
        mint_for_testing(usdc_amount, ctx(test)),
        mint_for_testing(usdt_amount, ctx(test)),
        lp_coin_cap,
        &usdc_metadata,
        &usdt_metadata,
        &mut lp_coin_metadata,
        false,
        ctx(test)
      );

      assert_eq(coin::get_symbol(&lp_coin_metadata), to_ascii(utf8(b"sc-s-USDC-USDT")));
      assert_eq(coin::get_name(&lp_coin_metadata), utf8(b"sc stable USD Coin USD Tether Lp Coin"));
      assert_eq(sui_coins_amm::exists_<Stable, USDC, USDT>(&registry), true);
      assert_eq(burn_for_testing(lp_coin), expected_shares);

      test::return_shared(usdt_metadata);
      test::return_shared(usdc_metadata);
      test::return_shared(lp_coin_metadata);
      test::return_shared(registry);
    };

    next_tx(test, alice);
    {      
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Stable, USDC, USDT>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));

      assert_eq(sui_coins_amm::lp_coin_supply<USDC, USDT, SC_S_USDC_USDT>(&pool), expected_shares + MINIMUM_LIQUIDITY);
      assert_eq(sui_coins_amm::balance_x<USDC, USDT, SC_S_USDC_USDT>(&pool), usdc_amount);
      assert_eq(sui_coins_amm::balance_y<USDC, USDT, SC_S_USDC_USDT>(&pool), usdt_amount);
      assert_eq(sui_coins_amm::decimals_x<USDC, USDT, SC_S_USDC_USDT>(&pool), USDC_DECIMAL_SCALAR);
      assert_eq(sui_coins_amm::decimals_y<USDC, USDT, SC_S_USDC_USDT>(&pool), USDT_DECIMAL_SCALAR);
      assert_eq(sui_coins_amm::volatile<USDC, USDT, SC_S_USDC_USDT>(&pool), false);
      assert_eq(sui_coins_amm::stable<USDC, USDT, SC_S_USDC_USDT>(&pool), true);
      assert_eq(sui_coins_amm::seed_liquidity<USDC, USDT, SC_S_USDC_USDT>(&pool), MINIMUM_LIQUIDITY);
      assert_eq(sui_coins_amm::locked<USDC, USDT, SC_S_USDC_USDT>(&pool), false);
      assert_eq(sui_coins_amm::admin_balance_x<USDC, USDT, SC_S_USDC_USDT>(&pool), 0);
      assert_eq(sui_coins_amm::admin_balance_y<USDC, USDT, SC_S_USDC_USDT>(&pool), 0); 

      let fees = sui_coins_amm::fees<USDC, USDT, SC_S_USDC_USDT>(&pool);

      assert_eq(fees::fee_in_percent(&fees), INITIAL_STABLE_FEE_PERCENT);
      assert_eq(fees::fee_out_percent(&fees), INITIAL_STABLE_FEE_PERCENT);
      assert_eq(fees::admin_fee_percent(&fees), INITIAL_ADMIN_FEE);

      test::return_shared(registry);
      test::return_shared(pool);
    };
    
    test::end(scenario);
  }

  #[test]
  fun test_volatile_swap() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    next_tx(test, alice);
    {
      admin::init_for_testing(ctx(test));
      sui_coins_amm::init_for_testing(ctx(test));
    };

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(test, eth_amount, usdc_amount);

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Volatile, ETH, USDC>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));
      let pool_fees = sui_coins_amm::fees<ETH, USDC, SC_V_ETH_USDC>(&pool);

      let amount_in = 3 * ETH_DECIMAL_SCALAR;
      let amount_in_fee = fees::get_fee_in_amount(&pool_fees, amount_in);
      let admin_in_fee = fees::get_admin_amount(&pool_fees, amount_in_fee);
      let expected_amount_out = volatile::get_amount_out(amount_in - amount_in_fee, eth_amount, usdc_amount);
      let amount_out_fee = fees::get_fee_out_amount(&pool_fees, expected_amount_out);
      let admin_out_fee = fees::get_admin_amount(&pool_fees, amount_out_fee);
      let expected_amount_out = expected_amount_out - amount_out_fee; 

      let usdc_coin = sui_coins_amm::swap<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool,
        mint_for_testing(amount_in, ctx(test)),
        expected_amount_out,
        ctx(test)
      );

      assert_eq(burn_for_testing(usdc_coin), expected_amount_out);
      assert_eq(sui_coins_amm::balance_x<ETH, USDC, SC_V_ETH_USDC>(&pool), eth_amount + amount_in - admin_in_fee);
      assert_eq(sui_coins_amm::balance_y<ETH, USDC, SC_V_ETH_USDC>(&pool), usdc_amount - (expected_amount_out + admin_out_fee));
      assert_eq(sui_coins_amm::admin_balance_x<ETH, USDC, SC_V_ETH_USDC>(&pool), admin_in_fee);
      assert_eq(sui_coins_amm::admin_balance_y<ETH, USDC, SC_V_ETH_USDC>(&pool), admin_out_fee);

      test::return_shared(registry);
      test::return_shared(pool);      
    };

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Volatile, ETH, USDC>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));
      let pool_fees = sui_coins_amm::fees<ETH, USDC, SC_V_ETH_USDC>(&pool);

      let eth_amount = sui_coins_amm::balance_x<ETH, USDC, SC_V_ETH_USDC>(&pool);
      let usdc_amount = sui_coins_amm::balance_y<ETH, USDC, SC_V_ETH_USDC>(&pool);
      let initial_admin_balance_x = sui_coins_amm::admin_balance_x<ETH, USDC, SC_V_ETH_USDC>(&pool);
      let initial_admin_balance_y = sui_coins_amm::admin_balance_y<ETH, USDC, SC_V_ETH_USDC>(&pool);

      let amount_in = 7777 * USDC_DECIMAL_SCALAR;
      let amount_in_fee = fees::get_fee_in_amount(&pool_fees, amount_in);
      let admin_in_fee = fees::get_admin_amount(&pool_fees, amount_in_fee);
      let expected_amount_out = volatile::get_amount_out(amount_in - amount_in_fee, usdc_amount, eth_amount);
      let amount_out_fee = fees::get_fee_out_amount(&pool_fees, expected_amount_out);
      let admin_out_fee = fees::get_admin_amount(&pool_fees, amount_out_fee);
      let expected_amount_out = expected_amount_out - amount_out_fee;       

     let eth_coin = sui_coins_amm::swap<USDC, ETH, SC_V_ETH_USDC>(
        &mut pool,
        mint_for_testing(amount_in, ctx(test)),
        expected_amount_out,
        ctx(test)
      );

      assert_eq(burn_for_testing(eth_coin), expected_amount_out);
      assert_eq(sui_coins_amm::balance_x<ETH, USDC, SC_V_ETH_USDC>(&pool), eth_amount - (expected_amount_out + admin_out_fee));
      assert_eq(sui_coins_amm::balance_y<ETH, USDC, SC_V_ETH_USDC>(&pool), usdc_amount + amount_in - admin_in_fee);
      assert_eq(sui_coins_amm::admin_balance_x<ETH, USDC, SC_V_ETH_USDC>(&pool), admin_out_fee + initial_admin_balance_x);
      assert_eq(sui_coins_amm::admin_balance_y<ETH, USDC, SC_V_ETH_USDC>(&pool), admin_in_fee + initial_admin_balance_y);

      test::return_shared(registry);
      test::return_shared(pool);
    };

    test::end(scenario);
  }

  #[test]
  fun test_stable_swap() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up_test(test);

    let usdc_amount = 3333 * USDC_DECIMAL_SCALAR;
    let usdt_amount = 3333 * USDT_DECIMAL_SCALAR;

    deploy_usdc_usdt_pool(test, usdc_amount, usdt_amount);

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Stable, USDC, USDT>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));
      let pool_fees = sui_coins_amm::fees<USDC, USDT, SC_S_USDC_USDT>(&pool);

      let amount_in = 150 * USDC_DECIMAL_SCALAR;
      let amount_in_fee = fees::get_fee_in_amount(&pool_fees, amount_in);
      let admin_in_fee = fees::get_admin_amount(&pool_fees, amount_in_fee);

      let expected_amount_out = stable::get_amount_out(
        amount_in - amount_in_fee,
        usdc_amount,
        usdt_amount,
        USDC_DECIMAL_SCALAR,
        USDT_DECIMAL_SCALAR,
        true
      );
      
      let amount_out_fee = fees::get_fee_out_amount(&pool_fees, expected_amount_out);
      let admin_out_fee = fees::get_admin_amount(&pool_fees, amount_out_fee);
      let expected_amount_out = expected_amount_out - amount_out_fee;     

      let usdt_coin = sui_coins_amm::swap<USDC, USDT, SC_S_USDC_USDT>(
        &mut pool,
        mint_for_testing(amount_in, ctx(test)),
        expected_amount_out,
        ctx(test)
      );
      
      assert_eq(burn_for_testing(usdt_coin), expected_amount_out);
      assert_eq(sui_coins_amm::balance_x<USDC, USDT, SC_S_USDC_USDT>(&pool), usdc_amount + amount_in - admin_in_fee);
      assert_eq(sui_coins_amm::balance_y<USDC, USDT, SC_S_USDC_USDT>(&pool), usdt_amount - (expected_amount_out + admin_out_fee));
      assert_eq(sui_coins_amm::admin_balance_x<USDC, USDT, SC_S_USDC_USDT>(&pool), admin_in_fee);
      assert_eq(sui_coins_amm::admin_balance_y<USDC, USDT, SC_S_USDC_USDT>(&pool), admin_out_fee);

      test::return_shared(registry);
      test::return_shared(pool);   
    };

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Stable, USDC, USDT>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));
      let pool_fees = sui_coins_amm::fees<USDC, USDT, SC_S_USDC_USDT>(&pool);

      let usdc_amount = sui_coins_amm::balance_x<USDC, USDT, SC_S_USDC_USDT>(&pool);
      let usdt_amount = sui_coins_amm::balance_y<USDC, USDT, SC_S_USDC_USDT>(&pool);
      let initial_admin_balance_x = sui_coins_amm::admin_balance_x<USDC, USDT, SC_S_USDC_USDT>(&pool);
      let initial_admin_balance_y = sui_coins_amm::admin_balance_y<USDC, USDT, SC_S_USDC_USDT>(&pool);

      let amount_in = 345 * USDT_DECIMAL_SCALAR;
      let amount_in_fee = fees::get_fee_in_amount(&pool_fees, amount_in);
      let admin_in_fee = fees::get_admin_amount(&pool_fees, amount_in_fee);
      
      let expected_amount_out = stable::get_amount_out(
        amount_in - amount_in_fee,
        usdc_amount,
        usdt_amount,
        USDC_DECIMAL_SCALAR,
        USDT_DECIMAL_SCALAR,
        false
      );

      let amount_out_fee = fees::get_fee_out_amount(&pool_fees, expected_amount_out);
      let admin_out_fee = fees::get_admin_amount(&pool_fees, amount_out_fee);
      let expected_amount_out = expected_amount_out - amount_out_fee;       

      let usdc_coin = sui_coins_amm::swap<USDT, USDC, SC_S_USDC_USDT>(
        &mut pool,
        mint_for_testing(amount_in, ctx(test)),
        expected_amount_out,
        ctx(test)
      );

      assert_eq(burn_for_testing(usdc_coin), expected_amount_out);
      assert_eq(sui_coins_amm::balance_x<USDC, USDT, SC_S_USDC_USDT>(&pool), usdc_amount - (expected_amount_out + admin_out_fee));
      assert_eq(sui_coins_amm::balance_y<USDC, USDT, SC_S_USDC_USDT>(&pool), usdt_amount + amount_in - admin_in_fee);
      assert_eq(sui_coins_amm::admin_balance_x<USDC, USDT, SC_S_USDC_USDT>(&pool), admin_out_fee + initial_admin_balance_x);
      assert_eq(sui_coins_amm::admin_balance_y<USDC, USDT, SC_S_USDC_USDT>(&pool), admin_in_fee + initial_admin_balance_y);

      test::return_shared(registry);
      test::return_shared(pool);
    };

    test::end(scenario);
  }

  #[test]
  fun test_add_liquidity() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up_test(test);

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(test, eth_amount, usdc_amount);

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Volatile, ETH, USDC>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));
      let initial_lp_coin_supply = sui_coins_amm::lp_coin_supply<ETH, USDC, SC_V_ETH_USDC>(&pool);

      let amount_x = 20 * ETH_DECIMAL_SCALAR;
      let amount_y = 27000 * USDC_DECIMAL_SCALAR;

      let (shares, optimal_x, optimal_y) = quote::add_liquidity<ETH, USDC, SC_V_ETH_USDC>(&pool, amount_x, amount_y);

      let (lp_coin, eth_coin, usdc_coin) = sui_coins_amm::add_liquidity<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool,
        mint_for_testing(amount_x, ctx(test)),
        mint_for_testing(amount_y, ctx(test)),
        shares,
        ctx(test)
      );

      assert_eq(burn_for_testing(lp_coin), shares);
      assert_eq(burn_for_testing(eth_coin), amount_x - optimal_x);
      assert_eq(burn_for_testing(usdc_coin), amount_y - optimal_y);
      assert_eq(sui_coins_amm::lp_coin_supply<ETH, USDC, SC_V_ETH_USDC>(&pool), shares + initial_lp_coin_supply);
      assert_eq(sui_coins_amm::balance_x<ETH, USDC, SC_V_ETH_USDC>(&pool), eth_amount + optimal_x);
      assert_eq(sui_coins_amm::balance_y<ETH, USDC, SC_V_ETH_USDC>(&pool), usdc_amount + optimal_y);

      test::return_shared(registry);
      test::return_shared(pool);
    };
    test::end(scenario);    
  }

  #[test]
  fun test_remove_liquidity() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up_test(test);

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(test, eth_amount, usdc_amount);

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Volatile, ETH, USDC>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));
      let initial_lp_coin_supply = sui_coins_amm::lp_coin_supply<ETH, USDC, SC_V_ETH_USDC>(&pool);  

      let (expected_x, expected_y) = quote::remove_liquidity<ETH, USDC, SC_V_ETH_USDC>(&pool, initial_lp_coin_supply / 3);

      let (eth_coin, usdc_coin) = sui_coins_amm::remove_liquidity<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool,
        mint_for_testing(initial_lp_coin_supply / 3, ctx(test)),
        expected_x,
        expected_y,
        ctx(test)
      );   

      assert_eq(burn_for_testing(eth_coin), expected_x);
      assert_eq(burn_for_testing(usdc_coin), expected_y);
      assert_eq(sui_coins_amm::lp_coin_supply<ETH, USDC, SC_V_ETH_USDC>(&pool), initial_lp_coin_supply - initial_lp_coin_supply / 3);
      assert_eq(sui_coins_amm::balance_x<ETH, USDC, SC_V_ETH_USDC>(&pool), eth_amount - expected_x);
      assert_eq(sui_coins_amm::balance_y<ETH, USDC, SC_V_ETH_USDC>(&pool), usdc_amount - expected_y);

      test::return_shared(registry);
      test::return_shared(pool);
    };    
    test::end(scenario); 
  }

  #[test]
  fun test_flash_loan() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up_test(test);

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(test, eth_amount, usdc_amount);

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Volatile, ETH, USDC>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));

      let eth_coin_amount = 5 * ETH_DECIMAL_SCALAR;
      let usdc_coin_amount = 1500 * USDC_DECIMAL_SCALAR;

      let (invoice, eth_coin, usdc_coin) = sui_coins_amm::flash_loan<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool,
        eth_coin_amount,
        usdc_coin_amount,
        ctx(test)
      );

      let invoice_repay_amount_x = sui_coins_amm::repay_amount_x(&invoice);
      let invoice_repay_amount_y = sui_coins_amm::repay_amount_y(&invoice);

      assert_eq(burn_for_testing(eth_coin), eth_coin_amount);
      assert_eq(burn_for_testing(usdc_coin), usdc_coin_amount);
      assert_eq(sui_coins_amm::locked<ETH, USDC, SC_V_ETH_USDC>(&pool), true);
      assert_eq(sui_coins_amm::balance_x<ETH, USDC, SC_V_ETH_USDC>(&pool), eth_amount - eth_coin_amount);
      assert_eq(sui_coins_amm::balance_y<ETH, USDC, SC_V_ETH_USDC>(&pool), usdc_amount - usdc_coin_amount);
      assert_eq(invoice_repay_amount_x, eth_coin_amount + (math256::mul_div_up((eth_coin_amount as u256), FLASH_LOAN_FEE_PERCENT, PRECISION) as u64));
      assert_eq(invoice_repay_amount_y, usdc_coin_amount + (math256::mul_div_up((usdc_coin_amount as u256), FLASH_LOAN_FEE_PERCENT, PRECISION) as u64));

      sui_coins_amm::repay_flash_loan<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool,
        invoice,
        mint_for_testing(invoice_repay_amount_x, ctx(test)),
        mint_for_testing(invoice_repay_amount_y, ctx(test))
      );

      assert_eq(sui_coins_amm::locked<ETH, USDC, SC_V_ETH_USDC>(&pool), false);
      assert_eq(sui_coins_amm::balance_x<ETH, USDC, SC_V_ETH_USDC>(&pool), eth_amount + invoice_repay_amount_x - eth_coin_amount);
      assert_eq(sui_coins_amm::balance_y<ETH, USDC, SC_V_ETH_USDC>(&pool), usdc_amount + invoice_repay_amount_y - usdc_coin_amount);

      test::return_shared(registry);
      test::return_shared(pool);     
    };    

    test::end(scenario); 
  }

  #[test]
  fun test_admin_fees_actions() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up_test(test);

    let usdc_amount = 3333 * USDC_DECIMAL_SCALAR;
    let usdt_amount = 3333 * USDT_DECIMAL_SCALAR;

    deploy_usdc_usdt_pool(test, usdc_amount, usdt_amount);

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Stable, USDC, USDT>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));
      let admin_cap = test::take_from_sender<Admin>(test);
      
      sui_coins_amm::update_fee<USDC, USDT, SC_S_USDC_USDT>(
        &admin_cap,
        &mut pool,
        option::some(MAX_FEE_PERCENT),
        option::some(MAX_FEE_PERCENT),
        option::none()
      );

      let pool_fees = sui_coins_amm::fees<USDC, USDT, SC_S_USDC_USDT>(&pool);
      assert_eq(fees::fee_in_percent(&pool_fees), MAX_FEE_PERCENT);
      assert_eq(fees::fee_out_percent(&pool_fees), MAX_FEE_PERCENT);

      assert_eq(sui_coins_amm::admin_balance_x<USDC, USDT, SC_S_USDC_USDT>(&pool), 0);
      assert_eq(sui_coins_amm::admin_balance_y<USDC, USDT, SC_S_USDC_USDT>(&pool), 0);

      let i = 0;

      while (10 > i) {
        burn_for_testing(sui_coins_amm::swap<USDC, USDT, SC_S_USDC_USDT>(
          &mut pool,
          mint_for_testing(usdc_amount / 3, ctx(test)),
          0,
          ctx(test)
        ));

        burn_for_testing(sui_coins_amm::swap<USDT, USDC, SC_S_USDC_USDT>(
          &mut pool,
          mint_for_testing(usdt_amount / 3, ctx(test)),
          0,
          ctx(test)
        ));

        i = i + 1;
      };

      let admin_balance_x = sui_coins_amm::admin_balance_x<USDC, USDT, SC_S_USDC_USDT>(&pool);
      let admin_balance_y = sui_coins_amm::admin_balance_y<USDC, USDT, SC_S_USDC_USDT>(&pool);

      assert_eq(admin_balance_x != 0, true);
      assert_eq(admin_balance_y != 0, true);

      let (usdc_coin, usdt_coin) = sui_coins_amm::take_fees<USDC, USDT, SC_S_USDC_USDT>(
        &admin_cap,
        &mut pool,
        ctx(test)
      );

      assert_eq(burn_for_testing(usdc_coin), admin_balance_x);
      assert_eq(burn_for_testing(usdt_coin), admin_balance_y);
      
      assert_eq(sui_coins_amm::admin_balance_x<USDC, USDT, SC_S_USDC_USDT>(&pool), 0);
      assert_eq(sui_coins_amm::admin_balance_y<USDC, USDT, SC_S_USDC_USDT>(&pool), 0);

      test::return_to_sender(test, admin_cap);
      test::return_shared(registry);  
      test::return_shared(pool);         
    };
    test::end(scenario);    
  }

  #[test]
  #[expected_failure(abort_code = 0)]  
  fun test_flash_loan_not_enough_balance_x() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up_test(test);

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(test, eth_amount, usdc_amount);

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Volatile, ETH, USDC>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));

      let (invoice, eth_coin, usdc_coin) = sui_coins_amm::flash_loan<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool,
        eth_amount + 1,
        usdc_amount,
        ctx(test)
      );

      sui_coins_amm::repay_flash_loan<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool,
        invoice,
        eth_coin,
        usdc_coin
      );

      test::return_shared(registry);
      test::return_shared(pool);    
    };    
    test::end(scenario); 
  }

  #[test]
  #[expected_failure(abort_code = 0)]  
  fun test_flash_loan_not_enough_balance_y() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up_test(test);

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(test, eth_amount, usdc_amount);

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Volatile, ETH, USDC>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));

      let (invoice, eth_coin, usdc_coin) = sui_coins_amm::flash_loan<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool,
        eth_amount,
        usdc_amount + 1,
        ctx(test)
      );

      sui_coins_amm::repay_flash_loan<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool,
        invoice,
        eth_coin,
        usdc_coin
      );

      test::return_shared(registry);
      test::return_shared(pool);    
    };    
    test::end(scenario); 
  }  

  #[test]
  #[expected_failure(abort_code = 11)]  
  fun test_flash_loan_locked() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up_test(test);

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(test, eth_amount, usdc_amount);

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Volatile, ETH, USDC>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));

      let (invoice, eth_coin, usdc_coin) = sui_coins_amm::flash_loan<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool,
        1,
        2,
        ctx(test)
      );

      let (invoice2, eth_coin2, usdc_coin2) = sui_coins_amm::flash_loan<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool,
        3,
        4,
        ctx(test)
      );

      sui_coins_amm::repay_flash_loan<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool,
        invoice,
        eth_coin,
        usdc_coin
      );

      sui_coins_amm::repay_flash_loan<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool,
        invoice2,
        eth_coin2,
        usdc_coin2
      );

      test::return_shared(registry);
      test::return_shared(pool);    
    };    
    test::end(scenario); 
  }

  #[test]
  #[expected_failure(abort_code = 15)]    
  fun test_repay_wrong_pool() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up_test(test);

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(test, eth_amount, usdc_amount);
    deploy_usdc_usdt_pool(test, 100 * USDC_DECIMAL_SCALAR, 100 * USDT_DECIMAL_SCALAR);

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Volatile, ETH, USDC>(&registry);
      let pool1 = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));
      let pool_id = sui_coins_amm::pool_id<Stable, USDC, USDT>(&registry);
      let pool2 = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));

      let (invoice, eth_coin, usdc_coin) = sui_coins_amm::flash_loan<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool1,
        1,
        2,
        ctx(test)
      );

      sui_coins_amm::repay_flash_loan<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool2,
        invoice,
        eth_coin,
        usdc_coin
      );

      test::return_shared(registry);
      test::return_shared(pool1);
      test::return_shared(pool2);    
    };
    test::end(scenario); 
  } 

  #[test]
  #[expected_failure(abort_code = 12)]    
  fun test_repay_wrong_repay_amount_x() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up_test(test);

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(test, eth_amount, usdc_amount);
    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Volatile, ETH, USDC>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));

      let (invoice, eth_coin, usdc_coin) = sui_coins_amm::flash_loan<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool,
        eth_amount,
        usdc_amount,
        ctx(test)
      );

      burn_for_testing(eth_coin);
      burn_for_testing(usdc_coin);

      let invoice_repay_amount_x = sui_coins_amm::repay_amount_x(&invoice);
      let invoice_repay_amount_y = sui_coins_amm::repay_amount_y(&invoice);      

      sui_coins_amm::repay_flash_loan<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool,
        invoice,
        mint_for_testing(invoice_repay_amount_x - 1, ctx(test)),
        mint_for_testing(invoice_repay_amount_y, ctx(test))
      );

      test::return_shared(registry);
      test::return_shared(pool);   
    };
    test::end(scenario); 
  }   

  #[test]
  #[expected_failure(abort_code = 12)]    
  fun test_repay_wrong_repay_amount_y() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up_test(test);

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(test, eth_amount, usdc_amount);
    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Volatile, ETH, USDC>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));

      let (invoice, eth_coin, usdc_coin) = sui_coins_amm::flash_loan<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool,
        eth_amount,
        usdc_amount,
        ctx(test)
      );

      burn_for_testing(eth_coin);
      burn_for_testing(usdc_coin);

      let invoice_repay_amount_x = sui_coins_amm::repay_amount_x(&invoice);
      let invoice_repay_amount_y = sui_coins_amm::repay_amount_y(&invoice);      

      sui_coins_amm::repay_flash_loan<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool,
        invoice,
        mint_for_testing(invoice_repay_amount_x, ctx(test)),
        mint_for_testing(invoice_repay_amount_y - 1, ctx(test))
      );

      test::return_shared(registry);
      test::return_shared(pool);   
    };
    test::end(scenario); 
  }        

  #[test]
  #[expected_failure(abort_code = 13)]  
  fun test_new_pool_wrong_lp_coin_metadata() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up_test(test);

    next_tx(test, alice);
    {
      sc_btce_eth::init_for_testing(ctx(test));
    };

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let lp_coin_cap = test::take_from_sender<TreasuryCap<SC_BTCE_ETH>>(test);
      let btc_metadata = test::take_shared<CoinMetadata<BTC>>(test);
      let eth_metadata = test::take_shared<CoinMetadata<ETH>>(test);
      let lp_coin_metadata = test::take_shared<CoinMetadata<SC_BTCE_ETH>>(test);
      
      let lp_coin = sui_coins_amm::new_pool<BTC, ETH, SC_BTCE_ETH>(
        &mut registry,
        mint_for_testing(100, ctx(test)),
        mint_for_testing(10, ctx(test)),
        lp_coin_cap,
        &btc_metadata,
        &eth_metadata,
        &mut lp_coin_metadata,
        true,
        ctx(test)
      );

      burn_for_testing(lp_coin);

      test::return_shared(eth_metadata);
      test::return_shared(btc_metadata);
      test::return_shared(lp_coin_metadata);
      test::return_shared(registry);
    };    
    test::end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = 6)]  
  fun test_new_pool_wrong_lp_coin_supply() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up_test(test);

    next_tx(test, alice);
    {
      sc_v_eth_usdc::init_for_testing(ctx(test));
    };

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let lp_coin_cap = test::take_from_sender<TreasuryCap<SC_V_ETH_USDC>>(test);
      let eth_metadata = test::take_shared<CoinMetadata<ETH>>(test);
      let usdc_metadata = test::take_shared<CoinMetadata<USDC>>(test);
      let lp_coin_metadata = test::take_shared<CoinMetadata<SC_V_ETH_USDC>>(test);

      burn_for_testing(coin::mint(&mut lp_coin_cap, 100, ctx(test)));
      
      let lp_coin = sui_coins_amm::new_pool<ETH, USDC, SC_V_ETH_USDC>(
        &mut registry,
        mint_for_testing(100, ctx(test)),
        mint_for_testing(10, ctx(test)),
        lp_coin_cap,
        &eth_metadata,
        &usdc_metadata,
        &mut lp_coin_metadata,
        true,
        ctx(test)
      );

      burn_for_testing(lp_coin);

      test::return_shared(eth_metadata);
      test::return_shared(usdc_metadata);
      test::return_shared(lp_coin_metadata);
      test::return_shared(registry);
    };    
    test::end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = 3)]  
  fun test_new_pool_zero_coin_x() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up_test(test);

    next_tx(test, alice);
    {
      sc_v_eth_usdc::init_for_testing(ctx(test));
    };

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let lp_coin_cap = test::take_from_sender<TreasuryCap<SC_V_ETH_USDC>>(test);
      let eth_metadata = test::take_shared<CoinMetadata<ETH>>(test);
      let usdc_metadata = test::take_shared<CoinMetadata<USDC>>(test);
      let lp_coin_metadata = test::take_shared<CoinMetadata<SC_V_ETH_USDC>>(test);
      
      let lp_coin =sui_coins_amm::new_pool<ETH, USDC, SC_V_ETH_USDC>(
        &mut registry,
        coin::zero(ctx(test)),
        mint_for_testing(10, ctx(test)),
        lp_coin_cap,
        &eth_metadata,
        &usdc_metadata,
        &mut lp_coin_metadata,
        true,
        ctx(test)
      );

      burn_for_testing(lp_coin);

      test::return_shared(eth_metadata);
      test::return_shared(usdc_metadata);
      test::return_shared(lp_coin_metadata);
      test::return_shared(registry);
    };    
    test::end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = 3)]  
  fun test_new_pool_zero_coin_y() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up_test(test);

    next_tx(test, alice);
    {
      sc_v_eth_usdc::init_for_testing(ctx(test));
    };

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let lp_coin_cap = test::take_from_sender<TreasuryCap<SC_V_ETH_USDC>>(test);
      let eth_metadata = test::take_shared<CoinMetadata<ETH>>(test);
      let usdc_metadata = test::take_shared<CoinMetadata<USDC>>(test);
      let lp_coin_metadata = test::take_shared<CoinMetadata<SC_V_ETH_USDC>>(test);
      
      let lp_coin =sui_coins_amm::new_pool<ETH, USDC, SC_V_ETH_USDC>(
        &mut registry,
        mint_for_testing(10, ctx(test)),
        coin::zero(ctx(test)),
        lp_coin_cap,
        &eth_metadata,
        &usdc_metadata,
        &mut lp_coin_metadata,
        true,
        ctx(test)
      );

      burn_for_testing(lp_coin);

      test::return_shared(eth_metadata);
      test::return_shared(usdc_metadata);
      test::return_shared(lp_coin_metadata);
      test::return_shared(registry);
    };    
    test::end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = 5)]  
  fun test_new_pool_deploy_same_pool() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up_test(test);

    next_tx(test, alice);
    {
      sc_v_eth_usdc::init_for_testing(ctx(test));
    };

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let lp_coin_cap = test::take_from_sender<TreasuryCap<SC_V_ETH_USDC>>(test);
      let eth_metadata = test::take_shared<CoinMetadata<ETH>>(test);
      let usdc_metadata = test::take_shared<CoinMetadata<USDC>>(test);
      let lp_coin_metadata = test::take_shared<CoinMetadata<SC_V_ETH_USDC>>(test);
      
      let lp_coin =sui_coins_amm::new_pool<ETH, USDC, SC_V_ETH_USDC>(
        &mut registry,
        mint_for_testing(10, ctx(test)),
        mint_for_testing(10, ctx(test)),
        lp_coin_cap,
        &eth_metadata,
        &usdc_metadata,
        &mut lp_coin_metadata,
        true,
        ctx(test)
      );

      burn_for_testing(lp_coin);

      test::return_shared(eth_metadata);
      test::return_shared(usdc_metadata);
      test::return_shared(lp_coin_metadata);
      test::return_shared(registry);
    };  

    next_tx(test, alice);
    {
      sc_v_eth_usdc::init_for_testing(ctx(test));
    };

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let lp_coin_cap = test::take_from_sender<TreasuryCap<SC_V_ETH_USDC>>(test);
      let eth_metadata = test::take_shared<CoinMetadata<ETH>>(test);
      let usdc_metadata = test::take_shared<CoinMetadata<USDC>>(test);
      let lp_coin_metadata = test::take_shared<CoinMetadata<SC_V_ETH_USDC>>(test);
      
      let lp_coin =sui_coins_amm::new_pool<ETH, USDC, SC_V_ETH_USDC>(
        &mut registry,
        mint_for_testing(10, ctx(test)),
        mint_for_testing(10, ctx(test)),
        lp_coin_cap,
        &eth_metadata,
        &usdc_metadata,
        &mut lp_coin_metadata,
        true,
        ctx(test)
      );

      burn_for_testing(lp_coin);

      test::return_shared(eth_metadata);
      test::return_shared(usdc_metadata);
      test::return_shared(lp_coin_metadata);
      test::return_shared(registry);
    };  

    test::end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = 9)]  
  fun test_swap_zero_coin() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    next_tx(test, alice);
    {
      admin::init_for_testing(ctx(test));
      sui_coins_amm::init_for_testing(ctx(test));
    };

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(test, eth_amount, usdc_amount);

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Volatile, ETH, USDC>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));

      let eth_coin = sui_coins_amm::swap<USDC, ETH, SC_V_ETH_USDC>(
        &mut pool,
        coin::zero(ctx(test)),
        0,
        ctx(test)
      );

      burn_for_testing(eth_coin);

      test::return_shared(registry);
      test::return_shared(pool);   
    };    
    test::end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = 11)]  
  fun test_swap_x_locked_pool() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    next_tx(test, alice);
    {
      admin::init_for_testing(ctx(test));
      sui_coins_amm::init_for_testing(ctx(test));
    };

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(test, eth_amount, usdc_amount);

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Volatile, ETH, USDC>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));

      let (invoice, coin_x, coin_y) = sui_coins_amm::flash_loan<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool,
        1,
        2,
        ctx(test)
      );

      let eth_coin = sui_coins_amm::swap<USDC, ETH, SC_V_ETH_USDC>(
        &mut pool,
        mint_for_testing(1, ctx(test)),
        0,
        ctx(test)
      );

      sui_coins_amm::repay_flash_loan<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool,
        invoice,
        coin_x,
        coin_y
      );

      burn_for_testing(eth_coin);

      test::return_shared(registry);
      test::return_shared(pool);   
    };    
    test::end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = 11)]  
  fun test_swap_y_locked_pool() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    next_tx(test, alice);
    {
      admin::init_for_testing(ctx(test));
      sui_coins_amm::init_for_testing(ctx(test));
    };

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(test, eth_amount, usdc_amount);

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Volatile, ETH, USDC>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));

      let (invoice, coin_x, coin_y) = sui_coins_amm::flash_loan<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool,
        1,
        2,
        ctx(test)
      );

      let usdc_coin = sui_coins_amm::swap<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool,
        mint_for_testing(1, ctx(test)),
        0,
        ctx(test)
      );

      sui_coins_amm::repay_flash_loan<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool,
        invoice,
        coin_x,
        coin_y
      );

      burn_for_testing(usdc_coin);

      test::return_shared(registry);
      test::return_shared(pool);   
    };    
    test::end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = 8)]  
  fun test_swap_x_slippage() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    set_up_test(test);
    deploy_eth_usdc_pool(test, eth_amount, usdc_amount);
    
    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Volatile, ETH, USDC>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));
      let pool_fees = sui_coins_amm::fees<ETH, USDC, SC_V_ETH_USDC>(&pool);

      let amount_in = 3 * ETH_DECIMAL_SCALAR;
      let amount_in_fee = fees::get_fee_in_amount(&pool_fees, amount_in);
      let expected_amount_out = volatile::get_amount_out(amount_in - amount_in_fee, eth_amount, usdc_amount);
      let amount_out_fee = fees::get_fee_out_amount(&pool_fees, expected_amount_out);
      let expected_amount_out = expected_amount_out - amount_out_fee; 

      let usdc_coin = sui_coins_amm::swap<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool,
        mint_for_testing(amount_in, ctx(test)),
        expected_amount_out + 1,
        ctx(test)
      );

      burn_for_testing(usdc_coin);

      test::return_shared(registry);
      test::return_shared(pool);   
    };

    test::end(scenario);
  }  

  #[test]
  #[expected_failure(abort_code = 8)]  
  fun test_swap_y_slippage() {

    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    set_up_test(test);
    deploy_eth_usdc_pool(test, eth_amount, usdc_amount);
    
    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Volatile, ETH, USDC>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));
      let pool_fees = sui_coins_amm::fees<ETH, USDC, SC_V_ETH_USDC>(&pool);

      let eth_amount = sui_coins_amm::balance_x<ETH, USDC, SC_V_ETH_USDC>(&pool);
      let usdc_amount = sui_coins_amm::balance_y<ETH, USDC, SC_V_ETH_USDC>(&pool);

      let amount_in = 7777 * USDC_DECIMAL_SCALAR;
      let amount_in_fee = fees::get_fee_in_amount(&pool_fees, amount_in);
      let expected_amount_out = volatile::get_amount_out(amount_in - amount_in_fee, usdc_amount, eth_amount);
      let amount_out_fee = fees::get_fee_out_amount(&pool_fees, expected_amount_out);
      let expected_amount_out = expected_amount_out - amount_out_fee;       

      let eth_coin = sui_coins_amm::swap<USDC, ETH, SC_V_ETH_USDC>(
        &mut pool,
        mint_for_testing(amount_in, ctx(test)),
        expected_amount_out + 1,
        ctx(test)
       );


      burn_for_testing(eth_coin);

      test::return_shared(registry);
      test::return_shared(pool);      
    };    
    test::end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = 8)]    
  fun test_add_liquidity_slippage() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up_test(test);

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(test, eth_amount, usdc_amount);

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Volatile, ETH, USDC>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));

      let amount_x = 20 * ETH_DECIMAL_SCALAR;
      let amount_y = 27000 * USDC_DECIMAL_SCALAR;

      let (shares, _, _) = quote::add_liquidity<ETH, USDC, SC_V_ETH_USDC>(&pool, amount_x, amount_y);

      let (lp_coin, eth_coin, usdc_coin) = sui_coins_amm::add_liquidity<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool,
        mint_for_testing(amount_x, ctx(test)),
        mint_for_testing(amount_y, ctx(test)),
        shares + 1,
        ctx(test)
      );

      burn_for_testing(lp_coin);
      burn_for_testing(eth_coin);
      burn_for_testing(usdc_coin);

      test::return_shared(registry);
      test::return_shared(pool);
    };
    test::end(scenario);    
  }
  
  #[test]
  #[expected_failure(abort_code = 11)]    
  fun test_add_liquidity_locked() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up_test(test);

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(test, eth_amount, usdc_amount);

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Volatile, ETH, USDC>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));

      let amount_x = 20 * ETH_DECIMAL_SCALAR;
      let amount_y = 27000 * USDC_DECIMAL_SCALAR;

      let (invoice, coin_x, coin_y) = sui_coins_amm::flash_loan<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool,
        1,
        2,
        ctx(test)
      );

      let (lp_coin, eth_coin, usdc_coin) = sui_coins_amm::add_liquidity<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool,
        mint_for_testing(amount_x, ctx(test)),
        mint_for_testing(amount_y, ctx(test)),
        0,
        ctx(test)
      );

      sui_coins_amm::repay_flash_loan<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool,
        invoice,
        coin_x,
        coin_y
      );

      burn_for_testing(lp_coin);
      burn_for_testing(eth_coin);
      burn_for_testing(usdc_coin);

      test::return_shared(registry);
      test::return_shared(pool);
    };
    test::end(scenario);    
  }

  #[test]
  #[expected_failure(abort_code = 3)]    
  fun test_add_liquidity_zero_coin_x() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up_test(test);

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(test, eth_amount, usdc_amount);

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Volatile, ETH, USDC>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));

      let (lp_coin, eth_coin, usdc_coin) = sui_coins_amm::add_liquidity<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool,
        coin::zero(ctx(test)),
        mint_for_testing(1, ctx(test)),
        0,
        ctx(test)
      );

      burn_for_testing(lp_coin);
      burn_for_testing(eth_coin);
      burn_for_testing(usdc_coin);

      test::return_shared(registry);
      test::return_shared(pool);
    };
    test::end(scenario);    
  }  

  #[test]
  #[expected_failure(abort_code = 3)]    
  fun test_add_liquidity_zero_coin_y() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up_test(test);

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(test, eth_amount, usdc_amount);

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Volatile, ETH, USDC>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));

      let (lp_coin, eth_coin, usdc_coin) = sui_coins_amm::add_liquidity<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool,
        mint_for_testing(1, ctx(test)),
        coin::zero(ctx(test)),
        0,
        ctx(test)
      );

      burn_for_testing(lp_coin);
      burn_for_testing(eth_coin);
      burn_for_testing(usdc_coin);

      test::return_shared(registry);
      test::return_shared(pool);
    };
    test::end(scenario);    
  }  

  #[test]
  #[expected_failure(abort_code = 3)]    
  fun test_add_liquidity_both_zero_coins() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up_test(test);

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(test, eth_amount, usdc_amount);

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Volatile, ETH, USDC>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));

      let (lp_coin, eth_coin, usdc_coin) = sui_coins_amm::add_liquidity<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool,
        coin::zero(ctx(test)),
        coin::zero(ctx(test)),
        0,
        ctx(test)
      );

      burn_for_testing(lp_coin);
      burn_for_testing(eth_coin);
      burn_for_testing(usdc_coin);

      test::return_shared(registry);
      test::return_shared(pool);
    };
    test::end(scenario);    
  }  

  #[test]
  #[expected_failure(abort_code = 9)]  
  fun test_remove_liquidity_no_zero_coin() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up_test(test);

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(test, eth_amount, usdc_amount);

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Volatile, ETH, USDC>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));

      let (eth_coin, usdc_coin) = sui_coins_amm::remove_liquidity<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool,
        coin::zero(ctx(test)),
        0,
        0,
        ctx(test)
      );   

      burn_for_testing(eth_coin);
      burn_for_testing(usdc_coin);

      test::return_shared(registry);
      test::return_shared(pool);
    };    
    test::end(scenario); 
  }   

  #[test]
  #[expected_failure(abort_code = 11)]  
  fun test_remove_liquidity_locked() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up_test(test);

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(test, eth_amount, usdc_amount);

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Volatile, ETH, USDC>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));

      let (invoice, coin_x, coin_y) = sui_coins_amm::flash_loan<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool,
        1,
        2,
        ctx(test)
      );

      let (eth_coin, usdc_coin) = sui_coins_amm::remove_liquidity<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool,
        mint_for_testing(1, ctx(test)),
        0,
        0,
        ctx(test)
      );   

      burn_for_testing(eth_coin);
      burn_for_testing(usdc_coin);

      sui_coins_amm::repay_flash_loan<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool,
        invoice,
        coin_x,
        coin_y
      );

      test::return_shared(registry);
      test::return_shared(pool);
    };    
    test::end(scenario); 
  }  

  #[test]
  #[expected_failure(abort_code = 8)] 
  fun test_remove_liquidity_slippage_coin_x() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up_test(test);

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(test, eth_amount, usdc_amount);

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Volatile, ETH, USDC>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));
      let initial_lp_coin_supply = sui_coins_amm::lp_coin_supply<ETH, USDC, SC_V_ETH_USDC>(&pool);  

      let (expected_x, expected_y) = quote::remove_liquidity<ETH, USDC, SC_V_ETH_USDC>(&pool, initial_lp_coin_supply / 3);

      let (eth_coin, usdc_coin) = sui_coins_amm::remove_liquidity<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool,
        mint_for_testing(initial_lp_coin_supply / 3, ctx(test)),
        expected_x + 1,
        expected_y,
        ctx(test)
      );   

      burn_for_testing(eth_coin);
      burn_for_testing(usdc_coin);

      test::return_shared(registry);
      test::return_shared(pool);
    };    
    test::end(scenario); 
  }  

  #[test]
  #[expected_failure(abort_code = 8)] 
  fun test_remove_liquidity_slippage_coin_y() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up_test(test);

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(test, eth_amount, usdc_amount);

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Volatile, ETH, USDC>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));
      let initial_lp_coin_supply = sui_coins_amm::lp_coin_supply<ETH, USDC, SC_V_ETH_USDC>(&pool);  

      let (expected_x, expected_y) = quote::remove_liquidity<ETH, USDC, SC_V_ETH_USDC>(&pool, initial_lp_coin_supply / 3);

      let (eth_coin, usdc_coin) = sui_coins_amm::remove_liquidity<ETH, USDC, SC_V_ETH_USDC>(
        &mut pool,
        mint_for_testing(initial_lp_coin_supply / 3, ctx(test)),
        expected_x,
        expected_y + 1,
        ctx(test)
      );   

      burn_for_testing(eth_coin);
      burn_for_testing(usdc_coin);

      test::return_shared(registry);
      test::return_shared(pool);
    };    
    test::end(scenario); 
  }          
  
  fun set_up_test(test: &mut Scenario) {
    let (alice, _) = people();

    deploy_coins(test);

    next_tx(test, alice);
    {
      admin::init_for_testing(ctx(test));
      sui_coins_amm::init_for_testing(ctx(test));
    };
  }
}