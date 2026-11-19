# Laboratorio 5 - Seguridad en APIs

Este repositorio contiene el proyecto Spring Boot del ejercicio 3 y su variante con mTLS del ejercicio 4. Las respuestas y evidencias de los ejercicios 0 a 5 se integran en un unico PDF grupal para la entrega final.

| Ruta | Ejercicio | Contenido |
|---|---|---|
| `ejercicio-3/api-segura` | 3 | API HTTPS con HSTS y cliente Java que confia mediante truststore |
| `ejercicio-4/api-mtls` | 4(c)-(d) | Misma API con `client-auth=need` (TLS mutuo) |

Ambas exponen `GET https://localhost:8443/api/v1/salud` y no pueden ejecutarse al mismo tiempo (comparten el puerto 8443).

## Requisitos

- JDK 17 o superior (incluye `keytool`).
- `curl` en `PATH`.
- Maven, o el wrapper incluido (`mvnw` / `mvnw.cmd`), con acceso a Maven Central la primera vez.

## Opcion rapida: scripts de demostracion

Generan certificados y contrasenas aleatorias (solo en el entorno del proceso), compilan, arrancan la API, ejecutan los casos del enunciado y guardan las salidas en `../resultados/` (excluida de Git).

| | Linux / macOS / Git Bash | Windows PowerShell |
|---|---|---|
| Ejercicio 3 | `bash scripts/demostrar-ejercicio3.sh` | `powershell -ExecutionPolicy Bypass -File .\scripts\Demostrar-Ejercicio3.ps1` |
| Ejercicio 4 | `bash scripts/demostrar-ejercicio4.sh` | `powershell -ExecutionPolicy Bypass -File .\scripts\Demostrar-Ejercicio4.ps1` |

Cada script se ejecuta desde la carpeta de su proyecto.

## Opcion manual: generar certificados y definir las contrasenas

Las contrasenas son de prueba: cada integrante elige las suyas y nunca se versionan ni se copian al informe. Con `-storepass:env` keytool lee la clave de la variable de entorno sin mostrarla en la linea de comandos.

### Ejercicio 3 (HTTPS)

Desde `ejercicio-3/api-segura`.

Bash:

```bash
export KEYSTORE_PASSWORD='clave-de-prueba-servidor'
export TRUSTSTORE_PASSWORD='clave-de-prueba-confianza'
mkdir -p .local

# (a) Certificado autofirmado del servidor y su parte publica
keytool -genkeypair -alias seii -keyalg RSA -keysize 2048 -validity 30 \
  -storetype PKCS12 -keystore src/main/resources/keystore.p12 -storepass:env KEYSTORE_PASSWORD \
  -dname "CN=localhost" -ext "SAN=dns:localhost,ip:127.0.0.1"
keytool -exportcert -alias seii -keystore src/main/resources/keystore.p12 \
  -storepass:env KEYSTORE_PASSWORD -rfc -file .local/seii.crt

# (d) Truststore del cliente Java
keytool -importcert -alias seii -file .local/seii.crt -keystore .local/confianza.p12 \
  -storetype PKCS12 -storepass:env TRUSTSTORE_PASSWORD -noprompt

# Compilar y arrancar la API
./mvnw -Dmaven.test.skip=true package
java -jar target/api-segura-0.0.1-SNAPSHOT.jar
```

PowerShell (mismos comandos `keytool`, cambiando `\` por `` ` `` al final de linea):

```powershell
$env:KEYSTORE_PASSWORD = 'clave-de-prueba-servidor'
$env:TRUSTSTORE_PASSWORD = 'clave-de-prueba-confianza'
```

En otra terminal, con la API arriba:

