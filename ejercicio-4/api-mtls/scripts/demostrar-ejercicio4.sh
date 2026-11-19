#!/usr/bin/env bash
# Ejercicio 4(c)-(d): genera material de prueba, arranca la API con mTLS y ejecuta los casos.
# Uso: bash scripts/demostrar-ejercicio4.sh   (requiere JDK 17+, openssl no, curl, mvn o ./mvnw)
set -euo pipefail
cd "$(dirname "$0")/.."
LOCAL=.local; RES=../resultados
mkdir -p "$LOCAL" "$RES"
gen() { head -c 24 /dev/urandom | base64 | tr -d '/+='; }
# Contrasenas de prueba aleatorias, solo en el entorno de este proceso (no se imprimen).
export KEYSTORE_PASSWORD="${KEYSTORE_PASSWORD:-$(gen)}"
export TRUSTSTORE_PASSWORD="${TRUSTSTORE_PASSWORD:-$(gen)}"
export CLIENTE_PASSWORD="${CLIENTE_PASSWORD:-$(gen)}"
export CONFIANZA_PASSWORD="${CONFIANZA_PASSWORD:-$(gen)}"
rm -f src/main/resources/keystore.p12 src/main/resources/truststore.p12 "$LOCAL"/*.p12 "$LOCAL"/*.crt

# Servidor: certificado autofirmado para localhost (Ejercicio 3).
keytool -genkeypair -alias seii -keyalg RSA -keysize 2048 -validity 30 -storetype PKCS12 \
  -keystore src/main/resources/keystore.p12 -storepass:env KEYSTORE_PASSWORD \
  -dname "CN=localhost" -ext "SAN=dns:localhost,ip:127.0.0.1" -ext "EKU=serverAuth" 2>/dev/null
keytool -exportcert -alias seii -keystore src/main/resources/keystore.p12 \
  -storepass:env KEYSTORE_PASSWORD -rfc -file "$LOCAL/seii.crt" 2>/dev/null

# Cliente autorizado: servicio de pagos (Ejercicio 4c).
keytool -genkeypair -alias pagos -keyalg RSA -keysize 2048 -validity 30 -storetype PKCS12 \
  -keystore "$LOCAL/cliente-pagos.p12" -storepass:env CLIENTE_PASSWORD \
  -dname "CN=servicio-pagos" -ext "EKU=clientAuth" 2>/dev/null
keytool -exportcert -alias pagos -keystore "$LOCAL/cliente-pagos.p12" \
  -storepass:env CLIENTE_PASSWORD -rfc -file "$LOCAL/cliente-pagos.crt" 2>/dev/null
# Truststore del SERVIDOR: solo contiene la parte publica del cliente autorizado.
keytool -importcert -alias pagos -file "$LOCAL/cliente-pagos.crt" -noprompt -storetype PKCS12 \
  -keystore src/main/resources/truststore.p12 -storepass:env TRUSTSTORE_PASSWORD 2>/dev/null
# Truststore del CLIENTE JAVA: confia en el certificado del servidor.
keytool -importcert -alias seii -file "$LOCAL/seii.crt" -noprompt -storetype PKCS12 \
  -keystore "$LOCAL/confianza.p12" -storepass:env CONFIANZA_PASSWORD 2>/dev/null

MVN=./mvnw; [ -x "$MVN" ] || MVN=mvn
command -v mvn >/dev/null && MVN=mvn
"$MVN" ${MAVEN_EXTRA:-} -q -Dmaven.test.skip=true package --batch-mode
mkdir -p "$LOCAL/clases"
javac --release 17 -encoding UTF-8 -d "$LOCAL/clases" $(find cliente-java -name '*.java')

java -jar target/api-mtls-0.0.1-SNAPSHOT.jar > "$RES/servidor-stdout.txt" 2>&1 &
PID=$!
trap 'kill $PID 2>/dev/null || true' EXIT
for i in $(seq 1 60); do (echo > /dev/tcp/127.0.0.1/8443) 2>/dev/null && break; sleep 1; done

run() { local n="$1"; shift; echo "### $n"; echo "\$ $*" | sed "s/${CLIENTE_PASSWORD}/<clave>/g"; set +e; "$@" 2>&1; echo "[exit $?]"; set -e; echo; }
{
run "A. Sin certificado de cliente (curl --cacert)" \
  curl -sS -i --max-time 10 --cacert "$LOCAL/seii.crt" https://localhost:8443/api/v1/salud
run "B. Con certificado de cliente (curl --cert-type P12)" \
  curl -sS -i --max-time 10 --cacert "$LOCAL/seii.crt" --cert-type P12 --cert "$LOCAL/cliente-pagos.p12:$CLIENTE_PASSWORD" https://localhost:8443/api/v1/salud
run "C. Cliente con certificado NO autorizado (autofirmado distinto)" bash -c '
  keytool -genkeypair -alias intruso -keyalg RSA -keysize 2048 -validity 1 -storetype PKCS12 \
    -keystore .local/intruso.p12 -storepass:env CLIENTE_PASSWORD -dname "CN=intruso" 2>/dev/null
  curl -sS -i --max-time 10 --cacert .local/seii.crt --cert-type P12 --cert ".local/intruso.p12:$CLIENTE_PASSWORD" https://localhost:8443/api/v1/salud'
run "D. Java con truststore pero SIN certificado de cliente" java -cp "$LOCAL/clases" edu.lab5.cliente.ClienteSalud --confiar
run "E. Java con truststore y certificado de cliente (mTLS)" java -cp "$LOCAL/clases" edu.lab5.cliente.ClienteSalud --confiar --cliente
} 2>&1 | tee "$RES/ejercicio4-mtls.txt"
