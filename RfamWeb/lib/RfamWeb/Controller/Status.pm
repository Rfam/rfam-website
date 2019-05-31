
package RfamWeb::Controller::Status;

use Moose;
use namespace::autoclean;

BEGIN {
  extends 'Catalyst::Controller';
}


sub status : Chained( '/' )
          PathPart( 'status' )
          Args( 0 ) {
  my ( $this, $c ) = @_;

  $c->log->debug('RfamWeb::Root::status: status message') if $c->debug;

  # see if we can get a DB ResultSet from the VERSION table, which is
  # effectively a test of whether we can connect to the DB.

  eval {
    my $releaseData;
    $releaseData = $c->model('RfamDB::Version')
                     ->find( {} );
  };
  if ( $@ ) {
    $c->stash->{status} = "Error";
  } else {
    $c->stash->{status} = "All systems operational";
  }

  $c->stash->{template} = 'pages/status.tt';
}


1;
