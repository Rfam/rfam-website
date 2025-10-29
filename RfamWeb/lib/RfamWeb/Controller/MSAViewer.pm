package RfamWeb::Controller::MSAViewer;

use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

RfamWeb::Controller::MSAViewer - Controller for standalone MSA viewer

=head1 DESCRIPTION

Provides a standalone MSA viewer page for iframe embedding.
This controller serves a clean HTML page with the MSA viewer component
isolated from the main site's CSS and JavaScript.

=cut

=head2 standalone

Serves the standalone MSA viewer page for iframe embedding.
Parameters:
- endpoint: API endpoint URL for MSA data
- identifier: Family identifier (e.g., RF03072)

=cut

sub standalone : Path('/msa_viewer_standalone') : Args(0) {
    my ( $self, $c ) = @_;
    
    # Get parameters from query string
    my $endpoint = $c->request->param('endpoint');
    my $identifier = $c->request->param('identifier');
    
    # Basic validation
    unless ($endpoint && $identifier) {
        $c->response->status(400);
        $c->response->body('Missing required parameters: endpoint and identifier');
        return;
    }
    
    # Sanitize parameters to prevent XSS
    $endpoint =~ s/[<>"']//g;
    $identifier =~ s/[<>"']//g;
    
    # Set content type
    $c->response->content_type('text/html; charset=utf-8');
    
    # Generate the standalone HTML page DIRECTLY (no template)
    my $html = $self->_generate_standalone_html($c, $endpoint, $identifier);
    
    # Set response body directly - bypasses all template processing
    $c->response->body($html);
}

=head2 _generate_standalone_html

Private method to generate the standalone MSA viewer HTML page.

=cut

sub _generate_standalone_html {
    my ($self, $c, $endpoint, $identifier) = @_;
    
    # Get the base URI for static assets
    my $static_base = $c->uri_for('/static');
    
    return qq{<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MSA Alignment Viewer - $identifier</title>
    <script type="module" src="${static_base}/javascripts/msa-viewer/index.js"></script>
    <style>
        body {
            margin: 0;
            padding: 10px;
            font-family: Arial, sans-serif;
            background: white;
            font-size: 14px;
            overflow: hidden;
            width: 1380px;
            height: 580px;
        }
        
        msa-viewer {
            display: block;
            width: 1350px;
            height: 550px;
        }
        
        .loading {
            text-align: center;
            padding: 20px;
            color: #666;
        }
        
        .error {
            text-align: center;
            padding: 20px;
            color: #d32f2f;
            background: #ffebee;
            border: 1px solid #ffcdd2;
            border-radius: 4px;
            margin: 10px 0;
        }
        
        .msa-container {
            width: 100%;
            min-height: 300px;
        }
    </style>
</head>
<body>
    <div id="loading" class="loading">Loading MSA viewer...</div>
    <div id="error" class="error" style="display: none;"></div>
    
    <div class="msa-container">
        <msa-viewer id="msaViewer" style="display: none;"></msa-viewer>
    </div>

    <script type="module">
        const endpoint = '$endpoint';
        const identifier = '$identifier';
        
        const loadingDiv = document.getElementById('loading');
        const errorDiv = document.getElementById('error');
        const msaViewer = document.getElementById('msaViewer');
        
        try {
            await customElements.whenDefined('msa-viewer');
            
            msaViewer.setAttribute('api-endpoint', endpoint);
            msaViewer.setAttribute('identifier', identifier);
            msaViewer.setAttribute('height', '550');
            msaViewer.setAttribute('width', '1200');
            msaViewer.setAttribute('label-width', '300');
            
            let attempts = 0;
            const maxAttempts = 30;
            
            const checkLoaded = setInterval(() => {
                attempts++;
                
                if (msaViewer._error) {
                    clearInterval(checkLoaded);
                    loadingDiv.style.display = 'none';
                    errorDiv.style.display = 'block';
                    errorDiv.innerHTML = \`Failed to load alignment data: \${msaViewer._error}\`;
                    
                } else if (msaViewer._data && msaViewer._data.sequences) {
                    clearInterval(checkLoaded);
                    loadingDiv.style.display = 'none';
                    msaViewer.style.display = 'block';
                    
                } else if (attempts > maxAttempts) {
                    clearInterval(checkLoaded);
                    loadingDiv.style.display = 'none';
                    errorDiv.style.display = 'block';
                    errorDiv.innerHTML = \`Failed to load MSA data within timeout period.\`;
                }
            }, 500);
            
        } catch (error) {
            loadingDiv.style.display = 'none';
            errorDiv.style.display = 'block';
            errorDiv.innerHTML = \`Error initializing MSA viewer: \${error.message}\`;
        }
    </script>
</body>
</html>};
}

=head1 AUTHOR

Generated for RfamWeb MSA viewer iframe integration

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;