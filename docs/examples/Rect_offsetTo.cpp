// Copyright 2019 Google LLC.
// Use of this source code is governed by a BSD-style license that can be found in the LICENSE file.
#include "tools/fiddle/examples.h"
REG_FIDDLE(Rect_offsetTo, 256, 256, true, 0) {
void draw(SkCanvas* canvas) {
    SkRect rect = { 10, 14, 50, 73 };
    rect.offsetTo(15, 27);
    SkDebugf("rect: %g, %g, %g, %g\n", rect.fLeft, rect.fTop, rect.fRight, rect.fBottom);
}
}  // END FIDDLE
