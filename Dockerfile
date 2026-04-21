# 使用 Ubuntu 作为基础镜像
FROM ubuntu:20.04

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
# 安装必要的软件包
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    git \
    vim nano \
    curl \
    ca-certificates \
    build-essential \
    bash-completion \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# 安装 NVIDIA Container Toolkit（如果你的主机支持 GPU）
# 如果你不需要 GPU 支持，可以注释掉以下与 NVIDIA 相关的行
#RUN apt-get update && apt-get install -y --no-install-recommends \
#    nvidia-container-toolkit \
#    && rm -rf /var/lib/apt/lists/*

# 下载并安装 Miniconda
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
RUN curl -fsSL https://code-server.dev/install.sh | sh
RUN bash miniconda.sh -b -p /opt/conda
RUN rm miniconda.sh
ENV PATH="/opt/conda/bin:$PATH"

# 创建一个 Anaconda 环境并安装 TensorFlow 1.15 GPU
# 请注意：TensorFlow 1.15 GPU 需要 CUDA 10.0 和 cuDNN 7.6。
# Ubuntu 20.04 默认的 CUDA 版本可能不兼容。
# 为了简化，这里使用 conda 安装 TensorFlow 1.15 GPU，它会尝试管理 CUDA 依赖。
# 如果遇到问题，可能需要手动安装特定版本的 CUDA 和 cuDNN。
RUN conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
RUN conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

RUN conda create -n tf_gpu_env python=3.6 -y  # <-- 更改为 python=3.6
# 启用 conda 的 shell 初始化
RUN conda init bash
SHELL ["conda", "run", "-n", "tf_gpu_env", "/bin/bash", "-c"]
RUN conda install -c anaconda tensorflow-gpu=1.15 -y && \
    pip install numpy==1.19.1 opencv-python-headless==3.4.3.18 && \
    pip install matplotlib==3.3.4 && \
    conda clean -a -y

# 默认使用 tf_gpu_env（包括 code-server 终端）
ENV PATH="/opt/conda/envs/tf_gpu_env/bin:/opt/conda/bin:$PATH"
ENV CONDA_DEFAULT_ENV=tf_gpu_env
RUN echo ". /opt/conda/etc/profile.d/conda.sh && conda activate tf_gpu_env" >> /root/.bashrc

# 安装 code-server

# 设置 code-server 的密码
# 建议在运行容器时通过环境变量设置更安全的密码
ENV PASSWORD=password

# 暴露 code-server 的端口
EXPOSE 8080

# 启动 code-server
CMD ["code-server", "--auth", "password", "--host", "0.0.0.0", "--port", "8080"]
