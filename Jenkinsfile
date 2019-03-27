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

if (env.OPENQA_SERIES == null) {
  env.OPENQA_SERIES = 'xenial'
}

// WARNING: DO NOT set properites()!
// properties() calls override whatever we set in the XML via our tooling
// templates. That is to say: calling properties() overrides the actual
// properties from the XML and can have all sorts of side effects.
// This is contrary to the reference documentation which says properties
// are preserved for non-multibranch pipelines!
// If you need properties set do it in pangea-tooling or talk to sitter/bshah
// about it

lock(inversePrecedence: true, label: 'OPENQA_INSTALL', quantity: 1, variable: 'DEBUG_LOCK') {
  fancyNode('openqa') {
    try {
      stage('clone') {
        sh 'env'
        git 'git://anongit.kde.org/sysadmin/neon-openqa.git'
      }
      stage('rake-test') {
        sh 'rake test'
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
      dir('metadata') { archiveArtifacts allowEmptyArchive: true, artifacts: '*' }
      dir('wok') { archiveArtifacts allowEmptyArchive: true, artifacts: 'testresults/*, ulogs/*, video.*, vars.json, slide.html' }
      junit 'junit/*'
      sh 'bin/contain.rb chown -R jenkins .'
      // Make sure we fail if metadata was empty, we didn't assert this earlier
      // because we want the rest of the post-build to run.
      sh 'ls metadata/*'
    }
  }
}

def fancyNode(label = null, body) {
  node(label) {
    wrap([$class: 'AnsiColorBuildWrapper', colorMapName: 'xterm']) {
      wrap([$class: 'TimestamperBuildWrapper']) {
        finally_cleanup { finally_chown { body() } }
      }
    }
  }
}

def finally_chown(body) {
  try {
    body()
  } finally {
    sh 'bin/contain.rb chown -R jenkins .'
  }
}

def finally_cleanup(body) {
  try {
    body()
  } finally {
    if (!env.NO_CLEAN) {
      cleanWs()
    }
  }
}

// When not called from an ISO build we'll want to infer the type from our own name.
def inferType() {
  if (!env.JOB_NAME) {
    return null
  }
  String[] types = ["user", "user_lts", "unstable", "testing"]
  for (type in types) {
    if (env.JOB_NAME.contains(type)) {
      return type
    }
  }
  return null
}
