module openplay::roulette_const;

public enum BetType {
    STRAIGHT_UP,
    SPLIT,
    STREET,
    CORNER,
    FIVE_NUMBER, // only available in American roulette
    COLUMN,
    DOZEN,
    HALF,
    COLOR,
    EVEN_ODD,
}


public enum Color {
    RED,
    BLACK,
    GREEN,
}

public enum State {
    NEW,
    INITIALIZED,
    SETTLED,
}

public enum WheelType {
    AMERICAN,
    EUROPEAN,
}
