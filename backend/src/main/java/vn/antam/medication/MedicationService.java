package vn.antam.medication;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import vn.antam.common.ApiException;
import vn.antam.notification.Notifier;
import vn.antam.group.ElderProfile;
import vn.antam.group.ElderProfileRepository;
import vn.antam.group.FamilyGroupRepository;
import vn.antam.group.GroupAccess;
import vn.antam.group.GroupMember;
import vn.antam.group.GroupMemberRepository;
import vn.antam.group.GroupRole;
import vn.antam.medication.MedicationDtos.ImageInfo;
import vn.antam.medication.MedicationDtos.MedicationRequest;
import vn.antam.medication.MedicationDtos.MedicationResponse;
import vn.antam.medication.MedicationDtos.ScheduleResponse;

/**
 * Medications of an elder. Only the group owner changes them (plan §5); every change bumps the
 * group's schedule version, which tells the elder's phone to re-download and re-arm its alarms.
 */
@Service
public class MedicationService {

    static final int MAX_IMAGES_PER_MEDICATION = 4;

    private final MedicationRepository medications;
    private final MedicationImageRepository images;
    private final DoseLogRepository doseLogs;
    private final AuditLogRepository audit;
    private final GroupAccess access;
    private final GroupMemberRepository members;
    private final FamilyGroupRepository groups;
    private final ElderProfileRepository elders;
    private final ImageStore imageStore;
    private final Clock clock;
    private final vn.antam.care.CareService care;
    private final Notifier notifier;
    private final vn.antam.chat.ChatService chat;
    private final vn.antam.exercise.ExerciseService exercises;

    public MedicationService(MedicationRepository medications, MedicationImageRepository images, DoseLogRepository doseLogs,
                             AuditLogRepository audit, GroupAccess access, GroupMemberRepository members,
                             FamilyGroupRepository groups, ElderProfileRepository elders, ImageStore imageStore, Clock clock,
                             vn.antam.care.CareService care, Notifier notifier,
                             vn.antam.exercise.ExerciseService exercises, vn.antam.chat.ChatService chat) {
        this.medications = medications;
        this.images = images;
        this.doseLogs = doseLogs;
        this.audit = audit;
        this.access = access;
        this.members = members;
        this.groups = groups;
        this.elders = elders;
        this.imageStore = imageStore;
        this.clock = clock;
        this.care = care;
        this.notifier = notifier;
        this.chat = chat;
        this.exercises = exercises;
    }

    @Transactional(readOnly = true)
    public List<MedicationResponse> list(Long userId, Long groupId, Long elderUserId) {
        GroupMember me = access.requireMember(groupId, userId);
        if (me.getRole() == GroupRole.ELDER && !me.getUserId().equals(elderUserId)) {
            throw ApiException.forbidden("Bạn chỉ xem được thuốc của mình.");
        }
        ElderProfile elder = elderInGroup(groupId, elderUserId);
        return toResponses(groupId, medications.current(elderUserId, today(elder)));
    }

    @Transactional(readOnly = true)
    public ScheduleResponse scheduleForElder(Long elderUserId) {
        ElderProfile elder = elders.findById(elderUserId).orElseThrow(() -> ApiException.forbidden("Chỉ máy của người già mới tải lịch này."));
        GroupMember membership = members.findByGroupIdAndUserIdAndLeftAtIsNull(elder.getGroupId(), elderUserId)
                .filter(m -> m.getRole() == GroupRole.ELDER)
                .orElseThrow(() -> ApiException.notFound("nhóm"));
        long version = groups.findById(membership.getGroupId()).filter(g -> !g.isDeleted())
                .orElseThrow(() -> ApiException.notFound("nhóm")).getScheduleVersion();
        List<MedicationResponse> meds = toResponses(elder.getGroupId(), medications.current(elderUserId, today(elder)));
        return new ScheduleResponse(elder.getGroupId(), elderUserId, elder.getCallName(), elder.getTimezone(), version, meds,
                care.recentFor(elder), exercises.currentFor(elder), exercises.recentFor(elder));
    }

    @Transactional
    public MedicationResponse create(Long userId, Long groupId, Long elderUserId, MedicationRequest r) {
        access.requireOwner(groupId, userId);
        ElderProfile elder = elderInGroup(groupId, elderUserId);
        Instant now = clock.instant();
        MedicationFields f = fields(r, today(elder));
        Medication m = new Medication(groupId, elderUserId, UUID.randomUUID(), userId, now);
        m.apply(f);
        medications.save(m);
        changed(groupId, userId, "MEDICATION_CREATED", m, now);
        return toResponse(groupId, m, List.of());
    }

