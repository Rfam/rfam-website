# Base image https://hub.docker.com/_/perl/
FROM perl:latest

# Install system dependencies including ALL required libraries for GD and XML
RUN apt-get update && apt-get install -y \
    libgd-dev \
    libgd3 \
    libgdchart-gd2-xpm-dev \
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
    libxml-libxml-perl \
    libxml-parser-perl \
    dos2unix \
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

# Try to install XML::Feed early with all dependencies
RUN echo "Installing XML::Feed and dependencies early..." && \
    cpanm --notest XML::Parser \
    && cpanm --notest XML::LibXML \
    && cpanm --notest Class::ErrorHandler \
    && cpanm --notest DateTime::Format::Mail \
    && cpanm --notest DateTime::Format::W3CDTF \
    && cpanm --notest XML::RSS \
    && cpanm --notest XML::Atom \
    && cpanm --notest XML::Feed \
    && echo "✅ XML::Feed installed successfully" || \
    echo "⚠️ XML::Feed installation failed - will create stub later"

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

# Install ALL the optional modules during build phase while network is available
RUN echo "Installing DateTime modules..." && \
    cpanm --notest DateTime && \
    cpanm --notest DateTime::Format::MySQL && \
    cpanm --notest DateTime::Format::ISO8601 && \
    cpanm --notest DateTime::TimeZone

RUN echo "Installing File handling modules..." && \
    cpanm --notest File::Slurp && \
    cpanm --notest Path::Tiny && \
    cpanm --notest File::Copy::Recursive

RUN echo "Installing XML Parser with verbose output..." && \
    cpanm --verbose --notest XML::Parser || \
    (echo "XML::Parser failed, installing system dependencies and retrying..." && \
     apt-get update && apt-get install -y libexpat1-dev expat && \
     cpanm --force --notest XML::Parser) || \
    (echo "CRITICAL: XML::Parser installation failed completely" && exit 1)

