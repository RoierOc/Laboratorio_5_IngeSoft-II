package edu.lab5.api;

import jakarta.servlet.http.HttpServletRequest;
import java.security.cert.X509Certificate;
import java.util.LinkedHashMap;
import java.util.Map;
import javax.naming.InvalidNameException;
import javax.naming.ldap.LdapName;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class SaludController {
    @GetMapping("/api/v1/salud")
    public Map<String, String> salud(HttpServletRequest request) {
        Map<String, String> cuerpo = new LinkedHashMap<>();
        cuerpo.put("estado", "ok");
        // Ejercicio 4(d) opcional: el certificado del cliente validado en el handshake.
        var certs = (X509Certificate[]) request.getAttribute("jakarta.servlet.request.X509Certificate");
        if (certs != null && certs.length > 0) {
            cuerpo.put("cliente", extraerCn(certs[0]));
        }
        return cuerpo;
    }

    /** Devuelve solo el CN del sujeto (p. ej. "servicio-pagos"), o el DN completo si no tiene CN. */
    private static String extraerCn(X509Certificate cert) {
        String dn = cert.getSubjectX500Principal().getName();
        try {
            return new LdapName(dn).getRdns().stream()
                    .filter(rdn -> rdn.getType().equalsIgnoreCase("CN"))
                    .map(rdn -> rdn.getValue().toString())
                    .findFirst().orElse(dn);
        } catch (InvalidNameException e) {
            return dn;
        }
    }
}
