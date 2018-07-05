#!groovy

properties([gitLabConnection('https://gitlab.cs.fau.de/'),
           ])

node {
  gitlabBuilds(builds: ['build', 'lint', 'test']) {

    gitlabCommitStatus("build") {
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

    gitlabCommitStatus("lint") {
      stage('Lint') {
        sh """#!/usr/bin/env bash
          set -e
          set -x

          export GEM_HOME="\$(pwd)/gems"

          bundle exec pronto run -c "${gitlabBefore}"
          """
      }
    }


    gitlabCommitStatus("test") {
      stage('Test') {
        sh """#!/usr/bin/env bash
          set -e
          set -x

          echo "Run tests here"
          """
      }
    }
  }
}
