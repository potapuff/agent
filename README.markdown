# Monitor

Linux monitoring agent fro course Techical Solution Support / Software Quality Assurance, Sumy Stete University, fall 2020.
Highly base on **Graphy**.


## Installation
Pre-requisit: you need ruby

    apt install ruby ruby-dev gcc libffi-dev make
   
or

    yum install ruby ruby-dev gcc libffi-dev make  

First, upload lasted version of gem grom github

    wget https://github.com/potapuff/agent/releases/download/0.1.X/agent-0.1.X.gem
 
Then install the gem on your server:

    gem install agent-0.1.X.gem
    

Then run the `init` command to initialize the required directories and files:

    sudo agent init    # or rvmsudo if you use rvm
    agent update       # or rvmsudo if you use rvm

This will create a directory for storing config and data files at `/var/lib/agent`.
You need to run this command through sudo, because a standard user probably doesn't have
write access to `/etc` and `/var/lib`.


## Configuration

The `init` command will create a sample config file for you at `/var/lib/agent/agent.conf`.

## Stopping the monitor

If for some reason you want to stop the monitoring, call:

    agent remove    # or: agent disable

This will remove the crontab line (and leave all your data in place).

## Deleting the data

If you want to completely remove whatever graphy has installed on the server, call the `purge` command:

    sudo agent purge    # or rvmsudo

This will delete the entire `/var/lib/agent` directory.

## Credits
Created by Kuzikov Borys by modification of Graphy.

Graphy was created by [Jakub Suder](http://psionides.eu) at [Lunar Logic Polska](http://lunarlogicpolska.com). It's
licensed under [MIT license](https://github.com/psionides/graphy/blob/master/MIT-LICENSE.txt).

