# Laboratorio 5 - Seguridad en APIs

Este repositorio contiene el proyecto Spring Boot del ejercicio 3, tal como solicita la guia. Las respuestas y evidencias de los ejercicios 0 a 5 se integran en un unico PDF grupal para la entrega final.

## Proyecto del ejercicio 3

Ruta: `ejercicio-3/api-segura`

La API expone `GET https://localhost:8443/api/v1/salud`, devuelve `{"estado":"ok"}` y agrega `Strict-Transport-Security` en respuestas HTTPS. Incluye un cliente Java que conserva la validacion TLS y un truststore local generado para esta practica.

## Requisitos

- JDK 17 o superior.
- Windows PowerShell y `curl` en `PATH`.
- Conectividad a Maven Central durante la primera compilacion.

## Generar certificados y ejecutar la demostracion

Desde PowerShell:

```powershell
Set-Location .\ejercicio-3\api-segura
powershell -ExecutionPolicy Bypass -File .\scripts\Demostrar-Ejercicio3.ps1
```

El script prepara los certificados, compila el proyecto, ejecuta las cinco verificaciones documentadas y detiene el proceso del servidor que inicio.

Para preparar certificados sin ejecutar todos los casos:

```powershell
. .\scripts\Preparar-Certificados.ps1
```

El script define `KEYSTORE_PASSWORD` y `TRUSTSTORE_PASSWORD` solo en la sesion actual de PowerShell. Cada integrante debe generar sus propios almacenes y contrasenas. No se deben copiar entre equipos ni imprimir en el informe.

## Archivos locales excluidos

El `.gitignore` excluye `*.p12`, `*.crt`, `*.key`, `.env`, `.env.*`, `.local/`, `target/` y logs. No subas keystores, llaves privadas ni archivos `.env`. El JAR local incluye el keystore porque el proyecto lo carga desde `classpath`; no se debe versionar `target/` ni compartir ese JAR.

## Ejercicio 4 (mTLS)

Ruta: `ejercicio-4/api-mtls`. Ver su README. Se ejecuta con `scripts/Demostrar-Ejercicio4.ps1`.

