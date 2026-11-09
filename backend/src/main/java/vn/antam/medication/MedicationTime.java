package vn.antam.medication;

import java.time.LocalTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

@Entity
@Table(name = "medication_times")
public class MedicationTime {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "medication_id")
    private Medication medication;

    @Column(name = "time_of_day", nullable = false)
    private LocalTime timeOfDay;

    protected MedicationTime() {
    }

    MedicationTime(Medication medication, LocalTime timeOfDay) {
        this.medication = medication;
        this.timeOfDay = timeOfDay;
    }

    public LocalTime getTimeOfDay() {
        return timeOfDay;
    }
}
