$ErrorActionPreference = 'Stop'
$proyecto = Split-Path $PSScriptRoot -Parent
$local = Join-Path $proyecto '.local'
New-Item -ItemType Directory -Force -Path $local | Out-Null
$keystore = Join-Path $proyecto 'src\main\resources\keystore.p12'
$certificado = Join-Path $local 'seii.crt'
$confianza = Join-Path $local 'confianza.p12'
$credenciales = Join-Path $local 'credenciales.xml'
if (Test-Path -LiteralPath $credenciales) {
    $secretos = Import-Clixml -LiteralPath $credenciales
} else {
    if ((Test-Path -LiteralPath $keystore) -or (Test-Path -LiteralPath $confianza)) {
        throw 'Hay almacenes existentes sin credenciales locales. No se sobrescribiran; usa una copia limpia del proyecto.'
    }
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    $secretos = @{}
    foreach ($nombre in @('KEYSTORE_PASSWORD','TRUSTSTORE_PASSWORD')) {
        $bytes = New-Object byte[] 24
        $rng.GetBytes($bytes)
        $secretos[$nombre] = ConvertTo-SecureString ([Convert]::ToBase64String($bytes)) -AsPlainText -Force
    }
    $rng.Dispose()
    # DPAPI: solo el usuario local puede recuperar las claves; .local se excluye de Git.
    $secretos | Export-Clixml -LiteralPath $credenciales
}
foreach ($nombre in @('KEYSTORE_PASSWORD','TRUSTSTORE_PASSWORD')) {
    $valor = [Net.NetworkCredential]::new('', $secretos[$nombre]).Password
    [Environment]::SetEnvironmentVariable($nombre, $valor, 'Process')
}
if (-not (Test-Path -LiteralPath $keystore)) {
    & keytool -genkeypair -alias seii -keyalg RSA -keysize 2048 -validity 30 `
        -storetype PKCS12 -keystore $keystore -storepass:env KEYSTORE_PASSWORD `
        -dname 'CN=localhost' -ext 'SAN=dns:localhost,ip:127.0.0.1' -ext 'EKU=serverAuth'
    if ($LASTEXITCODE -ne 0) { throw 'Fallo la generacion del certificado' }
}
& keytool -exportcert -alias seii -keystore $keystore -storepass:env KEYSTORE_PASSWORD -rfc -file $certificado
if ($LASTEXITCODE -ne 0) { throw 'Fallo la exportacion publica' }
if (-not (Test-Path -LiteralPath $confianza)) {
    & keytool -importcert -alias seii -file $certificado -keystore $confianza `
        -storetype PKCS12 -storepass:env TRUSTSTORE_PASSWORD -noprompt
    if ($LASTEXITCODE -ne 0) { throw 'Fallo la creacion del truststore' }
}
Write-Host 'Certificado y truststore preparados. No se imprimen contrasenas.'
