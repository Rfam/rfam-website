const tableBody = document.getElementById("table-body");

getData();

async function getData() {
      const response = await fetch('static/data/3d-pdb.tsv')
      const data = await response.text();

      const table = data.split('\n');
      table.forEach((row,index) => {
      const columns = row.split('\t');
      const id = columns[0];
      const desc = columns[1];
      const pdb = columns[2].split(',').map(pdb => `<a href="https://www.ebi.ac.uk/pdbe/entry/pdb/${pdb}">${pdb}</a>`).join(', ')
      const seed = columns[3];

      const tr = document.createElement("tr");
      tr.innerHTML = `
          <td><a href="/family/${id}">${id}</a></td>
          <td>${desc}</td>
          <td>${pdb}</td>
          <td><a href="/family/${id}/alignment/stockholm?gzip=1&download=1">${id}.sto.gz</a></td>
          `;
       tableBody.append(tr);
})
}
