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

fancyNode('master') {
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
    stage('archive-raid') {
      tar = "/var/www/metadata/os-autoinst/${env.TYPE}.tar"
      sh "tar --exclude=*.iso --exclude=*.iso.* --exclude=*socket --exclude=wok/video.ogv --exclude=wok/ulogs --exclude=wok/testresults -cf ${tar}.new ."
      sh "gpg2 --armor --detach-sign -o ${tar}.new.sig ${tar}.new"
      sh "mv -v ${tar}.new ${tar}"
      sh "mv -v ${tar}.new.sig ${tar}.sig"
    }
  } finally {
    archiveArtifacts 'wok/testresults/*.png, wok/testresults/*.json, wok/ulogs/*, wok/video.ogv'
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
