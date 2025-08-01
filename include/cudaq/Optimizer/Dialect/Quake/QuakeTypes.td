/***********************************************************-*- tablegen -*-****
 * Copyright (c) 2022 - 2025 NVIDIA Corporation & Affiliates.                  *
 * All rights reserved.                                                        *
 *                                                                             *
 * This source code and the accompanying materials are made available under    *
 * the terms of the Apache License 2.0 which accompanies this distribution.    *
 ******************************************************************************/

#ifndef CUDAQ_OPTIMIZER_DIALECT_QUAKE_TYPES
#define CUDAQ_OPTIMIZER_DIALECT_QUAKE_TYPES

include "cudaq/Optimizer/Dialect/Quake/QuakeDialect.td"
include "mlir/IR/AttrTypeBase.td"

//===----------------------------------------------------------------------===//
// BaseType
//===----------------------------------------------------------------------===//

class QuakeType<string name, string typeMnemonic, list<Trait> traits = [],
        string baseCppClass = "mlir::Type">
    : TypeDef<QuakeDialect, name, traits, baseCppClass> {
  let mnemonic = typeMnemonic;
}

//===----------------------------------------------------------------------===//
// Wire type: quantum value type
//===----------------------------------------------------------------------===//

def WireType : QuakeType<"Wire", "wire"> {
  let summary = "A quantum value. Wires are a linear type.";
  let description = [{
    A `wire` is a primitive quantum "SSA-value" that differs from a traditional
    SSA-value in that it can and will be modified when used in any target
    position. That means quantum "SSA-values" are not true SSA values. To
    enforce this property a `wire` type is a linear type. Therefore, `wire`
    values must be used exactly once. A `wire` value might be thought of as
    having somewhat similar properties to volatile memory. An operation that
    uses a `wire` is required to return a new `wire` value reflecting the
    updated/new state and propagating the linear type.

    The following is a simple example of using `wire` values.

    ```mlir
      // Create two wires.
      %q0 = ... : !quake.wire
      %q1 = ... : !quake.wire

      // Apply some quantum gates.
      %q2:2 = quake.gate1 [%q0] %q1 : (!quake.wire, !quake.wire) ->
                 (!quake.wire, !quake.wire)
      %q3 = quake.gate2 %q2#0 : (!quake.wire) -> !quake.wire

      // Final use of the wires.
      quake.sink %q3 : !quake.wire
      quake.wrap %q2#1 to %r0 : !quake.wire, !quake.ref
    ```

    See also the description of the `ref` type.
  }];

  let genStorageClass = 0;
}

//===----------------------------------------------------------------------===//
// Control type: quantum value type
//===----------------------------------------------------------------------===//

def ControlType : QuakeType<"Control", "control"> {
  let summary = "A quantum control value.";
  let description = [{
    A value having type `control` is quite similar to a value of type `wire`.
    The distinction is that a value of type `control` must be used in a control
    position of a quantum operator. Using a qubit in a control position means
    the qubit \em{is} an SSA value. Values of type `control`, unlike values of
    type `wire`, can be defined once and used multiple times (in multiple
    control positions on distinct quantum operators) without changing value.

    ```mlir
      %10 = quake.to_ctrl %0 : (!quake.wire) -> !quake.control
      %11 = quake.g1 [%10] %1 : (!quake.control, !quake.wire) -> !quake.wire
      %12 = quake.g2 [%10] %2 : (!quake.control, !quake.wire) -> !quake.wire
      %13 = quake.g3 [%10] %3 : (!quake.control, !quake.wire) -> !quake.wire
      %20 = quake.from_ctrl %10 : (!quake.control) -> !quake.wire
    ```
  }];

  let genStorageClass = 0;
}

//===----------------------------------------------------------------------===//
// RefType: quantum reference type
//===----------------------------------------------------------------------===//

def RefType : QuakeType<"Ref", "ref"> {
  let summary = "reference to a quantum wire";
  let description = [{
    A `ref` represents a reference to a value of `wire` type.  One can view the
    values of this type as the horizontal lines in the following quantum circuit
    diagram. A value of type `ref` is an SSA value with reference semantics. A
    quantum operator that uses a `ref` value implicitly performs an unwrap
    (read), modify, and wrap (write) on the "wire" value referenced.

    ```
    q0 : ─────●────────── <--+
              │              |
            ┌─┴┐  ┌──┐       |
    q1 : ───┤  ├──┤  ├─── <--+-- `ref`s
            └──┘  └──┘
    ```

    The following example is the quake representation of the above circuit.
    (gate1 and gate2 are quantum gates.)

    ```mlir
      %q0 = quake.alloca : !quake.ref
      %q1 = quake.alloca : !quake.ref
      quake.gate1 [%q0] (%q1)
      quake.gate2 (%q1)
    ```

    In the example, `gate1` has quantum memory side-effects on the reference
    `%q1 : !quake.ref`, which is assumed to be modified in place, similar to a
    volatile memory location. The next operation, `gate2`, also has quantum
    memory side-effects through the same reference, `%q1`. Because these
    operations use the same reference, they cannot be reordered relative to one
    another.
    
    Furthermore, `gate1` implies \em{only} a quantum memory read side-effect on
    the reference value `%q0`. This is because `%q0` appears in a control
    position in `gate1`, as indicated by the square brackets.
  }];

  let genStorageClass = 0;
}

//===----------------------------------------------------------------------===//
// VeqType: quantum reference type
//===----------------------------------------------------------------------===//

