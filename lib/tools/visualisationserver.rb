require 'webrick'
require 'pathname'
require 'json'
require 'erb'
require 'pp'

module VisualisationServer

class Templates
  include ERB::Util

  def make_page(context)
    # Variables in context that are referenced:
    #   - @title
    #   - @cssfiles     (optional)
    #   - @jsscripts    (optional)
    #   - @bodytemplate (optional)
    #   - @jsinit       (optional)
    page = %{
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="utf-8">
        <meta http-equiv="X-UA-Compatible" content="IE=edge">
        <meta name="viewport" content="width=device-width, initial-scale=1">

        <title><%= title %></title>

        <% if defined?(cssfiles) %>
          <% for @css in cssfiles %>
            <link href="<%= u(@css) %>" rel="stylesheet">
          <% end %>
        <% end %>
      </head>
    <body>
      <%= ERB.new(bodytemplate, 1, nil, '_sub_body').result(binding) if defined?(bodytemplate) %>

      <% if defined?(jsscripts) %>
        <% for @script in jsscripts %>
          <script src="<%= u(@script) %>"></script>
        <% end %>
      <% end %>
      <script type="text/javascript">
        <%= ERB.new(jsinit, 1, nil, '_sub_jsinit').result(binding) if defined?(jsinit) %>
      </script>
    </body>
    </html>
    }

    ERB.new(page, 1).result(context)
  end

  def view_source(file)
    context = binding
    context.local_variable_set(:title, "#{file}: Sourceview")
    context.local_variable_set(:sourcecode, File.read(file))
    bodytemplate = %{<pre id="l" data-line=" " class="language-c line-numbers"><code><%= h(sourcecode) %></code></pre>}
    context.local_variable_set(:jsscripts, ['/static/js/thirdparty/prism.js'])
    context.local_variable_set(:cssfiles,  ['/static/css/thirdparty/prism.css'])
    context.local_variable_set(:bodytemplate, bodytemplate)

    make_page(context)
  end

  def view_ilp(entrypoint, svgurl, constraintsurl, srchintsurl, srcviewurl)
    context = binding
    context.local_variable_set(:title, "#{entrypoint}: ILP")
    # context.local_variable_set(:jsscripts, [ '/static/js/interactivity.js' \
                                           # , '/static/js/thirdparty/seedrandom.min.js'])
    context.local_variable_set(:jsscripts, [ '/static/js/interactivity.js' \
                                           , '/static/js/thirdparty/seedrandom.min.js' \
                                           , '/static/js/thirdparty/prism.js' \
                                           , '/static/js/thirdparty/jquery-2.2.4.min.js' \
                                           , '/static/js/thirdparty/jquery.qtip.min.js' \
                                           , '/static/js/sourceviewtooltip.js' \
                                           ])
    # context.local_variable_set(:cssfiles,  ['/static/css/interactivity.css'])
    context.local_variable_set(:cssfiles,  [ '/static/css/thirdparty/jquery.qtip.min.css' \
                                           , '/static/css/thirdparty/prism.css' \
                                           , '/static/css/interactivity.css' \
                                           , '/static/css/sourceviewtooltip.css' \
                                           ])

    context.local_variable_set(:svgurl, svgurl)
    context.local_variable_set(:constrainturl, constraintsurl)
    context.local_variable_set(:srchinturl, srchintsurl)
    context.local_variable_set(:srcviewurl, srcviewurl)

    bodytemplate = %{
      <div class="viewer">
      <div class="content">
      <object id="ilpcanvas" data="<%= u(svgurl) %>" type="image/svg+xml"></object>
      </div>
      <div id="constraints">
        <button id="allconstraintsbtn" type="button">All constraints</button>
        <ul id="constraintlist">
        </ul>
      </div>
      </div>
    }
    context.local_variable_set(:bodytemplate, bodytemplate)

    jsinit = %{
		  init('<%= u(constrainturl) %>', 'ilpcanvas', '/static/css/ilp.svg.css');
      sourceview_init('ilpcanvas', '<%= u(srchinturl) %>', '<%= u(srcviewurl) %>');
    }
    context.local_variable_set(:jsinit, jsinit)

    make_page(context)
  end

  def tooltip_test
    context = binding
    context.local_variable_set(:title, "tooltiptest")
    context.local_variable_set(:jsscripts, [ '/static/js/thirdparty/prism.js' \
                                           , '/static/js/thirdparty/jquery-2.2.4.min.js' \
                                           , '/static/js/thirdparty/jquery.qtip.min.js' \
                                           , '/static/js/sourceviewtooltip.js' \
                                           ])
    context.local_variable_set(:cssfiles,  [ '/static/css/thirdparty/jquery.qtip.min.css' \
                                           , '/static/css/thirdparty/prism.css'])

    bodytemplate = <<-EOS
      <style>
        .box {
          background-color: #DCF9E1;
          min-width: 70px;
          min-height: 30px;
          position: absolute;
          border: 1px solid black;
        }

        #tl {
          top: 0;
          left: 0;
        }
        #tr {
          top: 0;
          right: 0;
        }
        #bl {
          bottom: 0;
          left: 0;
        }
        #br {
          bottom: 0;
          right: 0;
        }
        #mid {
          left: 50%;
          top: 50%;
        }
        .qtip {
          max-width: unset;
        }

        code[class*="language-"],
        pre[class*="language-"] {
          line-height: 11.0px;
          font-size: 11.0px;
        }
      </style>
      <div id="tl"  class="box"></div>
      <div id="tr"  class="box"></div>
      <div id="bl"  class="box"></div>
      <div id="br"  class="box"></div>
      <div id="mid" class="box"></div>

    EOS
    context.local_variable_set(:bodytemplate, bodytemplate)

    jsinit = <<-EOS
    EOS
    context.local_variable_set(:jsinit, jsinit)

    make_page(context)
  end
