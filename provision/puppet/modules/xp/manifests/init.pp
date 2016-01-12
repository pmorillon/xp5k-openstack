# Module:: xp
# Manifest:: init.pp
#

class xp {

  stage {
    'setup':
      before => Stage['main'];
  }

}
