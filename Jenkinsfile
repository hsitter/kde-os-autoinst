env.DIST = 'xenial'
env.TYPE = 'user'
env.PWD_BIND = '/workspace'

cleanNode('master') {
  stage('clone') {
    git 'https://github.com/apachelogger/kde-os-autoinst'
  }
  stage('run') {
    sh './contain.rb /workspace/bootstrap.rb'
  }
}

def cleanNode(label = null, body) {
  node(label) {
    deleteDir()
    try {
      wrap([$class: 'AnsiColorBuildWrapper', colorMapName: 'xterm']) {
        wrap([$class: 'TimestamperBuildWrapper']) {
          body()
        }
      }
    } finally {
      sh 'tar -cf wok.tar wok'
      archiveArtifacts 'wok.tar'
      sh './contain.rb chown -R jenkins .'
      // step([$class: 'WsCleanup', cleanWhenFailure: true])
    }
  }
}
