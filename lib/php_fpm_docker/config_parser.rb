# coding: utf-8
require 'inifile'
require 'pathname'

module PhpFpmDocker
  # Config file/directory handling
  class ConfigParser
    def initialize(path, filter = nil)
      if path.is_a?(Pathname)
        @path = path
      elsif path.is_a?(String)
        @path = Pathname.new path
      else
        fail TypeError "Unsupport type: #{path.type}"
      end

      @filter = filter || /\.conf$/
    end

    # Return file to read for config
    def files
      p = @path.to_s
      fail "Not existing path: #{p}" unless @path.exist?
      if @path.file?
        fail "Not readable: #{p}" unless @path.readable?
        return [p]
      elsif @path.directory?
        return files_directory
      else
        fail "No file and no directory: #{f}"
      end
    end

    def files_directory
      files = []
      Dir.entries(@path).each do |file|
        p = @path.join(file)
        next unless p.file?
        next unless p.readable?
        next unless @filter.match(file)
        files << p.to_s
      end
      files
    end

    def config
      @config ||= parse
      @config.to_h
    end

    def parse
      config = IniFile.new
      files.each do |file|
        config.merge!(IniFile.load(file, encoding: 'UTF-8'))
      end
      config
    end

    #
    def hash(*args)
      d = Digest::SHA2.new(256)
      d.reset
      args.each do |a|
        d.update a.to_s
      end
      d.to_s
    end

    # Hashes configs to detect changes
    def pools
      needed_pools = config.reject do |key, _value|
        key == 'global'
      end
      retval = {}
      needed_pools.each do |key, value|
        retval[hash(key, value)] = {
          name: key,
          config: value
        }
      end
      retval
    end
  end
end
