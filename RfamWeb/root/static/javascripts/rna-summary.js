angular.module('rfamApp')
.directive('rnaSummary', ['$http', '$location', function($http, $location) {
  return {
    restrict: 'E',
    scope: {
      name: '@',
      seqstart: '@',
      seqend: '@',
    },

    controller: function($scope) {

      var ensembl_genomes = ['ailuropoda_melanoleuca', 'anas_platyrhynchos', 'anolis_carolinensis', 'arabidopsis_thaliana', 'astyanax_mexicanus',
        'bombyx_mori', 'bos_taurus', 'caenorhabditis_elegans', 'callithrix_jacchus', 'canis_lupus_familiaris', 'cavia_porcellus',
        'chlorocebus_sabaeus', 'choloepus_hoffmanni', 'ciona_intestinalis', 'ciona_savignyi', 'danio_rerio', 'dasypus_novemcinctus',
        'dictyostelium_discoideum', 'dipodomys_ordii', 'drosophila_melanogaster', 'echinops_telfairi', 'equus_caballus',
        'erinaceus_europaeus', 'felis_catus', 'ficedula_albicollis', 'gadus_morhua', 'gallus_gallus', 'gasterosteus_aculeatus',
        'gorilla_gorilla_gorilla', 'homo_sapiens', 'ictidomys_tridecemlineatus', 'latimeria_chalumnae', 'lepisosteus_oculatus',
        'loxodonta_africana', 'macaca_mulatta', 'macropus_eugenii', 'meleagris_gallopavo', 'microcebus_murinus', 'monodelphis_domestica',
        'mus_musculus', 'mustela_putorius_furo', 'myotis_lucifugus', 'nomascus_leucogenys', 'ochotona_princeps', 'oreochromis_niloticus',
        'ornithorhynchus_anatinus', 'oryctolagus_cuniculus', 'oryzias_latipes', 'otolemur_garnettii', 'ovis_aries', 'pan_troglodytes',
        'papio_anubis', 'pelodiscus_sinensis', 'petromyzon_marinus', 'poecilia_formosa', 'pongo_abelii', 'procavia_capensis',
        'pteropus_vampyrus', 'rattus_norvegicus', 'sarcophilus_harrisii', 'schizosaccharomyces_pombe', 'sorex_araneus', 'sus_scrofa',
        'taeniopygia_guttata', 'takifugu_rubripes', 'tarsius_syrichta', 'tetraodon_nigroviridis', 'tupaia_belangeri', 'tursiops_truncatus',
        'vicugna_pacos', 'xenopus_tropicalis', 'xiphophorus_maculatus'];

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
      }).error(function(){
          console.log('RNA data could not be loaded');
      });

    },

    template: '\
    <div style="font-size: 14px;">\
    <h3>{{rna.description}}</h3>\
    <p>{{rna.rfamseq_acc_description}}</p>\
    <ul>\
      <li><a href="http://www.ebi.ac.uk/ena/data/view/{{rna.rfamseq_acc}}">{{rna.rfamseq_acc}}</a> | Nucleotides <i>{{seqstart | number}}-{{seqend | number}}</i></li>\
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
    <a href="http://www.ebi.ac.uk/ena/data/view/{{rna.rfamseq_acc}}&display=fasta&range={{seqstart}}-{{seqend}}">Download FASTA sequence</a>\
    <a ng-if="!genoverse" href="http://www.ebi.ac.uk/ena/data/view/{{rna.rfamseq_acc}}"><img src="http://www.ebi.ac.uk/ena/data/view/graphics/{{rna.rfamseq_acc}}%26showSequence=false%26featureRange={{rna.seq_start}}-{{rna.seq_end}}%26sequenceRange=1-1000.jpg"></a>\
    </div>\
    '
  };

}]);
