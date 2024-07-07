module amm::memez_amm_volume {

    // === Imports ===

    use sui::{clock::Clock};

    use suitears::math64::mul_div_up;

    use amm::memez_amm_moving_average::{Self as ma, MovingAverage};

    // === Constants ===

    const FIVE_MINUTES: u64 = 300000;
    const ONE_HOUR: u64 = 3600000;
    const PRECISION: u64 = 1_000_000_000_000_000_000;
    
    // === Structs ===

    public struct Volume has store {
        short_x: MovingAverage,
        short_y: MovingAverage,
        long_x: MovingAverage,
        long_y: MovingAverage
    }

    // === Mutative Functions ===

    public(package) fun new(ctx: &mut TxContext): Volume {
        Volume {
            short_x: ma::new(FIVE_MINUTES, ctx),
            short_y: ma::new(FIVE_MINUTES, ctx),
            long_x: ma::new(ONE_HOUR, ctx),
            long_y: ma::new(ONE_HOUR, ctx)
        }
    }

    public(package) fun add_coin_x(self: &mut Volume, clock: &Clock, value: u64): u64 {
       let x =  self.short_x.add(clock, value);
       let y = self.long_x.add(clock, value);

       if (x == 0 || y == 0) return 0;

       safe_mul_div(x, y)
    }

    public(package) fun add_coin_y(self: &mut Volume, clock: &Clock, value: u64): u64 {
       let x =  self.short_y.add(clock, value);
       let y = self.long_y.add(clock, value);

       if (x == 0 || y == 0) return 0;

       safe_mul_div(x, y)
    }

    public(package) fun coin_x(self: &Volume): u64 {
       let x =  self.short_x.calculate();
       let y = self.long_x.calculate();

       if (x == 0 || y == 0) return 0;

       safe_mul_div(x, y)
    }

    public(package) fun coin_y(self: &Volume): u64 {
       let x =  self.short_y.calculate();
       let y = self.long_y.calculate();

       safe_mul_div(x, y)
    }

    // === View Functions ===

    fun safe_mul_div(x: u64, y: u64): u64 {
        if (x == 0 || y == 0) return 0;

       mul_div_up(x, PRECISION, y)
    }

    // === Test-only Functions === 
}