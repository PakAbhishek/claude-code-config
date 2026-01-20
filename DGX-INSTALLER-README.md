# DGX Spark - Claude Code Installer

**Specialized installer for NVIDIA DGX Spark (GB10 Superchip)**

Version: 1.0.0
Last Updated: 2026-01-20

---

## Overview

The DGX Spark installer extends the personal Claude Code installer with GPU-optimized configurations for the NVIDIA DGX Spark. It provides:

- **Full personal setup**: Claude Code, Hindsight MCP, AWS SSO, CLAUDE.md auto-sync
- **GPU monitoring**: Real-time GB10 Superchip status on session start
- **Blackwell optimizations**: FP4 precision, Tensor Cores, unified memory
- **Development templates**: PyTorch containers, testing scripts, examples

---

## Hardware Specifications

### NVIDIA DGX Spark (GB10 Superchip)

| Component | Specification |
|-----------|---------------|
| **CPU** | 20-core ARM (10x Cortex-X925 + 10x Cortex-A725) |
| **GPU** | NVIDIA Blackwell (5th Gen Tensor Cores, 4th Gen RT Cores) |
| **Memory** | 128 GB LPDDR5x unified (shared CPU+GPU, 273 GB/s bandwidth) |
| **AI Performance** | 1 PFLOP (1,000 TOPS) at FP4 precision |
| **Storage** | 1-4 TB NVMe M.2 SSD (self-encrypting) |
| **Networking** | ConnectX-7 (200 Gbps), 10 GbE, Wi-Fi 7, Bluetooth 5.3/5.4 |
| **Power** | 140W TDP (240W external adapter) |
| **OS** | DGX OS (Ubuntu-based) |
| **Model Capacity** | 200B params locally, 405B with 2x systems |

### Pre-installed Software

- ✅ CUDA Toolkit
- ✅ cuDNN
- ✅ TensorRT
- ✅ RAPIDS (GPU data science)
- ✅ NIM (Inference Microservices)
- ✅ Blueprints (Reference architectures)

---

## Installation

### Prerequisites

1. **DGX Spark running DGX OS** (Ubuntu-based Linux)
2. **Internet connection** (for package downloads)
3. **OneDrive access** (see setup below)
4. **sudo privileges** (for system packages)

### Step 1: Set Up OneDrive Access

DGX OS (Linux) doesn't have native OneDrive client. Choose one method:

#### Option 1: Mount Windows OneDrive via SMB (Recommended)

```bash
# Install CIFS utilities
sudo apt-get update
sudo apt-get install cifs-utils

# Create mount point
sudo mkdir -p /mnt/onedrive

# Mount OneDrive from Windows machine
sudo mount -t cifs //WINDOWS_IP/Users/achau/OneDrive /mnt/onedrive -o username=achau,uid=$(id -u),gid=$(id -g)

# Create symlink for easy access
ln -s "/mnt/onedrive/OneDrive - PakEnergy" "$HOME/OneDrive - PakEnergy"

# Make persistent (add to /etc/fstab)
echo "//WINDOWS_IP/Users/achau/OneDrive /mnt/onedrive cifs username=achau,password=YOUR_PASSWORD,uid=$(id -u),gid=$(id -g) 0 0" | sudo tee -a /etc/fstab
```

Replace:
- `WINDOWS_IP`: IP address of your Windows machine with OneDrive
- `achau`: Your Windows username
- `YOUR_PASSWORD`: Your Windows password (or use credentials file)

#### Option 2: Use rclone

```bash
# Install rclone
curl https://rclone.org/install.sh | sudo bash

# Configure OneDrive
rclone config
# Select: n (new remote)
# Name: onedrive
# Storage: onedrive
# Follow browser authentication

# Mount OneDrive
mkdir -p "$HOME/OneDrive - PakEnergy"
rclone mount "onedrive:OneDrive - PakEnergy" "$HOME/OneDrive - PakEnergy" --daemon

# Make persistent (add to startup)
echo "@reboot rclone mount \"onedrive:OneDrive - PakEnergy\" \"$HOME/OneDrive - PakEnergy\" --daemon" | crontab -
```

