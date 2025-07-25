The purpose of this file is for when an employee quicks or gets fired this script can convert their mailbox to shared, 
add a forwarding feature and even delete the account if needed. The orignal concept was also supposed to have a scheduler.
While unforchantly, I couldn't get the script to properly communicate with Windows Task Scheduler I know it is possible.

It communicates with HaloPSA, Azer AD, and Microsoft Graph to do the tasks. 
As the script runs it communicates to all of the services while using a Microsoft Admin account. 
**Please note that it only works with an admin account.**
