package RfamWeb::Controller::Proxy;

use LWP::Simple;
use Moose;
use namespace::autoclean;

$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;

BEGIN {
  extends 'Catalyst::Controller::REST';
}

# set the name of the section
__PACKAGE__->config( SECTION => 'ebeye_proxy' );

#-------------------------------------------------------------------------------

sub ebeye_proxy : Chained( '/' )
             PathPart( 'ebeye_proxy' )
             CaptureArgs( 0 ) {
  my ( $this, $c ) = @_;

  $c->log->debug( 'Proxy::ebeye_proxy: start of chain' )
    if $c->debug;
}

#-------------------------------------------------------------------------------

=head2

Retrieve data from the URL and pass the response back.
This allows to avoid cross-origin restrictions in front-end code.

=cut

sub proxy : Chained( 'ebeye_proxy' )
                  PathPart( '' )
                  Args( 0 ) {
  my ( $this, $c ) = @_;

  $c->log->debug( 'Proxy::ebeye_proxy: end of chain;' )
    if $c->debug;

  my $data;
  my $url = $c->request->query_parameters->{url};

  if (defined $url) {
    my $uri = URI->new($url);
    my $host = $uri->host;

    if ($host && ($host =~ /\.?rfam\.org$/ || $host =~ /\.?ebi\.ac\.uk$/)) {
      my $browser = LWP::UserAgent->new;
      my $response = $browser->get($url);
      if ($response->is_success) {
        $data = $response->content;
      } else {
        $data = $response->status_line;
      }
    } else {
      $c->log->debug("Disallowed domain: " . ($host // 'undefined')) if $c->debug;
      $data = 'Disallowed domain';
    }
  } else {
    $data = 'URL not found';
  }

  $c->res->body($data);
}

#-------------------------------------------------------------------------------

1;
