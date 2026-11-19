$ErrorActionPreference = 'Stop'
$proyecto = Split-Path $PSScriptRoot -Parent
$resultados = Join-Path (Split-Path $proyecto -Parent) 'resultados'
New-Item -ItemType Directory -Force -Path $resultados | Out-Null
Push-Location $proyecto
$servidor = $null
try {
    foreach ($herramienta in @('java','javac','keytool','curl.exe')) {
        if (-not (Get-Command $herramienta -ErrorAction SilentlyContinue)) { throw "Falta $herramienta en PATH" }
    }
    $comprobacion = New-Object Net.Sockets.TcpClient
    try {
        $comprobacion.Connect('127.0.0.1',8443)
        throw 'El puerto 8443 ya esta ocupado. Deten la API anterior antes de continuar.'
    } catch [Net.Sockets.SocketException] {
        # Esperado cuando no hay servidor en ese puerto.
    } finally { $comprobacion.Dispose() }
    & (Join-Path $PSScriptRoot 'Preparar-Certificados.ps1')
    Write-Host 'Compilando Spring Boot. La primera vez descarga dependencias...'
    $mvnGlobal = Get-Command mvn.cmd -ErrorAction SilentlyContinue
    $maven = if ($mvnGlobal) { $mvnGlobal.Source } else { Join-Path $proyecto 'mvnw.cmd' }
    $env:MAVEN_USER_HOME = Join-Path $proyecto '.local\maven'
    & $maven '-Dmaven.repo.local=.local/m2' '-Dmaven.test.skip=true' package --batch-mode
    if ($LASTEXITCODE -ne 0) { throw 'Fallo la compilacion Maven' }
    $clases = Join-Path $proyecto '.local\cliente-clases'
    New-Item -ItemType Directory -Force -Path $clases | Out-Null
    $fuentes = @(Get-ChildItem -LiteralPath (Join-Path $proyecto 'cliente-java') -Recurse -Filter '*.java' | ForEach-Object FullName)
    & javac --release 17 -encoding UTF-8 -d $clases $fuentes
    if ($LASTEXITCODE -ne 0) { throw 'Fallo la compilacion del cliente' }
    $java = (Get-Command java).Source
    $jar = Join-Path $proyecto 'target\api-segura-0.0.1-SNAPSHOT.jar'
    $servidor = Start-Process -FilePath $java -ArgumentList @('-jar',('"'+$jar+'"')) -WorkingDirectory $proyecto -PassThru -WindowStyle Hidden -RedirectStandardOutput (Join-Path $resultados 'servidor-stdout.txt') -RedirectStandardError (Join-Path $resultados 'servidor-stderr.txt')
    $disponible = $false
    for ($i=0; $i -lt 45; $i++) {
        if ($servidor.HasExited) { throw 'La API termino durante el arranque. Revisar servidor-stdout.txt y servidor-stderr.txt' }
        $socket = New-Object Net.Sockets.TcpClient
        try { $socket.Connect('127.0.0.1',8443); $disponible = $true } catch [Net.Sockets.SocketException] {} finally { $socket.Dispose() }
        if ($disponible) { break }
        Start-Sleep -Seconds 1
    }
    if (-not $disponible) { throw 'La API no inicio en 45 segundos' }
    $resumen = New-Object Collections.Generic.List[string]
    Write-Host '1. HTTPS sin CA local: se espera error de confianza.'
    & curl.exe --max-time 10 -sS -i https://localhost:8443/api/v1/salud -o (Join-Path $resultados '01-curl-sin-ca-respuesta.txt') --stderr (Join-Path $resultados '01-curl-sin-ca-error.txt')
    $sinCa = $LASTEXITCODE
    $resumen.Add("curl sin CA: exit $sinCa (se espera error de confianza; revisar mensaje)")
    Write-Host '2. HTTPS con --cacert: se espera 200, JSON y HSTS.'
    & curl.exe --max-time 10 -sS -i --cacert '.local\seii.crt' https://localhost:8443/api/v1/salud -o (Join-Path $resultados '02-curl-con-ca-respuesta.txt') --stderr (Join-Path $resultados '02-curl-con-ca-error.txt')
    $conCa = $LASTEXITCODE
    $resumen.Add("curl con CA: exit $conCa (se espera 0)")
    Write-Host '3. HTTP al puerto TLS: no debe responder como una consulta HTTPS valida.'
    & curl.exe --max-time 10 -sS -i http://localhost:8443/api/v1/salud -o (Join-Path $resultados '03-http-en-puerto-tls-respuesta.txt') --stderr (Join-Path $resultados '03-http-en-puerto-tls-error.txt')
    $resumen.Add("HTTP al puerto TLS: exit $LASTEXITCODE; interpretar respuesta (curl puede devolver 0 aunque HTTP sea 400)")
    Write-Host '4. Java sin truststore: se espera rechazo PKIX.'
    & java -cp $clases edu.lab5.cliente.ClienteSalud 1> (Join-Path $resultados '04-java-sin-confianza.txt') 2> (Join-Path $resultados '04-java-sin-confianza-error.txt')
    $sinConfianza = $LASTEXITCODE
    $resumen.Add("Java sin truststore: exit $sinConfianza (se espera 3 por SSLHandshakeException)")
    Write-Host '5. Java con truststore: se espera 200, JSON y HSTS.'
    & java -cp $clases edu.lab5.cliente.ClienteSalud --confiar 1> (Join-Path $resultados '05-java-con-confianza.txt') 2> (Join-Path $resultados '05-java-con-confianza-error.txt')
    $conConfianza = $LASTEXITCODE
    $resumen.Add("Java con truststore: exit $conConfianza (se espera 0)")
    $resumen | Set-Content -Encoding UTF8 (Join-Path $resultados 'resumen.txt')
    Write-Host '--- Resultados observados ---'
    $resumen | ForEach-Object { Write-Host $_ }
    Get-Content -LiteralPath (Join-Path $resultados '02-curl-con-ca-respuesta.txt'),(Join-Path $resultados '05-java-con-confianza.txt')
    if ($conCa -ne 0 -or $conConfianza -ne 0 -or $sinConfianza -ne 3 -or $sinCa -eq 0) {
        throw 'Alguno de los casos requiere revision; conserva resultados y avisa en el chat.'
    }
    Write-Host "Demostracion finalizada. Resultados guardados en $resultados"
} finally {
    if ($null -ne $servidor -and -not $servidor.HasExited) { $servidor.Kill(); $servidor.WaitForExit() }
    Remove-Item Env:KEYSTORE_PASSWORD -ErrorAction SilentlyContinue
    Remove-Item Env:TRUSTSTORE_PASSWORD -ErrorAction SilentlyContinue
    Pop-Location
}
