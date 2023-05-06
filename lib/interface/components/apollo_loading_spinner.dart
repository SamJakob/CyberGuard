import 'package:flare_flutter/flare.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flare_flutter/flare_controller.dart';
import 'package:flutter/material.dart';

class ApolloLoadingSpinner extends StatelessWidget {
  final Color? color;
  final double size;

  const ApolloLoadingSpinner({
    super.key,
    this.color,
    this.size = 48,
  });

  @override
  Widget build(final BuildContext context) {
    return SizedBox(
      height: size,
      width: size,
      child: FlareActor(
        "res/flare/loader.flr",
        alignment: Alignment.center,
        fit: BoxFit.fill,
        animation: "loading",
        controller: ApolloLoadingSpinnerController(context, color),
      ),
    );
  }
}

class ApolloLoadingSpinnerController extends FlareController {
  final BuildContext context;
  Color? primaryColor;

  ApolloLoadingSpinnerController(this.context, this.primaryColor) {
    primaryColor ??= Theme.of(context).primaryColor;
  }

  @override
  bool advance(final FlutterActorArtboard artboard, final double elapsed) {
    return true;
  }

  @override
  void initialize(final FlutterActorArtboard artboard) {
    artboard.nodes.whereType<FlutterActorShape>().forEach(
        (final ActorNode? node) => (node as FlutterActorShape)
                .strokes
                .whereType<FlutterColorStroke>()
                .cast<FlutterColorStroke>()
                .forEach((final FlutterColorStroke stroke) {
              switch (node.name) {
                case "Light":
                  stroke.uiColor = primaryColor!;
                  break;
                case "Middle":
                  Color middleColor = primaryColor!
                      .withRed((primaryColor!.red * 0.8).round())
                      .withGreen((primaryColor!.green * 0.8).round())
                      .withBlue((primaryColor!.blue * 0.8).round());

                  stroke.uiColor = middleColor;
                  break;
                case "Dark":
                  Color darkenedColor = primaryColor!
                      .withRed((primaryColor!.red * 0.6).round())
                      .withGreen((primaryColor!.green * 0.6).round())
                      .withBlue((primaryColor!.blue * 0.6).round())
                      .withOpacity(0.8);

                  stroke.uiColor = darkenedColor;
                  break;
              }
            }));
  }

  @override
  void setViewTransform(final Mat2D viewTransform) {}
}
