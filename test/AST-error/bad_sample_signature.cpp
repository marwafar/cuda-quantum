/*******************************************************************************
 * Copyright (c) 2022 - 2025 NVIDIA Corporation & Affiliates.                  *
 * All rights reserved.                                                        *
 *                                                                             *
 * This source code and the accompanying materials are made available under    *
 * the terms of the Apache License 2.0 which accompanies this distribution.    *
 ******************************************************************************/

// REQUIRES: c++20
// RUN: cudaq-quake %cpp_std %s -verify

#include <cudaq.h>

struct bad {
  int operator()(int i) __qpu__ {
    cudaq::qvector q(i);
    h(q);
    mz(q);
    return i;
  }
};

// expected-note@* {{}}
// expected-note@* {{}}
// expected-note@* {{}}
// expected-note@* {{}}
// expected-note@* {{}}
// expected-note@* {{}}
// expected-note@* {{}}
// expected-note@* 2 {{requires 3 arguments, but 2 were provided}}

int main() {
    cudaq::sample(bad{}, 5); // expected-error {{no matching function for call to}}
}
