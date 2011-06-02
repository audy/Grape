class Client
  attr_accessor :addr, :user
  def initialize(args={})
    @addr, @user = args[:addr], args[:user]
  end
  
  def alive?
    `ping -q -c 1 -W 1 #{@addr}`
    if $?.exitstatus == 0
      true
    else
      false
    end
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
  
  def sync_databases
    @clients.each do |client|
      `rsync database/ #{client}:grapes/`
      fail "#{client} can't RSYNC!" unless $?.exitstatus == 0
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
  
  def remove_dead
    @clients.each do |client|
      @clients.delete client unless client.alive?
    end
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


g = Grape.new :config => ARGV[0]
puts "There are #{g.clients.length} clients."
puts "Removing dead clients"
g.remove_dead
g.sync_databases
puts "There are #{g.clients.length} clients left."