FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH=/usr/local/texlive/2025/bin/x86_64-linux:$PATH

# 1. Install system dependencies and SSH server
# - wget/perl: for TeX Live installer
# - openssh-server: for SSH access
# - fontconfig: for LuaHBTeX font discovery
RUN apt-get update && apt-get install -y \
    wget \
    perl \
    openssh-server \
    fontconfig \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# 2. Configure SSH for interactive auth
# - Create the privilege separation directory
# - specific user 'texuser' for safety (avoids root usage)
# - Set password to 'texpass' for interactive login
RUN mkdir /var/run/sshd && \
    useradd -m -s /bin/bash texuser && \
    echo 'texuser:texpass' | chpasswd && \
    # Allow password authentication (usually default, but explicit is safer)
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# 3. Install TeX Live 2025
# We use a profile to force the specific paths requested: /usr/local/texlive/2025
WORKDIR /tmp/install-tl
RUN wget -qO- https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz | \
    tar xz --strip-components=1 && \
    \
    # Create an installation profile
    echo "selected_scheme scheme-full" >> texlive.profile && \
    echo "TEXDIR /usr/local/texlive/2025" >> texlive.profile && \
    echo "TEXMFLOCAL /usr/local/texlive/texmf-local" >> texlive.profile && \
    echo "TEXMFSYSCONFIG /usr/local/texlive/2025/texmf-config" >> texlive.profile && \
    echo "TEXMFSYSVAR /usr/local/texlive/2025/texmf-var" >> texlive.profile && \
    echo "option_doc 0" >> texlive.profile && \
    echo "option_src 0" >> texlive.profile && \
    \
    # Run installer
    ./install-tl --profile=texlive.profile && \
    \
    # Cleanup
    cd / && \
    rm -rf /tmp/install-tl

# 4. Generate Font Cache (matches your luaotfload requirement)
# This populates /usr/local/texlive/2025/texmf-var/luatex-cache/
RUN luaotfload-tool --update

# 5. Persist PATH for SSH sessions
# SSH sessions don't always inherit Docker ENV, so we add it to .bashrc
RUN echo "export PATH=/usr/local/texlive/2025/bin/x86_64-linux:\$PATH" >> /home/texuser/.bashrc

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]
