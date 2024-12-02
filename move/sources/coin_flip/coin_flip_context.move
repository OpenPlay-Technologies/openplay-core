module openplay::coin_flip_context;

// === Structs ===

// Context representing the current state of the game
public struct CoinFlipContext has store {
    stake: u64,
    result: CoinFlipResult,
    status: Status
}

// Result of the coin flip
public enum CoinFlipResult has drop, store {
    Head,
    Tail,
    HouseWins
}

// Status of the game
public enum Status has drop, store {
    Initialized,
    Settled
}

// === Public-Package Functions ===
public(package) fun empty(): CoinFlipContext {
    CoinFlipContext {
        stake: 0,
        result: CoinFlipResult::Head,
        status: Status::Initialized
    }
}

public(package) fun house_wins(self: &mut CoinFlipContext) {
    self.result = CoinFlipResult::HouseWins;
    self.status = Status::Settled;
}