end

class Server
  class SourceServlet < WEBrick::HTTPServlet::AbstractServlet
    def initialize(server, srcroot)
      super server
      @srcroot = srcroot
    end

    def resolve_file(basedir, path)
      # Warning: This quite certainly enables a timing based file disclosure
      #          vulnerability. I don't really care in this context, though.
      begin
        realbase = Pathname.new(basedir).realpath.to_path
        realfile = Pathname.new(File.join(basedir, path)).realpath.to_path
        if realfile.start_with? realbase
          return realfile
        end
      rescue
      end
      return nil
    end

    def number_or_nil(string)
      num = string.to_i
      num if num.to_s == string
    end
  end


  class SourceInfoServlet < SourceServlet
    def do_GET(req, resp)
      file  = req.query["file"]
      line  = req.query["line"]
      range = req.query["range"] || :full
      if file && line
        realfile = resolve_file(@srcroot, file)
        realline = number_or_nil(line)
      end

      if range == "full"
        realrange = :full
      else
        realrange = number_or_nil(range)
      end

      if realfile.nil? || realline.nil? || realrange.nil?
        resp.body = 'Illegal parameters, expecting filepath file and numbers line, range'
        raise WEBrick::HTTPStatus::BadRequest
      end

      begin
      code = File.read(realfile).split("\n")
      rescue Errno
        resp.body = "Failed to open file"
        raise WEBrick::HTTPStatus::BadRequest
      end
      if realrange == :full
        from = 0
        to   = code.length - 1
        out  = code.join("\n")
      else
        from = [0, realline - realrange-1].max
        to   = [code.length - 1, realline + realrange].min
        out = code[from, to - from].join("\n")
      end
      resp.content_type = 'application/json'
      resp.body = JSON.generate({:from => from + 1, :to => to + 1, :code => out})
      raise WEBrick::HTTPStatus::OK
    end
  end

  class SourceViewServlet < SourceServlet
    def do_GET(req, resp)
      file  = req.query["file"]
      if file
        realfile = resolve_file(@srcroot, file)
      end

      if realfile.nil?
        resp.body = 'Illegal parameters, expecting filepath file and numbers line, range'
        raise WEBrick::HTTPStatus::BadRequest
      end

      resp.content_type = 'text/html'
      begin
        resp.body = Templates.new.view_source(realfile)
      rescue Errno
        raise WEBrick::HTTPStatus::BadRequest
      end
      raise WEBrick::HTTPStatus::OK
    end
  end

  class ToolTipTest < WEBrick::HTTPServlet::AbstractServlet
    def do_GET(req, resp)
      resp.content_type = 'text/html'
      begin
        resp.body = Templates.new.tooltip_test
      rescue Errno
        raise WEBrick::HTTPStatus::BadRequest
      end
      raise WEBrick::HTTPStatus::OK
    end
  end

  class ILPServlet < WEBrick::HTTPServlet::AbstractServlet

    def initialize(server, entrypoint, svgurl, constraintsurl, srchinturl, srcviewurl)
      super server
      @entrypoint, @svgurl, @constraintsurl, @srchinturl = entrypoint, svgurl, constraintsurl, srchinturl
      @srcviewurl = srcviewurl
    end

    def do_GET(req, resp)
      resp.content_type = 'text/html'
      begin
        resp.body = Templates.new.view_ilp(@entrypoint, @svgurl, @constraintsurl, @srchinturl, @srcviewurl)
      rescue Errno
        raise WEBrick::HTTPStatus::BadRequest
      end
      raise WEBrick::HTTPStatus::OK
    end
  end

  # Serve a hash containing several dataitems
  class HashServlet < WEBrick::HTTPServlet::AbstractServlet
    def initialize(server, data)
      super server
      @data = data
    end

    def do_GET(req, resp)
      effpath = req.path_info.gsub(/^\/+/, '')

      raise WEBrick::HTTPStatus::NotFound unless @data.has_key?(effpath)

      data = @data[effpath]
      if data.is_a?(Hash)
        resp.content_type = data['content_type']
        resp.body         = data['data']
      else
        resp.content_type = 'text/plain'
        resp.body         = data.to_s
        puts data.to_s
      end

      raise WEBrick::HTTPStatus::OK
    end
  end

  class RedirectServlet < WEBrick::HTTPServlet::AbstractServlet
    def initialize(server, url)
      super server
      @url = url
    end

    def do_GET(req, resp)
      effpath = req.path_info.gsub(/^\/+/, '')

      raise WEBrick::HTTPStatus::NotFound unless effpath.empty?

      resp.set_redirect(WEBrick::HTTPStatus::TemporaryRedirect, @url);
  end
  end


  def initialize(mode, opts, **webrick_opts)
    @server = WEBrick::HTTPServer.new webrick_opts

    @server.mount '/static', WEBrick::HTTPServlet::FileHandler, opts[:assets]

    # Sourceinfo servlets
    if [:ilp].include?(mode)
      assert("No source-root given") { opts.has_key?(:srcroot) }
      assert("#{opts[:srcroot]}: No such directory") { File.directory?(opts[:srcroot]) }
      @server.mount '/api/srcinfo', SourceInfoServlet, opts[:srcroot]
      @server.mount '/sourceview', SourceViewServlet, opts[:srcroot]
    end

    case mode
    when :ilp
      assert("HashServlet expects an Hash") { \
        opts.is_a?(Hash) && opts.has_key?(:data) && opts[:data].is_a?(Hash) \
      }
      @server.mount '/api/data', HashServlet, opts[:data]
      @server.mount '/', ILPServlet, opts[:entrypoint], '/api/data/ilp.svg', '/api/data/constraints.json', '/api/data/srchints.json', '/sourceview'
    when :callgraph
      assert("HashServlet expects an Hash") { \
        opts.is_a?(Hash) && opts.has_key?(:data) && opts[:data].is_a?(Hash) \
      }
      @server.mount '/api/data', HashServlet, opts[:data]
      @server.mount '/', RedirectServlet, '/api/data/callgraph.svg'
    else
      raise ArgumentError.new "No such server mode: #{mode}"
    end
  end

  def start
    old = trap 'INT' do @server.shutdown end
    @server.start
    trap 'INT', old
  end
end

end # module

if __FILE__ == $PROGRAM_NAME
  assert ("Usage: #{$PROGRAM_NAME} srcroot artifactsdir") {ARGV.length == 2}
  server = Server.new(:ilp, \
                      { \
                          :srcroot => ARGV[0] \
                        , :assets  => ARGV[1] \
                      },
                      :BindAddress => '127.0.0.1',
                      :Port => 8080)
  server.start
end
