
package RfamWeb::Controller::Microrna;

use Moose;
use namespace::autoclean;

BEGIN {
  extends 'Catalyst::Controller';
}

sub covid : Chained( '/' )
          PathPart( 'microrna' )
          Args( 0 ) {
  my ( $this, $c ) = @_;

  $c->log->debug('RfamWeb::Root::microRNA: status message') if $c->debug;

  $c->stash->{template} = 'pages/microrna.tt';
}


1;
