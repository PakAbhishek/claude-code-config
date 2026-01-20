# DGX Spark PyTorch GPU Container
# Optimized for NVIDIA Blackwell (GB10 Superchip)
# ARM64 architecture with CUDA support

FROM nvcr.io/nvidia/pytorch:24.01-py3

# Maintainer
LABEL maintainer="PakEnergy AI Team"
LABEL description="DGX Spark PyTorch development environment"

# Set environment for unified memory
ENV CUDA_UNIFIED_MEMORY=1
ENV CUDA_MANAGED_MEMORY=1
ENV NVIDIA_FP4_OVERRIDE=1
ENV TORCH_CUDA_ARCH_LIST="9.0"

# Install additional Python packages
RUN pip install --no-cache-dir \
    jupyter \
    jupyterlab \
    ipython \
    matplotlib \
    seaborn \
    pandas \
    numpy \
    scikit-learn \
    scipy \
    nvitop \
    gpustat \
    transformers \
    datasets \
    accelerate \
    bitsandbytes

# Install RAPIDS (GPU-accelerated data science)
RUN pip install --no-cache-dir \
    cudf-cu12 \
    cuml-cu12 \
    cugraph-cu12

# Set working directory
WORKDIR /workspace

# Expose Jupyter port
EXPOSE 8888

# Configure Jupyter
RUN jupyter notebook --generate-config && \
    echo "c.NotebookApp.ip = '0.0.0.0'" >> ~/.jupyter/jupyter_notebook_config.py && \
    echo "c.NotebookApp.allow_root = True" >> ~/.jupyter/jupyter_notebook_config.py && \
    echo "c.NotebookApp.open_browser = False" >> ~/.jupyter/jupyter_notebook_config.py

# Default command: Start Jupyter Lab
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--port=8888", "--no-browser", "--allow-root"]
