These set of files are a redacted and documented version of an onboarding script 
that is designed for a company that deals with more than one client.

It communicates with a the ticketing system HaloPSA that when it detects a companies domain
it will send the user to the folder or a seperate file (up to the companies preference) and run the file that is needed.
To fit with companies different position each file would have commands that will contain all of the needed 
licenses and accounts for that user. 
Then by using Azure it will sync with the companies Active Directory and store the users starting/birthdate and its email.

While not limited to what is in the files, the script will go from Create_AD_User to the company who it needs to connect to,
then will go to the needed onboarding file. If desired it can also go to the email file and send a confermation email.
