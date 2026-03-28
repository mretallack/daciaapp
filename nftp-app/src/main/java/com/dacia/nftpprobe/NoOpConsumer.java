package com.dacia.nftpprobe;

import java.util.function.Consumer;

public class NoOpConsumer implements Consumer<Object> {
    @Override
    public void accept(Object o) {
        // no-op
    }
}
