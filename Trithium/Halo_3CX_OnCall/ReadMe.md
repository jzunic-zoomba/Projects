# **HaloPSA and 3CX Rotations**

The point of these files are to automate the rotation of the On-Call position for Trithium, but of course this can be changed to fit other companies needs. 
Note that these were designed for HaloPSA and 3CX specifcally but can work with other applications if modified. The 3CX file was taken from 3CX (with specifics removed) while the HaloPSA files were taken from the GitHub Actions associated to Trithium. Also with specifics removed. 

## 3CX
The 3CX file was designed to not need any users assigned but rather to use a transfer system that takes advantage of the extenion numbers that are used in the system.
By using a series of if statements we are able to get the week number divided by three which will determine which extension number will be used.

## HaloPSA
HaloPSA a yml file was used to activate workflow actions to properly time it.
Note that the computers **default time zone is UCT** so plan accordingly. 

