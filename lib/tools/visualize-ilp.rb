#!/usr/bin/env ruby
# typed: ignore
#
# PLATIN tool set
#
# Simple visualizer (should be expanded to do proper report generation)
#
require 'json'

require 'set'
require 'platin'
require 'analysis/scopegraph'
require 'tools/visualize'
require 'tools/visualize-ilp'
require 'tools/visualisationserver'

include PML

begin
  require 'rubygems'
  require 'graphviz'
rescue Exception => details
  warn "Failed to load library graphviz"
  info "  ==> gem1.9.1 install ruby-graphviz"
  die "Failed to load required ruby libraries"
end

def run_visualization_server(ilp, options, unbounded, freqs)
  vis = ILPVisualisation.new(ilp, [:bitcode, :machinecode, :relationgraph, :gcfg])
  vis.generate_graph(:unbounded => unbounded, :freqmap => freqs, colorizewcet => true)
  ilp_graph_svg = vis.output(format: :svg)
  ilp_graph_dot = vis.output(format: :dot)
  ilp_dot = "wcec-ilp.dot"
  ilp_svg = "wcec-ilp.svg"
  File.write(ilp_svg, ilp_graph_svg)
  File.write(ilp_dot, ilp_graph_dot)
  info("Written #{ilp_dot} and #{ilp_svg}")

  constraints = vis.get_constraints
  srchints    = vis.get_srchints

  ilpdata = {
    'ilp.svg' => {
      'content_type' => 'image/svg+xml',
      # 'data' => visualisation[:ilp][:svg],
      'data' => ilp_graph_svg
    },
    'constraints.json' => {
      'content_type' => 'application/json',
      # 'data' => JSON.generate(visualisation[:ilp][:constraints]),
      'data' => JSON.generate(constraints)
    },
    'srchints.json' => {
      'content_type' => 'application/json',
      # 'data' => JSON.generate(visualisation[:ilp][:srchints]),
      'data' => JSON.generate(srchints)
    }
  }

  assetdir = File.realpath(File.join(__dir__, '..', '..', 'assets'))
  assert ("Not a directory #{assetdir}") { File.directory? (assetdir) }

  # TODO:
  options.source_path = '/'
  options.server_bind_addr = 'localhost'
  options.server_port = 2342

  server = VisualisationServer::Server.new( \
                      :ilp, \
                      { \
                          :entrypoint => options.analysis_entry \
                        , :srcroot => options.source_path  \
                        , :assets  => assetdir \
                        , :data    => ilpdata  \
                      }, \
                      :BindAddress => options.server_bind_addr, \
                      :Port => options.server_port \
  )

  # puts "Starting server, use <Ctrl-C> to return to REPL"
  puts "Listening at http://#{options.server_bind_addr}:#{options.server_port}/"
  server.start
end
