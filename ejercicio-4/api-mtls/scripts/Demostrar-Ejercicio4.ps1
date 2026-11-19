# Ejercicio 4(c)-(d): mTLS. Misma logica que demostrar-ejercicio4.sh, para Windows PowerShell.
$ErrorActionPreference = 'Stop'
$proyecto = Split-Path $PSScriptRoot -Parent
$local = Join-Path $proyecto '.local'
$resultados = Join-Path (Split-Path $proyecto -Parent) 'resultados'
New-Item -ItemType Directory -Force -Path $local, $resultados | Out-Null
Push-Location $proyecto
$servidor = $null
function Nueva-Clave { $rng = [Security.Cryptography.RandomNumberGenerator]::Create(); $b = New-Object byte[] 24; $rng.GetBytes($b); $rng.Dispose(); ([Convert]::ToBase64String($b)) -replace '[/+=]','' }
try {
    foreach ($n in 'KEYSTORE_PASSWORD','TRUSTSTORE_PASSWORD','CLIENTE_PASSWORD','CONFIANZA_PASSWORD') {
        Set-Item -Path "Env:$n" -Value (Nueva-Clave)   # solo en este proceso; no se imprimen
    }
    $ks = 'src\main\resources\keystore.p12'; $ts = 'src\main\resources\truststore.p12'
    Remove-Item -ErrorAction SilentlyContinue $ks, $ts, "$local\*.p12", "$local\*.crt"
    keytool -genkeypair -alias seii -keyalg RSA -keysize 2048 -validity 30 -storetype PKCS12 -keystore $ks -storepass:env KEYSTORE_PASSWORD -dname 'CN=localhost' -ext 'SAN=dns:localhost,ip:127.0.0.1' -ext 'EKU=serverAuth'
    keytool -exportcert -alias seii -keystore $ks -storepass:env KEYSTORE_PASSWORD -rfc -file "$local\seii.crt"
    keytool -genkeypair -alias pagos -keyalg RSA -keysize 2048 -validity 30 -storetype PKCS12 -keystore "$local\cliente-pagos.p12" -storepass:env CLIENTE_PASSWORD -dname 'CN=servicio-pagos' -ext 'EKU=clientAuth'
    keytool -exportcert -alias pagos -keystore "$local\cliente-pagos.p12" -storepass:env CLIENTE_PASSWORD -rfc -file "$local\cliente-pagos.crt"
    keytool -importcert -alias pagos -file "$local\cliente-pagos.crt" -noprompt -storetype PKCS12 -keystore $ts -storepass:env TRUSTSTORE_PASSWORD
    keytool -importcert -alias seii -file "$local\seii.crt" -noprompt -storetype PKCS12 -keystore "$local\confianza.p12" -storepass:env CONFIANZA_PASSWORD
    keytool -genkeypair -alias intruso -keyalg RSA -keysize 2048 -validity 1 -storetype PKCS12 -keystore "$local\intruso.p12" -storepass:env CLIENTE_PASSWORD -dname 'CN=intruso'

    & .\mvnw.cmd '-Dmaven.test.skip=true' package --batch-mode
    if ($LASTEXITCODE -ne 0) { throw 'Fallo la compilacion Maven' }
    New-Item -ItemType Directory -Force -Path "$local\clases" | Out-Null
    javac --release 17 -encoding UTF-8 -d "$local\clases" (Get-ChildItem cliente-java -Recurse -Filter *.java).FullName
    $servidor = Start-Process java -ArgumentList '-jar','target\api-mtls-0.0.1-SNAPSHOT.jar' -PassThru -WindowStyle Hidden -RedirectStandardOutput "$resultados\servidor-stdout.txt" -RedirectStandardError "$resultados\servidor-stderr.txt"
    for ($i=0; $i -lt 60; $i++) { try { $t = New-Object Net.Sockets.TcpClient('127.0.0.1',8443); $t.Dispose(); break } catch { Start-Sleep 1 } }
    if ($servidor.HasExited) { throw "La API termino al arrancar. Revise $resultados\servidor-stdout.txt y servidor-stderr.txt" }

    # curl.exe de Windows usa Schannel y falla con TLS 1.3 + certificados de cliente de keytool.
    # Preferimos el curl de Git for Windows (OpenSSL). Si no se encuentra, usamos curl.exe limitado a TLS 1.2.
    $curl = 'curl.exe'; $curlExtra = @('--tls-max','1.2')
    $candidatos = @("$env:ProgramFiles\Git\mingw64\bin\curl.exe", "${env:ProgramFiles(x86)}\Git\mingw64\bin\curl.exe", "$env:LOCALAPPDATA\Programs\Git\mingw64\bin\curl.exe")
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) { $candidatos += (Join-Path (Split-Path (Split-Path $git.Source -Parent) -Parent) 'mingw64\bin\curl.exe') }
    foreach ($c in $candidatos) { if (Test-Path -LiteralPath $c) { $curl = $c; $curlExtra = @(); break } }
    Write-Host "curl usado: $curl $($curlExtra -join ' ')"
    $out = "$resultados\ejercicio4-mtls.txt"; '' | Set-Content $out
    function Caso($titulo, [scriptblock]$cmd) {
        $ErrorActionPreference = 'Continue'   # en PS 5.1, stderr de curl/java no debe abortar el script
        "### $titulo" | Tee-Object -Append $out
        & $cmd 2>&1 | ForEach-Object { if ($_ -is [Management.Automation.ErrorRecord]) { $_.Exception.Message } else { "$_" } } | Out-String | Tee-Object -Append $out
        "[exit $LASTEXITCODE]`n" | Tee-Object -Append $out
    }
    Caso 'A. Sin certificado de cliente'       { & $curl @curlExtra -sS -i --max-time 10 --cacert "$local\seii.crt" https://localhost:8443/api/v1/salud }
    Caso 'B. Con certificado de cliente'       { & $curl @curlExtra -sS -i --max-time 10 --cacert "$local\seii.crt" --cert-type P12 --cert "$local\cliente-pagos.p12:$env:CLIENTE_PASSWORD" https://localhost:8443/api/v1/salud }
    Caso 'C. Certificado no autorizado'        { & $curl @curlExtra -sS -i --max-time 10 --cacert "$local\seii.crt" --cert-type P12 --cert "$local\intruso.p12:$env:CLIENTE_PASSWORD" https://localhost:8443/api/v1/salud }
    Caso 'D. Java sin certificado de cliente'  { java -cp "$local\clases" edu.lab5.cliente.ClienteSalud --confiar }
    Caso 'E. Java con certificado de cliente'  { java -cp "$local\clases" edu.lab5.cliente.ClienteSalud --confiar --cliente }
} finally {
    if ($servidor -and -not $servidor.HasExited) { $servidor.Kill() }
    'KEYSTORE_PASSWORD','TRUSTSTORE_PASSWORD','CLIENTE_PASSWORD','CONFIANZA_PASSWORD' | ForEach-Object { Remove-Item "Env:$_" -ErrorAction SilentlyContinue }
    Pop-Location
}
