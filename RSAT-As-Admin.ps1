Param(
    [Switch]$Console = $false           #--[ Set to true to enable local console result display. Defaults to false ]--
)
<#------------------------------------------------------------------------------ 
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
                   $Script:ScriptVer = "3.00"    <#--[ Current version # used in script ]--
                   : 
------------------------------------------------------------------------------#>
<#PSScriptInfo 
.VERSION 3.00 
.AUTHOR Kenneth C. Mazie (kcmjr AT kcmjr.com) 
.DESCRIPTION 
Automatically loads specified Windows RSAT AD Admin tools using the user ID you specify in the GUI prompt. 
#>
#Requires -Version 5.1

Clear-Host 

#--[ For Testing ]-------------
#$Script:Console = $true
#------------------------------

#--[ Suppress Console ]-------------------------------------------------------
Add-Type -Name Window -Namespace Console -MemberDefinition ' 
[DllImport("Kernel32.dll")] 
public static extern IntPtr GetConsoleWindow(); 
 
[DllImport("user32.dll")] 
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow); 
' 
$consolePtr = [Console.Window]::GetConsoleWindow()
[Console.Window]::ShowWindow($consolePtr, 0)
#------------------------------------------------------------------------------

$ErrorActionPreference = "silentlycontinue"

$Script:Icon = [System.Drawing.SystemIcons]::Information
$Script:ReportBody = ""
$Script:ScriptName = ($MyInvocation.MyCommand.Name).split(".")[0] 
$Script:ConfigFile = $PSScriptRoot+'\'+$Script:ScriptName+'.xml'
$Script:Validated = $False
$DomainName = $env:USERDOMAIN       #--[ Pulls local domain as an alternate if the user leaves it out ]-------

#--[ Functions ]--------------------------------------------------------------
Function UpdateOutput {
    $Script:OutputBox.update()
    $Script:OutputBox.Select($OutputBox.Text.Length, 0)
    $Script:OutputBox.ScrollToCaret()
}

Function IsThereText ($TargetBox){
  if (($TargetBox.Text.Length -ge 8)){ 
    Return $true
  }else{
    Return $false
  }
}

#--[ End of Functions ]---------------------------------------------------------

#--[ Detect RSAT ]--------------------------------------------------------------
If (!(Get-Module -list activedirectory)){
    Add-Type -AssemblyName PresentationCore,PresentationFramework
    $ButtonType = [System.Windows.MessageBoxButton]::OKCancel
    $MessageIcon = [System.Windows.MessageBoxImage]::Error
    $MessageBody = "The RSAT (Remote Server Administration Tools) was not detected on this system.  Click OK to download the tools, or Cancel to exit."
    $MessageTitle = "RSAT Not Detected"
    $Result = [System.Windows.MessageBox]::Show($MessageBody,$MessageTitle,$ButtonType,$MessageIcon)
    If ($Result -eq "ok"){
        Start-Process "https://support.microsoft.com/en-us/help/2693643/remote-server-administration-tools-rsat-for-windows-operating-systems"
    }Else{
        #--[ Just Exit ]--
    }
Break
}
If (!(Get-module ActiveDirectory)){$Null = Import-Module ActiveDirectory}

