#Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#https://github.com/JetBrains/intellij-community/blob/0e2aa4030ee763c9b0c828f0b5119f4cdcc66f35/platform/credential-store/src/keePass/masterKey.kt
#AES( DPAPI(KDBXkey)[iv len, iv, data], hard coded key)

Add-Type -AssemblyName System.Security

#fetch encrypted master password file, split on base64, convert
#$fileName = $env:APPDATA + "\JetBrains\PyCharm2021.1\c.pwd"
$fileName = $Args[0]
$fileName2 = $Args[1]

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
#https://gist.github.com/ctigeek/2a56648b923d198a6e60
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
	$aesManaged.Dispose()
	return $MasterKey
}

function Encrypt-String($key, $unencryptedBytes) {
    $aesManaged = Create-AesManagedObject $key
    $encryptor = $aesManaged.CreateEncryptor()
    $encryptedData = $encryptor.TransformFinalBlock($unencryptedBytes, 0, $unencryptedBytes.Length);
    #[byte[]] $fullData = $aesManaged.IV + $encryptedData
    $aesManaged.Dispose()
    [System.Convert]::ToBase64String($fullData)
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

Write-Host ('')
Write-Host ('KeePass DB Header')

$KeePassDB = [System.IO.File]::ReadAllBytes($fileName2)

$MASTER_SEED = $KeePassDB[41..72]
Write-Host ('MASTER_SEED: ' + $MASTER_SEED)

$TRANSFORM_SEED = $KeePassDB[76..107]
Write-Host ('TRANSFORM_SEED: ' + $TRANSFORM_SEED)

$TRANSFORM_ROUNDS = [bitconverter]::ToInt64($KeePassDB[111..118],0)
Write-Host ('TRANSFORM_ROUNDS: ' + $TRANSFORM_ROUNDS)

$ENCRYPTION_IV = $KeePassDB[122..137]
Write-Host ('ENCRYPTION_IV: ' + $ENCRYPTION_IV)


$PROTECTED_STREAM_KEY = $KeePassDB[141..172]
Write-Host ('PROTECTED_STREAM_KEY: ' + $PROTECTED_STREAM_KEY)

#src/kdbx/KdbxHeader.kt
#https://gist.github.com/lgg/e6ccc6e212d18dd2ecd8a8c116fb1e45

#AES tseed as key
$aesManaged = New-Object "System.Security.Cryptography.AesManaged"
$aesManaged.Mode = [System.Security.Cryptography.CipherMode]::ECB
$aesManaged.Padding = [System.Security.Cryptography.PaddingMode]::Zeros
$aesManaged.BlockSize = 128
$aesManaged.KeySize = 256
$aesManaged.Key = $TRANSFORM_SEED
$encryptor = $aesManaged.CreateEncryptor()
$TransformedKey = $KdbxKey

for($i = 0; $i -lt $TRANSFORM_ROUNDS; $i++){
  $TransformedKey = $encryptor.TransformFinalBlock($TransformedKey, 0, $TransformedKey.Length);
}
$aesManaged.Dispose()
$hasher = [System.Security.Cryptography.HashAlgorithm]::Create('sha256')
$TransformedKeyDigest = $hasher.ComputeHash($TransformedKey)

Write-Host ('Transformed Key Digest: ' + $TransformedKeyDigest)

$hasher = [System.Security.Cryptography.HashAlgorithm]::Create('sha256')
$CompoundKey = $hasher.ComputeHash($MASTER_SEED + $TransformedKeyDigest)

Write-Host ('Compound Key: ' + $CompoundKey)
