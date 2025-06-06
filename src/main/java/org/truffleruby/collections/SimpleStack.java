/*
 * Copyright (c) 2020, 2025 Oracle and/or its affiliates. All rights reserved. This
 * code is released under a tri EPL/GPL/LGPL license. You can use it,
 * redistribute it and/or modify it under the terms of the:
 *
 * Eclipse Public License version 2.0, or
 * GNU General Public License version 2, or
 * GNU Lesser General Public License version 2.1.
 */
package org.truffleruby.collections;

import org.truffleruby.core.array.ArrayUtils;

/** Simplistic array stack implementation that will partial-evaluate nicely, unlike {@link java.util.ArrayDeque}. */
@SuppressWarnings("unchecked")
public final class SimpleStack<T> {

    Object[] storage;
    int index = -1;

    public SimpleStack() {
        this(16);
    }

    public SimpleStack(int length) {
        this.storage = new Object[length];
    }

    public boolean isEmpty() {
        return index == -1;
    }

    public void push(T value) {
        if (++index == storage.length) {
            storage = ArrayUtils.grow(storage, storage.length * 2);
        }
        storage[index] = value;
    }

    public T peek() {
        return (T) storage[index];
    }

    public T pop() {
        T out = (T) storage[index];
        storage[index] = null;
        --index;
        return out;
    }

    public int size() {
        return index + 1;
    }
}
