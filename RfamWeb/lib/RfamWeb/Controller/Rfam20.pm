package RfamWeb::Controller::Rfam20;

use Moose;
use namespace::autoclean;

BEGIN {
  extends 'Catalyst::Controller';
}

sub covid : Chained( '/' )
          PathPart( 'rfam20' )
          Args( 0 ) {
  my ( $this, $c ) = @_;

  $c->log->debug('RfamWeb::Root::rfam20: status message') if $c->debug;

  $c->stash->{template} = 'pages/rfam20.tt';
}


1;
