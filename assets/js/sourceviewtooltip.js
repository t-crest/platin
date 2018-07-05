/*
$(document).ready(function() {
  $('.box').each(function() {
    $(this).qtip({
      content: {
        text: function(event, api) {
          $.ajax({
            url: '/api/srcinfo',
            type: 'GET',
            data: {file: 'kernel/sched/core.c', line: 120, range: 5},
            dataType: 'json',
          }).then(function(content) {
            api.set('content.title', 'kernel/sched/core.c');
            out = api.set('content.text', "<pre class='language-c line-numbers'>"
                            + "<code class='language-c'>"
                            + $('<div/>').text(content.code).html()
                            + "</code></pre>");
            elem = $("#" + out._id);
            pre  = elem.find("pre");
            pre.attr('data-start', content.from);
            pre.addClass("line-numbers");
            pre.attr('data-line', "6");
            code = pre.find("code");
            console.log(pre);
            console.log(code);
            Prism.highlightElement(code[0]);
            console.log(out);
          }, function(xhr, status, error) {
            api.set('content.text', 'failure: ' + status + ':' + error);
          });
          return 'Loading...';
        }
      },
      position: {
        viewport: $(window)
      },
      style: 'qtip-dark'
    });
  });
});
*/

function add_source_hints(svg, srchinturl, srcviewurl) {
  $.getJSON(srchinturl, function(data) {
    $.each(data, function (id, srcinfo) {
      var elem  = svg.contentDocument.getElementById(id);
      // JQuerify element
      var jelem = $(elem);
      var linerange = 5;
      jelem.qtip({

        content: {
          text: function(event, api) {
            $.ajax({
              url: '/api/srcinfo',
              type: 'GET',
              data: {file: srcinfo.file, line: srcinfo.line, range: linerange},
              dataType: 'json',
            }).then(function(content) {
              api.set('content.title', srcinfo.file);
              out = api.set('content.text', $('<div/>').css("fontface", "monospace").text(srcinfo.function).html()
                              + "<pre class='language-c line-numbers'>"
                              + "<code class='language-c'>"
                              + $('<div/>').text(content.code).html()
                              + "</code></pre>");
              elem = $("#" + out._id);
              pre  = elem.find("pre");
              pre.attr('data-start', content.from);
              pre.addClass("line-numbers");
              pre.attr('data-line-offset', content.from - 1);
              pre.attr('data-line', srcinfo.line);
              code = pre.find("code");
              Prism.highlightElement(code[0]);
            }, function(xhr, status, error) {
              api.set('content.text', 'failure: ' + status + ':' + error);
            });
            return 'Loading...';
          }
        },
        position: {
          viewport: $('#ilpcanvas')
        },
        style: 'qtip-dark'



      });

      // Hide the builtin tooltips for SVGs
      jelem.find('title').remove();
      jelem.find('a').removeAttr('xlink:title');


      var url = decodeURIComponent(srcviewurl) + '?' + $.param({file: srcinfo.file}) + "#l." + srcinfo.line;

      jelem.on("mousedown", function(e) {
        if ( e.which <= 2 ) {
          e.preventDefault();
          var win = window.open(url, 'platin-sources');
          if (win) {
            win.focus();
          } else {
            alert('Please allow popups for this website');
          }
        }
      });

    });

  })

  // Hide the builtin tooltips for SVGs
  $(svg.contentDocument).find('title').remove();
  $(svg.contentDocument).find('a').removeAttr('xlink:title');

}

function sourceview_init(svgid, srchinturl, srcviewurl) {
  // First wait for the svg to load
  var cb = function(o) {
    add_source_hints(document.getElementById(svgid), srchinturl, srcviewurl);
  };
  $('#' + svgid).each(function() {
      var $this = $(this);
      $this.on("load", cb);
      if (this.complete) { // `this` = the DOM element
              $this.off("load", cb);
              cb.call(this);
          }
  });
}
