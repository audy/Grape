class Client
  attr_accessor :addr, :user, :client
  
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
    # get prerequesites
  end
  
  def remote_sh(cmd)
    `ssh -i cluster.key #{@client} "#{cmd}"`
  end
  
  def mkdir(f)
    remote_sh "mkdir -p #{f}"
  end

  def sync_folder!(f)
    mkdir 'grapes'
    `rsync -av -e ssh -C -i cluster.key #{@client}:grapes/ #{f}`
    fail "#{@client} can't RSYNC! #{f}" unless $?.exitstatus == 0
  end
  
  def to_s
    "#{@user}@#{@addr}"
  end
  
end

class Grape
  attr_accessor :config, :clients
  
  def initialize(args={})
    @config = args[:config]
    @clients = load_config(@config)
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