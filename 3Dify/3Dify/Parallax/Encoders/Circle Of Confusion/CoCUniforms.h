//
//  CoCUniforms.h
//  DoFRendering
//
//  Created by Bartłomiej Nowak on 14/11/2018.
//  Copyright © 2018 Bartłomiej Nowak. All rights reserved.
//

#ifndef CoCUniforms_h
#define CoCUniforms_h

#include <simd/simd.h>

typedef struct {
    simd_float1 focusDist, focusRange, bokehRadius;
} CoCUniforms;

#endif /* CoCUniforms_h */
