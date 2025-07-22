#!/bin/bash
# config_setup.sh
# Generate Catalyst plugin and database configuration
set -euo pipefail

echo "=== config_setup.sh: Generating configuration ==="
mkdir -p /src/RfamWeb/config

cat > /src/RfamWeb/config/rfamweb_local.conf <<EOF
<Model RfamDB>
  schema_class RfamDB
  connect_info "dbi:mysql:database=${DATABASE_NAME};host=${DATABASE_HOST};port=${DATABASE_PORT};mysql_connect_timeout=10;mysql_read_timeout=30;mysql_write_timeout=30"
  connect_info ${DATABASE_USER}
  connect_info ${DATABASE_PASSWORD}
  <connect_info>
    on_connect_do "SET SESSION sql_mode=''"
    mysql_enable_utf8 1
    mysql_auto_reconnect 1
    AutoCommit 1
    RaiseError 1
    PrintError 0
  </connect_info>
</Model>

<Plugin Cache>
  <backend>
    class Cache::Redis
    server ${REDIS_HOST:-redis-service}:${REDIS_PORT:-6379}
    debug 0
    reconnect 10
    every 500
    <data>
      namespace rfam_cache
      default_expire 3600
    </data>
  </backend>
</Plugin>

<Plugin Static::Simple>
  expires 86400
  include_path /src/RfamWeb/root
  include_path /src/PfamBase/root
  <mime>
    css text/css
    js  application/javascript
    png image/png
    jpg image/jpeg
    gif image/gif
  </mime>
</Plugin>

<Plugin Compress>
  content_type text/html
  content_type text/plain
  content_type text/css
  content_type application/javascript
  content_type application/json
</Plugin>
EOF

echo "Generated /src/RfamWeb/config/rfamweb_local.conf:"
cat /src/RfamWeb/config/rfamweb_local.conf
echo "=== config_setup.sh complete ==="