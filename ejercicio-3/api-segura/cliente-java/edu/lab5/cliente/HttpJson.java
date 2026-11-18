package edu.lab5.cliente;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;

/** Adaptacion de HttpJson del laboratorio 4: mismo HttpClient y validacion TLS. */
final class HttpJson {
    private final HttpClient client;
    private final Duration timeout;

    HttpJson(HttpClient client, Duration timeout) {
        this.client = client;
        this.timeout = timeout;
    }

    HttpResponse<String> get(URI uri) throws IOException, InterruptedException {
        var request = HttpRequest.newBuilder(uri).timeout(timeout)
                .header("Accept", "application/json")
                .header("User-Agent", "Lab5-HTTPS-Client/1.0").GET().build();
        return client.send(request,
                HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
    }
}
