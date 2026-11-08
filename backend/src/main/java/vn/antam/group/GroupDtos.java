package vn.antam.group;

import java.time.Instant;
import java.util.List;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** Request and response bodies for the family group API. */
public final class GroupDtos {

    private GroupDtos() {
    }

    public record GroupSummary(Long id, String name, GroupRole myRole) {
    }

    public record Member(Long userId, String displayName, String phone, GroupRole role, Instant joinedAt, ElderInfo elder) {
    }

    public record ElderInfo(String callName, Short birthYear, String healthNote, String timezone) {
    }

    public record GroupDetail(Long id, String name, GroupRole myRole, long scheduleVersion, List<Member> members) {
    }

    public record NameRequest(@NotBlank @Size(max = 100) String name) {
    }

    public record ElderRequest(@NotBlank @Size(max = 60) String callName,
                               @Min(1900) @Max(2100) Short birthYear,
                               @Size(max = 20) String phone,
                               @Size(max = 500) String healthNote,
                               @Size(max = 40) String timezone) {
    }

    public record CodeResponse(String code, Instant expiresAt) {
    }

    public record AcceptInviteRequest(@NotBlank @Size(max = 20) String code) {
    }

    public record TransferRequest(Long userId) {
    }
}
