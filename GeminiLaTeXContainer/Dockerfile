FROM debian:trixie

# Prevent interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Install TeX Live and all required tools
RUN apt-get update && apt-get install -y \
    # Core TeX Live
    texlive-full \
    # Fonts
    fonts-noto \
    fonts-dejavu \
    fonts-liberation \
    fonts-freefont-ttf \
    # Build tools
    latexmk \
    biber \
    # Utilities
    gawk \
    coreutils \
    sed \
    grep \
    bash \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create directory structure matching Anthropic's setup
RUN mkdir -p /mnt/user-data/uploads \
             /mnt/user-data/outputs \
             /mnt/skills/public \
             /mnt/skills/private \
             /mnt/skills/examples \
             /mnt/transcripts \
             /home/bard \
             /app

# Copy configuration files
COPY latexmkrc /app/.latexmkrc
COPY entrypoint.sh /app/entrypoint.sh
COPY preview-pdf.min.html /app/preview-pdf.min.html
COPY main.log /app/main.log

# Make entrypoint executable
RUN chmod +x /app/entrypoint.sh
RUN chmod 777 /app/entrypoint.sh

# Set working directory
WORKDIR /app/

# Set entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]

# Default command (basename of tex file)
CMD ["main"]
