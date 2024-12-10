package RfamWeb::Controller::Accession;

use Moose;
use namespace::autoclean;

BEGIN {
  extends 'Catalyst::Controller';
}

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

  my $seq_start = $c->request->query_parameters->{seq_start};
  unless ( defined $seq_start && $seq_start =~ /^\d+$/ ) {
    $c->log->debug( 'Sequence summary: invalid seq_start found' )
      if $c->debug;
    $c->stash->{errorMsg} = 'Invalid or missing sequence start';
    return;
  }

  my $seq_end = $c->request->query_parameters->{seq_end};
  unless ( defined $seq_end && $seq_end =~ /^\d+$/ ) {
    $c->log->debug( 'Sequence summary: no seq_end found' )
      if $c->debug;
    $c->stash->{errorMsg} = 'Invalid or missing sequence end';
    return;
  }

  $c->stash->{entry} = $entry;
  $c->stash->{seq_start} = $seq_start;
  $c->stash->{seq_end} = $seq_end;
  $c->stash->{pageType} = 'accession';
  $c->stash->{template} = 'pages/tabless-layout.tt';
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
