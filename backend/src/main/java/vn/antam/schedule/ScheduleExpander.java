package vn.antam.schedule;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;

/** Turns a medication's times, weekdays and date range into concrete dose times. Mirrored in the app. */
public final class ScheduleExpander {

    private ScheduleExpander() {
    }

    /**
     * @param daysOfWeekMask bit 0 = Monday … bit 6 = Sunday (127 = every day)
     * @return dose times on dates from..to (inclusive), sorted
     */
    public static List<LocalDateTime> occurrences(List<LocalTime> times, int daysOfWeekMask, LocalDate startDate,
                                                  LocalDate endDate, LocalDate from, LocalDate to) {
        List<LocalTime> sorted = times.stream().sorted().toList();
        LocalDate first = from.isBefore(startDate) ? startDate : from;
        LocalDate last = endDate != null && endDate.isBefore(to) ? endDate : to;
        List<LocalDateTime> out = new ArrayList<>();
        for (LocalDate d = first; !d.isAfter(last); d = d.plusDays(1)) {
            if ((daysOfWeekMask & (1 << (d.getDayOfWeek().getValue() - 1))) == 0) continue;
            for (LocalTime t : sorted) out.add(d.atTime(t));
        }
        return out;
    }

    public static int maskOf(List<Integer> isoDays) {
        if (isoDays == null || isoDays.isEmpty()) return 127;
        int mask = 0;
        for (int d : isoDays) mask |= 1 << (d - 1);
        return mask;
    }
}
