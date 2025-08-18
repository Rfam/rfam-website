# Base image https://hub.docker.com/_/perl/
FROM perl:latest

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libgd-dev \
    libgd3 \
    libmariadb-dev \
    libmariadb-dev-compat \
    libssl-dev \
    libxml2-dev \
    libxml2-utils \
    libxslt1-dev \
    libexpat1-dev \
    expat \
    zlib1g-dev \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libfontconfig1-dev \
    build-essential \
    git \
    curl \
    netcat-openbsd \
    default-libmysqlclient-dev \
    pkg-config \
    dos2unix \
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
    Catalyst::View::JSON \
    Template::Plugin::Number::Format

# Database Modules
RUN cpanm --notest \
    DBI \
    Devel::CheckLib \
    DBD::mysql@4.050 \
    DBIx::Class \
    DBIx::Class::Schema::Loader \
    SQL::Abstract \
    SQL::Translator

# Web Server Modules
RUN cpanm --notest \
    Plack \
    Starman \
    Plack::Handler::Starman

# XML Processing Modules
RUN echo "Installing XML::Parser..." && \
    cpanm --notest XML::Parser

# Force install critical modules
RUN (cpanm --force --verbose XML::Feed || \
     cpanm --force --verbose --reinstall XML::Feed || \
     cpanm --force --verbose --mirror http://cpan.metacpan.org/ XML::Feed || \
     cpanm --force --verbose --mirror https://www.cpan.org/ XML::Feed) && \
    perl -e "use XML::Feed; print 'XML::Feed successfully loaded\n';"

# Graphics Module
RUN cpanm --notest GD

# Core Utilities
RUN cpanm --notest \
    Config::General \
    Data::UUID \
    Email::Valid \
    JSON \
    YAML \
    Search::QueryParser \
    HTML::FormHandler::Moose \
    Data::Printer

# Logging Modules
RUN cpanm --notest \
    Log::Log4perl \
    Log::Dispatch

# DateTime Modules
RUN cpanm --notest \
    DateTime \
    DateTime::Format::MySQL \
    DateTime::Format::ISO8601 \
    DateTime::TimeZone

# File Handling Modules
RUN cpanm --notest \
    File::Slurp \
    Path::Tiny \
    File::Copy::Recursive

# Web Modules
RUN cpanm --notest \
    LWP::UserAgent \
    HTTP::Request \
    URI

# Core Perl Utility Modules
RUN cpanm --notest \
    Moose \
    Try::Tiny \
    List::Util \
    Scalar::Util \
    Data::Dumper \
    Digest::MD5 \
    Digest::SHA \
    MIME::Base64 \
    Encode

# Optional Catalyst Plugins
RUN cpanm --notest \
    Catalyst::Plugin::Session \
    Catalyst::Plugin::Session::State::Cookie \
    Catalyst::Plugin::Session::Store::File \
    Catalyst::Plugin::Authentication \
    Catalyst::Plugin::Authorization::Roles \
    Catalyst::Plugin::Cache

# Install PageCache plugin and additional modules from original
RUN cpanm --notest Catalyst::Plugin::PageCache && \
    cpanm --notest Catalyst::View::Email

# Email Modules
RUN cpanm --notest \
    Email::MIME \
    Email::Sender::Simple \
    Email::Valid

# Cache Modules
RUN cpanm --notest \
    CHI \
    Cache::Cache \
    Cache::Memcached

# Testing Modules
RUN cpanm --notest \
    Test::More \
    Test::Deep \
    Test::WWW::Mechanize::Catalyst

# Set build arguments for flexibility
ARG REPO_URL=https://github.com/Rfam/rfam-website.git
ARG BRANCH=main

# Clone the source code
WORKDIR /tmp
RUN git clone --depth 1 ${REPO_URL} rfam-source || \
    git clone --depth 1 --branch master ${REPO_URL} rfam-source || \
    git clone --depth 1 --branch ${BRANCH} ${REPO_URL} rfam-source

# Copy source code to final location and verify structure
RUN mkdir -p /src && cp -r /tmp/rfam-source/* /src/

# Verify critical application files exist
RUN echo "Checking application structure..." && \
    ls -la /src/ && \
    echo "Checking for RfamWeb directory..." && \
    ls -la /src/RfamWeb/ && \
    echo "Checking for main application files..." && \
    find /src -name "*.pm" -path "*/RfamWeb*" | head -10 && \
    echo "Checking for RfamWeb.pm specifically..." && \
    find /src -name "RfamWeb.pm" -o -name "rfamweb.pm" | head -5

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

# Fix line endings and make executable
RUN dos2unix /usr/local/bin/startup.sh /setup/config-setup.sh && \
    chmod +x /usr/local/bin/startup.sh /setup/config-setup.sh

# Set proper permissions
RUN chmod +x /src/RfamWeb/script/rfamweb_server.pl

# Clean up
RUN rm -rf /tmp/rfam-source /var/lib/apt/lists/* /root/.cpanm

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