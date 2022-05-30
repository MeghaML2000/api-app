import 'dart:async';
import 'dart:developer';
import 'dart:math' as Math;

import 'package:air_quality/air_quality.dart';
import 'package:aqi_app/place_service.dart';
import 'package:aqi_app/secrets.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import 'package:uuid/uuid.dart';
import 'address_search.dart';

// import 'address_search.dart';
// import 'place_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
// final BehaviorSubject<ReceivedNotification> didReceiveLocalNotificationSubject =
//     BehaviorSubject<ReceivedNotification>();

// final BehaviorSubject<String?> selectNotificationSubject =
//     BehaviorSubject<String?>();

const MethodChannel platform =
    MethodChannel('dexterx.dev/flutter_local_notifications_example');

class ReceivedNotification {
  ReceivedNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final String? title;
  final String? body;
  final String? payload;
}

String? selectedNotificationPayload;
main() async {
  // await Firebase.initializeApp();
  WidgetsFlutterBinding.ensureInitialized();
  AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
            channelGroupKey: 'basic_tests',
            channelKey: 'basic_channel',
            channelName: 'Basic notifications',
            channelDescription: 'Notification channel for basic tests',
            defaultColor: const Color(0xFF9D50DD),
            ledColor: Colors.white,
            importance: NotificationImportance.High),
      ],
      channelGroups: [
        NotificationChannelGroup(
            channelGroupkey: 'basic_tests', channelGroupName: 'Basic tests'),
      ],
      debug: true);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Maps',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Map Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  StreamSubscription? _locationSubscription;
  List<Marker> markersList = [];
  List<GeoPoint> positionsList = [];
  final loc.Location _locationTracker = loc.Location();
  Marker? marker;
  double rotation = 0.0;
  Circle? circle;
  GoogleMapController? _controller;
  // final positionCollection = FirebaseFirestore.instance.collection("positions");
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static CameraPosition initialLocation = const CameraPosition(
    target: LatLng(12.87, 77.54),
    zoom: 14.4746,
  );
  var imageDataBreaker;
  @override
  initState() {
    super.initState();
    Future.delayed(Duration.zero).then((value) async {
      // await fetchMarkers();
      // imageDataBreaker = await getSpeedBreakerMarker();
      var location = await _locationTracker.getLocation();
      setState(() {
        initialLocation = CameraPosition(
          target: LatLng(location.latitude!, location.longitude!),
          zoom: 14.4746,
        );
      });
    });
  }

  getAQI(LatLng latLng) async {
    setState(() {
      isLoading = true;
    });
    AirQuality airQuality = AirQuality(Secrets.AQI_API_KEY);
    try {
      AirQualityData feedFromGeoLocation = await airQuality.feedFromGeoLocation(
          latLng.latitude, latLng.longitude);
      setState(() {
        isLoading = false;
      });
      return feedFromGeoLocation.airQualityIndex;
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      return 0;
    }
  }

  Future<void> _showNotificationCustomSound() async {
    AwesomeNotifications().createNotification(
        content: NotificationContent(
            id: 10,
            channelKey: 'basic_channel',
            title:
                '🟢 Average AQI is ${airIndex1 > airIndex2 ? airIndex2 : airIndex1}',
            body:
                'Distance ${bestAirIndexLine == 0 ? _placeDistance : _placeDistance1}'));
  }

  @override
  void dispose() {
    if (_locationSubscription != null) {
      _locationSubscription!.cancel();
    }
    super.dispose();
  }

  late Position _currentPosition;
  final String _currentAddress = '';

  final startAddressController = TextEditingController();
  final destinationAddressController = TextEditingController();

  final startAddressFocusNode = FocusNode();
  final desrinationAddressFocusNode = FocusNode();

  String _startAddress = '';
  String _destinationAddress = '';
  String? _placeDistance;
  String? _placeDistance1;

  Set<Marker> markers = {};

  late PolylinePoints polylinePoints;
  Map<PolylineId, Polyline> polylines = {};
  List<LatLng> polylineCoordinates = [];
  int polyLineIndex = 0;
  bool isLoading = false;

  Widget _textField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required double width,
    required Icon prefixIcon,
    Widget? suffixIcon,
    required Function(String) locationCallback,
  }) {
    return SizedBox(
      width: width * 0.9,
      child: TextField(
        onChanged: (value) {
          locationCallback(value);
        },
        controller: controller,
        focusNode: focusNode,
        onTap: () async {
          final sessionToken = const Uuid().v4();
          final Suggestion? result = await showSearch(
            context: context,
            delegate: AddressSearch(sessionToken),
          );
          if (result != null) {
            locationCallback(result.description);
            controller.text = result.description;
          }
        },
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          hintText: label,
          focusColor: Colors.white,
          iconColor: Colors.white,

          hintStyle: const TextStyle(color: Colors.white),
          filled: true,
          fillColor: Colors.black38,
          border: InputBorder.none,
          enabledBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(
              Radius.circular(10.0),
            ),
            borderSide: BorderSide(
              color: Colors.grey.shade400,
              width: 2,
            ),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(10.0),
            ),
            borderSide: BorderSide(
              color: Colors.white,
              width: 2,
            ),
          ),

          // contentPadding: const EdgeInsets.all(15),
          // hintText: hint,
        ),
      ),
    );
  }

  bool hide = false;
  // Method for calculating the distance between two places
  Future<bool> _calculateDistance() async {
    try {
      // Retrieving placemarks from addresses

      List<Location> startPlacemark = await locationFromAddress(_startAddress);
      List<Location> destinationPlacemark =
          await locationFromAddress(_destinationAddress);

      double startLatitude = _startAddress == _currentAddress
          ? _currentPosition.latitude
          : startPlacemark[0].latitude;

      double startLongitude = _startAddress == _currentAddress
          ? _currentPosition.longitude
          : startPlacemark[0].longitude;

      double destinationLatitude = destinationPlacemark[0].latitude;
      double destinationLongitude = destinationPlacemark[0].longitude;

      String startCoordinatesString = '($startLatitude, $startLongitude)';
      String destinationCoordinatesString =
          '($destinationLatitude, $destinationLongitude)';

      // Start Location Marker
      Marker startMarker = Marker(
        markerId: MarkerId(startCoordinatesString),
        position: LatLng(startLatitude, startLongitude),
        infoWindow: InfoWindow(
          title: 'Start $startCoordinatesString',
          snippet: _startAddress,
        ),
        icon: BitmapDescriptor.defaultMarker,
      );

      // Destination Location Marker
      Marker destinationMarker = Marker(
        markerId: MarkerId(destinationCoordinatesString),
        position: LatLng(destinationLatitude, destinationLongitude),
        infoWindow: InfoWindow(
          title: 'Destination $destinationCoordinatesString',
          snippet: _destinationAddress,
        ),
        icon: BitmapDescriptor.defaultMarker,
      );

      // Adding the markers to the list
      markersList.add(startMarker);
      markersList.add(destinationMarker);

      print(
        'START COORDINATES: ($startLatitude, $startLongitude)',
      );
      print(
        'DESTINATION COORDINATES: ($destinationLatitude, $destinationLongitude)',
      );

      // Calculating to check that the position relative
      // to the frame, and pan & zoom the camera accordingly.
      double miny = (startLatitude <= destinationLatitude)
          ? startLatitude
          : destinationLatitude;
      double minx = (startLongitude <= destinationLongitude)
          ? startLongitude
          : destinationLongitude;
      double maxy = (startLatitude <= destinationLatitude)
          ? destinationLatitude
          : startLatitude;
      double maxx = (startLongitude <= destinationLongitude)
          ? destinationLongitude
          : startLongitude;

      double southWestLatitude = miny;
      double southWestLongitude = minx;

      double northEastLatitude = maxy;
      double northEastLongitude = maxx;

      // Accommodate the two locations within the
      // camera view of the map

      _controller!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            northeast: LatLng(northEastLatitude, northEastLongitude),
            southwest: LatLng(southWestLatitude, southWestLongitude),
          ),
          100.0,
        ),
      );

      // Calculating the distance between the start and the end positions
      // with a straight path, without considering any route
      // double distanceInMeters = await Geolocator.bearingBetween(
      //   startLatitude,
      //   startLongitude,
      //   destinationLatitude,
      //   destinationLongitude,
      // );

      await _createPolylines(startLatitude, startLongitude, destinationLatitude,
          destinationLongitude);

      double totalDistance = 0.0;

      // Calculating the total distance by adding the distance
      // between small segments
      for (int i = 0; i < polylineCoordinates.length - 1; i++) {
        totalDistance += _coordinateDistance(
          polylineCoordinates[i].latitude,
          polylineCoordinates[i].longitude,
          polylineCoordinates[i + 1].latitude,
          polylineCoordinates[i + 1].longitude,
        );
      }
      double totalDistance1 = 0.0;

      for (int i = 0; i < polylineCoordinates1.length - 1; i++) {
        totalDistance1 += _coordinateDistance(
          polylineCoordinates1[i].latitude,
          polylineCoordinates1[i].longitude,
          polylineCoordinates1[i + 1].latitude,
          polylineCoordinates1[i + 1].longitude,
        );
      }

      setState(() {
        _placeDistance = totalDistance.toStringAsFixed(2);
        _placeDistance1 = totalDistance1.toStringAsFixed(2);
        hide = true;
        print('DISTANCE: $_placeDistance km');
      });
      _showNotificationCustomSound();
      return true;
    } catch (e) {
      print(e);
    }
    return false;
  }

  int? bestAirIndexLine;
  // Formula for calculating distance between two coordinates
  // https://stackoverflow.com/a/54138876/11910277
  double _coordinateDistance(lat1, lon1, lat2, lon2) {
    var p = 0.017453292519943295;
    var c = Math.cos;
    var a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * Math.asin(Math.sqrt(a));
  }

  Polyline? polyline1;
  Polyline? polyline2;
  int airIndex1 = 0;
  int airIndex2 = 0;
  List<Circle> aqiCircle = [];
  List<LatLng> polylineCoordinates1 = [];
  // Create the polylines for showing the route between two places
  _createPolylines(
    double startLatitude,
    double startLongitude,
    double destinationLatitude,
    double destinationLongitude,
  ) async {
    setState(() {
      airIndex1 = 0;
      airIndex2 = 0;
      polylineCoordinates1 = [];
      marker = null;
    });

    polylinePoints = PolylinePoints();
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      Secrets.API_KEY, // Google Maps API Key
      PointLatLng(startLatitude, startLongitude),
      PointLatLng(destinationLatitude, destinationLongitude),
      travelMode: TravelMode.driving,
    );
    PolylineResult result1 = await polylinePoints.getRouteBetweenCoordinates(
      Secrets.API_KEY, // Google Maps API Key
      PointLatLng(startLatitude, startLongitude),
      PointLatLng(destinationLatitude, destinationLongitude),
      travelMode: TravelMode.transit,
    );

    int i = 0;
    int j = 0;
    List<LatLng> temp1 = [];

    if (result1.points.isNotEmpty) {
      // log(AQIIINDEX.toString());

      for (var point in result1.points) {
        if (i % 50 == 0) {
          int aqi = (await getAQI(LatLng(
              result1.points[i % result1.points.length].latitude,
              result1.points[i % result1.points.length].longitude)) as int);
          if (aqi != 0) {
            airIndex2 += aqi;
            j += 1;
          }
        }
        i += 1;
        temp1.add(LatLng(point.latitude, point.longitude));
      }
    }
    setState(() {
      i = 0;
    });
    List<LatLng> temp2 = [];

    int k = 0;
    if (result.points.isNotEmpty) {
      for (var point in result.points) {
        // log("j");
        if (i % 50 == 0) {
          int aqi = (await getAQI(LatLng(
              result.points[i % result.points.length].latitude,
              result.points[i % result.points.length].longitude)) as int);
          if (aqi != 0) {
            airIndex1 += aqi;
            k += 1;
          }
        }

        i += 1;

        temp2.add(LatLng(point.latitude, point.longitude));
      }
    }
    setState(() {
      airIndex1 = airIndex1 ~/ j;
      airIndex2 = airIndex2 ~/ k;
    });

    if (airIndex1 > airIndex2) {
      setState(() {
        bestAirIndexLine = 1;
      });
    } else {
      setState(() {
        bestAirIndexLine = 0;
      });
    }
    setState(() {
      polylineCoordinates = temp1;
      polylineCoordinates1 = temp2;
    });
    // PolylineId id = const PolylineId('poly');
    // setState(() {
    //   polyline1 = Polyline(
    //     polylineId: id,
    //     color: polyLineIndex == 0 ? Colors.blue : Colors.grey,
    //     onTap: () {
    //       setState(() {
    //         polyLineIndex = 0;
    //       });
    //     },
    //     points: polylineCoordinates,
    //     width: 6,
    //   );
    // });
    // // polylines[id] = polyline;
    // PolylineId id1 = const PolylineId('poly1');
    // setState(() {
    // polyline2 = Polyline(
    //   polylineId: id1,
    //   color: polyLineIndex == 1 ? Colors.blue : Colors.grey,
    //   onTap: () {
    //     setState(() {
    //       polyLineIndex = 1;
    //     });
    //   },
    //   points: polylineCoordinates1,
    //   width: 6,
    // );
    // });
    // polylines[id1] = polyline1;
  }

  arePointsNear(checkPoint, centerPoint, km) {
    var ky = 40000 / 360;
    var kx = Math.cos(Math.pi * centerPoint.latitude / 180.0) * ky;
    var dx =
        (((centerPoint.longitude ?? 0) - (checkPoint!.longitude ?? 0)).abs()) *
            kx;
    var dy =
        ((centerPoint.latitude ?? 0) - (checkPoint.latitude ?? 0)).abs().abs() *
            ky;
    return Math.sqrt(dx * dx + dy * dy) <= km;
  }

  // @override
  // void initState() {
  //   super.initState();
  //   _getCurrentLocation();
  // }
  int? index;
  bool showDialog = false;
  @override
  Widget build(BuildContext context) {
    var height = MediaQuery.of(context).size.height;
    var width = MediaQuery.of(context).size.width;

    return SafeArea(
      child: Scaffold(
        body: Stack(
          children: [
            GoogleMap(
              compassEnabled: true,
              tileOverlays: {
                const TileOverlay(
                  tileOverlayId: TileOverlayId("1"),
                )
              },
              mapType: MapType.normal,
              initialCameraPosition: initialLocation,
              polylines: polylineCoordinates.isEmpty &&
                      polylineCoordinates1.isEmpty
                  ? {}
                  : <Polyline>{
                      Polyline(
                        polylineId: const PolylineId("1234"),
                        color:
                            bestAirIndexLine == 0 ? Colors.green : Colors.blue,
                        onTap: () {
                          setState(() {
                            polyLineIndex = 0;
                          });
                          log("2");
                        },
                        points: polylineCoordinates,
                        width: 6,
                      ),
                      Polyline(
                        polylineId: const PolylineId("123"),
                        color:
                            bestAirIndexLine == 1 ? Colors.green : Colors.blue,
                        onTap: () {
                          setState(() {
                            polyLineIndex = 1;
                            log("1");
                          });
                        },
                        points: polylineCoordinates1,
                        width: 6,
                      ),
                    },
              onTap: (latlong) async {
                // log(latlong.toString());
                setState(() {
                  showDialog = false;
                });
                for (var point in polylineCoordinates) {
                  if (arePointsNear(point, latlong, .1)) {
                    log(latlong.toString());
                    setState(() {
                      polyLineIndex = 0;
                      // index = airIndex1;
                      // showDialog = true;
                    });

                    return;
                  }
                }
                for (var point in polylineCoordinates1) {
                  if (arePointsNear(point, latlong, .1)) {
                    log(latlong.toString());
                    setState(() {
                      polyLineIndex = 1;
                      // index = airIndex2;
                      // showDialog = true;
                    });

                    return;
                  }
                }
              },
              onLongPress: (latlong) async {
                // log(latlong.toString());
                for (var point in polylineCoordinates) {
                  setState(() {
                    showDialog = false;
                  });
                  if (arePointsNear(point, latlong, .1)) {
                    log(latlong.toString());
                    setState(() {
                      // polyLineIndex = 0;
                      index = airIndex1;
                      // showDialog = true;
                    });
                    setState(() {
                      marker = Marker(
                        markerId: const MarkerId("Position marker"),
                        position: latlong,
                        infoWindow: InfoWindow(
                          title: "Average AQI in this path $airIndex1 ",
                          // snippet: _destinationAddress,
                        ),
                        icon: BitmapDescriptor.defaultMarker,
                      );
                    });
                    return;
                  }
                }
                for (var point in polylineCoordinates1) {
                  if (arePointsNear(point, latlong, .1)) {
                    log(latlong.toString());
                    setState(() {
                      // polyLineIndex = 1;
                      index = airIndex2;
                      // showDialog = true;
                    });
                    setState(() {
                      marker = Marker(
                        markerId: const MarkerId("Position marker"),
                        position: latlong,
                        infoWindow: InfoWindow(
                          title: "Average AQI in this path $airIndex2 ",
                          // snippet: _destinationAddress,
                        ),
                        icon: BitmapDescriptor.defaultMarker,
                      );
                    });
                    // int aqi = (await getAQI(latlong));
                    return;
                  }
                }
                setState(() {
                  // showDialog = true;
                });
                int aqi = (await getAQI(latlong));
                setState(() {
                  index = aqi;
                  // showDialog = true;
                });
                setState(() {
                  marker = Marker(
                    markerId: const MarkerId("Position marker"),
                    position: latlong,
                    infoWindow: InfoWindow(
                      title: "Aqi $aqi ",
                      // snippet: _destinationAddress,
                    ),
                    icon: BitmapDescriptor.defaultMarker,
                  );
                });
              },
              markers: Set.of(
                  (marker != null) ? [marker!, ...markersList] : markersList),
              onMapCreated: (GoogleMapController controller) {
                _controller = controller;
              },
            ),
            SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: AnimatedContainer(
                      color: (_startAddress != '' && _destinationAddress != '')
                          ? Colors.purple
                          : Colors.indigo,
                      width: width,
                      constraints:
                          BoxConstraints(minHeight: 30, maxHeight: height * .3),
                      height: !hide ? 35 : null,
                      padding: EdgeInsets.only(
                        top: !hide ? 0 : 10.0,
                      ),
                      duration: const Duration(milliseconds: 500),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (hide) ...[
                            _textField(
                                label: 'Start',
                                hint: 'Choose starting point',
                                prefixIcon: const Icon(
                                  Icons.circle_outlined,
                                  color: Colors.white,
                                ),
                                suffixIcon: IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {
                                    startAddressController.text =
                                        _currentAddress;
                                    _startAddress = _currentAddress;
                                  },
                                ),
                                controller: startAddressController,
                                focusNode: startAddressFocusNode,
                                width: width,
                                locationCallback: (String value) async {
                                  setState(() {
                                    _startAddress = value;
                                  });
                                }),
                            const SizedBox(height: 10),
                            _textField(
                                label: 'Destination',
                                hint: 'Choose destination',
                                prefixIcon: const Icon(
                                  Icons.pin_drop_outlined,
                                  color: Colors.red,
                                ),
                                suffixIcon: IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {
                                    destinationAddressController.text = "";
                                  },
                                ),
                                controller: destinationAddressController,
                                focusNode: desrinationAddressFocusNode,
                                width: width,
                                locationCallback: (String value) async {
                                  setState(() {
                                    _destinationAddress = value;
                                  });
                                }),
                            const SizedBox(height: 5),
                            ElevatedButton(
                              onPressed: (_startAddress != '' &&
                                      _destinationAddress != '')
                                  ? () async {
                                      if (isLoading) {
                                        return;
                                      }
                                      startAddressFocusNode.unfocus();
                                      desrinationAddressFocusNode.unfocus();
                                      setState(() {
                                        markersList = [];
                                        if (markers.isNotEmpty) {
                                          markers.clear();
                                        }
                                        if (polylines.isNotEmpty) {
                                          polylines.clear();
                                        }
                                        if (polylineCoordinates.isNotEmpty) {
                                          polylineCoordinates.clear();
                                        }
                                        _placeDistance = null;
                                      });

                                      _calculateDistance().then((isCalculated) {
                                        if (isCalculated) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Distance Calculated Sucessfully'),
                                            ),
                                          );
                                        } else {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Error Calculating Distance'),
                                            ),
                                          );
                                        }
                                      });
                                    }
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  isLoading
                                      ? 'Fetching aqi....'
                                      : 'Get Direction'.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20.0,
                                  ),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                primary: Colors.blueAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20.0),
                                ),
                              ),
                            ),
                          ],
                          InkWell(
                            onTap: () {
                              setState(() {
                                hide = !hide;
                              });
                            },
                            child: SizedBox(
                              height: 30,
                              child: Center(
                                  child: Icon(
                                !hide
                                    ? Icons.arrow_drop_down
                                    : Icons.arrow_drop_up,
                                color: Colors.white,
                              )),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Visibility(
                      visible: _placeDistance == null ? false : true,
                      child: Container(
                          // margin: const EdgeInsets.only(bottom: 10),
                          child: Container(
                        width: width,
                        height: 50,
                        color: Colors.white,
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Text(
                                  "🟢 AQI is ${airIndex1 > airIndex2 ? airIndex2 : airIndex1}"),
                              Text(
                                  "🔵 AQI is ${airIndex1 > airIndex2 ? airIndex1 : airIndex2}")
                            ]),
                      )
                          //  Text(
                          //   'DISTANCE: ${polyLineIndex == 0 ? _placeDistance : _placeDistance1} km',
                          //   style: const TextStyle(
                          //     fontSize: 16,
                          //     fontWeight: FontWeight.bold,
                          //   ),
                          // ),
                          ),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
        //   floatingActionButton: FloatingActionButton(
        //       child: const Icon(Icons.location_searching),
      ),
    );
  }
}
