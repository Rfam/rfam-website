/**
 * Rfam text search Angular app.
 */

; // concatenation safeguard

/**
 * Make it possible to include underscore as a dependency.
 */
var underscore = angular.module('underscore', []);
underscore.factory('_', function() {
    return window._;
});

/**
 * Create Rfam app.
 */
angular.module('rfamApp', ['chieffancypants.loadingBar', 'underscore']);

// hide spinning wheel
angular.module('rfamApp').config(['cfpLoadingBarProvider', function(cfpLoadingBarProvider) {
    cfpLoadingBarProvider.includeSpinner = false;
}]);

/**
 * Turn on html5mode only in modern browsers because
 * in the older ones html5mode rewrites urls with Hangbangs
 * which break normal Django pages.
 * With html5mode off IE lt 10 will be able to navigate the site
 * but won't be able to open deep links to Angular pages
 * (for example, a link to a search result won't load in IE 9).
 */
angular.module('rfamApp').config(['$locationProvider', function($locationProvider) {
    if (window.history && window.history.pushState) {
        $locationProvider.html5Mode(true);
    }
}]);

/**
 * Service for launching a text search.
 */
angular.module('rfamApp').service('search', ['$location', function($location) {

    /**
     * To launch a new search, change browser url,
     * which will automatically trigger a new search
     * since the url changes are watched in the query controller.
     */
    this.meta_search = function(query) {
        $location.url('/search' + '?q=' + query);
    };

}]);

/**
 * Service for passing data between controllers.
 */
