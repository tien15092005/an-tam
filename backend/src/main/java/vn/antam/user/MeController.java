package vn.antam.user;

import java.util.List;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import vn.antam.auth.CurrentUser;
import vn.antam.common.ApiException;
import vn.antam.group.GroupDtos.GroupSummary;
import vn.antam.group.GroupService;

@RestController
public class MeController {

    public record MeResponse(Long id, AccountType accountType, String displayName, String email, String phone,
                             List<GroupSummary> groups) {
    }

    private final UserRepository users;
    private final GroupService groups;

    public MeController(UserRepository users, GroupService groups) {
        this.users = users;
        this.groups = groups;
    }

    @GetMapping("/api/me")
    public MeResponse me(@CurrentUser Long me) {
        User u = users.findById(me).orElseThrow(() -> ApiException.notFound("tài khoản"));
        return new MeResponse(u.getId(), u.getAccountType(), u.getDisplayName(), u.getEmail(), u.getPhone(), groups.myGroups(me));
    }
}
