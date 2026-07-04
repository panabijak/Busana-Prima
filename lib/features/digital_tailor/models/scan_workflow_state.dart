/// Finite states for the Smart Guided Scan workflow.
enum ScanWorkflowState {
  searching,
  aligning,
  locking,
  locked,
  countdown,
  capturing,
  processing,
  completed,
}

extension ScanWorkflowStateLabel on ScanWorkflowState {
  String get label {
    switch (this) {
      case ScanWorkflowState.searching:
        return 'SEARCHING';
      case ScanWorkflowState.aligning:
        return 'ALIGNING';
      case ScanWorkflowState.locking:
        return 'LOCKING';
      case ScanWorkflowState.locked:
        return 'LOCKED';
      case ScanWorkflowState.countdown:
        return 'COUNTDOWN';
      case ScanWorkflowState.capturing:
        return 'CAPTURING';
      case ScanWorkflowState.processing:
        return 'PROCESSING';
      case ScanWorkflowState.completed:
        return 'COMPLETED';
    }
  }
}