#### Option 3: Manual Copy via SCP

```bash
# One-time copy from Windows machine
scp -r user@WINDOWS_IP:"/Users/achau/OneDrive - PakEnergy/Claude Backup" "$HOME/OneDrive - PakEnergy/Claude Backup"
```

**Note**: This method requires manual re-sync for updates.

### Step 2: Run Installer

```bash
# Navigate to installer location
cd "$HOME/OneDrive - PakEnergy/Claude Backup/claude-config/_scripts"

# Run DGX installer
bash install-claude-dgx.sh
```

### Step 3: Follow Prompts

The installer will:

1. **Detect hardware** - Verify DGX Spark GB10 Superchip
2. **Run personal installer** - Install Claude Code, AWS SSO, Hindsight
3. **Configure GPU environment** - Set up Blackwell optimizations
4. **Install monitoring tools** - nvitop, gpustat
5. **Register hooks** - GPU status on session start
6. **Create templates** - Development examples

### Installation Time

- **Total**: ~35 minutes
  - Base installation: ~20 minutes
  - GPU configuration: ~10 minutes
  - AWS SSO login: ~5 minutes (browser authentication)

---

## What Gets Installed

### Personal Features (from base installer)

| Feature | Description |
|---------|-------------|
| **Claude Code CLI** | Latest version via npm |
| **AWS CLI v2** | Bedrock authentication |
| **AWS SSO** | PakEnergy SSO integration |
| **Hindsight MCP** | Cloud memory server |
| **CLAUDE.md** | Auto-sync configuration |
| **Session Hooks** | AWS check, protocol reminder |
| **Environment** | CLAUDE_MODEL set to Opus 4.5 |

### DGX-Specific Additions

| Feature | Location | Description |
|---------|----------|-------------|
| **Hardware Profile** | `~/.claude/dgx-profile.json` | GB10 specs in JSON |
| **GPU Status Hook** | `~/.claude/hooks/dgx-gpu-status.js` | Session start display |
| **Environment Vars** | `~/.bashrc` or `~/.zshrc` | CUDA, unified memory, Blackwell |
| **Monitoring Tools** | `~/.local/bin/` | nvitop, gpustat |
| **Dev Templates** | `~/.claude/dgx-templates/` | PyTorch, examples, README |

---

## Verification

### Quick Check

After installation, open a **new terminal** and run:

```bash
claude
```

You should see:
1. **Protocol reminder** (from startup)
2. **AWS SSO check** (credentials valid)
3. **DGX Spark status** (GPU stats):
   ```
   ═══════════════════════════════════════════
     DGX Spark - GB10 Superchip Status
   ═══════════════════════════════════════════
   System: NVIDIA Blackwell
   Unified Memory: 12.5 / 128.0 GB (9.8%)
   GPU Utilization: 15%
   Temperature: 42°C
   Power Draw: 45W / 140W TDP
   ═══════════════════════════════════════════
   ```

### Comprehensive Verification

Run verification checklist:

```bash
# 1. Claude Code
claude --version

# 2. GPU accessible
nvidia-smi

# 3. CUDA configured
echo $CUDA_HOME
# Should show: /usr/local/cuda

# 4. Hindsight MCP
recall("test connection")
# Should connect successfully

# 5. AWS credentials
aws sts get-caller-identity
# Should show your identity

# 6. GPU monitoring
gpustat
# Should show GPU stats

# 7. Test unified memory
python ~/.claude/dgx-templates/test-unified-memory.py
# Should pass all tests

# 8. DGX environment
echo $DGX_SYSTEM
# Should show: DGX_SPARK
```

---

## Using the DGX Spark

### GPU Monitoring Commands

