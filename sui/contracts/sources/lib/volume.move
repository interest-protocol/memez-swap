module amm::memez_amm_volume {

    // === Imports ===

    use sui::{clock::Clock};

    use suitears::math256::mul_div_up;

    use amm::memez_amm_ema::{Self as ema, EMA};

    // === Constants ===

    const FIVE_MINUTES: u64 = 300000;
    const ONE_HOUR: u64 = 3600000;
    const PRECISION: u256 = 1_000_000_000_000_000_000;
    
    // === Structs ===

    public struct Volume has store {
        short_x: EMA,
        short_y: EMA,
        long_x: EMA,
        long_y: EMA
    }

    // === Mutative Functions ===

    public(package) fun new(): Volume {
        Volume {
            short_x: ema::new(FIVE_MINUTES),
            short_y: ema::new(FIVE_MINUTES),
            long_x: ema::new(ONE_HOUR),
            long_y: ema::new(ONE_HOUR)
        }
    }

    public(package) fun add_coin_x(self: &mut Volume, clock: &Clock, value: u64): u256 {
       let x =  self.short_x.save_value(clock, (value as u256));
       let y = self.long_x.save_value(clock, (value as u256));

       safe_mul_div(x, y)
    }

    public(package) fun add_coin_y(self: &mut Volume, clock: &Clock, value: u64): u256 {
       let x =  self.short_y.save_value(clock, (value as u256));
       let y = self.long_y.save_value(clock, (value as u256));

       safe_mul_div(x, y)
    }

    public(package) fun multiplier_x(self: &Volume): u256 {
       let x =  self.short_x.last_ema_value();
       let y = self.long_x.last_ema_value();

       safe_mul_div(x, y)
    }

    public(package) fun multiplier_y(self: &Volume): u256 {
       let x =  self.short_y.last_ema_value();
       let y = self.long_y.last_ema_value();

       safe_mul_div(x, y)
    }

    // === View Functions ===

    fun safe_mul_div(x: u256, y: u256): u256 {
        if (x == 0 || y == 0) return 0;

       mul_div_up(x, PRECISION, y)
    }

    // === Test-only Functions === 
}