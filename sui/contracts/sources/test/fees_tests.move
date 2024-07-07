// #[test_only]
// module amm::fees_tests {
//     use sui::{
//         test_utils::assert_eq,
//         test_scenario::{Self as test, next_tx}
//     };

//     use amm::memez_amm_fees as fees;
  
//     use amm::deploy_utils::{people, scenario};

//     const MAX_BURN_FEE: u256 = 500_000_000_000_000_000; // 50%
//     const MAX_SWAP_FEE: u256 = 25_000_000_000_000_000; // 2.5%
//     const MAX_ADMIN_FEE: u256 = 300_000_000_000_000_000; // 30%
//     const MAX_LIQUIDITY_FEE: u256 = 500_000_000_000_000_000; // 30%
//     const ONE_PER_CENT: u256 = 10_000_000_000_000_000;

//     #[test]
//     fun sets_initial_state_correctly() {
//         let mut scenario = scenario();
//         let (alice, _) = people();

//         let test = &mut scenario;
    
//         next_tx(test, alice);
//         {
      
//             let fees = fees::new(
//                 ONE_PER_CENT * 2,
//                 ONE_PER_CENT * 20,
//                 ONE_PER_CENT * 30,
//                 ONE_PER_CENT * 25,
//             );

//             assert_eq(fees.swap(), ONE_PER_CENT * 2);
//             assert_eq(fees.burn(), ONE_PER_CENT * 20);
//             assert_eq(fees.admin(), ONE_PER_CENT * 30);
//             assert_eq(fees.liquidity(), ONE_PER_CENT * 25);

//         };
//         test::end(scenario);      
//     }

//     #[test]
//     fun updates_fees_correctly() {
//         let mut scenario = scenario();
//         let (alice, _) = people();

//         let test = &mut scenario;

//         next_tx(test, alice);
//         {
//             let mut fees = fees::new(
//                 ONE_PER_CENT * 2,
//                 ONE_PER_CENT * 20,
//                 ONE_PER_CENT * 30,
//                 ONE_PER_CENT * 25
//             );

//             fees::update_swap(&mut fees, option::some(MAX_SWAP_FEE));
//             fees::update_burn(&mut fees, option::some(MAX_BURN_FEE));
//             fees::update_admin(&mut fees, option::some(MAX_ADMIN_FEE));
//             fees::update_liquidity(&mut fees, option::some(MAX_LIQUIDITY_FEE));


//             assert_eq(fees.swap(), MAX_SWAP_FEE);
//             assert_eq(fees.burn(), MAX_BURN_FEE);
//             assert_eq(fees.admin(), MAX_ADMIN_FEE);
//             assert_eq(fees.liquidity(), MAX_LIQUIDITY_FEE);

//             fees::update_swap(&mut fees, option::none());
//             fees::update_burn(&mut fees, option::none());
//             fees::update_admin(&mut fees, option::none());
//             fees::update_liquidity(&mut fees, option::none());

//             assert_eq(fees.swap(), MAX_SWAP_FEE);
//             assert_eq(fees.burn(), MAX_BURN_FEE);
//             assert_eq(fees.admin(), MAX_ADMIN_FEE);
//             assert_eq(fees.liquidity(), MAX_LIQUIDITY_FEE);

//             fees::update_swap(&mut fees, option::some(0));
//             fees::update_burn(&mut fees, option::some(0));
//             fees::update_admin(&mut fees, option::some(0));
//             fees::update_liquidity(&mut fees, option::some(0));

//             assert_eq(fees.swap(), 0);
//             assert_eq(fees.burn(), 0);
//             assert_eq(fees.admin(), 0);
//             assert_eq(fees.liquidity(), 0);

//            fees::update_swap(&mut fees, option::some(1));
//             fees::update_burn(&mut fees, option::some(2));
//             fees::update_admin(&mut fees, option::some(3));
//             fees::update_liquidity(&mut fees, option::some(4));

