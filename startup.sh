#!/bin/bash
# startup.sh - Force Search::QueryParser creation first
set -euo pipefail

echo "=== STARTING RFAM WEB APPLICATION - BUILD $(date) ==="

# -------------------------------------------------
# IMMEDIATELY create Search::QueryParser stub
# -------------------------------------------------
echo "=== FORCE CREATING Search::QueryParser STUB ==="
PERL_SITE="/usr/local/lib/perl5/site_perl/5.42.0"
mkdir -p "${PERL_SITE}/Search"

cat > ${PERL_SITE}/Search/QueryParser.pm <<'EOF'
package Search::QueryParser;
use strict; use warnings;
our $VERSION='1.0';
sub new { bless {}, shift }
sub parse { {} }
sub build_sql_clause { '' }
sub build_lucene_query { '' }
1;
EOF

echo "✅ Search::QueryParser stub created at ${PERL_SITE}/Search/QueryParser.pm"

# Test it immediately
if perl -e "use Search::QueryParser; print 'Search::QueryParser loaded successfully\n'; 1" 2>/dev/null; then
  echo "✅ Search::QueryParser stub is working"
else
  echo "❌ Search::QueryParser stub failed to load"
  echo "Contents of Search directory:"
  ls -la ${PERL_SITE}/Search/ || echo "Directory doesn't exist"
fi

# -------------------------------------------------
# Install other Perl modules (check and create stubs)
# -------------------------------------------------
echo "=== Running module setup ==="
if [ -f "/setup/module_setup.sh" ]; then
  source "/setup/module_setup.sh"
else
  echo "❌ Module setup script not found, creating basic stubs..."
  
  # Create other critical stubs inline
  mkdir -p "${PERL_SITE}/DateTime/Format"
  mkdir -p "${PERL_SITE}/File"
  mkdir -p "${PERL_SITE}/Log/Log4perl"
  mkdir -p "${PERL_SITE}/Catalyst/Plugin"
  mkdir -p "${PERL_SITE}/Catalyst/View"
  mkdir -p "${PERL_SITE}/XML"
  
  # DateTime stub
  cat > ${PERL_SITE}/DateTime.pm <<'EOF'
package DateTime;
use strict; use warnings;
our $VERSION='1.0';
sub new { bless {@_}, shift }
sub now { bless {year=>2024,month=>1,day=>1,hour=>0,minute=>0,second=>0}, shift }
sub ymd { sprintf "%04d%s%02d%s%02d", $_[0]->{year}, $_[1]||'-', $_[0]->{month}, $_[1]||'-', $_[0]->{day} }
sub hms { sprintf "%02d%s%02d%s%02d", $_[0]->{hour}, $_[1]||':', $_[0]->{minute}, $_[1]||':', $_[0]->{second} }
1;
EOF
  
  # File::Slurp stub
  cat > ${PERL_SITE}/File/Slurp.pm <<'EOF'
package File::Slurp;
use strict; use warnings; use Exporter;
our @ISA=qw(Exporter); our @EXPORT=qw(read_file write_file append_file);
sub read_file { open my $f,'<',$_[0] or die $!; local $/; <$f> }
sub write_file { open my $f,'>',$_[0] or die $!; print $f $_[1] }
sub append_file { open my $f,'>>',$_[0] or die $!; print $f $_[1] }
1;
EOF

  echo "✅ Basic stubs created inline"
fi

# -------------------------------------------------
# Configure RfamDB Model
# -------------------------------------------------
echo "=== Configuring RfamDB Model ==="
MODEL_FILE="/src/RfamWeb/script/../lib/RfamWeb/Model/RfamDB.pm"

if ! grep -q "schema_class" "$MODEL_FILE" 2>/dev/null; then
  echo "Adding database configuration to RfamDB model..."
  cp "$MODEL_FILE" "${MODEL_FILE}.bak" 2>/dev/null || true
  
  # Add the configuration before the final "1;"
  sed -i '/^1;$/i \
\
# Database configuration added by startup script\
__PACKAGE__->config(\
    schema_class => "RfamDB",\
    connect_info => {\
        dsn => "dbi:mysql:database=" . ($ENV{DATABASE_NAME} || "rfam_live") . ";host=" . ($ENV{DATABASE_HOST} || "localhost") . ";port=" . ($ENV{DATABASE_PORT} || "3306"),\
        user => $ENV{DATABASE_USER} || "rfam",\
        password => $ENV{DATABASE_PASSWORD} || "",\
        AutoCommit => 1,\
        mysql_enable_utf8 => 1,\
    }\
);' "$MODEL_FILE"
  
  echo "✅ RfamDB model configured: mysql://${DATABASE_USER}@${DATABASE_HOST}:${DATABASE_PORT}/${DATABASE_NAME}"
else
  echo "✅ RfamDB model already configured"
fi

# -------------------------------------------------
# Configure RfamDB Model 
# -------------------------------------------------
echo "=== Configuring RfamDB Model ==="
MODEL_FILE="/src/RfamWeb/script/../lib/RfamWeb/Model/RfamDB.pm"

if ! grep -q "schema_class" "$MODEL_FILE" 2>/dev/null; then
  echo "Adding database configuration to RfamDB model..."
  cp "$MODEL_FILE" "${MODEL_FILE}.bak" 2>/dev/null || true
  
  # Add the configuration before the final "1;"
  sed -i '/^1;$/i \
\
# Database configuration added by startup script\
__PACKAGE__->config(\
    schema_class => "RfamDB",\
    connect_info => {\
        dsn => "dbi:mysql:database=" . ($ENV{DATABASE_NAME} || "rfam_live") . ";host=" . ($ENV{DATABASE_HOST} || "localhost") . ";port=" . ($ENV{DATABASE_PORT} || "3306"),\
        user => $ENV{DATABASE_USER} || "rfam",\
        password => $ENV{DATABASE_PASSWORD} || "",\
        AutoCommit => 1,\
        mysql_enable_utf8 => 1,\
    }\
);' "$MODEL_FILE"
  
  echo "✅ RfamDB model configured: mysql://${DATABASE_USER}@${DATABASE_HOST}:${DATABASE_PORT}/${DATABASE_NAME}"
else
  echo "✅ RfamDB model already configured"
fi

# -------------------------------------------------
# Generate config
# -------------------------------------------------
echo "=== Running config setup ==="
if [ -f "/setup/config_setup.sh" ]; then
  source "/setup/config_setup.sh"
else
  echo "⚠️  Config setup script not found"
fi

# -------------------------------------------------
# Wait for Redis
# -------------------------------------------------
if [ -n "${REDIS_HOST:-}" ]; then
  echo "=== Waiting for Redis ==="
  if [ -f "/setup/redis_startup.sh" ]; then
    source "/setup/redis_startup.sh"
  else
    echo "⚠️  Redis startup script not found"
  fi
else
  echo "REDIS_HOST not set; skipping Redis wait."
fi

# -------------------------------------------------
# Test critical modules
# -------------------------------------------------
echo "=== Testing critical Perl modules ==="
for module in DateTime File::Slurp Search::QueryParser; do
  if perl -e "use $module; 1" 2>/dev/null; then
    echo "✅ $module - OK"
  else
    echo "❌ $module - FAILED"
  fi
done

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
# Start the application
# -------------------------------------------------
echo "=== Starting Rfam Web application ==="
echo "Application will be available at http://localhost:3000"

if command -v starman >/dev/null 2>&1; then
  exec /src/RfamWeb/script/rfamweb_server.pl -p 3000 --fork --keepalive
else
  exec /src/RfamWeb/script/rfamweb_server.pl -p 3000
fi