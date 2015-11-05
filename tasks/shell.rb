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

