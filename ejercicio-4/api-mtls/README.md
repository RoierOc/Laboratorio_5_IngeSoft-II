# API con mTLS (Laboratorio 5, ejercicio 4c-4d)

Es el proyecto del ejercicio 3 con **TLS mutuo**: el servidor exige certificado de cliente.

- `server.ssl.client-auth=need` + `server.ssl.trust-store=classpath:truststore.p12`.
- El truststore del servidor contiene solo el certificado publico de `CN=servicio-pagos`.
- `GET /api/v1/salud` responde `{"estado":"ok","cliente":"CN=servicio-pagos"}` leyendo `jakarta.servlet.request.X509Certificate`.
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

## Estado de verificacion

El codigo Java y el script **no fueron compilados ni ejecutados** por quien los redacto (el entorno no tenia acceso a Maven Central). Ejecute el script y revise `ejercicio4-mtls.txt` antes de entregar.
