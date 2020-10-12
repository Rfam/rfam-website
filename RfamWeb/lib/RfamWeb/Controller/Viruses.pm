
package RfamWeb::Controller::Viruses;

use Moose;
use namespace::autoclean;

BEGIN {
  extends 'Catalyst::Controller';
}

# __PACKAGE__->config( namespace => 'covid-19' );

sub covid : Chained( '/' )
          PathPart( 'viruses' )
          Args( 0 ) {
  my ( $this, $c ) = @_;

  $c->log->debug('RfamWeb::Root::viruses: status message') if $c->debug;

  $c->stash->{template} = 'pages/viruses.tt';
}


1;
