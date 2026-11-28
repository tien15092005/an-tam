package vn.antam.app.alarm;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class AlarmPolicyTest {

    private static final long MIN = 60_000;

    @Test
    public void aDoseRingsAtMostThreeTimes() {
        assertTrue(AlarmPolicy.mayRingAgain(1));
        assertTrue(AlarmPolicy.mayRingAgain(2));
        assertFalse(AlarmPolicy.mayRingAgain(3));
    }

    @Test
    public void anUnansweredRingComesBackTenMinutesAfterItStarted() {
        long start = 1_000_000_000L;
        assertEquals(start + 10 * MIN, AlarmPolicy.retryAt(start, start + 2 * MIN));
        // If the ring started long ago (phone was busy), never schedule in the past: one minute from now.
        assertEquals(start + 30 * MIN + MIN, AlarmPolicy.retryAt(start, start + 30 * MIN));
    }

    @Test
    public void repeatsDecodeToTheSameDoseAndARepeatOfARepeatKeepsItsId() {
        int schedule = AlarmScheduler.SCHEDULE_ID_BASE + 29_000_000;
        int repeat = AlarmPolicy.followUpId(schedule);
        assertEquals(schedule - AlarmScheduler.FOLLOW_UP_OFFSET, repeat);
        assertEquals(repeat, AlarmPolicy.followUpId(repeat));
    }

    @Test
    public void afterARebootARecentlyMissedAlarmRingsAndAnOldOneIsDropped() {
        long now = 5_000_000_000L;
        assertEquals(AlarmPolicy.Rearm.ARM, AlarmPolicy.onRestart(now + MIN, now));
        assertEquals(AlarmPolicy.Rearm.RING_NOW, AlarmPolicy.onRestart(now - 3 * MIN, now)); // 8:00 dose, phone back 8:03
        assertEquals(AlarmPolicy.Rearm.RING_NOW, AlarmPolicy.onRestart(now - 29 * MIN, now));
        assertEquals(AlarmPolicy.Rearm.DROP, AlarmPolicy.onRestart(now - 30 * MIN, now));
    }

    @Test
    public void alarmVolumeBelowHalfIsTooLowAndRaisingSetsEightyPercent() {
        assertTrue(AlarmPolicy.volumeTooLow(0, 7));
        assertTrue(AlarmPolicy.volumeTooLow(3, 7));
        assertFalse(AlarmPolicy.volumeTooLow(4, 7));
        assertEquals(6, AlarmPolicy.raisedVolume(7));
        assertTrue(AlarmPolicy.volumeTooLow(0, 0));
    }
}
