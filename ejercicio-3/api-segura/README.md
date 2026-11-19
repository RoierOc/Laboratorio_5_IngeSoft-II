# API HTTPS del Laboratorio 5

Proyecto generado con Spring Initializr (Maven, Java 17, Spring Web) sobre Spring Boot 3.5.16.

## Contenido

- GET https://localhost:8443/api/v1/salud responde JSON con estado ok.
- HTTPS, certificado RSA 2048 de 30 dias con SAN localhost y 127.0.0.1.
- HstsFilter agrega Strict-Transport-Security solo para peticiones seguras.
- Cliente Java 17 que adapta HttpJson del laboratorio 4; mantiene validacion de cadena y nombre.
- Truststore local especifico para confiar en el certificado del laboratorio.
- Servicio enlazado a 127.0.0.1 para la practica local.

## Ejecutar la demostracion en Linux / macOS / Git Bash

```bash
bash scripts/demostrar-ejercicio3.sh
```

Genera certificados y contrasenas aleatorias solo en el entorno del proceso (se regeneran en cada ejecucion), compila, arranca la API, ejecuta los casos (1), (2), (3) y los dos del cliente Java, y guarda la salida en ../resultados/ejercicio3-https.txt con la clave enmascarada. El cliente Java con truststore se ejecuta con las propiedades -D del enunciado.

## Ejecutar la demostracion en Windows

Requisitos: JDK 17+ y curl en PATH. Maven se incluye como herramienta local o se descarga mediante mvnw.cmd. No requiere instalacion global.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Demostrar-Ejercicio3.ps1
```

El script prepara certificados, compila SIN ejecutar pruebas JUnit, arranca temporalmente la API, ejecuta los cinco casos, guarda sus salidas y detiene solo el proceso que el mismo inicio. No se debe declarar completado hasta revisar esos resultados.

Resultados fuera del proyecto, en la carpeta hermana ../resultados. Los errores de confianza son resultados esperados en dos casos; no se usa curl -k ni un TrustManager permisivo.

## Certificados y variables

```powershell
. .\scripts\Preparar-Certificados.ps1
```

Genera KEYSTORE_PASSWORD y TRUSTSTORE_PASSWORD aleatorias y las define solo en el proceso actual. Usa keytool -storepass:env para no imprimirlas ni incluirlas en argumentos. Las claves se conservan cifradas con DPAPI en .local/credenciales.xml, vinculadas al usuario Windows; otro integrante debe generar las suyas desde una copia limpia. No copiar .local, los keystores ni target al compartir.

En este ejercicio TRUSTSTORE_PASSWORD protege el truststore del cliente Java (confianza.p12). En el ejercicio 4 la misma variable corresponde al truststore del servidor; ver la tabla del README de la raiz.

Almacen del servidor: src/main/resources/keystore.p12. Certificado publico: .local/seii.crt. Truststore del cliente: .local/confianza.p12. application.properties obtiene la clave del servidor de KEYSTORE_PASSWORD. ClienteSalud obtiene la clave de TRUSTSTORE_PASSWORD y configura javax.net.ssl.trustStore, trustStoreType y trustStorePassword antes de construir HttpClient. Es equivalente a las propiedades -D del enunciado sin escribir la clave en la linea de comandos.

Para arrancar manualmente, despues de preparar las variables y compilar:

```powershell
java -jar .\target\api-segura-0.0.1-SNAPSHOT.jar
```

## Archivos excluidos

.gitignore excluye *.p12, *.crt, *.key, .env, .env.*, .local/, target/ y logs. El JAR ejecutable incorpora el keystore local por usar classpath; NO compartir ni versionar target o ese JAR. Compartir fuentes y scripts; cada miembro genera su material.

No subir contrasenas ni copiar variables de entorno al informe. El certificado publico no es secreto, pero *.crt se excluye por exigencia del enunciado. Las contrasenas de los almacenes no son credenciales de usuarios reales.

## Alcance

Este proyecto corresponde al ejercicio 3. La autenticacion de clientes mediante mTLS se agregara en el ejercicio 4; aun no esta activada. No se instala esta CA en el almacen global del equipo.
