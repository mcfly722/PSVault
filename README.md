# PSVault

All credentials encrypted with certificate (hardware token could be used) and signed from substitute changes.

### How to use it

#### 1. Import psm module
```
import-module <full path>\psvault.psm1
```

#### 2. Add your new credentials for your program
```
Add-ToVault `
  -tag '-mybiz' `
  -description 'git push to myrepository.biz' `
  -exeTool 'C:\Program Files\Git\bin\git.exe' `
  -includeForParameters $('push','pull') `
  -parametersToEncrypt $('https://username:password@myrepository.biz/file.git')
```


* <b>tag</b> - this is argument for easy access to your credentials. Should be as short as possible, cause you will specify it every time from command line<br>f.e. like this:
```
git push -mybiz
```
It means that your <b>https://username:password@myrepository.biz/file.git</b> parameter would be added to final git call.<br><br>
Finally your arguments would be replaced and original tool would be called with sensitive data:
```
git push https://username:password@myrepository.biz/file.git
```
* <b>description</b> - short description to understand what is this credentials is used for. This description is visible on credentials choose dialog when several options are acceptable.
* <b>execTool</b> - original tool which have arguments, that should be protected. If you don't specify this parameter, module will opens dialog and ask you to choose your exe tool.
* <b>includeForParameters</b> - array of string parameters defines when sensitive data should be appended. (in this example it should be applied for <b>push</b> and <b>pull</b> git operations)
* <b>excludeForParamenters</b> - array of string parameters defines when sensitive data should be skipped (excluding have more priority than including)
* <b>paramentersToEncrypt</b> - array of string parameters which would be appended to the end of executed command (to extract this sensitive parameters you should use private key)
* <b>encryptionCertificate</b> - certificate with private key that should be used to encrypt and sign your sensitive data. If you do not specify this parameter, module will offer you to choose appropriate certificate from available list.



#### 3. List all credentials from vault
```
Get-VaultCredentials
```
#### 4. Delete credentials from vault
```
Get-VaultCredentials | ? {< deletion filter >} | % {Remove-FromVault}
```

### Signature
All sensitive data stores in <b>%USERPROFILE%\\.psvault</b> file in simple json format. Each credential are signed with your encryption private key, so you can't replace any values from any credential (it is additional protection to do not replace path to your <b>exeTool</b> on harmful one).<br>Credentials could be copied from json to another one without change, it is allowed.
