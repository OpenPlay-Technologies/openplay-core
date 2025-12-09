/// Module for storing key-value parameters using dynamic fields.
/// Allows flexible parameter storage that can be frozen after initialization.
module openplay_core::parameter_store;

use sui::dynamic_field as df;
use sui::transfer::freeze_object;

// === Structs ===
/// Object that stores parameters as dynamic fields.
/// Can be frozen to prevent further modifications.
public struct ParameterStore has key {
    id: UID,
}

// === View Functions ===
/// Returns the ID of the ParameterStore.
public fun id(self: &ParameterStore): ID {
    self.id.to_inner()
}

// === Public Functions ===
/// Creates a new ParameterStore.
public fun new(ctx: &mut TxContext): ParameterStore {
    ParameterStore { id: object::new(ctx) }
}

/// Freezes the ParameterStore, preventing further modifications.
public fun freeze_(self: ParameterStore) {
    freeze_object(self)
}

/// Adds a key-value pair to the ParameterStore.
/// Aborts with `sui::dynamic_field::EFieldAlreadyExists` if the ParameterStore already has an entry with
/// that key.
public fun add<Name: copy + drop + store, Value: store>(
    self: &mut ParameterStore,
    name: Name,
    value: Value,
) {
    df::add(&mut self.id, name, value);
}

/// Immutably borrows the ParameterStore's dynamic field with the name specified by `name: Name`.
/// Aborts with `EFieldDoesNotExist` if the ParameterStore does not have a field with that name.
/// Aborts with `EFieldTypeMismatch` if the field exists, but the value does not have the specified
/// type.
public fun borrow<Name: copy + drop + store, Value: store>(
    self: &ParameterStore,
    name: Name,
): &Value {
    df::borrow(&self.id, name)
}
