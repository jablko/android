KEYPAIR=keypair
SSH=ssh -o StrictHostKeyChecking=no -t ubuntu@$(HOSTNAME)

all:
	# http://stackoverflow.com/questions/3524726/how-to-make-eval-shell-work-in-gnu-make
	$(eval NAME=$(shell git var GIT_COMMITTER_IDENT | sed 's/\(.*\) <.*>.*/\1/'))
	$(eval EMAIL=$(shell git var GIT_COMMITTER_IDENT | sed 's/.* <\(.*\)>.*/\1/'))

	# Get latest Ubuntu AMI
	$(eval AMI=$(shell curl http://cloud-images.ubuntu.com/query/quantal/server/daily.current.txt | awk '$$5 == "ebs" && $$6 == "amd64" && $$7 == "us-east-1" && $$9 != "hvm" { print $$8 }'))

	# Run it, with enough disk and memory to build Android
	$(eval INSTANCE=$(shell ec2-run-instances -b /dev/sda1=:40 -k $(KEYPAIR) -t m1.medium $(AMI) | awk '/^INSTANCE/ { print $$2 }'))

	# Get hostname
	$(eval HOSTNAME=$(shell ec2-describe-instances $(INSTANCE) | awk '/^INSTANCE/ { print $$4 }'))

	# Connect, install build dependencies, init repo, and build.  Retry
	# connect until success or timeout.
	TIMEOUT=$$(date -d 12sec +%s) && while [ $$(date +%s) -lt $$TIMEOUT ]; do \
	  $(SSH) byobu new-session \' \
	    sudo dpkg --add-architecture i386 \&\& \
	    sudo aptitude update \&\& \
	    sudo aptitude -DRy dist-upgrade \&\& \
	    sudo aptitude -DRy install \
	      bison \
	      build-essential \
	      flex \
	      git \
	      gperf \
	      libstdc++6:i386 \
	      libxml2-utils \
	      unzip \
	      zip \
	      zlib1g:i386 \&\& \
	    wget --header \"Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2Ftechnetwork%2Fjava%2Fjavase%2Fdownloads%2Fjdk6downloads-1902814.html\" http://download.oracle.com/otn-pub/java/jdk/6u39-b04/jdk-6u39-linux-x64.bin \&\& \
	    chmod +x jdk-6u39-linux-x64.bin \&\& \
	    ./jdk-6u39-linux-x64.bin -noregister \&\& \
	    git config --global user.name \"$(NAME)\" \&\& \
	    git config --global user.email $(EMAIL) \&\& \
	    git config --global color.ui auto \&\& \
	    wget https://dl-ssl.google.com/dl/googlesource/git-repo/repo \&\& \
	    chmod +x repo \&\& \
	    ./repo init -u https://android.googlesource.com/platform/manifest \&\& \
	    ./repo sync \&\& \
	    PATH=$$PATH:~/jdk1.6.0_39/bin make -j4\; \
	    bash\' && break; \
	done