RUN echo "Installing XML::LibXML with timeout and retry handling..." && \
    (perl -e "use XML::LibXML; print 'XML::LibXML already available from system\n'" 2>/dev/null && echo "✅ XML::LibXML working from system packages") || \
    (echo "Trying XML::LibXML with shorter timeout and older version..." && \
     timeout 300 cpanm --mirror http://cpan.metacpan.org/ --notest XML::LibXML@2.0134) || \
    (echo "Trying even older stable version..." && \
     timeout 300 cpanm --mirror http://cpan.metacpan.org/ --notest XML::LibXML@2.0132) || \
    (echo "Trying XML::Parser as fallback..." && \
     cpanm --notest XML::Parser && \
     echo "⚠️ Using XML::Parser instead of XML::LibXML - reduced functionality") || \
    (echo "CRITICAL: No XML processing modules could be installed" && exit 1)

RUN echo "Installing XML modules with timeout protection..." && \
    (timeout 180 cpanm --mirror http://cpan.metacpan.org/ --notest XML::RSS || echo "⚠️ XML::RSS failed - continuing") && \
    (timeout 180 cpanm --mirror http://cpan.metacpan.org/ --notest XML::Atom || echo "⚠️ XML::Atom failed - continuing") && \
    (cpanm --mirror http://cpan.metacpan.org/ --notest Class::ErrorHandler || echo "⚠️ Class::ErrorHandler failed - continuing")

RUN echo "Installing DateTime format modules with timeout..." && \
    (timeout 180 cpanm --mirror http://cpan.metacpan.org/ --notest DateTime::Format::Mail || echo "⚠️ DateTime::Format::Mail failed - continuing") && \
    (timeout 180 cpanm --mirror http://cpan.metacpan.org/ --notest DateTime::Format::W3CDTF || echo "⚠️ DateTime::Format::W3CDTF failed - continuing")

RUN echo "Installing XML::Feed with simple approach..." && \
    (timeout 300 cpanm --mirror http://cpan.metacpan.org/ --notest XML::Feed && echo "✅ XML::Feed installed") || \
    (echo "⚠️ XML::Feed installation failed - some RSS functionality may be limited")

RUN echo "Installing Web modules..." && \
    cpanm --notest LWP::UserAgent && \
    cpanm --notest HTTP::Request && \
    cpanm --notest URI

RUN echo "Installing GD with timeout and fallback..." && \
    (timeout 300 cpanm --notest GD && echo "✅ GD installed successfully") || \
    (echo "GD failed, installing File::Which first..." && \
     timeout 180 cpanm --mirror http://cpan.metacpan.org/ --notest File::Which && \
     timeout 300 cpanm --notest GD && echo "✅ GD installed after dependency fix") || \
    (echo "⚠️ GD installation failed - image generation will be disabled")

RUN echo "Installing Image processing modules with timeout..." && \
    (timeout 300 cpanm --notest Image::Magick && echo "✅ Image::Magick installed") || \
    (timeout 300 cpanm --notest Graphics::Magick && echo "✅ Graphics::Magick installed") || \
    echo "⚠️ No image processing modules installed - image features disabled"

RUN echo "Installing Logging modules..." && \
    cpanm --notest Log::Log4perl || (echo "CRITICAL: Log::Log4perl failed" && exit 1) && \
    (cpanm --notest Log::Log4perl::Catalyst || cpanm --force --notest Log::Log4perl::Catalyst || echo "⚠️ Log4perl::Catalyst failed - using basic logging") && \
    cpanm --notest Log::Dispatch || (echo "CRITICAL: Log::Dispatch failed" && exit 1)

RUN echo "Installing additional Catalyst plugins (optional)..." && \
    (cpanm --notest Catalyst::Plugin::Session && echo "✅ Session plugin installed") || echo "⚠️ Session plugin failed" && \
    (cpanm --notest Catalyst::Plugin::Session::State::Cookie && echo "✅ Session cookie plugin installed") || echo "⚠️ Session cookie plugin failed" && \
    (cpanm --notest Catalyst::Plugin::Session::Store::File && echo "✅ Session file store installed") || echo "⚠️ Session file store failed" && \
    (cpanm --notest Catalyst::Plugin::Authentication && echo "✅ Authentication plugin installed") || echo "⚠️ Authentication plugin failed" && \
    (cpanm --notest Catalyst::Plugin::Authorization::Roles && echo "✅ Authorization plugin installed") || echo "⚠️ Authorization plugin failed" && \
    (cpanm --notest Catalyst::Plugin::PageCache && echo "✅ PageCache installed") || \
    (cpanm --notest CHI && echo "✅ CHI cache installed") || echo "⚠️ No caching modules installed" && \
    (cpanm --notest Catalyst::Plugin::Cache && echo "✅ Cache plugin installed") || echo "⚠️ Cache plugin failed"

RUN echo "Installing additional View modules (optional)..." && \
    cpanm --notest Catalyst::View::JSON && \
    (cpanm --notest Catalyst::View::Email && echo "✅ Email view installed") || echo "⚠️ Email view failed"

RUN echo "Installing Database ORM modules..." && \
    cpanm --notest DBIx::Class || (echo "CRITICAL: DBIx::Class failed" && exit 1) && \
    (cpanm --notest DBIx::Class::Schema::Loader && echo "✅ Schema loader installed") || echo "⚠️ Schema loader failed" && \
    cpanm --notest SQL::Abstract || (echo "CRITICAL: SQL::Abstract failed" && exit 1)

RUN echo "Installing Core Perl utility modules..." && \
    cpanm --notest Moose && \
    cpanm --notest Try::Tiny && \
    cpanm --notest List::Util && \
    cpanm --notest Scalar::Util && \
    cpanm --notest Data::Dumper && \
    cpanm --notest Digest::MD5 && \
    cpanm --notest Digest::SHA && \
    cpanm --notest MIME::Base64 && \
    cpanm --notest Encode

RUN echo "Installing Email handling modules (optional)..." && \
    cpanm --notest Email::MIME && \
    (cpanm --notest Email::Sender::Simple && echo "✅ Email sender installed") || echo "⚠️ Email sender failed" && \
    cpanm --notest Email::Valid

RUN echo "Installing Cache modules (optional)..." && \
    (cpanm --notest CHI && echo "✅ CHI installed") || echo "⚠️ CHI failed" && \
    (cpanm --notest Cache::Cache && echo "✅ Cache::Cache installed") || echo "⚠️ Cache::Cache failed" && \
    (cpanm --notest Cache::Memcached && echo "✅ Memcached client installed") || echo "⚠️ Memcached failed"

RUN echo "Installing Testing modules (optional)..." && \
    (cpanm --notest Test::WWW::Mechanize::Catalyst && echo "✅ Mechanize test installed") || echo "⚠️ Mechanize test failed" && \
    cpanm --notest Test::More && \
    (cpanm --notest Test::Deep && echo "✅ Test::Deep installed") || echo "⚠️ Test::Deep failed"

# Verify critical database connectivity
RUN perl -e "use DBI; use DBD::mysql; print \"✅ DBD::mysql version: \$DBD::mysql::VERSION\n\";" || \
    echo "❌ DBD::mysql verification failed"

# Force install critical modules that are causing startup failures
RUN echo "=== CRITICAL MODULE INSTALLATION - MUST SUCCEED ===" && \
    echo "Installing XML::Feed with all possible strategies..." && \
    (cpanm --force --verbose XML::Feed || \
     cpanm --force --verbose --reinstall XML::Feed || \
     cpanm --force --verbose --mirror http://cpan.metacpan.org/ XML::Feed || \
     cpanm --force --verbose --mirror https://www.cpan.org/ XML::Feed || \
     (echo "CRITICAL FAILURE: XML::Feed could not be installed" && exit 1)) && \
    echo "Installing GD with all possible strategies..." && \
    (cpanm --force --verbose GD || \
     cpanm --force --verbose --reinstall GD || \
     (echo "WARNING: GD could not be installed - continuing")) && \
    echo "=== VERIFYING CRITICAL MODULES ===" && \
    perl -e "use XML::Feed; print 'XML::Feed successfully loaded\n';" || (echo "CRITICAL: XML::Feed verification failed" && exit 1) && \
    echo "✅ All critical modules verified"

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

# Force cache bust for startup script
ARG CACHE_BUST=1

# Copy both startup and config setup scripts
COPY startup.sh /usr/local/bin/startup.sh
COPY setup/config-setup.sh /setup/config-setup.sh

# Fix line endings and make executable
RUN dos2unix /usr/local/bin/startup.sh /setup/config-setup.sh && \
    chmod +x /usr/local/bin/startup.sh /setup/config-setup.sh && \
    ls -la /usr/local/bin/startup.sh /setup/config-setup.sh && \
    echo "Checking startup script format:" && \
    head -1 /usr/local/bin/startup.sh | od -c

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