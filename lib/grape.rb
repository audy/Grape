REMOTE_DIR = '~/grapes'
KEY = './cluster.key'

class Client
  attr_accessor :addr, :user, :client, :platform
  
  def initialize(args={})
    @addr, @user = args[:addr], args[:user]
    @verbose = args[:verbose]
    @client = "#{@user}@#{@addr}"    
  end
  
  def alive?    
    `ping -q -c 1 -W 1 #{@addr}`
    if $?.exitstatus == 0
      true
    else
      false
    end
  end
  
  def setup!
    remote_sh "mkdir -p #{REMOTE_DIR}"
    puts 'made remote directory'
    @platform = remote_sh "uname".downcase
    puts "platform = #{@platform}"
    get_blast
  end
  
  def remote_sh(cmd)
    `ssh -i #{KEY} #{@client} "#{cmd}"`
  end
  
  def remote_has?(f)
    cmd = %{
      if [ -e #{f} ]
      then
        exit 0
      else
        exit 1
      fi      
    }
    remote_sh cmd
  end
  
  def has_blast?
    remote_has? "#{REMOTE_DIR}/megablast"
  end

  def sync_folder!(f)
    `rsync -av -e ssh -C -i #{KEY} #{@client}:#{REMOTE_DIR}/ #{f}`
    fail "#{@client} can't RSYNC! #{f}" unless $?.exitstatus == 0
  end
  
  def get_blast(args={})
    puts "Installing blast on #{@client}"
    puts @platform
    unless args[:force]
      return true if has_blast?
    end
    
    if @platform.include?('darwin')
      url = 'ftp://ftp.ncbi.nlm.nih.gov/blast/executables/release/2.2.25/blast-2.2.25-universal-macosx.tar.gz'
    elsif @platform.include?('linux')
      url = 'ftp://ftp.ncbi.nlm.nih.gov/blast/executables/release/2.2.25/blast-2.2.25-x64-linux.tar.gz'
    else
      fail 'unknown platform! Bug @audyyy: http://www.github.com/audy'
    end
    
    remote_sh "curl #{url} > ~/#{REMOTE_DIR}/blast.tar.gz"
    remote_sh "tar -zxvf blast.tar.gz"
    remote_sh "mv blast-2.2.25/bin/megablast #{REMOTE_DIR}"
    remote_sh "rm -r blast*"
    
    # TODO make sure it works!
  end
  
  def to_s
    "#{@user}@#{@addr}"
  end
  
end

class Grape
  attr_accessor :config, :clients
  
  def initialize(args={})
    @config = args[:config]
    @clients = load_config @config
  end
  
  def setup_clients

    # check platform
    @clients.each do |c|
      c.setup!
      puts "#{c} .. #{c.platform}"
    end

    # psuedo asyncronously setup clients
    # make deep copy of clients list
    need_blast = @clients.collect { |x| Marshal.load(Marshal.dump(x)) }

    need_blast.each do |c|
      fork { c.get_blast }
    end
    
    while need_blast.length > 0 do
      need_blast.delete_if { |x| x.has_blast? }
      sleep 5
      puts "#{need_blast.length} remaining..."
    end
    
    puts "all clients have blast! awesome!"
    
  end
  
  def sync_databases!
    @clients.each do |client|
      client.sync_folder! 'databases/'
    end
  end
  
  def print_clients
    @clients.each { |client| puts client }
  end
  
  def check_clients
    @clients.each do |client|
      puts "#{client}\t#{client.alive?}"
    end
  end
  
  def remove_dead!
    @clients.delete_if { |x| !x.alive? }
  end
  
  def load_config(filename)
    clients = Array.new
    File.open(filename) do |h|
      h.each do |line|
        unless line[0].chr == '#'
          line = line.strip.split("\t")
          clients << Client.new(:addr => line[0], :user => line[1])
        end
      end
    end
    clients
  end
end