# **Disclosure**
Due to an issue with licenses I was unable to properly test them. If you were to use a workflow tool like n8n you can make an easier version of this. 

## **Concept**
These two files are supposed to connect to HaloPSA and a messaging system. 
After non work hours they are supposed to connect to both halo and their messaging system to send
notifcations to the person who is assigned to On-Call every 5 minutes with the number of how many
tickets where made in those 5 minutes. 

Using a yml file the amount of time between each check and when it runs can be altered. 
Same if you chose to use another way of checking like Windows Task Scheduler or Azure Automation.
