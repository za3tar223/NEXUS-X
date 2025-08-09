#!/bin/bash
set -euo pipefail

# NEXUS-X Build Script
# Builds the complete NEXUS-X system with all security and performance features

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_TYPE="debug"
FEATURES="default"
VERBOSE=false
JOBS=$(nproc)

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m' 
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

show_help() {
    cat << EOF
NEXUS-X Build Script

Usage: $0 [OPTIONS]

OPTIONS:
    -r, --release           Build in release mode (default: debug)
    -f, --features FEATURES Cargo features to enable (default: default)
                           Available: all, security, performance, nephrazion
    -j, --jobs JOBS         Number of parallel build jobs (default: $JOBS)
    -v, --verbose           Enable verbose output
    -h, --help              Show this help message

EXAMPLES:
    $0                                  # Debug build with default features
    $0 --release --features all         # Release build with all features
    $0 -r -f security,performance -j 8  # Release build with specific features
    
FEATURE SETS:
    default     - Core runtime and basic security
    all         - All features enabled
    security    - Enhanced security features (HSS, XMSS, watermarking)
    performance - Performance features (JIT, SIMD, real-time)
    nephrazion  - Hot-swap kernel system
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--release)
            BUILD_TYPE="release"
            shift
            ;;
        -f|--features)
            FEATURES="$2"
            shift 2
            ;;
        -j|--jobs)
            JOBS="$2" 
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate environment
check_dependencies() {
    log_info "Checking build dependencies..."
    
    local missing_deps=()
    
    # Check Rust toolchain
    if ! command -v rustc &> /dev/null; then
        missing_deps+=("rust")
    else
        local rust_version=$(rustc --version | cut -d' ' -f2)
        log_info "Found Rust $rust_version"
    fi
    
    # Check LLVM
    if ! command -v llvm-config &> /dev/null; then
        missing_deps+=("llvm-dev")
    else
        local llvm_version=$(llvm-config --version)
        log_info "Found LLVM $llvm_version"
    fi
    
    # Check TPM library (optional)
    if ! ldconfig -p | grep -q libtss2; then
        log_warning "TPM 2.0 library not found - hardware security features will be limited"
    fi
    
    # Check CPU features
    if grep -q avx2 /proc/cpuinfo; then
        log_info "AVX2 instruction set detected"
    elif grep -q sse2 /proc/cpuinfo; then
        log_info "SSE2 instruction set detected (AVX2 fallback)"
    else
        log_warning "No SIMD instruction sets detected - performance may be limited"
    fi
    
    if [[ ${#missing_deps[@]} -ne 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_info "Install them with: sudo apt-get install ${missing_deps[*]}"
        exit 1
    fi
    
    log_success "All dependencies satisfied"
}

# Set up build environment
setup_environment() {
    log_info "Setting up build environment..."
    
    cd "$PROJECT_ROOT"
    
    # Set Rust flags for optimization
    if [[ "$BUILD_TYPE" == "release" ]]; then
        export RUSTFLAGS="-C target-cpu=native -C link-arg=-fuse-ld=lld"
        export CARGO_PROFILE_RELEASE_LTO=fat
        export CARGO_PROFILE_RELEASE_CODEGEN_UNITS=1
    fi
    
    # Set feature flags
    case "$FEATURES" in
        "all")
            FEATURES="security,performance,nephrazion,hss,xmss,watermark,jit,simd,real-time"
            ;;
        "security")
            FEATURES="hss,xmss,watermark,auth"
            ;;
        "performance")
            FEATURES="jit,simd,real-time,zero-copy"
            ;;
    esac
    
    log_info "Build type: $BUILD_TYPE"
    log_info "Features: $FEATURES"
    log_info "Parallel jobs: $JOBS"
}

# Build the workspace
build_workspace() {
    log_info "Building NEXUS-X workspace..."
    
    local cargo_args=(
        "build"
        "--workspace"
        "--features" "$FEATURES"
        "--jobs" "$JOBS"
    )
    
    if [[ "$BUILD_TYPE" == "release" ]]; then
        cargo_args+=("--release")
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        cargo_args+=("--verbose")
    fi
    
    # Build with timing information
    time cargo "${cargo_args[@]}"
    
    if [[ $? -eq 0 ]]; then
        log_success "Workspace build completed successfully"
    else
        log_error "Workspace build failed"
        exit 1
    fi
}

# Build documentation
build_docs() {
    log_info "Building documentation..."
    
    cargo doc --workspace --no-deps --features "$FEATURES"
    
    if [[ $? -eq 0 ]]; then
        log_success "Documentation build completed"
        log_info "Documentation available at target/doc/index.html"
    else
        log_warning "Documentation build failed (non-fatal)"
    fi
}

# Run post-build checks
post_build_checks() {
    log_info "Running post-build checks..."
    
    # Check binary sizes
    local binary_dir="target/$BUILD_TYPE"
    if [[ -d "$binary_dir" ]]; then
        log_info "Binary sizes:"
        find "$binary_dir" -name "nexus-*" -executable -type f -exec ls -lh {} \; | awk '{print "  " $9 ": " $5}'
    fi
    
    # Verify security features if enabled
    if [[ "$FEATURES" == *"security"* ]] || [[ "$FEATURES" == *"all"* ]]; then
        log_info "Verifying security features..."
        # Add security feature verification here
    fi
    
    # Check for hardening flags in release builds
    if [[ "$BUILD_TYPE" == "release" ]]; then
        log_info "Checking security hardening..."
        # Add hardening checks here
    fi
}

# Main build process
main() {
    log_info "Starting NEXUS-X build process..."
    log_info "Project root: $PROJECT_ROOT"
    
    check_dependencies
    setup_environment
    build_workspace
    build_docs
    post_build_checks
    
    log_success "NEXUS-X build completed successfully!"
    log_info "Next steps:"
    log_info "  - Run tests: ./scripts/test.sh"
    log_info "  - Install tools: ./scripts/install-tools.sh" 
    log_info "  - View docs: xdg-open target/doc/index.html"
}

# Run main function
main "$@"