def VeqType : QuakeType<"Veq", "veq"> {
  let summary = "an aggregate of quantum references";
  let description = [{
    A value of type `veq` is a (linear) collection of values of type `ref`.
    These aggregates are a convenience for referring to an entire group of
    quantum memory references. A `veq` value is an SSA value and can be defined
    once and used multiple times. `ref` values in a `veq` are non-volatile, so
    extracting a `ref` at the same index multiple times yields copies of the
    same quantum memory reference.
  }];

  let parameters = (ins "std::size_t":$size);

  let hasCustomAssemblyFormat = 1;
  
  let extraClassDeclaration = [{
    static constexpr std::size_t kDynamicSize =
      std::numeric_limits<std::size_t>::max();

    bool hasSpecifiedSize() const { return getSize() != kDynamicSize; }
    static VeqType getUnsized(mlir::MLIRContext *ctx) {
      return VeqType::get(ctx, kDynamicSize);
    }
  }];
}

//===----------------------------------------------------------------------===//
// StruqType: quantum reference type; product of veq and ref types.
//===----------------------------------------------------------------------===//

def StruqType : QuakeType<"Struq", "struq"> {
  let summary = "a product type of quantum references";
  let description = [{
    This type allows one to group veqs of quantum references together in a
    single product type.

    To support Python, a struq type can be assigned a name. This allows the
    python bridge to perform dictionary based lookups on member field names.
  }];

  let parameters = (ins
    "mlir::StringAttr":$name,
    // members must be NonStruqRefType.
    ArrayRefParameter<"mlir::Type">:$members
  );

  let hasCustomAssemblyFormat = 1;

  let extraClassDeclaration = [{
    std::size_t getNumMembers() const { return getMembers().size(); }
  }];

  let builders = [
    TypeBuilder<(ins CArg<"llvm::ArrayRef<mlir::Type>">:$members), [{
      return $_get($_ctxt, mlir::StringAttr{}, members);
    }]>,
    TypeBuilder<(ins CArg<"llvm::StringRef">:$name,
                     CArg<"llvm::ArrayRef<mlir::Type>">:$members), [{
      return $_get($_ctxt, mlir::StringAttr::get($_ctxt, name), members);
    }]>
  ];
}

def CableType : QuakeType<"Cable", "cable"> {
  let summary = "the type of a sequence of wires bound together";
  let description = [{
    This is the type of an aggregate of wire types. It is simply syntactic
    sugar that allows a group of wires to be passed around as a single cable
    value.
  }];

  let parameters = (ins "std::uint64_t":$size);

  let assemblyFormat = "`<` $size `>`";
}

//===----------------------------------------------------------------------===//
// MeasureType: classical data type
//===----------------------------------------------------------------------===//

def MeasureType : QuakeType<"Measure", "measure"> {
  let summary = "a classical result produced by a quantum measurement";
  let description = [{
    A quantum measurement captures the state of a qubit and returns a classical
    regular (not linear) value from the measurement. Depending on the target
    system this value may have two or more logical states. Typically, a value of
    type `measure` will be discriminated into a binary bit.

    ```mlir
      %m = quake.mz %0 : (!quake.ref) -> !quake.measure
      quake.dealloc %0 : !quake.ref
    ```
  }];

  let genStorageClass = 0;
}

//===----------------------------------------------------------------------===//
// StateType
//===----------------------------------------------------------------------===//

def quake_StateType : QuakeType<"State", "state"> {
  let summary = "Proxy for the cudaq::state class.";
  let description = [{
    The cudaq::state class is an abstraction for any data that may be used to
    describe the initial state of a set of qubits. It would typically be used
    in a simulation environment.

    The CUDA-Q runtime will implement an ABI of intrinsic functions for the
    compiler generated code to interface with this information in a generic
    manner.

    There are no legal operations in Quake/CC on a value of type `!quake.state`.
    Only pointers to such values should exist in the IR for the purposes of
    passing references to state objects to runtime functions at codegen.
  }];
  let genStorageClass = 0;
}

def AnyQTypeLike : TypeConstraint<Or<[WireType.predicate, VeqType.predicate,
        ControlType.predicate, RefType.predicate, StruqType.predicate]>,
        "quake quantum types">;
def AnyQType : Type<AnyQTypeLike.predicate, "quantum type">;
def AnyQTargetTypeLike : TypeConstraint<Or<[WireType.predicate,
        VeqType.predicate, RefType.predicate]>, "quake quantum target types">;
def AnyQTargetType : Type<AnyQTargetTypeLike.predicate, "quantum target type">;
def AnyRefTypeLike : TypeConstraint<Or<[VeqType.predicate, StruqType.predicate,
        RefType.predicate]>, "quake quantum reference types">;
def AnyRefType : Type<AnyRefTypeLike.predicate, "quantum reference type">;
def NonStruqRefTypeLike : TypeConstraint<Or<[VeqType.predicate,
        RefType.predicate]>, "non-struct quake quantum reference types">;
def NonStruqRefType : Type<NonStruqRefTypeLike.predicate,
        "non-struct quantum reference type">;
def AnyQValueTypeLike : TypeConstraint<Or<[WireType.predicate,
        ControlType.predicate]>, "quake quantum value types">;
def AnyQValueType : Type<AnyQValueTypeLike.predicate, "quantum value type">;
def AnyQLinearType : Type<WireType.predicate, "linear quantum value type">;

#endif // CUDAQ_OPTIMIZER_DIALECT_QUAKE_TYPES
