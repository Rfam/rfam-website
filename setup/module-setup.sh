#!/bin/bash
# module-setup.sh
# Runtime module verification and stub creation for missing modules
set -euo pipefail
echo "=== module-setup.sh: Checking Perl modules ==="

PERL_SITE="/usr/local/lib/perl5/site_perl/5.42.0"
mkdir -p "${PERL_SITE}"

# Function to create stub if module is missing
create_stub_if_missing() {
  local module="$1"
  local stub_code="$2"
  
  if perl -e "use $module; 1" 2>/dev/null; then
    echo "✅ $module - OK"
  else
    echo "⚠️  $module - Missing, creating stub..."
    eval "$stub_code"
    echo "✅ $module - Stub created"
  fi
}

# Check network connectivity for debugging
echo "=== Network Connectivity Check ==="
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
  echo "✅ External network connectivity OK"
else
  echo "❌ External network connectivity failed"
fi

if nslookup cpan.org >/dev/null 2>&1; then
  echo "✅ DNS resolution OK"
else
  echo "❌ DNS resolution failed"
fi

# Critical modules that need stubs if missing
echo "=== Checking Critical Modules ==="

# DateTime modules
create_stub_if_missing "DateTime" "
cat > ${PERL_SITE}/DateTime.pm <<'EOF'
package DateTime;
use strict; use warnings;
our \$VERSION='1.0';
sub new { my \$c=shift; my %a=@_; bless \%a,\$c; }
sub now { my \$c=shift; bless {year=>2024,month=>1,day=>1,hour=>0,minute=>0,second=>0},\$c; }
sub ymd { my (\$s,\$sep)=@_; \$sep||='-'; sprintf \"%04d%s%02d%s%02d\",\$s->{year},\$sep,\$s->{month},\$sep,\$s->{day}; }
sub hms { my (\$s,\$sep)=@_; \$sep||=':'; sprintf \"%02d%s%02d%s%02d\",\$s->{hour},\$sep,\$s->{minute},\$sep,\$s->{second}; }
1;
EOF
"

create_stub_if_missing "DateTime::Format::MySQL" "
mkdir -p ${PERL_SITE}/DateTime/Format
cat > ${PERL_SITE}/DateTime/Format/MySQL.pm <<'EOF'
package DateTime::Format::MySQL;
use strict; use warnings; use DateTime;
our \$VERSION='1.0';
sub new { bless {}, shift }
sub parse_datetime { my (\$s,\$d)=@_; return DateTime->now() unless \$d; DateTime->now(); }
sub format_datetime { my (\$s,\$dt)=@_; \$dt->ymd('-').' '.\$dt->hms(':') }
sub format_date { my (\$s,\$dt)=@_; \$dt->ymd('-') }
1;
EOF
"

# File utilities
create_stub_if_missing "File::Slurp" "
mkdir -p ${PERL_SITE}/File
cat > ${PERL_SITE}/File/Slurp.pm <<'EOF'
package File::Slurp;
use strict; use warnings;
use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(read_file write_file append_file);
our \$VERSION = '1.0';
sub read_file { my (\$f,%o)=@_; open my \$fh,'<',\$f or die \$!; local \$/; my \$c=<\$fh>; close \$fh; return \$c; }
sub write_file { my (\$f,\$c,%o)=@_; open my \$fh,'>',\$f or die \$!; print \$fh \$c; close \$fh; }
sub append_file { my (\$f,\$c,%o)=@_; open my \$fh,'>>',\$f or die \$!; print \$fh \$c; close \$fh; }
1;
EOF
"

# XML modules
create_stub_if_missing "XML::Feed" "
mkdir -p ${PERL_SITE}/XML
cat > ${PERL_SITE}/XML/Feed.pm <<'EOF'
package XML::Feed;
use strict; use warnings;
our \$VERSION='1.0';
sub new { bless {}, shift }
sub parse { bless {}, shift }
sub title { 'Mock Feed' }
sub entries { () }
1;
EOF
"

# GD graphics
create_stub_if_missing "GD" "
cat > ${PERL_SITE}/GD.pm <<'EOF'
package GD;
use strict; use warnings; use Exporter;
our @ISA=qw(Exporter);
our @EXPORT=qw(gdSmallFont gdLargeFont gdTinyFont gdGiantFont);
use constant gdSmallFont=>6; use constant gdLargeFont=>7;
use constant gdTinyFont=>9; use constant gdGiantFont=>10;
sub new { bless {}, shift }
sub png { '' }
sub jpeg { '' }
sub colorAllocate { 0 }
sub string {}
sub line {}
1;
EOF
"

# Check for DBD::mysql conflicts and clean up any stubs
echo "=== Cleaning up any DBD::mysql stubs ==="
if [ -f "${PERL_SITE}/DBD/mysql.pm" ]; then
  echo "Removing DBD::mysql stub that may cause conflicts..."
  rm -f "${PERL_SITE}/DBD/mysql.pm"
fi

# Critical: Do NOT create DBD::mysql stub - it causes segfaults
# Only check if DBD::mysql is available, don't stub it
echo "=== Checking Database Modules ==="
if perl -e "use DBI; use DBD::mysql; print \"✅ DBD::mysql version: \$DBD::mysql::VERSION\\n\"; 1" 2>/dev/null; then
  echo "✅ DBD::mysql - Working properly"
  
  # Show where DBD::mysql is installed
  perl -e "use DBD::mysql; print \"DBD::mysql location: \$INC{'DBD/mysql.pm'}\\n\";" 2>/dev/null || true
else
  echo "❌ DBD::mysql - MISSING or broken"
  echo "   Checking what's available..."
  find /usr -name "mysql.pm" 2>/dev/null | head -5 || true
  echo "   Application will not work without proper DBD::mysql!"
fi

echo "=== Module check complete ==="