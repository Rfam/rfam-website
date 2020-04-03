
package RfamWeb::Controller::Covid;

use Moose;
use namespace::autoclean;

BEGIN {
  extends 'Catalyst::Controller';
}

# __PACKAGE__->config( namespace => 'covid-19' );

sub covid : Chained( '/' )
          PathPart( 'covid-19' )
          Args( 0 ) {
  my ( $this, $c ) = @_;

  $c->log->debug('RfamWeb::Root::covid: status message') if $c->debug;

  $c->stash->{template} = 'pages/covid-19.tt';
}


1;
