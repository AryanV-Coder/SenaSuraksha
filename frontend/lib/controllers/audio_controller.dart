class AudioController {
  Future<void> Function()? _stopRecording;
  
  void setStopRecordingFunction(Future<void> Function() stopRecording) {
    _stopRecording = stopRecording;
  }
  
  Future<void> stopRecording() async {
    if (_stopRecording != null) {
      await _stopRecording!();
    }
  }
}
