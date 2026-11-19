#!/usr/bin/env bash
# Ejercicio 3: genera el certificado, arranca la API por HTTPS y ejecuta los casos (c) y (d).
# Uso: bash scripts/demostrar-ejercicio3.sh   (requiere JDK 17+, curl, mvn o ./mvnw)
set -euo pipefail
cd "$(dirname "$0")/.."
LOCAL=.local; RES=../resultados
mkdir -p "$LOCAL" "$RES"
gen() { head -c 24 /dev/urandom | base64 | tr -d '/+='; }
# Contrasenas de prueba aleatorias, solo en el entorno de este proceso (no se imprimen).
export KEYSTORE_PASSWORD="${KEYSTORE_PASSWORD:-$(gen)}"
export TRUSTSTORE_PASSWORD="${TRUSTSTORE_PASSWORD:-$(gen)}"
rm -f src/main/resources/keystore.p12 "$LOCAL"/*.p12 "$LOCAL"/*.crt

# (a) Certificado autofirmado para localhost y su parte publica.
keytool -genkeypair -alias seii -keyalg RSA -keysize 2048 -validity 30 -storetype PKCS12 \
  -keystore src/main/resources/keystore.p12 -storepass:env KEYSTORE_PASSWORD \
  -dname "CN=localhost" -ext "SAN=dns:localhost,ip:127.0.0.1" -ext "EKU=serverAuth" 2>/dev/null
keytool -exportcert -alias seii -keystore src/main/resources/keystore.p12 \
  -storepass:env KEYSTORE_PASSWORD -rfc -file "$LOCAL/seii.crt" 2>/dev/null
# (d) Truststore del cliente Java: confia solo en el certificado del laboratorio.
keytool -importcert -alias seii -file "$LOCAL/seii.crt" -noprompt -storetype PKCS12 \
  -keystore "$LOCAL/confianza.p12" -storepass:env TRUSTSTORE_PASSWORD 2>/dev/null

MVN=./mvnw; [ -x "$MVN" ] || MVN=mvn
command -v mvn >/dev/null && MVN=mvn
"$MVN" ${MAVEN_EXTRA:-} -q -Dmaven.test.skip=true package --batch-mode
mkdir -p "$LOCAL/clases"
javac --release 17 -encoding UTF-8 -d "$LOCAL/clases" $(find cliente-java -name '*.java')

if (echo > /dev/tcp/127.0.0.1/8443) 2>/dev/null; then
  echo "El puerto 8443 ya esta ocupado. Deten la API anterior antes de continuar." >&2; exit 1
fi
java -jar target/api-segura-0.0.1-SNAPSHOT.jar > "$RES/servidor-stdout.txt" 2>&1 &
PID=$!
trap 'kill $PID 2>/dev/null || true' EXIT
for i in $(seq 1 60); do (echo > /dev/tcp/127.0.0.1/8443) 2>/dev/null && break; sleep 1; done

run() { local n="$1"; shift; echo "### $n"; echo "\$ $*" | sed "s/${TRUSTSTORE_PASSWORD}/<clave>/g"; set +e; "$@" 2>&1; local c=$?; set -e; echo; echo "[exit $c]"; echo; }
{
run "(1) HTTPS sin CA local: se espera error de confianza" \
  curl -sS -i --max-time 10 https://localhost:8443/api/v1/salud
run "(2) HTTPS con --cacert: se espera 200, JSON y HSTS" \
  curl -sS -i --max-time 10 --cacert "$LOCAL/seii.crt" https://localhost:8443/api/v1/salud
run "(3) HTTP al puerto TLS: se espera 400 sin HSTS" \
  curl -sS -i --max-time 10 http://localhost:8443/api/v1/salud
run "(d) Java sin truststore: se espera PKIX path building failed" \
  java -cp "$LOCAL/clases" edu.lab5.cliente.ClienteSalud
run "(d) Java con truststore (-Djavax.net.ssl.trustStore)" \
  java -Djavax.net.ssl.trustStore="$LOCAL/confianza.p12" -Djavax.net.ssl.trustStoreType=PKCS12 \
       -Djavax.net.ssl.trustStorePassword="$TRUSTSTORE_PASSWORD" -cp "$LOCAL/clases" edu.lab5.cliente.ClienteSalud
} 2>&1 | tee "$RES/ejercicio3-https.txt"
