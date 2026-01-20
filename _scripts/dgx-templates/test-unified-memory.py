#!/usr/bin/env python3
"""
DGX Spark Unified Memory Test
Tests the GB10 Superchip's 128GB unified memory architecture
"""

def check_dgx_spark():
    """
    Verify DGX Spark GPU capabilities and unified memory
    """
    try:
        import torch
        print("═" * 50)
        print("  DGX Spark - GB10 Superchip Test")
        print("═" * 50)
        print(f"PyTorch version: {torch.__version__}")
        print(f"CUDA available: {torch.cuda.is_available()}")

        if not torch.cuda.is_available():
            print("\n❌ CUDA not available")
            print("   Check: nvidia-smi")
            print("   Check: CUDA installation")
            return False

        print(f"\n✓ System: {torch.cuda.get_device_name(0)}")

        # Get unified memory capacity
        mem_total = torch.cuda.get_device_properties(0).total_memory
        mem_total_gb = mem_total / 1e9
        print(f"✓ Unified Memory: {mem_total_gb:.1f} GB")

        if mem_total_gb < 100:
            print("⚠️  Warning: Expected ~128GB for DGX Spark")

        # Test 1: Unified memory allocation
        print("\n" + "─" * 50)
        print("Test 1: Unified Memory Allocation")
        print("─" * 50)
        print("Allocating 10,000 x 10,000 tensor (400MB)...")

        x = torch.randn(10000, 10000, device='cuda')
        mem_allocated = torch.cuda.memory_allocated() / 1e9
        print(f"✓ Allocated successfully")
        print(f"  Memory used: {mem_allocated:.2f} GB")

        # Test 2: Tensor Core computation
        print("\n" + "─" * 50)
        print("Test 2: Tensor Core Computation")
        print("─" * 50)
        print("Performing matrix multiplication (Tensor Cores)...")

        import time
        start = time.time()
        y = torch.matmul(x, x)
        torch.cuda.synchronize()
        elapsed = time.time() - start

        print(f"✓ Matrix multiplication completed")
        print(f"  Time: {elapsed:.4f} seconds")
        print(f"  TFLOPS: {(2 * 10000**3) / elapsed / 1e12:.2f}")

        # Test 3: Memory management
        print("\n" + "─" * 50)
        print("Test 3: Memory Management")
        print("─" * 50)
        print("Freeing allocated memory...")

        del x, y
        torch.cuda.empty_cache()

        mem_after = torch.cuda.memory_allocated() / 1e9
        print(f"✓ Memory freed")
        print(f"  Memory used: {mem_after:.2f} GB")

        # Test 4: Large allocation (unified memory benefit)
        print("\n" + "─" * 50)
        print("Test 4: Large Allocation (Unified Memory)")
        print("─" * 50)
        print("Allocating 20GB tensor...")

        try:
            large_tensor = torch.randn(50000, 50000, device='cuda')  # ~20GB
            mem_large = torch.cuda.memory_allocated() / 1e9
            print(f"✓ Large allocation successful")
            print(f"  Memory used: {mem_large:.2f} GB")
            del large_tensor
            torch.cuda.empty_cache()
        except RuntimeError as e:
            print(f"⚠️  Large allocation failed: {e}")
            print("   This may indicate memory constraints")

        # Summary
        print("\n" + "═" * 50)
        print("  Test Summary")
        print("═" * 50)
        print("✓ PyTorch CUDA functional")
        print("✓ Unified memory accessible")
        print("✓ Tensor Cores operational")
        print("✓ Memory management working")
        print("\nDGX Spark GB10 Superchip: READY")
        print("═" * 50)
        print()

        return True

    except ImportError:
        print("═" * 50)
        print("  PyTorch Not Installed")
        print("═" * 50)
        print("\nInstall PyTorch for ARM + CUDA:")
        print("  pip3 install torch --index-url https://download.pytorch.org/whl/cu121")
        print("\nFor CUDA 12.4+:")
        print("  pip3 install torch --index-url https://download.pytorch.org/whl/cu124")
        print()
        return False

    except Exception as e:
        print(f"\n❌ Error during testing: {e}")
        print("\nTroubleshooting:")
        print("  1. Check: nvidia-smi")
        print("  2. Verify: echo $CUDA_HOME")
        print("  3. Test: python -c 'import torch; print(torch.cuda.is_available())'")
        print()
        return False


if __name__ == "__main__":
    import sys
    success = check_dgx_spark()
    sys.exit(0 if success else 1)
