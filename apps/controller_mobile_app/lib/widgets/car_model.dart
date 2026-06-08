import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

class CarModel extends StatefulWidget {
  final bool brakeLightOn;

  const CarModel({super.key, this.brakeLightOn = false});

  @override
  State<CarModel> createState() => _CarModelState();
}

class _CarModelState extends State<CarModel> {
  WebViewController? _webViewController;

  @override
  void didUpdateWidget(CarModel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.brakeLightOn != widget.brakeLightOn) {
      _updateBrakeLights();
    }
  }

  void _updateBrakeLights() {
    if (_webViewController == null) return;

    final js =
        '''
  (function() {
    const modelViewer = document.querySelector('model-viewer');
    if (!modelViewer) return;

    function updateBrakeLights() {
      const mat = modelViewer.model.getMaterialByName('clearglass');
      if (!mat) {
        console.error('Material brake_lights not found');
        return;
      }
      mat.setEmissiveFactor([${widget.brakeLightOn ? 1.0 : 0.0}, 0.0, 0.0]);
      const ext = mat.extensions?.KHR_materials_emissive_strength;
      if (ext) {
        ext.setEmissiveStrength(${widget.brakeLightOn ? 10.0 : 0.0});
      }
    }

    if (modelViewer.loaded) {
      updateBrakeLights();
    } else {
      modelViewer.addEventListener('load', updateBrakeLights, { once: true });
    }
  })();
''';

    _webViewController!.runJavaScript(js);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Manual shadow beneath the car
        Positioned.fill(
          child: Align(
            alignment: Alignment.center,
            child: Container(
              width: 180,
              height: 80,
              margin: const EdgeInsets.only(top: 60),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 40,
                    spreadRadius: 30,
                    offset: const Offset(0, 50),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 25,
                    spreadRadius: 15,
                    offset: const Offset(0, 10),
                  ),
                ],
                gradient: RadialGradient(
                  colors: [
                    Colors.black.withOpacity(0.5),
                    Colors.black.withOpacity(0.2),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        ),
        // 3D Model
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.45),
            BlendMode.srcATop,
          ),
          child: ModelViewer(
            src: 'assets/mitsubishi.glb',
            alt: 'RC Car 3D Model',
            autoRotate: false,
            cameraControls: true,
            backgroundColor: Colors.transparent,
            minCameraOrbit: 'auto 75deg auto',
            maxCameraOrbit: 'auto 75deg auto',
            cameraOrbit: '0deg 75deg 125%',
            shadowIntensity: 1.0,
            shadowSoftness: 1.0,
            environmentImage: 'neutral',
            exposure: 0.5,
            disableTap: true,
            onWebViewCreated: (controller) {
              _webViewController = controller;
              Future.delayed(const Duration(milliseconds: 2000), () {
                _updateBrakeLights();
              });
            },
          ),
        ),
      ],
    );
  }
}