| Command | Purpose | Output |
|---------|---------|--------|
| `nvitop` | Interactive monitoring | Real-time dashboard |
| `gpustat -i 1` | Live stats (1s refresh) | Compact one-line |
| `nvidia-smi` | Detailed snapshot | Full GPU info |
| `watch -n 1 nvidia-smi` | Continuous nvidia-smi | Updates every 1s |

### Development Templates

Located in: `~/.claude/dgx-templates/`

| File | Purpose |
|------|---------|
| `README.md` | Complete guide with examples |
| `test-unified-memory.py` | Verify GPU functionality |
| `pytorch-gpu.dockerfile` | Container for development |

### Testing Unified Memory

```bash
cd ~/.claude/dgx-templates
python test-unified-memory.py
```

Expected output:
```
═══════════════════════════════════════════
  DGX Spark - GB10 Superchip Test
═══════════════════════════════════════════
PyTorch version: 2.1.0
CUDA available: True

✓ System: NVIDIA Blackwell
✓ Unified Memory: 128.0 GB
...
✓ All tests passed
```

### Running PyTorch Container

```bash
cd ~/.claude/dgx-templates

# Build container
docker build -f pytorch-gpu.dockerfile -t dgx-pytorch .

# Run with GPU and Jupyter
docker run -it --gpus all -p 8888:8888 -v $(pwd):/workspace dgx-pytorch

# Access Jupyter at: http://localhost:8888
```

### Environment Variables

Pre-configured in your shell profile:

```bash
# CUDA paths
CUDA_HOME="/usr/local/cuda"
PATH="$CUDA_HOME/bin:$PATH"

# Unified Memory
CUDA_UNIFIED_MEMORY=1
CUDA_MANAGED_MEMORY=1

# Blackwell optimizations
NVIDIA_FP4_OVERRIDE=1              # FP4 precision
TORCH_CUDA_ARCH_LIST="9.0"         # Compute capability

# DGX identification
DGX_SYSTEM="DGX_SPARK"
DGX_UNIFIED_MEMORY_GB="128"
DGX_AI_PERFORMANCE_TOPS="1000"
```

---

## Troubleshooting

### OneDrive Not Accessible

**Symptom**: Installer can't find `OneDrive - PakEnergy/Claude Backup/claude-config/`

**Solution**:
1. Verify mount: `ls "$HOME/OneDrive - PakEnergy"`
2. Check SMB connection: `mount | grep onedrive`
3. Remount if needed (see Step 1 above)

### GPU Not Detected

**Symptom**: Installer shows "⚠ NVIDIA drivers not detected"

**Solution**:
```bash
# Check drivers
nvidia-smi

# If not found, check DGX OS setup
sudo apt-get update
sudo apt-get install nvidia-driver-535  # Or latest

# Reboot may be required
sudo reboot
```

### AWS SSO Login Fails

**Symptom**: Browser doesn't open for SSO

**Solution**:
```bash
# Use manual mode
aws sso login --no-browser

# Copy URL to browser on local machine
# Complete authentication
```

### GPU Status Hook Not Showing

**Symptom**: No GPU stats on `claude` startup

**Solution**:
```bash
# Check hook exists
ls ~/.claude/hooks/dgx-gpu-status.js

# Test manually
node ~/.claude/hooks/dgx-gpu-status.js

# Re-register hook
cd "$HOME/OneDrive - PakEnergy/Claude Backup/claude-config/_scripts"
python3 add-dgx-hook.py
```

### Unified Memory Test Fails

**Symptom**: `test-unified-memory.py` reports errors

**Solution**:
```bash
# Check PyTorch installation
python3 -c "import torch; print(torch.cuda.is_available())"

# Reinstall PyTorch for ARM + CUDA
pip3 install --force-reinstall torch --index-url https://download.pytorch.org/whl/cu121

# Verify CUDA
echo $CUDA_HOME
nvcc --version
```

---

## Multi-Machine Sync

