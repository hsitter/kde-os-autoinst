env.DIST = 'xenial'
env.PWD_BIND = '/workspace'

if (env.TYPE == null) {
  if (params.TYPE != null) {
    env.TYPE = params.TYPE
  } else {
    type = inferType()
    if (type != null) {
      env.TYPE = type
    }
  }
}

if (env.OPENQA_SERIES == null) {
  env.OPENQA_SERIES = 'xenial'
}

if (env.TYPE == null) {
  error 'TYPE param not set. Cannot run install test without a type.'
}

properties([
  pipelineTriggers([upstream(threshold: 'UNSTABLE',
                             upstreamProjects: "iso_neon_${env.OPENQA_SERIES}_${TYPE}_amd64")]),
  pipelineTriggers([cron('0 H(9-22) * * *')])
])

fancyNode('openqa') {
  try {
    stage('clone') {
      git 'git://anongit.kde.org/sysadmin/neon-openqa.git'
    }
    stage('rake-test') {
      sh 'rake test'
    }
    stage('iso-handover') {
        if (params.ISO) {
          echo 'Picking up ISO from trigger job.'
          sh "cp -v ${params.ISO} incoming.iso"
      }
    }
    stage('test_installation') {
      wrap([$class: 'LiveScreenshotBuildWrapper', fullscreenFilename: 'wok/qemuscreenshot/last.png']) {
        sh 'INSTALLATION=1 bin/contain.rb /workspace/bin/bootstrap.rb'
      }
    }
    if (env.ARCHIVE) {
      stage('archive-raid') {
        sh 'bin/archive.rb'
      }
    }
  } finally {
    dir('metadata') { archiveArtifacts '*' }
    dir('wok') { archiveArtifacts allowEmptyArchive: true, artifacts: 'testresults/*, ulogs/*, video.*, vars.json, slide.html' }
    junit 'junit/*'
    sh 'bin/contain.rb chown -R jenkins .'
  }
}

def fancyNode(label = null, body) {
  node(label) {
    wrap([$class: 'AnsiColorBuildWrapper', colorMapName: 'xterm']) {
      wrap([$class: 'TimestamperBuildWrapper']) {
        body()
      }
    }
  }
}

// When not called from an ISO build we'll want to infer the type from our own name.
def inferType() {
  if (!env.JOB_NAME) {
    return null
  }
  String[] types = ["useredition", "userltsedition", "devedition-gitunstable", "devedition-gitstable"]
  for (type in types) {
    if (env.JOB_NAME.contains(type)) {
      return type
    }
  }
  return null
}
