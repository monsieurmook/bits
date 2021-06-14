#Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#https://github.com/JetBrains/intellij-community/blob/0e2aa4030ee763c9b0c828f0b5119f4cdcc66f35/platform/credential-store/src/keePass/masterKey.kt
#AES( DPAPI(KDBXkey)[iv len, iv, data], hard coded key)

Add-Type -AssemblyName System.Security

#fetch encrypted master password file, split on base64, convert
#$fileName = $env:APPDATA + "\JetBrains\PyCharm2021.1\c.pwd"
$fileName = $Args[0]
$separator = " "
$encryptedBytes = [IO.File]::ReadAllText($fileName).Split($separator,5) | Select-Object -Last 1
Write-Host ('parseKDBKey.ps1 c:\users\username\directory\intellij\c.pwd')

Write-Host ('c.pwd file contents')
Write-Host ('Protected Bytes: ' + $encryptedBytes)

Write-Host ('')
Write-Host ('DPAPI')
$encryptedBytes = [Convert]::FromBase64String($encryptedBytes)
$unprotectedBytes = [Security.Cryptography.ProtectedData]::Unprotect( $encryptedBytes, $null, 1 )
Write-Host ('Unprotected Data: ' + $unprotectedBytes)

#val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding")
#no support for PKCS5, so we set padding to None/Zeros and strip them from the output in Decrypt-String
function Create-AesManagedObject($key, $IV) {
    $aesManaged = New-Object "System.Security.Cryptography.AesManaged"
    $aesManaged.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $aesManaged.Padding = [System.Security.Cryptography.PaddingMode]::Zeros
    $aesManaged.BlockSize = 128
    $aesManaged.KeySize = 256
    $aesManaged.IV = $IV
    $aesManaged.Key = $key
    $aesManaged
}

function Decrypt-String($key, $iv, $encryptedString) {
    $aesManaged = Create-AesManagedObject $key $iv
    $decryptor = $aesManaged.CreateDecryptor();
    $unencryptedData = $decryptor.TransformFinalBlock($encryptedString, 20, $encryptedString.Length - 20);
    $aesManaged.Dispose()
    #trim the padding 5 ints, it'll always be 5 bytes of 5 because the key will always be 512 bytes long and base64 encoding will produce a static length output for input of the same size...
    $MasterKey = [System.Text.Encoding]::UTF8.GetString($unencryptedData).Trim([char]5)
    return $MasterKey
}

Write-Host ('')
Write-Host ('AES/CBC/PKCS5')
#$AESPassword=ASCII.GetBytes('Proxy Config Sec')
#https://github.com/JetBrains/intellij-community/blob/0e2aa4030ee763c9b0c828f0b5119f4cdcc66f35/platform/credential-store/src/kdbx/kdbx.kt
#https://github.com/JetBrains/intellij-community/blob/0e2aa4030ee763c9b0c828f0b5119f4cdcc66f35/platform/credential-store/src/EncryptionSupport.kt
$AESPassword = (80, 114, 111, 120, 121, 32, 67, 111, 110, 102, 105, 103, 32, 83, 101, 99)

Write-Host ('AESPassword: ' + $AESPassword)
$AESIV = $unprotectedBytes[4..19]
Write-Host ('AES256 IV: ' + $AESIV)
Write-Host ('AES Encrypted Data: ' + $unprotectedBytes)

#this is the original 512 bytes of securerandom that consitutes the master key
$MasterKey = Decrypt-String $AESPassword $AESIV $unprotectedBytes
Write-Host ('Master Key: ' + $MasterKey)

Write-Host ('')
Write-Host ('KeePass Database Key = sha256(MasterKey)')
#the KeePass Database key is a sha256 digest of the master key
$KdbxKey = [system.Text.Encoding]::UTF8.GetBytes($MasterKey) 
$hasher = [System.Security.Cryptography.HashAlgorithm]::Create('sha256')
$KdbxKey = $hasher.ComputeHash($hasher.ComputeHash($KdbxKey))
Write-Host ('KeePass DB Key: ' + $KdbxKey)