#--[ User Credential Options ]--------------------------------------------------
    $UN = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name        #--[ Current User   ]--
    $DN = $UN.split("\")[0]     #--[ Current Domain ]--    

    #--[  See: https://www.powershellgallery.com/packages/CredentialsWithKey ]-------------
    $PasswordFile = "u:\aAESP.txt"                      #--[ Location and name of encrypted PWD file.  Edit as needed. ]--
    $KeyFile = "u:\aAESK.txt"                           #--[ Location and name of encrypted KEY file.  Edit as needed. ]--
    #--------------------------------------------------------------------------------------

    If (Test-Path $PasswordFile){
        $Base64String = (Get-Content $KeyFile)
        $ByteArray = [System.Convert]::FromBase64String($Base64String)
        #--[ Create a Credential Object ]--
        $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $UN, (Get-Content $PasswordFile | ConvertTo-SecureString -Key $ByteArray)
        #--[ Recovered Creds for Testing ]--
        $UN = $Credential.GetNetworkCredential().Username
        $DN = $Credential.GetNetworkCredential().Domain 
        $PW = $Credential.GetNetworkCredential().Password 
    }    

#--[ Load Saved Config ]--------------------------------------------------------   
$SaveFile = $PSScriptRoot+"/"+($MyInvocation.MyCommand.Name).split(".")[0]+".cfg" 
if (Test-Path $SaveFile){
    $ConfigIn = Get-Content $SaveFile
}

#--------------------------------[ Prep GUI ]----------------------------------- 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
$Script:ScreenSize = (Get-WmiObject -Class Win32_DesktopMonitor | Select-Object ScreenWidth,ScreenHeight)
$Script:Width = $Script:ScreenSize.ScreenWidth
$Script:Height = $Script:ScreenSize.ScreenHeight

#--[ Initialize Form Objects ]--------------------------------------------------
$Script:Form = New-Object System.Windows.Forms.Form  
$Script:FormLabelBox = new-object System.Windows.Forms.Label
$Script:UserCredLabel = New-Object System.Windows.Forms.Label 
$Script:UserIDTextBox = New-Object System.Windows.Forms.TextBox 
$Script:UserPwdTextBox = New-Object System.Windows.Forms.TextBox 
$Script:InfoBox = New-Object System.Windows.Forms.TextBox
$Script:OptLabel = New-Object System.Windows.Forms.Label 
$CheckBox1 = new-object System.Windows.Forms.checkbox
$CheckBox2 = new-object System.Windows.Forms.checkbox
$CheckBox3 = new-object System.Windows.Forms.checkbox
$CheckBox4 = new-object System.Windows.Forms.checkbox
$CheckBox5 = new-object System.Windows.Forms.checkbox
$CheckBox6 = new-object System.Windows.Forms.checkbox
$CheckBox7 = new-object System.Windows.Forms.checkbox
$CheckBox8= new-object System.Windows.Forms.checkbox
$CheckBox9 = new-object System.Windows.Forms.checkbox
$CheckBox10 = new-object System.Windows.Forms.checkbox
$CheckBox11 = new-object System.Windows.Forms.checkbox
$CheckBox12 = new-object System.Windows.Forms.checkbox
$CheckBox13 = new-object System.Windows.Forms.checkbox
$CheckBox14 = new-object System.Windows.Forms.checkbox
$CheckBox15 = new-object System.Windows.Forms.checkbox
$CheckBox16 = new-object System.Windows.Forms.checkbox
$CheckBox17 = new-object System.Windows.Forms.checkbox
$CheckBox18 = new-object System.Windows.Forms.checkbox
$CheckBox19 = new-object System.Windows.Forms.checkbox
$CheckBox20 = new-object System.Windows.Forms.checkbox
$Script:VerifyButton = new-object System.Windows.Forms.Button
$Script:CloseButton = new-object System.Windows.Forms.Button
$Script:ProcessButton = new-object System.Windows.Forms.Button

#--[ Define Form ]--------------------------------------------------------------
[int]$Script:FormWidth = 350
[int]$Script:FormHeight = 440
[int]$Script:FormHCenter = ($Script:FormWidth / 2)   # 170 Horizontal center point
[int]$Script:FormVCenter = ($Script:FormHeight / 2)  # 209 Vertical center point
[int]$Script:ButtonHeight = 25
[int]$Script:TextHeight = 20

#--[ Create Form ]---------------------------------------------------------------------
#$Script:Form = New-Object System.Windows.Forms.Form    
$Script:Form.size = New-Object System.Drawing.Size($Script:FormWidth,$Script:FormHeight)
$Script:Notify = New-Object system.windows.forms.notifyicon
$Script:Notify.icon = $Script:Icon              #--[ NOTE: Available tooltip icons are = warning, info, error, and none
$Script:Notify.visible = $true
[int]$Script:FormVTop = 0 
[int]$Script:ButtonLeft = 55
[int]$Script:ButtonTop = ($Script:FormHeight - 75)
$Script:Form.Text = "$Script:ScriptName v$Script:ScriptVer"
$Script:Form.StartPosition = "CenterScreen"
$Script:Form.KeyPreview = $true
$Script:Form.Add_KeyDown({if ($_.KeyCode -eq "Escape"){$Script:Form.Close();$Stop = $true}})
$Script:ButtonFont = new-object System.Drawing.Font("New Times Roman",9,[System.Drawing.FontStyle]::Bold)

#--[ Form Title Label ]-----------------------------------------------------------------
$BoxLength = 350
$LineLoc = 5
#$Script:FormLabelBox = new-object System.Windows.Forms.Label
$Script:FormLabelBox.Font = $Script:ButtonFont
$Script:FormLabelBox.Location = new-object System.Drawing.Size(($Script:FormHCenter-($BoxLength/2)-10),$LineLoc)
$Script:FormLabelBox.size = new-object System.Drawing.Size($BoxLength,$Script:ButtonHeight)
$Script:FormLabelBox.TextAlign = 2 
$Script:FormLabelBox.Text = "Windows AD RSAT tools with alternate credentials." #$Script:ScriptName
$Script:Form.Controls.Add($Script:FormLabelBox)

#--[ User Credential Label ]-------------------------------------------------------------
$BoxLength = 250
$LineLoc = 28
#$Script:UserCredLabel = New-Object System.Windows.Forms.Label 
$Script:UserCredLabel.Location = New-Object System.Drawing.Point(($Script:FormHCenter-($BoxLength/2)-10),$LineLoc)
$Script:UserCredLabel.Size = New-Object System.Drawing.Size($BoxLength,$Script:TextHeight) 
$Script:UserCredLabel.ForeColor = "DarkCyan"
$Script:UserCredLabel.Font = $Script:ButtonFont
$Script:UserCredLabel.Text = "Enter / Edit  YOUR Credentials Below:"
$Script:UserCredLabel.TextAlign = 2 
$Script:Form.Controls.Add($Script:UserCredLabel) 

#--[ User ID Text Input Box ]-------------------------------------------------------------
$BoxLength = 140
$LineLoc = 55
#$Script:UserIDTextBox = New-Object System.Windows.Forms.TextBox 
$Script:UserIDTextBox.Location = New-Object System.Drawing.Size(($Script:FormHCenter-158),$LineLoc)
$Script:UserIDTextBox.Size = New-Object System.Drawing.Size($BoxLength,$Script:TextHeight) 
$Script:UserIDTextBox.TabIndex = 2

If (Test-Path $PasswordFile){
    $Script:UserIDTextBox.Text = $DN+"\"+$UN
    $Script:UserIDTextBox.ForeColor = "Black"
}Else{
    $Script:UserIDTextBox.Text = "Your Domain/UserID"
    $Script:UserIDTextBox.ForeColor = "DarkGray"
}
$Script:UserIDTextBox.TextAlign = 2
$Script:UserIDTextBox.Enabled = $True
$Script:UserIDTextBox.Add_GotFocus({
    if ($Script:UserIDTextBox.Text -eq 'Your Domain/UserID') {
        $Script:UserIDTextBox.Text = ''
        $Script:UserIDTextBox.ForeColor = 'Black'
    }
})
$Script:UserIDTextBox.Add_LostFocus({
    if ($Script:UserIDTextBox.Text -eq '') {
        $Script:UserIDTextBox.Text = 'Your Domain/UserID'
        $Script:UserIDTextBox.ForeColor = 'Darkgray'
    }
})
$Script:Form.Controls.Add($Script:UserIDTextBox) 

#$Script:UserPwdTextBox = New-Object System.Windows.Forms.TextBox 
$Script:UserPwdTextBox.Location = New-Object System.Drawing.Size((($Script:FormHCenter-3)),$LineLoc)
$Script:UserPwdTextBox.Size = New-Object System.Drawing.Size($BoxLength,$Script:TextHeight) 
$Script:UserPwdTextBox.Text = $Script:DN
$Script:UserPwdTextBox.TabIndex = 3
$Script:UserPwdTextBox.ForeColor = "DarkGray"

If (Test-Path $PasswordFile){
    $Script:UserPwdTextBox.Text = "Your Password"
}Else{
    $Script:UserPwdTextBox.Text = "Your Password"
}
$Script:UserPwdTextBox.TextAlign = 2
$Script:UserPwdTextBox.Enabled = $True
$Script:UserPwdTextBox.Add_GotFocus({
    if ($Script:UserPwdTextBox.Text -eq 'Your Password') {
        $Script:UserPwdTextBox.Text = ''
        $Script:UserPwdTextBox.PasswordChar = '*'
        $Script:UserPwdTextBox.ForeColor = 'Black'
    }
})
$Script:UserPwdTextBox.Add_LostFocus({
    if ($Script:UserPwdTextBox.Text -eq '') {
        $Script:UserPwdTextBox.Text = 'Your Password'
        $Script:UserPwdTextBox.ForeColor = 'Darkgray'
    }
})
$Script:UserPwdTextBox.add_TextChanged({
    If (IsThereText $Script:UserPwdTextBox){
        $Script:VerifyButton.Enabled = $True
        $Script:InfoBox.ForeColor = "Green"
        $Script:VerifyButton.ForeColor = "Green"
        $Script:InfoBox.Text = "Click VERIFY to inspect the user."
    }Else{
        $Script:VerifyButton.Enabled = $False
        $Script:VerifyButton.Font.Bold = $False
        $Script:InfoBox.ForeColor = "Red"
        $Script:InfoBox.Text = "Adjust detected User ID above as needed."
        $Script:ProcessButton.Enabled = $False
    } 
})
$Script:Form.Controls.Add($Script:UserPwdTextBox) 

#--[ Information Box ]-------------------------------------------------------------------
$BoxLength = 280
$LineLoc = 90
#$Script:InfoBox = New-Object System.Windows.Forms.TextBox
$Script:InfoBox.Location = New-Object System.Drawing.Size((($Script:FormHCenter-($BoxLength/2))-10),$LineLoc)
$Script:InfoBox.Size = New-Object System.Drawing.Size($BoxLength,$Script:TextHeight) 
$Script:InfoBox.Text = "Adjust detected User ID above as needed."
$Script:InfoBox.Enabled = $True
$Script:InfoBox.ReadOnly = $True
$Script:InfoBox.TextAlign = 2
$Script:Form.Controls.Add($Script:InfoBox) 

#--[ Option Buttons ]--------------------------------------------------------------------

#--[ Option Button Label ]---------------------------------------------------------------
$BoxLength = 250
$LineLoc = 118
#$Script:OptLabel = New-Object System.Windows.Forms.Label 
$Script:OptLabel.Location = New-Object System.Drawing.Point(($Script:FormHCenter-($BoxLength/2)-10),$LineLoc)
$Script:OptLabel.Size = New-Object System.Drawing.Size($BoxLength,$Script:TextHeight) 
$Script:OptLabel.ForeColor = "Gray"
$Script:OptLabel.Font = $Script:ButtonFont
$Script:OptLabel.Text = "Select the tools you wish to load Below:"
$Script:OptLabel.TextAlign = 2 
$Script:Form.Controls.Add($Script:OptLabel) 
$CbLeft = 30
$CbRight = 175
$CbHeight = 145
$CbVar = 20
$CbBox = 145
#--[ Checkbox 01 ]--
#$CheckBox1 = new-object System.Windows.Forms.checkbox
$CheckBox1.Location = new-object System.Drawing.Size($CbLeft,$CbHeight)
$CheckBox1.Size = new-object System.Drawing.Size($CbBox,$Script:TextHeight)
$CheckBox1.Text = "AD Admin Center"
If ($ConfigIn -contains "cb01"){
    $CheckBox1.Checked = $True
}Else{
    $CheckBox1.Checked = $False
}
$CheckBox1.Enabled = $False 
$Form.Controls.Add($CheckBox1) 

#--[ Checkbox 02 ]--
#$CheckBox2 = new-object System.Windows.Forms.checkbox
$CheckBox2.Location = new-object System.Drawing.Size($CbRight,$CbHeight)
$CheckBox2.Size = new-object System.Drawing.Size($CbBox,$Script:TextHeight)
$CheckBox2.Text = 'AD Users && Computers'
If ($ConfigIn -contains "cb02"){
    $CheckBox2.Checked = $True
}Else{
    $CheckBox2.Checked = $False
}
$CheckBox2.Enabled = $False 
$Form.Controls.Add($CheckBox2) 
   
$CbHeight = $CbHeight+$CbVar
#--[ Checkbox 03 ]--
#$CheckBox3 = new-object System.Windows.Forms.checkbox
$CheckBox3.Location = new-object System.Drawing.Size($CbLeft,$CbHeight)
$CheckBox3.Size = new-object System.Drawing.Size($CbBox,$Script:TextHeight)
$CheckBox3.Text = "AD Domains && Trusts"
If ($ConfigIn -contains "cb03"){
    $CheckBox3.Checked = $True
}Else{
    $CheckBox3.Checked = $False
}
$CheckBox3.Enabled = $False 
$Form.Controls.Add($CheckBox3) 
   
#--[ Checkbox 04 ]--
#$CheckBox4 = new-object System.Windows.Forms.checkbox
$CheckBox4.Location = new-object System.Drawing.Size($CbRight,$CbHeight)
$CheckBox4.Size = new-object System.Drawing.Size($CbBox,$Script:TextHeight)
$CheckBox4.Text = "AD Sites && Services"
If ($ConfigIn -contains "cb04"){
    $CheckBox4.Checked = $True
}Else{
    $CheckBox4.Checked = $False
}
$CheckBox4.Enabled = $False 
$Form.Controls.Add($CheckBox4) 

$CbHeight = $CbHeight+$CbVar
#--[ Checkbox 05 ]--
#$CheckBox5 = new-object System.Windows.Forms.checkbox
$CheckBox5.Location = new-object System.Drawing.Size($CbLeft,$CbHeight)
$CheckBox5.Size = new-object System.Drawing.Size($CbBox,$Script:TextHeight)
$CheckBox5.Text = "Group Policy Mgr"
If ($ConfigIn -contains "cb05"){
    $CheckBox5.Checked = $True
}Else{
    $CheckBox5.Checked = $False
}
$CheckBox5.Enabled = $False 
$Form.Controls.Add($CheckBox5) 
         
#--[ Checkbox 06 ]--
#$CheckBox6 = new-object System.Windows.Forms.checkbox
$CheckBox6.Location = new-object System.Drawing.Size($CbRight,$CbHeight)
$CheckBox6.Size = new-object System.Drawing.Size($CbBox,$Script:TextHeight)
$CheckBox6.Text = "DHCP Manager"
If ($ConfigIn -contains "cb06"){
    $CheckBox6.Checked = $True
}Else{
    $CheckBox6.Checked = $False
}
$CheckBox6.Enabled = $False 
$Form.Controls.Add($CheckBox6) 

$CbHeight = $CbHeight+$CbVar
#--[ Checkbox 07 ]--
#$CheckBox7 = new-object System.Windows.Forms.checkbox
$CheckBox7.Location = new-object System.Drawing.Size($CbLeft,$CbHeight)
$CheckBox7.Size = new-object System.Drawing.Size($CbBox,$Script:TextHeight)
$CheckBox7.Text = "DNS Manager"
If ($ConfigIn -contains "cb07"){
    $CheckBox7.Checked = $True
}Else{
    $CheckBox7.Checked = $False
}
$CheckBox7.Enabled = $False 
$Form.Controls.Add($CheckBox7) 
         
#--[ Checkbox 08 ]--
#$CheckBox8 = new-object System.Windows.Forms.checkbox
$CheckBox8.Location = new-object System.Drawing.Size($CbRight,$CbHeight)
$CheckBox8.Size = new-object System.Drawing.Size($CbBox,$Script:TextHeight)
$CheckBox8.Text = "DFS Manager"
If ($ConfigIn -contains "cb08"){
    $CheckBox8.Checked = $True
}Else{
    $CheckBox8.Checked = $False
}
$CheckBox8.Enabled = $False 
$Form.Controls.Add($CheckBox8) 

$CbHeight = $CbHeight+$CbVar
#--[ Checkbox 09 ]--
#$CheckBox9 = new-object System.Windows.Forms.checkbox
$CheckBox9.Location = new-object System.Drawing.Size($CbLeft,$CbHeight)
$CheckBox9.Size = new-object System.Drawing.Size($CbBox,$Script:TextHeight)
$CheckBox9.Text = "Volume Act Tool"
If ($ConfigIn -contains "cb09"){
    $CheckBox9.Checked = $True
}Else{
    $CheckBox9.Checked = $False
}
$CheckBox9.Enabled = $False 
$Form.Controls.Add($CheckBox9) 
         
#--[ Checkbox 10 ]--
#$CheckBox10 = new-object System.Windows.Forms.checkbox
$CheckBox10.Location = new-object System.Drawing.Size($CbRight,$CbHeight)
$CheckBox10.Size = new-object System.Drawing.Size($CbBox,$Script:TextHeight)
$CheckBox10.Text = "Printer Mananger"
If ($ConfigIn -contains "cb10"){
    $CheckBox10.Checked = $True
}Else{
    $CheckBox10.Checked = $False
}
$CheckBox10.Enabled = $False 
$Form.Controls.Add($CheckBox10) 

$CbHeight = $CbHeight+$CbVar
#--[ Checkbox 11 ]--
#$CheckBox11 = new-object System.Windows.Forms.checkbox
$CheckBox11.Location = new-object System.Drawing.Size($CbLeft,$CbHeight)
$CheckBox11.Size = new-object System.Drawing.Size($CbBox,$Script:TextHeight)
$CheckBox11.Text = "NLB Manager"
$CheckBox11.Checked = $False
$CheckBox11.Enabled = $False 
$Form.Controls.Add($CheckBox11) 
         
#--[ Checkbox 12 ]--
#$CheckBox12 = new-object System.Windows.Forms.checkbox
$CheckBox12.Location = new-object System.Drawing.Size($CbRight,$CbHeight)
$CheckBox12.Size = new-object System.Drawing.Size($CbBox,$Script:TextHeight)
$CheckBox12.Text = "Local Sec Policy"
$CheckBox12.Checked = $False
$CheckBox12.Enabled = $False 
$Form.Controls.Add($CheckBox12) 

$CbHeight = $CbHeight+$CbVar
#--[ Checkbox 13 ]--
#$CheckBox13 = new-object System.Windows.Forms.checkbox
$CheckBox13.Location = new-object System.Drawing.Size($CbLeft,$CbHeight)
$CheckBox13.Size = new-object System.Drawing.Size($CbBox,$Script:TextHeight)
$CheckBox13.Text = "iSCSI Manager"
$CheckBox13.Checked = $False
$CheckBox13.Enabled = $False 
$Form.Controls.Add($CheckBox13) 
         
#--[ Checkbox 14 ]--
#$CheckBox14 = new-object System.Windows.Forms.checkbox
$CheckBox14.Location = new-object System.Drawing.Size($CbRight,$CbHeight)
$CheckBox14.Size = new-object System.Drawing.Size($CbBox,$Script:TextHeight)
$CheckBox14.Text = "File Srv Resrc Mgr"
$CheckBox14.Checked = $False
$CheckBox14.Enabled = $False 
$Form.Controls.Add($CheckBox14) 

$CbHeight = $CbHeight+$CbVar
#--[ Checkbox 15 ]-- 
#$CheckBox15 = new-object System.Windows.Forms.checkbox
$CheckBox15.Location = new-object System.Drawing.Size($CbLeft,$CbHeight)
$CheckBox15.Size = new-object System.Drawing.Size($CbBox,$Script:TextHeight)
$CheckBox15.Text = "Failover Cluster Mgr"
$CheckBox15.Checked = $False
$CheckBox15.Enabled = $False 
$Form.Controls.Add($CheckBox15) 
         
#--[ Checkbox 16 ]--
#$CheckBox16 = new-object System.Windows.Forms.checkbox
$CheckBox16.Location = new-object System.Drawing.Size($CbRight,$CbHeight)
$CheckBox16.Size = new-object System.Drawing.Size($CbBox,$Script:TextHeight)
$CheckBox16.Text = "Cluster Aware Update"
$CheckBox16.Checked = $False
$CheckBox16.Enabled = $False 
$Form.Controls.Add($CheckBox16) 

$CbHeight = $CbHeight+$CbVar
#--[ Checkbox 17 ]--
#$CheckBox17 = new-object System.Windows.Forms.checkbox
$CheckBox17.Location = new-object System.Drawing.Size($CbLeft,$CbHeight)
$CheckBox17.Size = new-object System.Drawing.Size($CbBox,$Script:TextHeight)
$CheckBox17.Text = "Certificate Authority"
$CheckBox17.Checked = $False
$CheckBox17.Enabled = $False 
$Form.Controls.Add($CheckBox17) 
         
#--[ Checkbox 18 ]--
#$CheckBox18 = new-object System.Windows.Forms.checkbox
$CheckBox18.Location = new-object System.Drawing.Size($CbRight,$CbHeight)
$CheckBox18.Size = new-object System.Drawing.Size($CbBox,$Script:TextHeight)
$CheckBox18.Text = "ADSI Editor"
$CheckBox18.Checked = $False
$CheckBox18.Enabled = $False 
$Form.Controls.Add($CheckBox18) 

$CbHeight = $CbHeight+$CbVar
#--[ Checkbox 19 ]--
#$CheckBox19 = new-object System.Windows.Forms.checkbox
$CheckBox19.Location = new-object System.Drawing.Size($CbLeft,$CbHeight)
$CheckBox19.Size = new-object System.Drawing.Size($CbBox,$Script:TextHeight)
$CheckBox19.Text = "Computer Manager"
$CheckBox19.Checked = $False
$CheckBox19.Enabled = $False 
$Form.Controls.Add($CheckBox19) 
         
#--[ Checkbox 20 ]--
#$CheckBox20 = new-object System.Windows.Forms.checkbox
$CheckBox20.Location = new-object System.Drawing.Size($CbRight,$CbHeight)
$CheckBox20.Size = new-object System.Drawing.Size($CbBox,$Script:TextHeight)
$CheckBox20.Text = "Unused"
$CheckBox20.Checked = $False
$CheckBox20.Enabled = $False 
$Form.Controls.Add($CheckBox20) 
       #>

#--[ VERIFY Button ]-------------------------------------------------------------------------
$BoxLength = 100
$LineLoc = $FormHeight-80
#$Script:VerifyButton = new-object System.Windows.Forms.Button
$Script:VerifyButton.Location = new-object System.Drawing.Size(($Script:FormHCenter-($BoxLength/2)-110),$LineLoc)
$Script:VerifyButton.Size = new-object System.Drawing.Size($BoxLength,$Script:ButtonHeight)
$Script:VerifyButton.TabIndex = 4
$Script:VerifyButton.Text = "Verify"
$Script:VerifyButton.Enabled = $False
$Script:VerifyButton.Font = $Script:ButtonFont
$Script:VerifyButton.Add_Click({
    $ErrorActionPreference = "stop"
    If ((($Script:UserIDTextBox.Text).Split("\")).count -lt 2 ){
        $Script:UserIDTextBox.Text = $env:USERDOMAIN.ToLower()+'\'+$Script:UserIDTextBox.Text
    }
    $Script:InfoBox.TextAlign = 2
    $Script:InfoBox.Text = "Checking..."
    $Password = ConvertTo-SecureString -String $Script:UserPwdTextBox.Text -AsPlainText -Force
    $Script:SC = New-Object System.Management.Automation.PSCredential($Script:UserIDTextBox.Text,$Password)
    $Script:VerifyButton.Text = "Verify"
    $Script:VerifyButton.Enabled = $False

    Add-Type -AssemblyName System.DirectoryServices.AccountManagement 
    $DomainName = $Script:SC.username.Split("\")[0]
    $UserName = $Script:SC.username.Split("\")[1]
    $Password = $Script:SC.GetNetworkCredential().Password
    $ContextType = [System.DirectoryServices.AccountManagement.ContextType]::Domain
    $PrincipalContext = New-Object System.DirectoryServices.AccountManagement.PrincipalContext $ContextType,$Domain
    $Result = $PrincipalContext.ValidateCredentials($UserName,$Password)
    Start-Sleep -sec 3

    $UserProperties = Get-Aduser $UserName -Properties *

    If ($Result){
        $Script:InfoBox.Text = "Verified.  Select tools then click Execute."
        $Script:ProcessButton.ForeColor = "Green"
        $Script:ProcessButton.Enabled = $True
        $CheckBox1.Enabled = $True
        $CheckBox2.Enabled = $True
        $CheckBox3.Enabled = $True
        $CheckBox4.Enabled = $True
        $CheckBox5.Enabled = $True
        $CheckBox6.Enabled = $True
        $CheckBox7.Enabled = $True
        $CheckBox8.Enabled = $True
        $CheckBox9.Enabled = $True
        $CheckBox10.Enabled = $True
        $CheckBox11.Enabled = $True
        $CheckBox12.Enabled = $True
        $CheckBox13.Enabled = $True
        $CheckBox14.Enabled = $True
        $CheckBox15.Enabled = $True
        $CheckBox16.Enabled = $True
        $CheckBox17.Enabled = $True
        $CheckBox18.Enabled = $True
        $CheckBox19.Enabled = $True
        $CheckBox20.Enabled = $True
        $Script:OptLabel.ForeColor = "DarkCyan"
        $Script:OptLabel.Enabled = $True
        $Script:Validated = $True
    }Else{
        If ($UserProperties.LockedOut){
            $Script:InfoBox.Text = "Failed. User is Locked Out."            
        }ElseIf (!($UserProperties.Enabled)){
            $Script:InfoBox.Text = "Failed. User is disabled."
        }Else{    
            $Script:InfoBox.Text = "Failed. Verify Password"
        }
    } 
    $ErrorActionPreference = "silentlycontinue"
})
$Script:Form.Controls.Add($Script:VerifyButton)

#--[ CLOSE Button ]------------------------------------------------------------------------
#$Script:CloseButton = new-object System.Windows.Forms.Button
$Script:CloseButton.Location = New-Object System.Drawing.Size(($Script:FormHCenter-($BoxLength/2)-8),$LineLoc)
$Script:CloseButton.Size = new-object System.Drawing.Size($BoxLength,$Script:ButtonHeight)
$Script:CloseButton.TabIndex = 1
$Script:CloseButton.Text = "Cancel/Close"
$Script:CloseButton.Add_Click({

    $Script:Form.close()
    $Stop = $true
})
$Script:Form.Controls.Add($Script:CloseButton)

#--[ EXECUTE Button ]------------------------------------------------------------------------
#$Script:ProcessButton = new-object System.Windows.Forms.Button
$Script:ProcessButton.Location = new-object System.Drawing.Size(($Script:FormHCenter-($BoxLength/2)+94),$LineLoc)
$Script:ProcessButton.Size = new-object System.Drawing.Size($BoxLength,$Script:ButtonHeight)
$Script:ProcessButton.Text = "Execute"
$Script:ProcessButton.Enabled = $False
$Script:ProcessButton.Font = $Script:ButtonFont
$Script:ProcessButton.TabIndex = 5
$Script:ProcessButton.Add_Click({

#--[ RSAT Tool Definitions ]------------------------------------------------------------------
$ToolList = @()                     #--[ Array of separate items to allow easy addition or removal. Comment out lines for tools you don't want loaded ]--
If ($CheckBox1.Checked){
    $ToolList += "dsac.exe"            #--[ Active Directory Administrative Center ]--
    $ConfigOut = "CB01`n"
}    
If ($CheckBox2.Checked){
    $ToolList += "dsa.msc"              #--[ Active Directory Users and Computers ]--
    $ConfigOut += "CB02`n"
}    
If ($CheckBox3.Checked){
    $ToolList += "domain.msc"          #--[ Active Directory Domains and Trusts ]-- 
    $ConfigOut += "CB03`n"
}
If ($CheckBox4.Checked){
    $ToolList += "dssite.msc"          #--[ Active Directory Sites and Services ]--
    $ConfigOut += "CB04`n"
}
If ($CheckBox5.Checked){
    $ToolList += "gpmc.msc"             #--[ Group Policy Management ]--
    $ConfigOut += "CB05`n"
}
If ($CheckBox6.Checked){
    $ToolList += "dhcpmgmt.msc"         #--[ DHCP Manager ]--
    $ConfigOut += "CB06`n"
}
If ($CheckBox7.Checked){
    $ToolList += "dnsmgmt.msc"          #--[ DNS Manager ]--
    $ConfigOut += "CB07`n"
}
If ($CheckBox8.Checked){
    $ToolList += "dfsmgmt.msc"         #--[ DFS Manager ]--
    $ConfigOut += "CB08`n"
}
If ($CheckBox9.Checked){
    $ToolList += "vmw.exe"             #--[ Volume Activation Tools ]--
    $ConfigOut += "CB09`n"
}
If ($CheckBox10.Checked){
    $ToolList += "printmanagement.msc" #--[ Print Management ]--
    $ConfigOut += "CB10`n"
}
If ($CheckBox11.Checked){
    $ToolList += "nlbmgr.exe"          #--[ Network Load Balancing Manager ]--
    $ConfigOut += "CB11`n"
}
If ($CheckBox12.Checked){
    $ToolList += "secpol.msc /s"       #--[ Local Security Policy ]--
    $ConfigOut += "CB12`n"
}
If ($CheckBox13.Checked){
    $ToolList += "iscsicpl.exe"        #--[ iSCSI Initiator ]--
    $ConfigOut += "CB13`n"
}
If ($CheckBox14.Checked){
    $ToolList += "fsrm.msc"            #--[ File Server Resource Manager ]--
    $ConfigOut += "CB14`n"
}
If ($CheckBox15.Checked){
    $ToolList += "Cluadmin.msc"        #--[ Failover Cluster Manager ]--
    $ConfigOut += "CB15`n"
}
If ($CheckBox16.Checked){
    $ToolList += "ClusterUpdateUI.exe" #--[ Cluster Aware Updating ]--
    $ConfigOut += "CB16`n"
}
If ($CheckBox17.Checked){
    $ToolList += "certsrv.msc"         #--[ Certification Authority ]--
    $ConfigOut += "CB17`n"
}
If ($CheckBox18.Checked){
    $ToolList += "adsiedit.msc"        #--[ ADSI Edit ]--
    $ConfigOut += "CB18`n"
}
If ($CheckBox18.Checked){
    $ToolList += "compmgmt.msc /s"     #--[ Computer Manager ]--
    $ConfigOut += "CB19`n"
}
If ($CheckBox20.Checked){
    $ToolList += "notepad.exe"        #--[ unused ]--
    $ConfigOut += "CB20`n"
}
$ConfigOut | Out-File $SaveFile -Force:$true -Confirm:$False

#-------------------------------------------------------------------------------------------------

$ToolPath = "c:\windows\system32\"
[Environment]::CurrentDirectory = (Get-Location -PSProvider FileSystem).ProviderPath

$Result = disable-UEV 
#--[ Microsoft UE-V (User Experience Virtualization) is a tool that enables users to move from one Windows ]--
#--[ device to another and maintain the same operating system (OS) and applications settings. (i.e roaming) ]--
If ($Result -Like "*successfully*"){
    If ($Console){Write-host $Result -Foregroundcolor Green}
}Else{
    If ($Console){Write-Host "There was an error disabling UE-V" -ForegroundColor Red}
}

ForEach ($Tool in $ToolList){
    #If (!(Get-Process $Tool.Split(".")[0])){ --[ Unfortunately most of these use the MMC which is the process detected ]--
    If ($Console){write-host "`n-------------------------------------------------------------------`n"}
    If ($Tool.Split(" ").count -gt 1){    #--[ Check if there is a space in the tool command meaning some sort of argument ]--
        $Arg = $Tool.Split(" ")[1]
        $Tool = $Tool.Split(" ")[0]            
        If ($Tool.Split('.')[1] -eq "exe"){
            $Command = 'Start-Process "'+($ToolPath+$Tool+" "+$Arg)+'" -verb runas -WindowStyle hidden'
        }Else{
            $Command = 'Start-Process mmc.exe -verb runas -argument "'+($ToolPath+$Tool+" "+$Arg)+'" -WindowStyle hidden'
        }    
    }Else{
        If ($Tool.Split('.')[1] -eq "exe"){
            $Command = 'Start-Process '+($ToolPath+$Tool)+' -verb runas -WindowStyle hidden'
        }Else{
            $Command = 'Start-Process mmc.exe -verb runas -argument '+($ToolPath+$Tool)+' -WindowStyle hidden'
        }    
    }
    If (Test-Path -Path ($ToolPath+$Tool)) {
        Start-Process powershell.exe -Credential $Script:SC  -ArgumentList $Command -WindowStyle Hidden #-NoNewWindow
        If ($Console){write-host "Tool $Tool is starting..." -ForegroundColor Green}
    }Else{
        If ($Console){write-host "Tool $Tool was not found..." -ForegroundColor Red}
    }  
}

$Script:Form.Close()
})
$Script:Form.Controls.Add($Script:ProcessButton)

#--[ Open Form ]--
$Script:Form.topmost = $true
$Script:Form.Add_Shown({$Script:Form.Activate()})
[void] $Script:Form.ShowDialog()

if($Script:Stop -eq $true){$Script:Form.Close();break;break}

<#--[ Shortcut details ]---------------------------------------- 
To prevent any pop-up commend windows use the following in the "Target" field of a shortcut 
 
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -file "c:\scripts\RSAT-As-Admin.ps1" -windowstyle hidden -nonewwindow 
 
Adjust the path to the script as needed. 
 
Set the "Run" option to "Minimized" 
 
An icon will appear briefly in the taskbar while assemblies load, then disappear as the GUI loads. 
 
#>