#!/bin/sh
#
# platin setup script
#

set -e

if ! [ -x $(command -v bundler) ]; then
	echo "Could not find required command 'bundler'. Aborting." >&2
	exit 1
fi

if [ -z ${GEM_HOME+x} ]; then
	echo "GEM_HOME not set. Please et GEM_HOME to point to the directory, where gems should be installed. Aborting." >&2
	exit 1
fi

bundle install
