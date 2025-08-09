//! NEXUS-X Runtime Fabric
//! 
//! Production-ready runtime system with zero-copy memory management,
//! advanced garbage collection, and NUMA-aware allocation strategies.

#![deny(unsafe_code)]
#![warn(missing_docs, rust_2018_idioms)]

pub mod memory;
pub mod gc;
pub mod numa;
pub mod metrics;
pub mod error;

pub use memory::{Arena, ArenaAllocator, MemoryPool, Region};
pub use gc::{GarbageCollector, GenerationalGC, WriteBarrier};
pub use numa::{NumaAware, AffinityManager};
pub use error::{RuntimeError, Result};

use std::sync::Arc;
use parking_lot::RwLock;
use tracing::{info, debug, trace};

/// NEXUS-X Runtime Fabric
/// 
/// The central runtime system coordinating memory management, garbage collection,
/// and system resources. Designed for zero-copy operations and real-time performance.
#[derive(Debug)]
pub struct Runtime {
    /// Memory management subsystem
    memory_manager: Arc<memory::MemoryManager>,
    /// Garbage collector
    gc: Arc<dyn GarbageCollector + Send + Sync>,
    /// NUMA topology manager
    numa_manager: Option<Arc<numa::NumaManager>>,
    /// Runtime metrics collector
    metrics: Arc<metrics::MetricsCollector>,
    /// Runtime configuration
    config: Arc<RwLock<RuntimeConfig>>,
}

/// Runtime Configuration
#[derive(Debug, Clone)]
pub struct RuntimeConfig {
    /// Maximum heap size in bytes
    pub max_heap_size: usize,
    /// GC trigger threshold (percentage of heap usage)
    pub gc_threshold: f32,
    /// Enable NUMA awareness
    pub numa_enabled: bool,
    /// Enable debugging features
    pub debug_enabled: bool,
    /// Metrics collection interval
    pub metrics_interval_ms: u64,
}

impl Default for RuntimeConfig {
    fn default() -> Self {
        Self {
            max_heap_size: 1024 * 1024 * 1024, // 1GB
            gc_threshold: 0.8, // 80%
            numa_enabled: cfg!(feature = "numa"),
            debug_enabled: cfg!(feature = "debugging"),
            metrics_interval_ms: 1000, // 1 second
        }
    }
}

impl Runtime {
    /// Create a new runtime with default configuration
    pub fn new() -> Result<Self> {
        Self::with_config(RuntimeConfig::default())
    }
    
    /// Create a new runtime with custom configuration
    pub fn with_config(config: RuntimeConfig) -> Result<Self> {
        info!("Initializing NEXUS-X Runtime Fabric");
        
        // Initialize memory manager
        let memory_manager = Arc::new(memory::MemoryManager::new(config.max_heap_size)?);
        
        // Initialize garbage collector
        let gc: Arc<dyn GarbageCollector + Send + Sync> = Arc::new(
            gc::GenerationalGC::new(memory_manager.clone())?
        );
        
        // Initialize NUMA manager if enabled
        let numa_manager = if config.numa_enabled {
            Some(Arc::new(numa::NumaManager::new()?))
        } else {
            None
        };
        
        // Initialize metrics collector
        let metrics = Arc::new(metrics::MetricsCollector::new(config.metrics_interval_ms));
        
        let runtime = Self {
            memory_manager,
            gc,
            numa_manager,
            metrics,
            config: Arc::new(RwLock::new(config)),
        };
        
        info!("NEXUS-X Runtime Fabric initialized successfully");
        Ok(runtime)
    }
    
    /// Get the memory manager
    pub fn memory_manager(&self) -> &Arc<memory::MemoryManager> {
        &self.memory_manager
    }
    
    /// Get the garbage collector
    pub fn gc(&self) -> &Arc<dyn GarbageCollector + Send + Sync> {
        &self.gc
    }
    
    /// Get the NUMA manager if available
    pub fn numa_manager(&self) -> Option<&Arc<numa::NumaManager>> {
        self.numa_manager.as_ref()
    }
    
    /// Get runtime metrics
    pub fn metrics(&self) -> &Arc<metrics::MetricsCollector> {
        &self.metrics
    }
    
    /// Update runtime configuration
    pub fn update_config<F>(&self, updater: F) -> Result<()>
    where
        F: FnOnce(&mut RuntimeConfig) -> Result<()>,
    {
        let mut config = self.config.write();
        updater(&mut *config)?
        debug!("Runtime configuration updated");
        Ok(())
    }
    
    /// Trigger garbage collection
    pub fn collect_garbage(&self) -> Result<memory::GCStats> {
        debug!("Manual garbage collection triggered");
        self.gc.collect()
    }
    
    /// Get runtime statistics
    pub fn stats(&self) -> RuntimeStats {
        RuntimeStats {
            heap_size: self.memory_manager.heap_size(),
            heap_used: self.memory_manager.heap_used(),
            gc_stats: self.gc.stats(),
            numa_stats: self.numa_manager.as_ref().map(|nm| nm.stats()),
        }
    }
    
    /// Shutdown the runtime gracefully
    pub fn shutdown(&self) -> Result<()> {
        info!("Shutting down NEXUS-X Runtime Fabric");
        
        // Final garbage collection
        let _ = self.gc.collect();
        
        // Stop metrics collection
        self.metrics.stop();
        
        info!("NEXUS-X Runtime Fabric shutdown completed");
        Ok(())
    }
}

/// Runtime statistics
#[derive(Debug)]
pub struct RuntimeStats {
    /// Current heap size in bytes
    pub heap_size: usize,
    /// Current heap usage in bytes
    pub heap_used: usize,
    /// Garbage collection statistics
    pub gc_stats: memory::GCStats,
    /// NUMA statistics if available
    pub numa_stats: Option<numa::NumaStats>,
}

impl Drop for Runtime {
    fn drop(&mut self) {
        let _ = self.shutdown();
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[tokio::test]
    async fn test_runtime_creation() {
        let runtime = Runtime::new().unwrap();
        assert!(runtime.memory_manager().heap_size() > 0);
    }
    
    #[tokio::test]
    async fn test_memory_allocation() {
        let runtime = Runtime::new().unwrap();
        let arena = runtime.memory_manager().create_arena(1024).unwrap();
        
        let allocation = arena.allocate(64).unwrap();
        assert_eq!(allocation.size(), 64);
    }
    
    #[tokio::test]
    async fn test_garbage_collection() {
        let runtime = Runtime::new().unwrap();
        let stats_before = runtime.stats();
        
        // Allocate some memory
        let _arena = runtime.memory_manager().create_arena(1024).unwrap();
        
        // Force GC
        let gc_stats = runtime.collect_garbage().unwrap();
        assert!(gc_stats.collections_count > 0);
        
        let stats_after = runtime.stats();
        assert!(stats_after.gc_stats.collections_count >= stats_before.gc_stats.collections_count);
    }
}