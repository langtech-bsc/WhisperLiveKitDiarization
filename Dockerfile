# ✅ PyTorch 2.2.2 (cu121), Python 3.10, cuDNN 9.5.1+
FROM pytorch/pytorch:2.2.2-cuda12.1-cudnn8-runtime

ENV PYTHONUNBUFFERED=1
ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /app

# Optional: add caching envs (like HF cache) if needed
ENV HF_HOME="/app/tmp/cache/huggingface"
ENV XDG_CACHE_HOME="/app/tmp/cache"
ENV LIBROSA_CACHE_DIR="/app/tmp/librosa_cache"
ENV NUMBA_CACHE_DIR="/app/tmp/numba_cache"
ENV MPLCONFIGDIR="/app/tmp/matplotlib"
ENV HF_HUB_ETAG_TIMEOUT="600"
ENV HF_HUB_DOWNLOAD_TIMEOUT="600"

# 🧰 System dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ffmpeg \
        git \
        libportaudio2 \
        python3-dev \
        portaudio19-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 📦 Python packages
# Prefer installing torch packages already bundled, to avoid conflicts
RUN pip install --upgrade pip && \
    pip install \
        diart \
        sounddevice

COPY . .

# 🧼 Set permissions for Hugging Face cache
RUN mkdir -p $HF_HOME $XDG_CACHE_HOME $LIBROSA_CACHE_DIR $NUMBA_CACHE_DIR /.cache && \
    chmod -R 777 /app /root/.cache /.cache

# Install WhisperLiveKit directly, allowing for optional dependencies
#   Note: For gates modedls, need to add your HF toke. See README.md
#         for more details.
RUN if [ -n "$EXTRAS" ]; then \
      echo "Installing with extras: [$EXTRAS]"; \
      pip install --no-cache-dir .[$EXTRAS]; \
    else \
      echo "Installing base package only"; \
      pip install --no-cache-dir .; \
    fi

# Enable in-container caching for Hugging Face models by: 
# Note: If running multiple containers, better to map a shared
# bucket. 
#
# A) Make the cache directory persistent via an anonymous volume.
#    Note: This only persists for a single, named container. This is 
#          only for convenience at de/test stage. 
#          For prod, it is better to use a named volume via host mount/k8s.
VOLUME ["/root/.cache/huggingface/hub"]

# or
# B) Conditionally copy a local pre-cache from the build context to the 
#    container's cache via the HF_PRECACHE_DIR build-arg.
#    WARNING: This will copy ALL files in the pre-cache location.

# Conditionally copy a cache directory if provided
RUN if [ -n "$HF_PRECACHE_DIR" ]; then \
      echo "Copying Hugging Face cache from $HF_PRECACHE_DIR"; \
      mkdir -p /root/.cache/huggingface/hub && \
      cp -r $HF_PRECACHE_DIR/* /root/.cache/huggingface/hub; \
    else \
      echo "No local Hugging Face cache specified, skipping copy"; \
    fi

# Conditionally copy a Hugging Face token if provided

RUN if [ -n "$HF_TKN_FILE" ]; then \
      echo "Copying Hugging Face token from $HF_TKN_FILE"; \
      mkdir -p /root/.cache/huggingface && \
      cp $HF_TKN_FILE /root/.cache/huggingface/token; \
    else \
      echo "No Hugging Face token file specified, skipping token setup"; \
    fi

# ✅ Expose server port
EXPOSE 8000

# 🚀 Start the app
ENTRYPOINT ["whisperlivekit-server", "--host", "0.0.0.0"]
CMD ["--model", "tiny", "--diarization"]
