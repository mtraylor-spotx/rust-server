FROM docker.io/fedora:27

MAINTAINER Matt Traylor <mtraylor@spotx.tv>

# Install dependencies
RUN dnf makecache && \
    dnf update -y && \
    dnf install -y nginx expect libgdiplus bsdtar nodejs npm \
    glibc.i686 libstdc++.i686 net-tools procps && \
    dnf clean all
RUN groupadd rust && \
    useradd -m -d /home/rust -s /bin/bash -g rust rust && \
    rm -fr /usr/share/nginx/html/*

# Install webrcon (specific commit)
COPY nginx_rcon.conf /etc/nginx/nginx.conf
RUN curl -sL https://github.com/Facepunch/webrcon/archive/24b0898d86706723d52bb4db8559d90f7c9e069b.zip | bsdtar -xvf- -C /tmp && \
  mv /tmp/webrcon-24b0898d86706723d52bb4db8559d90f7c9e069b/* /usr/share/nginx/html/ && \
  rm -fr /tmp/webrcon-24b0898d86706723d52bb4db8559d90f7c9e069b

# Customize the webrcon package to fit our needs
ADD fix_conn.sh /tmp/fix_conn.sh

# Create and set the steamcmd folder as a volume
RUN mkdir -p /home/rust/steamcmd/rust && \
    chgrp -R 0 /home/rust && \
    chmod -R g=u /home/rust

# Setup proper shutdown support
ADD shutdown_app/ /home/rust/shutdown_app/
WORKDIR /home/rust/shutdown_app
RUN npm install

# Setup restart support (for update automation)
ADD restart_app/ /home/rust/restart_app/
WORKDIR /home/rust/restart_app
RUN npm install

# Setup scheduling support
ADD scheduler_app/ /home/rust/scheduler_app/
WORKDIR /scheduler_app
RUN npm install

# Setup rcon command relay app
ADD rcon_app/ /home/rust/rcon_app/
WORKDIR /home/rust/rcon_app
RUN npm install && ln -s /home/rust/rcon_app/app.js /usr/bin/rcon

# Copy the Rust startup script
ADD start_rust.sh install.txt update_check.sh README.md LICENSE.md /home/rust/

# Copy extra files
ADD uid_entrypoint.sh /

# Set the current working directory
WORKDIR /home/rust

RUN curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -

# Expose necessary ports
EXPOSE 8080 31015 31016

RUN chown -R rust /home/rust && \
    chgrp -R 0 /home/rust /var/log/nginx && \
    chmod -R g=u /etc/passwd && \
    chmod -R g=u /var/log/nginx/


ENTRYPOINT ["/uid_entrypoint.sh"]

USER 1000

# Setup default environment variables for the server
ENV RUST_SERVER_STARTUP_ARGUMENTS="-batchmode -load +server.secure 1 +server.port 31015 +rcon.port 31016 +rcon.password osrust" \
    RUST_SERVER_IDENTITY="docker" RUST_SERVER_SEED="13852" \
    RUST_SERVER_NAME="Rust Server [openshift]" \
    RUST_SERVER_DESCRIPTION="This is a Rust server running inside a Docker container!" \
    RUST_SERVER_URL="https://rust-rcon.openshift.mst.lab" \
    RUST_SERVER_BANNER_URL="" RUST_RCON_WEB="1" \
    RUST_UPDATE_CHECKING="0" \
    RUST_UPDATE_BRANCH="public" RUST_START_MODE="0" \
    RUST_OXIDE_ENABLED="0" RUST_OXIDE_UPDATE_ON_BOOT="1" \
    RUST_SERVER_WORLDSIZE="3500" RUST_SERVER_MAXPLAYERS="500" \
    RUST_SERVER_SAVE_INTERVAL="600" USER_NAME=rust HOME=/home/rust \
    PATH=/home/rust:$PATH 
