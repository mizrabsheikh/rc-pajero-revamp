// import 'package:flutter/material.dart';
// import 'package:flutterino/flutterino.dart';

// class StatusCard extends StatelessWidget {
//   final ConnectionStatus hardwareStatus;
//   final String cloudStatus;

//   const StatusCard({
//     super.key,
//     required this.hardwareStatus,
//     required this.cloudStatus,
//   });

//   @override
//   Widget build(BuildContext context) {
//     Color statusColor = Colors.grey;
//     IconData statusIcon = Icons.usb_off;

//     switch (hardwareStatus) {
//       case ConnectionStatus.connected:
//         statusColor = Colors.greenAccent;
//         statusIcon = Icons.check_circle;
//         break;
//       case ConnectionStatus.searching:
//       case ConnectionStatus.reconnecting:
//         statusColor = Colors.orangeAccent;
//         statusIcon = Icons.sync;
//         break;
//       case ConnectionStatus.error:
//       case ConnectionStatus.permissionDenied:
//         statusColor = Colors.redAccent;
//         statusIcon = Icons.error;
//         break;
//       default:
//         break;
//     }

//     return Card(
//       elevation: 4,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: Padding(
//         padding: const EdgeInsets.all(20.0),
//         child: Column(
//           children: [
//             Row(
//               children: [
//                 Icon(statusIcon, color: statusColor, size: 32),
//                 const SizedBox(width: 16),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       const Text(
//                         'Hardware Status',
//                         style: TextStyle(fontSize: 12, color: Colors.white70),
//                       ),
//                       Text(
//                         hardwareStatus.name.toUpperCase(),
//                         style: TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.bold,
//                           color: statusColor,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//             const Divider(height: 24),
//             Row(
//               children: [
//                 Icon(
//                   cloudStatus == 'Connected'
//                       ? Icons.cloud_done
//                       : Icons.cloud_off,
//                   color: cloudStatus == 'Connected'
//                       ? Colors.cyanAccent
//                       : Colors.grey,
//                   size: 32,
//                 ),
//                 const SizedBox(width: 16),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       const Text(
//                         'Cloud Status',
//                         style: TextStyle(fontSize: 12, color: Colors.white70),
//                       ),
//                       Text(
//                         cloudStatus.toUpperCase(),
//                         style: TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.bold,
//                           color: cloudStatus == 'Connected'
//                               ? Colors.cyanAccent
//                               : Colors.grey,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
