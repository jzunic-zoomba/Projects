These two files are supposed to connect to HaloPSA and a messaging system. 
After non work hours they are supposed to connect to both halo and their messaging system to send
notifcations to the person who is assigned to On-Call every 5 minutes with the number of how many
tickets where made in those 5 minutes. 

Using a yml file the amount of time between each check and when it runs can be altered. 
Same if you chose to use another way of checking like Windows Task Scheduler or Azure Automation.

Please note that due to not having the needed permissions and the time I wasn't able to properly test
the system but in theory it should work.
