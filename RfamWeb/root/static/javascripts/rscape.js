/**
 * - load R-scape SVG from the server
 * - add tooltips and get stats using D3
 * - add SVG to DOM
 * - launch svgPanZoom to add extra SVG-specific features
 */

var load_rscape = function(rscape_url, rscape_svg_div_id, rscape_msg_id) {

    d3.xml(rscape_url).mimeType("image/svg+xml").get(function(error, xml) {
        if (error) {
            hide_loading_indicator();
            show_rscape_not_available_msg();
            console.log(error);
            return;
        }
        var svgData = xml.getElementsByTagName("svg")[0];
        d3.select(rscape_svg_div_id).node().appendChild(svgData);
        var svg = d3.select(rscape_svg_div_id + " svg");

        var tooltip = d3.select("body").append("div")
            .attr("class", "rscape-tooltip")
            .style("opacity", 0);
        var panZoom,
            basepairs = 0,
            significant_basepairs = 0;

        hide_loading_indicator();
        remove_rscape_title();
        add_nucleotide_tooltips();
        add_circle_tooltips();
        add_message();
        launch_pan_zoom();
        resize_svg();

        /**
         * If R-scape message is not found or svg cannot be parsed, display
         * a message to the user.
         */
        function show_rscape_not_available_msg() {
            var msg = 'R-scape analysis not available';
            d3.select(rscape_msg_id).html(msg);
            d3.select('.rscape-key').style('display', 'none');
        }

        /**
         * Hide spinning wheel when SVG is loaded.
         */
        function hide_loading_indicator() {
            d3.selectAll('.rscape-loading').style("display", "none");
        }

        /**
         * Launch SvsPanZoom plugin.
         */
        function launch_pan_zoom() {
            panZoom = svgPanZoom(rscape_svg_div_id + ' svg', {
              controlIconsEnabled: true // show zoom in, zoom out and reset buttons
            });
        }

        /**
         * Ensure that SVG is not too small.
         * Resize SVG container div and then resize SVG to match it.
         */
        function resize_svg() {
            var width  = parseInt(d3.select(rscape_svg_div_id + " svg").attr('width')),
                height = parseInt(d3.select(rscape_svg_div_id + " svg").attr('height')),
                min_rscape_height = 400,
                min_rscape_width = 400;

            if (width < min_rscape_width) {
              d3.select(rscape_svg_div_id + " svg").attr('width', min_rscape_width);
            }
            if (height < min_rscape_height) {
              d3.select(rscape_svg_div_id + " svg").attr('height', min_rscape_height);
            }

            panZoom.resize();
            panZoom.fit();
            panZoom.center();
        }

        /**
         * R-scape includes a title in all images which should be removed.
         */
        function remove_rscape_title() {
            svg.selectAll("#text1000").remove();
        }

        /**
         * Add tooltip messages to SVG tspans.
         */
        function add_nucleotide_tooltips() {
            svg.selectAll("tspan").each(function(d) {
                var tspan = d3.select(this),
                    title = '',
                    nucleotide = tspan.text();
                if (nucleotide === 'R') {
                    nucleotide = 'G or A';
                } else if (nucleotide === 'Y') {
                    nucleotide = 'C or U';
                }
                if (tspan.attr('fill') == '#d90000') {
                    title = nucleotide + " present >97%";
                } else if (tspan.attr('fill') == '#000000') {
                    if (nucleotide != "5'") {
                        title = nucleotide + " present 90-97%";
                    }
                } else if (tspan.attr('fill') == '#807b88') {
                    title = nucleotide + " present 75-90%";
                } else if (tspan.attr('fill') == '#ffffff') {
                    title = nucleotide + " present 50-75%";
                }

                if (title) {
                    tspan.on("mouseover", function(d) {
                      tooltip.transition()
                             .duration(200)
                             .style("opacity", .9);
                      tooltip.html(title)
                             .style("left", (d3.event.pageX) + "px")
                             .style("top", (d3.event.pageY - 28) + "px");
                    }).on("mouseout", function(d) {
                        tooltip.transition()
                               .duration(500)
                               .style("opacity", 0);
                    });
                }
            });
        }

        /**
         * Add tooltip messages to SVG paths and count significant/non-significant
         * basepairs.
         */
        function add_circle_tooltips() {
            svg.selectAll("path").each(function(d) {
                var path = d3.select(this),
                    title = '';
                if (path.attr('fill') == '#31a354') {
                    title = "Significant basepair";
                    significant_basepairs += 1;
                } else if (path.attr('fill') == '#d90000') {
                    title = "Nucleotide present 97%";
                } else if (path.attr('fill') == '#000000') {
                    title = "Nucleotide present 90%";
                } else if (path.attr('fill') == '#807b88') {
                    title = "Nucleotide present 75%";
                } else if (path.attr('fill') == '#ffffff') {
                    title = "Nucleotide present 50%";
                }

                if (path.attr('stroke-width') == 1.44) {
                    basepairs += 1;
                }

                if (title) {
                    path.on("mouseover", function(d) {
                      tooltip.transition()
                             .duration(200)
                             .style("opacity", .9);
                      tooltip.html(title)
                             .style("left", (d3.event.pageX) + "px")
                             .style("top", (d3.event.pageY - 28) + "px");
                    }).on("mouseout", function(d) {
                        tooltip.transition()
                               .duration(500)
                               .style("opacity", 0);
                    });
                }
            });
        }

        /**
         * Insert a message with a number of significant
         */
        function add_message() {
            var msg = '<strong>' + significant_basepairs + '</strong> ' +
                      'out of <strong>' + basepairs + '</strong> basepairs ' +
                      'are significant at E-value=0.05';
            d3.select(rscape_msg_id).html(msg);
        }
  });

}
