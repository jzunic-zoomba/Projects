The purpose of this file is for when an employee quicks or gets fired this script can convert their mailbox to shared, 
add a forwarding feature and even delete the account if needed. The orignal concept was also supposed to have a scheduler.
While unforchantly, I couldn't get the script to properly communicate with Windows Task Scheduler I know it is possible.

It communicates with HaloPSA, Azer AD, and Microsoft Graph to do the tasks. 
As the script runs it communicates to all of the services while using a Microsoft Admin account. 
**Please note that it only works with an admin account.**

This originally was supposed to be a lot more complicated logicstially, using task scheduler and communicating with the comapnies email.
After working on this for a month I realized that this was just needless fluff and while it is possible, it is too much work for the task.
So after taking a break from this project and working on the onboarding files, 
I realized that this project shouldn't be complex due to the fact that all of the licenses are connected to the Microsoft account, if the account goes down, 
so will everything else. 
