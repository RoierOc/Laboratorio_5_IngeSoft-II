package edu.lab5.cliente;

import java.net.URI;
import java.net.http.HttpClient;
import java.nio.file.Path;
import java.time.Duration;
import javax.net.ssl.SSLHandshakeException;

public final class ClienteSalud {
    public static void main(String[] args) throws Exception {
        if (args.length > 1 || (args.length == 1 && !args[0].equals("--confiar"))) {
            System.err.println("Uso: ClienteSalud [--confiar]");
            System.exit(2);
        }
        if (args.length == 1) {
            String password = System.getenv("TRUSTSTORE_PASSWORD");
            if (password == null || password.isBlank()) {
                throw new IllegalStateException("Falta TRUSTSTORE_PASSWORD");
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
        }
    }
}