    /**
     * Full update. If the medication already has dose history and what/when changes, the old
     * version is closed and a new one starts today in the same series, so history stays truthful.
     */
    @Transactional
    public MedicationResponse update(Long userId, Long groupId, Long medicationId, MedicationRequest r) {
        access.requireOwner(groupId, userId);
        Medication current = medicationInGroup(groupId, medicationId);
        ElderProfile elder = elderInGroup(groupId, current.getElderUserId());
        LocalDate today = today(elder);
        Instant now = clock.instant();
        MedicationFields f = fields(r, current.getStartDate());

        boolean newVersion = f.changesScheduleOf(current)
                && current.getStartDate().isBefore(today)
                && doseLogs.existsByMedicationId(current.getId());
        Medication result;
        if (newVersion) {
            current.closeBefore(today);
            current.touch(userId, now);
            Medication next = new Medication(groupId, current.getElderUserId(), current.getSeriesId(), userId, now);
            MedicationFields fromToday = new MedicationFields(f.name(), f.strength(), f.dosage(), f.note(), f.shape(),
                    f.color(), f.imprint(), f.pillDescription(), f.times(), f.daysOfWeekMask(),
                    f.startDate().isBefore(today) ? today : f.startDate(), f.endDate(), current.getSource());
            next.apply(fromToday);
            medications.save(next);
            images.findByMedicationIdAndDeletedAtIsNullOrderBySortOrder(current.getId()).forEach(i -> i.moveTo(next.getId()));
            result = next;
        } else {
            current.apply(f);
            current.touch(userId, now);
            result = current;
        }
        changed(groupId, userId, newVersion ? "MEDICATION_NEW_VERSION" : "MEDICATION_UPDATED", result, now);
        return toResponse(groupId, result, images.findByMedicationIdAndDeletedAtIsNullOrderBySortOrder(result.getId()));
    }

    /** Soft delete: the elder stops being reminded; past doses keep their snapshot. */
    @Transactional
    public void delete(Long userId, Long groupId, Long medicationId) {
        access.requireOwner(groupId, userId);
        Medication m = medicationInGroup(groupId, medicationId);
        m.deactivate();
        m.touch(userId, clock.instant());
        changed(groupId, userId, "MEDICATION_DELETED", m, clock.instant());
    }

    @Transactional
    public ImageInfo addImage(Long userId, Long groupId, Long medicationId, MedicationImage.Kind kind, byte[] upload) {
        access.requireOwner(groupId, userId);
        Medication m = medicationInGroup(groupId, medicationId);
        List<MedicationImage> existing = images.findByMedicationIdAndDeletedAtIsNullOrderBySortOrder(m.getId());
        if (existing.size() >= MAX_IMAGES_PER_MEDICATION) {
            throw ApiException.badRequest("too_many_images", "Mỗi thuốc tối đa " + MAX_IMAGES_PER_MEDICATION + " ảnh.");
        }
        ImageStore.Stored stored = imageStore.save(upload);
        Instant now = clock.instant();
        MedicationImage img = images.save(new MedicationImage(m.getId(), kind == null ? MedicationImage.Kind.PILL : kind,
                stored.key(), stored.mimeType(), stored.sizeBytes(), stored.sha256(), existing.size(), userId, now));
        changed(groupId, userId, "MEDICATION_IMAGE_ADDED", m, now);
        return imageInfo(groupId, img);
    }

    @Transactional
    public void deleteImage(Long userId, Long groupId, Long medicationId, Long imageId) {
        access.requireOwner(groupId, userId);
        Medication m = medicationInGroup(groupId, medicationId);
        MedicationImage img = images.findById(imageId).filter(i -> i.getMedicationId().equals(m.getId()) && !i.isDeleted())
                .orElseThrow(() -> ApiException.notFound("ảnh"));
        img.delete(clock.instant());
        changed(groupId, userId, "MEDICATION_IMAGE_DELETED", m, clock.instant());
    }

    /** Photo bytes for any member of the group, including the elder's phone. */
    @Transactional(readOnly = true)
    public MedicationImage imageFor(Long userId, Long groupId, Long imageId) {
        access.requireMember(groupId, userId);
        MedicationImage img = images.findById(imageId).filter(i -> !i.isDeleted()).orElseThrow(() -> ApiException.notFound("ảnh"));
        medicationInGroup(groupId, img.getMedicationId());
        return img;
    }

    public byte[] imageBytes(MedicationImage img) {
        return imageStore.read(img.getStorageKey());
    }

    // ---- helpers

    private static String verb(String action) {
        if (action.endsWith("CREATED")) return "đã thêm";
        if (action.endsWith("DELETED")) return "đã xóa";
        if (action.contains("IMAGE")) return "đã đổi ảnh";
        return "đã sửa";
    }

