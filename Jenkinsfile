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

if (env.TYPE == null) {
  error 'TYPE param not set. Cannot run install test without a type.'
}

properties([
  pipelineTriggers([upstream(threshold: 'UNSTABLE',
                             upstreamProjects: "iso_neon_xenial_${TYPE}_amd64")]),
  pipelineTriggers([cron('0 H(9-22) * * *')])
])

fancyNode('openqa') {
  try {
    stage('clone') {
      git 'https://github.com/apachelogger/kde-os-autoinst'
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
    archiveArtifacts 'wok/testresults/*, wok/ulogs/*, wok/video.*'
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
  String[] types = ["useredition", "devedition-gitunstable", "devedition-gitstable"]
  for (type in types) {
    if (env.JOB_NAME.contains(type)) {
      return type
    }
  }
  return null
}
