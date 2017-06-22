env.DIST = 'xenial'
env.TYPE = params.TYPE
env.PWD_BIND = '/workspace'

cleanNode('master') {
  ws('/tmp/kde-os-autoinst') {
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
      // sh 'rm -f wok.tar wok.tar.xz'
      // sh 'tar cfJ wok.tar.xz wok'
      // archiveArtifacts 'wok.tar.xz'
      sh 'bin/contain.rb chown -R jenkins .'
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
