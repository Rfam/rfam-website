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
    "GD"
)

optional_modules=(
    "XML::Feed"
    "Log::Log4perl::Catalyst"
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
# Configuration setup
# -------------------------------------------------
echo "=== Running config setup ==="
source "/setup/config-setup.sh"

# -------------------------------------------------
# Final module verification
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
    GD
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
# Application and database test
# -------------------------------------------------
echo "=== Testing Catalyst Application ==="
cd /src

# Test database connectivity and connection
echo "Testing database connectivity and connection..."
if [ -n "${DATABASE_HOST:-}" ]; then
    if nc -z "${DATABASE_HOST}" "${DATABASE_PORT:-3306}" 2>/dev/null; then
        echo "✅ Database host ${DATABASE_HOST}:${DATABASE_PORT:-3306} is reachable"
        
        # Test actual database connection
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
    else
        echo "⚠️  Database host ${DATABASE_HOST}:${DATABASE_PORT:-3306} is not reachable"
    fi
else
    echo "⚠️  DATABASE_HOST not set"
fi

# -------------------------------------------------
# Start application
# -------------------------------------------------
echo "=== Starting Rfam Web application ==="
echo "Application will be available at http://localhost:3000"

# Set Perl library path
export PERL5LIB="/src/RfamWeb:/src/Rfam/Schemata:/src/PfamBase/lib:/src/PfamLib:/src/PfamSchemata"
cd /src

# Start with starman if available, otherwise use the built-in server
if command -v starman >/dev/null 2>&1; then
    echo "🚀 Starting with Starman server"
    exec /src/RfamWeb/script/rfamweb_server.pl -p 3000 --fork --keepalive
else
    echo "🚀 Starting with built-in server"
    exec /src/RfamWeb/script/rfamweb_server.pl -p 3000
fi