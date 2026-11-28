package vn.antam.common;

import java.net.InetAddress;
import java.net.UnknownHostException;

import jakarta.servlet.http.HttpServletRequest;

/**
 * The address of the phone behind a request, for per-address attempt limits.
 * <p>
 * The backend is reached through cloudflared running on the same machine, so every request arrives from
 * localhost or the Docker gateway. Cloudflare puts the real address in {@code CF-Connecting-IP}. That header is
 * trusted only when the request comes from such a local hop: if the backend were ever exposed directly, anyone
 * could send the header to dodge the limits, so a public sender's own address is used instead.
 */
public final class ClientIp {

    static final String HEADER = "CF-Connecting-IP";

    private ClientIp() {
    }

    public static String of(HttpServletRequest request) {
        String remote = request.getRemoteAddr();
        String forwarded = request.getHeader(HEADER);
        if (forwarded != null && !forwarded.isBlank() && isLocalHop(remote)) return forwarded.trim();
        return remote;
    }

    static boolean isLocalHop(String address) {
        if (address == null || address.isBlank()) return false;
        try {
            // Only literal addresses reach here (no DNS lookup for a raw IP string).
            InetAddress a = InetAddress.ofLiteral(address);
            return a.isLoopbackAddress() || a.isSiteLocalAddress() || a.isLinkLocalAddress();
        } catch (IllegalArgumentException e) {
            return false;
        }
    }
}
