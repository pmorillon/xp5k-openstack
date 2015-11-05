# Module:: xp
# Manifest:: locales.pp
#

class xp::locales {

  class {
    'locales':
      lang     => 'en_US.UTF-8',
      language => 'en_US:en',
      lc_all   => 'en_US.UTF-8';
  }

}