//             assert_eq(fees.swap(), 1);
//             assert_eq(fees.burn(), 2);
//             assert_eq(fees.admin(), 3);
//             assert_eq(fees.liquidity(), 4);
//         };
//         test::end(scenario);
//     }

//     #[test]
//     fun calculates_fees_properly() {
//         let mut scenario = scenario();
//         let (alice, _) = people();

//         let test = &mut scenario;

//         next_tx(test, alice);
//         {
//             let fees = fees::new(
//                 ONE_PER_CENT * 10,
//                 ONE_PER_CENT * 20,
//                 ONE_PER_CENT * 30,
//                 ONE_PER_CENT * 25
//             );

//             let amount = 100;

//             assert_eq(fees::get_swap_amount(&fees, amount), 10);
//             assert_eq(fees::get_burn_amount(&fees, amount), 20);
//             assert_eq(fees::get_admin_amount(&fees, amount), 30);
//             assert_eq(fees::get_liquidity_amount(&fees, amount), 25);

//             assert_eq(fees::get_swap_amount_initial_amount(&fees, amount), 112); // rounds up
//             assert_eq(fees::get_burn_amount_initial_amount(&fees, amount), 125); // rounds up
//         };
//         test::end(scenario);
//     }

//     #[test]
//     #[expected_failure(abort_code = amm::memez_amm_errors::EFeeIsTooHigh, location = amm::memez_amm_fees)]  
//     fun aborts_max_swap_fee() {
//         let mut scenario = scenario();
//         let (alice, _) = people();

//         let test = &mut scenario;

//         next_tx(test, alice);
//         {
//             let mut fees = fees::new(
//                 ONE_PER_CENT * 10,
//                 ONE_PER_CENT * 20,
//                 ONE_PER_CENT * 30,
//                 ONE_PER_CENT * 25
//             );

//             fees.update_swap(option::some(MAX_SWAP_FEE + 1));
//         };
//         test::end(scenario);
//     }  

//     #[test]
//     #[expected_failure(abort_code = amm::memez_amm_errors::EFeeIsTooHigh, location = amm::memez_amm_fees)]  
//     fun aborts_max_burn_fee() {
//         let mut scenario = scenario();
//         let (alice, _) = people();

//         let test = &mut scenario;

//         next_tx(test, alice);
//         {
//             let mut fees = fees::new(
//                 ONE_PER_CENT * 10,
//                 ONE_PER_CENT * 20,
//                 ONE_PER_CENT * 30,
//                 ONE_PER_CENT * 25
//             );

//             fees.update_burn(option::some(MAX_BURN_FEE + 1));
//         };
//         test::end(scenario);
//     }   

//     #[test]
//     #[expected_failure(abort_code = amm::memez_amm_errors::EFeeIsTooHigh, location = amm::memez_amm_fees)]  
//     fun aborts_max_admin_fee() {
//         let mut scenario = scenario();
//         let (alice, _) = people();

//         let test = &mut scenario;
   
//         next_tx(test, alice);
//         {
//             let mut fees = fees::new(
//                 ONE_PER_CENT * 10,
//                 ONE_PER_CENT * 20,
//                 ONE_PER_CENT * 30,
//                 ONE_PER_CENT * 25
//             );

//             fees.update_admin(option::some(MAX_ADMIN_FEE + 1));
//         };
//         test::end(scenario);
//     }  

//     #[test]
//     #[expected_failure(abort_code = amm::memez_amm_errors::EFeeIsTooHigh, location = amm::memez_amm_fees)]  
//     fun aborts_max_liquidity_fee() {
//         let mut scenario = scenario();
//         let (alice, _) = people();

//         let test = &mut scenario;
   
//         next_tx(test, alice);
//         {
//             let mut fees = fees::new(
//                 ONE_PER_CENT * 10,
//                 ONE_PER_CENT * 20,
//                 ONE_PER_CENT * 30,
//                 ONE_PER_CENT * 25
//             );

//             fees.update_liquidity(option::some(MAX_ADMIN_FEE + 1));
//         };
//         test::end(scenario);
//     } 
// }