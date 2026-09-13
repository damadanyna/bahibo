import 'package:livekit_client/livekit_client.dart';

/// Connect options shared by the host and viewer live pages.
///
/// The SDK gives the media path (ICE checks, TURN allocation when the
/// operator's NAT needs it, DTLS) 10 s to come up after the signalling join,
/// then fails with "Timed out waiting for PeerConnection to connect". That
/// is short on a weak 4G link, so it is doubled here. The same `connection`
/// value also bounds the wait for the join answer — a server that takes
/// 20 s to answer a join is down anyway. Other timeouts keep the defaults.
const ConnectOptions liveConnectOptions = ConnectOptions(
  timeouts: Timeouts(
    connection: Duration(seconds: 20),
    debounce: Duration(milliseconds: 100),
    publish: Duration(seconds: 10),
    subscribe: Duration(seconds: 10),
    peerConnection: Duration(seconds: 20),
    iceRestart: Duration(seconds: 10),
  ),
);
