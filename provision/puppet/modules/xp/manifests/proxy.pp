# Module:: xp
# Manifest:: proxy.pp
#

class xp::proxy {

  file {
    '/etc/apt/apt.conf.d/proxy-guess':
      ensure  => file,
      content => 'Acquire::http::Proxy "http://proxy:3128";';
    '/etc/environment':
      ensure  => file,
      content => '
http_proxy=http://proxy:3128
https_proxy=$https_proxy
ftp_proxy=$https_proxy
no_proxy="localhost,127.0.0.1,localaddress,.localdomain.com"
';
  }

}