### Keeping Configuration in Sync

Your CLAUDE.md and personal settings sync via OneDrive:

| File | Sync Method | Frequency |
|------|-------------|-----------|
| `CLAUDE.md` | Symlink or SessionStart hook | Real-time or on startup |
| `~/.claude/settings.json` | Manual (machine-specific) | N/A |
| `~/.claude/hooks/` | OneDrive backup | On change |
| `dgx-profile.json` | Machine-specific | N/A |

### Updating CLAUDE.md

1. Edit on any machine:
   ```bash
   nano "$HOME/OneDrive - PakEnergy/Claude Backup/claude-config/CLAUDE.md"
   ```

2. Changes sync automatically:
   - **Symlink**: Instant (real-time)
   - **Hook**: Next Claude Code start

### Backing Up DGX Configuration

```bash
# Backup DGX-specific config
cp ~/.claude/dgx-profile.json "$HOME/OneDrive - PakEnergy/Claude Backup/claude-config/backups/"

# Backup custom hooks (if modified)
cp -r ~/.claude/hooks/* "$HOME/OneDrive - PakEnergy/Claude Backup/claude-config/backups/hooks/"
```

---

## Advanced Usage

### Multi-System Clustering (405B Models)

Connect two DGX Spark systems for 256GB total unified memory:

```python
import torch.distributed as dist
import os

# System 1
os.environ['MASTER_ADDR'] = 'dgx-spark-1.local'
os.environ['MASTER_PORT'] = '29500'
os.environ['RANK'] = '0'
os.environ['WORLD_SIZE'] = '2'

# Initialize over ConnectX-7 (200 Gbps)
dist.init_process_group(backend='nccl')

# Load 405B parameter model
model = load_405b_model()
model = torch.nn.parallel.DistributedDataParallel(model)
```

### NIM (Inference Microservices)

Deploy optimized model serving:

```bash
# Check NIM availability
nim-ls

# Start inference service
nim-start llama-2-70b --port 8000

# Test inference
curl -X POST http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Hello", "max_tokens": 50}'
```

### RAPIDS GPU Data Science

```python
import cudf
import cuml

# GPU DataFrame (like pandas)
df = cudf.read_csv('large_dataset.csv')

# GPU-accelerated ML
from cuml.ensemble import RandomForestClassifier
clf = RandomForestClassifier()
clf.fit(X_train, y_train)

# 10-100x faster than CPU
```

---

## Maintenance

### Updating Claude Code

```bash
npm update -g @anthropic-ai/claude-code
```

### Updating GPU Monitoring Tools

```bash
pip3 install --upgrade nvitop gpustat
```

### Updating Installer

```bash
cd "$HOME/OneDrive - PakEnergy/Claude Backup/claude-config"
git pull  # If using git
# Or wait for OneDrive sync
```

### Re-running Installer

Safe to re-run installer to update configuration:

```bash
cd "$HOME/OneDrive - PakEnergy/Claude Backup/claude-config/_scripts"
bash install-claude-dgx.sh
```

Existing configuration preserved, only missing components added.

---

## Support

### Internal Support

- **PakEnergy IT**: Hardware issues, network setup
- **AI Team**: Development workflows, model deployment
- **achau**: Installer issues, configuration help

### External Resources

- **NVIDIA DGX Support**: Enterprise support for hardware
- **Claude Code Issues**: https://github.com/anthropics/claude-code/issues
- **Hindsight MCP**: Internal documentation

---

## Changelog

### Version 1.0.0 (2026-01-20)

- Initial release
- DGX Spark GB10 Superchip support
- Extends personal installer v3.0.23
- Blackwell architecture optimizations
- Unified memory configuration
- GPU monitoring hooks
- Development templates

---

## License

Internal PakEnergy tool. Not for external distribution.

**Maintainer**: Abhishek Chauhan (achau)
**Organization**: PakEnergy
**Last Updated**: 2026-01-20