```bash
curl -i https://localhost:8443/api/v1/salud                        # (1) falla: certificado autofirmado
curl -i --cacert .local/seii.crt https://localhost:8443/api/v1/salud # (2) 200 + Strict-Transport-Security
curl -i http://localhost:8443/api/v1/salud                         # (3) 400: el puerto exige TLS

mkdir -p .local/clases && javac --release 17 -d .local/clases $(find cliente-java -name '*.java')
java -cp .local/clases edu.lab5.cliente.ClienteSalud               # PKIX path building failed
java -Djavax.net.ssl.trustStore=.local/confianza.p12 -Djavax.net.ssl.trustStoreType=PKCS12 \
     -Djavax.net.ssl.trustStorePassword="$TRUSTSTORE_PASSWORD" \
     -cp .local/clases edu.lab5.cliente.ClienteSalud               # 200 + HSTS
```

### Ejercicio 4 (mTLS)

Desde `ejercicio-4/api-mtls`. Se generan el keystore del servidor igual que en el ejercicio 3 y, ademas, la identidad del cliente `servicio-pagos` y el truststore **del servidor**:

```bash
export KEYSTORE_PASSWORD='clave-de-prueba-servidor'
export TRUSTSTORE_PASSWORD='clave-de-prueba-truststore-servidor'
export CLIENTE_PASSWORD='clave-de-prueba-cliente'
mkdir -p .local

keytool -genkeypair -alias seii -keyalg RSA -keysize 2048 -validity 30 \
  -storetype PKCS12 -keystore src/main/resources/keystore.p12 -storepass:env KEYSTORE_PASSWORD \
  -dname "CN=localhost" -ext "SAN=dns:localhost,ip:127.0.0.1"
keytool -exportcert -alias seii -keystore src/main/resources/keystore.p12 \
  -storepass:env KEYSTORE_PASSWORD -rfc -file .local/seii.crt

keytool -genkeypair -alias pagos -keyalg RSA -keysize 2048 -validity 30 \
  -storetype PKCS12 -keystore .local/cliente-pagos.p12 -storepass:env CLIENTE_PASSWORD \
  -dname "CN=servicio-pagos"
keytool -exportcert -alias pagos -keystore .local/cliente-pagos.p12 \
  -storepass:env CLIENTE_PASSWORD -rfc -file .local/cliente-pagos.crt
keytool -importcert -alias pagos -file .local/cliente-pagos.crt -noprompt \
  -storetype PKCS12 -keystore src/main/resources/truststore.p12 -storepass:env TRUSTSTORE_PASSWORD

./mvnw -Dmaven.test.skip=true package
java -jar target/api-mtls-0.0.1-SNAPSHOT.jar
```

Pruebas:

```bash
curl -i --cacert .local/seii.crt https://localhost:8443/api/v1/salud    # falla: certificate required
curl -i --cacert .local/seii.crt --cert-type P12 \
     --cert ".local/cliente-pagos.p12:$CLIENTE_PASSWORD" https://localhost:8443/api/v1/salud  # 200
```

### Variables de entorno

| Variable | Ejercicio 3 | Ejercicio 4 |
|---|---|---|
| `KEYSTORE_PASSWORD` | `keystore.p12` del servidor | `keystore.p12` del servidor |
| `TRUSTSTORE_PASSWORD` | `.local/confianza.p12`: truststore **del cliente Java** | `truststore.p12`: truststore **del servidor** (certificados de clientes autorizados) |
| `CLIENTE_PASSWORD` | - | `.local/cliente-pagos.p12`: identidad del cliente |
| `CONFIANZA_PASSWORD` | - | `.local/confianza.p12`: truststore del cliente Java |

En el ejercicio 4 `TRUSTSTORE_PASSWORD` sigue el `application.properties` del enunciado (truststore del servidor); por eso el truststore del cliente Java usa `CONFIANZA_PASSWORD`.

## Archivos locales excluidos

El `.gitignore` excluye `*.p12`, `*.crt`, `*.key`, `.env`, `.env.*`, `.local/`, `target/`, `resultados/` y logs. No subas keystores, llaves privadas ni archivos `.env`. El JAR local incluye los almacenes porque el proyecto los carga desde `classpath`; no se debe versionar `target/` ni compartir ese JAR.
