# Base image https://hub.docker.com/_/perl/
FROM perl:latest

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libgd-dev \
    libssl-dev \
    libxml2-dev \
    libxml2-utils \
    libxslt1-dev \
    libexpat1-dev \
    expat \
    zlib1g-dev \
    build-essential \
    git \
    curl \
    default-libmysqlclient-dev \
    pkg-config \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install cpanm
RUN curl -L http://cpanmin.us | perl - App::cpanminus

# Install all working modules in logical groups
# Core Catalyst Framework
RUN cpanm --notest \
    Catalyst::Runtime \
    Catalyst::Devel \
    Catalyst::ScriptRunner \
    Catalyst::Action::RenderView \
    Catalyst::Controller::REST \
    Catalyst::Model::DBIC::Schema \
    Catalyst::Plugin::ConfigLoader \
    Catalyst::Plugin::Static::Simple \
    Catalyst::Plugin::Unicode

# View Modules
RUN cpanm --notest \
    Catalyst::View::TT \
    Template::Plugin::Number::Format

# Database Modules
RUN cpanm --notest \
    --force DBD::mysql@4.051 \
    SQL::Translator

# Web Server Modules
RUN cpanm --notest \
    Plack \
    Starman \
    Plack::Handler::Starman


# Force install critical modules
RUN (cpanm --force --verbose --mirror https://www.cpan.org/ XML::Feed) && \
    perl -e "use XML::Feed; print 'XML::Feed successfully loaded\n';"

# Graphics Module
RUN cpanm --notest GD

# Core Utilities
RUN cpanm --notest \
    Config::General \
    Data::UUID \
    Email::Valid \
    JSON \
    Search::QueryParser \
    HTML::FormHandler::Moose \
    Data::Printer

# Logging Modules
RUN cpanm --notest \
    Log::Log4perl 

# DateTime Modules
RUN cpanm --notest \
    DateTime::Format::MySQL 

# File Handling Modules
RUN cpanm --notest \
    File::Slurp

# Web Modules
RUN cpanm --notest \
    LWP::UserAgent \
    HTTP::Request \
    URI

# Install PageCache plugin and additional modules from original
RUN cpanm --notest Catalyst::Plugin::PageCache && \
    cpanm --notest Catalyst::View::Email


# Cache Modules
RUN cpanm --notest \
    Cache::Memcached

# Set build arguments for flexibility
ARG REPO_URL=https://github.com/Rfam/rfam-website.git
ARG BRANCH=create-k8s-deployment-for-preview-site-using-docker
ARG USE_LOCAL_SOURCE=false

# Copy source code - either from local context or git clone
RUN if [ "$USE_LOCAL_SOURCE" = "true" ]; then \
        echo "Using local source code..."; \
        mkdir -p /src; \
    else \
        echo "Cloning source code from git..."; \
        git clone --depth 1 --branch ${BRANCH} ${REPO_URL} /tmp/rfam-source || \
        git clone --depth 1 --branch master ${REPO_URL} /tmp/rfam-source || \
        git clone --depth 1 ${REPO_URL} /tmp/rfam-source; \
        mkdir -p /src && cp -r /tmp/rfam-source/* /src/ && rm -rf /tmp/rfam-source; \
    fi

# Copy local source if using local mode (this will be a no-op if using git)
COPY . /tmp/local-source/
RUN if [ "$USE_LOCAL_SOURCE" = "true" ]; then \
        cp -r /tmp/local-source/* /src/; \
    fi && \
    rm -rf /tmp/local-source

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

# Copy startup and config setup scripts
COPY startup.sh /usr/local/bin/startup.sh
COPY setup/config-setup.sh /setup/config-setup.sh

# Make executable
RUN chmod +x /usr/local/bin/startup.sh /setup/config-setup.sh

# Set proper permissions
RUN chmod +x /src/RfamWeb/script/rfamweb_server.pl

# Clean up
RUN rm -rf /var/lib/apt/lists/* /root/.cpanm

# Setup environment variables
ENV PERL5LIB=/src/RfamWeb:/src/Rfam/Schemata:/src/PfamBase/lib:/src/PfamLib:/src/PfamSchemata
ENV RFAMWEB_CONFIG=/src/RfamWeb/config/rfamweb.conf
ENV DBIC_TRACE=1

# Add labels
LABEL maintainer="Rfam Team"
LABEL org.opencontainers.image.title="Rfam Website"
LABEL org.opencontainers.image.description="Rfam RNA families database website"
LABEL org.opencontainers.image.url="https://github.com/Rfam/rfam-website"
LABEL org.opencontainers.image.source="https://github.com/Rfam/rfam-website"

# Set working directory
WORKDIR /src

# Expose port
EXPOSE 3000

# Default entrypoint
ENTRYPOINT ["/usr/local/bin/startup.sh"]