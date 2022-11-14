package RfamWeb::Controller::3d;

use Moose;
use namespace::autoclean;

BEGIN {
  extends 'Catalyst::Controller';
}

sub covid : Chained( '/' )
          PathPart( '3d' )
          Args( 0 ) {
  my ( $this, $c ) = @_;

  $c->log->debug('RfamWeb::Root::3d: status message') if $c->debug;

  $c->stash->{template} = 'pages/3d.tt';
}


1;
