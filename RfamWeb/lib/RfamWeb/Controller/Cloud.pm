
package RfamWeb::Controller::Cloud;

use Moose;
use namespace::autoclean;

BEGIN {
  extends 'Catalyst::Controller';
}

sub covid : Chained( '/' )
          PathPart( 'cloud' )
          Args( 0 ) {
  my ( $this, $c ) = @_;

  $c->log->debug('RfamWeb::Root::cloud: status message') if $c->debug;

  $c->stash->{template} = 'pages/cloud.tt';
}


1;
