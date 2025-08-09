#!/bin/bash
# startup.sh - Simplified startup without module installation
set -euo pipefail

echo "=== STARTING RFAM WEB APPLICATION - BUILD $(date) ==="

# -------------------------------------------------
# Verify critical modules are installed
# -------------------------------------------------
echo "=== Verifying installed modules ==="
critical_modules=(
    "Catalyst::Runtime"
    "DBI"
    "DBD::mysql"
    "Plack"
    "JSON"
    "DateTime"
    "DateTime::Format::MySQL"
    "File::Slurp"
    "Search::QueryParser"
)

optional_modules=(
    "XML::Feed"
    "Log::Log4perl::Catalyst"
    "GD"
)

missing_modules=()
for module in "${critical_modules[@]}"; do
    if perl -e "use $module; 1" 2>/dev/null; then
        echo "✅ $module"
    else
        echo "❌ $module - MISSING"
        missing_modules+=("$module")
    fi
done

# If critical modules are missing, show error but continue
if [ ${#missing_modules[@]} -gt 0 ]; then
    echo "⚠️  Warning: ${#missing_modules[@]} critical modules are missing:"
    printf "   - %s\n" "${missing_modules[@]}"
    echo "   Application may not function correctly"
fi

# Check optional modules
echo "=== Checking optional modules ==="
for module in "${optional_modules[@]}"; do
    if perl -e "use $module; 1" 2>/dev/null; then
        echo "✅ $module (optional)"
    else
        echo "⚠️  $module (optional) - missing, some features may be disabled"
    fi
done

# -------------------------------------------------
# Generate config
# -------------------------------------------------
echo "=== Running config setup ==="
if [ -f "/setup/config-setup.sh" ]; then
    echo "Found config setup script, executing..."
    source "/setup/config-setup.sh"
else
    echo "⚠️  Config setup script not found at /setup/config-setup.sh"
    echo "Available files in /setup/:"
    ls -la /setup/ 2>/dev/null || echo "No /setup directory found"
fi

# -------------------------------------------------
# Configuration check
# -------------------------------------------------
echo "=== Configuration check ==="
if [ -f "/src/RfamWeb/config/rfamweb.conf" ]; then
    echo "✅ Main config file found"
else
    echo "⚠️  Main config file not found - application may have issues"
fi

# -------------------------------------------------
# Test basic database connectivity (non-fatal)
# -------------------------------------------------
echo "=== BASIC DATABASE CONNECTIVITY CHECK ==="
if [ -n "${DATABASE_HOST:-}" ]; then
    if nc -z "${DATABASE_HOST}" "${DATABASE_PORT:-3306}" 2>/dev/null; then
        echo "✅ Database host ${DATABASE_HOST}:${DATABASE_PORT:-3306} is reachable"
    else
        echo "⚠️  Database host ${DATABASE_HOST}:${DATABASE_PORT:-3306} is not reachable"
        echo "   Application will attempt to connect anyway"
    fi
else
    echo "⚠️  DATABASE_HOST not set"
fi

# -------------------------------------------------
# Final module verification with better error handling
# -------------------------------------------------
echo "=== Final module check ==="
perl_verification_result=0
perl -e '
use strict;
use warnings;

my @required = qw(
    Catalyst::Runtime
    DBI
    DBD::mysql
    DateTime
    DateTime::Format::MySQL
    File::Slurp
    Search::QueryParser
);

my $all_good = 1;
for my $module (@required) {
    eval "require $module";
    if ($@) {
        print "❌ $module: $@";
        $all_good = 0;
    } else {
        print "✅ $module\n";
    }
}

exit($all_good ? 0 : 1);
' || perl_verification_result=$?

if [ $perl_verification_result -eq 0 ]; then
    echo "✅ All critical modules verified"
else
    echo "❌ Some modules failed to load - application may have issues"
    echo "   Continuing startup anyway..."
fi

# -------------------------------------------------
# Test the Catalyst application startup
# -------------------------------------------------
echo "=== Testing Catalyst Application ==="
cd /src

# Test if the application can be loaded at all
echo "Testing basic Catalyst app loading..."
if perl -I/src/RfamWeb -I/src/Rfam/Schemata -I/src/PfamBase/lib -I/src/PfamLib -I/src/PfamSchemata -e "use RfamWeb; print 'Catalyst app loaded successfully\n';" 2>/dev/null; then
    echo "✅ Catalyst application loads successfully"
else
    echo "❌ Catalyst application failed to load - checking detailed error..."
    perl -I/src/RfamWeb -I/src/Rfam/Schemata -I/src/PfamBase/lib -I/src/PfamLib -I/src/PfamSchemata -e "use RfamWeb;" 2>&1 || true
fi

# Test database connection
echo "Testing database connection..."
if [ -n "${DATABASE_HOST:-}" ]; then
    perl -I/src/RfamWeb -I/src/Rfam/Schemata -I/src/PfamBase/lib -I/src/PfamLib -I/src/PfamSchemata -e "
    use DBI;
    my \$dbh = DBI->connect(
        'dbi:mysql:database=${DATABASE_NAME:-rfam_live};host=${DATABASE_HOST:-localhost};port=${DATABASE_PORT:-3306}',
        '${DATABASE_USER:-rfam}',
        '${DATABASE_PASSWORD:-}',
        { PrintError => 0, RaiseError => 1 }
    );
    if (\$dbh) {
        print 'Database connection successful\n';
        \$dbh->disconnect;
    }
    " 2>/dev/null && echo "✅ Database connection working" || echo "⚠️ Database connection failed"
fi
echo "=== Starting Rfam Web application ==="
echo "Application will be available at http://localhost:3000"

# Check if we have the application script
if [ ! -f "/src/RfamWeb/script/rfamweb_server.pl" ]; then
    echo "❌ Application server script not found at /src/RfamWeb/script/rfamweb_server.pl"
    exit 1
fi

# Start with starman if available, otherwise use the built-in server
if command -v starman >/dev/null 2>&1; then
    echo "🚀 Starting with Starman server"
    export PERL5LIB="/src/RfamWeb:/src/Rfam/Schemata:/src/PfamBase/lib:/src/PfamLib:/src/PfamSchemata"
    cd /src
    
    echo "Starting server in production mode..."
    exec /src/RfamWeb/script/rfamweb_server.pl -p 3000 --fork --keepalive
else
    echo "🚀 Starting with built-in server"
    export PERL5LIB="/src/RfamWeb:/src/Rfam/Schemata:/src/PfamBase/lib:/src/PfamLib:/src/PfamSchemata"
    cd /src
    exec /src/RfamWeb/script/rfamweb_server.pl -p 3000
fi