#!groovy

def executors = 'Ubuntu-18.04'
properties([gitLabConnection('https://gitlab.cs.fau.de/'),
           ])

node(executors) {
  gitlabBuilds(builds: ['build', 'lint', 'test']) {

    gitlabCommitStatus(name: "build") {
      stage('Preparation') {
        cleanWs()
          checkout scm

          sh """#!/usr/bin/env bash
          set -e
          set -x

          echo "###############################################################"
          echo "# GITLAB PLUGIN OUTPUT"
          echo "###############################################################"
          echo ""
          echo gitlabBranch                       \$gitlabBranch
          echo gitlabSourceBranch                 \$gitlabSourceBranch
          echo gitlabActionType                   \$gitlabActionType
          echo gitlabUserName                     \$gitlabUserName
          echo gitlabUserEmail                    \$gitlabUserEmail
          echo gitlabSourceRepoHomepage           \$gitlabSourceRepoHomepage
          echo gitlabSourceRepoName               \$gitlabSourceRepoName
          echo gitlabSourceNamespace              \$gitlabSourceNamespace
          echo gitlabSourceRepoURL                \$gitlabSourceRepoURL
          echo gitlabSourceRepoSshUrl             \$gitlabSourceRepoSshUrl
          echo gitlabSourceRepoHttpUrl            \$gitlabSourceRepoHttpUrl
          echo gitlabMergeRequestTitle            \$gitlabMergeRequestTitle
          echo gitlabMergeRequestDescription      \$gitlabMergeRequestDescription
          echo gitlabMergeRequestId               \$gitlabMergeRequestId
          echo gitlabMergeRequestIid              \$gitlabMergeRequestIid
          echo gitlabMergeRequestState            \$gitlabMergeRequestState
          echo gitlabMergedByUser                 \$gitlabMergedByUser
          echo gitlabMergeRequestAssignee         \$gitlabMergeRequestAssignee
          echo gitlabMergeRequestLastCommit       \$gitlabMergeRequestLastCommit
          echo gitlabMergeRequestTargetProjectId  \$gitlabMergeRequestTargetProjectId
          echo gitlabTargetBranch                 \$gitlabTargetBranch
          echo gitlabTargetRepoName               \$gitlabTargetRepoName
          echo gitlabTargetNamespace              \$gitlabTargetNamespace
          echo gitlabTargetRepoSshUrl             \$gitlabTargetRepoSshUrl
          echo gitlabTargetRepoHttpUrl            \$gitlabTargetRepoHttpUrl
          echo gitlabBefore                       \$gitlabBefore
          echo gitlabAfter                        \$gitlabAfter
          echo gitlabTriggerPhrase                \$gitlabTriggerPhrase
          echo "###############################################################"
          echo ""

          export GEM_HOME="\$(pwd)/gems"
          gem install rake
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
          MERGE_BASE="\$(git merge-base ${gitlabBefore} ${gitlabAfter} || true)"
          if [[ ! -z \${MERGE_BASE+x} ]]; then
            echo "Could not determine MERGE_BASE: Assuming force push, using master as base"
            MERGE_BASE="\$(git merge-base refs/remotes/origin/master ${gitlabAfter})"
          fi
          bundle exec pronto run -c "\${MERGE_BASE}"
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
