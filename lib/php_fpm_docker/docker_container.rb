# coding: utf-8
require 'php_fpm_docker/docker_image'
require 'docker'

module PhpFpmDocker
  # Wraps the docker connection
  class DockerContainer
    include Logging

    def self.cmd(*args)
      c = DockerContainer.create(*args)
      c.output
    end

    def self.create(image, *args)
      c = DockerContainer.new(image)
      c.create(*args)
      c
    end

    def initialize(image)
      if image.is_a?(DockerImage)
        @image = image
      else
        fail(
          ArgumentError,
          "Expect a docker image as argument: #{image.class}"
        )
      end
    end

    def options
      {
        'Image' => @image.id
      }
    end

    def output(timeout = 5)
      start
      output = attach(
        stream: true,
        stdin: nil,
        stdout: true,
        stderr: true,
        logs: true,
        tty: false
      )
      return_code = wait(timeout)['StatusCode']
      delete(force: true)

      output.map! do |i|
        if i.first.nil?
          nil
        else
          i.join
        end
      end

      {
        return_code: return_code,
        stdout: output[0],
        stderr: output[1]
      }
    end

    def container
      fail 'no container created' if @container.nil?
      @container
    end

    def status
      ret_val = {}
      container.json['State'].each do |key, value|
        ret_val[key.downcase.to_sym] = value
      end
      ret_val
    end

    def running?
      status[:running]
    rescue RuntimeError
      false
    end

    def method_missing(sym, *args, &block)
      if [:start, :stop, :delete, :wait, :logs, :attach].include? sym
        container.send(sym, *args, &block)
      else
        super
      end
    end

    def create(opts = {})
      opts = { 'Cmd' => opts } if opts.is_a? Array

      fail(
        ArgumentError,
        'Argument has to be a hash or array of strings'
      ) if opts.nil?

      my_opts = options
      my_opts.merge! opts

      fail(ArgumentError, "cmd is no array: #{my_opts['Cmd']}") \
        unless my_opts['Cmd'].is_a? Array

      # ensure there are only strings
      my_opts['Cmd'] = my_opts['Cmd'].map(&:to_s)

      @container = Docker::Container.create(my_opts)
      logger.debug do
        "created container opts=#{my_opts.inspect}"
      end
      @container
    end

    def to_s
      "#<DockerContainer:#{@image.name}:#{id}>"
    end

    def id
      container.id
    rescue RuntimeError
      'unknown'
    end
  end
end
