#!groovy

properties([gitLabConnection('https://gitlab.cs.fau.de/'),
           ])

node {
  gitlabBuilds(builds: ['build', 'lint', 'test']) {

    gitlabCommitStatus(name: "build") {
      stage('Preparation') {
        cleanWs()
          checkout scm

          sh """#!/usr/bin/env bash
          set -e
          set -x

          export GEM_HOME="\$(pwd)/gems"
          bundle install
          """
      }
    }

    gitlabCommitStatus(name: "lint") {
      stage('Lint') {
        sh """#!/usr/bin/env bash
          set -e
          set -x

          export GEM_HOME="\$(pwd)/gems"
          bundle exec pronto run -c "${gitlabBefore}"
          """
      }
    }


    gitlabCommitStatus(name: "test") {
      stage('Test') {
        sh """#!/usr/bin/env bash
          set -e
          set -x

          export GEM_HOME="\$(pwd)/gems"
          export LD_LIBRARY_PATH="/usr/lib/lp_solve"
          export PATH="\$(pwd):\$PATH"
          bundle exec ./test/testrunner.rb -v -v
          """
      }
    }
  }
}
