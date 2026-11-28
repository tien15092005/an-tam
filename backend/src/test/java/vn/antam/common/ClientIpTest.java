package vn.antam.common;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;

class ClientIpTest {

    private static MockHttpServletRequest from(String remote, String cfHeader) {
        MockHttpServletRequest r = new MockHttpServletRequest();
        r.setRemoteAddr(remote);
        if (cfHeader != null) r.addHeader("CF-Connecting-IP", cfHeader);
        return r;
    }

    @Test
    void behindTheLocalTunnelEachPhoneGetsItsOwnAddress() {
        assertThat(ClientIp.of(from("172.18.0.1", "113.161.5.20"))).isEqualTo("113.161.5.20"); // Docker gateway
        assertThat(ClientIp.of(from("127.0.0.1", "14.232.1.9"))).isEqualTo("14.232.1.9");
    }

    @Test
    void aPublicSenderCannotChooseItsAddressWithTheHeader() {
        assertThat(ClientIp.of(from("203.0.113.7", "1.2.3.4"))).isEqualTo("203.0.113.7");
    }

    @Test
    void withoutTheHeaderTheConnectionAddressIsUsed() {
        assertThat(ClientIp.of(from("172.18.0.1", null))).isEqualTo("172.18.0.1");
    }
}
