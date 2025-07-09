# Base image https://hub.docker.com/_/perl/
FROM perl:latest

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libgd-dev \
    libmariadb-dev \
    libmariadb-dev-compat \
    libssl-dev \
    build-essential \
    git \
    curl \
    netcat-openbsd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install cpanm
RUN curl -L http://cpanmin.us | perl - App::cpanminus

# Install core Catalyst framework
RUN cpanm --notest Catalyst::Runtime \
    && cpanm --notest Catalyst::Devel \
    && cpanm --notest Catalyst::ScriptRunner

# Install Catalyst plugins
RUN cpanm --notest Catalyst::Action::RenderView \
    && cpanm --notest Catalyst::Controller::REST \
    && cpanm --notest Catalyst::Model::DBIC::Schema \
    && cpanm --notest Catalyst::Plugin::ConfigLoader \
    && cpanm --notest Catalyst::Plugin::Static::Simple \
    && cpanm --notest Catalyst::Plugin::Unicode

# Install Views and Templates
RUN cpanm --notest Catalyst::View::Email \
    && cpanm --notest Catalyst::View::TT \
    && cpanm --notest Template::Plugin::Number::Format

# Install Database modules (DBD::mysql separately with error handling)
RUN cpanm --force --notest DBD::mysql || echo "DBD::mysql failed, continuing..."
RUN cpanm --notest DateTime::Format::MySQL \
    && cpanm --notest SQL::Translator

# Install core utility modules
RUN cpanm --notest Config::General \
    && cpanm --notest Data::Printer \
    && cpanm --notest Data::UUID \
    && cpanm --notest Email::Valid \
    && cpanm --notest Term::Size::Any

# Install XML dependencies first
RUN cpanm --notest XML::LibXML || true
RUN cpanm --notest XML::Atom || true

# Install GD and web modules (with resilient installation)
RUN cpanm --retry 3 --notest File::Which || true
RUN cpanm --retry 3 --notest GD || true
RUN cpanm --notest HTML::FormHandler::Moose || true
RUN cpanm --notest HTML::Scrubber || true  
RUN cpanm --notest XML::Feed || true

# Install caching modules
RUN cpanm --notest Cache::Memcached || true

# Install logging and search modules
RUN cpanm --notest Log::Log4perl::Catalyst || true
RUN cpanm --notest Search::QueryParser || true
RUN cpanm --notest MooseX::ClassAttribute || true

# Install problematic modules with force
RUN cpanm --force --notest MediaWiki::Bot || true
RUN cpanm --force --notest DBIx::Class::Result::ColumnData || true

# Try to install optional caching and compression plugins (may not be available)
RUN cpanm --notest Catalyst::Plugin::PageCache || true
RUN cpanm --notest Catalyst::Plugin::Cache || true
RUN cpanm --notest Catalyst::Plugin::Compress || true
RUN cpanm --notest Cache::Redis || true

# Set build arguments for flexibility
ARG REPO_URL=https://github.com/Rfam/rfam-website.git
ARG BRANCH=main

# Clone the source code (check available branches first)
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

# Default entrypoint - can be overridden
ENTRYPOINT ["/src/RfamWeb/script/rfamweb_server.pl", "-p", "3000", "--debug", "--restart"]