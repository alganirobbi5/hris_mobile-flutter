class CutiApprovalAccess {
  const CutiApprovalAccess._();

  static bool canApprove({
    required bool isHr,
    required bool isLeaveLeader,
    required bool isPending,
    required int leaderUserId,
    int? currentUserId,
  }) {
    if (isHr || !isLeaveLeader || !isPending) return false;
    return leaderUserId == 0 || leaderUserId == currentUserId;
  }
}
