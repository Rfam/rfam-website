#!/bin/bash
# module-setup.sh - Runtime stub creation for optional modules only
set -euo pipefail
echo "=== Module setup script starting ==="

PERL_SITE="/usr/local/lib/perl5/site_perl/5.42.0"
mkdir -p "${PERL_SITE}"

# Function to install or create stub if module is missing
install_or_stub() {
  local module="$1"
  local stub_code="$2"
  
  # Check if already installed
  if perl -e "use $module; 1" 2>/dev/null; then
    echo "✅ $module"
    return
  fi
  
  # Try to install if network is available
  if ping -c1 8.8.8.8 >/dev/null 2>&1; then
    echo "🌐 Trying to install $module..."
    if cpanm --notest --quiet "$module" 2>/dev/null; then
      echo "✅ $module - Installed"
      return
    elif cpanm --force --notest --quiet "$module" 2>/dev/null; then
      echo "✅ $module - Installed (forced)"
      return
    fi
  fi
  
  # Fall back to stub if installation failed or no network
  if [ -n "$stub_code" ]; then
    echo "⚠️  $module - Creating stub..."
    eval "$stub_code"
    echo "✅ $module - Stub created"
  else
    echo "❌ $module - Missing (no stub available)"
  fi
}

# Verify critical modules are installed (these should be from Dockerfile)
echo "=== Verifying Critical Modules ==="
for module in "Catalyst::Runtime" "DBI" "DBD::mysql" "Plack" "JSON"; do
  if perl -e "use $module; 1" 2>/dev/null; then
    echo "✅ $module"
  else
    echo "❌ $module - CRITICAL MODULE MISSING!"
  fi
done

# Create stubs for optional modules that might be missing
echo "=== Installing or Stubbing Optional Modules ==="

install_or_stub "DateTime" "
cat > ${PERL_SITE}/DateTime.pm <<'EOF'
package DateTime;
use strict; use warnings;
our \$VERSION='1.0';
sub new { bless {@_}, shift }
sub now { bless {year=>2024,month=>1,day=>1,hour=>0,minute=>0,second=>0}, shift }
sub ymd { sprintf \"%04d%s%02d%s%02d\", \$_[0]->{year}, \$_[1]||'-', \$_[0]->{month}, \$_[1]||'-', \$_[0]->{day} }
sub hms { sprintf \"%02d%s%02d%s%02d\", \$_[0]->{hour}, \$_[1]||':', \$_[0]->{minute}, \$_[1]||':', \$_[0]->{second} }
1;
EOF
"

install_or_stub "DateTime::Format::MySQL" "
mkdir -p ${PERL_SITE}/DateTime/Format
cat > ${PERL_SITE}/DateTime/Format/MySQL.pm <<'EOF'
package DateTime::Format::MySQL;
use strict; use warnings; use DateTime;
sub new { bless {}, shift }
sub parse_datetime { DateTime->now() }
sub format_datetime { my(\$s,\$dt)=@_; \$dt->ymd('-').' '.\$dt->hms(':') }
sub format_date { \$_[1]->ymd('-') }
1;
EOF
"

install_or_stub "File::Slurp" "
mkdir -p ${PERL_SITE}/File
cat > ${PERL_SITE}/File/Slurp.pm <<'EOF'
package File::Slurp;
use strict; use warnings; use Exporter;
our @ISA=qw(Exporter); our @EXPORT=qw(read_file write_file append_file);
sub read_file { open my \$f,'<',\$_[0] or die \$!; local \$/; <\$f> }
sub write_file { open my \$f,'>',\$_[0] or die \$!; print \$f \$_[1] }
sub append_file { open my \$f,'>>',\$_[0] or die \$!; print \$f \$_[1] }
1;
EOF
"

install_or_stub "XML::Feed" "
mkdir -p ${PERL_SITE}/XML
cat > ${PERL_SITE}/XML/Feed.pm <<'EOF'
package XML::Feed;
sub new { bless {}, shift } sub parse { bless {}, shift }
sub title { 'Mock Feed' } sub entries { () }
1;
EOF
"

install_or_stub "GD" "
cat > ${PERL_SITE}/GD.pm <<'EOF'
package GD;
use strict; use warnings; use Exporter;
our @ISA=qw(Exporter); our @EXPORT=qw(gdSmallFont gdLargeFont gdTinyFont gdGiantFont);
use constant gdSmallFont=>6; use constant gdLargeFont=>7; use constant gdTinyFont=>9; use constant gdGiantFont=>10;
sub new { bless {}, shift } sub png { '' } sub jpeg { '' } sub colorAllocate { 0 }
sub string {} sub line {}
1;
EOF
"

install_or_stub "Log::Log4perl::Catalyst" "
mkdir -p ${PERL_SITE}/Log/Log4perl
cat > ${PERL_SITE}/Log/Log4perl/Catalyst.pm <<'EOF'
package Log::Log4perl::Catalyst;
use strict; use warnings;
sub new { bless {}, shift }
sub debug { CORE::warn \"[DEBUG] \$_[1]\\n\" if \$_[1] }
sub info { CORE::warn \"[INFO] \$_[1]\\n\" if \$_[1] }
sub warn { CORE::warn \"[WARN] \$_[1]\\n\" if \$_[1] }
sub error { CORE::warn \"[ERROR] \$_[1]\\n\" if \$_[1] }
sub fatal { die \"[FATAL] \$_[1]\\n\" if \$_[1] }
1;
EOF
"

install_or_stub "Catalyst::Plugin::PageCache" "
mkdir -p ${PERL_SITE}/Catalyst/Plugin
cat > ${PERL_SITE}/Catalyst/Plugin/PageCache.pm <<'EOF'
package Catalyst::Plugin::PageCache;
use strict; use warnings;
use Moose::Role;
sub cache_page { 1 }
sub clear_cache { 1 }
1;
EOF
"

install_or_stub "Catalyst::Plugin::Cache" "
mkdir -p ${PERL_SITE}/Catalyst/Plugin
cat > ${PERL_SITE}/Catalyst/Plugin/Cache.pm <<'EOF'
package Catalyst::Plugin::Cache;
use strict; use warnings;
use Moose::Role;
sub cache { bless {}, 'MockCache' }
package MockCache;
sub get { undef }
sub set { 1 }
sub remove { 1 }
sub clear { 1 }
1;
EOF
"

install_or_stub "Catalyst::View::Email" "
mkdir -p ${PERL_SITE}/Catalyst/View
cat > ${PERL_SITE}/Catalyst/View/Email.pm <<'EOF'
package Catalyst::View::Email;
use strict; use warnings;
use base 'Catalyst::View';
sub new { bless {}, shift }
sub process { 1 }
1;
EOF
"

# Final database verification
if perl -e "use DBI; use DBD::mysql; 1" 2>/dev/null; then
  echo "✅ DBD::mysql - Working properly"
else
  echo "❌ DBD::mysql - MISSING (application will not work)"
fi

echo "=== Module setup script complete ==="
echo "DEBUG: Created stub files:"
find ${PERL_SITE} -name "*.pm" 2>/dev/null | head -10 || true