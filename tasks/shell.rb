# Definitions
#

# Fork the execution of a command. Used to execute ssh on deployed nodes.
def fork_exec(command, *args)
  # Remove empty args
  args.select! { |arg| arg != "" }
  args.flatten!
  pid = fork do
    Kernel.exec(command, *args)
  end
  Process.wait(pid)
end


# Shell tasks
#
desc "ssh on host, need host=<role|FQDN>"
task :shell do
  host = parse_host().first
  fork_exec('ssh', SSH_CONFIGFILE_OPT.split(" "), 'root@' + host)
end

desc 'Launch command in parallel, need cmd=<command> and host=<role|FQDN>'
task :cmd do
  abort "Need cmd=" unless cmd = ENV['cmd']
  user = ENV['user'] || 'root'
  hosts = parse_host()
  on hosts, :user => user do
    cmd
  end
end

