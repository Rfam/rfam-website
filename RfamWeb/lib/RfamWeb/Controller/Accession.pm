package RfamWeb::Controller::Accession;

use Moose;
use namespace::autoclean;

BEGIN {
  extends 'Catalyst::Controller';
}

with 'PfamBase::Roles::Section';

# set the name of the section
__PACKAGE__->config( SECTION => 'accession' );

#-------------------------------------------------------------------------------

=head1 METHODS

=head2 rna


=cut

sub accession : Chained( '/' )
          PathPart( 'accession' )
          CaptureArgs( 1 ) {
  my ( $this, $c, $tainted_entry ) = @_;

  my ( $entry ) = $tainted_entry =~ m/^([A-Za-z0-9\.]+)$/;
  unless ( defined $entry ) {
    $c->log->debug( 'Sequence summary: no valid accession found' )
      if $c->debug;

    $c->stash->{errorMsg} = 'No valid accession';

    return;
  }

  $c->stash->{entry} = $entry;
  $c->stash->{pageType} = 'accession';
  $c->stash->{template} = 'pages/layout.tt';
}

#-------------------------------------------------------------------------------

=head2 rna_page


=cut

sub accession_page : Chained( 'accession' )
                  PathPart( '' )
                  Args( 0 ) {
  my ( $this, $c ) = @_;

  $c->cache_page( 604800 );
}
