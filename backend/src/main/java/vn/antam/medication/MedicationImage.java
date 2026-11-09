package vn.antam.medication;

import java.time.Instant;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/** A photo that helps the elder recognise a medicine: the pill itself or its package. */
@Entity
@Table(name = "medication_images")
public class MedicationImage {

    public enum Kind { PILL, PACKAGE }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "medication_id", nullable = false)
    private Long medicationId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Kind kind;

    @Column(name = "storage_key", nullable = false, unique = true)
    private String storageKey;

    @Column(name = "mime_type", nullable = false)
    private String mimeType;

    @Column(name = "size_bytes", nullable = false)
    private int sizeBytes;

    @Column(nullable = false)
    private String sha256;

    @Column(name = "sort_order", nullable = false)
    private int sortOrder;

    @Column(name = "created_by", nullable = false)
    private Long createdBy;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "deleted_at")
    private Instant deletedAt;

    protected MedicationImage() {
    }

    public MedicationImage(Long medicationId, Kind kind, String storageKey, String mimeType, int sizeBytes, String sha256,
                           int sortOrder, Long createdBy, Instant now) {
        this.medicationId = medicationId;
        this.kind = kind;
        this.storageKey = storageKey;
        this.mimeType = mimeType;
        this.sizeBytes = sizeBytes;
        this.sha256 = sha256;
        this.sortOrder = sortOrder;
        this.createdBy = createdBy;
        this.createdAt = now;
    }

    /** Moves the photo to the new version of an edited medication. */
    void moveTo(Long newMedicationId) {
        this.medicationId = newMedicationId;
    }

    void delete(Instant now) {
        this.deletedAt = now;
    }

    public Long getId() { return id; }
    public Long getMedicationId() { return medicationId; }
    public Kind getKind() { return kind; }
    public String getStorageKey() { return storageKey; }
    public String getMimeType() { return mimeType; }
    public String getSha256() { return sha256; }
    public boolean isDeleted() { return deletedAt != null; }
}
