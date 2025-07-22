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
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install cpanm for use by setup scripts
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

# Install DateTime modules first (critical dependency)
RUN echo "Installing DateTime modules..." && \
    cpanm --notest DateTime && \
    cpanm --notest DateTime::Format::MySQL || \
    cpanm --force --notest DateTime::Format::MySQL || \
    echo "DateTime modules installation completed"

# Install File utilities with aggressive retry
RUN echo "Installing file utilities..." && \
    cpanm --notest File::Which && \
    cpanm --notest File::Slurp || \
    cpanm --force --notest File::Slurp || \
    echo "File utilities installation completed"

# Install XML dependencies with multiple approaches
RUN echo "Installing XML modules..." && \
    cpanm --notest XML::Parser && \
    cpanm --notest XML::SAX && \
    cpanm --notest XML::LibXML && \
    cpanm --notest XML::Atom && \
    cpanm --notest XML::Feed || \
    echo "First attempt failed, trying with force..." && \
    cpanm --force --notest XML::LibXML && \
    cpanm --force --notest XML::Atom && \
    cpanm --force --notest XML::Feed || \
    echo "XML modules installation completed with some failures"

# Install GD with all prerequisites
RUN echo "Installing GD with prerequisites..." && \
    cpanm --notest ExtUtils::PkgConfig && \
    cpanm --notest GD || \
    echo "GD first attempt failed, trying with force..." && \
    cpanm --force --notest GD || \
    echo "GD installation completed"

# Install Database modules with compatibility fix
RUN echo "Installing database modules..." && \
    apt-get update && \
    apt-get install -y default-libmysqlclient-dev libmariadb-dev-compat && \
    cpanm --notest DBI && \
    cpanm --notest Devel::CheckLib && \
    echo "Installing older compatible DBD::mysql version..." && \
    cpanm --notest --force DBD::mysql@4.050 && \
    cpanm --notest SQL::Translator && \
    apt-get clean && \
    echo "Database modules installation completed"

# Verify DBD::mysql is working properly
RUN perl -e "use DBI; use DBD::mysql; print \"✅ DBD::mysql version: \$DBD::mysql::VERSION\n\";" || \
    echo "❌ DBD::mysql verification failed - using fallback approach"

# Install core utility modules
RUN cpanm --notest Config::General \
    && cpanm --notest Data::Printer \
    && cpanm --notest Data::UUID \
    && cpanm --notest Email::Valid \
    && cpanm --notest Term::Size::Any

# Install web modules with retry logic
RUN cpanm --retry 3 --notest HTML::FormHandler::Moose || true
RUN cpanm --retry 3 --notest HTML::Scrubber || true

# Install caching modules with retry logic
RUN cpanm --retry 3 --notest Cache::Memcached || true
RUN cpanm --retry 3 --notest Cache::Redis || true

# Install Plack/Starman with aggressive retry logic
RUN for i in 1 2 3 4 5; do cpanm --notest Plack && break || sleep 10; done || cpanm --force --notest Plack || true
RUN for i in 1 2 3 4 5; do cpanm --notest Starman && break || sleep 10; done || cpanm --force --notest Starman || true
RUN for i in 1 2 3 4 5; do cpanm --notest Plack::Handler::Starman && break || sleep 10; done || cpanm --force --notest Plack::Handler::Starman || true

# Install logging and search modules with retry logic
RUN cpanm --retry 3 --notest Log::Log4perl::Catalyst || true
RUN cpanm --retry 3 --notest Search::QueryParser || true
RUN cpanm --retry 3 --notest MooseX::ClassAttribute || true

# Install problematic modules with force
RUN cpanm --force --notest MediaWiki::Bot || true
RUN cpanm --force --notest DBIx::Class::Result::ColumnData || true

# Try to install optional caching and compression plugins
RUN cpanm --notest Catalyst::Plugin::PageCache || true
RUN cpanm --notest Catalyst::Plugin::Cache || true
RUN cpanm --notest Catalyst::Plugin::Compress || true

# Install additional modules that might be needed
RUN cpanm --notest JSON || true
RUN cpanm --notest JSON::XS || true
RUN cpanm --notest YAML || true
RUN cpanm --notest YAML::XS || true

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
COPY setup/config_setup.sh /setup/config_setup.sh
COPY setup/module-setup.sh /setup/module_setup.sh
COPY setup/redis-setup.sh /setup/redis_startup.sh

# Make setup scripts executable
RUN chmod +x /setup/*.sh

# Copy startup script
COPY startup.sh /usr/local/bin/startup.sh
RUN chmod +x /usr/local/bin/startup.sh

# Set proper permissions
RUN chmod +x /src/RfamWeb/script/rfamweb_server.pl

# All Perl module installation is handled by setup scripts at runtime

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