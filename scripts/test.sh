#!/bin/bash
set -euo pipefail

# NEXUS-X Test Runner
# Comprehensive test suite for all NEXUS-X components

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_TYPE="unit"
COVERAGE=false
BENCHMARK=false
SECURITY=false
INTEGRATION=false
VERBOSE=false
JOBS=$(nproc)

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m' 
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

show_help() {
    cat << EOF
NEXUS-X Test Runner

Usage: $0 [OPTIONS]

OPTIONS:
    -u, --unit              Run unit tests (default)
    -i, --integration       Run integration tests  
    -s, --security          Run security tests
    -b, --benchmark         Run performance benchmarks
    -c, --coverage          Generate coverage reports
    --comprehensive         Run all test types
    -j, --jobs JOBS         Number of parallel test jobs (default: $JOBS)
    -v, --verbose           Enable verbose output
    -h, --help              Show this help message

EXAMPLES:
    $0                      # Run unit tests
    $0 --comprehensive      # Run all tests
    $0 -s -c                # Run security tests with coverage
    $0 -b                   # Run benchmarks only
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--unit)
            TEST_TYPE="unit"
            shift
            ;;
        -i|--integration)
            INTEGRATION=true
            shift
            ;;
        -s|--security)
            SECURITY=true
            shift
            ;;
        -b|--benchmark)
            BENCHMARK=true
            shift
            ;;
        -c|--coverage)
            COVERAGE=true
            shift
            ;;
        --comprehensive)
            INTEGRATION=true
            SECURITY=true
            BENCHMARK=true
            COVERAGE=true
            shift
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

# Setup test environment
setup_test_env() {
    log_info "Setting up test environment..."
    
    cd "$PROJECT_ROOT"
    
    # Create test output directories
    mkdir -p target/test-results
    mkdir -p target/coverage
    mkdir -p target/benchmarks
    
    # Set environment variables for testing
    export RUST_BACKTRACE=1
    export RUST_TEST_THREADS="$JOBS"
    
    if [[ "$VERBOSE" == "true" ]]; then
        export RUST_LOG=debug
    fi
}

# Run unit tests
run_unit_tests() {
    log_info "Running unit tests..."
    
    local test_args=(
        "test"
        "--workspace"
        "--lib"
        "--bins"
        "--tests"
        "--jobs" "$JOBS"
    )
    
    if [[ "$VERBOSE" == "true" ]]; then
        test_args+=("--verbose")
    fi
    
    # Add coverage if requested
    if [[ "$COVERAGE" == "true" ]]; then
        export RUSTFLAGS="-C instrument-coverage"
        export LLVM_PROFILE_FILE="target/coverage/nexus-x-%p-%m.profraw"
    fi
    
    cargo "${test_args[@]}"
    
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        log_success "Unit tests passed"
    else
        log_error "Unit tests failed"
        return $exit_code
    fi
}

# Run integration tests  
run_integration_tests() {
    log_info "Running integration tests..."
    
    local integration_dirs=(
        "tests/integration/runtime"
        "tests/integration/compiler"
        "tests/integration/security"
        "tests/integration/nephrazion"
    )
    
    for dir in "${integration_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_info "Running integration tests in $dir..."
            cargo test --manifest-path="$dir/Cargo.toml" --jobs "$JOBS"
            
            local exit_code=$?
            if [[ $exit_code -ne 0 ]]; then
                log_error "Integration tests in $dir failed"
                return $exit_code
            fi
        fi
    done
    
    log_success "Integration tests passed"
}

# Run security tests
run_security_tests() {
    log_info "Running security tests..."
    
    # Test cryptographic implementations
    log_info "Testing cryptographic functions..."
    cargo test --package nexus-xmss --features test-vectors
    cargo test --package nexus-watermark --features security-tests
    
    # Test hardware security subsystem
    log_info "Testing hardware security subsystem..."
    cargo test --package nexus-hss --features mock-tpm
    
    # Test capability and authentication systems
    log_info "Testing authentication systems..."
    cargo test --package nexus-auth --features security-tests
    
    # Run property-based security tests
    log_info "Running property-based security tests..."
    cargo test --package nexus-security-tests --features proptest
    
    log_success "Security tests passed"
}

# Run performance benchmarks
run_benchmarks() {
    log_info "Running performance benchmarks..."
    
    local benchmark_dirs=(
        "benchmarks/runtime"
        "benchmarks/compiler"
        "benchmarks/security"
        "benchmarks/memory"
    )
    
    for dir in "${benchmark_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_info "Running benchmarks in $dir..."
            cargo bench --manifest-path="$dir/Cargo.toml" \
                       --jobs "$JOBS" \
                       -- --output-format html \
                       --output-dir "target/benchmarks/$(basename "$dir")"
        fi
    done
    
    # Run criterion benchmarks
    cargo bench --workspace --features benchmark
    
    log_success "Benchmarks completed"
    log_info "Results available in target/benchmarks/"
}

