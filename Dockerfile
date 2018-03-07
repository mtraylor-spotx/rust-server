FROM didstopia/base:nodejs-steamcmd-ubuntu-16.04

MAINTAINER Didstopia <support@didstopia.com>

# Fix apt-get warnings
ARG DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    nginx \
    expect \
    tcl \
    libgdiplus && \
    rm -rf /var/lib/apt/lists/* \
    useradd rust

# Remove default nginx stuff
RUN rm -fr /usr/share/nginx/html/* && \
	rm -fr /etc/nginx/sites-available/* && \
	rm -fr /etc/nginx/sites-enabled/*

# Install webrcon (specific commit)
COPY nginx_rcon.conf /etc/nginx/nginx.conf
RUN curl -sL https://github.com/Facepunch/webrcon/archive/24b0898d86706723d52bb4db8559d90f7c9e069b.zip | bsdtar -xvf- -C /tmp && \
	mv /tmp/webrcon-24b0898d86706723d52bb4db8559d90f7c9e069b/* /usr/share/nginx/html/ && \
	rm -fr /tmp/webrcon-24b0898d86706723d52bb4db8559d90f7c9e069b

# Customize the webrcon package to fit our needs
ADD fix_conn.sh /tmp/fix_conn.sh

# Create and set the steamcmd folder as a volume
RUN mkdir -p /home/rust/steamcmd/rust
VOLUME ["/steamcmd/rust"]

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
RUN npm install
RUN ln -s /home/rust/rcon_app/app.js /usr/bin/rcon

# Add the steamcmd installation script
ADD install.txt /home/rust/install.txt

# Copy the Rust startup script
ADD start_rust.sh /home/rust/start.sh

# Copy the Rust update check script
ADD update_check.sh /home/rust/update_check.sh

# Copy extra files
COPY README.md LICENSE.md uid_entrypoint /home/rust/

RUN chmod -R u+x /home/rust/uid_entrypoint

# Set the current working directory
WORKDIR /home/rust

# Expose necessary ports
EXPOSE 8080
EXPOSE 28015
EXPOSE 28016

# Setup default environment variables for the server
ENV RUST_SERVER_STARTUP_ARGUMENTS="-batchmode -load +server.secure 1" \
    RUST_SERVER_IDENTITY="docker" RUST_SERVER_SEED="13852" \
    RUST_SERVER_NAME="Rust Server [openshift]" \
    RUST_SERVER_DESCRIPTION="This is a Rust server running inside a Docker container!" \
    RUST_SERVER_URL="https://rust-rcon.openshift.mst.lab" \
    RUST_SERVER_BANNER_URL="" RUST_RCON_WEB="1" RUST_RCON_PORT="28016" \
    RUST_RCON_PASSWORD="osrust" RUST_UPDATE_CHECKING="0" \
    RUST_UPDATE_BRANCH="public" RUST_START_MODE="0" \
    RUST_OXIDE_ENABLED="0" RUST_OXIDE_UPDATE_ON_BOOT="1" \
    RUST_SERVER_WORLDSIZE="3500" RUST_SERVER_MAXPLAYERS="500" \
    RUST_SERVER_SAVE_INTERVAL="600" USER_NAME=rust HOME=/home/rust 

RUN chgrp -R 0 /home/rust && \
    chmod -R g=u /home/rust /etc/passwd

USER 1001
ENTRYPOINT ["/home/rust/uid_entrypoint"]
