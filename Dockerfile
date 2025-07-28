# Base image https://hub.docker.com/_/perl/
FROM perl:latest

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libgd-dev \
    libmariadb-dev \
    libmariadb-dev-compat \
    libssl-dev \
    libxml2-dev \
    libexpat1-dev \
    zlib1g-dev \
    build-essential \
    git \
    curl \
    netcat-openbsd \
    default-libmysqlclient-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install cpanm for use by setup scripts
RUN curl -L http://cpanmin.us | perl - App::cpanminus

# Install CRITICAL modules that cannot be stubbed (need network during build)
RUN echo "Installing Core Catalyst Framework..." && \
    cpanm --notest Catalyst::Runtime \
    && cpanm --notest Catalyst::Devel \
    && cpanm --notest Catalyst::ScriptRunner

RUN echo "Installing Essential Catalyst Plugins..." && \
    cpanm --notest Catalyst::Action::RenderView \
    && cpanm --notest Catalyst::Controller::REST \
    && cpanm --notest Catalyst::Model::DBIC::Schema \
    && cpanm --notest Catalyst::Plugin::ConfigLoader \
    && cpanm --notest Catalyst::Plugin::Static::Simple \
    && cpanm --notest Catalyst::Plugin::Unicode

RUN echo "Installing View Modules..." && \
    cpanm --notest Catalyst::View::TT \
    && cpanm --notest Template::Plugin::Number::Format

RUN echo "Installing Database Modules..." && \
    cpanm --notest DBI \
    && cpanm --notest Devel::CheckLib \
    && cpanm --notest --force DBD::mysql@4.050 \
    && cpanm --notest SQL::Translator

RUN echo "Installing Web Server Modules..." && \
    cpanm --notest Plack \
    && cpanm --notest Starman \
    && cpanm --notest Plack::Handler::Starman

RUN echo "Installing Core Utilities..." && \
    cpanm --notest Config::General \
    && cpanm --notest Data::UUID \
    && cpanm --notest Email::Valid \
    && cpanm --notest JSON \
    && cpanm --notest YAML \
    && cpanm --notest Search::QueryParser || \
    cpanm --force --notest Search::QueryParser || \
    echo "❌ Search::QueryParser installation failed"

RUN echo "Installing Form Handler modules..." && \
    cpanm --notest HTML::FormHandler::Moose || \
    cpanm --force --notest HTML::FormHandler::Moose || \
    echo "❌ HTML::FormHandler::Moose installation failed"

RUN echo "Installing Email modules..." && \
    cpanm --notest Email::MIME || \
    cpanm --force --notest Email::MIME || \
    echo "❌ Email::MIME installation failed"

RUN echo "Installing Debug/Utility modules..." && \
    cpanm --notest Data::Printer || \
    cpanm --force --notest Data::Printer || \
    echo "❌ Data::Printer installation failed"

# Verify critical database connectivity
RUN perl -e "use DBI; use DBD::mysql; print \"✅ DBD::mysql version: \$DBD::mysql::VERSION\n\";" || \
    echo "❌ DBD::mysql verification failed"

# Set build arguments for flexibility
ARG REPO_URL=https://github.com/Rfam/rfam-website.git
ARG BRANCH=main

# Clone the source code
WORKDIR /tmp
RUN git ls-remote --heads ${REPO_URL} && \
    git clone --depth 1 ${REPO_URL} rfam-source || \
    git clone --depth 1 --branch master ${REPO_URL} rfam-source || \
    git clone --depth 1 --branch ${BRANCH} ${REPO_URL} rfam-source

# Copy source code to final location
RUN mkdir -p /src && cp -r /tmp/rfam-source/* /src/

# Set up configuration directories
RUN mkdir -p /src/RfamWeb/config

# Copy config files to expected location
RUN if [ -d "/src/config" ]; then cp -r /src/config/* /src/RfamWeb/config/; fi

# Create changelog.conf if it doesn't exist
RUN if [ ! -f "/src/RfamWeb/config/changelog.conf" ]; then \
        touch /src/RfamWeb/config/changelog.conf && \
        echo "# Changelog configuration file" > /src/RfamWeb/config/changelog.conf; \
    fi

# Copy from config.dist if available
RUN if [ -d "/src/RfamWeb/config.dist" ]; then \
        cp -r /src/RfamWeb/config.dist/* /src/RfamWeb/config/ 2>/dev/null || true; \
    fi

# Create setup directory and copy setup scripts
RUN mkdir -p /setup

# Force cache bust to ensure fresh copy of setup scripts
ARG CACHE_BUST=1
COPY setup/config-setup.sh /setup/config-setup.sh
COPY setup/module-setup.sh /setup/module_setup.sh  

# Make setup scripts executable
RUN chmod +x /setup/*.sh

# Copy startup script with cache bust
COPY startup.sh /usr/local/bin/startup.sh
RUN chmod +x /usr/local/bin/startup.sh

# Set proper permissions
RUN chmod +x /src/RfamWeb/script/rfamweb_server.pl

# Clean up
RUN rm -rf /tmp/rfam-source /var/lib/apt/lists/* /root/.cpanm

# Setup environment variables
ENV PERL5LIB=/src/RfamWeb:/src/Rfam/Schemata:/src/PfamBase/lib:/src/PfamLib:/src/PfamSchemata
ENV RFAMWEB_CONFIG=/src/RfamWeb/config/rfamweb.conf
ENV DBIC_TRACE=1

# Add labels for better container management
LABEL maintainer="Rfam Team"
LABEL org.opencontainers.image.title="Rfam Website"
LABEL org.opencontainers.image.description="Rfam RNA families database website"
LABEL org.opencontainers.image.url="https://github.com/Rfam/rfam-website"
LABEL org.opencontainers.image.source="https://github.com/Rfam/rfam-website"

# Set working directory
WORKDIR /src

# Expose port
EXPOSE 3000

# Default entrypoint - use the startup script
ENTRYPOINT ["/usr/local/bin/startup.sh"]