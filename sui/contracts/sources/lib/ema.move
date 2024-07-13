module amm::memez_amm_ema {

    // === Imports ===

    use sui::{
        clock::Clock
    };

    use suitears::{
        int,
        fixed_point_wad
    };

    // === Constants ===

    const PRECISION: u256 = 1_000_000_000_000_000_000;
    const MAX_E: u256 = 41_000_000_000_000_000_000_000;

    // === Structs ===

    public struct EMA has store {
        last_time: u64,
        sample_interval: u256,
        last_value: u256,
        last_ema_value: u256
    }

    // === Mutative Functions ===

    public fun new(sample_interval: u64): EMA {
        EMA {
            last_time: 0,
            sample_interval: (sample_interval as u256),
            last_value: 0,
            last_ema_value: 0
        }
    }

    public fun save_value(self: &mut EMA, clock: &Clock, value: u256): u256 {
        self.last_ema_value = self.ema_value(clock);
        self.last_value = value;
        self.last_time = clock.timestamp_ms();

        self.last_ema_value
    }

    // === View Functions ===

    public fun last_time(self: &EMA): u64 {
        self.last_time
    }

    public fun sample_interval(self: &EMA): u64 {
        (self.sample_interval as u64)
    }

    public fun last_value(self: &EMA): u256 {
        self.last_value
    }

    public fun last_ema_value(self: &EMA): u256 {
        self.last_ema_value
    }

    // === Private Functions ===

    fun ema_value(self: &mut EMA, clock: &Clock): u256 {
        if (clock.timestamp_ms() > self.last_time) {

            let timestamp_delta = ((clock.timestamp_ms() - self.last_time) as u256);
            let e = (timestamp_delta * PRECISION) / self.sample_interval;

            if (e > MAX_E) {
                self.last_value
            } else {
                let alpha = int::to_u256(fixed_point_wad::exp(int::neg_from_u256((e)))); 
                (self.last_value * (PRECISION - alpha) + self.last_ema_value * alpha) / PRECISION
            }
        } else {
            self.last_ema_value
        }
    }

    // === Test-only Functions ===
  
}