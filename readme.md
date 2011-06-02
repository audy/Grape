# Grape

Run BLAST distributedly on a Beowulf cluster.

aka: Why am I still using BLAST?  
aaka: Why is the computer lab so hot?

## Grapes, how do they work?

Grape only requires your clients (workers) to have bash and an SSH server running. Grape installs megablast on clients, syncs database with clients and streams query sequences to clients while they stream results back. This whole process is error-prone and there are currently is no fault tolerance implemented.

## Requirements:

1. Ruby 1.8.7
2. megablast 2.2.25 (downloaded automagically)
3. A room full of idle iMacs

## Okay great but how do I use this thing?

Well, like this:

	ruby grape.rb clients.txt	

Where `clients.txt` is a list of clients and usernames that looks like this:

	# IP ADDRESS	HOSTNAME
	192.168.0.12	beavis
	192.168.0.24	butthead

Yep, those are tabs separating the ip address from the hostname.

By default, Grape uses cluster.key for ssh. If you don't like that, `ln -s`. Of course, make sure you put your key in the clients' `authorized_keys` or you will be typing a lot of passwords.

## Cool, now where do my datas go?

Excellent question, good chap!

Query files go into `queries/`.  
_You are responsible for granularization!_

Database goes in `database/`. Database gets synced with RSYNC.  

Upon syncronization, data is stored on the remote machine's `~/grapes`

## lib/grape

If you're the hacker type, you can fiddle with Grape in your own pipeline:

	# Load config
	grape = Grape.new :config => 'config.txt'
	
	# Checks if clients are alive, removes them otherwise.
	grape.remove_dead!
	
	# Install BLAST on clients
	grape.setup_clients
	
	# Syncronize database using RSYNC
	grape.sync_database!
	
	# Run BLAST
	# Grape will blast any queries files in queries/ against whatever is in database/ using as many clients at once as possible.
	grape.run_blast