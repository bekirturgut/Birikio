param(
    [string]$ApkPath,
    [switch]$RequireNewVersion,
    [string]$KeystorePath = (Join-Path $env:USERPROFILE '.android\debug.keystore')
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$identity = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'update_identity.json') -Raw | ConvertFrom-Json

function Assert-Match([string]$value, [string]$pattern, [string]$message) {
    if ($value -notmatch $pattern) { throw $message }
}

$gradle = Get-Content -LiteralPath (Join-Path $repo 'android\app\build.gradle.kts') -Raw
$store = Get-Content -LiteralPath (Join-Path $repo 'lib\data\store.dart') -Raw
$backup = Get-Content -LiteralPath (Join-Path $repo 'lib\data\backup.dart') -Raw
$mainActivity = Get-Content -LiteralPath (Join-Path $repo 'android\app\src\main\kotlin\com\bekirturgut\birikio\MainActivity.kt') -Raw
$widgets = Get-Content -LiteralPath (Join-Path $repo 'android\app\src\main\kotlin\com\bekirturgut\birikio\BirikioWidgets.kt') -Raw
$pubspec = Get-Content -LiteralPath (Join-Path $repo 'pubspec.yaml') -Raw
$package = [regex]::Escape($identity.applicationId)
$storageKey = [regex]::Escape($identity.storageKey)
$backupFormat = [regex]::Escape($identity.backupFormat)
Assert-Match $gradle "namespace\s*=\s*`"$package`"" 'Android namespace değişmiş.'
Assert-Match $gradle "applicationId\s*=\s*`"$package`"" 'Android applicationId değişmiş.'
Assert-Match $store "storageKey\s*=\s*'$storageKey'" 'Yerel veri anahtarı değişmiş.'
Assert-Match $backup "backupFormat\s*=\s*'$backupFormat'" 'JSON yedek biçimi değişmiş.'
Assert-Match $mainActivity "package\s+$package" 'MainActivity Kotlin paket adı değişmiş.'
Assert-Match $widgets "package\s+$package" 'Widget Kotlin paket adı değişmiş.'
if ($pubspec -notmatch '(?m)^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$') {
    throw 'pubspec.yaml sürüm biçimi geçersiz.'
}
$versionName = $Matches[1]
$versionCode = [int]$Matches[2]
if ($versionCode -lt [int]$identity.lastDeliveredVersionCode) {
    throw "versionCode son teslimden küçük olamaz: $versionCode."
}
if ($RequireNewVersion -and $versionCode -le [int]$identity.lastDeliveredVersionCode) {
    throw "Yeni APK için versionCode $($identity.lastDeliveredVersionCode) değerinden büyük olmalı. Şu an: $versionCode."
}

if (-not (Test-Path -LiteralPath $KeystorePath -PathType Leaf)) {
    throw "Eski imza anahtarı bulunamadı: $KeystorePath. Yeni anahtar üretme; aynı imza olmadan güncelleme mümkün değil."
}
$keytool = if ($env:JAVA_HOME -and (Test-Path -LiteralPath (Join-Path $env:JAVA_HOME 'bin\keytool.exe'))) {
    Join-Path $env:JAVA_HOME 'bin\keytool.exe'
} elseif (Test-Path -LiteralPath 'C:\Program Files\Android\Android Studio1\jbr\bin\keytool.exe') {
    'C:\Program Files\Android\Android Studio1\jbr\bin\keytool.exe'
} else {
    (Get-Command keytool -ErrorAction Stop).Source
}
$password = if ($env:BIRIKIO_KEYSTORE_PASSWORD) { $env:BIRIKIO_KEYSTORE_PASSWORD } else { 'android' }
$keyInfo = (& $keytool -list -v -keystore $KeystorePath -alias $identity.signingAlias -storepass $password 2>&1) | Out-String
if ($LASTEXITCODE -ne 0) { throw 'İmza anahtarı okunamadı.' }
if ($keyInfo -notmatch 'SHA256:\s*([0-9A-Fa-f:]+)') {
    throw 'Anahtar sertifikası okunamadı.'
}
$keyFingerprint = $Matches[1].Replace(':', '').ToLowerInvariant()
if ($keyFingerprint -ne $identity.signingCertificateSha256) {
    throw "İmza uyuşmuyor: $keyFingerprint. Beklenen: $($identity.signingCertificateSha256)."
}

if ($ApkPath) {
    $apk = (Resolve-Path -LiteralPath $ApkPath).Path
    $sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } elseif ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } else { Join-Path $env:LOCALAPPDATA 'Android\sdk' }
    $tools = Get-ChildItem -LiteralPath (Join-Path $sdk 'build-tools') -Directory | Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
    if (-not $tools) { throw 'Android build-tools bulunamadı.' }
    $apksigner = Join-Path $tools.FullName 'apksigner.bat'
    $aapt = Join-Path $tools.FullName 'aapt.exe'
    $signatures = (& $apksigner verify --print-certs $apk 2>&1) | Out-String
    if ($LASTEXITCODE -ne 0) { throw 'APK imza doğrulamasından geçmedi.' }
    $certificates = [regex]::Matches($signatures, 'Signer #\d+ certificate SHA-256 digest:\s*([0-9a-fA-F]+)')
    if ($certificates.Count -ne 1 -or $certificates[0].Groups[1].Value.ToLowerInvariant() -ne $identity.signingCertificateSha256) {
        throw 'APK tam olarak beklenen tek sertifikayla imzalanmamış.'
    }
    $badging = (& $aapt dump badging $apk 2>&1) | Out-String
    if ($LASTEXITCODE -ne 0) { throw 'APK paket bilgisi okunamadı.' }
    Assert-Match $badging "package: name='$package' versionCode='$versionCode' versionName='$versionName'" 'APK paket kimliği veya sürümü kaynakla uyuşmuyor.'
}

Write-Host "Kimlik doğrulandı: $($identity.applicationId), sürüm $versionName+$versionCode, sertifika $keyFingerprint"
