module Hutch
  module Launcher
    # inspired by
    # https://gist.githubusercontent.com/mynameisrufus/1372491/raw/dc44d5a51368f9a289ea3458a94579bba23cc4d4/simple_daemon.rb

    def self.daemonize!
      Hutch.logger.info 'starting as daemon'

      # grandparent
      raise 'First fork failed' if (pid = fork) == -1
      exit unless pid.nil?
      # parent
      Process.setsid
      raise 'Second fork failed' if (pid = fork) == -1
      exit unless pid.nil?
      # daemon

      redirect_streams
      kill(Hutch::Config.pidfile)
      write(Process.pid, Hutch::Config.pidfile)
    end

    def self.kill(pidfile)
      opid = open(pidfile).read.strip.to_i
      Process.kill 'QUIT', opid

    rescue TypeError;     Hutch.logger.warn "#{pidfile} is empty"
    rescue Errno::ENOENT; Hutch.logger.warn "#{pidfile} does not exist"
    rescue Errno::ESRCH;  Hutch.logger.warn "Process #{opid} does not exist"
    rescue Errno::EPERM;  raise "Insufficient privileges to manage process #{opid}"
    end

    def self.write(pid, pidfile)
      File.open(pidfile, 'w') { |f| f.write pid }
    end

    def self.redirect_streams
      [$stdin, $stdout, $stderr].each { |fd| fd.reopen '/dev/null' }
      $stdout.sync = $stderr.sync = true
    end
  end
end
