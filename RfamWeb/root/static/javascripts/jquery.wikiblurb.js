/*
* File: jquery.wikiblurb.js
* Version: 1.0.2
* Description: A simple jQuery plugin to get sections of Wikipedia and other Wikis
* Author: 9bit Studios
* Copyright 2014, 9bit Studios
* http://www.9bitstudios.com
* Free to use and abuse under the MIT license.
* http://www.opensource.org/licenses/mit-license.php
*/

(function (jQuery) {

    jQuery.fn.wikiblurb = function (options) {

        var defaults = jQuery.extend({
            wikiURL: "https://en.wikipedia.org/",
            apiPath: 'w',
            section: 0,
            page: 'RNA',
            removeLinks: false,
            type: 'all',
            customSelector: '',
            filterSelector: '',
            callback: function(){ }
        }, options);

        /******************************
        Private Variables
        *******************************/

        var object = jQuery(this);
        var settings = jQuery.extend(defaults, options);

        /******************************
        Public Methods
        *******************************/

        var methods = {

            init: function() {
                return this.each(function () {
                    methods.appendHTML();
                    methods.initializeItems();
                });
            },

            /******************************
            Utilities
            *******************************/

            addUnderscores: function(page) {
                if(page.trim().indexOf(' ') !== -1) {
                    page.replace(' ', '_');
                }
                return page;
            },

            /******************************
            Append HTML
            *******************************/

            appendHTML: function() {
                // nothing to append
            },

            /******************************
            Initialize
            *******************************/

            initializeItems: function() {

                var page = methods.addUnderscores(settings.page), section;

                if(settings.section !== null) {
                    section = "&section=" + settings.section
                }

                jQuery.ajax({
                    type: "GET",
                    url: settings.wikiURL + settings.apiPath + "/api.php?action=parse&format=json&prop=text"+ "&page="+ page +"&callback=?",
                    contentType: "application/json; charset=utf-8",
                    async: true,
                    dataType: "json",
                    success: function (data, textStatus, jqXHR) {

                        try {
                            var markup = data.parse.text["*"];
                            var blurb = jQuery('<div class="nbs-wikiblurb"></div>').html(markup);

                            if (jQuery(blurb).find('.redirectText a').length) {
                              var redirect_page = jQuery(blurb).find('.redirectText a').attr('href').replace('/wiki/', '');
                              jQuery('#wikiArticle').wikiblurb({
                                  page: redirect_page,
                              });
                              return;

                            }

                            methods.refineResult(blurb);

                            switch(settings.type) {
                                case 'text':
                                    object.html(jQuery(blurb).find('p'));
                                    break;

                                case 'blurb':
                                    object.html(jQuery(blurb).find('p:first'));
                                    break;

                                case 'infobox':
                                    object.html(jQuery(blurb).find('.infobox'));
                                    break;

                                case 'custom':
                                    object.html(jQuery(blurb).find(settings.customSelector));
                                    break;

                                default:
                                    object.html(blurb);
                                    break;
                            }

                            settings.callback();

                        }
                        catch(e){
                            methods.showError();
                        }
                    },
                    error: function (jqXHR, textStatus, errorThrown) {
                        methods.showError();
                    }
                });
            },
            refineResult: function(blurb){
                // remove links?

                blurb.find('.mw-editsection').remove();
                blurb.find('.mw-empty-elt').remove();
                blurb.find('.box-Multiple_issues').remove(); // wikipedia box with a warning about issues
                blurb.find('.box-Technical').remove(); //wikipedia box with a warning about article being too technical
                blurb.find('.plainlinks.hlist.navbar.mini').remove(); // gallery controls
                blurb.find('#toc').remove();

                if(settings.removeLinks) {
                    blurb.find('a').each(function() {
                        jQuery(this).replaceWith(jQuery(this).html());
                    });
                }
                else {

                    var baseWikiURL = methods.removeTrailingSlash(settings.wikiURL);

                    blurb.find('a').each(function() {
                        var link = jQuery(this);
                        var relativePath = link.attr('href') || '';
                        // links to wiki pages are relative so need to add wikipedia domain but it shouldn't be added to fully qualified URLs
                        if (relativePath.indexOf('http://') === -1 && relativePath.indexOf('www.') === -1 && relativePath.indexOf('.com') === -1 && relativePath.indexOf('.org') === -1) {
                            link.attr('href', baseWikiURL + relativePath);
                        }
                    });
                }

                blurb.find('img').each(function() {
                  var img = jQuery(this);
                  img.attr('src', 'https:' + img.attr('src') );
                  img.attr('srcset', '');
                });

                // remove any references
                blurb.find('sup').remove();

                // remove cite error
                blurb.find('.mw-ext-cite-error').remove();

                // filter elements
                if(settings.filterSelector) {
                    blurb.find(settings.filterSelector).remove();
                }

                return blurb;

            },
            removeTrailingSlash: function(str){

                if(str.substr(-1) === '/') {
                    return str.substr(0, str.length - 1);
                }
                return str;

            },
            showError: function(){
                object.html('<div class="nbs-wikiblurb-error">There was an error locating your wiki data</div>');
            }
        };

        if (methods[options]) { // jQuery("#element").pluginName('methodName', 'arg1', 'arg2');
            return methods[options].apply(this, Array.prototype.slice.call(arguments, 1));
        } else if (typeof options === 'object' || !options) { 	// jQuery("#element").pluginName({ option: 1, option:2 });
            return methods.init.apply(this);
        } else {
            jQuery.error( 'Method "' +  method + '" does not exist in wikiblurb plugin!');
        }
    };

})(jQuery);