angular.module('rfamApp').service('results', ['_', '$http', '$location', '$window', function(_, $http, $location, $window) {

    /**
     * Service initialization.
     */
    var result = {
        hitCount: null,
        entries: [],
        facets: [],
        _query: null, // query after preprocessing
    };

    var status = {
        display_search_interface: false, // hide results section at first
        search_in_progress: false, // display spinning wheel while searching
        show_error: false, // display error message
    };

    var search_config = {
        ebeye_base_url: global_settings.EBI_SEARCH_ENDPOINT + '/ebisearch/ws/rest/rfam',
        fields: [
            'assembly_name',
            'common_name',
            'chromosome_name',
            'description',
            'entry_type',
            'length',
            'name',
            'num_3d_structures',
            'num_families',
            'num_full',
            'num_rfam_hits',
            'num_seed',
            'num_species',
            'rna_type',
            'scientific_name',
            'tax_string',
            'alignment_type',
            'evalue_score',
            'bit_score',
            'truncated',
            'seq_start',
            'seq_end',
            'rfamseq_acc',
        ],
        facetfields: [
            'entry_type',
            'rna_type',
            'TAXONOMY',
            'popular_species',
            'has_3d_structure',
            'author',
            'has_pseudoknot',
            'pseudoknot_evidence',
            'alignment_type',
        ], // will be displayed in this order
        facetcount: 30,
        pagesize: 15,
        ordering: 'num_seed:descending,num_families:descending,bit_score:descending',
    };

    var query_urls = {
        'ebeye_search': search_config.ebeye_base_url +
                        '?query={QUERY}' +
                        '&format=json' +
                        '&hlfields=' + search_config.fields.join() +
                        '&hlpretag=<span class="text-search-highlights">&hlposttag=</span>' +
                        '&facetcount=' + search_config.facetcount +
                        '&facetfields=' + search_config.facetfields.join() +
                        '&size=' + search_config.pagesize +
                        '&start={START}' +
                        '&sort={ORDERING}',
        'proxy': '/ebeye_proxy?url={EBEYE_URL}',
    };

    /**
     * Calculate base url for production and development environments.
     */
    function get_base_url() {
        var base_url = $location.protocol() + '://' + $location.host();
        var port = $location.port();
        if (port !== '') {
            base_url += ':' + port;
        }
        return base_url;
    }

    /**
     * Launch EBeye search.
     * `start` determines the range of the results to be returned.
     */
    this.search = function(query, start, ordering) {
        start = start || 0;
        ordering = ordering || search_config.ordering;

        display_search_interface();
        display_spinner();
        update_page_title();

        query = preprocess_query(query);
        query_url = get_query_url(query, start);
        execute_ebeye_search(query_url, start === 0);

        /**
         * Display search spinner if not a "load more" request.
         */
        function display_spinner() {
            if (start === 0) {
                result.hitCount = null; // display spinner
            }
        }

        /**
         * Change page title, which is also used in browser tabs.
         */
        function update_page_title() {
            $window.document.title = 'Search: ' + query;
        }

        /**
         * Setting `display_search_interface` value to true hides all non-search page content
         * and begins displaying search results interface.
         */
        function display_search_interface() {
            status.display_search_interface = true;
        }

        /**
         * Create an EBeye query url.
         */
        function get_query_url() {
            var ebeye_url = query_urls.ebeye_search.replace('{QUERY}', query).replace('{START}', start).replace('{ORDERING}', ordering);
            var url = query_urls.proxy.replace('{EBEYE_URL}', encodeURIComponent(ebeye_url));
            return url;
        }

        /**
         * Split query into words and then:
         *  - append wildcards to all terms without double quotes and not ending with wildcards
         *  - escape special symbols
         *  - capitalize logical operators
         *
         *  Splitting into words is based on this SO question:
         *  http://stackoverflow.com/questions/366202/regex-for-splitting-a-string-using-space-when-not-surrounded-by-single-or-double
         * Each "word" is a sequence of characters that aren't spaces or quotes,
         * or a sequence of characters that begin and end with a quote, with no quotes in between.
         */
        function preprocess_query(query) {

            apply_species_specific_filtering();

            // replace length query with a placeholder, example: length:[100 TO 200]
            var length_clause = query.match(/length\:\[\d+\s+to\s+\d+\]/i);
            var placeholder = 'length_clause';
            if (length_clause) {
              query = query.replace(length_clause[0], placeholder);
              length_clause[0] = length_clause[0].replace(/to/i, 'TO');
            }

            var words = query.match(/[^\s"]+|"[^"]*"/g);
            var array_length = words.length;
            for (var i = 0; i < array_length; i++) {
                if ( words[i].match(/^(and|or|not)$/gi) ) {
                    // capitalize logical operators
                    words[i] = words[i].toUpperCase();
                } else if ( words[i].match(/\:$/gi) ) {
                    // faceted search term + a colon, e.g. expert_db:
                    var term = words[i].replace(':','');
                    var xrefs = ['pubmed', 'doi', 'taxonomy'];
                    if ( term.match(new RegExp('^(' + xrefs.join('|') + ')$', 'i') ) ) {
                        // xref fields must be capitalized
                        term = term.toUpperCase();
                    }
                    words[i] = term + ':';
                } else if ( words[i].match(/\//)) {
                    // do not add wildcards to DOIs
                    words[i] = escape_search_term(words[i]);
                } else if ( words[i].match(/^".+?"$/) ) {
                    // double quotes, do nothing
                } else if ( words[i].match(/\*$/) ) {
                    // wildcard, escape term
                    words[i] = escape_search_term(words[i]);
                } else if ( words[i].match(/\)$/) ) {
                    // right closing grouping parenthesis, don't add a wildcard
                } else if ( words[i].match(/(-|_)/) ) {
                    // term contains a hyphen or an underscore, don't add a wildcard
                } else if ( words[i].length < 3 ) {
                    // the word is too short for wildcards, do nothing
                } else {
                    // all other words
                    // escape term, add wildcard
                    words[i] = escape_search_term(words[i]) + '*';
                }
            }
            query = words.join(' ');
            query = query.replace(/\: /g, ':'); // to avoid spaces after faceted search terms
            // replace placeholder with the original search term
            if (length_clause) {
              query = query.replace(placeholder + '*', length_clause[0]);
            }
            result._query = query;
            return query;

            /**
             * If query contains URS/taxid or URS_taxid identifiers,
             * perform species-specific search and show species-specific links.
             */
            function apply_species_specific_filtering() {
                var urs_taxid_regexp = new RegExp('(URS[0-9A-F]{10})(\/|_)(\\d+)', 'i');
                match = query.match(urs_taxid_regexp);
                if (match) {
                    upi = match[1];
                    query = upi + ' taxonomy:"' + match[3] + '"';
                }
            }

            /**
             * Escape special symbols used by Lucene
             * Escaped: + - && || ! { } [ ] ^ ~ ? : \ /
             * Not escaped: * " ( ) because they may be used deliberately by the user
             */
            function escape_search_term(search_term) {
                return search_term.replace(/[\+\-&|!\{\}\[\]\^~\?\:\\\/]/g, "\\$&");
            }
        }

        /**
         * Execute remote request.
         */
        function execute_ebeye_search(url, overwrite_results) {
            status.search_in_progress = true;
            status.show_error = false;
            $http({
                url: url,
                method: 'GET'
            }).success(function(data) {
                data = preprocess_results(data);
                overwrite_results = overwrite_results || false;
                if (overwrite_results) {
                    data._query = result._query;
                    result = data; // replace
                } else {
                    // append new entries
                    result.entries = result.entries.concat(data.entries);
                }
                status.search_in_progress = false;
            }).error(function(){
                status.search_in_progress = false;
                status.show_error = true;
            });

            /**
             * Preprocess data received from the server.
             */
            function preprocess_results(data) {

                merge_species_facets();
                order_facets();
                rename_hlfields();
                return data;

                /**
                 * Use `hlfields` with highlighted matches instead of `fields`.
                 */
                function rename_hlfields() {
                    for (var i=0; i < data.entries.length; i++) {
                        data.entries[i].fields = data.entries[i].highlights;
                        data.entries[i].fields.entry_type[0] = data.entries[i].fields.entry_type[0].replace(/<[^>]+>/gm, '');
                        if (data.entries[i].fields.tax_string[0]) {
                          data.entries[i].fields.tax_string_array = data.entries[i].fields.tax_string[0].slice(0, -1).split('; ');
                        }
                    }
                }

                /**
                 * Order facets the same way as in the config.
                 */
                function order_facets() {
                    data.facets = _.sortBy(data.facets, function(facet){
                        return _.indexOf(search_config.facetfields, facet.id);
                    });
                }

                /**
                 * Merge the two species facets putting popular_species
                 * at the top of the list.
                 * Species facets:
                 * - TAXONOMY (all species)
                 * - popular_species (manually curated set of top organisms).
                 */
                function merge_species_facets() {

                    // find the popular species facet
                    var top_species_facet_id = find_facet_id('popular_species');

                    if (top_species_facet_id) {
                        // get top species names
                        var popular_species = _.pluck(data.facets[top_species_facet_id].facetValues, 'label');

                        // find the taxonomy facet
                        var taxonomy_facet_id = find_facet_id('TAXONOMY');

                        // extract other species from the taxonomy facet
                        var other_species = get_other_species();

                        // merge popular_species with other_species
                        data.facets[taxonomy_facet_id].facetValues = data.facets[top_species_facet_id].facetValues.concat(other_species);

                        // remove the Popular species facet
                        delete data.facets[top_species_facet_id];
                        data.facets = _.compact(data.facets);
                    }

                    /**
                     * Get Taxonomy facet values that are not also in popular_species.
                     */
                    function get_other_species() {
                        var taxonomy_facet = data.facets[taxonomy_facet_id].facetValues,
                            other_species = [];
                        for (var i=0; i<taxonomy_facet.length; i++) {
                            if (_.indexOf(popular_species, taxonomy_facet[i].label) === -1) {
                                other_species.push(taxonomy_facet[i]);
                            }
                        }
                        return other_species;
                    }

                    /**
                     * Find objects in array by attribute value.
                     * Given an array like:
                     * [{'id': 'a'}, {'id': 'b'}, {'id': 'c'}]
                     * find_facet_id('b') -> 1
                     */
                    function find_facet_id(facet_label) {
                        var index;
                        _.find(data.facets, function(facet, i){
                            if (facet.id === facet_label) {
                                index = i;
                                return true;
                            }
                        });
                        return index;
                    }
                }

            }
        }

    };

    /**
     * Load more results starting from the last loaded index.
     */
    this.load_more_results = function() {
        query = $location.search().q;
        this.search(query, result.entries.length);
    };

    /**
     * Broadcast whether search interface should be displayed.
     */
    this.get_status = function() {
        return status.display_search_interface;
    };

    /**
     * Broadcast search results changes.
     */
    this.get_result = function() {
        return result;
    };

    /**
     * Broadcast whether search is in progress.
     */
    this.get_search_in_progress = function() {
        return status.search_in_progress;
    };

    /**
     * Broadcast whether an error has occurred.
     */
    this.get_show_error = function() {
        return status.show_error;
    };

    /**
     * Repeat the query with a different ordering.
     */
    this.sort_results = function(ordering) {
        query = $location.search().q;
        search_config.ordering = ordering;
        this.search(query);
    };

}]);

angular.module('rfamApp').controller('MainContent', ['$scope', '$anchorScroll', '$location', 'results', 'search', function($scope, $anchorScroll, $location, results, search) {
    /**
     * Enables scrolling to anchor tags.
     * <a ng-click="scrollTo('anchor')">Title</a>
     */
    $scope.scrollTo = function(id) {
        $location.hash(id);
        $anchorScroll();
    };

    /**
     * Watch `display_search_interface` in order to hide non-search-related content
     * when a search is initiated.
     */
    $scope.$watch(function () { return results.get_status(); }, function (newValue, oldValue) {
        if (newValue !== null) {
            $scope.display_search_interface = newValue;
        }
    });

    /**
     * Launch a text search from a web page.
     */
    $scope.meta_search = function(query) {
        search.meta_search(query);
    };

}]);

/**
 * Results display controller
 * Responsible for visualising search results.
 */
angular.module('rfamApp').controller('ResultsListCtrl', ['$scope', '$location', '$http', 'results', function($scope, $location, $http, results) {

    $scope.result = {
        entries: [],
    };
    $scope.show_export_error = false;

    $scope.search_in_progress = results.get_search_in_progress();
    $scope.show_error = results.get_show_error();

    $scope.ordering = [
        // search_type = 'family'
        { type: 'family', sort_field: 'num_seed:descending', label: 'Number of seed alignment sequences \u2193'},
        { type: 'family', sort_field: 'num_seed', label: 'Number of seed alignment sequences \u2191'},
        { type: 'family', sort_field: 'num_full:descending', label: 'Number of full alignment sequences \u2193' },
        { type: 'family', sort_field: 'num_full', label: 'Number of full alignment sequences \u2191' },
        { type: 'family', sort_field: 'num_species:descending', label: 'Number of species \u2193'},
        { type: 'family', sort_field: 'num_species', label: 'Number of species \u2191'},
        { type: 'family', sort_field: 'id:descending', label: 'Rfam accession  \u2193'},
        { type: 'family', sort_field: 'id', label: 'Rfam accession  \u2191' },
        
        // search_type = 'genome'
        { type: 'genome', sort_field: 'num_families:descending', label: 'Number of families in genome  \u2193'},
        { type: 'genome', sort_field: 'num_families', label: 'Number of families in genome  \u2191'},
        { type: 'genome', sort_field: 'num_rfam_hits:descending', label: 'Number of RNAs in genome  \u2193'},
        { type: 'genome', sort_field: 'num_rfam_hits', label: 'Number of RNAs in genome  \u2191'},
        { type: 'genome', sort_field: 'length:descending', label: 'Genome length  \u2193'},
        { type: 'genome', sort_field: 'length', label: 'Genome length  \u2191' },
        
        // search_type = 'clan'
        { type: 'clan', sort_field: 'num_families:descending', label: 'Number of families in clan  \u2193'},
        { type: 'clan', sort_field: 'num_families', label: 'Number of families in clan  \u2191' },
        
        // search_type = 'motif'
        { type: 'motif', sort_field: 'num_families:descending', label: 'Number of families in motif  \u2193'},
        { type: 'motif', sort_field: 'num_families', label: 'Number of families in motif  \u2191' },
        
        // search_type = 'sequence'
        { type: 'sequence', sort_field: 'bit_score:descending', label: 'Bit score  \u2193'},
        { type: 'sequence', sort_field: 'bit_score', label: 'Bit score  \u2191'},
        { type: 'sequence', sort_field: 'evalue_score:descending', label: 'E-value score  \u2193'},
        { type: 'sequence', sort_field: 'evalue_score', label: 'E-value score  \u2191' },
        
        // search_type = 'all'
        { type: 'all', sort_field: 'id:descending', label: 'Accession  \u2193'},
        { type: 'all', sort_field: 'id', label: 'Accession  \u2191' },
        { type: 'all', sort_field: 'num_seed:descending', label: 'Number of seed alignment sequences  \u2193'},
        { type: 'all', sort_field: 'num_seed', label: 'Number of seed alignment sequences  \u2191' },
        { type: 'all', sort_field: 'num_rfam_hits:descending', label: 'Number of families in genome  \u2193'},
        { type: 'all', sort_field: 'num_rfam_hits', label: 'Number of families in genome  \u2191' },
        { type: 'all', sort_field: 'length:descending', label: 'Genome length  \u2193'},
        { type: 'all', sort_field: 'length', label: 'Genome length  \u2191' },
        { type: 'all', sort_field: 'num_3d_structures:descending', label: 'Number of 3d structures  \u2193'},
        { type: 'all', sort_field: 'num_3d_structures', label: 'Number of 3d structures  \u2191'},
        { type: 'all', sort_field: 'num_species:descending', label: 'Number of species  \u2193'},
        { type: 'all', sort_field: 'num_species', label: 'Number of species  \u2191'},
        { type: 'all', sort_field: 'num_full:descending', label: 'Number of full alignment sequences  \u2193'},
        { type: 'all', sort_field: 'num_full', label: 'Number of full alignment sequences  \u2191'},
        { type: 'all', sort_field: 'num_families:descending', label: 'Number of families in genome  \u2193'},
        { type: 'all', sort_field: 'num_families', label: 'Number of families in genome  \u2191'},
        { type: 'all', sort_field: 'bit_score:descending', label: 'Bit score  \u2193'},
        { type: 'all', sort_field: 'bit_score', label: 'Bit score  \u2191'},
        { type: 'all', sort_field: 'evalue_score:descending', label: 'E-value score  \u2193'},
        { type: 'all', sort_field: 'evalue_score', label: 'E-value score  \u2191'},
    ];
    $scope.params = {
        selectedOrdering: $scope.ordering[0],
    };
    $scope.search_type = '';

    /**
     * Set search type based on what facet is enabled.
     * The `search_type` is used to filter ordering options.
     */
    $scope.$watch(function () { return $location.search().q; }, function (newValue, oldValue) {
        var match = newValue.match(/entry_type\:["'](\w+)["']/);
        if (match) {
            $scope.search_type = match[1].toLowerCase();
        } else {
            $scope.search_type = 'all';
        }
        $scope.params.selectedOrdering = $scope.ordering.filter(function(element){
            return element.type == $scope.search_type;
        })[0];
    });

    /**
     * Detect When query looks like `UP000029965 AND entry_type:"Family"`.
     */
    $scope.show_family_genome_context = function() {
        if ($scope.get_genome_id_from_query()) {
            return true;
        } else {
            return false;
        }
    };

    /**
     * Extract genome id from query.
     */
     $scope.get_genome_id_from_query = function() {
         var query = $location.search().q,
             match = query.match(/(UP\d{9})\s+AND\s+entry_type:["']Family["']/i);
         if (match) {
             return match[1];
         } else {
             return false;
         }
     }

    /**
     * Update the `ordering` url parameter
     * based on the current user selection.
     */
    $scope.update_ordering = function() {
        results.sort_results($scope.params.selectedOrdering.sort_field);
    };

    /**
     * Watch `result` changes.
     */
    $scope.$watch(function () { return results.get_result(); }, function (newValue, oldValue) {
        if (newValue !== null) {
            $scope.result = newValue;
        }
    });

    /**
     * Watch `display_search_interface` changes.
     */
    $scope.$watch(function () { return results.get_status(); }, function (newValue, oldValue) {
        if (newValue !== null) {
            $scope.display_search_interface = newValue;
        }
    });

    /**
     * Watch `search_in_progress` changes.
     */
    $scope.$watch(function () { return results.get_search_in_progress(); }, function (newValue, oldValue) {
        if (newValue != oldValue) {
            $scope.search_in_progress = newValue;
        }
    });

    /**
     * Watch `show_error` changes.
     */
    $scope.$watch(function () { return results.get_show_error(); }, function (newValue, oldValue) {
        if (newValue != oldValue) {
            $scope.show_error = newValue;
        }
    });

    /**
     * Fired when "Load more" button is clicked.
     */
    $scope.load_more_results = function() {
        results.load_more_results();
    };

    /**
     * Detect if the accession is an RNAcentral id.
     */
    $scope.is_rnacentral = function(accession) {
        var urs_id = new RegExp(/URS[0-9A-F]{10}_\d+/, 'i');
        if (accession.match(urs_id)) {
            return true;
        } else {
            return false;
        }
    }

    /**
     * Determine if the facet has already been applied.
     */
    $scope.is_facet_applied = function(facet_id, facet_value) {
        var query = $location.search().q || '';
        var facet_query = new RegExp(facet_id + '\\:"' + facet_value + '"', 'i');
        if (query.match(facet_query)) {
            return true;
        } else {
            return false;
        }
    };

    /**
     * Run a search with a facet enabled.
     * The facet will be toggled on and off in the repeated calls with the same
     * parameters.
     */
    $scope.facet_search = function(facet_id, facet_value) {
        var query = $location.search().q || '',
            facet = facet_id + ':"' + facet_value + '"',
            new_query;

        if ($scope.is_facet_applied(facet_id, facet_value)) {
            new_query = query;
            // remove facet in different contexts
            new_query = new_query.replace(' AND ' + facet + ' AND ', ' AND ', 'i');
            new_query = new_query.replace(facet + ' AND ', '', 'i');
            new_query = new_query.replace(' AND ' + facet, '', 'i');
            new_query = new_query.replace(facet, '', 'i') || 'RF0*';
        } else {
            new_query = query + ' AND ' + facet; // add new facet
        }
        $location.search('q', new_query);
    };

    /**
     * Show/hide search facets to save screen space.
     * Uses jQuery for simplicity.
     * Activated only on mobile devices.
     */
    $scope.toggle_facets = function() {
        var facets = $('.metasearch-facets');
        facets.toggleClass('hidden-xs', !facets.hasClass('hidden-xs'));
        $('#toggle-facets').text(function(i, text){
          return text === "Show facets" ? "Hide facets" : "Show facets";
        });
    };

    $scope.download_fasta = function(rna) {
      var url = getFastaDownloadUrl(rna.fields.rfamseq_acc[0], rna.fields.seq_start[0], rna.fields.seq_end[0]);
      window.open(url);
    }


}]);

/**
 * Query controller
 * Responsible for the search box in the header.
 */
angular.module('rfamApp').controller('QueryCtrl', ['$scope', '$location', '$window', '$timeout', 'results', 'search', function($scope, $location, $window, $timeout, results, search) {

    $scope.query = {
        text: '',
        submitted: false
    };

    /**
     * Launch a text search using the service.
     */
    $scope.meta_search = function(query) {
        search.meta_search(query);
    };

    /**
     * Control browser navigation buttons.
     */
    $scope.$watch(function () { return $location.url(); }, function (newUrl, oldUrl) {
        // ignore url hash
        newUrl = newUrl.replace(/#.+$/, '');
        oldUrl = oldUrl.replace(/#.+$/, '');
        // url has changed
        if (newUrl !== oldUrl) {
            if (newUrl.indexOf('/search') == -1) {
                // a non-search url, load that page
                redirect(newUrl);
            } else {
                // the new url is a search result page, launch that search
                $scope.query.text = $location.search().q;
                results.search($location.search().q);
                $scope.query.submitted = false;
            }
        }

        function redirect(newUrl) {
            $timeout(function() {
                // wrapping in $timeout to avoid "digest in progress" errors
                $window.location = newUrl;
            });
        }

    });

    /**
     * Called when the form is submitted.
     */
    $scope.submit_query = function() {
        $scope.query.submitted = true;
        if ($scope.queryForm.text.$invalid) {
            return;
        }
        $scope.meta_search($scope.query.text);
    };

    /**
     * Check if the url contains a query when the controller is first created
     * and initiate a search if necessary.
     */
    (function () {
        if ($location.url().indexOf("/search?q=") > -1) {
            // a search result page, launch a new search
            $scope.query.text = $location.search().q;
            results.search($location.search().q);
        }
    })();

}]);

/**
 * Custom filter for inserting HTML code in templates.
 * Used for processing search results highlighting.
 */
angular.module('rfamApp').filter("sanitize", ['$sce', function($sce) {
  return function(htmlCode){
    return $sce.trustAsHtml(htmlCode);
  }
}]);

/**
 * Custom filter for formatting genome size using humanize.js.
 */
angular.module('rfamApp').filter('humanizeGenomesize', function () {
    return function () {
        var args = Array.prototype.slice.call(arguments);
        args[0] = parseInt(args[0])
        if ( isNaN(args[0]) ) { return args[0]; }
        return humanize.genomesize.apply(null, args);
     };
});

/**
 * Strip out HTML code.
 */
angular.module('rfamApp').filter('htmlToPlaintext', function() {
    return function(text) {
      return  text ? String(text).replace(/<[^>]+>/gm, '') : '';
    };
});

/**
 * Absolute value as a filter.
 */
angular.module('rfamApp').filter('abs', function () {
  return function(val) {
    return Math.abs(val);
  }
});
