import 'package:flutter_test/flutter_test.dart';
import 'package:hris_mobile/services/cuti_approval_access.dart';
import 'package:hris_mobile/services/employee_request.dart';
import 'package:hris_mobile/services/leave_leader_service.dart';

void main() {
  test('parsing data leader dari leave_leaders.php', () {
    final LeaveLeader leader = LeaveLeader.fromJson(<String, dynamic>{
      'id': 3,
      'user_id': 9,
      'employee_id': 12,
      'username': 'andi',
      'nama_lengkap': 'Andi Pratama',
      'keterangan': 'Kepala Bagian',
    });

    expect(leader.id, 3);
    expect(leader.userId, 9);
    expect(leader.employeeId, 12);
    expect(leader.displayName, 'Andi Pratama');
    expect(
      leader.keterangan,
      'Kepala Bagian',
    );
  });

  test('nama leader memakai username bila nama lengkap kosong', () {
    final LeaveLeader leader = LeaveLeader.fromJson(<String, dynamic>{
      'id': 1,
      'user_id': 4,
      'username': 'siti',
      'nama_lengkap': '',
      'keterangan': null,
    });
    expect(leader.displayName, 'siti');
    expect(leader.keterangan, isEmpty);
  });

  test('parsing eligible users untuk dialog tambah leader', () {
    final EligibleLeaveUser user = EligibleLeaveUser.fromJson(<String, dynamic>{
      'user_id': 11,
      'username': 'rina',
      'nama_lengkap': 'Rina Wati',
      'employee_id': 20,
    });
    expect(user.userId, 11);
    expect(user.displayName, 'Rina Wati');
  });

  test('pengajuan cuti wajib membawa leader_user_id', () {
    final Map<String, dynamic> payload = EmployeeRequest.leaveCreatePayload(
      employeeId: 42,
      title: 'Cuti Tahunan',
      reason: 'Keluarga',
      startDate: '2026-11-25',
      endDate: '2026-11-26',
      leaderUserId: 9,
    );
    expect(payload['leader_user_id'], 9);
  });

  test('tombol approval hanya tampil untuk leader pada pengajuan sendiri', () {
    expect(
      CutiApprovalAccess.canApprove(
        isHr: true,
        isLeaveLeader: true,
        isPending: true,
        leaderUserId: 9,
        currentUserId: 9,
      ),
      isTrue,
      reason: 'HR yang juga Leader boleh menyetujui',
    );
    expect(
      CutiApprovalAccess.canApprove(
        isHr: false,
        isLeaveLeader: false,
        isPending: true,
        leaderUserId: 9,
        currentUserId: 9,
      ),
      isFalse,
      reason: 'bukan leader tidak boleh menyetujui',
    );
    expect(
      CutiApprovalAccess.canApprove(
        isHr: false,
        isLeaveLeader: true,
        isPending: true,
        leaderUserId: 10,
        currentUserId: 9,
      ),
      isFalse,
      reason: 'leader lain tidak boleh menyetujui',
    );
    expect(
      CutiApprovalAccess.canApprove(
        isHr: false,
        isLeaveLeader: true,
        isPending: true,
        leaderUserId: 9,
        currentUserId: 9,
      ),
      isTrue,
    );
    expect(
      CutiApprovalAccess.canApprove(
        isHr: false,
        isLeaveLeader: true,
        isPending: false,
        leaderUserId: 9,
        currentUserId: 9,
      ),
      isFalse,
      reason: 'yang sudah diproses tidak bisa diulang',
    );
  });
}
