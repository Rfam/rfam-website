#!/bin/bash
# Minimal Catalyst configuration for Kubernetes
set -euo pipefail

echo "=== GENERATING MINIMAL CATALYST CONFIG ==="

mkdir -p /src/RfamWeb/config

cat > /src/RfamWeb/config/rfamweb_local.conf <<EOF
# Database connection
<Model RfamDB>
  schema_class RfamDB
  connect_info "dbi:mysql:database=${DATABASE_NAME};host=${DATABASE_HOST};port=${DATABASE_PORT}"
  connect_info ${DATABASE_USER}
  connect_info ${DATABASE_PASSWORD}
  <connect_info>
    mysql_enable_utf8 1
    mysql_auto_reconnect 1
    AutoCommit 1
  </connect_info>
</Model>

# Static files - let Apache handle them
<Plugin::Static::Simple>
  include_path /src/RfamWeb/root
  include_path /src/PfamBase/root
</Plugin>

# External URL configuration
base_uri {{ .Values.baseUrl }}
using_frontend_proxy 1
EOF

echo "Generated minimal config. Size: $(wc -l < /src/RfamWeb/config/rfamweb_local.conf) lines"
echo "=== CONFIG GENERATION COMPLETE ==="