package edu.lab5.cliente;

import java.net.URI;
import java.net.http.HttpClient;
import java.nio.file.Path;
import java.time.Duration;
import javax.net.ssl.SSLHandshakeException;

public final class ClienteSalud {
    public static void main(String[] args) throws Exception {
        var opciones = java.util.Set.of(args);
        if (!java.util.Set.of("--confiar", "--cliente").containsAll(opciones)) {
            System.err.println("Uso: ClienteSalud [--confiar] [--cliente]");
            System.exit(2);
        }
        if (opciones.contains("--cliente")) {
            // mTLS: el cliente presenta su certificado (cliente-pagos.p12).
            String password = System.getenv("CLIENTE_PASSWORD");
            if (password == null || password.isBlank()) {
                throw new IllegalStateException("Falta CLIENTE_PASSWORD");
            }
            System.setProperty("javax.net.ssl.keyStore",
                    Path.of(".local", "cliente-pagos.p12").toAbsolutePath().toString());
            System.setProperty("javax.net.ssl.keyStoreType", "PKCS12");
            System.setProperty("javax.net.ssl.keyStorePassword", password);
        }
        if (opciones.contains("--confiar")) {
            String password = System.getenv("CONFIANZA_PASSWORD");
            if (password == null || password.isBlank()) {
                throw new IllegalStateException("Falta CONFIANZA_PASSWORD");
            }
            // Equivale a -Djavax.net.ssl.trustStore* sin exponer la clave en argumentos.
            System.setProperty("javax.net.ssl.trustStore",
                    Path.of(".local", "confianza.p12").toAbsolutePath().toString());
            System.setProperty("javax.net.ssl.trustStoreType", "PKCS12");
            System.setProperty("javax.net.ssl.trustStorePassword", password);
        }
        var client = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5))
                .followRedirects(HttpClient.Redirect.NEVER).build();
        try {
            var response = new HttpJson(client, Duration.ofSeconds(5))
                    .get(URI.create("https://localhost:8443/api/v1/salud"));
            System.out.println("HTTP " + response.statusCode());
            System.out.println("HSTS: " + response.headers()
                    .firstValue("Strict-Transport-Security").orElse("AUSENTE"));
            System.out.println(response.body());
            if (response.statusCode() != 200) System.exit(1);
        } catch (SSLHandshakeException e) {
            System.out.println("Validacion TLS rechazada: " + e.getMessage());
            System.exit(3);
        } catch (java.io.IOException e) {
            // Con client-auth=need y sin certificado, el servidor corta el handshake (TLS 1.3: alerta tras el Finished).
            System.out.println("Conexion cerrada por el servidor: " + e);
            System.exit(4);
        }
    }
}
