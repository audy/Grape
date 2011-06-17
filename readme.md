# Grapes, how do they work?

Grape is map-reduce duct taped onto BLAST. In this setup, worker nodes are controlled by a head node via SSH. Worker nodes need to have SSH servers running and the host's encryption key in their authorized_keys file. The head node will command workers to retrieve the appropriate build of BLAST for their architecture, retrieve and format the database from the head node, BLAST sequences against said database and return results to the head node over SSH. In the end, you get a single, tab-delimited output file with the results.

**Requirements:**

1. Ruby 1.8.7
2. megablast 2.2.25 (downloaded automagically)
3. Mac OSX / Linux (intel) supported. Other architectures can easily be added.

See also: [zounds](http://www.github.com/ctb/zounds).


## Setting up

Invoke thusly,

	ruby grape.rb clients.txt	

Where `clients.txt` is a list of clients and usernames that looks like this:

	# IP ADDRESS	HOSTNAME
	192.168.0.12	beavis
	192.168.0.24	butthead

Yep, those are tabs separating the ip address from the hostname. By default, Grape uses cluster.key for SSH. Concatenate this file with the ~/.ssh/authorized_keys file on the workers. Query files go into `queries/`. Files are sent to worker nodes as is so split them up as much as you like. Database goes in `database/`. Databases are syncronized with workers and formatted on the workers using `formatdb`. All worker files are stored in `~/grapes`.

## lib/grape

For genome hacking cyberpunks only:

	require './lib/grape.rb' # Get grapin'
	
	# Load config
	grape = Grape.new :config => 'config.txt'
	
	# Checks if clients are alive, removes them otherwise.
	grape.remove_dead!
	
	# Install BLAST on clients
	grape.setup_clients
	
	# Syncronize database (run formatdb yourself first) using RSYNC
	grape.sync_database!
	
	# Run BLAST
	# Grape will blast any queries files in queries/ against whatever is in database/ using as many clients at once as possible.
	grape.run_blast