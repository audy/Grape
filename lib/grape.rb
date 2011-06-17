REMOTE_DIR = '~/grapes'
KEY = './cluster.key'
DATABASE_DIR = "database"

class Client
  attr_accessor :addr, :user, :platform
  
  def initialize(args={})
    @addr, @user = args[:addr], args[:user]
    @verbose = args[:verbose]
    @client = "#{@user}@#{@addr}"
    @busy = false
  end
  
  # does the client respond to pings?
  def alive?
    `ping -q -c 1 -W 1 #{@addr}`
    if $?.exitstatus == 0
      true
    else
      false
    end
  end
  
  # for locking
  def busy?
    @busy
  end
  
  # get everything client needs in order to run blast
  def setup!
    @busy = true
    # make directory
    remote_sh "mkdir -p #{REMOTE_DIR}"
    
    # get platform
    @platform = (remote_sh "uname").downcase
    @platform = 'darwin'
    
    # download blast and sync database
    ret = get_blast && (sync_folder! 'database/')
    @busy = false
    ret
  end
  
  # for client.sh 'command', returns exit status
  def sh(cmd)
    remote_sh cmd
  end
  
  # delete's remote directory
  def clean!
    remote_sh "rm -rf #{REMOTE_DIR}"
  end
  
  # runs blast on client
  def run_blast(args={})
    query = args[:query]
    database = args[:database]
    
    puts "#{@client}: #{query} vs #{database}"
    
    cmd = %{
      cat #{query} | \
      ssh -C -i #{KEY} #{@client} \
      "#{REMOTE_DIR}/megablast \
        -i /dev/stdin \
        -o /dev/stdout \
        -d #{REMOTE_DIR}/#{database} \
        -m 8 \
        -v 1 \
        -b 1 \
        -a 4" > results/#{File.basename(query)}
      }
      
    # Lock
    @busy = true
    `#{cmd}`
    @busy = false
  end

  # true/false if client has file
  def has_file?(f)
    cmd = %{
      if [ -e #{f} ]
      then
        exit 0
      else
        exit 1
      fi
    }
    `ssh -i cluster.key #{@client} \"#{cmd}\"`
    $?.exitstatus
  end
  
  # does the client have blast?
  def has_blast?
    has_file? "#{REMOTE_DIR}/megablast"
  end

  # syncronize a local folder to REMOTE_DIR using RSYNC
  def sync_folder!(f)
    remote_sh "mkdir -p #{REMOTE_DIR}"
    cmd = "rsync -auvz -e \"ssh -C -i #{KEY} \" #{f} #{@client}:#{REMOTE_DIR}"
    `#{cmd}`
    puts cmd
    fail "#{@client} can't RSYNC! #{f}" unless $?.exitstatus == 0
  end
  
  def to_s
    @client
  end
  
  private
  
  # Download and install BLAST
  def get_blast(args={})
    unless args[:force]
      return true if (has_blast? == 0)
    end
    
    @busy = true
    puts "Installing blast on #{@client}"
    
    if @platform.include?('darwin')
      url = 'ftp://ftp.ncbi.nlm.nih.gov/blast/executables/release/2.2.25/blast-2.2.25-universal-macosx.tar.gz'
    elsif @platform.include?('linux')
      url = 'ftp://ftp.ncbi.nlm.nih.gov/blast/executables/release/2.2.25/blast-2.2.25-x64-linux.tar.gz'
    else
      fail "unknown platform: #{@platform}"
    end
    
    cmd = %{
      cd #{REMOTE_DIR}
      curl #{url} > blast.tar.gz
      tar -zxvf blast.tar.gz
      mv blast-2.2.25/bin/megablast .
      rm -r blast-2.2.25/*
    }
    remote_sh cmd
    @busy = false
    
    has_file? "#{REMOTE_DIR}/megablast"
  end
  
  # Run commands remotely, returns exit status
  def remote_sh(cmd)
    @busy = true

    puts cmd.inspect
    begin
      res = `ssh -i #{KEY} #{@client} "#{cmd}"` # todo, allow for failure
    rescue
      return 1
    end
    @busy = false
    res # need to return result
  end

end

class Grape
  attr_accessor :config, :clients, :database
  
  def initialize(args={})
    @config = args[:config]
    @clients = Array.new
    @database = args[:database]
    
    load_config unless @config.nil?
  end
  
  # Gets clients ready for BLAST
  def setup_clients
    # psuedo asyncronously setup clients
    # make deep copy of clients list
    need_blast = @clients.collect { |x| Marshal.load(Marshal.dump(x)) }

    need_blast.each do |c|
      fork { c.setup! }
    end
    
    while need_blast.length > 0 do
      need_blast.delete_if { |x| x.has_blast? }
      sleep 5
      puts "#{need_blast.length} remaining..."
    end
    
    puts "all clients have blast! awesome!"
  end
  
  # Run blast on queries/*
  def run_blast
    query_files = Dir.glob('queries/*')
    while query_files.length > 0
      @clients.each do |client|
      file = query_files.pop
      puts file
        fork {
          client.run_blast(:query => file, :database => @database)
        } unless client.busy?
        break if query_files.length == 0
      end
      sleep 5
    end
  end
  
  # Syncronize database with clients
  def sync_database!
    @clients.each do |client|
      client.sync_folder! DATABASE_DIR
    end
  end
  
  # run command on all clients
  def sh(cmd)
    @clients.each { |client| client.sh cmd }
  end
  
  # List clients
  def print_clients
    @clients.each { |client| puts client }
  end
  
  # Print a list of dead/alive clients
  def check_clients
    @clients.each do |client|
      puts "#{client}\t#{client.alive?}"
    end
  end
  
  # Remote clients that don't respond to pings
  def remove_dead!
    @clients.delete_if { |x| !x.alive? }
  end
  
  # Add a new client
  def add_client(args={})
    @clients << Client.new(args)
  end
  
  # Load a config file, add clients
  def load_config
    File.open(@config) do |h|
      h.each do |line|
        unless line[0].chr == '#'
          line = line.strip.split("\t")
          add_client(:addr => line[0], :user => line[1])
        end
      end
    end
  end
end