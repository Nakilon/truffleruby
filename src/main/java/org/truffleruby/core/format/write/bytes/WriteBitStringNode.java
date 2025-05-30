/*
 * Copyright (c) 2015, 2025 Oracle and/or its affiliates. All rights reserved. This
 * code is released under a tri EPL/GPL/LGPL license. You can use it,
 * redistribute it and/or modify it under the terms of the:
 *
 * Eclipse Public License version 2.0, or
 * GNU General Public License version 2, or
 * GNU Lesser General Public License version 2.1.
 *
 * Some logic copied from jruby.util.Pack
 *
 *  * Version: EPL 2.0/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Eclipse Public
 * License Version 2.0 (the "License"); you may not use this file
 * except in compliance with the License. You may obtain a copy of
 * the License at http://www.eclipse.org/legal/epl-v20.html
 *
 * Software distributed under the License is distributed on an "AS
 * IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
 * implied. See the License for the specific language governing
 * rights and limitations under the License.
 *
 * Copyright (C) 2002-2004 Jan Arne Petersen <jpetersen@uni-bonn.de>
 * Copyright (C) 2002-2004 Anders Bengtsson <ndrsbngtssn@yahoo.se>
 * Copyright (C) 2003-2004 Thomas E Enebo <enebo@acm.org>
 * Copyright (C) 2004 Charles O Nutter <headius@headius.com>
 * Copyright (C) 2004 Stefan Matthias Aust <sma@3plus4.de>
 * Copyright (C) 2005 Derek Berner <derek.berner@state.nm.us>
 * Copyright (C) 2006 Evan Buswell <ebuswell@gmail.com>
 * Copyright (C) 2007 Nick Sieger <nicksieger@gmail.com>
 * Copyright (C) 2009 Joseph LaFata <joe@quibb.org>
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either of the GNU General Public License Version 2 or later (the "GPL"),
 * or the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the EPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the EPL, the GPL or the LGPL.
 */
package org.truffleruby.core.format.write.bytes;

import java.nio.ByteOrder;

import com.oracle.truffle.api.dsl.Bind;
import com.oracle.truffle.api.nodes.Node;
import com.oracle.truffle.api.strings.InternalByteArray;
import com.oracle.truffle.api.strings.TruffleString;
import org.truffleruby.core.format.FormatNode;

import com.oracle.truffle.api.dsl.Cached;
import com.oracle.truffle.api.dsl.NodeChild;
import com.oracle.truffle.api.dsl.Specialization;
import com.oracle.truffle.api.frame.VirtualFrame;
import org.truffleruby.language.library.RubyStringLibrary;

@NodeChild("value")
public abstract class WriteBitStringNode extends FormatNode {

    private final ByteOrder byteOrder;
    private final boolean star;
    private final int length;

    public WriteBitStringNode(ByteOrder byteOrder, boolean star, int length) {
        this.byteOrder = byteOrder;
        this.star = star;
        this.length = length;
    }

    @Specialization
    Object write(VirtualFrame frame, Object string,
            @Bind Node node,
            @Cached RubyStringLibrary libString,
            @Cached TruffleString.GetInternalByteArrayNode byteArrayNode) {
        var tstring = libString.getTString(node, string);
        var encoding = libString.getTEncoding(node, string);

        return write(frame, byteArrayNode.execute(tstring, encoding));
    }

    protected Object write(VirtualFrame frame, InternalByteArray byteArray) {
        int occurrences;

        int byteLength = byteArray.getLength();

        if (star) {
            occurrences = byteLength;
        } else {
            occurrences = length;
        }

        int currentByte = 0;
        int padLength = 0;

        if (occurrences > byteLength) {
            padLength = (occurrences - byteLength) / 2 + (occurrences + byteLength) % 2;
            occurrences = byteLength;
        }

        if (byteOrder == ByteOrder.LITTLE_ENDIAN) {
            for (int i = 0; i < occurrences;) {
                if ((byteArray.get(i++) & 1) != 0) { // if the low bit is set
                    currentByte |= 128; //set the high bit of the result
                }

                if ((i & 7) == 0) {
                    writeByte(frame, (byte) (currentByte & 0xff));
                    currentByte = 0;
                    continue;
                }

                //if the index is not a multiple of 8, we are not on a byte boundary
                currentByte >>= 1; //shift the byte
            }

            if ((occurrences & 7) != 0) { //if the length is not a multiple of 8
                currentByte >>= 7 - (occurrences & 7); //we need to pad the last byte
                writeByte(frame, (byte) (currentByte & 0xff));
            }
        } else {
            for (int i = 0; i < occurrences;) {
                currentByte |= byteArray.get(i++) & 1;

                // we filled up current byte; append it and create next one
                if ((i & 7) == 0) {
                    writeByte(frame, (byte) (currentByte & 0xff));
                    currentByte = 0;
                    continue;
                }

                //if the index is not a multiple of 8, we are not on a byte boundary
                currentByte <<= 1;
            }

            if ((occurrences & 7) != 0) { //if the length is not a multiple of 8
                currentByte <<= 7 - (occurrences & 7); //we need to pad the last byte
                writeByte(frame, (byte) (currentByte & 0xff));
            }
        }

        writeNullBytes(frame, padLength);

        return null;
    }

}
