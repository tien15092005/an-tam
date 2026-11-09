package vn.antam.schedule;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.List;
import java.util.Map;
import java.util.stream.Stream;

import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;

import com.jayway.jsonpath.JsonPath;

/** Runs the cases in shared/test-vectors; the Flutter app runs the very same files. */
class SharedVectorsTest {

    private static final Path VECTORS = Path.of("..", "shared", "test-vectors");

    static Stream<Arguments> doseStatus() throws IOException {
        List<Map<String, Object>> cases = JsonPath.read(Files.readString(VECTORS.resolve("dose-status.json")), "$.cases");
        return cases.stream().map(c -> Arguments.of(c.get("name"), c));
    }

    static Stream<Arguments> expansion() throws IOException {
        List<Map<String, Object>> cases = JsonPath.read(Files.readString(VECTORS.resolve("schedule-expansion.json")), "$.cases");
        return cases.stream().map(c -> Arguments.of(c.get("name"), c));
    }

    @ParameterizedTest(name = "{0}")
    @MethodSource
    void doseStatus(String name, Map<String, Object> c) {
        DoseStatus actual = DoseStatus.of(
                LocalDateTime.parse((String) c.get("due")),
                LocalDateTime.parse((String) c.get("now")),
                LocalDateTime.parse((String) c.get("createdAt")),
                (String) c.get("log"));
        assertThat(actual.name()).as(name).isEqualTo(c.get("expected"));
    }

    @ParameterizedTest(name = "{0}")
    @MethodSource
    @SuppressWarnings("unchecked")
    void expansion(String name, Map<String, Object> c) {
        Map<String, Object> m = (Map<String, Object>) c.get("medication");
        List<LocalTime> times = ((List<String>) m.get("times")).stream().map(LocalTime::parse).toList();
        List<Integer> days = (List<Integer>) m.get("daysOfWeek");
        List<String> actual = ScheduleExpander.occurrences(times, ScheduleExpander.maskOf(days),
                        LocalDate.parse((String) m.get("startDate")),
                        m.get("endDate") == null ? null : LocalDate.parse((String) m.get("endDate")),
                        LocalDate.parse((String) c.get("from")), LocalDate.parse((String) c.get("to")))
                .stream().map(LocalDateTime::toString).toList();
        assertThat(actual).as(name).containsExactlyElementsOf((List<String>) c.get("expected"));
    }
}
