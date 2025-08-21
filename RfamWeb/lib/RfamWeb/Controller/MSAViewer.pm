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
    
    # Generate the standalone HTML page
    my $html = $self->_generate_standalone_html($c, $endpoint, $identifier);
    
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
        }
        
        msa-viewer {
            display: block;
            width: 100%;
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
        
        .info {
            font-size: 12px;
            color: #666;
            margin-bottom: 10px;
        }
        
        /* Ensure proper sizing for the component */
        .msa-container {
            width: 100%;
            min-height: 300px;
        }
    </style>
</head>
<body>
    <div class="info">Loading alignment for family: $identifier</div>
    <div id="loading" class="loading">Loading MSA viewer...</div>
    <div id="error" class="error" style="display: none;"></div>
    
    <div class="msa-container">
        <msa-viewer id="msaViewer" style="display: none;"></msa-viewer>
    </div>

    <script type="module">
        // Configuration
        const endpoint = '$endpoint';
        const identifier = '$identifier';
        
        const loadingDiv = document.getElementById('loading');
        const errorDiv = document.getElementById('error');
        const msaViewer = document.getElementById('msaViewer');
        
        console.log('MSA Viewer Standalone - Starting load for:', identifier);
        
        try {
            // Wait for component to be defined
            await customElements.whenDefined('msa-viewer');
            console.log('✓ MSA Viewer component loaded in iframe');
            
            // Set attributes for the component
            msaViewer.setAttribute('api-endpoint', endpoint);
            msaViewer.setAttribute('identifier', identifier);
            msaViewer.setAttribute('height', '300');
            msaViewer.setAttribute('width', '100%');
            msaViewer.setAttribute('label-width', '300');
            
            // Wait for data to load with timeout
            let attempts = 0;
            const maxAttempts = 30; // 15 seconds timeout
            
            const checkLoaded = setInterval(() => {
                attempts++;
                
                if (msaViewer._error) {
                    // Component reported an error
                    clearInterval(checkLoaded);
                    loadingDiv.style.display = 'none';
                    errorDiv.style.display = 'block';
                    errorDiv.innerHTML = `Failed to load alignment data: \${msaViewer._error}`;
                    console.error('MSA Viewer error:', msaViewer._error);
                    
                } else if (msaViewer._data && msaViewer._data.sequences) {
                    // Data loaded successfully
                    clearInterval(checkLoaded);
                    loadingDiv.style.display = 'none';
                    msaViewer.style.display = 'block';
                    
                    const sequenceCount = msaViewer._data.sequences.length;
                    console.log(`✓ Iframe MSA viewer loaded: \${sequenceCount} sequences`);
                    
                    // Set up event logging to verify drag functionality
                    setTimeout(() => {
                        const manager = msaViewer.querySelector('nightingale-manager');
                        const navTrack = msaViewer.querySelector('nightingale-navigation');
                        
                        if (manager && navTrack) {
                            let changeCount = 0;
                            
                            // Listen for navigation changes
                            navTrack.addEventListener('change', (e) => {
                                changeCount++;
                                console.log(`Iframe navigation change \${changeCount}:`, e.detail);
                            });
                            
                            // Listen for manager changes
                            manager.addEventListener('change', (e) => {
                                console.log('Iframe manager change:', e.detail);
                            });
                            
                            console.log('✓ Iframe MSA viewer ready - drag functionality should work!');
                            console.log('Sequences:', sequenceCount, 'Length:', msaViewer._sequenceLength);
                            
                            // Log initial state for comparison
                            console.log('Initial state:', {
                                navStart: navTrack.getAttribute('display-start'),
                                navEnd: navTrack.getAttribute('display-end'),
                                managerStart: manager.getAttribute('display-start'),
                                managerEnd: manager.getAttribute('display-end')
                            });
                        } else {
                            console.warn('Navigation track or manager not found');
                        }
                    }, 1000);
                    
                } else if (attempts > maxAttempts) {
                    // Timeout
                    clearInterval(checkLoaded);
                    loadingDiv.style.display = 'none';
                    errorDiv.style.display = 'block';
                    errorDiv.innerHTML = `
                        <div>Failed to load MSA data within timeout period.</div>
                        <div style="font-size: 12px; margin-top: 10px;">
                            Endpoint: \${endpoint}<br>
                            Identifier: \${identifier}
                        </div>
                    `;
                    console.error('MSA Viewer timeout after', attempts, 'attempts');
                }
            }, 500);
            
        } catch (error) {
            loadingDiv.style.display = 'none';
            errorDiv.style.display = 'block';
            errorDiv.innerHTML = `<div>Error initializing MSA viewer</div><div style="font-size: 12px; margin-top: 10px;">\${error.message}</div>`;
            console.error('Iframe MSA viewer initialization error:', error);
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