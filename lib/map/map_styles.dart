import 'package:flutter/material.dart';

/// Styles JSON Google Maps de l'app : épuré, POI réduits, routes lisibles.
/// Le mode sombre utilise #121212 comme fond (spec design).
class MapStyles {
  MapStyles._();

  static const Color brandOrange = Color(0xFFFF6600);

  static String forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  static const String light = '''[
    {"elementType":"geometry","stylers":[{"color":"#f6f5f2"}]},
    {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
    {"elementType":"labels.text.fill","stylers":[{"color":"#6b6b6b"}]},
    {"elementType":"labels.text.stroke","stylers":[{"color":"#ffffff"},{"weight":3}]},
    {"featureType":"administrative","elementType":"geometry","stylers":[{"visibility":"off"}]},
    {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#2b2b2b"}]},
    {"featureType":"administrative.neighborhood","elementType":"labels.text.fill","stylers":[{"color":"#8a8a8a"}]},
    {"featureType":"poi","stylers":[{"visibility":"off"}]},
    {"featureType":"poi.park","elementType":"geometry","stylers":[{"visibility":"on"},{"color":"#e3eedb"}]},
    {"featureType":"poi.park","elementType":"labels","stylers":[{"visibility":"off"}]},
    {"featureType":"transit","stylers":[{"visibility":"off"}]},
    {"featureType":"landscape.man_made","elementType":"geometry","stylers":[{"color":"#efedea"}]},
    {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#ffffff"}]},
    {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#e2ded8"},{"weight":1}]},
    {"featureType":"road.arterial","elementType":"geometry.fill","stylers":[{"color":"#ffffff"}]},
    {"featureType":"road.arterial","elementType":"geometry.stroke","stylers":[{"color":"#d9d4cc"}]},
    {"featureType":"road.highway","elementType":"geometry.fill","stylers":[{"color":"#ffe9d6"}]},
    {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#f5cfa8"}]},
    {"featureType":"road.local","elementType":"labels","stylers":[{"visibility":"simplified"}]},
    {"featureType":"water","elementType":"geometry","stylers":[{"color":"#cfe0ee"}]},
    {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#7d9bb3"}]}
  ]''';

  static const String dark = '''[
    {"elementType":"geometry","stylers":[{"color":"#121212"}]},
    {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
    {"elementType":"labels.text.fill","stylers":[{"color":"#8c8c8c"}]},
    {"elementType":"labels.text.stroke","stylers":[{"color":"#121212"},{"weight":3}]},
    {"featureType":"administrative","elementType":"geometry","stylers":[{"visibility":"off"}]},
    {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#c7c7c7"}]},
    {"featureType":"poi","stylers":[{"visibility":"off"}]},
    {"featureType":"poi.park","elementType":"geometry","stylers":[{"visibility":"on"},{"color":"#16211a"}]},
    {"featureType":"poi.park","elementType":"labels","stylers":[{"visibility":"off"}]},
    {"featureType":"transit","stylers":[{"visibility":"off"}]},
    {"featureType":"landscape.man_made","elementType":"geometry","stylers":[{"color":"#181818"}]},
    {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#2a2a2a"}]},
    {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#1a1a1a"},{"weight":1}]},
    {"featureType":"road.arterial","elementType":"geometry.fill","stylers":[{"color":"#333333"}]},
    {"featureType":"road.highway","elementType":"geometry.fill","stylers":[{"color":"#4a3826"}]},
    {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#2a2018"}]},
    {"featureType":"road.local","elementType":"labels","stylers":[{"visibility":"simplified"}]},
    {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0a1620"}]},
    {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#4a6275"}]}
  ]''';
}
