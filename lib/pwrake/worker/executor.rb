module Pwrake

  class Executor

    def initialize(selector,dir_class,id)
      @selector = selector
      @id = id
      @out = Writer.instance
      @log = LogExecutor.instance
      @queue = FiberQueue.new
      @rd_list = []
      @dir = dir_class.new
      @dir.open
      @dir.open_messages.each{|m| @log.info(m)}
      @out.puts "#{@id}:open"

      r,w = IO.pipe
      @command_pipe_r = NBIO::Reader.new(@selector,r)
      @command_pipe_w = NBIO::Writer.new(@selector,w)
      @start_process_fiber = Fiber.new do
        while line = @queue.deq
          cmd = line
          while /\\$/ =~ line  # line continues
            line = @queue.deq
            break if !line
            cmd += line
          end
          break if @stopped
          cmd.chomp!
          if !cmd.empty?
            start_process(cmd)
          end
          Fiber.yield
        end
      end
    end

    def stop
      @stopped = true
      @queue.finish
    end

    def close
      if @thread
        @thread.join(15)
        sleep 0.1
      end
      @thread = Thread.new do
        @dir.close_messages.each{|m| @log.info(m)}
        @dir.close
      end
    rescue => exc
      @log.error(([exc.to_s]+exc.backtrace).join("\n"))
    end

    def join
      if @thread
        @thread.join(15)
      end
    rescue => exc
      @log.error(([exc.to_s]+exc.backtrace).join("\n"))
    end

    def execute(cmd)
      return if @stopped
      @queue.enq(cmd)
      @start_process_fiber.resume
    end

    def start_process(command)
      return if @thread      # running
      return if !command     # empty queue
      @spawn_in, @sh_in = IO.pipe
      @sh_out, @spawn_out = IO.pipe
      @sh_err, @spawn_err = IO.pipe

      @pid = Kernel.spawn(command,
                          :in=>@spawn_in,
                          :out=>@spawn_out,
                          :err=>@spawn_err,
                          :chdir=>@dir.current,
                          :pgroup=>true
                         )
      @log.info "pid=#{@pid} started. command=#{command.inspect}"

      @thread = Thread.new do
        @pid2,@status = Process.waitpid2(@pid)
        @spawn_in.close
        @spawn_out.close
        @spawn_err.close
      end

      @rd_out = NBIO::Reader.new(@selector,@sh_out)
      @rd_err = NBIO::Reader.new(@selector,@sh_err)
      @rd_list = [@rd_out,@rd_err]

      Fiber.new{callback(@rd_err,"e")}.resume
      Fiber.new{callback(@rd_out,"o")}.resume
    end

    def callback(rd,mode)
      while s = rd.gets
        @out.puts "#{@id}:#{mode}:#{s.chomp}"
      end
      if rd.eof?
        @rd_list.delete(rd)
        if @rd_list.empty?  # process_end
          @thread = @pid = nil
          @log.info inspect_status
          @out.puts "#{@id}:z:#{exit_status}"
          @sh_in.close
          @sh_out.close
          @sh_err.close
          @start_process_fiber.resume # next process
        end
      end
    rescue => exc
      @log.error(([exc.to_s]+exc.backtrace).join("\n"))
      stop
    end

    def inspect_status
      s = @status
      case
      when s.signaled?
        if s.coredump?
          "pid=#{s.pid} dumped core."
        else
          "pid=#{s.pid} was killed by signal #{s.termsig}"
        end
      when s.stopped?
        "pid=#{s.pid} was stopped by signal #{s.stopsig}"
      when s.exited?
        "pid=#{s.pid} exited normally. status=#{s.exitstatus}"
      else
        "unknown status %#x" % s.to_i
      end
    end

    def exit_status
      s = @status
      case
      when s.signaled?
        if s.coredump?
          "core_dumped"
        else
          "killed:#{s.termsig}"
        end
      when s.stopped?
        "stopped:#{s.stopsig}"
      when s.exited?
        "#{s.exitstatus}"
      else
        "unknown:%#x" % s.to_i
      end
    end

    def kill(sig)
      stop
      if @pid
        Process.kill(sig,-@pid)
        @log.warn "Executor(id=#{@id})#kill pid=#{@pid} sig=#{sig}"
      end
    end

  end
end
