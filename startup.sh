#!/bin/bash
# startup.sh
set -euo pipefail

echo "Starting Rfam Web Application..."

# -------------------------------------------------
# Install Perl modules (check and create stubs)
# -------------------------------------------------
source "/setup/module_setup.sh"

# -------------------------------------------------
# Generate config
# -------------------------------------------------
source "/setup/config_setup.sh"

# -------------------------------------------------
# Wait for Redis
# -------------------------------------------------
if [ -n "${REDIS_HOST:-}" ]; then
  source "/setup/redis_startup.sh"
else
  echo "REDIS_HOST not set; skipping Redis wait."
fi

# -------------------------------------------------
# Test critical modules only
# -------------------------------------------------
echo "Testing critical Perl modules..."
for module in DateTime DateTime::Format::MySQL File::Slurp; do
  if perl -e "use $module; 1" 2>/dev/null; then
    echo "✅ $module - OK"
  else
    echo "⚠️  $module - Using stub implementation"
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
echo "Starting Rfam Web application..."
echo "Application will be available at http://localhost:3000"

if command -v starman >/dev/null 2>&1; then
  exec /src/RfamWeb/script/rfamweb_server.pl -p 3000 --fork --keepalive
else
  exec /src/RfamWeb/script/rfamweb_server.pl -p 3000
fi