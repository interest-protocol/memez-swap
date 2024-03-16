#[test_only]
module amm::interest_protocol_amm_tests {
  use std::option;
  use std::string::{utf8, to_ascii};

  use sui::table;
  use sui::test_utils::assert_eq;
  use sui::coin::{Self, mint_for_testing, burn_for_testing, TreasuryCap, CoinMetadata};
  use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};

  use suitears::math256;

  use amm::quote;
  use amm::stable;
  use amm::btc::BTC;
  use amm::eth::ETH;
  use amm::volatile;
  use amm::usdc::USDC;
  use amm::usdt::USDT;
  use amm::fees::{Self, Fees};
  use amm::admin::{Self, Admin};
  use amm::curves::{Volatile, Stable};
  use amm::ipx_btce_eth::{Self, IPX_BTCE_ETH};
  use amm::ipx_v_eth_usdc::{Self, IPX_V_ETH_USDC};
  use amm::ipx_s_usdc_usdt::{Self, IPX_S_USDC_USDT};
  use amm::interest_protocol_amm::{Self, Registry, InterestPool};
  use amm::deploy_utils::{people, scenario, deploy_coins, deploy_eth_usdc_pool, deploy_usdc_usdt_pool};

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
    let (scenario, alice, _) = start_test();  

    let scenario_mut = &mut scenario;
    
    next_tx(scenario_mut, alice);
    {
      ipx_v_eth_usdc::init_for_testing(ctx(scenario_mut));
      ipx_s_usdc_usdt::init_for_testing(ctx(scenario_mut));
    };

    let eth_amount = 10 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 25000 * USDC_DECIMAL_SCALAR;
    let expected_shares = (math256::sqrt_down((eth_amount as u256) * (usdc_amount as u256)) as u64);

    next_tx(scenario_mut, alice);
    {
      let registry = test::take_shared<Registry>(scenario_mut);
      let lp_coin_cap = test::take_from_sender<TreasuryCap<IPX_V_ETH_USDC>>(scenario_mut);
      let eth_metadata = test::take_shared<CoinMetadata<ETH>>(scenario_mut);
      let usdc_metadata = test::take_shared<CoinMetadata<USDC>>(scenario_mut);
      let lp_coin_metadata = test::take_shared<CoinMetadata<IPX_V_ETH_USDC>>(scenario_mut);
      
      assert_eq(table::is_empty(interest_protocol_amm::pools(&registry)), true);
      
      let lp_coin = interest_protocol_amm::new<ETH, USDC, IPX_V_ETH_USDC>(
        &mut registry,
        mint_for_testing(eth_amount, ctx(scenario_mut)),
        mint_for_testing(usdc_amount, ctx(scenario_mut)),
        lp_coin_cap,
        &eth_metadata,
        &usdc_metadata,
        &mut lp_coin_metadata,
        true,
        ctx(scenario_mut)
      );

      assert_eq(coin::get_symbol(&lp_coin_metadata), to_ascii(utf8(b"ipx-v-ETH-USDC")));
      assert_eq(coin::get_name(&lp_coin_metadata), utf8(b"ipx volatile Ether USD Coin Lp Coin"));
      assert_eq(interest_protocol_amm::exists_<Volatile, ETH, USDC>(&registry), true);
      assert_eq(burn_for_testing(lp_coin), expected_shares);

      test::return_shared(eth_metadata);
      test::return_shared(usdc_metadata);
      test::return_shared(lp_coin_metadata);
      test::return_shared(registry);
    };

    next_tx(scenario_mut, alice);
    {
      let request = request<Volatile, ETH, USDC, IPX_V_ETH_USDC>(scenario_mut);

      assert_eq(interest_protocol_amm::lp_coin_supply<ETH, USDC, IPX_V_ETH_USDC>(&request.pool), expected_shares + MINIMUM_LIQUIDITY);
      assert_eq(interest_protocol_amm::balance_x<ETH, USDC, IPX_V_ETH_USDC>(&request.pool), eth_amount);
      assert_eq(interest_protocol_amm::balance_y<ETH, USDC, IPX_V_ETH_USDC>(&request.pool), usdc_amount);
      assert_eq(interest_protocol_amm::decimals_x<ETH, USDC, IPX_V_ETH_USDC>(&request.pool), ETH_DECIMAL_SCALAR);
      assert_eq(interest_protocol_amm::decimals_y<ETH, USDC, IPX_V_ETH_USDC>(&request.pool), USDC_DECIMAL_SCALAR);
      assert_eq(interest_protocol_amm::volatile<ETH, USDC, IPX_V_ETH_USDC>(&request.pool), true);
      assert_eq(interest_protocol_amm::seed_liquidity<ETH, USDC, IPX_V_ETH_USDC>(&request.pool), MINIMUM_LIQUIDITY);
      assert_eq(interest_protocol_amm::locked<ETH, USDC, IPX_V_ETH_USDC>(&request.pool), false);
      assert_eq(interest_protocol_amm::admin_balance_x<ETH, USDC, IPX_V_ETH_USDC>(&request.pool), 0);
      assert_eq(interest_protocol_amm::admin_balance_y<ETH, USDC, IPX_V_ETH_USDC>(&request.pool), 0);

      let fees = interest_protocol_amm::fees<ETH, USDC, IPX_V_ETH_USDC>(&request.pool);

      assert_eq(fees::fee_in_percent(&fees), INITIAL_VOLATILE_FEE_PERCENT);
      assert_eq(fees::fee_out_percent(&fees), INITIAL_VOLATILE_FEE_PERCENT);
      assert_eq(fees::admin_fee_percent(&fees), INITIAL_ADMIN_FEE);

      destroy_request(request);
    };

    let usdc_amount = 7777 * USDC_DECIMAL_SCALAR;
    let usdt_amount = 7777 * USDT_DECIMAL_SCALAR;
    let expected_shares = (math256::sqrt_down((usdt_amount as u256) * (usdc_amount as u256)) as u64);

    next_tx(scenario_mut, alice);
    {
      let registry = test::take_shared<Registry>(scenario_mut);
      let lp_coin_cap = test::take_from_sender<TreasuryCap<IPX_S_USDC_USDT>>(scenario_mut);
      let usdc_metadata = test::take_shared<CoinMetadata<USDC>>(scenario_mut);
      let usdt_metadata = test::take_shared<CoinMetadata<USDT>>(scenario_mut);
      let lp_coin_metadata = test::take_shared<CoinMetadata<IPX_S_USDC_USDT>>(scenario_mut);
      
      assert_eq(table::is_empty(interest_protocol_amm::pools(&registry)), false);
      assert_eq(table::length(interest_protocol_amm::pools(&registry)), 1);
      
      let lp_coin = interest_protocol_amm::new<USDC, USDT, IPX_S_USDC_USDT>(
        &mut registry,
        mint_for_testing(usdc_amount, ctx(scenario_mut)),
        mint_for_testing(usdt_amount, ctx(scenario_mut)),
        lp_coin_cap,
        &usdc_metadata,
        &usdt_metadata,
        &mut lp_coin_metadata,
        false,
        ctx(scenario_mut)
      );

      assert_eq(coin::get_symbol(&lp_coin_metadata), to_ascii(utf8(b"ipx-s-USDC-USDT")));
      assert_eq(coin::get_name(&lp_coin_metadata), utf8(b"ipx stable USD Coin USD Tether Lp Coin"));
      assert_eq(interest_protocol_amm::exists_<Stable, USDC, USDT>(&registry), true);
      assert_eq(burn_for_testing(lp_coin), expected_shares);

      test::return_shared(usdt_metadata);
      test::return_shared(usdc_metadata);
      test::return_shared(lp_coin_metadata);
      test::return_shared(registry);
    };

    next_tx(scenario_mut, alice);
    {      
      let request = request<Stable, USDC, USDT, IPX_S_USDC_USDT>(scenario_mut);

      assert_eq(interest_protocol_amm::lp_coin_supply<USDC, USDT, IPX_S_USDC_USDT>(&request.pool), expected_shares + MINIMUM_LIQUIDITY);
      assert_eq(interest_protocol_amm::balance_x<USDC, USDT, IPX_S_USDC_USDT>(&request.pool), usdc_amount);
      assert_eq(interest_protocol_amm::balance_y<USDC, USDT, IPX_S_USDC_USDT>(&request.pool), usdt_amount);
      assert_eq(interest_protocol_amm::decimals_x<USDC, USDT, IPX_S_USDC_USDT>(&request.pool), USDC_DECIMAL_SCALAR);
      assert_eq(interest_protocol_amm::decimals_y<USDC, USDT, IPX_S_USDC_USDT>(&request.pool), USDT_DECIMAL_SCALAR);
      assert_eq(interest_protocol_amm::volatile<USDC, USDT, IPX_S_USDC_USDT>(&request.pool), false);
      assert_eq(interest_protocol_amm::stable<USDC, USDT, IPX_S_USDC_USDT>(&request.pool), true);
      assert_eq(interest_protocol_amm::seed_liquidity<USDC, USDT, IPX_S_USDC_USDT>(&request.pool), MINIMUM_LIQUIDITY);
      assert_eq(interest_protocol_amm::locked<USDC, USDT, IPX_S_USDC_USDT>(&request.pool), false);
      assert_eq(interest_protocol_amm::admin_balance_x<USDC, USDT, IPX_S_USDC_USDT>(&request.pool), 0);
      assert_eq(interest_protocol_amm::admin_balance_y<USDC, USDT, IPX_S_USDC_USDT>(&request.pool), 0); 

      let fees = interest_protocol_amm::fees<USDC, USDT, IPX_S_USDC_USDT>(&request.pool);

      assert_eq(fees::fee_in_percent(&fees), INITIAL_STABLE_FEE_PERCENT);
      assert_eq(fees::fee_out_percent(&fees), INITIAL_STABLE_FEE_PERCENT);
      assert_eq(fees::admin_fee_percent(&fees), INITIAL_ADMIN_FEE);

      destroy_request(request);
    };
    
    test::end(scenario);
  }

  #[test]
  fun test_volatile_swap() {
    let (scenario, alice, _) = start_test();  

    let scenario_mut = &mut scenario;

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(scenario_mut, eth_amount, usdc_amount);

    next_tx(scenario_mut, alice);
    {
      let request = request<Volatile, ETH, USDC, IPX_V_ETH_USDC>(scenario_mut);

      let amount_in = 3 * ETH_DECIMAL_SCALAR;
      let amount_in_fee = fees::get_fee_in_amount(&request.fees, amount_in);
      let admin_in_fee = fees::get_admin_amount(&request.fees, amount_in_fee);
      let expected_amount_out = volatile::get_amount_out(amount_in - amount_in_fee, eth_amount, usdc_amount);
      let amount_out_fee = fees::get_fee_out_amount(&request.fees, expected_amount_out);
      let admin_out_fee = fees::get_admin_amount(&request.fees, amount_out_fee);
      let expected_amount_out = expected_amount_out - amount_out_fee; 

      let usdc_coin = interest_protocol_amm::swap<ETH, USDC, IPX_V_ETH_USDC>(
        &mut request.pool,
        mint_for_testing(amount_in, ctx(scenario_mut)),
        expected_amount_out,
        ctx(scenario_mut)
      );

      assert_eq(burn_for_testing(usdc_coin), expected_amount_out);
      assert_eq(interest_protocol_amm::balance_x<ETH, USDC, IPX_V_ETH_USDC>(&request.pool), eth_amount + amount_in - admin_in_fee);
      assert_eq(interest_protocol_amm::balance_y<ETH, USDC, IPX_V_ETH_USDC>(&request.pool), usdc_amount - (expected_amount_out + admin_out_fee));
      assert_eq(interest_protocol_amm::admin_balance_x<ETH, USDC, IPX_V_ETH_USDC>(&request.pool), admin_in_fee);
      assert_eq(interest_protocol_amm::admin_balance_y<ETH, USDC, IPX_V_ETH_USDC>(&request.pool), admin_out_fee);

      destroy_request(request);     
    };

    next_tx(scenario_mut, alice);
    {
      let request = request<Volatile, ETH, USDC, IPX_V_ETH_USDC>(scenario_mut);

      let eth_amount = interest_protocol_amm::balance_x<ETH, USDC, IPX_V_ETH_USDC>(&request.pool);
      let usdc_amount = interest_protocol_amm::balance_y<ETH, USDC, IPX_V_ETH_USDC>(&request.pool);
      let initial_admin_balance_x = interest_protocol_amm::admin_balance_x<ETH, USDC, IPX_V_ETH_USDC>(&request.pool);
      let initial_admin_balance_y = interest_protocol_amm::admin_balance_y<ETH, USDC, IPX_V_ETH_USDC>(&request.pool);

      let amount_in = 7777 * USDC_DECIMAL_SCALAR;
      let amount_in_fee = fees::get_fee_in_amount(&request.fees, amount_in);
      let admin_in_fee = fees::get_admin_amount(&request.fees, amount_in_fee);
      let expected_amount_out = volatile::get_amount_out(amount_in - amount_in_fee, usdc_amount, eth_amount);
      let amount_out_fee = fees::get_fee_out_amount(&request.fees, expected_amount_out);
      let admin_out_fee = fees::get_admin_amount(&request.fees, amount_out_fee);
      let expected_amount_out = expected_amount_out - amount_out_fee;       

     let eth_coin = interest_protocol_amm::swap<USDC, ETH, IPX_V_ETH_USDC>(
        &mut request.pool,
        mint_for_testing(amount_in, ctx(scenario_mut)),
        expected_amount_out,
        ctx(scenario_mut)
      );

      assert_eq(burn_for_testing(eth_coin), expected_amount_out);
      assert_eq(interest_protocol_amm::balance_x<ETH, USDC, IPX_V_ETH_USDC>(&request.pool), eth_amount - (expected_amount_out + admin_out_fee));
      assert_eq(interest_protocol_amm::balance_y<ETH, USDC, IPX_V_ETH_USDC>(&request.pool), usdc_amount + amount_in - admin_in_fee);
      assert_eq(interest_protocol_amm::admin_balance_x<ETH, USDC, IPX_V_ETH_USDC>(&request.pool), admin_out_fee + initial_admin_balance_x);
      assert_eq(interest_protocol_amm::admin_balance_y<ETH, USDC, IPX_V_ETH_USDC>(&request.pool), admin_in_fee + initial_admin_balance_y);

      destroy_request(request);
    };

    test::end(scenario);
  }

  #[test]
  fun test_stable_swap() {
    let (scenario, alice, _) = start_test();  

    let scenario_mut = &mut scenario;

    let usdc_amount = 3333 * USDC_DECIMAL_SCALAR;
    let usdt_amount = 3333 * USDT_DECIMAL_SCALAR;

    deploy_usdc_usdt_pool(scenario_mut, usdc_amount, usdt_amount);

    next_tx(scenario_mut, alice);
    {
      let request = request<Stable, USDC, USDT, IPX_S_USDC_USDT>(scenario_mut);

      let amount_in = 150 * USDC_DECIMAL_SCALAR;
      let amount_in_fee = fees::get_fee_in_amount(&request.fees, amount_in);
      let admin_in_fee = fees::get_admin_amount(&request.fees, amount_in_fee);

      let expected_amount_out = stable::get_amount_out(
        amount_in - amount_in_fee,
        usdc_amount,
        usdt_amount,
        USDC_DECIMAL_SCALAR,
        USDT_DECIMAL_SCALAR,
        true
      );
      
      let amount_out_fee = fees::get_fee_out_amount(&request.fees, expected_amount_out);
      let admin_out_fee = fees::get_admin_amount(&request.fees, amount_out_fee);
      let expected_amount_out = expected_amount_out - amount_out_fee;     

      let usdt_coin = interest_protocol_amm::swap<USDC, USDT, IPX_S_USDC_USDT>(
        &mut request.pool,
        mint_for_testing(amount_in, ctx(scenario_mut)),
        expected_amount_out,
        ctx(scenario_mut)
      );
      
      assert_eq(burn_for_testing(usdt_coin), expected_amount_out);
      assert_eq(interest_protocol_amm::balance_x<USDC, USDT, IPX_S_USDC_USDT>(&request.pool), usdc_amount + amount_in - admin_in_fee);
      assert_eq(interest_protocol_amm::balance_y<USDC, USDT, IPX_S_USDC_USDT>(&request.pool), usdt_amount - (expected_amount_out + admin_out_fee));
      assert_eq(interest_protocol_amm::admin_balance_x<USDC, USDT, IPX_S_USDC_USDT>(&request.pool), admin_in_fee);
      assert_eq(interest_protocol_amm::admin_balance_y<USDC, USDT, IPX_S_USDC_USDT>(&request.pool), admin_out_fee);

      destroy_request(request);   
    };

    next_tx(scenario_mut, alice);
    {
      let request = request<Stable, USDC, USDT, IPX_S_USDC_USDT>(scenario_mut);

      let usdc_amount = interest_protocol_amm::balance_x<USDC, USDT, IPX_S_USDC_USDT>(&request.pool);
      let usdt_amount = interest_protocol_amm::balance_y<USDC, USDT, IPX_S_USDC_USDT>(&request.pool);
      let initial_admin_balance_x = interest_protocol_amm::admin_balance_x<USDC, USDT, IPX_S_USDC_USDT>(&request.pool);
      let initial_admin_balance_y = interest_protocol_amm::admin_balance_y<USDC, USDT, IPX_S_USDC_USDT>(&request.pool);

      let amount_in = 345 * USDT_DECIMAL_SCALAR;
      let amount_in_fee = fees::get_fee_in_amount(&request.fees, amount_in);
      let admin_in_fee = fees::get_admin_amount(&request.fees, amount_in_fee);
      
      let expected_amount_out = stable::get_amount_out(
        amount_in - amount_in_fee,
        usdc_amount,
        usdt_amount,
        USDC_DECIMAL_SCALAR,
        USDT_DECIMAL_SCALAR,
        false
      );

      let amount_out_fee = fees::get_fee_out_amount(&request.fees, expected_amount_out);
      let admin_out_fee = fees::get_admin_amount(&request.fees, amount_out_fee);
      let expected_amount_out = expected_amount_out - amount_out_fee;       

      let usdc_coin = interest_protocol_amm::swap<USDT, USDC, IPX_S_USDC_USDT>(
        &mut request.pool,
        mint_for_testing(amount_in, ctx(scenario_mut)),
        expected_amount_out,
        ctx(scenario_mut)
      );

      assert_eq(burn_for_testing(usdc_coin), expected_amount_out);
      assert_eq(interest_protocol_amm::balance_x<USDC, USDT, IPX_S_USDC_USDT>(&request.pool), usdc_amount - (expected_amount_out + admin_out_fee));
      assert_eq(interest_protocol_amm::balance_y<USDC, USDT, IPX_S_USDC_USDT>(&request.pool), usdt_amount + amount_in - admin_in_fee);
      assert_eq(interest_protocol_amm::admin_balance_x<USDC, USDT, IPX_S_USDC_USDT>(&request.pool), admin_out_fee + initial_admin_balance_x);
      assert_eq(interest_protocol_amm::admin_balance_y<USDC, USDT, IPX_S_USDC_USDT>(&request.pool), admin_in_fee + initial_admin_balance_y);

      destroy_request(request);
    };

    test::end(scenario);
  }

  #[test]
  fun test_add_liquidity() {
    let (scenario, alice, _) = start_test();  

    let scenario_mut = &mut scenario;

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(scenario_mut, eth_amount, usdc_amount);

    next_tx(scenario_mut, alice);
    {
      let request = request<Volatile, ETH, USDC, IPX_V_ETH_USDC>(scenario_mut);

      let amount_x = 20 * ETH_DECIMAL_SCALAR;
      let amount_y = 27000 * USDC_DECIMAL_SCALAR;

      let initial_lp_coin_supply = interest_protocol_amm::lp_coin_supply<ETH, USDC, IPX_V_ETH_USDC>(&request.pool);

      let (shares, optimal_x, optimal_y) = quote::add_liquidity<ETH, USDC, IPX_V_ETH_USDC>(&request.pool, amount_x, amount_y);

      let (lp_coin, eth_coin, usdc_coin) = interest_protocol_amm::add_liquidity<ETH, USDC, IPX_V_ETH_USDC>(
        &mut request.pool,
        mint_for_testing(amount_x, ctx(scenario_mut)),
        mint_for_testing(amount_y, ctx(scenario_mut)),
        shares,
        ctx(scenario_mut)
      );

      assert_eq(burn_for_testing(lp_coin), shares);
      assert_eq(burn_for_testing(eth_coin), amount_x - optimal_x);
      assert_eq(burn_for_testing(usdc_coin), amount_y - optimal_y);
      assert_eq(interest_protocol_amm::lp_coin_supply<ETH, USDC, IPX_V_ETH_USDC>(&request.pool), shares + initial_lp_coin_supply);
      assert_eq(interest_protocol_amm::balance_x<ETH, USDC, IPX_V_ETH_USDC>(&request.pool), eth_amount + optimal_x);
      assert_eq(interest_protocol_amm::balance_y<ETH, USDC, IPX_V_ETH_USDC>(&request.pool), usdc_amount + optimal_y);

      destroy_request(request);
    };
    test::end(scenario);    
  }

  // #[test]
  // fun test_remove_liquidity() {
  //   let (scenario, alice, _) = start_test();  

  //   let scenario_mut = &mut scenario;

  //   let eth_amount = 15 * ETH_DECIMAL_SCALAR;
  //   let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
  //   deploy_eth_usdc_pool(scenario_mut, eth_amount, usdc_amount);

  //   next_tx(scenario_mut, alice);
  //   {
  //     let request = request<Volatile, ETH, USDC, IPX_V_ETH_USDC>(scenario_mut);

  //     let initial_lp_coin_supply = interest_protocol_amm::lp_coin_supply<ETH, USDC, IPX_V_ETH_USDC>(&request.pool);  

  //     let (expected_x, expected_y) = quote::remove_liquidity<ETH, USDC, IPX_V_ETH_USDC>(&request.pool, initial_lp_coin_supply / 3);

  //     let (eth_coin, usdc_coin) = interest_protocol_amm::remove_liquidity<ETH, USDC, IPX_V_ETH_USDC>(
  //       &mut request.pool,
  //       mint_for_testing(initial_lp_coin_supply / 3, ctx(scenario_mut)),
  //       expected_x,
  //       expected_y,
  //       ctx(scenario_mut)
  //     );   

  //     assert_eq(burn_for_testing(eth_coin), expected_x);
  //     assert_eq(burn_for_testing(usdc_coin), expected_y);
  //     assert_eq(interest_protocol_amm::lp_coin_supply<ETH, USDC, IPX_V_ETH_USDC>(&request.pool), initial_lp_coin_supply - initial_lp_coin_supply / 3);
  //     assert_eq(interest_protocol_amm::balance_x<ETH, USDC, IPX_V_ETH_USDC>(&request.pool), eth_amount - expected_x);
  //     assert_eq(interest_protocol_amm::balance_y<ETH, USDC, IPX_V_ETH_USDC>(&request.pool), usdc_amount - expected_y);

  //     destroy_request(request);
  //   };    
  //   test::end(scenario); 
  // }

  #[test]
  fun test_flash_loan() {
    let (scenario, alice, _) = start_test();  

    let scenario_mut = &mut scenario;

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(scenario_mut, eth_amount, usdc_amount);

    next_tx(scenario_mut, alice);
    {
      let request = request<Volatile, ETH, USDC, IPX_V_ETH_USDC>(scenario_mut);

      let eth_coin_amount = 5 * ETH_DECIMAL_SCALAR;
      let usdc_coin_amount = 1500 * USDC_DECIMAL_SCALAR;

      let (invoice, eth_coin, usdc_coin) = interest_protocol_amm::flash_loan<ETH, USDC, IPX_V_ETH_USDC>(
        &mut request.pool,
        eth_coin_amount,
        usdc_coin_amount,
        ctx(scenario_mut)
      );

      let invoice_repay_amount_x = interest_protocol_amm::repay_amount_x(&invoice);
      let invoice_repay_amount_y = interest_protocol_amm::repay_amount_y(&invoice);

      assert_eq(burn_for_testing(eth_coin), eth_coin_amount);
      assert_eq(burn_for_testing(usdc_coin), usdc_coin_amount);
      assert_eq(interest_protocol_amm::locked<ETH, USDC, IPX_V_ETH_USDC>(&request.pool), true);
      assert_eq(interest_protocol_amm::balance_x<ETH, USDC, IPX_V_ETH_USDC>(&request.pool), eth_amount - eth_coin_amount);
      assert_eq(interest_protocol_amm::balance_y<ETH, USDC, IPX_V_ETH_USDC>(&request.pool), usdc_amount - usdc_coin_amount);
      assert_eq(invoice_repay_amount_x, eth_coin_amount + (math256::mul_div_up((eth_coin_amount as u256), FLASH_LOAN_FEE_PERCENT, PRECISION) as u64));
      assert_eq(invoice_repay_amount_y, usdc_coin_amount + (math256::mul_div_up((usdc_coin_amount as u256), FLASH_LOAN_FEE_PERCENT, PRECISION) as u64));

      interest_protocol_amm::repay_flash_loan<ETH, USDC, IPX_V_ETH_USDC>(
        &mut request.pool,
        invoice,
        mint_for_testing(invoice_repay_amount_x, ctx(scenario_mut)),
        mint_for_testing(invoice_repay_amount_y, ctx(scenario_mut))
      );

      assert_eq(interest_protocol_amm::locked<ETH, USDC, IPX_V_ETH_USDC>(&request.pool), false);
      assert_eq(interest_protocol_amm::balance_x<ETH, USDC, IPX_V_ETH_USDC>(&request.pool), eth_amount + invoice_repay_amount_x - eth_coin_amount);
      assert_eq(interest_protocol_amm::balance_y<ETH, USDC, IPX_V_ETH_USDC>(&request.pool), usdc_amount + invoice_repay_amount_y - usdc_coin_amount);

      destroy_request(request);    
    };    

    test::end(scenario); 
  }

  #[test]
  fun test_admin_fees_actions() {
    let (scenario, alice, _) = start_test();  

    let scenario_mut = &mut scenario;

    let usdc_amount = 3333 * USDC_DECIMAL_SCALAR;
    let usdt_amount = 3333 * USDT_DECIMAL_SCALAR;

    deploy_usdc_usdt_pool(scenario_mut, usdc_amount, usdt_amount);

    next_tx(scenario_mut, alice);
    {
      let request = request<Stable, USDC, USDT, IPX_S_USDC_USDT>(scenario_mut);
      let admin_cap = test::take_from_sender<Admin>(scenario_mut);
      
      interest_protocol_amm::update_fees<USDC, USDT, IPX_S_USDC_USDT>(
        &admin_cap,
        &mut request.pool,
        option::some(MAX_FEE_PERCENT),
        option::some(MAX_FEE_PERCENT),
        option::none()
      );

      let pool_fees = interest_protocol_amm::fees<USDC, USDT, IPX_S_USDC_USDT>(&request.pool);
      assert_eq(fees::fee_in_percent(&pool_fees), MAX_FEE_PERCENT);
      assert_eq(fees::fee_out_percent(&pool_fees), MAX_FEE_PERCENT);

      assert_eq(interest_protocol_amm::admin_balance_x<USDC, USDT, IPX_S_USDC_USDT>(&request.pool), 0);
      assert_eq(interest_protocol_amm::admin_balance_y<USDC, USDT, IPX_S_USDC_USDT>(&request.pool), 0);

      let i = 0;

      while (10 > i) {
        burn_for_testing(interest_protocol_amm::swap<USDC, USDT, IPX_S_USDC_USDT>(
          &mut request.pool,
          mint_for_testing(usdc_amount / 3, ctx(scenario_mut)),
          0,
          ctx(scenario_mut)
        ));

        burn_for_testing(interest_protocol_amm::swap<USDT, USDC, IPX_S_USDC_USDT>(
          &mut request.pool,
          mint_for_testing(usdt_amount / 3, ctx(scenario_mut)),
          0,
          ctx(scenario_mut)
        ));

        i = i + 1;
      };

      let admin_balance_x = interest_protocol_amm::admin_balance_x<USDC, USDT, IPX_S_USDC_USDT>(&request.pool);
      let admin_balance_y = interest_protocol_amm::admin_balance_y<USDC, USDT, IPX_S_USDC_USDT>(&request.pool);

      assert_eq(admin_balance_x != 0, true);
      assert_eq(admin_balance_y != 0, true);

      let (usdc_coin, usdt_coin) = interest_protocol_amm::take_fees<USDC, USDT, IPX_S_USDC_USDT>(
        &admin_cap,
        &mut request.pool,
        ctx(scenario_mut)
      );

      assert_eq(burn_for_testing(usdc_coin), admin_balance_x);
      assert_eq(burn_for_testing(usdt_coin), admin_balance_y);
      
      assert_eq(interest_protocol_amm::admin_balance_x<USDC, USDT, IPX_S_USDC_USDT>(&request.pool), 0);
      assert_eq(interest_protocol_amm::admin_balance_y<USDC, USDT, IPX_S_USDC_USDT>(&request.pool), 0);

      test::return_to_sender(scenario_mut, admin_cap);
      destroy_request(request);         
    };
    test::end(scenario);    
  }

  #[test]
  #[expected_failure(abort_code = amm::errors::ENotEnoughFundsToLend, location = amm::interest_protocol_amm)]  
  fun test_flash_loan_not_enough_balance_x() {
    let (scenario, alice, _) = start_test();  

    let scenario_mut = &mut scenario;

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(scenario_mut, eth_amount, usdc_amount);

    next_tx(scenario_mut, alice);
    {
      let request = request<Volatile, ETH, USDC, IPX_V_ETH_USDC>(scenario_mut);

      let (invoice, eth_coin, usdc_coin) = interest_protocol_amm::flash_loan<ETH, USDC, IPX_V_ETH_USDC>(
        &mut request.pool,
        eth_amount + 1,
        usdc_amount,
        ctx(scenario_mut)
      );

      interest_protocol_amm::repay_flash_loan<ETH, USDC, IPX_V_ETH_USDC>(
        &mut request.pool,
        invoice,
        eth_coin,
        usdc_coin
      );

      destroy_request(request);    
    };    
    test::end(scenario); 
  }

  #[test]
  #[expected_failure(abort_code = amm::errors::ENotEnoughFundsToLend, location = amm::interest_protocol_amm)]  
  fun test_flash_loan_not_enough_balance_y() {
    let (scenario, alice, _) = start_test();  

    let scenario_mut = &mut scenario;

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(scenario_mut, eth_amount, usdc_amount);

    next_tx(scenario_mut, alice);
    {
      let request = request<Volatile, ETH, USDC, IPX_V_ETH_USDC>(scenario_mut);

      let (invoice, eth_coin, usdc_coin) = interest_protocol_amm::flash_loan<ETH, USDC, IPX_V_ETH_USDC>(
        &mut request.pool,
        eth_amount,
        usdc_amount + 1,
        ctx(scenario_mut)
      );

      interest_protocol_amm::repay_flash_loan<ETH, USDC, IPX_V_ETH_USDC>(
        &mut request.pool,
        invoice,
        eth_coin,
        usdc_coin
      );

      destroy_request(request);   
    };    

    test::end(scenario); 
  }  

  #[test]
  #[expected_failure(abort_code = amm::errors::EPoolIsLocked, location = amm::interest_protocol_amm)]  
  fun test_flash_loan_locked() {
    let (scenario, alice, _) = start_test();  

    let scenario_mut = &mut scenario;

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(scenario_mut, eth_amount, usdc_amount);

    next_tx(scenario_mut, alice);
    {
      let request = request<Volatile, ETH, USDC, IPX_V_ETH_USDC>(scenario_mut);

      let (invoice, eth_coin, usdc_coin) = interest_protocol_amm::flash_loan<ETH, USDC, IPX_V_ETH_USDC>(
        &mut request.pool,
        1,
        2,
        ctx(scenario_mut)
      );

      let (invoice2, eth_coin2, usdc_coin2) = interest_protocol_amm::flash_loan<ETH, USDC, IPX_V_ETH_USDC>(
        &mut request.pool,
        3,
        4,
        ctx(scenario_mut)
      );

      interest_protocol_amm::repay_flash_loan<ETH, USDC, IPX_V_ETH_USDC>(
        &mut request.pool,
        invoice,
        eth_coin,
        usdc_coin
      );

      interest_protocol_amm::repay_flash_loan<ETH, USDC, IPX_V_ETH_USDC>(
        &mut request.pool,
        invoice2,
        eth_coin2,
        usdc_coin2
      );

      destroy_request(request);   
    };    
    test::end(scenario); 
  }

  #[test]
  #[expected_failure(abort_code = amm::errors::EWrongPool, location = amm::interest_protocol_amm)]    
  fun test_repay_wrong_pool() {
    let (scenario, alice, _) = start_test();  

    let scenario_mut = &mut scenario;

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(scenario_mut, eth_amount, usdc_amount);
    deploy_usdc_usdt_pool(scenario_mut, 100 * USDC_DECIMAL_SCALAR, 100 * USDT_DECIMAL_SCALAR);

    next_tx(scenario_mut, alice);
    {
      let registry = test::take_shared<Registry>(scenario_mut);
      let pool_id = interest_protocol_amm::pool_id<Volatile, ETH, USDC>(&registry);
      let v_pool = test::take_shared_by_id<InterestPool>(scenario_mut, option::destroy_some(pool_id));
      let pool_id = interest_protocol_amm::pool_id<Stable, USDC, USDT>(&registry);
      let s_pool = test::take_shared_by_id<InterestPool>(scenario_mut, option::destroy_some(pool_id));

      let (invoice, eth_coin, usdc_coin) = interest_protocol_amm::flash_loan<ETH, USDC, IPX_V_ETH_USDC>(
        &mut v_pool,
        1,
        2,
        ctx(scenario_mut)
      );

      interest_protocol_amm::repay_flash_loan<ETH, USDC, IPX_V_ETH_USDC>(
        &mut s_pool,
        invoice,
        eth_coin,
        usdc_coin
      );

      test::return_shared(registry);
      test::return_shared(v_pool);
      test::return_shared(s_pool);    
    };
    test::end(scenario); 
  } 

  #[test]
  #[expected_failure(abort_code = amm::errors::EWrongRepayAmount, location = amm::interest_protocol_amm)]    
  fun test_repay_wrong_repay_amount_x() {
    let (scenario, alice, _) = start_test();  

    let scenario_mut = &mut scenario;

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(scenario_mut, eth_amount, usdc_amount);
    next_tx(scenario_mut, alice);
    {
      let request = request<Volatile, ETH, USDC, IPX_V_ETH_USDC>(scenario_mut);

      let (invoice, eth_coin, usdc_coin) = interest_protocol_amm::flash_loan<ETH, USDC, IPX_V_ETH_USDC>(
        &mut request.pool,
        eth_amount,
        usdc_amount,
        ctx(scenario_mut)
      );

      burn_for_testing(eth_coin);
      burn_for_testing(usdc_coin);

      let invoice_repay_amount_x = interest_protocol_amm::repay_amount_x(&invoice);
      let invoice_repay_amount_y = interest_protocol_amm::repay_amount_y(&invoice);      

      interest_protocol_amm::repay_flash_loan<ETH, USDC, IPX_V_ETH_USDC>(
        &mut request.pool,
        invoice,
        mint_for_testing(invoice_repay_amount_x - 1, ctx(scenario_mut)),
        mint_for_testing(invoice_repay_amount_y, ctx(scenario_mut))
      );

      destroy_request(request);   
    };
    test::end(scenario); 
  }   

  #[test]
  #[expected_failure(abort_code = amm::errors::EWrongRepayAmount, location = amm::interest_protocol_amm)]    
  fun test_repay_wrong_repay_amount_y() {
    let (scenario, alice, _) = start_test();  

    let scenario_mut = &mut scenario;

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(scenario_mut, eth_amount, usdc_amount);
    next_tx(scenario_mut, alice);
    {
      let request = request<Volatile, ETH, USDC, IPX_V_ETH_USDC>(scenario_mut);

      let (invoice, eth_coin, usdc_coin) = interest_protocol_amm::flash_loan<ETH, USDC, IPX_V_ETH_USDC>(
        &mut request.pool,
        eth_amount,
        usdc_amount,
        ctx(scenario_mut)
      );

      burn_for_testing(eth_coin);
      burn_for_testing(usdc_coin);

      let invoice_repay_amount_x = interest_protocol_amm::repay_amount_x(&invoice);
      let invoice_repay_amount_y = interest_protocol_amm::repay_amount_y(&invoice);      

      interest_protocol_amm::repay_flash_loan<ETH, USDC, IPX_V_ETH_USDC>(
        &mut request.pool,
        invoice,
        mint_for_testing(invoice_repay_amount_x, ctx(scenario_mut)),
        mint_for_testing(invoice_repay_amount_y - 1, ctx(scenario_mut))
      );

      destroy_request(request);   
    };
    test::end(scenario); 
  }        

  #[test]
  #[expected_failure(abort_code = amm::errors::EWrongModuleName, location = amm::utils)]  
  fun test_new_pool_wrong_lp_coin_metadata() {
    let (scenario, alice, _) = start_test();  

    let scenario_mut = &mut scenario;

    next_tx(scenario_mut, alice);
    {
      ipx_btce_eth::init_for_testing(ctx(scenario_mut));
    };

    next_tx(scenario_mut, alice);
    {
      let registry = test::take_shared<Registry>(scenario_mut);
      let lp_coin_cap = test::take_from_sender<TreasuryCap<IPX_BTCE_ETH>>(scenario_mut);
      let btc_metadata = test::take_shared<CoinMetadata<BTC>>(scenario_mut);
      let eth_metadata = test::take_shared<CoinMetadata<ETH>>(scenario_mut);
      let lp_coin_metadata = test::take_shared<CoinMetadata<IPX_BTCE_ETH>>(scenario_mut);
      
      let lp_coin = interest_protocol_amm::new<BTC, ETH, IPX_BTCE_ETH>(
        &mut registry,
        mint_for_testing(100, ctx(scenario_mut)),
        mint_for_testing(10, ctx(scenario_mut)),
        lp_coin_cap,
        &btc_metadata,
        &eth_metadata,
        &mut lp_coin_metadata,
        true,
        ctx(scenario_mut)
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
  #[expected_failure(abort_code = amm::errors::ESupplyMustHaveZeroValue, location = amm::interest_protocol_amm)]  
  fun test_new_pool_wrong_lp_coin_supply() {
    let (scenario, alice, _) = start_test();  

    let scenario_mut = &mut scenario;

    next_tx(scenario_mut, alice);
    {
      ipx_v_eth_usdc::init_for_testing(ctx(scenario_mut));
    };

    next_tx(scenario_mut, alice);
    {
      let registry = test::take_shared<Registry>(scenario_mut);
      let lp_coin_cap = test::take_from_sender<TreasuryCap<IPX_V_ETH_USDC>>(scenario_mut);
      let eth_metadata = test::take_shared<CoinMetadata<ETH>>(scenario_mut);
      let usdc_metadata = test::take_shared<CoinMetadata<USDC>>(scenario_mut);
      let lp_coin_metadata = test::take_shared<CoinMetadata<IPX_V_ETH_USDC>>(scenario_mut);

      burn_for_testing(coin::mint(&mut lp_coin_cap, 100, ctx(scenario_mut)));
      
      let lp_coin = interest_protocol_amm::new<ETH, USDC, IPX_V_ETH_USDC>(
        &mut registry,
        mint_for_testing(100, ctx(scenario_mut)),
        mint_for_testing(10, ctx(scenario_mut)),
        lp_coin_cap,
        &eth_metadata,
        &usdc_metadata,
        &mut lp_coin_metadata,
        true,
        ctx(scenario_mut)
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
  #[expected_failure(abort_code = amm::errors::EProvideBothCoins, location = amm::interest_protocol_amm)]  
  fun test_new_pool_zero_coin_x() {
    let (scenario, alice, _) = start_test();  

    let scenario_mut = &mut scenario;

    next_tx(scenario_mut, alice);
    {
      ipx_v_eth_usdc::init_for_testing(ctx(scenario_mut));
    };

    next_tx(scenario_mut, alice);
    {
      let registry = test::take_shared<Registry>(scenario_mut);
      let lp_coin_cap = test::take_from_sender<TreasuryCap<IPX_V_ETH_USDC>>(scenario_mut);
      let eth_metadata = test::take_shared<CoinMetadata<ETH>>(scenario_mut);
      let usdc_metadata = test::take_shared<CoinMetadata<USDC>>(scenario_mut);
      let lp_coin_metadata = test::take_shared<CoinMetadata<IPX_V_ETH_USDC>>(scenario_mut);
      
      let lp_coin =interest_protocol_amm::new<ETH, USDC, IPX_V_ETH_USDC>(
        &mut registry,
        coin::zero(ctx(scenario_mut)),
        mint_for_testing(10, ctx(scenario_mut)),
        lp_coin_cap,
        &eth_metadata,
        &usdc_metadata,
        &mut lp_coin_metadata,
        true,
        ctx(scenario_mut)
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
  #[expected_failure(abort_code = amm::errors::EProvideBothCoins, location = amm::interest_protocol_amm)]  
  fun test_new_pool_zero_coin_y() {
    let (scenario, alice, _) = start_test();  

    let scenario_mut = &mut scenario;

    next_tx(scenario_mut, alice);
    {
      ipx_v_eth_usdc::init_for_testing(ctx(scenario_mut));
    };

    next_tx(scenario_mut, alice);
    {
      let registry = test::take_shared<Registry>(scenario_mut);
      let lp_coin_cap = test::take_from_sender<TreasuryCap<IPX_V_ETH_USDC>>(scenario_mut);
      let eth_metadata = test::take_shared<CoinMetadata<ETH>>(scenario_mut);
      let usdc_metadata = test::take_shared<CoinMetadata<USDC>>(scenario_mut);
      let lp_coin_metadata = test::take_shared<CoinMetadata<IPX_V_ETH_USDC>>(scenario_mut);
      
      let lp_coin =interest_protocol_amm::new<ETH, USDC, IPX_V_ETH_USDC>(
        &mut registry,
        mint_for_testing(10, ctx(scenario_mut)),
        coin::zero(ctx(scenario_mut)),
        lp_coin_cap,
        &eth_metadata,
        &usdc_metadata,
        &mut lp_coin_metadata,
        true,
        ctx(scenario_mut)
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
  #[expected_failure(abort_code = amm::errors::EPoolAlreadyDeployed, location = amm::interest_protocol_amm)]  
  fun test_new_pool_deploy_same_pool() {
    let (scenario, alice, _) = start_test();  

    let scenario_mut = &mut scenario;

    next_tx(scenario_mut, alice);
    {
      ipx_v_eth_usdc::init_for_testing(ctx(scenario_mut));
    };

    next_tx(scenario_mut, alice);
    {
      let registry = test::take_shared<Registry>(scenario_mut);
      let lp_coin_cap = test::take_from_sender<TreasuryCap<IPX_V_ETH_USDC>>(scenario_mut);
      let eth_metadata = test::take_shared<CoinMetadata<ETH>>(scenario_mut);
      let usdc_metadata = test::take_shared<CoinMetadata<USDC>>(scenario_mut);
      let lp_coin_metadata = test::take_shared<CoinMetadata<IPX_V_ETH_USDC>>(scenario_mut);
      
      let lp_coin =interest_protocol_amm::new<ETH, USDC, IPX_V_ETH_USDC>(
        &mut registry,
        mint_for_testing(10, ctx(scenario_mut)),
        mint_for_testing(10, ctx(scenario_mut)),
        lp_coin_cap,
        &eth_metadata,
        &usdc_metadata,
        &mut lp_coin_metadata,
        true,
        ctx(scenario_mut)
      );

      burn_for_testing(lp_coin);

      test::return_shared(eth_metadata);
      test::return_shared(usdc_metadata);
      test::return_shared(lp_coin_metadata);
      test::return_shared(registry);
    };  

    next_tx(scenario_mut, alice);
    {
      ipx_v_eth_usdc::init_for_testing(ctx(scenario_mut));
    };

    next_tx(scenario_mut, alice);
    {
      let registry = test::take_shared<Registry>(scenario_mut);
      let lp_coin_cap = test::take_from_sender<TreasuryCap<IPX_V_ETH_USDC>>(scenario_mut);
      let eth_metadata = test::take_shared<CoinMetadata<ETH>>(scenario_mut);
      let usdc_metadata = test::take_shared<CoinMetadata<USDC>>(scenario_mut);
      let lp_coin_metadata = test::take_shared<CoinMetadata<IPX_V_ETH_USDC>>(scenario_mut);
      
      let lp_coin =interest_protocol_amm::new<ETH, USDC, IPX_V_ETH_USDC>(
        &mut registry,
        mint_for_testing(10, ctx(scenario_mut)),
        mint_for_testing(10, ctx(scenario_mut)),
        lp_coin_cap,
        &eth_metadata,
        &usdc_metadata,
        &mut lp_coin_metadata,
        true,
        ctx(scenario_mut)
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
  #[expected_failure(abort_code = amm::errors::ENoZeroCoin, location = amm::interest_protocol_amm)]  
  fun test_swap_zero_coin() {
    let (scenario, alice, _) = start_test();  

    let scenario_mut = &mut scenario;

    next_tx(scenario_mut, alice);
    {
      admin::init_for_testing(ctx(scenario_mut));
      interest_protocol_amm::init_for_testing(ctx(scenario_mut));
    };

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(scenario_mut, eth_amount, usdc_amount);

    next_tx(scenario_mut, alice);
    {
      let request = request<Volatile, ETH, USDC, IPX_V_ETH_USDC>(scenario_mut);

      let eth_coin = interest_protocol_amm::swap<USDC, ETH, IPX_V_ETH_USDC>(
        &mut request.pool,
        coin::zero(ctx(scenario_mut)),
        0,
        ctx(scenario_mut)
      );

      burn_for_testing(eth_coin);

      destroy_request(request);  
    };    
    test::end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = amm::errors::EPoolIsLocked, location = amm::interest_protocol_amm)]  
  fun test_swap_x_locked_pool() {
    let (scenario, alice, _) = start_test();  

    let scenario_mut = &mut scenario;

    next_tx(scenario_mut, alice);
    {
      admin::init_for_testing(ctx(scenario_mut));
      interest_protocol_amm::init_for_testing(ctx(scenario_mut));
    };

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(scenario_mut, eth_amount, usdc_amount);

    next_tx(scenario_mut, alice);
    {
      let request = request<Volatile, ETH, USDC, IPX_V_ETH_USDC>(scenario_mut);

      let (invoice, coin_x, coin_y) = interest_protocol_amm::flash_loan<ETH, USDC, IPX_V_ETH_USDC>(
        &mut request.pool,
        1,
        2,
        ctx(scenario_mut)
      );

      let eth_coin = interest_protocol_amm::swap<USDC, ETH, IPX_V_ETH_USDC>(
        &mut request.pool,
        mint_for_testing(1, ctx(scenario_mut)),
        0,
        ctx(scenario_mut)
      );

      interest_protocol_amm::repay_flash_loan<ETH, USDC, IPX_V_ETH_USDC>(
        &mut request.pool,
        invoice,
        coin_x,
        coin_y
      );

      burn_for_testing(eth_coin);

      destroy_request(request);   
    };    
    test::end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = amm::errors::EPoolIsLocked, location = amm::interest_protocol_amm)]  
  fun test_swap_y_locked_pool() {
    let (scenario, alice, _) = start_test();  

    let scenario_mut = &mut scenario;

    next_tx(scenario_mut, alice);
    {
      admin::init_for_testing(ctx(scenario_mut));
      interest_protocol_amm::init_for_testing(ctx(scenario_mut));
    };

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(scenario_mut, eth_amount, usdc_amount);

    next_tx(scenario_mut, alice);
    {
      let request = request<Volatile, ETH, USDC, IPX_V_ETH_USDC>(scenario_mut);

      let (invoice, coin_x, coin_y) = interest_protocol_amm::flash_loan<ETH, USDC, IPX_V_ETH_USDC>(
        &mut request.pool,
        1,
        2,
        ctx(scenario_mut)
      );

      let usdc_coin = interest_protocol_amm::swap<ETH, USDC, IPX_V_ETH_USDC>(
        &mut request.pool,
        mint_for_testing(1, ctx(scenario_mut)),
        0,
        ctx(scenario_mut)
      );

      interest_protocol_amm::repay_flash_loan<ETH, USDC, IPX_V_ETH_USDC>(
        &mut request.pool,
        invoice,
        coin_x,
        coin_y
      );

      burn_for_testing(usdc_coin);

      destroy_request(request);  
    };    
    test::end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = amm::errors::ESlippage, location = amm::interest_protocol_amm)]  
  fun test_swap_x_slippage() {
    let (scenario, alice, _) = start_test();  

    let scenario_mut = &mut scenario;

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(scenario_mut, eth_amount, usdc_amount);
    
    next_tx(scenario_mut, alice);
    {
      let request = request<Volatile, ETH, USDC, IPX_V_ETH_USDC>(scenario_mut);

      let amount_in = 3 * ETH_DECIMAL_SCALAR;
      let amount_in_fee = fees::get_fee_in_amount(&request.fees, amount_in);
      let expected_amount_out = volatile::get_amount_out(amount_in - amount_in_fee, eth_amount, usdc_amount);
      let amount_out_fee = fees::get_fee_out_amount(&request.fees, expected_amount_out);
      let expected_amount_out = expected_amount_out - amount_out_fee; 

      let usdc_coin = interest_protocol_amm::swap<ETH, USDC, IPX_V_ETH_USDC>(
        &mut request.pool,
        mint_for_testing(amount_in, ctx(scenario_mut)),
        expected_amount_out + 1,
        ctx(scenario_mut)
      );

      burn_for_testing(usdc_coin);

      destroy_request(request);   
    };

    test::end(scenario);
  }  

  #[test]
  #[expected_failure(abort_code = amm::errors::ESlippage, location = amm::interest_protocol_amm)]  
  fun test_swap_y_slippage() {
    let (scenario, alice, _) = start_test();  

    let scenario_mut = &mut scenario;

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(scenario_mut, eth_amount, usdc_amount);
    
    next_tx(scenario_mut, alice);
    {
      let request = request<Volatile, ETH, USDC, IPX_V_ETH_USDC>(scenario_mut);

      let eth_amount = interest_protocol_amm::balance_x<ETH, USDC, IPX_V_ETH_USDC>(&request.pool);
      let usdc_amount = interest_protocol_amm::balance_y<ETH, USDC, IPX_V_ETH_USDC>(&request.pool);

      let amount_in = 7777 * USDC_DECIMAL_SCALAR;
      let amount_in_fee = fees::get_fee_in_amount(&request.fees, amount_in);
      let expected_amount_out = volatile::get_amount_out(amount_in - amount_in_fee, usdc_amount, eth_amount);
      let amount_out_fee = fees::get_fee_out_amount(&request.fees, expected_amount_out);
      let expected_amount_out = expected_amount_out - amount_out_fee;       

      let eth_coin = interest_protocol_amm::swap<USDC, ETH, IPX_V_ETH_USDC>(
        &mut request.pool,
        mint_for_testing(amount_in, ctx(scenario_mut)),
        expected_amount_out + 1,
        ctx(scenario_mut)
       );

      burn_for_testing(eth_coin);

      destroy_request(request);     
    };    
    test::end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = amm::errors::ESlippage, location = amm::interest_protocol_amm)]    
  fun test_add_liquidity_slippage() {
    let (scenario, alice, _) = start_test();  

    let scenario_mut = &mut scenario;

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(scenario_mut, eth_amount, usdc_amount);

    next_tx(scenario_mut, alice);
    {
      let request = request<Volatile, ETH, USDC, IPX_V_ETH_USDC>(scenario_mut);

      let amount_x = 20 * ETH_DECIMAL_SCALAR;
      let amount_y = 27000 * USDC_DECIMAL_SCALAR;

      let (shares, _, _) = quote::add_liquidity<ETH, USDC, IPX_V_ETH_USDC>(&request.pool, amount_x, amount_y);

      let (lp_coin, eth_coin, usdc_coin) = interest_protocol_amm::add_liquidity<ETH, USDC, IPX_V_ETH_USDC>(
        &mut request.pool,
        mint_for_testing(amount_x, ctx(scenario_mut)),
        mint_for_testing(amount_y, ctx(scenario_mut)),
        shares + 1,
        ctx(scenario_mut)
      );

      burn_for_testing(lp_coin);
      burn_for_testing(eth_coin);
      burn_for_testing(usdc_coin);

      destroy_request(request);
    };
    test::end(scenario);    
  }
  
  #[test]
  #[expected_failure(abort_code = amm::errors::EPoolIsLocked, location = amm::interest_protocol_amm)]    
  fun test_add_liquidity_locked() {
    let (scenario, alice, _) = start_test();  

    let scenario_mut = &mut scenario;

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(scenario_mut, eth_amount, usdc_amount);

    next_tx(scenario_mut, alice);
    {
      let request = request<Volatile, ETH, USDC, IPX_V_ETH_USDC>(scenario_mut);

      let amount_x = 20 * ETH_DECIMAL_SCALAR;
      let amount_y = 27000 * USDC_DECIMAL_SCALAR;

      let (invoice, coin_x, coin_y) = interest_protocol_amm::flash_loan<ETH, USDC, IPX_V_ETH_USDC>(
        &mut request.pool,
        1,
        2,
        ctx(scenario_mut)
      );

      let (lp_coin, eth_coin, usdc_coin) = interest_protocol_amm::add_liquidity<ETH, USDC, IPX_V_ETH_USDC>(
        &mut request.pool,
        mint_for_testing(amount_x, ctx(scenario_mut)),
        mint_for_testing(amount_y, ctx(scenario_mut)),
        0,
        ctx(scenario_mut)
      );

      interest_protocol_amm::repay_flash_loan<ETH, USDC, IPX_V_ETH_USDC>(
        &mut request.pool,
        invoice,
        coin_x,
        coin_y
      );

      burn_for_testing(lp_coin);
      burn_for_testing(eth_coin);
      burn_for_testing(usdc_coin);

      destroy_request(request);
    };
    test::end(scenario);    
  }

  #[test]
  #[expected_failure(abort_code = amm::errors::EProvideBothCoins, location = amm::interest_protocol_amm)]    
  fun test_add_liquidity_zero_coin_x() {
    let (scenario, alice, _) = start_test();  

    let scenario_mut = &mut scenario;

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(scenario_mut, eth_amount, usdc_amount);

    next_tx(scenario_mut, alice);
    {
      let request = request<Volatile, ETH, USDC, IPX_V_ETH_USDC>(scenario_mut);

      let (lp_coin, eth_coin, usdc_coin) = interest_protocol_amm::add_liquidity<ETH, USDC, IPX_V_ETH_USDC>(
        &mut request.pool,
        coin::zero(ctx(scenario_mut)),
        mint_for_testing(1, ctx(scenario_mut)),
        0,
        ctx(scenario_mut)
      );

      burn_for_testing(lp_coin);
      burn_for_testing(eth_coin);
      burn_for_testing(usdc_coin);

      destroy_request(request);
    };
    test::end(scenario);    
  }  

  #[test]
  #[expected_failure(abort_code = amm::errors::EProvideBothCoins, location = amm::interest_protocol_amm)]    
  fun test_add_liquidity_zero_coin_y() {
    let (scenario, alice, _) = start_test();  

    let scenario_mut = &mut scenario;

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(scenario_mut, eth_amount, usdc_amount);

    next_tx(scenario_mut, alice);
    {
      let request = request<Volatile, ETH, USDC, IPX_V_ETH_USDC>(scenario_mut);

      let (lp_coin, eth_coin, usdc_coin) = interest_protocol_amm::add_liquidity<ETH, USDC, IPX_V_ETH_USDC>(
        &mut request.pool,
        mint_for_testing(1, ctx(scenario_mut)),
        coin::zero(ctx(scenario_mut)),
        0,
        ctx(scenario_mut)
      );

      burn_for_testing(lp_coin);
      burn_for_testing(eth_coin);
      burn_for_testing(usdc_coin);

      destroy_request(request);
    };
    test::end(scenario);    
  }  

  #[test]
  #[expected_failure(abort_code = amm::errors::EProvideBothCoins, location = amm::interest_protocol_amm)]    
  fun test_add_liquidity_both_zero_coins() {
    let (scenario, alice, _) = start_test();  

    let scenario_mut = &mut scenario;

    let eth_amount = 15 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
    deploy_eth_usdc_pool(scenario_mut, eth_amount, usdc_amount);

    next_tx(scenario_mut, alice);
    {
      let request = request<Volatile, ETH, USDC, IPX_V_ETH_USDC>(scenario_mut);

      let (lp_coin, eth_coin, usdc_coin) = interest_protocol_amm::add_liquidity<ETH, USDC, IPX_V_ETH_USDC>(
        &mut request.pool,
        coin::zero(ctx(scenario_mut)),
        coin::zero(ctx(scenario_mut)),
        0,
        ctx(scenario_mut)
      );

      burn_for_testing(lp_coin);
      burn_for_testing(eth_coin);
      burn_for_testing(usdc_coin);

      destroy_request(request);
    };
    test::end(scenario);    
  }  

  // #[test]
  // #[expected_failure(abort_code = amm::errors::ENoZeroCoin, location = amm::interest_protocol_amm)]  
  // fun test_remove_liquidity_no_zero_coin() {
  //   let (scenario, alice, _) = start_test();  

  //   let scenario_mut = &mut scenario;

  //   let eth_amount = 15 * ETH_DECIMAL_SCALAR;
  //   let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
  //   deploy_eth_usdc_pool(scenario_mut, eth_amount, usdc_amount);

  //   next_tx(scenario_mut, alice);
  //   {
  //     let request = request<Volatile, ETH, USDC, IPX_V_ETH_USDC>(scenario_mut);

  //     let (eth_coin, usdc_coin) = interest_protocol_amm::remove_liquidity<ETH, USDC, IPX_V_ETH_USDC>(
  //       &mut request.pool,
  //       coin::zero(ctx(scenario_mut)),
  //       0,
  //       0,
  //       ctx(scenario_mut)
  //     );   

  //     burn_for_testing(eth_coin);
  //     burn_for_testing(usdc_coin);

  //     destroy_request(request);
  //   };    
  //   test::end(scenario); 
  // }   

  // #[test]
  // #[expected_failure(abort_code = amm::errors::EPoolIsLocked, location = amm::interest_protocol_amm)]  
  // fun test_remove_liquidity_locked() {
  //   let (scenario, alice, _) = start_test();  

  //   let scenario_mut = &mut scenario;

  //   let eth_amount = 15 * ETH_DECIMAL_SCALAR;
  //   let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
  //   deploy_eth_usdc_pool(scenario_mut, eth_amount, usdc_amount);

  //   next_tx(scenario_mut, alice);
  //   {
  //     let request = request<Volatile, ETH, USDC, IPX_V_ETH_USDC>(scenario_mut);

  //     let (invoice, coin_x, coin_y) = interest_protocol_amm::flash_loan<ETH, USDC, IPX_V_ETH_USDC>(
  //       &mut request.pool,
  //       1,
  //       2,
  //       ctx(scenario_mut)
  //     );

  //     let (eth_coin, usdc_coin) = interest_protocol_amm::remove_liquidity<ETH, USDC, IPX_V_ETH_USDC>(
  //       &mut request.pool,
  //       mint_for_testing(1, ctx(scenario_mut)),
  //       0,
  //       0,
  //       ctx(scenario_mut)
  //     );   

  //     burn_for_testing(eth_coin);
  //     burn_for_testing(usdc_coin);

  //     interest_protocol_amm::repay_flash_loan<ETH, USDC, IPX_V_ETH_USDC>(
  //       &mut request.pool,
  //       invoice,
  //       coin_x,
  //       coin_y
  //     );

  //     destroy_request(request);
  //   };    
  //   test::end(scenario); 
  // }  

  // #[test]
  // #[expected_failure(abort_code = amm::errors::ESlippage, location = amm::interest_protocol_amm)] 
  // fun test_remove_liquidity_slippage_coin_x() {
  //   let (scenario, alice, _) = start_test();  

  //   let scenario_mut = &mut scenario;

  //   let eth_amount = 15 * ETH_DECIMAL_SCALAR;
  //   let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
  //   deploy_eth_usdc_pool(scenario_mut, eth_amount, usdc_amount);

  //   next_tx(scenario_mut, alice);
  //   {
  //     let request = request<Volatile, ETH, USDC, IPX_V_ETH_USDC>(scenario_mut);
  //     let initial_lp_coin_supply = interest_protocol_amm::lp_coin_supply<ETH, USDC, IPX_V_ETH_USDC>(&request.pool);  

  //     let (expected_x, expected_y) = quote::remove_liquidity<ETH, USDC, IPX_V_ETH_USDC>(&request.pool, initial_lp_coin_supply / 3);

  //     let (eth_coin, usdc_coin) = interest_protocol_amm::remove_liquidity<ETH, USDC, IPX_V_ETH_USDC>(
  //       &mut request.pool,
  //       mint_for_testing(initial_lp_coin_supply / 3, ctx(scenario_mut)),
  //       expected_x + 1,
  //       expected_y,
  //       ctx(scenario_mut)
  //     );   

  //     burn_for_testing(eth_coin);
  //     burn_for_testing(usdc_coin);

  //     destroy_request(request);
  //   };    
  //   test::end(scenario); 
  // }  

  // #[test]
  // #[expected_failure(abort_code = amm::errors::ESlippage, location = amm::interest_protocol_amm)] 
  // fun test_remove_liquidity_slippage_coin_y() {
  //   let (scenario, alice, _) = start_test();  

  //   let scenario_mut = &mut scenario;

  //   let eth_amount = 15 * ETH_DECIMAL_SCALAR;
  //   let usdc_amount = 37500 * USDC_DECIMAL_SCALAR;
    
  //   deploy_eth_usdc_pool(scenario_mut, eth_amount, usdc_amount);

  //   next_tx(scenario_mut, alice);
  //   {
  //     let request = request<Volatile, ETH, USDC, IPX_V_ETH_USDC>(scenario_mut);
  //     let initial_lp_coin_supply = interest_protocol_amm::lp_coin_supply<ETH, USDC, IPX_V_ETH_USDC>(&request.pool);  

  //     let (expected_x, expected_y) = quote::remove_liquidity<ETH, USDC, IPX_V_ETH_USDC>(&request.pool, initial_lp_coin_supply / 3);

  //     let (eth_coin, usdc_coin) = interest_protocol_amm::remove_liquidity<ETH, USDC, IPX_V_ETH_USDC>(
  //       &mut request.pool,
  //       mint_for_testing(initial_lp_coin_supply / 3, ctx(scenario_mut)),
  //       expected_x,
  //       expected_y + 1,
  //       ctx(scenario_mut)
  //     );   

  //     burn_for_testing(eth_coin);
  //     burn_for_testing(usdc_coin);

  //     destroy_request(request);
  //   };    
  //   test::end(scenario); 
  // } 

  struct Request {
    registry: Registry,
    pool: InterestPool,
    fees: Fees
  } 

  fun request<Curve, CoinX, CoinY, LpCoin>(scenario_mut: &Scenario): Request {
      let registry = test::take_shared<Registry>(scenario_mut);
      let pool_id = interest_protocol_amm::pool_id<Curve, CoinX, CoinY>(&registry);
      let pool = test::take_shared_by_id<InterestPool>(scenario_mut, option::destroy_some(pool_id));
      let fees = interest_protocol_amm::fees<CoinX, CoinY, LpCoin>(&pool);

    Request {
      registry,
      pool,
      fees
    }
  }

  fun destroy_request(request: Request) {
    let Request { registry, pool, fees: _ } = request;
  
    test::return_shared(registry);
    test::return_shared(pool);
  }        
  
  fun start_test(): (Scenario, address, address) {
    let scenario = scenario();
    let (alice, bob) = people();

    let scenario_mut = &mut scenario;

    deploy_coins(scenario_mut);

    next_tx(scenario_mut, alice);
    {
      admin::init_for_testing(ctx(scenario_mut));
      interest_protocol_amm::init_for_testing(ctx(scenario_mut));
    };

    (scenario, alice, bob)
  }
}