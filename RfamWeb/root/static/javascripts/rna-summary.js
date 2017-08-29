angular.module('rfamApp')
.directive('rnaSummary', ['$http', '$location', function($http, $location) {
  return {
    restrict: 'E',
    scope: {
      name: '@'
    },

    controller: function($scope) {

      var search_config = {
          ebeye_base_url: 'http://wwwdev.ebi.ac.uk/ebisearch/ws/rest/rfam',
          fields: [
              'id',
              'evalue_score',
              'bit_score',
              'truncated',
              'seq_start',
              'seq_end',
              'rfamseq_acc',
              'rna_type',
              'description',
              'alignment_type',
              'scientific_name',
          ],
      };

      var query_urls = {
          'ebeye_search': search_config.ebeye_base_url +
                          '?query=rfamseq_acc:"{ACCESSION}"%20AND%20seq_start:"{SEQ_START}"%20AND%20seq_end:"{SEQ_END}"%20AND%20entry_type:"match"' +
                          '&format=json' +
                          '&fields=' + search_config.fields.join(),
          'proxy': '/ebeye_proxy?url=',
      };

      var seq_start = $location.search().seq_start || '',
          seq_end = $location.search().seq_end || '';

      $http({
          url: query_urls.proxy + encodeURIComponent(query_urls.ebeye_search.replace('{ACCESSION}', $scope.name).replace('{SEQ_START}', seq_start).replace('{SEQ_END}', seq_end)),
          method: 'GET'
      }).success(function(data) {
          $scope.rna = {};
          $scope.rna['id'] = data.entries[0].id;
          Object.keys(data.entries[0].fields).forEach(function(key){
              $scope.rna[key] = data.entries[0].fields[key][0];
          });
          $scope.rna['seq_start'] = seq_start;
          $scope.rna['seq_end'] = seq_end;
      }).error(function(){
          console.log('RNA data could not be loaded');
      });

    },

    template: '\
    <div style="font-size: 14px;">\
    <h3>{{rna.description}}</h3>\
    <p>{{rna.rfamseq_acc_description}}</p>\
    <ul>\
      <li><a href="http://www.ebi.ac.uk/ena/data/view/{{rna.rfamseq_acc}}">{{rna.rfamseq_acc}}</a> | Nucleotides <i>{{rna.seq_start | number}}-{{rna.seq_end | number}}</i></li>\
      <li>RNA type: {{rna.rna_type}}</li>\
      <li><strong>{{ rna.alignment_type }}</strong> alignment</li>\
      <li title="A bit score of {{ rna.bit_score }} bits indicates the sequence is 2 * {{ rna.bit_score }} times more likely to have been generated from the covariance model than from the random background model">bit score: <strong>{{ rna.bit_score | number }}</strong> bits</li>\
      <li title="The number of hits expected to score this highly in a database of this size">E-value score: {{ rna.evalue_score | number }}</li>\
      <li ng-if="rna.truncated != \'0\'">\
        <span ng-if="rna.truncated == \'5\'">Truncated on 5\' end</span>\
        <span ng-if="rna.truncated == \'3\'">Truncated on 3\' end</span>\
        <span ng-if="rna.truncated == \'53\'">Truncated on both 5\' and 3\' ends</span>\
      </li>\
      <li>Species: {{rna.scientific_name}}</li>\
      <li>Length: </li>\
      <li>Rfam accession</li>\
      <li>Genome accession</li>\
    </ul>\
    <a href="http://www.ebi.ac.uk/ena/data/view/{{rna.rfamseq_acc}}"><img src="http://www.ebi.ac.uk/ena/data/view/graphics/{{rna.rfamseq_acc}}%26showSequence=false%26featureRange={{rna.seq_start}}-{{rna.seq_end}}%26sequenceRange=1-1000.jpg"></a>\
    </div>\
    '
  };

}]);
