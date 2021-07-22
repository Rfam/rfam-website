angular.module('rfamApp')
.directive('rfamGenome', ['$http', function($http) {
  return {
    restrict: 'E',
    scope: {
      name: '@'
    },

    controller: function($scope) {

      var search_config = {
          ebeye_base_url: global_settings.EBI_SEARCH_ENDPOINT + '/ebisearch/ws/rest/rfam',
          fields: [
              'id',
              'assembly_level',
              'assembly_name',
              'common_name',
              'description',
              'gca_accession',
              'length',
              'ncbi_taxid',
              'num_families',
              'num_rfam_hits',
              'scientific_name',
              'tax_string',
          ],
      };

      var query_urls = {
          'ebeye_search': search_config.ebeye_base_url +
                          '?query={QUERY}%20AND%20entry_type:"genome"' +
                          '&format=json' +
                          '&fields=' + search_config.fields.join(),
          'proxy': '/ebeye_proxy?url=',
      };

      $http({
          url: query_urls.proxy + encodeURIComponent(query_urls.ebeye_search.replace('{QUERY}', $scope.name)),
          method: 'GET'
      }).success(function(data) {
          $scope.genome = {};
          $scope.genome['id'] = data.entries[0].id;
          Object.keys(data.entries[0].fields).forEach(function(key){
              $scope.genome[key] = data.entries[0].fields[key][0];
          });
          window.document.title = $scope.genome.scientific_name + ' genome';
      }).error(function(){
          console.log('Genome data could not be loaded');
      });

    },

    template: '\
    <div style="font-size: 14px;">\
    <h3>{{genome.scientific_name}}\
    <small class="text-capitalize-first-letter" style="display: inline-block;">{{genome.common_name}}</small>\
    </h3>\
    <p>{{genome.description}}</p>\
    <dl class="dl-horizontal">\
      <dt>UniProt ID</dt>\
      <dd><a class="ext" title="View in UniProt" href="http://www.uniprot.org/proteomes/{{genome.id}}">{{genome.id}}</a></dd>\
      <dt>NCBI Taxonomy ID</dt>\
      <dd><a class="ext" title="View NCBI Taxonomy" href="https://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?id={{genome.ncbi_taxid}}">{{genome.ncbi_taxid}}</a></dt>\
      <dt ng-if="genome.gca_accession">Assembly accession</dt>\
      <dd ng-if="genome.gca_accession"><a class="ext" title="View in ENA" href="http://www.ebi.ac.uk/ena/data/view/{{genome.gca_accession}}">{{genome.gca_accession}}</a></dd>\
      <dt>Genome length</dt>\
      <dd>{{genome.length | humanizeGenomesize}}</dd>\
      <dt>Taxonomic lineage</dt>\
      <dd>{{genome.tax_string}}</dd>\
    </dl>\
    <a href="/search?q={{genome.id}}%20AND%20entry_type:&quot;Sequence&quot;" class="btn btn-primary" style="background-color: #734639; border-color: #734639;">Browse <strong>{{genome.num_rfam_hits | number}}</strong> sequences</a>\
    <a href="/search?q={{genome.id}}%20AND%20entry_type:&quot;Family&quot;" class="btn btn-primary" style="background-color: #734639; border-color: #734639;">Browse <strong>{{genome.num_families | number}}</strong> families</a>\
    </div>\
    '
  };

}]);
