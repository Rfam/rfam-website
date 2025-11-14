package RfamWeb::Controller::Alignments;

use Moose;
use namespace::autoclean;
use LWP::UserAgent;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

RfamWeb::Controller::Alignments - Alignments API Proxy Controller

=head1 DESCRIPTION

Controller for proxying requests to the external alignments API

=cut

=head2 index

Default action for /alignments - shows usage information

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    
    # Force logging regardless of debug level
    $c->log->warn("ALIGNMENTS INDEX ACTION CALLED");
    $c->log->warn("Request URI: " . $c->request->uri);
    $c->log->warn("Host header: " . ($c->request->header('Host') || 'NONE'));
    
    $c->response->content_type('text/plain');
    $c->response->body('Alignments API Proxy - Usage: /alignments/RF03116');
}

=head2 family

Proxy requests to the alignments API for a specific family

=cut

sub family :Path :Args(1) {
    my ( $self, $c, $family_id ) = @_;

    # Force logging regardless of debug level
    $c->log->warn("ALIGNMENTS FAMILY ACTION CALLED WITH ID: " . ($family_id || 'UNDEFINED'));
    $c->log->warn("Request URI: " . $c->request->uri);
    $c->log->warn("Host header: " . ($c->request->header('Host') || 'NONE'));
    $c->log->warn("Request method: " . $c->request->method);
    
    # Only support GET requests
    unless ( $c->request->method eq 'GET' ) {
        $c->log->warn("ALIGNMENTS: Method not allowed: " . $c->request->method);
        $c->response->status(405);
        $c->response->content_type('text/plain');
        $c->response->body('Method Not Allowed - Only GET requests supported');
        return;
    }
    
    # For testing - use httpbin.org to verify proxy works
    if ($family_id eq 'test') {
        $c->log->warn("ALIGNMENTS: Running test mode");
        eval {
            my $api_url = 'https://httpbin.org/json';
            my $ua = LWP::UserAgent->new(timeout => 30);
            my $response = $ua->get($api_url);
            
            $c->response->status($response->code);
            $c->response->content_type($response->header('Content-Type') || 'text/plain');
            $c->response->body($response->content);
        };
        if ($@) {
            $c->log->error("ALIGNMENTS: Test error: $@");
            $c->response->status(500);
            $c->response->content_type('text/plain');
            $c->response->body("Error in test: $@");
        }
        return;
    }
    
    # Wrap everything in eval to catch errors
    eval {
        # Determine API URL based on deployment
        my $api_url;
        my $host = $c->request->header('Host') || '';
        my $server_name = $c->engine->env->{SERVER_NAME} || '';
        
        $c->log->warn("ALIGNMENTS: Host='$host', ServerName='$server_name'");
        
        if ($host =~ /preview\.rfam\.org/)  {
            # Preview site (always on prod cluster but different port)
            $api_url = 'http://hh-rke-wp-webadmin-82-worker-2.caas.ebi.ac.uk:30082/' . $family_id;
            $c->log->warn("ALIGNMENTS: Matched preview, using worker-2:30082");
        } elsif ($server_name =~ /hx-rke-wp-webadmin-91-/) {
            # Fallback cluster
            $api_url = 'http://hx-rke-wp-webadmin-91-worker-3.caas.ebi.ac.uk:30081/' . $family_id;
            $c->log->warn("ALIGNMENTS: Matched fallback cluster, using worker-3:30081");
        } else {
            # Default for prod cluster (hh-rke-wp-webadmin-82-worker-*)
            $api_url = 'http://hh-rke-wp-webadmin-82-worker-3.caas.ebi.ac.uk:30081/' . $family_id;
            $c->log->warn("ALIGNMENTS: Using default prod, worker-3:30081");
        }
        
        # Add query parameters if present
        if (my $query = $c->request->uri->query) {
            $api_url .= "?$query";
            $c->log->warn("ALIGNMENTS: Added query params: $query");
        }
        
        $c->log->warn("ALIGNMENTS: Final API URL: $api_url");
        
        # Add debug headers
        $c->response->header('X-API-URL' => $api_url);
        $c->response->header('X-Server-Name' => $server_name);
        $c->response->header('X-Family-ID' => $family_id);
        
        # Make API request
        $c->log->warn("ALIGNMENTS: Making request to API...");
        my $ua = LWP::UserAgent->new(timeout => 30);
        my $response = $ua->get($api_url);
        
        $c->log->warn("ALIGNMENTS: API responded with status: " . $response->code);
        
        # Add debug information
        $c->response->header('X-API-Status' => $response->code);
        $c->response->header('X-API-Success' => $response->is_success ? 'true' : 'false');
        
        # Forward the response
        $c->response->status($response->code);
        $c->response->content_type($response->header('Content-Type') || 'text/plain');
        $c->response->body($response->content);
        
        $c->log->warn("ALIGNMENTS: Response forwarded to client");
    };
    
    if ($@) {
        $c->log->error("ALIGNMENTS: Controller Error: $@");
        $c->response->status(500);
        $c->response->content_type('text/plain');
        $c->response->body("Controller Error: $@");
    }
}

=head2 end

Override end method to prevent template processing

=cut

sub end : Private {
    my ( $self, $c ) = @_;
    $c->log->warn("ALIGNMENTS: end action called");
    # Do nothing - we handle our own responses
}

__PACKAGE__->meta->make_immutable;

1;