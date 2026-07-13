enum TransferTaskDirection { incoming, outgoing }

enum TransferTaskStatus { waiting, transferring, completed, failed, cancelled }

class TransferTask {
  const TransferTask({
    required this.id,
    required this.direction,
    required this.status,
    required this.peerAlias,
    required this.fileName,
    required this.fileCount,
    required this.totalBytes,
    this.progress,
    this.subtitle,
    this.receivedFiles = 0,
  });

  factory TransferTask.outgoing({
    required String id,
    required String peerAlias,
    required String fileName,
    required int fileCount,
    required int totalBytes,
  }) {
    return TransferTask(
      id: id,
      direction: TransferTaskDirection.outgoing,
      status: TransferTaskStatus.transferring,
      peerAlias: peerAlias,
      fileName: fileName,
      fileCount: fileCount,
      totalBytes: totalBytes,
      progress: 0,
      subtitle: '准备发送',
    );
  }

  factory TransferTask.incomingRequest({
    required String id,
    required String peerAlias,
    required String fileName,
    required int fileCount,
    required int totalBytes,
  }) {
    return TransferTask(
      id: id,
      direction: TransferTaskDirection.incoming,
      status: TransferTaskStatus.waiting,
      peerAlias: peerAlias,
      fileName: fileName,
      fileCount: fileCount,
      totalBytes: totalBytes,
      subtitle: '等待确认',
    );
  }

  final String id;
  final TransferTaskDirection direction;
  final TransferTaskStatus status;
  final String peerAlias;
  final String fileName;
  final int fileCount;
  final int totalBytes;
  final double? progress;
  final String? subtitle;
  final int receivedFiles;

  TransferTask copyWith({
    TransferTaskStatus? status,
    double? progress,
    String? subtitle,
    int? receivedFiles,
  }) {
    return TransferTask(
      id: id,
      direction: direction,
      status: status ?? this.status,
      peerAlias: peerAlias,
      fileName: fileName,
      fileCount: fileCount,
      totalBytes: totalBytes,
      progress: progress ?? this.progress,
      subtitle: subtitle ?? this.subtitle,
      receivedFiles: receivedFiles ?? this.receivedFiles,
    );
  }
}