    private void changed(Long groupId, Long userId, String action, Medication m, Instant now) {
        var group = groups.findById(groupId).orElseThrow();
        group.bumpScheduleVersion();
        // Data-only push so the elder's phone downloads the new schedule even while the app is closed.
        notifier.toUser(m.getElderUserId(), Notifier.Kind.SCHEDULE_CHANGED, groupId, m.getId(),
                "schedule:" + groupId + ":" + group.getScheduleVersion() + ":" + m.getElderUserId(), null, null, false);
        chat.system(groupId, chat.nameOf(userId) + " " + verb(action) + " thuốc " + m.getName(), null);
        audit.save(new AuditLog(groupId, userId, action, "MEDICATION", m.getId(),
                "{\"name\":\"" + jsonEscape(m.getName()) + "\",\"seriesId\":\"" + m.getSeriesId() + "\"}", now));
    }

    private Medication medicationInGroup(Long groupId, Long medicationId) {
        return medications.findById(medicationId)
                .filter(m -> m.getGroupId().equals(groupId) && m.isActive())
                .orElseThrow(() -> ApiException.notFound("thuốc"));
    }

    private ElderProfile elderInGroup(Long groupId, Long elderUserId) {
        return members.findByGroupIdAndUserIdAndLeftAtIsNull(groupId, elderUserId)
                .filter(m -> m.getRole() == GroupRole.ELDER)
                .flatMap(m -> elders.findById(elderUserId))
                .orElseThrow(() -> ApiException.notFound("người già trong nhóm"));
    }

    private LocalDate today(ElderProfile elder) {
        return LocalDate.now(clock.withZone(ZoneId.of(elder.getTimezone())));
    }

    private static MedicationFields fields(MedicationRequest r, LocalDate defaultStart) {
        List<LocalTime> times = r.times().stream().map(LocalTime::parse).distinct().sorted().toList();
        short mask = 0;
        if (r.daysOfWeek() == null || r.daysOfWeek().isEmpty()) {
            mask = 127;
        } else {
            for (Integer d : r.daysOfWeek()) {
                if (d == null || d < 1 || d > 7) throw ApiException.badRequest("validation", "Ngày trong tuần phải từ 1 (Thứ 2) đến 7 (Chủ nhật).");
                mask |= (short) (1 << (d - 1));
            }
        }
        LocalDate start = r.startDate() != null ? r.startDate() : defaultStart;
        if (r.endDate() != null && r.endDate().isBefore(start)) {
            throw ApiException.badRequest("validation", "Ngày kết thúc phải sau ngày bắt đầu.");
        }
        return new MedicationFields(r.name().trim(), blank(r.strength()), blank(r.dosage()), blank(r.note()), blank(r.shape()),
                blank(r.color()), blank(r.imprint()), blank(r.pillDescription()), times, mask, start, r.endDate(), r.source());
    }

    private List<MedicationResponse> toResponses(Long groupId, List<Medication> meds) {
        if (meds.isEmpty()) return List.of();
        Map<Long, List<MedicationImage>> byMed = images
                .findByMedicationIdInAndDeletedAtIsNullOrderBySortOrder(meds.stream().map(Medication::getId).toList())
                .stream().collect(Collectors.groupingBy(MedicationImage::getMedicationId));
        return meds.stream().map(m -> toResponse(groupId, m, byMed.getOrDefault(m.getId(), List.of()))).toList();
    }

    private MedicationResponse toResponse(Long groupId, Medication m, List<MedicationImage> imgs) {
        List<Integer> days = new ArrayList<>();
        for (int d = 1; d <= 7; d++) if ((m.getDaysOfWeek() & (1 << (d - 1))) != 0) days.add(d);
        return new MedicationResponse(m.getId(), m.getSeriesId(), m.getElderUserId(), m.getName(), m.getStrength(),
                m.getDosage(), m.getNote(), m.getShape(), m.getColor(), m.getImprint(), m.getPillDescription(),
                m.timeList().stream().map(t -> t.toString().substring(0, 5)).toList(), days, m.getStartDate(), m.getEndDate(),
                m.getSource(), imgs.stream().map(i -> imageInfo(groupId, i)).toList(), m.getCreatedAt(),
                m.getUpdatedAt() != null ? m.getUpdatedAt() : m.getCreatedAt());
    }

    private static ImageInfo imageInfo(Long groupId, MedicationImage i) {
        return new ImageInfo(i.getId(), i.getKind(), "/api/groups/" + groupId + "/medication-images/" + i.getId(), i.getSha256());
    }

    private static String blank(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }

    private static String jsonEscape(String s) {
        return s.replace("\\", "\\\\").replace("\"", "\\\"");
    }
}
