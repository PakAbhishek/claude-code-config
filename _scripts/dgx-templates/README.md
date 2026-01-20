# DGX Spark Development Templates

This directory contains templates and examples for GPU-accelerated development on the NVIDIA DGX Spark (GB10 Superchip).

## System Specifications

- **System**: NVIDIA DGX Spark (Grace Blackwell GB10)
- **CPU**: 20-core ARM (10x Cortex-X925 + 10x Cortex-A725)
- **GPU**: NVIDIA Blackwell (5th Gen Tensor Cores, 4th Gen RT Cores)
- **Memory**: 128 GB LPDDR5x unified (shared CPU+GPU, 273 GB/s bandwidth)
- **AI Performance**: 1 PFLOP (1,000 TOPS) at FP4 precision
- **Model Capacity**: Up to 200B parameters locally (405B with 2x systems)

## Quick Start

### Test Unified Memory

```bash
python test-unified-memory.py
```

This script verifies:
- PyTorch installation and CUDA availability
- Unified memory allocation (128GB shared)
- Tensor Core functionality
- Memory management

### Docker Containers

Build and run GPU-accelerated container:

```bash
# Build PyTorch container
docker build -f pytorch-gpu.dockerfile -t dgx-pytorch .

# Run with GPU support and Jupyter
docker run -it --gpus all -p 8888:8888 -v $(pwd):/workspace dgx-pytorch

# Access Jupyter at: http://localhost:8888
```

## GPU Monitoring

### Interactive Monitoring

```bash
nvitop
```

Features:
- Real-time GPU stats
- Process monitoring
- Memory usage graphs
- Interactive process management

### Live Stats (1-second refresh)

```bash
gpustat -i 1
```

Compact output showing:
- GPU utilization
- Memory usage
- Temperature
- Process list

### Standard NVIDIA Tool

```bash
nvidia-smi
```

Detailed information:
- Driver version
- CUDA version
- Power draw
- Clock speeds
- ECC errors

## Pre-installed AI Stack

### CUDA Toolkit
- Location: `/usr/local/cuda`
- Includes: cuBLAS, cuDNN, cuFFT, cuSPARSE
- Optimized for Blackwell architecture

### TensorRT
High-performance inference engine:
```python
import tensorrt as trt
```

### RAPIDS
GPU-accelerated data science:
```python
import cudf  # GPU DataFrame
import cuml  # GPU ML algorithms
```

### NIM (NVIDIA Inference Microservices)
Deploy optimized model serving:
```bash
# Check NIM containers
docker ps | grep nim

# View available models
nim-ls
```

## Development Workflows

### PyTorch Development

```python
import torch

# Verify Blackwell GPU
print(torch.cuda.get_device_name(0))  # Should show Blackwell

# Use FP4 precision for maximum performance
model = model.to(torch.float8_e4m3fn)  # FP4 equivalent

# Leverage unified memory
torch.cuda.set_per_process_memory_fraction(0.95)  # Can use most of 128GB
```

### TensorFlow Development

```python
import tensorflow as tf

# Verify GPU
print(tf.config.list_physical_devices('GPU'))

# Enable unified memory
gpus = tf.config.list_physical_devices('GPU')
for gpu in gpus:
    tf.config.experimental.set_memory_growth(gpu, True)
```

### Multi-System Clustering

Connect two DGX Spark systems for 405B parameter models:

```python
import torch.distributed as dist

# Initialize distributed training over ConnectX-7 (200 Gbps)
dist.init_process_group(backend='nccl')

# 256GB total unified memory available (2x 128GB)
```

## Blackwell-Specific Optimizations

### FP4 Precision

Enable ultra-low precision for 1 PFLOP performance:

```python
# Environment variable (already set by installer)
# export NVIDIA_FP4_OVERRIDE=1

# PyTorch FP4
model = model.to(torch.float8_e4m3fn)
```

### Tensor Cores (5th Generation)

```python
# Automatic with compatible operations
torch.backends.cuda.matmul.allow_tf32 = True
torch.backends.cudnn.allow_tf32 = True
```

### Unified Memory Architecture

```python
# No explicit GPU memory management needed
# 128GB seamlessly shared between CPU and GPU

# Allocate large models directly
model = LargeLanguageModel(params=200e9)  # 200B parameters
model = model.cuda()  # Automatic unified memory
```

## Common Use Cases

### 1. Local LLM Inference (up to 200B params)

```python
from transformers import AutoModelForCausalLM, AutoTokenizer

# Load large model leveraging unified memory
model = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Llama-2-70b-hf",
    device_map="auto",  # Automatic placement
    torch_dtype=torch.float16
)
```

### 2. Computer Vision with RT Cores

```python
# 4th Gen Ray Tracing Cores for graphics workloads
import torch
import torchvision

model = torchvision.models.detection.fasterrcnn_resnet50_fpn(pretrained=True)
model = model.cuda()
```

### 3. Scientific Computing with RAPIDS

```python
import cudf
import cuml

# GPU-accelerated DataFrame (like pandas)
df = cudf.read_csv('large_dataset.csv')

# GPU-accelerated ML
from cuml.ensemble import RandomForestClassifier
clf = RandomForestClassifier()
clf.fit(X_train, y_train)
```

## Environment Variables (Pre-configured)

```bash
# CUDA paths
export CUDA_HOME="/usr/local/cuda"
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH

# Unified Memory
export CUDA_UNIFIED_MEMORY=1
export CUDA_MANAGED_MEMORY=1

# Blackwell optimizations
export NVIDIA_FP4_OVERRIDE=1
export TORCH_CUDA_ARCH_LIST="9.0"  # Blackwell compute capability

# DGX identification
export DGX_SYSTEM="DGX_SPARK"
export DGX_SOC="GB10_SUPERCHIP"
export DGX_UNIFIED_MEMORY_GB="128"
export DGX_AI_PERFORMANCE_TOPS="1000"
```

## Troubleshooting

### Check CUDA Installation

```bash
nvcc --version
```

### Verify Unified Memory

```bash
nvidia-smi --query-gpu=memory.total --format=csv
# Should show ~128GB
```

### Test GPU Communication

```python
import torch
x = torch.randn(1000, 1000, device='cuda')
y = torch.matmul(x, x)
print("✓ GPU compute working")
```

### ConnectX-7 Network (Multi-System)

```bash
# Check network interface
ip link show | grep mlx5

# Test bandwidth
iperf3 -s  # On one system
iperf3 -c <other-dgx-ip> -t 60  # On other system
# Should show ~200 Gbps
```

## Resources

- **CUDA Documentation**: https://docs.nvidia.com/cuda/
- **TensorRT Guide**: https://docs.nvidia.com/deeplearning/tensorrt/
- **RAPIDS Docs**: https://docs.rapids.ai/
- **NIM Documentation**: https://docs.nvidia.com/nim/
- **DGX Spark User Guide**: Contact NVIDIA support

## Support

For DGX Spark-specific issues:
- NVIDIA Enterprise Support
- DGX Spark Community Forum
- Internal PakEnergy IT (for hardware issues)
