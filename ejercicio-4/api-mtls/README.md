# API con mTLS (Laboratorio 5, ejercicio 4c-4d)

Es el proyecto del ejercicio 3 con **TLS mutuo**: el servidor exige certificado de cliente.

- `server.ssl.client-auth=need` + `server.ssl.trust-store=classpath:truststore.p12`.
- El truststore del servidor contiene solo el certificado publico de `CN=servicio-pagos`.
- `GET /api/v1/salud` responde `{"estado":"ok","cliente":"servicio-pagos"}` leyendo `jakarta.servlet.request.X509Certificate` y extrayendo el CN del sujeto.
- `ClienteSalud --confiar --cliente` es el cliente Java con truststore y keystore de cliente (sin desactivar validacion).

## Ejecutar (Windows)

```powershell
Set-Location .\ejercicio-4\api-mtls
powershell -ExecutionPolicy Bypass -File .\scripts\Demostrar-Ejercicio4.ps1
```

En Linux/macOS: `bash scripts/demostrar-ejercicio4.sh`.

El script genera todos los certificados y contrasenas aleatorias (`KEYSTORE_PASSWORD`, `TRUSTSTORE_PASSWORD`, `CLIENTE_PASSWORD`, `CONFIANZA_PASSWORD`) **solo en el entorno del proceso**, compila, arranca la API, ejecuta cinco casos y guarda las salidas en `../resultados/` (excluida de Git).

Para arrancar a mano: defina `KEYSTORE_PASSWORD` y `TRUSTSTORE_PASSWORD` con las claves que uso al crear `keystore.p12` y `truststore.p12` y ejecute `java -jar target/api-mtls-0.0.1-SNAPSHOT.jar`.

## Seguridad del repositorio

Ningun `.p12`, `.crt`, `.key` ni `.env` se versiona (ver `.gitignore`). No suba `target/`: el JAR contiene keystore y truststore.

## Variables de entorno

| Variable | Almacen |
|---|---|
| `KEYSTORE_PASSWORD` | `src/main/resources/keystore.p12`: identidad del servidor |
| `TRUSTSTORE_PASSWORD` | `src/main/resources/truststore.p12`: truststore **del servidor** (clientes autorizados) |
| `CLIENTE_PASSWORD` | `.local/cliente-pagos.p12`: identidad del cliente |
| `CONFIANZA_PASSWORD` | `.local/confianza.p12`: truststore del cliente Java |

A diferencia del ejercicio 3, aqui `TRUSTSTORE_PASSWORD` corresponde al truststore del servidor, como en el `application.properties` del enunciado. Los comandos manuales estan en el README de la raiz.

## Resultados esperados

Verificado con `scripts/demostrar-ejercicio4.sh` (JDK 17+, OpenSSL 3):

| Caso | Resultado |
|---|---|
| A. curl sin certificado de cliente | exit 56, `tlsv13 alert certificate required` |
| B. curl con `cliente-pagos.p12` | `200`, `{"estado":"ok","cliente":"servicio-pagos"}` y HSTS |
| C. curl con certificado no autorizado | exit 56, `alert certificate unknown` |
| D. Java sin certificado de cliente | `Received fatal alert: certificate_required` |
| E. Java con certificado de cliente | `200` y HSTS |

En TLS 1.3 el rechazo del caso A ocurre despues del `Finished` del cliente: el servidor valida el `Certificate` (vacio) y envia la alerta `certificate_required`, que el cliente recibe en su primera lectura. Por eso curl reporta un error de `SSL_read` y no de conexion.
