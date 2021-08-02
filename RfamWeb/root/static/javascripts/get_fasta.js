var getFasta = function(event, rfamAcc, seqAcc, seqStart, seqEnd) {
    event.target.style.color = '#b18b80';

    // RNAcentral identifier
    if (seqAcc.search(/^URS[A-F0-9]{10}/i) !== -1) {
        rnacentral_id = seqAcc.slice(0,13);
        jQuery.ajax({
            url: 'https://rnacentral.org/api/v1/rna/URS.fasta'.replace('URS', rnacentral_id),
            success: function(data) {
                var filename = seqAcc + '.fasta';
                if (rfamAcc !== '') {
                    filename = rfamAcc + '_' + filename;
                }
                downloadFile(data, filename);
            },
            error: function(request, status, error) {
                event.target.parentNode.innerHTML = '<i class="fa fa-warning fa-2x" aria-hidden="true" style="color: red;" title="Sequence could not be downloaded from RNAcentral: ' + error + '"></i>';
            },
        });
        return;
    }

    seqStart = parseInt(seqStart);
    seqEnd = parseInt(seqEnd);
    var reversed = (seqStart > seqEnd);

    var url = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nuccore&id=seqAcc&rettype=fasta&retmode=text&seq_start=seqStart&seq_stop=seqEnd&strand=seqStrand';
    var proxyUrl = '/ebeye_proxy';

    if (!reversed) {
        url = url.replace('seqStart', seqStart).replace('seqEnd', seqEnd);
        url = url.replace('seqStrand', '1');
    } else {
        url = url.replace('seqStart', seqEnd).replace('seqEnd', seqStart);
        url = url.replace('seqStrand', '2');
    }
    url = url.replace('seqAcc', seqAcc);

    jQuery.ajax({
        url: proxyUrl,
        data: {'url': url},
        success: function(data) {
            // parse the response to make sure there are no errors and to update the sequence name
            var lines = data.split('\n');
            if (lines.length == 1) {
                event.target.parentNode.innerHTML = '<i class="fa fa-warning fa-2x" aria-hidden="true" style="color: red;" title="Sequence could not be downloaded: ' + lines[0] + '"></i>';
                console.log(url);
                console.log('Error received: ' + data);
                return;
            }
            var sequence = '';
            for (i = 0; i < lines.length; i++) {
                if (i == 0 && lines[i].indexOf('>') !== -1) {
                    continue; // skip FASTA header
                }
                sequence += lines[i];
            }
            sequence = sequence.replace(/T/gi, 'U');
            var seq_region = seqAcc + '/' + seqStart + '-' + seqEnd;
            var fasta = '>' + seq_region + '\n' + sequence;
            var filename = seq_region.replace('/', '_') + '.fasta';
            if (rfamAcc !== '') {
                filename = rfamAcc + '_' + filename;
            }
            downloadFile(fasta, filename);
        }
    });
}

function downloadFile(data, fileName, type="text/plain") {
  // Create an invisible A element
  const a = document.createElement("a");
  a.style.display = "none";
  document.body.appendChild(a);

  // Set the HREF to a Blob representation of the data to be downloaded
  a.href = window.URL.createObjectURL(
    new Blob([data], { type })
  );

  // Use download attribute to set set desired file name
  a.setAttribute("download", fileName);

  // Trigger the download by simulating click
  a.click();

  // Cleanup
  window.URL.revokeObjectURL(a.href);
  document.body.removeChild(a);
}
