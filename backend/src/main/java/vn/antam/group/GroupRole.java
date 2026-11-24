package vn.antam.group;

/** Role inside one family group (see SKILL_AN_TAM.md §5). */
public enum GroupRole {
    /** The single highest-permission caregiver: sets schedules, manages members. */
    OWNER,
    /** Another caregiver: views, handles alerts, marks doses on the elder's behalf. */
    MEMBER,
    /** An elder whose medication is managed by the group. */
    ELDER
}
