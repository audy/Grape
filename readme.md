# Grape

Run BLAST distributedly on a Beowulf cluster

aka: Why am I still using BLAST?  
aaka: Why is the computer lab so hot?


## Requirements:

1. Ruby 1.8.7
2. megablast 2.2.20 (the old and fast one)
3. A room full of idle iMacs

## Okay great but how do I use this thing?

Well, like this:

	ruby grape.rb clients.txt
	
Where `clients.txt` is a list of clients and usernames that looks like this:

	# IP ADDRESS	HOSTNAME
	192.168.0.666	beavis
	192.168.0.420	butthead
	
Yep, those are tabs separating the ip address from the hostname.

By default, Grape uses cluster.key for ssh. If you don't like that, `ln -s`. Of course, make sure you put your key in the clients' `authorized_keys` or you will be typing a lot of passwords.


## Cool, now where do my datas go?

Excellent question, good chap!

Query files go into `queries/`.  
_You are responsible for granularization!_

Database goes in `database/`. Database gets synced with RSYNC.  


Upon syncronization, data is stored on the remote machine's `~/grapes`