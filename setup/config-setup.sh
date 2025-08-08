#!/bin/bash
# config-setup.sh
# Generate Catalyst plugin and database configuration
set -euo pipefail

echo "=== config-setup.sh: Generating configuration ==="
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

# Configure the application to know its external URL
<Plugin::Static::Simple>
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

# Set the base URI for URL generation
base_uri https://preview.rfam.org

# Configure proxy awareness
using_frontend_proxy 1

# Trust proxy headers
<Engine>
  <Plack>
    # Trust X-Forwarded headers from proxy
    enable_reverse_proxy 1
  </Plack>
</Engine>

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
echo "=== config-setup.sh complete ==="