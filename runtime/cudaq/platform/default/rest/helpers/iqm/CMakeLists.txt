# ============================================================================ #
# Copyright (c) 2022 - 2025 NVIDIA Corporation & Affiliates.                   #
# All rights reserved.                                                         #
#                                                                              #
# This source code and the accompanying materials are made available under     #
# the terms of the Apache License 2.0 which accompanies this distribution.     #
# ============================================================================ #
target_sources(cudaq-rest-qpu PRIVATE IQMServerHelper.cpp)
add_target_config(iqm)
add_target_mapping_arch(iqm "Crystal_5.txt")
add_target_mapping_arch(iqm "Crystal_20.txt")
add_target_mapping_arch(iqm "Crystal_54.txt")


add_library(cudaq-serverhelper-iqm SHARED IQMServerHelper.cpp )
target_link_libraries(cudaq-serverhelper-iqm
  PUBLIC 
    cudaq-common 
    fmt::fmt-header-only 
)
install(TARGETS cudaq-serverhelper-iqm DESTINATION lib)

