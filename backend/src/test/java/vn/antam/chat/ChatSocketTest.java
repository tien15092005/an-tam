package vn.antam.chat;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.UUID;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketHttpHeaders;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.client.standard.StandardWebSocketClient;
import org.springframework.web.socket.handler.TextWebSocketHandler;
import org.testcontainers.postgresql.PostgreSQLContainer;

import com.jayway.jsonpath.JsonPath;

/** Phase 9 DoD (real time): two phones get the message live; strangers can neither connect nor subscribe. */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
class ChatSocketTest {

    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:18");

    static {
        POSTGRES.start();
    }

    @LocalServerPort
    int port;

    final HttpClient http = HttpClient.newHttpClient();

    record Who(Long id, String token) {
    }

    private String call(String method, String path, String token, String json) throws Exception {
        HttpRequest.Builder b = HttpRequest.newBuilder(URI.create("http://localhost:" + port + path))
                .header("Content-Type", "application/json")
                .method(method, json == null ? HttpRequest.BodyPublishers.noBody() : HttpRequest.BodyPublishers.ofString(json));
        if (token != null) b.header("Authorization", "Bearer " + token);
        return http.send(b.build(), HttpResponse.BodyHandlers.ofString()).body();
    }

    private Who register(String name) throws Exception {
        String email = name.replace(' ', '.') + UUID.randomUUID().toString().substring(0, 8) + "@test.vn";
        String r = call("POST", "/api/auth/register", null,
                "{\"email\":\"%s\",\"password\":\"matkhau123\",\"displayName\":\"%s\"}".formatted(email, name));
        String token = JsonPath.read(r, "$.accessToken");
        Number id = JsonPath.read(call("GET", "/api/me", token, null), "$.id");
        return new Who(id.longValue(), token);
    }

    private WebSocketSession connect(String token, BlockingQueue<String> inbox) throws Exception {
        WebSocketHttpHeaders headers = new WebSocketHttpHeaders();
        if (token != null) headers.add("Authorization", "Bearer " + token);
        return new StandardWebSocketClient().execute(new TextWebSocketHandler() {
            @Override
            protected void handleTextMessage(WebSocketSession s, TextMessage m) {
                inbox.add(m.getPayload());
            }
        }, headers, URI.create("ws://localhost:" + port + "/ws/chat")).get(5, TimeUnit.SECONDS);
    }

    @Test
    void membersReceiveMessagesLiveAndStrangersCannot() throws Exception {
        Who owner = register("Chi Hoa");
        Who member = register("Anh Nam");
        Who outsider = register("Nguoi La");
        Number gid = JsonPath.read(call("POST", "/api/groups", owner.token(), "{\"name\":\"Nhà\"}"), "$.id");
        long groupId = gid.longValue();
        String code = JsonPath.read(call("POST", "/api/groups/" + groupId + "/invites", owner.token(), null), "$.code");
        call("POST", "/api/invites/accept", member.token(), "{\"code\":\"" + code + "\"}");

        // No token: the handshake itself is refused.
        assertThatThrownBy(() -> connect(null, new LinkedBlockingQueue<>())).isNotNull();

        BlockingQueue<String> memberInbox = new LinkedBlockingQueue<>();
        BlockingQueue<String> outsiderInbox = new LinkedBlockingQueue<>();
        WebSocketSession memberWs = connect(member.token(), memberInbox);
        WebSocketSession outsiderWs = connect(outsider.token(), outsiderInbox);
        memberWs.sendMessage(new TextMessage("{\"type\":\"subscribe\",\"groupId\":" + groupId + "}"));
        outsiderWs.sendMessage(new TextMessage("{\"type\":\"subscribe\",\"groupId\":" + groupId + "}"));
        assertThat(memberInbox.poll(5, TimeUnit.SECONDS)).contains("\"subscribed\"");
        assertThat(outsiderInbox.poll(5, TimeUnit.SECONDS)).contains("\"error\"").contains("not_found");

        long sent = System.nanoTime();
        call("POST", "/api/groups/" + groupId + "/chat/messages", owner.token(),
                "{\"clientMessageId\":\"" + UUID.randomUUID() + "\",\"body\":\"Chiều nay ai qua với mẹ?\"}");
        String live = memberInbox.poll(5, TimeUnit.SECONDS);
        long ms = (System.nanoTime() - sent) / 1_000_000;
        assertThat(live).contains("\"type\":\"message\"").contains("Chiều nay ai qua với mẹ?").contains("Chi Hoa");
        assertThat(ms).isLessThan(5000);
        assertThat(outsiderInbox.poll(1, TimeUnit.SECONDS)).isNull();
        System.out.println("chat delivery latency ms = " + ms);

        // Removed from the group: no more messages, even on an open socket.
        call("DELETE", "/api/groups/" + groupId + "/members/" + member.id(), owner.token(), null);
        call("POST", "/api/groups/" + groupId + "/chat/messages", owner.token(),
                "{\"clientMessageId\":\"" + UUID.randomUUID() + "\",\"body\":\"tin riêng\"}");
        assertThat(memberInbox.poll(2, TimeUnit.SECONDS)).isNull();
        memberWs.close();
        outsiderWs.close();
    }
}
