/*
 * Copyright (c) 2024, 2025 Oracle and/or its affiliates. All rights reserved. This
 * code is released under a tri EPL/GPL/LGPL license. You can use it,
 * redistribute it and/or modify it under the terms of the:
 *
 * Eclipse Public License version 2.0, or
 * GNU General Public License version 2, or
 * GNU Lesser General Public License version 2.1.
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
 * Copyright (C) 2002-2004 Anders Bengtsson <ndrsbngtssn@yahoo.se>
 * Copyright (C) 2002-2004 Jan Arne Petersen <jpetersen@uni-bonn.de>
 * Copyright (C) 2004 Thomas E Enebo <enebo@acm.org>
 * Copyright (C) 2004 Stefan Matthias Aust <sma@3plus4.de>
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
package org.truffleruby.parser;

import org.prism.Loader;
import org.prism.ParseResult;
import org.truffleruby.core.encoding.Encodings;
import org.truffleruby.core.encoding.RubyEncoding;
import org.truffleruby.core.encoding.TStringUtils;

import java.nio.charset.Charset;

public final class YARPLoader extends Loader {

    public static ParseResult load(byte[] serialized, byte[] sourceBytes, RubySource rubySource) {
        return new YARPLoader(serialized, sourceBytes, rubySource).load();
    }

    private final RubyEncoding encoding;

    public YARPLoader(byte[] serialized, byte[] sourceBytes, RubySource rubySource) {
        super(serialized, sourceBytes);
        this.encoding = rubySource.getEncoding();
    }

    @Override
    public Charset getEncodingCharset(String encodingName) {
        var rubyEncoding = Encodings.getBuiltInEncoding(encodingName);
        assert rubyEncoding == encoding : rubyEncoding + " (" + encodingName + ") vs " + encoding;
        return null; // encodingCharset is not used
    }

    @Override
    public String bytesToName(byte[] bytes) {
        return TStringUtils.bytesToJavaStringOrThrow(bytes, 0, bytes.length, encoding);
    }

}
