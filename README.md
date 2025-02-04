# RSAT-As-Admin
         File Name : RSAT-As-Admin.ps1 
   Original Author : Kenneth C. Mazie (kcmjr AT kcmjr.com) 
                   : 
       Description : Automatically loads specified Windows RSAT AD Admin tools using the user ID you specify 
                   : in the GUI. 
                   : 
             Notes : Normal operation is with no command line options.  
                   : See end of script for detail about how to launch via shortcut. 
                   : If an AES encrypted credential file exists it will be used (see line 112)
                   : 
         Arguments : Command line options for testing: 
                   : - "-console $true" will enable local console echo 
                   : 
          Warnings : None 
                   : 
             Legal : Public Domain. Modify and redistribute freely. No rights reserved. 
                   : SCRIPT PROVIDED "AS IS" WITHOUT WARRANTIES OR GUARANTEES OF 
                   : ANY KIND. USE AT YOUR OWN RISK. NO TECHNICAL SUPPORT PROVIDED. 
                   : That being said, please let me know if you find bugs or improve the script. 
                   : 
           Credits : Code snippets and/or ideas came from many sources including but 
                   : not limited to the following: n/a 
                   : 
    Last Update by : Kenneth C. Mazie 
   Version History : v1.00 - 09-24-18 - Original 
    Change History : v2.00 - 12-10-18 - Complete rewrite 
                   : v2.10 - 12-24-18 - added console suppression. 
                   : v3.00 - 02-05-20 - Added checkboxes to select tool to load. Added detection
                   :                    of current user ID.  Detection of RSAT.
                   : #>