# Generate coverage report
generate_coverage() {
    log_info "Generating coverage report..."
    
    if ! command -v grcov &> /dev/null; then
        log_warning "grcov not found, installing..."
        cargo install grcov
    fi
    
    # Generate coverage report
    grcov target/coverage \
          --binary-path target/debug \
          --source-dir . \
          --output-type html \
          --output-path target/coverage/html \
          --branch \
          --ignore-not-existing \
          --ignore "/*" \
          --ignore "target/*" \
          --ignore "tests/*"
    
    # Generate coverage summary
    grcov target/coverage \
          --binary-path target/debug \
          --source-dir . \
          --output-type coveralls \
          --output-path target/coverage/coveralls.json \
          --branch \
          --ignore-not-existing \
          --ignore "/*" \
          --ignore "target/*" \
          --ignore "tests/*"
    
    log_success "Coverage report generated"
    log_info "HTML report: target/coverage/html/index.html"
}

# Security vulnerability scanning
run_security_scan() {
    log_info "Running security vulnerability scan..."
    
    # Check for known vulnerabilities in dependencies
    if command -v cargo-audit &> /dev/null; then
        cargo audit
    else
        log_warning "cargo-audit not found, skipping dependency scan"
    fi
    
    # Run clippy with security lints
    cargo clippy --workspace --all-features -- -W clippy::all -W clippy::nursery -W clippy::cargo
    
    log_success "Security scan completed"
}

# Memory safety testing
run_memory_tests() {
    log_info "Running memory safety tests..."
    
    # Test with AddressSanitizer if available
    if rustc --print target-features | grep -q "address-sanitizer"; then
        log_info "Running AddressSanitizer tests..."
        RUSTFLAGS="-Z sanitizer=address" \
        cargo test --workspace --target x86_64-unknown-linux-gnu
    fi
    
    # Test with Miri if available  
    if command -v cargo-miri &> /dev/null; then
        log_info "Running Miri tests..."
        cargo miri test --workspace
    fi
    
    log_success "Memory safety tests completed"
}

# Test summary and reporting
generate_test_report() {
    log_info "Generating test summary report..."
    
    local report_file="target/test-results/summary.md"
    
    cat > "$report_file" << EOF
# NEXUS-X Test Summary Report

**Generated**: $(date)
**Test Configuration**: 
- Jobs: $JOBS
- Coverage: $COVERAGE
- Verbose: $VERBOSE

## Test Results

### Unit Tests
- Status: ✅ Passed
- Coverage: $(if [[ "$COVERAGE" == "true" ]]; then echo "Available in target/coverage/"; else echo "Not generated"; fi)

### Integration Tests  
- Status: $(if [[ "$INTEGRATION" == "true" ]]; then echo "✅ Passed"; else echo "⏭️ Skipped"; fi)

### Security Tests
- Status: $(if [[ "$SECURITY" == "true" ]]; then echo "✅ Passed"; else echo "⏭️ Skipped"; fi)

### Performance Benchmarks
- Status: $(if [[ "$BENCHMARK" == "true" ]]; then echo "✅ Completed"; else echo "⏭️ Skipped"; fi)
- Results: $(if [[ "$BENCHMARK" == "true" ]]; then echo "Available in target/benchmarks/"; else echo "Not generated"; fi)

## Recommendations

$(if [[ "$COVERAGE" != "true" ]]; then echo "- Consider running with --coverage for detailed coverage analysis"; fi)
$(if [[ "$SECURITY" != "true" ]]; then echo "- Run security tests with -s before production deployment"; fi)
$(if [[ "$BENCHMARK" != "true" ]]; then echo "- Run benchmarks with -b to verify performance requirements"; fi)

---
*NEXUS-X Test Suite v3.0*
EOF
    
    log_success "Test summary report generated: $report_file"
}

# Main test execution
main() {
    log_info "Starting NEXUS-X test suite..."
    
    setup_test_env
    
    # Always run unit tests
    run_unit_tests
    
    # Run additional test types based on flags
    if [[ "$INTEGRATION" == "true" ]]; then
        run_integration_tests
    fi
    
    if [[ "$SECURITY" == "true" ]]; then
        run_security_tests
        run_security_scan
        run_memory_tests
    fi
    
    if [[ "$BENCHMARK" == "true" ]]; then
        run_benchmarks
    fi
    
    if [[ "$COVERAGE" == "true" ]]; then
        generate_coverage
    fi
    
    generate_test_report
    
    log_success "NEXUS-X test suite completed successfully!"
}

# Run main function
main "$@"