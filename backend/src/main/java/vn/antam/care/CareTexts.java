package vn.antam.care;

import java.time.LocalTime;

import vn.antam.medication.DoseLog;

/** Wording of the notifications caregivers receive. Calm, factual, no medical advice (plan §9, §11). */
final class CareTexts {

    private CareTexts() {
    }

    static String alertTitle(String elder, Alert.Kind kind) {
        return switch (kind) {
            case UNWELL -> elder + " báo không khỏe";
            case LOST_MEDICINE -> elder + " báo mất thuốc";
            case OUT_OF_MEDICINE -> elder + " báo hết thuốc";
            case UNSURE_PILL -> elder + " không chắc đúng thuốc";
            case OTHER_ISSUE -> elder + " báo có vấn đề";
            // "Not confirmed", never "forgot": the phone may be off or offline (plan §9).
            case NOT_CONFIRMED -> elder + " chưa xác nhận uống thuốc";
        };
    }

    static String alertBody(Alert a) {
        String when = a.getScheduledTime() == null ? null : hhmm(a.getScheduledTime());
        String meds = a.getMedicationNames();
        String about = when == null ? null : meds == null ? "Lần uống " + when : when + " · " + meds;
        if (a.getKind() == Alert.Kind.NOT_CONFIRMED) {
            return about + ". Máy có thể đang tắt hoặc mất mạng, hãy gọi hỏi thăm.";
        }
        if (a.getKind() == Alert.Kind.UNWELL) {
            return (about == null ? "" : about + ". ") + "Hãy gọi hỏi thăm. Nếu nguy cấp, gọi cấp cứu 115.";
        }
        return about == null ? "Mở An Tâm để xem." : about;
    }

    static String reportTitle(String elder, DoseLog.Status status) {
        return status == DoseLog.Status.TAKEN ? elder + " đã uống thuốc" : elder + " không uống được thuốc";
    }

    static String markedTitle(String caregiver, String elder) {
        return caregiver + " đã đánh dấu giúp " + elder;
    }

    static String hhmm(LocalTime t) {
        return t.toString().substring(0, 5);
    }
}
