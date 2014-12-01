require 'spec_helper'
require 'php_fpm_docker/config_parser'

describe PhpFpmDocker::ConfigParser do
  let(:example) {
  }
  let (:a_i_only) do
    @path ||= Pathname.new '/tmp/etc/config.ini'
    i=described_class.new(@path, @filter)
    mock_logger i
    i
  end
  let (:a_i) do
    a_i_only
  end
  let (:prepare_files) do
    if @config.length == 1
      files = [[Tempfile.new('config').path, @config.first[1], true]]
    elsif @config.length > 1
      files = []
      @dir = Dir.mktmpdir
      @path = Pathname.new @dir
      @config.each do |filename,content,readable|
        p = @path.join(filename)
        files << [p,content,readable]
      end
    end
    files.each do |file|
      f = open(file[0],'w')
      f.write file[1]
      f.chmod(0000) unless file[2]
      f.flush
      f.close
    end
    @files = files.map {|f| f.first}
  end
  let (:cleanup_files) do

  end
  describe '#initialize' do
    after (:example) do
      a_i_only
      expect(a_i_only.instance_variable_get(:@path)).to be_a(Pathname)
    end
    it 'accept pathname' do
    end
    it 'accept string' do
      @path = '/tmp/string'
    end
  end
  describe '#files' do
    let (:prepare_file) do
      @file = Tempfile.new 'config'
      @file.write(@content || 'nocontent')
      @file.flush
      @path = Pathname.new @file.path
    end
    let!(:files_in_dir) do
      @files = [
        {:name => 'test1.txt',  :non_readable => false},
        {:name => 'test2.conf', :non_readable => false},
        {:name => 'test3.cnf',  :non_readable => false},
        {:name => 'test4.conf', :non_readable => true},
      ]
    end
    let (:prepare_dir) do
      files_in_dir 
      @dir = Dir.mktmpdir
      @path = Pathname.new @dir
      @files.each do |file|
        p = @path.join(file[:name])
        f = open(p,'w')
        f.write 'no content'
        f.flush
        f.chmod(0000) if file[:non_readable]
      end
    end
    let (:delete_dir) do
      FileUtils.rm_rf(@dir)
    end
    it 'config file existing and readable' do
      prepare_file
      expect(method).to eq([@path.to_s])
    end
    it 'config file existing and not readable' do
      prepare_file
      expect(@path).to receive(:readable?).and_return(false)
      expect{method}.to raise_error(/Not readable/)
    end
    it 'config file not existing' do
      prepare_file
      @file.delete
      expect{method}.to raise_error(/Not existing path/)
    end
    it 'config dir files default filter' do
      prepare_dir
      files = @files.reject do |x|
        not x[:name] =~ /\.conf$/ or x[:non_readable]
      end.map do |x|
        @path.join(x[:name]).to_s
      end
      expect(method).to contain_exactly(*files)
      delete_dir
    end
    it 'config dir files with custom filter' do
      @filter = /\.cnf$/
      prepare_dir
      files = @files.reject do |x|
        not x[:name] =~ @filter or x[:non_readable]
      end.map do |x|
        @path.join(x[:name]).to_s
      end
      expect(method).to contain_exactly(*files)
      delete_dir
    end
  end
  describe '#config' do
    it 'uses cache if existent' do
      @sample = {:test => :cache}
      config = double()
      expect(config).to receive(:to_h).and_return(@sample)
      a_i.instance_variable_set(:@config, config)
      expect(a_i).not_to receive(:parse)
      expect(method).to eq(@sample)
    end
    it 'uses calls parse without cache' do
      @sample = {:test => :parse}
      config = double()
      expect(config).to receive(:to_h).and_return(@sample)
      expect(a_i).to receive(:parse).and_return(config)
      inst_set(:@config, nil)
      expect(method).to eq(@sample)
    end
  end
  describe '#parse' do
    after(:example) do
      expect(a_i).to receive(:files).and_return(@files)
      expect(method.to_h).to eq(@result)
      cleanup_files
    end
    it 'parse one file' do
      @config = [
        ['file1.conf', "main = cool \n[web4]\n\nuser = web4 ",true],
      ]
      prepare_files
      @result = { 'web4' => {'user' => 'web4'}, 'global' => {'main' => 'cool'}}
    end
    it 'parse two file no overlap' do
      @config = [
        ['file1.conf', "[web4]\n\nuser = web4 ",true],
        ['file2.conf', "[web3]\n\nuser = web3 ",true],
      ]
      prepare_files
      @result = {
        'web3' => {'user' => 'web3'},
        'web4' => {'user' => 'web4'},
      }
    end
    it 'parse two file no overlap' do
      @config = [
        ['file1.conf', "a=1\n[web4]\n\nuser = web4 ",true],
        ['file2.conf', "a=2\n[web4]\n\nuser = web4a\n[web3]\n\nuser = web3 ",true],
      ]
      prepare_files
      @result = {
        'global' => {'a' => 2 },
        'web3' => {'user' => 'web3'},
        'web4' => {'user' => 'web4a'},
      }
    end
  end
  describe '#hash' do
    it 'return hash with no args' do
      expect(method).to be_a(String)
    end
    it 'work with two string args' do
      expect(method(:a,:b)).to eq(method(:a,:b))
      expect(method(:a,:b)).not_to eq(method(:a,:c))
      expect(method(:c,:b)).not_to eq(method(:a,:b))
    end
    it 'work with two hash args' do
      expect(method({:a => :b})).to eq(method({:a =>:b}))
      expect(method(:a,{})).not_to eq(method(:a,{:c => 1}))
    end
  end
  describe '#pools' do
    before(:example) do
      @input = {
        'global' => {'a' => 2 },
        'web3' => {'user' => 'web3'},
        'web4' => {'user' => 'web4'},
      }
      @result = {
        'hash1'=> {
          :name=>'web3',
          :config=> {'user'=>'web3'}
        },
        'hash2'=>{
          :name=>'web4', 
          :config=>{'user'=>'web4'}
        }
      }
    end
    let(:set) do
      expect(a_i).to receive(:config).and_return(@input)
      expect(a_i).to receive(:hash) do |key,value|
        @count = 0 if @count.nil?
        @count += 1
        "hash#{@count}"
      end.at_least(:twice)
    end
    it 'do show correct format' do
      set
      expect(method).to eq(@result)
    end
  end
end


