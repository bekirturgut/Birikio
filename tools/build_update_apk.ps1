param(
    [string]$KeystorePath = (Join-Path $env:USERPROFILE '.android\debug.keystore'),
    [string]$OutputDirectory = ([Environment]::GetFolderPath('Desktop'))
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$identityFile = Join-Path $PSScriptRoot 'update_identity.json'
$previousPassword = $env:BIRIKIO_KEYSTORE_PASSWORD
$identity = Get-Content -LiteralPath $identityFile -Raw | ConvertFrom-Json
$pubspec = Get-Content -LiteralPath (Join-Path $repo 'pubspec.yaml') -Raw
if ($pubspec -notmatch '(?m)^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$') { throw 'pubspec.yaml sürümü okunamadı.' }
$versionName = $Matches[1]
$versionCode = [int]$Matches[2]

& (Join-Path $PSScriptRoot 'check_update_identity.ps1') -RequireNewVersion -KeystorePath $KeystorePath
if ($LASTEXITCODE -ne 0) { throw 'Kimlik denetimi başarısız.' }
if (Test-Path -LiteralPath (Join-Path $repo 'android\key.properties')) {
    throw 'android/key.properties bulundu. Çift/farklı imzalamayı önlemek için önce bu dosyadaki imza yapılandırmasını doğrula.'
}

Push-Location $repo
try {
    & flutter analyze
    if ($LASTEXITCODE -ne 0) { throw 'flutter analyze başarısız.' }
    & flutter test
    if ($LASTEXITCODE -ne 0) { throw 'flutter test başarısız.' }
    & flutter build apk --release
    if ($LASTEXITCODE -ne 0) { throw 'APK derlenemedi.' }

    $sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } elseif ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } else { Join-Path $env:LOCALAPPDATA 'Android\sdk' }
    $tools = Get-ChildItem -LiteralPath (Join-Path $sdk 'build-tools') -Directory | Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
    if (-not $tools) { throw 'Android build-tools bulunamadı.' }
    $apksigner = Join-Path $tools.FullName 'apksigner.bat'
    $unsigned = Join-Path $repo 'build\app\outputs\flutter-apk\app-release.apk'
    $signed = Join-Path $repo "build\birikio-guncelleme-v$versionName-$versionCode.apk"
    $password = if ($env:BIRIKIO_KEYSTORE_PASSWORD) { $env:BIRIKIO_KEYSTORE_PASSWORD } else { 'android' }
    $env:BIRIKIO_KEYSTORE_PASSWORD = $password
    & $apksigner sign --ks $KeystorePath --ks-key-alias $identity.signingAlias --ks-pass env:BIRIKIO_KEYSTORE_PASSWORD --key-pass env:BIRIKIO_KEYSTORE_PASSWORD --out $signed $unsigned
    if ($LASTEXITCODE -ne 0) { throw 'APK imzalanamadı.' }
    & (Join-Path $PSScriptRoot 'check_update_identity.ps1') -ApkPath $signed -KeystorePath $KeystorePath
    if ($LASTEXITCODE -ne 0) { throw 'İmzalı APK kimlik denetimi başarısız.' }

    $destination = Join-Path $OutputDirectory "Birikio-guncelleme-v$versionName-$versionCode.apk"
    Copy-Item -LiteralPath $signed -Destination $destination -Force
    $identity.lastDeliveredVersionCode = $versionCode
    $identity | ConvertTo-Json | Set-Content -LiteralPath $identityFile -Encoding utf8
    Write-Host "Güncelleme APK'si hazır: $destination"
    Write-Host 'Kurulumdan önce Birikio içinden JSON yedek al; uygulamayı kaldırmadan Güncelle seçeneğini kullan.'
    Write-Host 'README ve update_identity.json değişikliklerini aynı commit ile kaydet.'
} finally {
    if ($null -eq $previousPassword) {
        Remove-Item Env:BIRIKIO_KEYSTORE_PASSWORD -ErrorAction SilentlyContinue
    } else {
        $env:BIRIKIO_KEYSTORE_PASSWORD = $previousPassword
    }
    Pop-Location
}
