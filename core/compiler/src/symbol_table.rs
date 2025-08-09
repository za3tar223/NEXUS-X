//! Symbol Table for NEXUS-X Language
//! 
//! Hierarchical symbol table with scope management, type information,
//! and support for generics, traits, and modules.

use std::collections::HashMap;
use crate::ast::{Type, Visibility};
use crate::error::{CompilerError, Result};
use crate::SourceLocation;

/// Symbol table with hierarchical scopes
#[derive(Debug, Clone)]
pub struct SymbolTable {
    /// Stack of scopes (innermost scope is at the end)
    scopes: Vec<Scope>,
    /// Global scope index
    global_scope: usize,
    /// Module information
    modules: HashMap<String, ModuleInfo>,
    /// Current module path
    current_module: Vec<String>,
}

/// A single scope containing symbols
#[derive(Debug, Clone)]
pub struct Scope {
    /// Symbols in this scope
    symbols: HashMap<String, Symbol>,
    /// Scope type
    scope_type: ScopeType,
    /// Parent scope index (None for global scope)
    parent: Option<usize>,
    /// Scope location in source
    location: Option<SourceLocation>,
}

/// Type of scope
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ScopeType {
    /// Global/module scope
    Global,
    /// Function scope
    Function,
    /// Block scope
    Block,
    /// Struct/enum scope
    Type,
    /// Trait scope
    Trait,
    /// Implementation scope
    Impl,
    /// Loop scope (for break/continue)
    Loop,
}

/// Symbol information
#[derive(Debug, Clone, PartialEq)]
pub struct Symbol {
    /// Symbol name
    pub name: String,
    /// Symbol kind
    pub kind: SymbolKind,
    /// Symbol type
    pub symbol_type: Type,
    /// Visibility
    pub visibility: Visibility,
    /// Mutability (for variables)
    pub mutable: bool,
    /// Location where symbol is defined
    pub location: SourceLocation,
    /// Generic parameters (for functions, types)
    pub generic_params: Vec<String>,
    /// Documentation comments
    pub documentation: Option<String>,
}

/// Kind of symbol
#[derive(Debug, Clone, PartialEq)]
pub enum SymbolKind {
    /// Variable symbol
    Variable,
    /// Constant symbol
    Constant,
    /// Function symbol
    Function {
        /// Function parameters
        parameters: Vec<(String, Type)>,
        /// Return type
        return_type: Type,
        /// Is this an async function?
        is_async: bool,
        /// Is this an external function?
        is_extern: bool,
    },
    /// Type symbol (struct, enum)
    Type {
        /// Type kind
        type_kind: TypeKind,
        /// Type fields/variants
        members: Vec<TypeMember>,
    },
    /// Trait symbol
    Trait {
        /// Trait methods
        methods: Vec<Symbol>,
        /// Super traits
        super_traits: Vec<String>,
    },
    /// Module symbol
    Module {
        /// Module path
        path: Vec<String>,
        /// Exported symbols
        exports: HashMap<String, Symbol>,
    },
    /// Generic type parameter
    GenericParam {
        /// Constraints/bounds
        bounds: Vec<String>,
    },
}

/// Type definition kind
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TypeKind {
    /// Struct type
    Struct,
    /// Enum type
    Enum,
    /// Union type
    Union,
    /// Type alias
    Alias,
}

/// Type member (field or enum variant)
#[derive(Debug, Clone, PartialEq)]
pub struct TypeMember {
    /// Member name
    pub name: String,
    /// Member type
    pub member_type: Type,
    /// Member visibility
    pub visibility: Visibility,
    /// Member location
    pub location: SourceLocation,
    /// For enum variants: associated data types
    pub variant_data: Option<Vec<Type>>,
}

/// Module information
#[derive(Debug, Clone)]
pub struct ModuleInfo {
    /// Module name
    pub name: String,
    /// Module path
    pub path: Vec<String>,
    /// Module symbols
    pub symbols: HashMap<String, Symbol>,
    /// Imported modules
    pub imports: HashMap<String, Vec<String>>, // alias -> full path
    /// Module location
    pub location: SourceLocation,
}

// Implementation continues with all the methods shown earlier...
// [The rest of the implementation from the previous file]

impl SymbolTable {
    pub fn new() -> Self {
        let global_scope = Scope::new(ScopeType::Global, None, None);
        Self {
            scopes: vec![global_scope],
            global_scope: 0,
            modules: HashMap::new(),
            current_module: Vec::new(),
        }
    }
    
    // All other methods from the previous implementation...
}

// [Include all other implementations from the previous symbol_table.rs file]