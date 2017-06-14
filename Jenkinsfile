env.DIST = 'xenial'
env.TYPE = 'user'
env.PWD_BIND = '/workspace'

cleanNode('master') {
  ws('/tmp/kde-os-autoinst') {
    try {
      stage('clone') {
        git 'https://github.com/apachelogger/kde-os-autoinst'
      }
      stage('run') {
        sh './contain.rb /workspace/bin/bootstrap.rb'
      }
    } finally {
      archiveArtifacts 'wok/testresults/*.png, wok/testresults/*.json, wok/ulogs/*, wok/video.ogv'
      junit 'junit/*'
      // sh 'rm -f wok.tar wok.tar.xz'
      // sh 'tar cfJ wok.tar.xz wok'
      // archiveArtifacts 'wok.tar.xz'
      sh './contain.rb chown -R jenkins .'
    }
  }
}

def cleanNode(label = null, body) {
  node(label) {
    try {
// Supremely bugged causing excessive slowdown in jenkins. not sure why.
// <org.jenkinsci.plugins.livescreenshot.LiveScreenshotBuildWrapper plugin="livescreenshot@1.4.5">
// <fullscreenFilename>screenshot.png</fullscreenFilename>
// <thumbnailFilename>screenshot-thumb.png</thumbnailFilename>
// </org.jenkinsci.plugins.livescreenshot.LiveScreenshotBuildWrapper>
      wrap([$class: 'AnsiColorBuildWrapper', colorMapName: 'xterm']) {
        wrap([$class: 'TimestamperBuildWrapper']) {
          body()
        }
      }
    } finally {
      // step([$class: 'WsCleanup', cleanWhenFailure: true])
    }
  }
}
