module amm::memez_amm_moving_average {

    // === Imports ===

    use sui::{
        clock::Clock,
        linked_table::{Self, LinkedTable}
    };

    // === Structs ===

    public struct Point(u256, u64) has store, drop, copy;

    public struct MovingAverage has store {
        interval: u64,
        sum: u256,
        data: LinkedTable<u64, Point>
    }

    // === Mutative Functions ===


    public(package) fun new(interval: u64, ctx: &mut TxContext): MovingAverage {
        MovingAverage {
            interval,
            sum: 0,
            data: linked_table::new(ctx)
        }
    }

    public(package) fun add(self: &mut MovingAverage, clock: &Clock, value: u64): u64 {
        
        // Convert Milliseconds => Minutes
        let timestamp = clock.timestamp_ms() / 60000;
       
        while(self.data.length() > 0 && timestamp - self.data[0].1 >= self.interval) {
            let (_, point) = self.data.pop_front();
            self.sum = self.sum - (point.0 as u256);
        };

        if (self.data.contains(timestamp)) {
            let point = self.data.borrow_mut(timestamp);
            point.0 = point.0 + (value as u256);
        } else {
            self.data.push_back(timestamp, Point((value as u256), timestamp));
        };

        self.sum = self.sum + (value as u256);

        (self.sum / (self.data.length() as u256) as u64)
    } 

    // === View Functions ===

    public(package) fun sum(self: &MovingAverage): u256 {
        self.sum
    }  

    public(package) fun calculate(self: &MovingAverage): u64 {
        let len = (self.data.length() as u256);
        if (len == 0) return 0;
        (self.sum / len as u64)
    }  

    // === Test-only Functions ===

    #[test_only]
    public(package) fun interval(self: &MovingAverage): u64 {
        self.interval
    }    
}