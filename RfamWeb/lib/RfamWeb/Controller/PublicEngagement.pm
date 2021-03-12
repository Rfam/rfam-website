
package RfamWeb::Controller::PublicEngagement;

use Moose;
use namespace::autoclean;

BEGIN {
  extends 'Catalyst::Controller';
}

sub covid : Chained( '/' )
          PathPart( 'genome-explorers' )
          Args( 0 ) {
  my ( $this, $c ) = @_;

  $c->log->debug('RfamWeb::Root::genome-explorers: status message') if $c->debug;

  $c->stash->{template} = 'pages/genome-explorers.tt';
}


1;
