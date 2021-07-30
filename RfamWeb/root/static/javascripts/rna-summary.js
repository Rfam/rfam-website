angular.module('rfamApp')
.directive('rnaSummary', ['$http', function($http) {
  return {
    restrict: 'E',
    scope: {
      name: '@',
      seqstart: '@',
      seqend: '@',
    },

    controller: function($scope) {

      var ensembl_genomes = ['anolis_carolinensis', 'arabidopsis_thaliana', 'bombyx_mori', 'bos_taurus',
      'caenorhabditis_elegans', 'callithrix_jacchus', 'canis_lupus_familiaris',
      'chlorocebus_sabaeus', 'ciona_intestinalis', 'danio_rerio', 'dictyostelium_discoideum',
      'drosophila_melanogaster', 'equus_caballus', 'felis_catus', 'gallus_gallus',
      'gorilla_gorilla_gorilla', 'grch37', 'grch38', 'homo_sapiens', 'lepisosteus_oculatus',
      'macaca_mulatta', 'meleagris_gallopavo', 'monodelphis_domestica', 'mus_musculus',
      'ornithorhynchus_anatinus', 'oryctolagus_cuniculus', 'oryzias_latipes', 'ovis_aries',
      'pan_troglodytes', 'papio_anubis', 'pongo_abelii', 'rattus_norvegicus', 'schizosaccharomyces_pombe',
      'sus_scrofa', 'taeniopygia_guttata', 'tetraodon_nigroviridis'];

      var search_config = {
          ebeye_base_url: global_settings.EBI_SEARCH_ENDPOINT + '/ebisearch/ws/rest/rfam',
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
              'rfamseq_acc_description',
              'chromosome_name',
              'chromosome_type',
          ],
      };

      var query_urls = {
          'ebeye_search': search_config.ebeye_base_url +
                          '?query=rfamseq_acc:"{ACCESSION}"%20AND%20seq_start:"{SEQ_START}"%20AND%20seq_end:"{SEQ_END}"%20AND%20entry_type:"Sequence"' +
                          '&format=json' +
                          '&fields=' + search_config.fields.join(),
          'xref_rfam_search': search_config.ebeye_base_url + '/entry/{ID}/xref/rfam?format=json',
          'xref_taxid_search': search_config.ebeye_base_url + '/entry/{ID}/xref/taxonomy?format=json',
          'xref_rnacentral_search': search_config.ebeye_base_url + '/entry/{ID}/xref/rnacentral?format=json',
          'proxy': '/ebeye_proxy?url=',
      };

      var sort_start_end = function () {
        if ($scope.seqstart > $scope.seqend) {
          var temp = $scope.seqend;
          $scope.seqend = $scope.seqstart;
          $scope.seqstart = temp;
        }
      };

      $http({
          url: query_urls.proxy + encodeURIComponent(query_urls.ebeye_search.replace('{ACCESSION}', $scope.name).replace('{SEQ_START}', $scope.seqstart).replace('{SEQ_END}', $scope.seqend)),
          method: 'GET'
      }).success(function(data) {
          $scope.rna = {};
          $scope.rna['id'] = data.entries[0].id;
          Object.keys(data.entries[0].fields).forEach(function(key){
              $scope.rna[key] = data.entries[0].fields[key][0];
          });
          window.document.title = $scope.rna['description'];
          var species_label = $scope.rna.scientific_name.replace(' ', '_').toLowerCase();
          if (jQuery.inArray(species_label, ensembl_genomes) !== -1 && $scope.rna.chromosome_name) {
            $scope.genoverse = true;
          } else {
            $scope.genoverse = false;
          }
          sort_start_end();
          var offset = Number(Math.round(($scope.seqend - $scope.seqstart)/10));
          if ($scope.genoverse) {
            var genoverse = new Genoverse({
              container: '#genoverse',
              genome: species_label,
              chr: $scope.rna.chromosome_name,
              start: Number($scope.seqstart) - offset,
              end: Number($scope.seqend) + offset,
              tracks: [
                Genoverse.Track.Scalebar,
                Genoverse.Track.Gene,
              ],
              trackAutoHeight: true, // expand tracks to show all features
              plugins: [ "controlPanel", "trackControls", "karyotype"],
              urlParamTemplate: '', // do not update URL when navigating the genome
              hideEmptyTracks: false,
              highlights: [{
                start: 	Number($scope.seqstart),
                end: Number($scope.seqend),
                label: "RFXXXXX",
                removable: false,
              }],
            });
          }

          $http({
              url: query_urls.proxy + encodeURIComponent(query_urls.xref_rfam_search.replace('{ID}', $scope.rna.id)),
              method: 'GET',
          }).success(function(data) {
              $scope.rna.rfam_id = data.entries[0].references[0].id;
          }).error(function(){
              console.log('Error while retrieving xrefs');
          });

          $http({
              url: query_urls.proxy + encodeURIComponent(query_urls.xref_taxid_search.replace('{ID}', $scope.rna.id)),
              method: 'GET',
          }).success(function(data) {
              $scope.rna.ncbi_id = data.entries[0].references[0].id;
          }).error(function(){
              console.log('Error while retrieving xrefs');
          });

          $scope.rna.rnacentral_id = '';
          $http({
              url: query_urls.proxy + encodeURIComponent(query_urls.xref_rnacentral_search.replace('{ID}', $scope.rna.id)),
              method: 'GET',
          }).success(function(data) {
              if (data.entries[0].referenceCount > 0) {
                $scope.rna.rnacentral_id = data.entries[0].references[0].id;
              } else {
                $scope.rna.rnacentral_id = '';
              }
          }).error(function(){
              console.log('Error while retrieving RNAcentral xref');
          });
      }).error(function(){
          console.log('RNA data could not be loaded');
      });

    },

    template: '\
    <div style="font-size: 14px;">\
    <h3>{{rna.description}}</h3>\
    <dl class="dl-horizontal">\
      <dt>Description</dt>\
      <dd>{{rna.rfamseq_acc_description}}</dd>\
      <dt>Species</dd>\
      <dd><a class="ext" href="https://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?id={{rna.ncbi_id}}">{{rna.scientific_name}}</a></dt>\
      <dt>Accession</dt>\
      <dd><a class="ext" href="http://www.ebi.ac.uk/ena/data/view/{{rna.rfamseq_acc}}">{{rna.rfamseq_acc}}</a></dd>\
      <dt>Nucleotides</dt>\
      <dd>{{seqstart | number}}-{{seqend | number}}</dd>\
      <dt>Length</dd>\
      <dd><strong>{{seqend - seqstart | abs | number}}</strong> nucleotides</dt>\
      <dt>Rfam accession</dt>\
      <dd><a href="/family/{{rna.rfam_id}}">{{rna.rfam_id}}</a> (<strong>{{ rna.alignment_type }}</strong> alignment)</dd>\
      <dt>RNA type</dt>\
      <dd>{{rna.rna_type}}</dd>\
      <dt>Bit score</dt>\
      <dd><strong>{{ rna.bit_score | number }}</strong> bits</dd>\
      <dt ng-if="rna.chromosome_type">Location</dt>\
      <dd ng-if="rna.chromosome_type">{{rna.chromosome_type}} {{rna.chromosome_name}}</dd>\
      <dt ng-if="rna.truncated != \'0\'">Truncated</dt>\
      <dd ng-if="rna.truncated != \'0\'">\
        <span ng-if="rna.truncated == \'5\'">Truncated on 5\' end</span>\
        <span ng-if="rna.truncated == \'3\'">Truncated on 3\' end</span>\
        <span ng-if="rna.truncated == \'53\'">Truncated on both 5\' and 3\' ends</span>\
      </dd>\
      <dt ng-if="rna.rnacentral_id">RNAcentral</dt>\
      <dd ng-if="rna.rnacentral_id"><a href="http://rnacentral.org/rna/{{rna.rnacentral_id}}">{{rna.rnacentral_id}}</a></dd>\
    </dl>\
    <a class="btn btn-primary" style="background-color: #734639; border-color: #734639;" href="http://www.ebi.ac.uk/ena/data/view/{{rna.rfamseq_acc}}&display=fasta&range={{seqstart}}-{{seqend}}"><i class="fa fa-download" aria-hidden="true"></i> FASTA sequence</a>\
    </div>\
    '
  };

}]);
