package vn.antam.group;

import java.util.List;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import vn.antam.auth.CurrentUser;
import vn.antam.group.GroupDtos.AcceptInviteRequest;
import vn.antam.group.GroupDtos.CodeResponse;
import vn.antam.group.GroupDtos.ElderRequest;
import vn.antam.group.GroupDtos.GroupDetail;
import vn.antam.group.GroupDtos.GroupSummary;
import vn.antam.group.GroupDtos.Member;
import vn.antam.group.GroupDtos.NameRequest;
import vn.antam.group.GroupDtos.TransferRequest;

@RestController
@RequestMapping("/api")
public class GroupController {

    private final GroupService groups;

    public GroupController(GroupService groups) {
        this.groups = groups;
    }

    @GetMapping("/groups")
    public List<GroupSummary> myGroups(@CurrentUser Long me) {
        return groups.myGroups(me);
    }

    @PostMapping("/groups")
    @ResponseStatus(HttpStatus.CREATED)
    public GroupSummary create(@CurrentUser Long me, @Valid @RequestBody NameRequest r) {
        return groups.create(me, r.name());
    }

    @GetMapping("/groups/{groupId}")
    public GroupDetail detail(@CurrentUser Long me, @PathVariable Long groupId) {
        return groups.detail(me, groupId);
    }

    @PatchMapping("/groups/{groupId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void rename(@CurrentUser Long me, @PathVariable Long groupId, @Valid @RequestBody NameRequest r) {
        groups.rename(me, groupId, r.name());
    }

    @PostMapping("/groups/{groupId}/invites")
    @ResponseStatus(HttpStatus.CREATED)
    public CodeResponse invite(@CurrentUser Long me, @PathVariable Long groupId) {
        return groups.createMemberInvite(me, groupId);
    }

    @PostMapping("/invites/accept")
    public GroupSummary accept(@CurrentUser Long me, @Valid @RequestBody AcceptInviteRequest r, HttpServletRequest http) {
        return groups.acceptInvite(me, r.code(), http.getRemoteAddr());
    }

    @PostMapping("/groups/{groupId}/elders")
    @ResponseStatus(HttpStatus.CREATED)
    public Member addElder(@CurrentUser Long me, @PathVariable Long groupId, @Valid @RequestBody ElderRequest r) {
        return groups.addElder(me, groupId, r);
    }

    @PatchMapping("/groups/{groupId}/elders/{elderUserId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void updateElder(@CurrentUser Long me, @PathVariable Long groupId, @PathVariable Long elderUserId,
                            @Valid @RequestBody ElderRequest r) {
        groups.updateElder(me, groupId, elderUserId, r);
    }

    @PostMapping("/groups/{groupId}/elders/{elderUserId}/pairing-code")
    @ResponseStatus(HttpStatus.CREATED)
    public CodeResponse pairingCode(@CurrentUser Long me, @PathVariable Long groupId, @PathVariable Long elderUserId) {
        return groups.createPairingCode(me, groupId, elderUserId);
    }

    @PostMapping("/groups/{groupId}/transfer-ownership")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void transfer(@CurrentUser Long me, @PathVariable Long groupId, @RequestBody TransferRequest r) {
        groups.transferOwnership(me, groupId, r.userId());
    }

    @DeleteMapping("/groups/{groupId}/members/{userId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void remove(@CurrentUser Long me, @PathVariable Long groupId, @PathVariable Long userId) {
        groups.removeMember(me, groupId, userId);
    }

    @PostMapping("/groups/{groupId}/leave")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void leave(@CurrentUser Long me, @PathVariable Long groupId,
                      @RequestParam(defaultValue = "false") boolean confirmDelete) {
        groups.leave(me, groupId, confirmDelete);
    }
}
