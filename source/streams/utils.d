module streams.utils;

struct Optional(T) {
    const bool present = false;
    const T value = T.init;

    this(T value) {
        this.present = true;
        this.value = value;
    }

    bool notPresent() const {
        return !this.present;
    }
}

struct Either(A, B) {
    const Optional!A first;
    const Optional!B second;

    this(A value) {
        this.first = Optional!A(value);
        this.second = Optional!B.init;
    }

    this(B value) {
        this.second = Optional!B(value);
        this.first = Optional!A.init;
    }

    invariant {
        assert((first.present || second.present) && !(first.present && second.present));
    }
}

enum BufferAllocationStrategy { Linear, Doubling, None }


