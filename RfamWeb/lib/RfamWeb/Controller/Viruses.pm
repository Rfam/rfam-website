package RfamWeb::Controller::Viruses;

use Moose;
use namespace::autoclean;

BEGIN {
  extends 'Catalyst::Controller';
}

sub covid : Chained( '/' )
          PathPart( 'viruses' )
          Args( 0 ) {
  my ( $this, $c ) = @_;

  $c->log->debug('RfamWeb::Root::viruses: status message') if $c->debug;

  $c->stash->{template} = 'pages/viruses.tt';
}

sub hcv : Chained( '/' )
        PathPart( 'viruses/hcv' )
        Args( 0 ) {
  my ( $this, $c ) = @_;

  $c->log->debug('RfamWeb::Viruses::hcv: redirecting to viruses page') if $c->debug;

  # Redirect to the general viruses page with a 301 (permanent redirect)
  $c->response->redirect( $c->uri_for('/viruses'), 301 );
}


1;