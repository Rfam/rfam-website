const tableBody = document.getElementById("table-body");

getData();

async function getData() {
      const response = await fetch('static/data/3d-pdb.csv')
      const data = await response.text();
      console.log(data);

      const table = data.split('\n');
      table.forEach((row,index) => {
      const columns = row.split(',')
      const id = columns[0]
      const desc = columns[1]
      const pdb = columns[2]
      const seed = columns[3]
      console.log(id, desc, pdb, seed);
      const tr = document.createElement("tr");
      tr.innerHTML = `
          <td><a href="/family/${id}">${id}</a></td>
          <td>${desc}</td>
          <td>${pdb}</td>
          <td><a href="/family/${id}/alignment/stockholm?gzip=1&download=1">${id}.stockholm.txt.gz</a></td>
          `;
       tableBody.append(tr);
})
}